const std = @import("std");

pub const SourceSpan = struct {
    line: usize,
    col: usize,
    start: usize,
    end: usize,
};

pub const SourceLineSpan = struct {
    line: usize,
    start: usize,
    end: usize,
};

pub const Source = struct {
    name: []const u8,
    code: []const u8,
    lines_span: std.ArrayList(SourceLineSpan),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, code: []const u8) !Source {
        var lines_span = std.ArrayList(SourceLineSpan).empty;
        var start: usize = 0;
        for (0..code.len) |cursor| {
            if (code[cursor] != '\n')
                continue;

            const end = if (cursor > 0) cursor - 1 else cursor;
            try lines_span.append(allocator, .{ .line = lines_span.items.len + 1, .start = start, .end = end });
            start = cursor + 1;
        }

        if (start < code.len) {
            try lines_span.append(allocator, .{
                .line = lines_span.items.len + 1,
                .start = start,
                .end = code.len,
            });
        }

        return .{ .name = name, .code = code, .lines_span = lines_span };
    }

    pub fn initFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Source {
        const dir: std.Io.Dir = .cwd();
        const buffer = try dir.readFileAlloc(io, path, allocator, .unlimited);
        return Source.init(allocator, path, buffer);
    }
};
