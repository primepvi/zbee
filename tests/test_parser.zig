const std = @import("std");
const bee = @import("zbee");

const Source = bee.source.Source;
const DiagnosticBag = bee.diagnostics.DiagnosticBag;

const Lexer = bee.lexer.Lexer;
const Parser = bee.parser.Parser;
const Token = bee.token.Token;
const TokenKind = bee.token.TokenKind;

const AST = bee.ast.AST;
const StmtKind = bee.ast.StmtKind;
const ExprKind = bee.ast.ExprKind;

fn parse(allocator: std.mem.Allocator, source: *const Source, bag: *DiagnosticBag) !AST {
    var tokens = std.ArrayList(Token).empty;
    defer tokens.deinit(allocator);
    
    var lexer = Lexer.init(source, bag);
    var current: Token = undefined;
    while (current.kind != .eof) {
        current = try lexer.nextToken();
        try tokens.append(allocator, current);
    }

    try std.testing.expectEqual(0, bag.diagnostics.items.len);
    var parser = Parser.init(allocator, source, tokens, bag);    
    return try parser.parse();
}


test "parse expr stmt" {
    const allocator = std.testing.allocator;
    const code =
        \\10
        \\"Hello, World!"
        \\message
        \\5 + 5
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);
    
    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();
    
    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();
    
    try std.testing.expectEqual(0, bag.diagnostics.items.len);
    try std.testing.expectEqual(4, ast.stmts.items.len);

    const expr_kinds = [_]ExprKind{
        .literal_expr, .literal_expr,
        .identifier_expr, .binary_expr,
    };
    
    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i];        
        try std.testing.expectEqual(.expr_stmt, std.meta.activeTag(stmt));
        try std.testing.expectEqual(expr_kinds[i], std.meta.activeTag(stmt.expr_stmt.expr));
    }
}

test "parse echo stmt" {
    const allocator = std.testing.allocator;
    const code =
        \\echo 10
        \\echo "Hello, World!"
        \\echo message
        \\echo 5 + 5
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);
    
    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();
    
    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();
    
    try std.testing.expectEqual(0, bag.diagnostics.items.len);
    try std.testing.expectEqual(4, ast.stmts.items.len);

    const message_kinds = [_]ExprKind{
        .literal_expr, .literal_expr,
        .identifier_expr, .binary_expr,
    };
    
    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i];
        try std.testing.expectEqual(.echo_keyword, stmt.echo_stmt.keyword_token.kind);
        try std.testing.expectEqual(.echo_stmt, std.meta.activeTag(stmt));
        try std.testing.expectEqual(message_kinds[i], std.meta.activeTag(stmt.echo_stmt.message));
    }
}
