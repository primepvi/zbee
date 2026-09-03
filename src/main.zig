const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Source = @import("internals/source.zig").Source;
const DiagnosticBag = @import("internals/diagnostics.zig").DiagnosticBag;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const source = try Source.init_from_file(arena.allocator(), init.io, "examples/all.bee");
    var lexer_bag = DiagnosticBag.init(arena.allocator(), &source);
    var lexer = Lexer.init(&source, &lexer_bag);    
    while (lexer.has_more_tokens()) {
      const token = lexer.next_token();
      std.debug.print("{any}\n", .{token});
    }

    if (lexer_bag.has_errors()) {
        try lexer_bag.debug();
    }
}
