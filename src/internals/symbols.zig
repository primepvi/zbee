const std = @import("std");
const TokenKind = @import("Token.zig").TokenKind;
const TypeAnnotation = @import("ast.zig").TypeAnnotation;

pub const FunctionType = struct {
    param_types: std.ArrayList(Type),
    return_type: *Type,
};

pub const TypeKind = union(enum) {
    int_t,
    bool_t,
    string_t,
    invalid_t,
    void_t,
    null_t,
    function_t: FunctionType,
};

pub const Type = struct {
    kind: TypeKind,
    nullable: bool,

    const Self = @This();
    const typings_map = std.StaticStringMap(TypeKind).initComptime(.{
        .{ "int", .int_t },
        .{ "bool", .bool_t },
        .{ "string", .string_t },
        .{ "void", .void_t },
        .{ "null", .null_t },
    });

    pub fn fromLexeme(lexeme: []const u8) Self {
        return .{
            .kind = typings_map.get(lexeme) orelse .invalid_t,
            .nullable = false,
        };
    }

    pub fn fromAnnotation(annotation: TypeAnnotation) Self {
        return .{
            .kind = typings_map.get(annotation.identifier_token.lexeme) orelse .invalid_t,
            .nullable = annotation.nullable,
        };
    }

    pub fn function(params_types: std.ArrayList(Type), return_type: *Type) Self {
        const function_type: FunctionType = .{
            .param_types = params_types,
            .return_type = return_type,
        };

        return .{
            .kind = .{ .function_t = function_type },
            .nullable = false,
        };
    }

    pub fn invalid() Self {
        return .{
            .kind = .invalid_t,
            .nullable = false,
        };
    }

    pub fn empty() Self {
        return .{
            .kind = .void_t,
            .nullable = false,
        };
    }

    pub fn isEmpty(self: *const Self) bool {
        return switch (self.kind) {
            .void_t => true,
            else => false,
        };
    }

    pub fn isInvalid(self: *const Self) bool {
        return switch (self.kind) {
            .invalid_t => true,
            else => false,
        };
    }

    pub fn isEqualTo(self: *const Self, other: Self) bool {
        return std.mem.eql(u8, @tagName(self.kind), @tagName(other.kind));
    }

    pub fn isAssignableTo(self: *const Self, expected: Self) bool {
        const is_equal = std.mem.eql(u8, @tagName(self.kind), @tagName(expected.kind));
        if (expected.nullable and (is_equal or self.kind == .null_t)) {
            return true;
        } else {
            return is_equal and !self.nullable;
        }
    }

    pub fn supportsUnaryOperator(self: *const Self, operator: TokenKind) bool {
        return switch (operator) {
            .minus_symbol, .plus_symbol => self.kind == .int_t,
            .not_keyword => self.kind == .bool_t,
            else => false,
        };
    }

    pub fn supportsBinaryOperator(self: *const Self, other: *const Self, operator: TokenKind) bool {
        return switch (operator) {
            .minus_symbol, .plus_symbol, .star_symbol, .slash_symbol, .percentage_symbol, .lt_symbol, .gt_symbol, .lte_symbol, .gte_symbol => self.kind == .int_t and other.kind == .int_t,

            .eqeq_symbol, .neq_symbol => !(self.isEmpty() or self.isInvalid()) and !(other.isEmpty() or other.isInvalid()),
            .and_keyword, .or_keyword => self.kind == .bool_t and other.kind == .bool_t,
            else => false,
        };
    }
};

pub const SymbolKind = enum { variable, function };

pub const VariableSymbol = struct {
    name: []const u8,
    constant: bool,
    typing: Type,
};

pub const FunctionSymbol = struct {
    name: []const u8,
    arity: usize,
    typing: Type,
};

pub const Symbol = union(SymbolKind) {
    variable: VariableSymbol,
    function: FunctionSymbol,

    const Self = @This();

    pub fn getName(self: *const Self) []const u8 {
        return switch (self.*) {
            .variable => |v| v.name,
            .function => |f| f.name,
        };
    }

    pub fn getType(self: *const Self) Type {
        return switch (self.*) {
            .variable => |v| v.typing,
            .function => |f| f.typing,
        };
    }

    pub fn isVariable(self: *const Self) bool {
        return switch (self.*) {
            .variable => true,
            else => false,
        };
    }

    pub fn isFunction(self: *const Self) bool {
        return switch (self.*) {
            .function => true,
            else => false,
        };
    }
};

pub const ScopeKind = enum { global, function, block };

pub const SymbolTable = struct {
    scope: ScopeKind,
    env: std.StringHashMap(Symbol),
    parent: ?*SymbolTable,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, scope: ScopeKind, parent: ?*SymbolTable) Self {
        return .{
            .scope = scope,
            .env = .init(allocator),
            .parent = parent,
        };
    }

    pub fn deinit(self: *Self) void {
        self.env.deinit();
    }

    pub fn scopeHas(self: *const Self, name: []const u8) bool {
        return self.env.get(name) != null;
    }

    pub fn put(self: *Self, symbol: Symbol) !void {
        try self.env.put(symbol.getName(), symbol);
    }

    pub fn get(self: *Self, name: []const u8) ?Symbol {
        if (self.scopeHas(name)) {
            return self.env.get(name);
        } else if (self.parent != null) {
            return self.parent.?.get(name);
        } else {
            return null;
        }
    }
};
