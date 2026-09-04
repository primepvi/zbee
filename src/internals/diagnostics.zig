const std = @import("std");

const source_mod = @import("source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("token.zig");
const Token = token_mod.Token;

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

fn digits(value: usize) usize {
    var n = value;
    var result: usize = 1;

    while (n >= 10) {
        n /= 10;
        result += 1;
    }

    return result;
}

fn write_spaces(writer: *std.Io.Writer, count: usize) !void {
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

    pub fn to_string(
        self: *const Self,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        var output = std.Io.Writer.Allocating.init(allocator);
        defer output.deinit();

        const line_count = self.source.lines_span.items.len;
        const gutter = digits(line_count);

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

        try write_spaces(&output.writer, gutter + 2);
        try output.writer.writeAll("|\n");

        const first_line = self.range.line - 1;
        for (first_line..line_count) |i| {
            const span = self.source.lines_span.items[i];

            if (span.start > self.range.end)
                break;

            const line = span.line;
            const line_digits = digits(line);

            try output.writer.print(
                " {d}",
                .{line},
            );

            try write_spaces(
                &output.writer,
                gutter - line_digits + 1,
            );

            try output.writer.print(
                "| {s}\n",
                .{self.source.code[span.start .. span.end + 1]},
            );

            if (self.emphasis.line != line)
                continue;

            try write_spaces(&output.writer, gutter + 2);
            try output.writer.writeByte('|');

            if (self.emphasis.col > 1) {
                try write_spaces(
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
        return .{ .allocator = allocator, .diagnostics = .empty, .source = source };
    }

    pub fn deinit(self: *Self) void {
        self.diagnostics.deinit(self.allocator);
    }

    pub fn add(self: *Self, diagnostic: Diagnostic) !void {
        try self.diagnostics.append(self.allocator, diagnostic);
    }

    pub fn add_lex_unexpected_symbol(self: *Self, token: Token) !void {
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

    pub fn add_lex_unterminated_string(self: *Self, string: Token) !void {
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

    pub fn add_parse_unexpected_token(self: *Self, token: Token, expected: []const u8) !void {
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

    pub fn add_parse_unterminated_parenthesized_expr(self: *Self, open_paren_span: SourceSpan, expr_span: SourceSpan) !void {
        const range: SourceSpan = .{
            .line = open_paren_span.line,
            .col = open_paren_span.col,
            .start = open_paren_span.start,
            .end = expr_span.end + 1,
        };

        const emphasis: SourceSpan = .{ .line = expr_span.line, .col = expr_span.col, .start = expr_span.end, .end = expr_span.end + 1 };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "unterminated parenthesized expr has found.",
            .level = .err,
            .code = 201,
            .range = range,
            .emphasis = emphasis,
        };

        try self.add(diagnostic);
    }

    pub fn add_parse_invalid_expr(self: *Self, emphasis: SourceSpan, range: SourceSpan) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "invalid expr has found.",
            .level = .err,
            .code = 202,
            .range = range,
            .emphasis = emphasis,
        };

        try self.add(diagnostic);
    }

    pub fn add_parse_unexpected_end_of_file(self: *Self, eof: Token) !void {
        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "expected an expr but received end of file.",
            .level = .err,
            .code = 203,
            .range = eof.span,
            .emphasis = eof.span,
        };

        try self.add(diagnostic);
    }

    pub fn add_parse_unterminated_block_stmt(self: *Self, first_token_span: SourceSpan, invalid_token_span: SourceSpan) !void {
        const range: SourceSpan = .{
            .line = first_token_span.line,
            .col = first_token_span.col,
            .start = first_token_span.start,
            .end = invalid_token_span.end,
        };

        const diagnostic: Diagnostic = .{
            .source = self.source,
            .message = "unterminated block stmt has found.",
            .level = .err,
            .code = 204,
            .range = range,
            .emphasis = invalid_token_span,
        };

        try self.add(diagnostic);
    }

    pub fn has_errors(self: *const Self) bool {
        for (self.diagnostics.items) |item| {
            if (item.level == .err) {
                return true;
            }
        }

        return false;
    }

    pub fn debug(self: *const Self) !void {
        for (self.diagnostics.items) |item| {
            std.debug.print("{s}\n", .{try item.to_string(self.allocator)});
        }
    }
};
