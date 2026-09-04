const std = @import("std");

const source_mod = @import("source.zig");
const Source = source_mod.Source;
const SourceSpan = source_mod.SourceSpan;

const token_mod = @import("token.zig");
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

    pub fn deinit(self: *Self) !void {
        try self.stmts.deinit(self.allocator);
    }
};
