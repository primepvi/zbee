const std = @import("std");

const source_mod = @import("internals/source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("internals/token.zig");
const Token = token_mod.Token;
const TokenKind = token_mod.TokenKind;

const ast_mod = @import("internals/ast.zig");
const AST = ast_mod.AST;
const Stmt = ast_mod.Stmt;
const Expr = ast_mod.Expr;
const TypeAnnotation = ast_mod.TypeAnnotation;
const FunctionDeclParam = ast_mod.FunctionDeclParam;

const Lexer = @import("lexer.zig").Lexer;
const DiagnosticBag = @import("internals/diagnostics.zig").DiagnosticBag;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    source: *const Source,
    tokens: std.ArrayList(Token),
    bag: *DiagnosticBag,
    cursor: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, source: *const Source, tokens: std.ArrayList(Token), bag: *DiagnosticBag) Self {
        return .{
            .allocator = allocator,
            .source = source,
            .tokens = tokens,
            .bag = bag,
            .cursor = 0,
        };
    }

    pub fn parse(self: *Self) anyerror!AST {
        var ast = AST.init(self.allocator, self.source);
        while (self.has_more_tokens()) {
            const stmt = try self.parse_stmt();
            try ast.stmts.append(self.allocator, stmt);
        }

        return ast;
    }

    fn parse_literal_expr(self: *Self) anyerror!Expr {
        const value_token = self.eat();
        return .{
            .literal_expr = .{
                .value_token = value_token,
                .span = value_token.span,
            },
        };
    }

    fn parse_assignment_expr(self: *Self) anyerror!Expr {
        const identifier_token = self.eat();
        const assignment_token = self.eat();
        const value = try self.allocator.create(Expr);
        value.* = try self.parse_expr();
        const span: SourceSpan = .{
            .line = identifier_token.span.line,
            .col = identifier_token.span.col,
            .start = identifier_token.span.start,
            .end = value.get_span().end,
        };

        return .{
            .assignment_expr = .{
                .identifier_token = identifier_token,
                .assignment_token = assignment_token,
                .value = value,
                .span = span,
            },
        };
    }

    fn parse_parenthesized_expr(self: *Self) anyerror!Expr {
        const open_paren_token = self.eat();
        const expr = try self.allocator.create(Expr);
        expr.* = try self.parse_expr();

        var close_paren_token: Token = undefined;
        if (self.peek().kind == .close_paren_symbol) {
            close_paren_token = self.eat();
        } else {
            try self.bag.add_parse_unterminated_parenthesized_expr(open_paren_token.span, expr.*.get_span());
            close_paren_token = .{
                .kind = .invalid,
                .lexeme = ")",
                .span = self.eat().span,
            };
        }

        const span: SourceSpan = .{
            .line = open_paren_token.span.line,
            .col = open_paren_token.span.col,
            .start = open_paren_token.span.start,
            .end = close_paren_token.span.end,
        };

        return .{
            .parenthesized_expr = .{
                .open_paren_token = open_paren_token,
                .close_paren_token = close_paren_token,
                .expr = expr,
                .span = span,
            },
        };
    }

    fn parse_when_expr(self: *Self) anyerror!Expr {
        const when_token = self.eat();
        const condition = try self.allocator.create(Expr);
        condition.* = try self.parse_expr();
        if (self.peek().kind == .then_keyword) {
            _ = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), "then");
        }

        const consequent = try self.allocator.create(Expr);
        consequent.* = try self.parse_expr();

        var otherwise_token: Token = undefined;
        if (self.peek().kind == .otherwise_keyword) {
            otherwise_token = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), "otherwise");
            otherwise_token = .{
                .kind = .invalid,
                .lexeme = "otherwise",
                .span = self.eat().span,
            };
        }

        const alternate = try self.allocator.create(Expr);
        alternate.* = try self.parse_expr();

        const span: SourceSpan = .{
            .line = when_token.span.line,
            .col = when_token.span.col,
            .start = when_token.span.start,
            .end = alternate.get_span().end,
        };

        return .{
            .when_expr = .{
                .when_token = when_token,
                .otherwise_token = otherwise_token,
                .condition = condition,
                .consequent = consequent,
                .alternate = alternate,
                .span = span,
            },
        };
    }

    fn parse_call_expr(self: *Self) anyerror!Expr {
        const identifier_token = self.eat();
        const open_paren_token = self.eat();
        var arguments = std.ArrayList(Expr).empty;
        while (self.has_more_tokens() and self.peek().kind != .close_paren_symbol) {
            const expr = try self.parse_expr();
            try arguments.append(self.allocator, expr);

            if (self.peek().kind == .comma_symbol) {
                _ = self.eat();
            } else {
                break;
            }
        }

        var close_paren_token: Token = undefined;
        if (self.peek().kind == .close_paren_symbol) {
            close_paren_token = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), ")");
            close_paren_token = .{
                .kind = .invalid,
                .lexeme = ")",
                .span = self.eat().span,
            };
        }

        const span: SourceSpan = .{
            .line = identifier_token.span.line,
            .col = identifier_token.span.col,
            .start = identifier_token.span.start,
            .end = close_paren_token.span.end,
        };

        return .{
            .call_expr = .{
                .identifier_token = identifier_token,
                .open_paren_token = open_paren_token,
                .close_paren_token = close_paren_token,
                .arguments = arguments,
                .span = span,
            },
        };
    }

    fn parse_identifier_expr(self: *Self) anyerror!Expr {
        const identifier_token = self.eat();
        return .{
            .identifier_expr = .{
                .identifier_token = identifier_token,
                .span = identifier_token.span,
            },
        };
    }

    fn parse_primary_expr(self: *Self) anyerror!Expr {
        return switch (self.peek().kind) {
            .null_keyword, .true_keyword, .false_keyword, .number_literal, .string_literal => try self.parse_literal_expr(),

            .open_paren_symbol => try self.parse_parenthesized_expr(),

            .identifier => {
                if (self.lookahead().kind == .equal_symbol) {
                    return try self.parse_assignment_expr();
                } else if (self.lookahead().kind == .open_paren_symbol) {
                    return try self.parse_call_expr();
                } else {
                    return try self.parse_identifier_expr();
                }
            },

            .when_keyword => try self.parse_when_expr(),
            .eof => {
                try self.bag.add_parse_unexpected_end_of_file(self.peek());
                return .{
                    .invalid_expr = self.peek(),
                };
            },
            else => {
                const invalid_token = self.eat();
                var range = invalid_token.span;
                while (self.has_more_tokens() and !self.can_start_expr()) {
                    range.end = self.eat().span.end;
                }

                try self.bag.add_parse_invalid_expr(invalid_token.span, range);
                return try self.parse_expr();
            },
        };
    }

    fn parse_binary_expr(self: *Self, priority: usize) anyerror!Expr {
        const unary_op_priority = TokenKind.get_unary_operator_priority(self.peek().kind);
        var left = try self.allocator.create(Expr);
        if (unary_op_priority != 0 and unary_op_priority >= priority) {
            const operator_token = self.eat();
            const operand = try self.allocator.create(Expr);
            operand.* = try self.parse_binary_expr(unary_op_priority);

            const span: SourceSpan = .{
                .line = operator_token.span.line,
                .col = operator_token.span.col,
                .start = operator_token.span.start,
                .end = operand.get_span().end,
            };

            left.* = .{
                .unary_expr = .{
                    .operator_token = operator_token,
                    .operand = operand,
                    .span = span,
                },
            };
        } else {
            left.* = try self.parse_primary_expr();
        }

        while (true) {
            const op_priority = TokenKind.get_binary_operator_priority(self.peek().kind);
            if (op_priority == 0 or op_priority <= priority)
                break;

            const operator_token = self.eat();
            const right = try self.allocator.create(Expr);
            right.* = try self.parse_binary_expr(op_priority);

            const span: SourceSpan = .{
                .line = left.get_span().line,
                .col = left.get_span().col,
                .start = left.get_span().start,
                .end = right.get_span().end,
            };

            left.* = .{
                .binary_expr = .{
                    .left = left,
                    .right = right,
                    .operator_token = operator_token,
                    .span = span,
                },
            };
        }

        return left.*;
    }

    fn parse_expr(self: *Self) anyerror!Expr {
        return try self.parse_binary_expr(0);
    }

    fn parse_type_annotation(self: *Self) !TypeAnnotation {
        const colon_token = self.eat();
        var identifier_token: Token = undefined;
        if (self.peek().kind == .identifier) {
            identifier_token = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), "type name");
            identifier_token = .{
                .kind = .invalid,
                .lexeme = "invalid",
                .span = self.eat().span,
            };
        }

        var nullable = false;
        if (self.peek().kind == .question_symbol) {
            _ = self.eat();
            nullable = true;
        }

        const span: SourceSpan = .{ .line = colon_token.span.line, .col = colon_token.span.col, .start = colon_token.span.start, .end = if (nullable) identifier_token.span.end + 1 else identifier_token.span.end };

        return .{
            .colon_token = colon_token,
            .identifier_token = identifier_token,
            .nullable = nullable,
            .span = span,
        };
    }

    fn parse_block_stmt(self: *Self, end_kinds: []const TokenKind) anyerror!Stmt {
        const start_span = self.peek().span;
        var end_span = start_span;
        var items = std.ArrayList(Stmt).empty;
        while (self.has_more_tokens() and std.mem.indexOfScalar(TokenKind, end_kinds, self.peek().kind) == null) {
            const stmt = try self.parse_stmt();
            end_span = stmt.get_span();
            try items.append(self.allocator, stmt);
        }

        if (std.mem.indexOfScalar(TokenKind, end_kinds, self.peek().kind) == null) {
            try self.bag.add_parse_unterminated_block_stmt(start_span, end_span);
        }

        const span: SourceSpan = .{
            .line = start_span.line,
            .col = start_span.col,
            .start = start_span.start,
            .end = self.peek().span.end,
        };

        return .{
            .block_stmt = .{
                .items = items,
                .span = span,
            },
        };
    }

    fn parse_function_decl_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        var identifier_token: Token = undefined;
        if (self.peek().kind == .identifier) {
            identifier_token = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), "function name");
            identifier_token = .{
                .kind = .invalid,
                .lexeme = "invalid",
                .span = self.eat().span,
            };
        }

        if (self.peek().kind == .open_paren_symbol) {
            _ = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.eat(), "(");
        }

        var params = std.ArrayList(FunctionDeclParam).empty;
        while (self.has_more_tokens() and self.peek().kind != .close_paren_symbol) {
            var param_identifier_token: Token = undefined;
            if (self.peek().kind == .identifier) {
                param_identifier_token = self.eat();
            } else {
                try self.bag.add_parse_unexpected_token(self.peek(), "param name");
                param_identifier_token = .{
                    .kind = .invalid,
                    .lexeme = "invalid",
                    .span = self.eat().span,
                };
            }

            const type_annotation = try self.parse_type_annotation();
            const span: SourceSpan = .{ .line = identifier_token.span.line, .col = identifier_token.span.col, .start = identifier_token.span.start, .end = type_annotation.span.end };

            const param: FunctionDeclParam = .{ .identifier_token = param_identifier_token, .type_annotation = type_annotation, .span = span };

            try params.append(self.allocator, param);
            if (self.peek().kind == .comma_symbol) {
                _ = self.eat();
            } else {
                break;
            }
        }

        if (self.peek().kind == .close_paren_symbol) {
            _ = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.eat(), ")");
        }

        const type_annotation = try self.parse_type_annotation();
        const body = try self.allocator.create(Stmt);
        if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            body.* = try self.parse_stmt();
        } else {
            const end_kinds = [_]TokenKind{.end_keyword};
            body.* = try self.parse_block_stmt(end_kinds[0..1]);
        }

        if (std.meta.activeTag(body.*) == .block_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = body.get_span().end,
        };

        return .{
            .function_decl_stmt = .{
                .keyword_token = keyword_token,
                .identifier_token = identifier_token,
                .type_annotation = type_annotation,
                .params = params,
                .body = body,
                .span = span,
            },
        };
    }

    fn parse_echo_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const message = try self.parse_expr();
        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = message.get_span().end,
        };

        return .{
            .echo_stmt = .{ .keyword_token = keyword_token, .message = message, .span = span },
        };
    }

    fn parse_if_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const condition = try self.parse_expr();
        const consequent = try self.allocator.create(Stmt);
        if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            consequent.* = try self.parse_stmt();
        } else if (self.peek().kind == .then_keyword) {
            _ = self.eat();
            const end_kinds = [_]TokenKind{ .end_keyword, .else_keyword };
            consequent.* = try self.parse_block_stmt(end_kinds[0..2]);
        } else {
            // TODO: add invalid if body diagnostic.
        }

        var alternate: ?*Stmt = null;
        if (self.peek().kind == .else_keyword) {
            alternate = try self.allocator.create(Stmt);
            _ = self.eat();

            if (self.peek().kind == .if_keyword) {
                alternate.?.* = try self.parse_if_stmt();
            } else if (self.peek().kind == .arrow_symbol) {
                _ = self.eat();
                alternate.?.* = try self.parse_stmt();
            } else {
                const end_kinds = [_]TokenKind{.end_keyword};
                alternate.?.* = try self.parse_block_stmt(end_kinds[0..1]);
            }
        }

        if (std.meta.activeTag(consequent.*) == .block_stmt and alternate != null or std.meta.activeTag(alternate.?.*) == .if_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = if (alternate != null) alternate.?.get_span().end else consequent.get_span().end,
        };

        return .{
            .if_stmt = .{
                .keyword_token = keyword_token,
                .condition = condition,
                .consequent = consequent,
                .alternate = alternate,
                .span = span,
            },
        };
    }

    fn parse_while_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const condition = try self.parse_expr();
        const body = try self.allocator.create(Stmt);
        if (self.peek().kind == .do_keyword) {
            _ = self.eat();
            const end_kinds = [_]TokenKind{.end_keyword};
            body.* = try self.parse_block_stmt(end_kinds[0..1]);
        } else if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            body.* = try self.parse_stmt();
        } else {
            // TODO: add invalid while body diagnostic.
        }

        if (std.meta.activeTag(body.*) == .block_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = body.get_span().end,
        };

        return .{
            .while_stmt = .{
                .keyword_token = keyword_token,
                .body = body,
                .condition = condition,
                .span = span,
            },
        };
    }

    fn parse_for_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const init_stmt = try self.allocator.create(Stmt);
        init_stmt.* = try self.parse_stmt();

        if (std.meta.activeTag(init_stmt.*) != .variable_decl_stmt) {
            // TODO: add invalid for init stmt diagnostic.
        }

        if (self.peek().kind == .comma_symbol) {
            _ = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.eat(), ",");
        }

        const condition = try self.parse_expr();
        if (self.peek().kind == .comma_symbol) {
            _ = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.eat(), ",");
        }

        const update = try self.parse_expr();
        const body = try self.allocator.create(Stmt);
        if (self.peek().kind == .do_keyword) {
            _ = self.eat();
            const end_kinds = [_]TokenKind{.end_keyword};
            body.* = try self.parse_block_stmt(end_kinds[0..1]);
        } else if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            body.* = try self.parse_stmt();
        } else {
            // TODO: add invalid for body diagnostic.
        }

        if (std.meta.activeTag(body.*) == .block_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = body.get_span().end,
        };

        return .{
            .for_stmt = .{
                .keyword_token = keyword_token,
                .init = init_stmt,
                .condition = condition,
                .update = update,
                .body = body,
                .span = span,
            },
        };
    }

    fn parse_return_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const expr: ?Expr = if (self.can_start_expr()) try self.parse_expr() else null;
        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = if (expr == null) keyword_token.span.end else expr.?.get_span().end,
        };

        return .{
            .return_stmt = .{
                .keyword_token = keyword_token,
                .expr = expr,
                .span = span,
            },
        };
    }

    fn parse_expr_stmt(self: *Self) anyerror!Stmt {
        const expr = try self.parse_expr();
        return .{
            .expr_stmt = .{ .expr = expr, .span = expr.get_span() },
        };
    }

    fn parse_variable_decl_stmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        var identifier_token: Token = undefined;
        if (self.peek().kind == .identifier) {
            identifier_token = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), "variable name");
            identifier_token = .{
                .kind = .invalid,
                .lexeme = "invalid",
                .span = self.eat().span,
            };
        }
        
        var type_annotation: ?TypeAnnotation = null;
        if (self.peek().kind == .colon_symbol) {
            type_annotation = try self.parse_type_annotation();
        }

        var assignment_token: Token = undefined;
        if (self.peek().kind == .equal_symbol) {
            assignment_token = self.eat();
        } else {
            try self.bag.add_parse_unexpected_token(self.peek(), "=");
            assignment_token = .{
                .kind = .invalid,
                .lexeme = "=",
                .span = self.eat().span,
            };
        }

        const value = try self.parse_expr();
        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.col,
            .end = value.get_span().end,
        };

        return .{
            .variable_decl_stmt = .{ .keyword_token = keyword_token, .identifier_token = identifier_token, .assignment_token = assignment_token, .type_annotation = type_annotation, .value = value, .span = span },
        };
    }

    fn parse_stmt(self: *Self) anyerror!Stmt {
        const current = self.peek();
        return switch (current.kind) {
            .const_keyword, .let_keyword => try self.parse_variable_decl_stmt(),
            .fn_keyword => try self.parse_function_decl_stmt(),
            .echo_keyword => try self.parse_echo_stmt(),
            .if_keyword => try self.parse_if_stmt(),
            .while_keyword => try self.parse_while_stmt(),
            .for_keyword => try self.parse_for_stmt(),
            .return_keyword => try self.parse_return_stmt(),
            else => try self.parse_expr_stmt(),
        };
    }

    fn peek(self: *const Self) Token {
        return self.tokens.items[self.cursor];
    }

    fn lookahead(self: *const Self) Token {
        return self.tokens.items[self.cursor + 1];
    }

    fn eat(self: *Self) Token {
        const token = self.tokens.items[self.cursor];
        self.cursor += 1;

        return token;
    }

    fn has_more_tokens(self: *const Self) bool {
        return self.tokens.items.len > self.cursor and self.peek().kind != .eof;
    }

    fn can_start_expr(self: *const Self) bool {
        return switch (self.peek().kind) {
            .null_keyword, .true_keyword, .false_keyword, .number_literal, .string_literal, .open_paren_symbol, .identifier, .when_keyword => true,
            else => false,
        };
    }
};
