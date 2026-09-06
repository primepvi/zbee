const std = @import("std");
const Lexer = @import("Lexer.zig").Lexer;
const Parser = @import("Parser.zig").Parser;
const TypeChecker = @import("TypeChecker.zig").TypeChecker;
const Token = @import("internals/Token.zig").Token;
const Source = @import("internals/Source.zig").Source;
const DiagnosticBag = @import("internals/diagnostics.zig").DiagnosticBag;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var source = try Source.initFromFile(arena.allocator(), init.io, "examples/all.bee");
    defer source.deinit(arena.allocator());
    
    var tokens = std.ArrayList(Token).empty;
    defer tokens.deinit(arena.allocator());
    
    var lexer_bag = DiagnosticBag.init(arena.allocator(), &source);
    defer lexer_bag.deinit();
    
    var lexer = Lexer.init(&source, &lexer_bag);
    var current: Token = undefined;
    while (current.kind != .eof) {
        current = try lexer.nextToken();
        try tokens.append(arena.allocator(), current);        
    }

    if (lexer_bag.hasErrors()) {
        try lexer_bag.debug();
        std.process.exit(1);
    }

    var parser_bag = DiagnosticBag.init(arena.allocator(), &source);
    defer parser_bag.deinit();
    
    var parser = Parser.init(arena.allocator(), &source, tokens, &parser_bag);
    var ast = try parser.parse();
    defer ast.deinit();
    
    if (parser_bag.hasErrors()) {
        try parser_bag.debug();
        std.process.exit(1);
    }      

    for (ast.stmts.items) |stmt| {
        std.debug.print("{}\n", .{stmt});
    }

    var checker_bag = DiagnosticBag.init(arena.allocator(), &source);
    defer checker_bag.deinit();
    
    var checker = TypeChecker.init(arena.allocator(), &ast, &checker_bag);
    try checker.check();
    if (checker_bag.hasErrors()) {
        try checker_bag.debug();
        std.process.exit(1);
    }
}
