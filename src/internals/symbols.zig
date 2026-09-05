const std = @import("std");
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
        .{"int", .int_t},
        .{"bool", .bool_t},
        .{"string", .string_t},
        .{"void", .void_t},
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

    pub fn isEmpty(self: *Self) bool {
        return switch(self.*) {
            .void_t => true,
            else => false,
        };
    }

    pub fn isInvalid(self: *Self) bool {
        return switch(self.*) {
            .invalid_t => true,
            else => false,
        };
    }

    pub fn isAssignableTo(self: *Self, expected: Self) bool {
        const is_equal = std.mem.eql(TypeKind, self.kind, expected.kind);
        if (expected.nullable and (is_equal or self.kind == .null_t)) {
            return true;
        } else {
            return is_equal and !self.nullable;
        }
    }
};

pub const SymbolKind = enum {
    variable,
    function
};

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
        return switch(self.*) {
            .variable => |v| v.name,
            .function => |f| f.name,
        };
    }
};

pub const ScopeKind = enum {
    global,
    function,
    block
};

pub const SymbolTable = struct {
    scope: ScopeKind,
    env: std.StringHashMap(Symbol),
    parent: ?*SymbolTable,

    const Self = @This();

    pub fn init(scope: ScopeKind, parent: ?*SymbolTable) Self {
        return .{
            .scope = scope,
            .env = .empty,
            .parent = parent,
        };
    }

    pub fn scopeHas(self: *const Self, name: []const u8) bool {
        return self.env.get(name) != null;
    }

    pub fn put(self: *Self, symbol: Symbol) !void {
        try self.env.put(symbol.getName(), symbol);
    }
};
