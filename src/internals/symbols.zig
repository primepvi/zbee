const std = @import("std");
const TypeAnnotation = @import("ast.zig").TypeAnnotation;

pub const FunctionType = struct {
    param_types: []const Type,
    return_type: *Type,
};
    
pub const TypeKind = union(enum) {
    int_t,
    bool_t,
    string_t,
    invalid_t,
    void_t,

    function: FunctionType,
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
};

pub const ScopeKind = enum {
    global,
    function,
    block
};

pub const SymbolTable = struct {
    scope: ScopeKind,
    env: std.StringHashMap(Symbol),
    parent: *SymbolTable
};
