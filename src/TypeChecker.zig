const std = @import("std");

const ast_mod = @import("internals/ast.zig");
const AST = ast_mod.AST;
const Stmt = ast_mod.Stmt;
const Expr = ast_mod.Expr;

const symbols_mod = @import("internals/symbols.zig");
const SymbolTable = symbols_mod.SymbolTable;
const Symbol = symbols_mod.Symbol;
const Type = symbols_mod.Type;
const TypeKind = symbols_mod.TypeKind;

const Flow = struct {
    can_continue: bool,
};

pub const TypeChecker = struct {
    allocator: std.mem.Allocator,
    ast: *const AST,
    symbols: SymbolTable,
    expected_return_type: Type,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, ast: *const AST) Self {
        return .{
            .allocator = allocator,
            .ast = ast,
            .symbols = SymbolTable.init(.global),
            .expected_return_type = Type.invalid(),
        };
    }

    pub fn check(self: *Self) !void {
        for (self.ast.stmts.items) |stmt| {
            try self.checkStmt(stmt);
        }
    }

    fn checkStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        switch (stmt.*) {
            .echo_stmt => try self.checkEchoStmt(stmt),
            .expr_stmt => try self.checkExprStmt(stmt),
            .variable_decl_stmt => try self.checkVariableDeclStmt(stmt),
            .function_decl_stmt => try self.checkFunctionDeclStmt(stmt),
            .block_stmt => try self.checkBlockStmt(stmt),
            .if_stmt => try self.checkIfStmt(stmt),
            .while_stmt => try self.checkWhileStmt(stmt),
            .for_stmt => try self.checkForStmt(stmt),
            .return_stmt => try self.checkReturnStmt(stmt),
            else => unreachable,
        }
    }

    fn checkEchoStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const echo = stmt.echo_stmt;
        const message_type = try self.checkExpr(echo.message);
        if (message_type.isEmpty()) {
            // TODO: add type mismatch diagnostic.
        }

        return .{
            .can_continue = true,
        };
    }

    fn checkExprStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        _ = try self.checkExpr(stmt.expr_stmt.expr);
        return .{
            .can_continue = true,
        };
    }

    fn checkVariableDeclStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const decl = stmt.variable_decl_stmt;
        if (self.symbols.scopeHas(decl.identifier_token.lexeme)) {
            // TODO: add variable already declared diagnostic.
        }

        const value_type = try self.checkExpr(decl.value);
        var variable_type = value_type;
        if (decl.type_annotation != null) {
            const annotation_type = Type.fromAnnotation(decl.type_annotation);
            if (annotation_type.isEmpty()) {
                // TODO: add invalid variable type annotation diagnostic.
            }

            if (!value_type.isAssignableTo(annotation_type)) {
                // TODO: add type mismatch diagnostic.
            }

            variable_type = annotation_type;
        } else if (variable_type.isEmpty()) {
            // TODO: add invalid variable value type diagnostic.
        }

        const symbol: Symbol = .{
            .variable = .{
                .typing = variable_type,
                .constant = std.mem.eql(u8, decl.keyword_token.lexeme, "const"),
                .name = decl.identifier_token.lexeme,
            },
        };

        try self.symbols.put(symbol);

        return .{
            .can_continue = true,
        };
    }

    fn checkFunctionDeclStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const decl = stmt.function_decl_stmt;
        if (self.symbols.scope != .global) {
            // TODO: add invalid function decl diagnostic.
        }

        if (self.symbols.scopeHas(decl.identifier_token.lexeme)) {
            // TODO: add function already declared diagnostic.
        }

        var param_types = try std.ArrayList(Type).initCapacity(self.allocator, decl.params.capacity);
        var scope = SymbolTable.init(.function, self.symbols);
        for (decl.params.items) |param| {
            const param_type = Type.fromAnnotation(param.type_annotation);
            if (param_type.isEmpty() || param_type.isInvalid()) {
                // TODO: add invalid param type annotation diagnostic.
            }

            const param_symbol: Symbol = .{
                .variable = .{
                    .typing = param_type,
                    .constant = true,
                    .name = param.identifier_token.lexeme,
                },
            };

            param_types.appendAssumeCapacity(param_type);
            scope.put(param_symbol);
        }

        const return_type = self.allocator.create(Type);
        return_type.* = Type.fromAnnotation(decl.type_annotation);
        if (return_type.isInvalid()) {
            // TODO: add invalid return type diagnostic.
        }

        const symbol: Symbol = .{
            .function = .{
                .name = decl.identifier_token.lexeme,
                .arity = decl.params.items.len,
                .typing = Type.function(param_types, return_type),
            },
        };

        self.symbols.put(symbol);
        scope.put(symbol);

        const prev_return_type = self.expected_return_type;
        self.expected_return_type = return_type.*;
        self.symbols = &scope;

        const flow = try self.checkStmt(decl.body);
        self.symbols = scope.parent.?;
        self.expected_return_type = prev_return_type;

        if (!return_type.isEmpty() and flow.can_continue) {
            // TODO: add some control path dont return value diagnostic.
        }

        return .{
            .can_continue = true,
        };
    }

    fn checkBlockStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const block = stmt.block_stmt;
        var scope = SymbolTable.init(.block, self.symbols);
        self.symbols = &scope;

        var flow: Flow = .{ .can_continue = true };
        for (block.items.items) |s| {
            if (!flow.can_continue)
                break;

            flow = try self.checkStmt(s);
        }

        self.symbols = scope.parent.?;

        return flow;
    }

    fn checkIfStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const if_stmt = stmt.if_stmt;
        const condition_type = try self.checkExpr(if_stmt.condition);
        if (condition_type.kind != .bool_t) {
            // TODO: add invalid if condition diagnostic.
        }

        const consequent_flow = try self.checkStmt(if_stmt.consequent);
        var alternate_flow: Flow = .{ .can_continue = true };
        if (if_stmt.alternate) |alt| {
            alternate_flow = try self.checkStmt(alt);
        }

        return .{
            .can_continue = consequent_flow.can_continue or alternate_flow.can_continue,
        };
    }

    fn checkWhileStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const while_stmt = stmt.while_stmt;
        const condition_type = try self.checkExpr(while_stmt.condition);
        if (condition_type.kind != .bool_t) {
            // TODO: add invalid while condition diagnostic.
        }

        const scope = SymbolTable.init(.block, self.symbols);
        self.symbols = &scope;

        const flow = try self.checkStmt(while_stmt.body);
        self.symbols = scope.parent.?;

        return flow;
    }

    fn checkForStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const for_stmt = stmt.for_stmt;
        const scope = SymbolTable.init(.block, self.symbols);
        self.symbols = &scope;
        _ = try self.checkStmt(for_stmt.init);

        const condition_type = try self.checkExpr(for_stmt.condition);
        if (condition_type.kind != .bool_t) {
            // TODO: add invalid for condition type diagnostic.
        }

        _ = try self.checkExpr(for_stmt.update);

        const flow = try self.checkStmt(for_stmt.body);
        self.symbols = scope.parent.?;
        return flow;
    }

    fn checkReturnStmt(self: *Self, stmt: *const Stmt) anyerror!Flow {
        const ret = stmt.return_stmt;
        var function_scope = self.symbols;
        while (function_scope.parent != null and function_scope.scope != .function) {
            function_scope = function_scope.parent.?;
        }

        if (function_scope.scope != .function) {
            // TODO: add invalid usage of return diagnostic.
        }

        const ret_type = if (ret.expr) |e| try self.checkExpr(e) else Type.empty();
        if (!ret_type.isAssignableTo(self.expected_return_type)) {
            // TODO: add invalid return type diagnostic.
        }

        return .{
            .can_continue = false,
        };
    }

    fn checkExpr(self: *Self, expr: *const Expr) anyerror!Type {
        return switch (expr.*) {
            .literal_expr => try self.checkLiteralExpr(expr),
            .identifier_expr => try self.checkIdentifierExpr(expr),
            .unary_expr => try self.checkUnaryExpr(expr),
            .binary_expr => try self.checkBinaryExpr(expr),
            .parenthesized_expr => try self.checkParenthesizedExpr(expr),
            .assignment_expr => try self.checkAssignmentExpr(expr),
            .when_expr => try self.checkWhenExpr(expr),
            .call_expr => try self.checkCallExpr(expr),
            else => unreachable,
        };
    }

    fn checkLiteralExpr(_: *Self, expr: *const Expr) anyerror!Type {
        const literal = expr.literal_expr;
        return switch (literal.value_token.kind) {
            .number_literal => Type.fromLexeme("int"),
            .string_literal => Type.fromLexeme("string"),
            .true_keyword, .false_keyword => Type.fromLexeme("bool"),
            .null_keyword => Type.fromLexeme("null"),
            else => unreachable,
        };
    }

    fn checkIdentifierExpr(self: *Self, expr: *const Expr) anyerror!Type {
        const ident = expr.identifier_expr;
        const symbol = self.symbols.get(ident.identifier_token.lexeme);
        if (symbol == null) {
            // TODO: add undefined identifier diagnostic.
        }

        return symbol.?.getType();
    }

    fn checkUnaryExpr(self: *Self, expr: *const Expr) anyerror!Type {
        const unary = expr.unary_expr;
        const operand_type = try self.checkExpr(unary.operand);
        if (!operand_type.supportsUnaryOperator(unary.operator_token.kind)) {
            // TODO: add unsuported unary operation diagnostic.
        }

        return operand_type;
    }

    fn checkBinaryExpr(self: *Self, expr: *const Expr) anyerror!Type {
        const binary = expr.binary_expr;
        const left_type = try self.checkExpr(binary.left);
        const right_type = try self.checkExpr(binary.right);
        if (!left_type.supportsBinaryOperator(right_type, binary.operator_token.kind)) {
            // TODO: add unsuported binary operation diagnostic.
        }
        
        return switch (binary.operator_token.kind) {
            .minus_symbol, .plus_symbol, .star_symbol, .slash_symbol, .percentage_symbol => Type.fromLexeme("int"),

            .lt_symbol, .lte_symbol, .gt_symbol, .gte_symbol, .eqeq_symbol, .neq_symbol, .and_symbol, .or_symbol => Type.fromLexeme("bool"),
            else => unreachable,
        };
    }

    fn checkAssignmentExpr(self: *Self, expr: *const Expr) anyerror!Type {
        const assignment = expr.assignment_expr;
        const symbol = self.symbols.get(assignment.identifier_token.lexeme);
        if (symbol == null) {
            // TODO: add undefined identifier diagnostic.
        }

        if (!symbol.?.isVariable()) {
            // TODO: add attempt to assign a non-variable identifier.
        }

        const variable = symbol.?.variable;
        if (variable.constant) {
            // TODO: add attempt to assign a constant variable.
        }

        const value_type = try self.checkExpr(assignment.value);
        if (!value_type.isAssignableTo(variable.typing)) {
            // TODO: add type mismatch diagnostic.
        }

        return value_type;
    }

    fn checkWhenExpr(self: *Self, expr: *const Expr) anyerror!Type {
        const when = expr.when_expr;
        const condition_type = try self.checkExpr(when.condition);
        if (condition_type.kind != .bool_t) {
            // TODO: add invalid when condition type.
        }

        const consequent_type = try self.checkExpr(when.consequent);
        const alternate_type = try self.checkExpr(when.alternate);

        var expected: Type = undefined;
        var received: Type = undefined;
        if (consequent_type.kind == .null_t) {
            received = consequent_type;
            expected = alternate_type;
            expected.nullable = true;
        } else if (alternate_type.kind == .null_t) {
            received = alternate_type;
            expected = consequent_type;
            expected.nullable = true;
        } else {
            expected = consequent_type;
            received = alternate_type;
        }

        if (std.mem.eql(TypeKind, expected.kind, received.kind) and alternate_type.nullable) {
            expected.nullable = true;
        }

        if (!received.isAssignableTo(expected)) {
            // TODO: add type mismatch diagnostic.
        }

        return expected;
    }

    fn checkCallExpr(self: *Self, expr: *const Expr) anyerror!Type {
        const call = expr.call_expr;
        const symbol = self.symbols.get(call.identifier_token.lexeme);
        if (symbol == null) {
            // TODO: add attempt to call a undefined function diagnostic.
        }

        if (!symbol.?.isFunction()) {
            // TODO: add attempt to call a non-function diagnostic.
        }

        const function = symbol.?.function;
        if (call.arguments.items.len != function.arity) {
            // TODO: add invalid number of arguments diagnostic.
        }

        const param_types = function.typing.kind.function_t.param_types;
        for (0..param_types.items.len) |i| {
            const param_type = param_types.items[i];
            const argument_type = try self.checkExpr(call.arguments.items[i]);
            if (!argument_type.isAssignableTo(param_type)) {
                // TODO: add type mismatch diagnostic.
            }
        }

        const return_type = function.typing.kind.function_t.return_type;
        return return_type;
    }
};
