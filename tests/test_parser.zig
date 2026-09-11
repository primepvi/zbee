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

    try bag.debug();
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

    try bag.debug();
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

test "function decl stmt parsing" {
    const allocator = std.testing.allocator;
    const code =
        \\fn sum(a: int, b:int): void
        \\   echo a + b
        \\end
        \\
        \\fn double(x: int): int -> return x * 2
        \\fn hello(): void -> echo "Hello, World"
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();

    try bag.debug();
    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expect(ast.stmts.items.len == 3);

    const Expected = struct {
        function_name: []const u8,
        params_typings_name: []const []const u8,
        params_name: []const []const u8,
        return_typing_name: []const u8,
        body_kind: StmtKind,
    };

    const expects = [_]Expected{
        .{
            .function_name = "sum",
            .params_typings_name = &.{ "int", "int" },
            .params_name = &.{ "a", "b" },
            .return_typing_name = "void",
            .body_kind = .block_stmt,
        },
        .{
            .function_name = "double",
            .params_typings_name = &.{"int"},
            .params_name = &.{"x"},
            .return_typing_name = "int",
            .body_kind = .return_stmt,
        },
        .{
            .function_name = "hello",
            .params_typings_name = &.{},
            .params_name = &.{},
            .return_typing_name = "void",
            .body_kind = .echo_stmt,
        },
    };

    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i];
        const expected = expects[i];
        try std.testing.expectEqual(.function_decl_stmt, std.meta.activeTag(stmt));
        try std.testing.expectEqualStrings(expected.function_name, stmt.function_decl_stmt.identifier_token.lexeme);
        try std.testing.expectEqual(expected.params_typings_name.len, stmt.function_decl_stmt.params.items.len);

        for (0..expected.params_typings_name.len) |j| {
            const param = stmt.function_decl_stmt.params.items[j];
            try std.testing.expectEqualStrings(expected.params_typings_name[j], param.type_annotation.identifier_token.lexeme);
            try std.testing.expectEqualStrings(expected.params_name[j], param.identifier_token.lexeme);
        }

        try std.testing.expectEqualStrings(expected.return_typing_name, stmt.function_decl_stmt.type_annotation.identifier_token.lexeme);
        try std.testing.expectEqual(expected.body_kind, std.meta.activeTag(stmt.function_decl_stmt.body.*));
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

    try bag.debug();
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

    try bag.debug();
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

    try bag.debug();
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

test "if stmt parsing" {
    const allocator = std.testing.allocator;

    const code =
        \\if a > b then
        \\   echo "a > b"
        \\end
        \\
        \\if a > b -> echo "a > b"
        \\
        \\if a > b then
        \\   echo "a > b"
        \\else
        \\   echo "a <= b"
        \\end
        \\
        \\if a > b -> echo "a > b"
        \\else -> echo "a <= b"
        \\
        \\if a > b then
        \\   echo "a > b"
        \\else if a < b then
        \\   echo "a < b"
        \\else
        \\   echo "a == b"
        \\end
        \\
        \\if a > b -> echo "a > b"
        \\else if a < b -> echo "a < b"
        \\else -> echo "a == b"
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();

    try bag.debug();
    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expectEqual(6, ast.stmts.items.len);

    const Expected = struct {
        consequent_kind: StmtKind,
        has_alternate: bool,
        alternate_kind: ?StmtKind,
        alternate_consequent_kind: ?StmtKind,
        alternate_has_alternate: bool,
        alternate_alternate_kind: ?StmtKind,
    };

    const expects = [_]Expected{
        .{
            .consequent_kind = .block_stmt,
            .has_alternate = false,
            .alternate_kind = null,
            .alternate_consequent_kind = null,
            .alternate_has_alternate = false,
            .alternate_alternate_kind = null,
        },
        .{
            .consequent_kind = .echo_stmt,
            .has_alternate = false,
            .alternate_kind = null,
            .alternate_consequent_kind = null,
            .alternate_has_alternate = false,
            .alternate_alternate_kind = null,
        },
        .{
            .consequent_kind = .block_stmt,
            .has_alternate = true,
            .alternate_kind = .block_stmt,
            .alternate_consequent_kind = null,
            .alternate_has_alternate = false,
            .alternate_alternate_kind = null,
        },
        .{
            .consequent_kind = .echo_stmt,
            .has_alternate = true,
            .alternate_kind = .echo_stmt,
            .alternate_consequent_kind = null,
            .alternate_has_alternate = false,
            .alternate_alternate_kind = null,
        },
        .{
            .consequent_kind = .block_stmt,
            .has_alternate = true,
            .alternate_kind = .if_stmt,
            .alternate_consequent_kind = .block_stmt,
            .alternate_has_alternate = true,
            .alternate_alternate_kind = .block_stmt,
        },
        .{
            .consequent_kind = .echo_stmt,
            .has_alternate = true,
            .alternate_kind = .if_stmt,
            .alternate_consequent_kind = .echo_stmt,
            .alternate_has_alternate = true,
            .alternate_alternate_kind = .echo_stmt,
        },
    };

    for (0..ast.stmts.items.len) |i| {
        const stmt = ast.stmts.items[i].if_stmt;
        const expected = expects[i];
        try std.testing.expectEqual(expected.consequent_kind, std.meta.activeTag(stmt.consequent.*));
        try std.testing.expectEqual(expected.has_alternate, stmt.alternate != null);
        if (!expected.has_alternate) continue;

        const alternate = stmt.alternate.?;
        const alternate_kind = std.meta.activeTag(alternate.*);
        try std.testing.expectEqual(expected.alternate_kind, alternate_kind);
        try std.testing.expectEqual(expected.alternate_has_alternate, alternate_kind == .if_stmt and alternate.if_stmt.alternate != null);

        if (!expected.alternate_has_alternate) continue;
        try std.testing.expectEqual(expected.alternate_consequent_kind, std.meta.activeTag(alternate.if_stmt.consequent.*));
        const alternate_alternate = alternate.if_stmt.alternate.?;
        const alternate_alternate_kind = std.meta.activeTag(alternate_alternate.*);
        try std.testing.expectEqual(expected.alternate_alternate_kind, alternate_alternate_kind);
    }
}

test "block stmt parsing" {
    const allocator = std.testing.allocator;
    const code =
        \\if not false then
        \\   10
        \\   "Hello, World!"
        \\   message
        \\   5 + 5
        \\end
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var ast = try parse(allocator, &source, &bag);
    defer ast.deinit();

    try bag.debug();
    try std.testing.expect(bag.diagnostics.items.len == 0);
    try std.testing.expect(ast.stmts.items.len == 1);

    const stmt = ast.stmts.items[0];
    try std.testing.expectEqual(.if_stmt, std.meta.activeTag(stmt));
    try std.testing.expectEqual(.block_stmt, std.meta.activeTag(stmt.if_stmt.consequent.*));

    const block = stmt.if_stmt.consequent.block_stmt;
    const expr_kinds = [_]ExprKind{
        .literal_expr,    .literal_expr,
        .identifier_expr, .binary_expr,
    };

    try std.testing.expectEqual(expr_kinds.len, block.items.items.len);
    for (0..block.items.items.len) |i| {
        const inner_stmt = block.items.items[i];
        try std.testing.expectEqual(.expr_stmt, std.meta.activeTag(inner_stmt));
        try std.testing.expectEqual(expr_kinds[i], std.meta.activeTag(inner_stmt.expr_stmt.expr));
    }
}
