const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Token = @import("internals/token.zig").Token;
const Source = @import("internals/source.zig").Source;
const DiagnosticBag = @import("internals/diagnostics.zig").DiagnosticBag;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const source = try Source.init_from_file(arena.allocator(), init.io, "examples/all.bee");
    var tokens = std.ArrayList(Token).empty;
    var lexer_bag = DiagnosticBag.init(arena.allocator(), &source);
    var lexer = Lexer.init(&source, &lexer_bag);
    while (lexer.has_more_tokens()) {
        const token = lexer.next_token();
        try tokens.append(arena.allocator(), token);
    }

    if (lexer_bag.has_errors()) {
        try lexer_bag.debug();
        @panic("LEXER_PANIC");
    }

    var parser_bag = DiagnosticBag.init(arena.allocator(), &source);
    var parser = Parser.init(arena.allocator(), &source, tokens, &parser_bag);
    const ast = try parser.parse();
    if (parser_bag.has_errors()) {
        try parser_bag.debug();
        @panic("PARSER_PANIC");
    }           

    for (ast.stmts.items) |stmt| {
        std.debug.print("{}\n", .{stmt});
    }
}
