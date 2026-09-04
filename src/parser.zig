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
    panic: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, source: *const Source, tokens: std.ArrayList(Token), bag: *DiagnosticBag) Self {
        return .{
            .allocator = allocator,
            .source = source,
            .tokens = tokens,
            .bag = bag,
            .cursor = 0,
            .panic = false,
        };
    }

    fn expectToken(self: *Self, kind: TokenKind, name: []const u8) !Token {
        if (self.peek().kind == kind) {
            return self.eat();
        }

        if (!self.panic) {
            try self.bag.errorParserUnexpectedToken(self.peek(), name);
            self.panic = true;
        }

        const current_span = self.peek().span;
        const span: SourceSpan = .{
            .line = current_span.line,
            .col = current_span.col - 1,
            .start = current_span.start - 1,
            .end = current_span.start - 1,
        };

        return .{
            .kind = .invalid,
            .lexeme = name,
            .span = span,
        };
    }

    pub fn parse(self: *Self) anyerror!AST {
        var ast = AST.init(self.allocator, self.source);
        while (self.hasMoreTokens()) {
            const stmt = try self.parseStmt();
            try ast.stmts.append(self.allocator, stmt);
        }

        return ast;
    }

    fn parseLiteralExpr(self: *Self) anyerror!Expr {
        const value_token = self.eat();
        return .{
            .literal_expr = .{
                .value_token = value_token,
                .span = value_token.span,
            },
        };
    }

    fn parseAssignmentExpr(self: *Self) anyerror!Expr {
        const identifier_token = self.eat();
        const assignment_token = self.eat();
        const value = try self.allocator.create(Expr);
        value.* = try self.parseExpr();

        const span: SourceSpan = .{
            .line = identifier_token.span.line,
            .col = identifier_token.span.col,
            .start = identifier_token.span.start,
            .end = value.getSourceSpan().end,
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

    fn parseParenthesizedExpr(self: *Self) anyerror!Expr {
        const open_paren_token = self.eat();
        const expr = try self.allocator.create(Expr);
        expr.* = try self.parseExpr();

        const close_paren_token = try self.expectToken(.close_paren_symbol, ")");
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

    fn parseWhenExpr(self: *Self) anyerror!Expr {
        const when_token = self.eat();
        const condition = try self.allocator.create(Expr);
        condition.* = try self.parseExpr();
        _ = try self.expectToken(.then_keyword, "then");

        const consequent = try self.allocator.create(Expr);
        consequent.* = try self.parseExpr();

        const otherwise_token = try self.expectToken(.otherwise_keyword, "otherwise");
        const alternate = try self.allocator.create(Expr);
        alternate.* = try self.parseExpr();

        const span: SourceSpan = .{
            .line = when_token.span.line,
            .col = when_token.span.col,
            .start = when_token.span.start,
            .end = alternate.getSourceSpan().end,
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

    fn parseCallExpr(self: *Self) anyerror!Expr {
        const identifier_token = self.eat();
        const open_paren_token = self.eat();

        var arguments = std.ArrayList(Expr).empty;
        var close_paren_token: Token = undefined;
        while (self.hasMoreTokens() and self.peek().kind != .close_paren_symbol) {
            const expr = try self.parseExpr();
            try arguments.append(self.allocator, expr);

            if (self.peek().kind == .comma_symbol) {
                _ = self.eat();
            } else {
                close_paren_token = try self.expectToken(.close_paren_symbol, ")");
                break;
            }
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

    fn parseIdentifierExpr(self: *Self) anyerror!Expr {
        const identifier_token = self.eat();
        return .{
            .identifier_expr = .{
                .identifier_token = identifier_token,
                .span = identifier_token.span,
            },
        };
    }

    fn parsePrimaryExpr(self: *Self) anyerror!Expr {
        return switch (self.peek().kind) {
            .null_keyword, .true_keyword, .false_keyword, .number_literal, .string_literal => try self.parseLiteralExpr(),

            .open_paren_symbol => try self.parseParenthesizedExpr(),

            .identifier => {
                if (self.lookahead().kind == .equal_symbol) {
                    return try self.parseAssignmentExpr();
                } else if (self.lookahead().kind == .open_paren_symbol) {
                    return try self.parseCallExpr();
                } else {
                    return try self.parseIdentifierExpr();
                }
            },

            .when_keyword => try self.parseWhenExpr(),
            else => blk: {
                if (!self.panic) {
                    try self.bag.errorParserInvalidExpr(self.peek());
                    self.panic = true;
                }

                if (self.peek().kind == .eof) {
                    break :blk .{
                        .invalid_expr = self.peek(),
                    };
                }

                break :blk .{ .invalid_expr = self.eat() };
            },
        };
    }

    fn parseBinaryExpr(self: *Self, priority: usize) anyerror!Expr {
        const unary_op_priority = TokenKind.getUnaryOperatorPriority(self.peek().kind);

        var left = try self.allocator.create(Expr);
        if (unary_op_priority != 0 and unary_op_priority >= priority) {
            const operator_token = self.eat();
            const operand = try self.allocator.create(Expr);
            operand.* = try self.parseBinaryExpr(unary_op_priority);

            const span: SourceSpan = .{
                .line = operator_token.span.line,
                .col = operator_token.span.col,
                .start = operator_token.span.start,
                .end = operand.getSourceSpan().end,
            };

            left.* = .{
                .unary_expr = .{
                    .operator_token = operator_token,
                    .operand = operand,
                    .span = span,
                },
            };
        } else {
            left.* = try self.parsePrimaryExpr();
        }

        while (true) {
            const op_priority = TokenKind.getBinaryOperatorPriority(self.peek().kind);
            if (op_priority == 0 or op_priority <= priority)
                break;

            const operator_token = self.eat();
            const right = try self.allocator.create(Expr);
            right.* = try self.parseBinaryExpr(op_priority);

            const span: SourceSpan = .{
                .line = left.getSourceSpan().line,
                .col = left.getSourceSpan().col,
                .start = left.getSourceSpan().start,
                .end = right.getSourceSpan().end,
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

    fn parseExpr(self: *Self) anyerror!Expr {
        return try self.parseBinaryExpr(0);
    }

    fn parseTypeAnnotation(self: *Self) !TypeAnnotation {
        const colon_token = self.eat();
        const identifier_token = try self.expectToken(.identifier, "type name");
        var nullable = false;
        if (self.peek().kind == .question_symbol) {
            _ = self.eat();
            nullable = true;
        }

        const span: SourceSpan = .{
            .line = colon_token.span.line,
            .col = colon_token.span.col,
            .start = colon_token.span.start,
            .end = if (nullable) identifier_token.span.end + 1 else identifier_token.span.end,
        };

        return .{
            .colon_token = colon_token,
            .identifier_token = identifier_token,
            .nullable = nullable,
            .span = span,
        };
    }

    fn parseBlockStmt(self: *Self, end_kinds: []const TokenKind) anyerror!Stmt {
        const start_span = self.peek().span;
        var end_span = start_span;
        var items = std.ArrayList(Stmt).empty;
        while (self.hasMoreTokens() and std.mem.indexOfScalar(TokenKind, end_kinds, self.peek().kind) == null) {
            const stmt = try self.parseStmt();
            end_span = stmt.getSourceSpan();
            try items.append(self.allocator, stmt);
        }

        if (std.mem.indexOfScalar(TokenKind, end_kinds, self.peek().kind) == null) {
            try self.bag.errorParserUnterminatedBlockStmt(start_span, end_span);
            self.panic = true;
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

    fn parseFunctionDeclStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const identifier_token = try self.expectToken(.identifier, "function name");
        _ = try self.expectToken(.close_paren_symbol, ")");

        var params = std.ArrayList(FunctionDeclParam).empty;
        while (self.hasMoreTokens() and self.peek().kind != .close_paren_symbol) {
            const param_identifier_token = try self.expectToken(.identifier, "param name");
            const type_annotation = try self.parseTypeAnnotation();

            const span: SourceSpan = .{
                .line = identifier_token.span.line,
                .col = identifier_token.span.col,
                .start = identifier_token.span.start,
                .end = type_annotation.span.end,
            };

            const param: FunctionDeclParam = .{
                .identifier_token = param_identifier_token,
                .type_annotation = type_annotation,
                .span = span,
            };

            try params.append(self.allocator, param);
            if (self.peek().kind == .comma_symbol) {
                _ = self.eat();
            } else {
                _ = try self.expectToken(.close_paren_symbol, ")");
                break;
            }
        }

        const type_annotation = try self.parseTypeAnnotation();
        const body = try self.allocator.create(Stmt);
        if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            body.* = try self.parseStmt();
        } else {
            const end_kinds = [_]TokenKind{.end_keyword};
            body.* = try self.parseBlockStmt(end_kinds[0..1]);
        }

        if (std.meta.activeTag(body.*) == .block_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = body.getSourceSpan().end,
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

    fn parseEchoStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const message = try self.parseExpr();
        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = message.getSourceSpan().end,
        };

        return .{
            .echo_stmt = .{
                .keyword_token = keyword_token,
                .message = message,
                .span = span,
            },
        };
    }

    fn parseIfStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const condition = try self.parseExpr();
        const consequent = try self.allocator.create(Stmt);

        if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            consequent.* = try self.parseStmt();
        } else if (self.peek().kind == .then_keyword) {
            _ = self.eat();
            const end_kinds = [_]TokenKind{ .end_keyword, .else_keyword };
            consequent.* = try self.parseBlockStmt(end_kinds[0..2]);
        } else {
            consequent.* = .{
                .invalid_stmt = self.peek(),
            };

            try self.bag.errorParserInvalidIfStmtBody(keyword_token, self.peek());
            self.panic = true;
        }

        var alternate: ?*Stmt = null;
        if (self.peek().kind == .else_keyword) {
            alternate = try self.allocator.create(Stmt);
            _ = self.eat();

            if (self.peek().kind == .if_keyword) {
                alternate.?.* = try self.parseIfStmt();
            } else if (self.peek().kind == .arrow_symbol) {
                _ = self.eat();
                alternate.?.* = try self.parseStmt();
            } else {
                const end_kinds = [_]TokenKind{.end_keyword};
                alternate.?.* = try self.parseBlockStmt(end_kinds[0..1]);
            }
        }

        const is_consequent_block = std.meta.activeTag(consequent.*) == .block_stmt;
        const is_alternate_valid = if (alternate) |alt|
            std.meta.activeTag(alt.*) == .if_stmt
        else
            false;

        if (is_consequent_block and (alternate != null or is_alternate_valid)) {
            _ = self.eat();
        }

        const end_span = if (alternate) |alt|
            alt.getSourceSpan()
        else
            consequent.getSourceSpan();

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = end_span.end,
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

    fn parseWhileStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const condition = try self.parseExpr();
        const body = try self.allocator.create(Stmt);

        if (self.peek().kind == .do_keyword) {
            _ = self.eat();
            const end_kinds = [_]TokenKind{.end_keyword};
            body.* = try self.parseBlockStmt(end_kinds[0..1]);
        } else if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            body.* = try self.parseStmt();
        } else {
            body.* = .{
                .invalid_stmt = self.peek(),
            };

            try self.bag.errorParserInvalidWhileStmtBody(keyword_token, self.peek());
            self.panic = true;
        }

        if (std.meta.activeTag(body.*) == .block_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = body.getSourceSpan().end,
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

    fn parseForStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const init_stmt = try self.allocator.create(Stmt);
        init_stmt.* = try self.parseStmt();

        if (std.meta.activeTag(init_stmt.*) != .variable_decl_stmt) {
            try self.bag.errorParserInvalidForInitStmt(init_stmt.getSourceSpan());
            self.panic = true;
        }

        _ = try self.expectToken(.comma_symbol, ",");

        const condition = try self.parseExpr();
        _ = try self.expectToken(.comma_symbol, ",");

        const update = try self.parseExpr();
        const body = try self.allocator.create(Stmt);
        if (self.peek().kind == .do_keyword) {
            _ = self.eat();
            const end_kinds = [_]TokenKind{.end_keyword};
            body.* = try self.parseBlockStmt(end_kinds[0..1]);
        } else if (self.peek().kind == .arrow_symbol) {
            _ = self.eat();
            body.* = try self.parseStmt();
        } else {
            body.* = .{
                .invalid_stmt = self.peek(),
            };

            try self.bag.errorParserInvalidForStmtBody(keyword_token, self.peek());
            self.panic = true;
        }

        if (std.meta.activeTag(body.*) == .block_stmt) {
            _ = self.eat();
        }

        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = body.getSourceSpan().end,
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

    fn parseReturnStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const expr: ?Expr = if (self.canStartExpr()) try self.parseExpr() else null;
        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.start,
            .end = if (expr == null) keyword_token.span.end else expr.?.getSourceSpan().end,
        };

        return .{
            .return_stmt = .{
                .keyword_token = keyword_token,
                .expr = expr,
                .span = span,
            },
        };
    }

    fn parseExprStmt(self: *Self) anyerror!Stmt {
        const expr = try self.parseExpr();
        return .{
            .expr_stmt = .{ .expr = expr, .span = expr.getSourceSpan() },
        };
    }

    fn parseVariableDeclStmt(self: *Self) anyerror!Stmt {
        const keyword_token = self.eat();
        const identifier_token = try self.expectToken(.identifier, "variable name");

        var type_annotation: ?TypeAnnotation = null;
        if (self.peek().kind == .colon_symbol) {
            type_annotation = try self.parseTypeAnnotation();
        }

        const assignment_token = try self.expectToken(.equal_symbol, "=");
        const value = try self.parseExpr();
        const span: SourceSpan = .{
            .line = keyword_token.span.line,
            .col = keyword_token.span.col,
            .start = keyword_token.span.col,
            .end = value.getSourceSpan().end,
        };

        return .{
            .variable_decl_stmt = .{
                .keyword_token = keyword_token,
                .identifier_token = identifier_token,
                .assignment_token = assignment_token,
                .type_annotation = type_annotation,
                .value = value,
                .span = span,
            },
        };
    }

    fn parseStmt(self: *Self) anyerror!Stmt {
        const stmt = try self.parseNextStmt();

        if (self.panic) {
            const invalid_token = self.peek();
            self.synchronize();
            return .{
                .invalid_stmt = invalid_token,
            };
        }

        return stmt;
    }

    fn parseNextStmt(self: *Self) anyerror!Stmt {
        return switch (self.peek().kind) {
            .const_keyword, .let_keyword => try self.parseVariableDeclStmt(),
            .fn_keyword => try self.parseFunctionDeclStmt(),
            .echo_keyword => try self.parseEchoStmt(),
            .if_keyword => try self.parseIfStmt(),
            .while_keyword => try self.parseWhileStmt(),
            .for_keyword => try self.parseForStmt(),
            .return_keyword => try self.parseReturnStmt(),
            else => try self.parseExprStmt(),
        };
    }

    fn synchronize(self: *Self) void {
        _ = self.eat();

        while (self.hasMoreTokens()) {
            switch (self.peek().kind) {
                .const_keyword, .let_keyword, .fn_keyword, .echo_keyword, .if_keyword, .while_keyword, .for_keyword, .return_keyword, .end_keyword => {
                    self.panic = false;
                    return;
                },
                else => {},
            }

            _ = self.eat();
        }

        self.panic = false;
    }

    fn peek(self: *const Self) Token {
        if (self.cursor >= self.tokens.items.len) {
            if (self.tokens.items.len > 0) {
                return self.tokens.items[self.tokens.items.len - 1];
            }

            return Token{
                .kind = .eof,
                .lexeme = "",
                .span = .{ .line = 0, .col = 0, .start = 0, .end = 0 },
            };
        }

        return self.tokens.items[self.cursor];
    }

    fn lookahead(self: *const Self) Token {
        return if (self.peek().kind != .eof)
            self.tokens.items[self.cursor + 1]
        else self.peek();
    }

    fn eat(self: *Self) Token {
        const token = self.peek();
        self.cursor += 1;

        return token;
    }

    fn hasMoreTokens(self: *const Self) bool {
        return self.tokens.items.len > self.cursor and self.peek().kind != .eof;
    }

    fn canStartExpr(self: *const Self) bool {
        return switch (self.peek().kind) {
            .null_keyword, .true_keyword, .false_keyword, .number_literal, .string_literal, .open_paren_symbol, .identifier, .when_keyword => true,
            else => false,
        };
    }
};
