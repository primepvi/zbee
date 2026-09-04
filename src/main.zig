const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Token = @import("internals/token.zig").Token;
const Source = @import("internals/source.zig").Source;
const DiagnosticBag = @import("internals/diagnostics.zig").DiagnosticBag;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const source = try Source.initFromFile(arena.allocator(), init.io, "examples/all.bee");
    var tokens = std.ArrayList(Token).empty;
    
    var lexer_bag = DiagnosticBag.init(arena.allocator(), &source);
    defer lexer_bag.deinit();
    
    var lexer = Lexer.init(&source, &lexer_bag);
    var current: ?Token = null;
    while (current != null and current.?.kind != .eof) {
        current = try lexer.nextToken();
        try tokens.append(arena.allocator(), current.?);
    }

    if (lexer_bag.hasErrors()) {
        try lexer_bag.debug();
        std.process.exit(1);
    }

    var parser_bag = DiagnosticBag.init(arena.allocator(), &source);
    defer parser_bag.deinit();
    
    var parser = Parser.init(arena.allocator(), &source, tokens, &parser_bag);
    const ast = try parser.parse();
    if (parser_bag.hasErrors()) {
        try parser_bag.debug();
        std.process.exit(1);
    }           

    for (ast.stmts.items) |stmt| {
        std.debug.print("{}\n", .{stmt});
    }
}
