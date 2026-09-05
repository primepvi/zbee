const std = @import("std");

const source_mod = @import("Source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("Token.zig");
const Token = token_mod.Token;

const Type = @import("symbols.zig").Type;

pub const DiagnosticLevel = enum {
    err,
    warning,

    pub fn label(self: DiagnosticLevel) []const u8 {
        return switch (self) {
            .err => "error",
            .warning => "warning",
        };
    }
};

fn countDigits(value: usize) usize {
    var n = value;
    var result: usize = 1;

    while (n >= 10) {
        n /= 10;
        result += 1;
    }

    return result;
}

fn writeSpaces(writer: *std.Io.Writer, count: usize) !void {
    for (0..count) |_| {
        try writer.writeByte(' ');
    }
}

pub const Diagnostic = struct {
    source: *const Source,
    message: []const u8,
    level: DiagnosticLevel,
    code: u32,
    range: SourceSpan,
    emphasis: SourceSpan,

    const Self = @This();

    pub fn toString(
        self: *const Self,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        var output = std.Io.Writer.Allocating.init(allocator);
        defer output.deinit();

        const line_count = self.source.lines_span.items.len;
        const gutter = countDigits(line_count);

        try output.writer.print(
            "{s}({d}) at [{s}:{d}:{d}]: {s}\n",
            .{
                self.level.label(),
                self.code,
                self.source.name,
                self.emphasis.line,
                self.emphasis.col,
                self.message,
            },
        );

        try writeSpaces(&output.writer, gutter + 2);
        try output.writer.writeAll("|\n");

        const first_line = self.range.line - 1;
        for (first_line..line_count) |i| {
            const span = self.source.lines_span.items[i];

            if (span.start > self.range.end)
                break;

            const line = span.line;
            const line_digits = countDigits(line);

            try output.writer.print(
                " {d}",
                .{line},
            );

            try writeSpaces(
                &output.writer,
                gutter - line_digits + 1,
            );

            try output.writer.print(
                "| {s}\n",
                .{self.source.code[span.start .. span.end + 1]},
            );

            if (self.emphasis.line != line)
                continue;

            try writeSpaces(&output.writer, gutter + 2);
            try output.writer.writeByte('|');

            if (self.emphasis.col > 1) {
                try writeSpaces(
                    &output.writer,
                    self.emphasis.col - 1,
                );
            }

            const emphasis_len =
                self.emphasis.end - self.emphasis.start;

            for (0..@max(emphasis_len, 1)) |_| {
                try output.writer.writeByte('^');
            }

            try output.writer.writeByte('\n');
        }

        return try output.toOwnedSlice();
    }
};

pub const DiagnosticBag = struct {
    allocator: std.mem.Allocator,
    diagnostics: std.ArrayList(Diagnostic),
    source: *const Source,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, source: *const Source) Self {
        return .{
            .allocator = allocator,
            .diagnostics = .empty,
            .source = source,
        };
    }

    pub fn deinit(self: *Self) void {
        self.diagnostics.deinit(self.allocator);
    }

    pub fn add(self: *Self, diagnostic: Diagnostic) !void {
        try self.diagnostics.append(self.allocator, diagnostic);
    }

    pub fn errorLexerUnexpectedSymbol(self: *Self, token: Token) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();

        try builder.writer.print("unexpected symbol '{s}' has found.", .{token.lexeme});
        const message = try builder.toOwnedSlice();

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 100,
            .range = token.span,
            .emphasis = token.span,
        };

        try self.add(diagnostic);
    }

    pub fn errorLexerUnterminatedString(self: *Self, string: Token) !void {
        const range: SourceSpan = .{ .line = string.span.line, .col = string.span.col, .start = string.span.start, .end = string.span.end };

        const emphasis: SourceSpan = .{
            .line = string.span.line,
            .col = string.span.col + string.lexeme.len,
            .start = string.span.end,
            .end = string.span.end + 1,
        };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "unterminated string has found, expected '\"'.",
            .level = .err,
            .code = 101,
            .range = range,
            .emphasis = emphasis,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserUnexpectedToken(self: *Self, token: Token, expected: []const u8) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();

        try builder.writer.print("unexpected token has found, expected '{s}' but received '{s}'.", .{
            expected, token.lexeme,
        });
        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 200,
            .range = token.span,
            .emphasis = token.span,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserInvalidExpr(self: *Self, token: Token) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "invalid expr has found.",
            .level = .err,
            .code = 201,
            .range = token.span,
            .emphasis = token.span,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserUnterminatedBlockStmt(self: *Self, start_span: SourceSpan, end_span: SourceSpan) !void {
        const range: SourceSpan = .{
            .line = start_span.line,
            .col = start_span.col,
            .start = start_span.start,
            .end = end_span.end,
        };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "unterminated block stmt has found.",
            .level = .err,
            .code = 202,
            .range = range,
            .emphasis = end_span,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserInvalidIfStmtBody(self: *Self, keyword: Token, invalid: Token) !void {
        const range: SourceSpan = .{
            .line = keyword.span.line,
            .col = keyword.span.col,
            .start = keyword.span.start,
            .end = invalid.span.end,
        };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "The 'if' statement expects an short body with '-> (statement)' or an block body with 'then (statements) end'.",
            .level = .err,
            .code = 203,
            .range = range,
            .emphasis = invalid.span,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserInvalidWhileStmtBody(self: *Self, keyword: Token, invalid: Token) !void {
        const range: SourceSpan = .{
            .line = keyword.span.line,
            .col = keyword.span.col,
            .start = keyword.span.start,
            .end = invalid.span.end,
        };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "The 'while' statement expects an short body with '-> (statement)' or an block body with 'do (statements) end'.",
            .level = .err,
            .code = 204,
            .range = range,
            .emphasis = invalid.span,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserInvalidForStmtBody(self: *Self, keyword: Token, invalid: Token) !void {
        const range: SourceSpan = .{
            .line = keyword.span.line,
            .col = keyword.span.col,
            .start = keyword.span.start,
            .end = invalid.span.end,
        };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "The 'for' statement expects an short body with '-> (statement)' or an block body with 'do (statements) end'.",
            .level = .err,
            .code = 205,
            .range = range,
            .emphasis = invalid.span,
        };

        try self.add(diagnostic);
    }

    pub fn errorParserInvalidForInitStmt(self: *Self, span: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "The 'for' statement expects an 'variable declarement' in the 'init statement'.",
            .level = .err,
            .code = 206,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerTypeMismatch(self: *Self, span: SourceSpan, expected: Type, received: Type) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("expected type '{s}', but received type '{s}'.", .{ try expected.toString(self.allocator), try received.toString(self.allocator) });

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 300,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerInvalidVoidUsage(self: *Self, span: SourceSpan, complement: []const u8) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("type 'void' cannot be used as '{s}'.", .{complement});

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 301,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerIdentifierAlreadyDeclared(self: *Self, span: SourceSpan, identifier: []const u8) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("already has a declaration with identifier '{s}'.", .{identifier});

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 302,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerNonGlobalScopeFunctionDecl(self: *Self, span: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "function declarations is only allowed in global scope.",
            .level = .err,
            .code = 303,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerInvalidTypeAnnotation(self: *Self, range: SourceSpan, emphasis: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "attempt to annotate an identifier with invalid type.",
            .level = .err,
            .code = 304,
            .range = range,
            .emphasis = emphasis,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerVoidControlPaths(self: *Self, span: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "some function control paths dont return value.",
            .level = .err,
            .code = 305,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerInvalidReturnUsage(self: *Self, span: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "attempt to return value outside function block.",
            .level = .err,
            .code = 306,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerUndefinedIdentifier(self: *Self, span: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "undefined identifier.",
            .level = .err,
            .code = 307,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerInvalidAssignment(self: *Self, span: SourceSpan, complement: []const u8) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("attempt to assign a '{s}'.", .{complement});

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 308,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerUnsupportedUnaryOperation(self: *Self, span: SourceSpan, operator: []const u8, operand: Type) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("unary operator '{s}' dont support a operand of type '{s}'.", .{ operator, try operand.toString(self.allocator) });

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 309,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerUnsupportedBinaryOperation(self: *Self, span: SourceSpan, operator: []const u8, left: Type, right: Type) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("binary operator '{s}' dont support a left expression of type '{s}' and right expression of type '{s}'.", .{ operator, try left.toString(self.allocator), try right.toString(self.allocator) });

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 310,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerNonFunctionCall(self: *Self, span: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "attempt to call a non-function identifier.",
            .level = .err,
            .code = 311,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn errorCheckerInvalidFunctionArity(self: *Self, span: SourceSpan, expected: usize, received: usize) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();
        try builder.writer.print("function expects '{d}' arguments, but received '{d}' arguments.", .{ expected, received });

        const message = try builder.toOwnedSlice();
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 312,
            .range = span,
            .emphasis = span,
        };

        try self.add(diagnostic);
    }

    pub fn hasErrors(self: *const Self) bool {
        for (self.diagnostics.items) |item| {
            if (item.level == .err) {
                return true;
            }
        }

        return false;
    }

    pub fn debug(self: *const Self) !void {
        for (self.diagnostics.items) |item| {
            std.debug.print("{s}\n", .{try item.toString(self.allocator)});
        }
    }
};
