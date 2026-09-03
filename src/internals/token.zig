const std = @import("std");
const SourceSpan = @import("source.zig").SourceSpan;

pub const TokenKind = enum {
    // keywords
    let_keyword,
    const_keyword,
    echo_keyword,
    true_keyword,
    false_keyword,
    null_keyword,
    and_keyword,
    or_keyword,
    not_keyword,
    then_keyword,
    end_keyword,
    if_keyword,
    else_keyword,
    while_keyword,
    for_keyword,
    do_keyword,
    when_keyword,
    otherwise_keyword,
    fn_keyword,
    return_keyword,
    identifier,

    // literals
    number_literal,
    string_literal,

    // symbols
    colon_symbol,
    semicolon_symbol,
    question_symbol,
    equal_symbol,
    open_paren_symbol,
    close_paren_symbol,
    gt_symbol,
    gte_symbol,
    lt_symbol,
    lte_symbol,
    eqeq_symbol,
    neq_symbol,
    arrow_symbol,
    comma_symbol,
    plus_symbol,
    minus_symbol,
    star_symbol,
    slash_symbol,
    percentage_symbol,

    // specials
    invalid,
    eof,

    const keywords_map = std.StaticStringMap(TokenKind).initComptime(.{
        .{ "let", .let_keyword },
        .{ "const", .const_keyword },
        .{ "echo", .echo_keyword },
        .{ "true", .true_keyword },
        .{ "false", .false_keyword },
        .{ "null", .null_keyword },
        .{ "and", .and_keyword },
        .{ "or", .or_keyword },
        .{ "not", .not_keyword },
        .{ "then", .then_keyword },
        .{ "end", .end_keyword },
        .{ "if", .if_keyword },
        .{ "else", .else_keyword },
        .{ "while", .while_keyword },
        .{ "for", .for_keyword },
        .{ "do", .do_keyword },
        .{ "when", .when_keyword },
        .{ "otherwise", .otherwise_keyword },
        .{ "fn", .fn_keyword },
        .{ "return", .return_keyword },
    });

    const symbols_kind = std.StaticStringMap(TokenKind).initComptime(.{
        .{ ":", .colon_symbol },
        .{ ";", .semicolon_symbol },
        .{ "?", .question_symbol },
        .{ "=", .equal_symbol },
        .{ "(", .open_paren_symbol },
        .{ ")", .close_paren_symbol },
        .{ ">", .gt_symbol },
        .{ ">=", .gte_symbol },
        .{ "<", .lt_symbol },
        .{ "<=", .lte_symbol },
        .{ "==", .eqeq_symbol },
        .{ "!=", .neq_symbol },
        .{ "->", .arrow_symbol },
        .{ ",", .comma_symbol },
        .{ "+", .plus_symbol },
        .{ "-", .minus_symbol },
        .{ "*", .star_symbol },
        .{ "/", .slash_symbol },
        .{ "%", .percentage_symbol },
    });

    const Self = @This();

    pub fn get_keyword_kind(keyword: []const u8) TokenKind {
        return keywords_map.get(keyword) orelse .identifier;
    }

    pub fn get_symbol_kind(symbol: []const u8) TokenKind {
        return symbols_kind.get(symbol) orelse .invalid;
    }

    pub fn get_kind_name(self: Self) []const u8 {
        return @tagName(self);
    }
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    span: SourceSpan,
};
