const std = @import("std");
const bee = @import("zbee");

const Lexer = bee.lexer.Lexer;
const Source = bee.source.Source;
const DiagnosticBag = bee.diagnostics.DiagnosticBag;
const TokenKind = bee.token.TokenKind;

test "keyword tokens and identifier tokens lexing" {
    const allocator = std.testing.allocator;
    const code =
        \\let const fn return
        \\echo
        \\true false null
        \\and or not 
        \\if else then when otherwise
        \\while for do end
        \\bee zig c
    ;

    const expected_kinds = [_]TokenKind{
        .let_keyword,
        .const_keyword,
        .fn_keyword,
        .return_keyword,
        .echo_keyword,
        .true_keyword,
        .false_keyword,
        .null_keyword,
        .and_keyword,
        .or_keyword,
        .not_keyword,
        .if_keyword,
        .else_keyword,
        .then_keyword,
        .when_keyword,
        .otherwise_keyword,
        .while_keyword,
        .for_keyword,
        .do_keyword,
        .end_keyword,
        .identifier,
        .identifier,
        .identifier,
    };

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var lexer = Lexer.init(&source, &bag);
    for (expected_kinds) |expected_kind| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(expected_kind, token.kind);
        try std.testing.expectEqual(expected_kind, TokenKind.getKeywordKind(token.lexeme));
    }
}

test "literals tokens lexing" {
    const allocator = std.testing.allocator;
    const code =
        \\10 20 30 40 50
        \\"hello" "world" "bee" "zig" "c"
    ;

    const expected_kinds = [_]TokenKind{
        .number_literal,
        .number_literal,
        .number_literal,
        .number_literal,
        .number_literal,
        .string_literal,
        .string_literal,
        .string_literal,
        .string_literal,
        .string_literal,
    };

    const expected_lexemes = [_][]const u8{
        "10",    "20",    "30",  "40",  "50",
        "hello", "world", "bee", "zig", "c",
    };

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var lexer = Lexer.init(&source, &bag);
    for (0..expected_kinds.len) |i| {
        const token = try lexer.nextToken();
        const expected_kind = expected_kinds[i];
        const expected_lexeme = expected_lexemes[i];
        try std.testing.expectEqual(expected_kind, token.kind);
        try std.testing.expectEqualStrings(expected_lexeme, token.lexeme);
    }
}

test "symbol tokens lexing" {
    const allocator = std.testing.allocator;
    const code =
        \\: ; ? = ( )
        \\> >= < <=
        \\== != -> ,
        \\+ - * / %
    ;

    const expected_kinds = [_]TokenKind{
        .colon_symbol,
        .semicolon_symbol,
        .question_symbol,
        .equal_symbol,
        .open_paren_symbol,
        .close_paren_symbol,
        .gt_symbol,
        .gte_symbol,
        .lt_symbol,
        .lte_symbol,
        .eqeq_symbol,
        .neq_symbol,
        .arrow_symbol,
        .comma_symbol,
        .plus_symbol,
        .minus_symbol,
        .star_symbol,
        .slash_symbol,
        .percentage_symbol,
    };

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var lexer = Lexer.init(&source, &bag);
    for (expected_kinds) |expected_kind| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(expected_kind, token.kind);
        try std.testing.expectEqual(expected_kind, TokenKind.getSymbolKind(token.lexeme));
    }
}

test "unterminated string lexing error" {
    const allocator = std.testing.allocator;
    const code =
        \\"Hello, World!
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var lexer = Lexer.init(&source, &bag);
    const invalid_token = try lexer.nextToken();

    try std.testing.expectEqual(invalid_token.kind, .string_literal);
    try std.testing.expectEqualStrings(invalid_token.lexeme, "Hello, World!");

    try std.testing.expect(bag.diagnostics.items.len == 1);
    
    const diagnostic = bag.diagnostics.items[0];
    try std.testing.expectEqual(diagnostic.level, .err);
    try std.testing.expectEqual(diagnostic.code, 101);
}

test "unexpected symbol lexing error" {
    const allocator = std.testing.allocator;
    const code =
        \\$
    ;

    var source = try Source.init(allocator, "test.bee", code);
    defer source.deinit(allocator);

    var bag = DiagnosticBag.init(allocator, &source);
    defer bag.deinit();

    var lexer = Lexer.init(&source, &bag);
    const invalid_token = try lexer.nextToken();

    try std.testing.expectEqual(invalid_token.kind, .invalid);
    try std.testing.expectEqualStrings(invalid_token.lexeme, "$");

    try std.testing.expect(bag.diagnostics.items.len == 1);
    
    const diagnostic = bag.diagnostics.items[0];
    try std.testing.expectEqual(diagnostic.level, .err);
    try std.testing.expectEqual(diagnostic.code, 100);
    allocator.free(diagnostic.message);
}
