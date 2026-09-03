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

    pub fn add_unexpected_symbol(self: *Self, token: Token) !void {
        var builder = std.Io.Writer.Allocating.init(self.allocator);
        defer builder.deinit();

        try builder.writer.print("unexpected symbol '{s}' has found.", .{token.lexeme});
        const message = try builder.toOwnedSlice();
        
        const diagnostic = Diagnostic{
            .source = self.source,
            .message = message,
            .level = .err,
            .code = 100,
            .range = token.span,
            .emphasis = token.span,
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
