const std = @import("std");
const ascii = std.ascii;

const source_mod = @import("internals/source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("internals/token.zig");
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
        return .{ .line = 1, .col = 1, .cursor = 0, .source = source, .bag = bag };
    }

    pub fn has_more_tokens(self: Self) bool {
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

    fn make_source_span(self: Self, len: usize) SourceSpan {
        return .{ .line = self.line, .col = self.col, .start = self.cursor - len, .end = self.cursor };
    }

    pub fn next_token(self: *Self) Token {
        self.read_whitespaces();
        if (!self.has_more_tokens()) {
            return .{ .kind = .eof, .lexeme = "", .span = self.make_source_span(1) };
        }

        const current = self.peek();
        if (ascii.isAlphabetic(current)) {
            return self.read_keyword();
        }

        if (current == '"') {
            return self.read_string();
        }

        if (ascii.isDigit(current)) {
            return self.read_number();
        }

        return self.read_symbol();
    }

    fn read_whitespaces(self: *Self) void {
        while (self.has_more_tokens() and ascii.isWhitespace(self.peek())) {
            if (self.peek() == '\n') {
                self.cursor += 1;
                self.line += 1;
                self.col = 1;
            } else {
                self.advance();
            }
        }
    }

    fn read_keyword(self: *Self) Token {
        const start = self.cursor;
        while (self.has_more_tokens() and (ascii.isAlphanumeric(self.peek()) or self.peek() == '_'))
            self.advance();

        const lexeme = self.source.code[start..self.cursor];
        return .{ .kind = TokenKind.get_keyword_kind(lexeme), .lexeme = lexeme, .span = self.make_source_span(lexeme.len) };
    }

    fn read_string(self: *Self) Token {
        self.advance(); // eating start string quote symbol

        const start = self.cursor;
        while (self.has_more_tokens() and self.peek() != '"' and self.peek() != '\n')
            self.advance();

        if (self.peek() != '"') {
            // TODO: add unterminated string diagnostic.
        }

        const lexeme = self.source.code[start..self.cursor];
        self.advance(); // eating end string quote symbol

        return .{ .kind = .string_literal, .lexeme = lexeme, .span = self.make_source_span(lexeme.len) };
    }

    fn read_number(self: *Self) Token {
        const start = self.cursor;
        while (self.has_more_tokens() and ascii.isDigit(self.peek()))
            self.advance();

        const lexeme = self.source.code[start..self.cursor];
        return .{ .kind = .number_literal, .lexeme = lexeme, .span = self.make_source_span(lexeme.len) };
    }

    fn read_symbol(self: *Self) Token {
        if (self.cursor + 1 < self.source.code.len) {
            const lexeme = self.source.code[self.cursor .. self.cursor + 2];
            const kind = TokenKind.get_symbol_kind(lexeme);

            if (kind != .invalid) {
                self.advance();
                self.advance();

                return .{ .kind = kind, .lexeme = lexeme, .span = self.make_source_span(2) };
            }
        }

        const lexeme = self.source.code[self.cursor .. self.cursor + 1];
        self.advance();

        const token: Token = .{ .kind = TokenKind.get_symbol_kind(lexeme), .lexeme = lexeme, .span = self.make_source_span(1) };
        if (token.kind == .invalid) {
            self.bag.add_unexpected_symbol(token) catch |err| {
                std.debug.panic("unexpected error has occured.\n {}", .{err});
            };
        }

        return token;
    }
};
