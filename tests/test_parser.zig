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

test "variable decl stmt parsing" {
    const allocator = std.testing.allocator;
    const code =
        \\let n1 = 10        
        \\let n2: int = 20
        \\let n3: int? = null
        \\const s1 = "John"
        \\const s2: string = "Doe"
        \\const s3: string? = null
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();
    
    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expect(ast.stmts.items.len == 6);

    const Expected = struct {
        keyword_kind: TokenKind,
        identifier_lexeme: []const u8,
        typing_lexeme: ?[]const u8,
        typing_nullable: ?bool,
    };

    const expects = [_]Expected{
        .{ .keyword_kind = .let_keyword, .identifier_lexeme = "n1", .typing_lexeme = null, .typing_nullable = null },
        .{ .keyword_kind = .let_keyword, .identifier_lexeme = "n2", .typing_lexeme = "int", .typing_nullable = false },
        .{ .keyword_kind = .let_keyword, .identifier_lexeme = "n3", .typing_lexeme = "int", .typing_nullable = true },        
        .{ .keyword_kind = .const_keyword, .identifier_lexeme = "s1", .typing_lexeme = null, .typing_nullable = null },
        .{ .keyword_kind = .const_keyword, .identifier_lexeme = "s2", .typing_lexeme = "string", .typing_nullable = false },
        .{ .keyword_kind = .const_keyword, .identifier_lexeme = "s3", .typing_lexeme = "string", .typing_nullable = true },
    };

    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i].variable_decl_stmt;
        const expected = expects[i];
        try std.testing.expectEqual(expected.keyword_kind, stmt.keyword_token.kind);
        try std.testing.expectEqualStrings(expected.identifier_lexeme, stmt.identifier_token.lexeme);
        if (stmt.type_annotation != null) {
            try std.testing.expectEqualStrings(expected.typing_lexeme.?, stmt.type_annotation.?.identifier_token.lexeme);
            try std.testing.expect(stmt.type_annotation.?.nullable == expected.typing_nullable);
        }        
    }
}

test "expr stmt parsing" {
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

    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expect(ast.stmts.items.len == 4);

    const expr_kinds = [_]ExprKind{
        .literal_expr,    .literal_expr,
        .identifier_expr, .binary_expr,
    };

    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i];
        try std.testing.expectEqual(.expr_stmt, std.meta.activeTag(stmt));
        try std.testing.expectEqual(expr_kinds[i], std.meta.activeTag(stmt.expr_stmt.expr));
    }
}

test "echo stmt parsing" {
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

    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expect(ast.stmts.items.len == 4);

    const message_kinds = [_]ExprKind{
        .literal_expr,    .literal_expr,
        .identifier_expr, .binary_expr,
    };

    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i];
        try std.testing.expectEqual(.echo_keyword, stmt.echo_stmt.keyword_token.kind);
        try std.testing.expectEqual(.echo_stmt, std.meta.activeTag(stmt));
        try std.testing.expectEqual(message_kinds[i], std.meta.activeTag(stmt.echo_stmt.message));
    }
}

test "return stmt parsing" {
    const allocator = std.testing.allocator;
    const code =
        \\ return 10
        \\ return "Hello, World!"
        \\ return bee
        \\ return
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();

    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expect(ast.stmts.items.len == 4);

    const r0 = ast.stmts.items[0];
    try std.testing.expectEqual(.return_stmt, std.meta.activeTag(r0));
    try std.testing.expectEqual(.literal_expr, std.meta.activeTag(r0.return_stmt.expr.?));

    const r1 = ast.stmts.items[1];
    try std.testing.expectEqual(.return_stmt, std.meta.activeTag(r1));
    try std.testing.expectEqual(.literal_expr, std.meta.activeTag(r1.return_stmt.expr.?));

    const r2 = ast.stmts.items[2];
    try std.testing.expectEqual(.return_stmt, std.meta.activeTag(r2));
    try std.testing.expectEqual(.identifier_expr, std.meta.activeTag(r2.return_stmt.expr.?));

    const r3 = ast.stmts.items[3];
    try std.testing.expectEqual(.return_stmt, std.meta.activeTag(r3));
    try std.testing.expectEqual(null, r3.return_stmt.expr);
}
