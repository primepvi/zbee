const std = @import("std");

const FixtureRegion = struct {
    name: []const u8,
    content: []const u8,
};

const FixtureParser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Self {
        return .{
            .allocator = allocator,
            .source = source,
        };
    }

    pub fn parse(self: *Self) !std.ArrayList(FixtureRegion) {
        var regions = std.ArrayList(FixtureRegion).empty;
        var lines = std.mem.splitScalar(u8, self.source, '\n');

        var region_name: ?[]const u8 = null;
        var region_start: usize = 0;
        var cursor: usize = 0;

        while (lines.next()) |line| {
            const line_start = cursor;
            cursor += line.len + 1;

            if (std.mem.startsWith(u8, line, "#region ")) {
                if (region_name != null)
                    return error.InvalidFixture;

                region_name = line["#region ".len..];
                region_start = cursor;
                continue;
            }

            if (std.mem.eql(u8, line, "#end")) {
                const name = region_name orelse
                    return error.InvalidFixture;

                const content = self.source[region_start..line_start];

                try regions.append(self.allocator, .{
                    .name = name,
                    .content = content,
                });

                region_name = null;
                continue;
            }

            if (region_name == null and !std.mem.allEqual(u8, line, ' ')) {
                return error.InvalidFixture;
            }
        }

        if (region_name != null)
            return error.InvalidFixture;

        return regions;
    }
};
