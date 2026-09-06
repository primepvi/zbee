const std = @import("std");

const source_mod = @import("Source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("Token.zig");
const Token = token_mod.Token;

pub const ExprKind = enum {
    literal_expr,
    identifier_expr,
    assignment_expr,
    binary_expr,
    unary_expr,
    parenthesized_expr,
    when_expr,
    call_expr,
    invalid_expr,
};

pub const LiteralExpr = struct {
    value_token: Token,
    span: SourceSpan,
};

pub const IdentifierExpr = struct {
    identifier_token: Token,
    span: SourceSpan,
};

pub const AssignmentExpr = struct {
    identifier_token: Token,
    assignment_token: Token,
    value: *Expr,
    span: SourceSpan,
};

pub const BinaryExpr = struct {
    left: *Expr,
    right: *Expr,
    operator_token: Token,
    span: SourceSpan,
};

pub const UnaryExpr = struct {
    operator_token: Token,
    operand: *Expr,
    span: SourceSpan,
};

pub const ParenthesizedExpr = struct {
    open_paren_token: Token,
    close_paren_token: Token,
    expr: *Expr,
    span: SourceSpan,
};

pub const WhenExpr = struct {
    when_token: Token,
    otherwise_token: Token,
    condition: *Expr,
    consequent: *Expr,
    alternate: *Expr,
    span: SourceSpan,
};

pub const CallExpr = struct {
    identifier_token: Token,
    open_paren_token: Token,
    close_paren_token: Token,
    arguments: std.ArrayList(Expr),
    span: SourceSpan,
};

pub const Expr = union(ExprKind) {
    literal_expr: LiteralExpr,
    identifier_expr: IdentifierExpr,
    assignment_expr: AssignmentExpr,
    binary_expr: BinaryExpr,
    unary_expr: UnaryExpr,
    parenthesized_expr: ParenthesizedExpr,
    when_expr: WhenExpr,
    call_expr: CallExpr,
    invalid_expr: Token,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .assignment_expr => {
                var e = self.assignment_expr;
                e.value.deinit(allocator);
                allocator.destroy(e.value);
            },
            .binary_expr => {
                var e = self.binary_expr;
                e.left.deinit(allocator);
                e.right.deinit(allocator);
                allocator.destroy(e.left);
                allocator.destroy(e.right);
            },
            .unary_expr => {
                var e = self.unary_expr;
                e.operand.deinit(allocator);
                allocator.destroy(e.operand);
            },
            .parenthesized_expr => {
                var e = self.parenthesized_expr;
                e.expr.deinit(allocator);
                allocator.destroy(e.expr);
            },
            .when_expr => {
                var e = self.when_expr;
                e.condition.deinit(allocator);
                e.consequent.deinit(allocator);
                e.alternate.deinit(allocator);
                allocator.destroy(e.condition);
                allocator.destroy(e.consequent);
                allocator.destroy(e.alternate);
            },
            .call_expr => {
                var e = self.call_expr;
                for (0..e.arguments.items.len) |i| {
                    var arg = e.arguments.items[i];
                    arg.deinit(allocator);
                }
                e.arguments.deinit(allocator);
            },
            else => {},
        }
    }

    pub fn getSourceSpan(self: *const Self) SourceSpan {
        return switch (self.*) {
            .literal_expr => |e| {
                return e.span;
            },
            .identifier_expr => |e| {
                return e.span;
            },
            .assignment_expr => |e| {
                return e.span;
            },
            .binary_expr => |e| {
                return e.span;
            },
            .unary_expr => |e| {
                return e.span;
            },
            .parenthesized_expr => |e| {
                return e.span;
            },
            .when_expr => |e| {
                return e.span;
            },
            .call_expr => |e| {
                return e.span;
            },
            .invalid_expr => |e| {
                return e.span;
            }
        };
    }
};

pub const StmtKind = enum {
    variable_decl_stmt,
    function_decl_stmt,
    return_stmt,
    expr_stmt,
    echo_stmt,
    if_stmt,
    block_stmt,
    while_stmt,
    for_stmt,
    invalid_stmt,
};

pub const TypeAnnotation = struct {
    colon_token: Token,
    identifier_token: Token,
    nullable: bool,
    span: SourceSpan,
};

pub const VariableDeclStmt = struct {
    keyword_token: Token,
    identifier_token: Token,
    assignment_token: Token,
    type_annotation: ?TypeAnnotation,
    value: Expr,
    span: SourceSpan,
};

pub const FunctionDeclParam = struct {
    identifier_token: Token,
    type_annotation: TypeAnnotation,
    span: SourceSpan,
};

