const std = @import("std");
const ascii = std.ascii;

const source_mod = @import("internals/Source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("internals/Token.zig");
const Token = token_mod.Token;
const TokenKind = token_mod.TokenKind;

const diagnostics_mod = @import("internals/diagnostics.zig");
const Diagnostic = diagnostics_mod.Diagnostic;
const DiagnosticBag = diagnostics_mod.DiagnosticBag;

pub const Lexer = struct {
    cursor: u32,
    line: u32,
    col: u32,
    source: *const Source,
    bag: *DiagnosticBag,

    const Self = @This();

    pub fn init(source: *const Source, bag: *DiagnosticBag) Self {
        return .{
            .line = 1,
            .col = 1,
            .cursor = 0,
            .source = source,
            .bag = bag,
        };
    }

    pub fn hasMoreTokens(self: Self) bool {
        return self.cursor < self.source.code.len;
    }

    fn peek(self: Self) u8 {
        return self.source.code[self.cursor];
    }

    fn lookahead(self: Self) u8 {
        return self.source.code[self.cursor + 1];
    }

    fn advance(self: *Self) void {
        self.cursor += 1;
        self.col += 1;
    }

    fn makeSourceSpan(self: Self, len: usize) SourceSpan {
        return .{
            .line = self.line,
            .col = self.col - len + 1,
            .start = self.cursor - len,
            .end = self.cursor,
        };
    }

    pub fn nextToken(self: *Self) !Token {
        self.readWhitespaces();
        if (!self.hasMoreTokens()) {
            return .{
                .kind = .eof,
                .lexeme = "eof",
                .span = self.makeSourceSpan(1),
            };
        }

        const current = self.peek();
        if (ascii.isAlphabetic(current)) {
            return self.readKeyword();
        }

        if (current == '"') {
            return try self.readString();
        }

        if (ascii.isDigit(current)) {
            return self.readNumber();
        }

        return try self.readSymbol();
    }

    fn readWhitespaces(self: *Self) void {
        while (self.hasMoreTokens() and ascii.isWhitespace(self.peek())) {
            if (self.peek() == '\n') {
                self.cursor += 1;
                self.line += 1;
                self.col = 1;
            } else {
                self.advance();
            }
        }
    }

    fn readKeyword(self: *Self) Token {
        const start = self.cursor;
        while (self.hasMoreTokens() and (ascii.isAlphanumeric(self.peek()) or self.peek() == '_'))
            self.advance();

        const lexeme = self.source.code[start..self.cursor];
        return .{
            .kind = TokenKind.getKeywordKind(lexeme),
            .lexeme = lexeme,
            .span = self.makeSourceSpan(lexeme.len),
        };
    }

    fn readString(self: *Self) !Token {
        self.advance(); // eating start string quote symbol

        const start = self.cursor;
        while (self.hasMoreTokens() and self.peek() != '"' and self.peek() != '\n')
            self.advance();

        const lexeme = self.source.code[start..self.cursor];
        const token: Token = .{
            .kind = .string_literal,
            .lexeme = lexeme,
            .span = self.makeSourceSpan(lexeme.len),
        };

        if (self.peek() != '"') {
            try self.bag.errorLexerUnterminatedString(token);
        } else {
            self.advance(); // eating end string quote symbol
        }

        return token;
    }

    fn readNumber(self: *Self) Token {
        const start = self.cursor;
        while (self.hasMoreTokens() and ascii.isDigit(self.peek()))
            self.advance();

        const lexeme = self.source.code[start..self.cursor];
        return .{
            .kind = .number_literal,
            .lexeme = lexeme,
            .span = self.makeSourceSpan(lexeme.len),
        };
    }

    fn readSymbol(self: *Self) !Token {
        if (self.cursor + 1 < self.source.code.len) {
            const lexeme = self.source.code[self.cursor .. self.cursor + 2];
            const kind = TokenKind.getSymbolKind(lexeme);

            if (kind != .invalid) {
                self.advance();
                self.advance();

                return .{
                    .kind = kind,
                    .lexeme = lexeme,
                    .span = self.makeSourceSpan(2),
                };
            }
        }

        const lexeme = self.source.code[self.cursor .. self.cursor + 1];
        self.advance();

        const token: Token = .{
            .kind = TokenKind.getSymbolKind(lexeme),
            .lexeme = lexeme,
            .span = self.makeSourceSpan(1),
        };
        if (token.kind == .invalid) {
            try self.bag.errorLexerUnexpectedSymbol(token);
        }

        return token;
    }
};
