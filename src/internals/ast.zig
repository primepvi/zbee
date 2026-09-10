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
            },
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
            else => {},
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
            },
        };
    }
};

const AstDebugWriter = struct {
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,

    const Self = @This();

    const Color = struct {
        const reset = "\x1b[0m";

        const branch = "\x1b[38;5;243m";
        const statement = "\x1b[38;5;109m";
        const expression = "\x1b[38;5;139m";
        const property = "\x1b[38;5;179m";
        const value = "\x1b[38;5;108m";
    };

    pub fn init(allocator: std.mem.Allocator, writer: *std.Io.Writer) Self {
        return Self{
            .writer = writer,
            .allocator = allocator,
        };
    }

    pub fn debug(self: *Self, program: *const std.ArrayList(Stmt)) !void {
        try self.statement("", "", "Program");
        for (0..program.items.len) |i| {
            const is_last = i == program.items.len - 1;
            const stmt = program.items[i];
            try self.debugStmt(&stmt, " ", is_last);
        }
    }

    fn debugExpr(self: *Self, expr: *const Expr, prefix: []const u8, is_last: bool) !void {
        const common = Color.branch ++ "├──" ++ Color.reset;
        const last = Color.branch ++ "└──" ++ Color.reset;
        const symbol = if (is_last) last else common;

        switch (expr.*) {
            .literal_expr => |l| {
                try self.expression(prefix, symbol, "Literal Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, last, "Value:");
                try self.value("\"{s}\"\n", .{l.value_token.lexeme});
            },
            .identifier_expr => |i| {
                try self.expression(prefix, symbol, "Identifier Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, last, "Identifier:");
                try self.value("\"{s}\"\n", .{i.identifier_token.lexeme});
            },
            .assignment_expr => |a| {
                try self.expression(prefix, symbol, "Assignment Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Identifier:");
                try self.value("\"{s}\"\n", .{a.identifier_token.lexeme});
                try self.property(child_prefix, last, "Value:\n");
                const expr_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(expr_prefix);
                try self.debugExpr(a.value, expr_prefix, true);
            },
            .binary_expr => |b| {
                try self.expression(prefix, last, "Binary Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                const left_prefix = try self.childPrefix(child_prefix, false);
                defer self.allocator.free(left_prefix);

                try self.property(child_prefix, common, "Left:\n");
                try self.debugExpr(b.left, left_prefix, true);

                try self.property(child_prefix, common, "Operator:");
                try self.value("\"{s}\"\n", .{b.operator_token.lexeme});

                const right_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(right_prefix);

                try self.property(child_prefix, last, "Right:\n");
                try self.debugExpr(b.right, right_prefix, true);
            },
            .unary_expr => |u| {
                try self.expression(prefix, symbol, "Unary Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Operator:");
                try self.value("\"{s}\"\n", .{u.operator_token.lexeme});

                const operand_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(operand_prefix);

                try self.property(child_prefix, last, "Operand:\n");
                try self.debugExpr(u.operand, operand_prefix, true);
            },
            .parenthesized_expr => |p| {
                try self.expression(prefix, symbol, "Parenthesized Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, last, "Expression:\n");
                const expr_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(expr_prefix);
                try self.debugExpr(p.expr, expr_prefix, true);
            },
            .when_expr => |w| {
                try self.expression(prefix, symbol, "When Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Condition:\n");
                const common_prefix = try self.childPrefix(child_prefix, false);
                defer self.allocator.free(common_prefix);
                try self.debugExpr(w.condition, common_prefix, true);

                try self.property(child_prefix, common, "Alternate:\n");
                try self.debugExpr(w.alternate, common_prefix, true);

                const last_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(last_prefix);

                try self.property(child_prefix, last, "Consequent:\n");
                try self.debugExpr(w.consequent, last_prefix, true);
            },
            .call_expr => |c| {
                try self.expression(prefix, symbol, "Call Expression");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Identifier:");
                try self.value("\"{s}\"\n", .{c.identifier_token.lexeme});
                try self.property(child_prefix, last, "Arguments:\n");
                const arguments_title_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(arguments_title_prefix);

                for (0..c.arguments.items.len) |i| {
                    const argument_title = try std.fmt.allocPrint(self.allocator, "{d}:\n", .{i});
                    defer self.allocator.free(argument_title);

                    const inner_is_last = i == c.arguments.items.len - 1;
                    const inner_symbol = if (inner_is_last) last else common;
                    try self.property(arguments_title_prefix, inner_symbol, argument_title);

                    const argument_prefix = try self.childPrefix(arguments_title_prefix, inner_is_last);
                    defer self.allocator.free(argument_prefix);
                    const argument = c.arguments.items[i];
                    try self.debugExpr(&argument, argument_prefix, true);
                }
            },
            else => {},
        }
    }

    fn debugStmt(self: *Self, stmt: *const Stmt, prefix: []const u8, is_last: bool) !void {
        const common = Color.branch ++ "├──" ++ Color.reset;
        const last = Color.branch ++ "└──" ++ Color.reset;
        const symbol = if (is_last) last else common;

        switch (stmt.*) {
            .variable_decl_stmt => |v| {
                try self.statement(prefix, symbol, "Variable Declaration Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Constant:");
                try self.value("{}\n", .{std.mem.eql(u8, v.keyword_token.lexeme, "const")});

                try self.property(child_prefix, common, "Identifier:");
                try self.value("\"{s}\"\n", .{v.identifier_token.lexeme});

                if (v.type_annotation) |annotation| {
                    try self.property(child_prefix, common, "TypeAnnotation:");
                    try self.writer.print(" (Nullable:", .{});
                    try self.value("{}", .{annotation.nullable});
                    try self.writer.print(", Lexeme:", .{});
                    try self.value("\"{s}\"", .{annotation.identifier_token.lexeme});
                    try self.writer.print(")\n", .{});
                }

                try self.property(child_prefix, last, "Value:\n");
                const expr_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(expr_prefix);
                try self.debugExpr(&v.value, expr_prefix, true);
            },
            .function_decl_stmt => |f| {
                try self.statement(prefix, symbol, "Function Declaration Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Identifier:");
                try self.value("\"{s}\"\n", .{f.identifier_token.lexeme});

                try self.property(child_prefix, common, "TypeAnnotation:");
                try self.writer.print(" (Nullable:", .{});
                try self.value("{}", .{f.type_annotation.nullable});
                try self.writer.print(", Lexeme:", .{});
                try self.value("\"{s}\"", .{f.type_annotation.identifier_token.lexeme});
                try self.writer.print(")\n", .{});

                try self.property(child_prefix, common, "Body:\n");
                const body_prefix = try self.childPrefix(child_prefix, is_last);
                defer self.allocator.free(body_prefix);
                try self.debugStmt(f.body, body_prefix, true);

                try self.property(child_prefix, last, "Params:\n");
                const param_title_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(param_title_prefix);

                for (0..f.params.items.len) |i| {
                    const param_title = try std.fmt.allocPrint(self.allocator, "{d}:\n", .{i});
                    defer self.allocator.free(param_title);

                    const inner_is_last = i == f.params.items.len - 1;
                    const inner_symbol = if (inner_is_last) last else common;
                    try self.property(param_title_prefix, inner_symbol, param_title);

                    const param_prefix = try self.childPrefix(param_title_prefix, inner_is_last);
                    defer self.allocator.free(param_prefix);
                    const param = f.params.items[i];

                    try self.property(param_prefix, common, "Identifier:");
                    try self.value("\"{s}\"\n", .{param.identifier_token.lexeme});

                    try self.property(param_prefix, last, "TypeAnnotation:");
                    try self.writer.print(" (Nullable:", .{});
                    try self.value("{}", .{param.type_annotation.nullable});
                    try self.writer.print(", Lexeme:", .{});
                    try self.value("\"{s}\"", .{param.type_annotation.identifier_token.lexeme});
                    try self.writer.print(")\n", .{});
                }
            },
            .return_stmt => |r| {
                try self.statement(prefix, symbol, "Return Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                if (r.expr) |expr| {
                    try self.property(child_prefix, last, "Expression:\n");
                    const expr_prefix = try self.childPrefix(child_prefix, true);
                    defer self.allocator.free(expr_prefix);
                    try self.debugExpr(&expr, expr_prefix, true);
                }
            },
            .expr_stmt => |e| {
                try self.statement(prefix, symbol, "Expression Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, last, "Expression:\n");
                const expr_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(expr_prefix);
                try self.debugExpr(&e.expr, expr_prefix, true);
            },
            .echo_stmt => |e| {
                try self.statement(prefix, symbol, "Echo Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, last, "Message:\n");
                const message_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(message_prefix);
                try self.debugExpr(&e.message, message_prefix, true);
            },
            .if_stmt => |i| {
                try self.statement(prefix, symbol, "If Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Condition:\n");
                const common_prefix = try self.childPrefix(child_prefix, false);
                defer self.allocator.free(common_prefix);
                try self.debugExpr(&i.condition, common_prefix, true);

                if (i.alternate) |alt| {
                    try self.property(child_prefix, common, "Alternate:\n");
                    try self.debugStmt(alt, common_prefix, true);
                }

                const last_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(last_prefix);

                try self.property(child_prefix, last, "Consequent:\n");
                try self.debugStmt(i.consequent, last_prefix, true);
            },
            .block_stmt => |b| {
                try self.statement(prefix, symbol, "Block Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, last, "Statements:\n");
                const stmt_title_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(stmt_title_prefix);

                for (0..b.items.items.len) |i| {
                    const stmt_title = try std.fmt.allocPrint(self.allocator, "{d}:\n", .{i});
                    defer self.allocator.free(stmt_title);

                    const inner_is_last = i == b.items.items.len - 1;
                    const inner_symbol = if (inner_is_last) last else common;
                    try self.property(stmt_title_prefix, inner_symbol, stmt_title);

                    const stmt_prefix = try self.childPrefix(stmt_title_prefix, inner_is_last);
                    defer self.allocator.free(stmt_prefix);
                    const s = b.items.items[i];
                    try self.debugStmt(&s, stmt_prefix, true);
                }
            },
            .for_stmt => |f| {
                try self.statement(prefix, symbol, "For Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Init:\n");
                const common_prefix = try self.childPrefix(child_prefix, false);
                defer self.allocator.free(common_prefix);

                try self.debugStmt(f.init, common_prefix, true);

                try self.property(child_prefix, common, "Condition:\n");
                try self.debugExpr(&f.condition, common_prefix, true);

                try self.property(child_prefix, common, "Update:\n");
                try self.debugExpr(&f.update, common_prefix, true);

                try self.property(child_prefix, last, "Body:\n");
                const last_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(last_prefix);
                try self.debugStmt(f.body, last_prefix, true);
            },
            .while_stmt => |w| {
                try self.statement(prefix, symbol, "While Statement");
                const child_prefix = try self.childPrefix(prefix, is_last);
                defer self.allocator.free(child_prefix);

                try self.property(child_prefix, common, "Condition:\n");
                const common_prefix = try self.childPrefix(child_prefix, false);
                defer self.allocator.free(common_prefix);
                try self.debugExpr(&w.condition, common_prefix, true);

                try self.property(child_prefix, last, "Body:\n");
                const last_prefix = try self.childPrefix(child_prefix, true);
                defer self.allocator.free(last_prefix);
                try self.debugStmt(w.body, last_prefix, true);
            },
            else => {},
        }
    }

    fn childPrefix(
        self: *Self,
        prefix: []const u8,
        is_last: bool,
    ) ![]const u8 {
        const whitespace = if (is_last)
            "    "
        else
            Color.branch ++ "│   " ++ Color.reset;

        return try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ prefix, whitespace },
        );
    }

    fn statement(
        self: *Self,
        prefix: []const u8,
        symbol: []const u8,
        comptime name: []const u8,
    ) !void {
        try self.writer.print(
            "{s}" ++ Color.branch ++ "{s}" ++ Color.statement ++
                " " ++ name ++ Color.reset ++ "\n",
            .{ prefix, symbol },
        );
    }

    fn expression(
        self: *Self,
        prefix: []const u8,
        symbol: []const u8,
        comptime name: []const u8,
    ) !void {
        try self.writer.print(
            "{s}" ++ Color.branch ++ "{s}" ++ Color.expression ++
                " " ++ name ++ Color.reset ++ "\n",
            .{ prefix, symbol },
        );
    }

    fn property(
        self: *Self,
        prefix: []const u8,
        symbol: []const u8,
        name: []const u8,
    ) !void {
        try self.writer.print(
            "{s}" ++ Color.branch ++ "{s}" ++
                Color.property ++ " {s}" ++ Color.reset ++ "",
            .{ prefix, symbol, name },
        );
    }

    fn value(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.writer.print(
            " " ++ Color.value ++ fmt ++ Color.reset,
            args,
        );
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

    pub fn debug(self: *Self, writter: *std.Io.Writer) !void {
        var debug_writter = AstDebugWriter.init(self.allocator, writter);
        try debug_writter.debug(&self.stmts);
    }
};