pub const FunctionDeclStmt = struct {
    keyword_token: Token,
    identifier_token: Token,
    type_annotation: TypeAnnotation,
    params: std.ArrayList(FunctionDeclParam),
    body: *Stmt,
    span: SourceSpan,
};

pub const ReturnStmt = struct {
    keyword_token: Token,
    expr: ?Expr,
    span: SourceSpan,
};

pub const ExprStmt = struct {
    expr: Expr,
    span: SourceSpan,
};

pub const EchoStmt = struct {
    keyword_token: Token,
    message: Expr,
    span: SourceSpan,
};

pub const IfStmt = struct {
    keyword_token: Token,
    condition: Expr,
    consequent: *Stmt,
    alternate: ?*Stmt,
    span: SourceSpan,
};

pub const WhileStmt = struct {
    keyword_token: Token,
    condition: Expr,
    body: *Stmt,
    span: SourceSpan,
};

pub const ForStmt = struct {
    keyword_token: Token,
    init: *Stmt,
    condition: Expr,
    update: Expr,
    body: *Stmt,
    span: SourceSpan,
};

pub const BlockStmt = struct {
    items: std.ArrayList(Stmt),
    span: SourceSpan,
};

pub const Stmt = union(StmtKind) {
    variable_decl_stmt: VariableDeclStmt,
    function_decl_stmt: FunctionDeclStmt,
    return_stmt: ReturnStmt,
    expr_stmt: ExprStmt,
    echo_stmt: EchoStmt,
    if_stmt: IfStmt,
    block_stmt: BlockStmt,
    while_stmt: WhileStmt,
    for_stmt: ForStmt,
    invalid_stmt: Token,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .variable_decl_stmt => {
                var s = self.variable_decl_stmt;
                s.value.deinit(allocator);
            },
            .function_decl_stmt => {
                var s = self.function_decl_stmt;
                s.body.deinit(allocator);
                allocator.destroy(s.body);
                s.params.deinit(allocator);
            },
            .return_stmt => {
                var s = self.return_stmt;
                if (s.expr != null) s.expr.?.deinit(allocator);
            },
            .expr_stmt => {
                var s = self.expr_stmt;
                s.expr.deinit(allocator);
            },
            .echo_stmt => {
                var s = self.echo_stmt;
                s.message.deinit(allocator);
            },
            .if_stmt => {
                var s = self.if_stmt;
                s.condition.deinit(allocator);
                s.consequent.deinit(allocator);
                allocator.destroy(s.consequent);
                
                if (s.alternate != null) {
                    s.alternate.?.deinit(allocator);
                    allocator.destroy(s.alternate.?);
                }                
            },
            .block_stmt => {                
                var s = self.block_stmt;
                for (0..s.items.items.len) |i| {
                    var inner = s.items.items[i];
                    inner.deinit(allocator);
                }
                s.items.deinit(allocator);
            },
            .for_stmt => {
                var s = self.for_stmt;
                s.update.deinit(allocator);
                s.condition.deinit(allocator);
                
                s.body.deinit(allocator);
                allocator.destroy(s.body);
                
                s.init.deinit(allocator);
                allocator.destroy(s.init);
            },
            .while_stmt => {
                var s = self.while_stmt;
                s.condition.deinit(allocator);
                s.body.deinit(allocator);
                allocator.destroy(s.body);
            },
            else => {}
        }
    }

    pub fn getSourceSpan(self: *const Self) SourceSpan {
        return switch (self.*) {
            .variable_decl_stmt => |s| {
                return s.span;
            },
            .function_decl_stmt => |s| {
                return s.span;
            },
            .return_stmt => |s| {
                return s.span;
            },
            .expr_stmt => |s| {
                return s.span;
            },
            .echo_stmt => |s| {
                return s.span;
            },
            .if_stmt => |s| {
                return s.span;
            },
            .while_stmt => |s| {
                return s.span;
            },
            .for_stmt => |s| {
                return s.span;
            },
            .block_stmt => |s| {
                return s.span;
            },
            .invalid_stmt => |s| {
                return s.span;
            }
        };
    }
};

pub const AST = struct {
    allocator: std.mem.Allocator,
    source: *const Source,
    stmts: std.ArrayList(Stmt),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, source: *const Source) Self {
        return .{ .allocator = allocator, .source = source, .stmts = .empty };
    }

    pub fn deinit(self: *Self) void {
        for (0..self.stmts.items.len) |i| {
            var stmt = self.stmts.items[i];
            stmt.deinit(self.allocator);
        }
        
        self.stmts.deinit(self.allocator);
    }
};
