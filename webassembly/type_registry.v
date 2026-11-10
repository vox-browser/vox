// Copyright (c) 2026, Ali Mohammad Pur <ali@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/TypeSystem.cpp: TypeRegistry, GroupRoller and type closing.
@[has_globals]
module webassembly

import sync

@[heap]
pub struct BinaryCanonicalType {
mut:
	sub_type_        BinaryDefinedType
	supertype_       &BinaryCanonicalType = unsafe { nil }
	ancestors_       []&BinaryCanonicalType
	subtyping_depth_ u32
	registry_index_  u32
}

pub fn (type_ &BinaryCanonicalType) sub_type() BinaryDefinedType { return type_.sub_type_ }

pub fn (type_ &BinaryCanonicalType) supertype() ?&BinaryCanonicalType {
	if isnil(type_.supertype_) { return none }
	return type_.supertype_
}

pub fn (type_ &BinaryCanonicalType) is_final() bool { return type_.sub_type_.is_final }

pub fn (type_ &BinaryCanonicalType) subtyping_depth() u32 { return type_.subtyping_depth_ }

pub fn (type_ &BinaryCanonicalType) ancestors() []&BinaryCanonicalType {
	return type_.ancestors_.clone()
}

pub fn (type_ &BinaryCanonicalType) registry_index() u32 { return type_.registry_index_ }

pub struct BinaryTypeContext {
pub:
	types []&BinaryCanonicalType
}

@[heap]
struct BinaryTypeRegistry {
mut:
	mutex           &sync.Mutex
	types           []&BinaryCanonicalType
	interned_groups map[string]u32
}

// Source identities are intentionally immortal and process-wide. The rooted
// registry retains all heap records and serializes lookup/interning with a mutex.
__global binary_type_registry_ = &BinaryTypeRegistry{ mutex: sync.new_mutex() }

pub fn (context BinaryTypeContext) resolve(index u32) ?&BinaryCanonicalType {
	if context.types.len == 0 {
		mut registry := binary_type_registry_
		registry.mutex.lock()
		defer { registry.mutex.unlock() }
		if u64(index) >= u64(registry.types.len) { return none }
		return registry.types[index]
	}
	if u64(index) >= u64(context.types.len) { return none }
	return context.types[index]
}

struct RolledBinaryTypeUse {
	recursive bool
	index     u32
}

struct BinaryGroupRoller {
	group    BinaryRecGroupSpan
	resolved []&BinaryCanonicalType
}

fn (roller BinaryGroupRoller) roll(index u32) !RolledBinaryTypeUse {
	if index < roller.group.start {
		return RolledBinaryTypeUse{ index: roller.resolved[index].registry_index_ }
	}
	if index < roller.group.start + roller.group.count {
		return RolledBinaryTypeUse{ recursive: true, index: index - roller.group.start }
	}
	return error('CompileError: unknown type ${index} referenced from recursive type group')
}

// Source StringBuilder appends the native u32 representation to its binary
// key. Preserve those bytes, including embedded NULs, instead of text indices.
fn append_type_key_u32(mut key []u8, value u32) {
	key << unsafe { (&u8(&value)).vbytes(int(sizeof(u32))).clone() }
}

fn (roller BinaryGroupRoller) serialize_use(mut key []u8, index u32) ! {
	use := roller.roll(index)!
	key << if use.recursive { u8(`R`) } else { u8(`C`) }
	append_type_key_u32(mut key, use.index)
}

fn (roller BinaryGroupRoller) serialize_value(mut key []u8, type_ BinaryValueType) ! {
	key << [u8(type_.kind), u8(type_.nullable)]
	if type_.kind == .type_use_reference { roller.serialize_use(mut key, type_.type_index)! }
}

fn (roller BinaryGroupRoller) serialize_field(mut key []u8, field BinaryFieldType) ! {
	roller.serialize_value(mut key, field.type_)!
	key << u8(field.mutable_)
}

fn (roller BinaryGroupRoller) serialize_type(mut key []u8, type_ BinaryDefinedType) ! {
	key << u8(type_.is_final)
	append_type_key_u32(mut key, u32(type_.supertypes.len))
	for index in type_.supertypes { roller.serialize_use(mut key, index)! }
	match type_.kind {
		.function_ {
			key << u8(`F`)
			append_type_key_u32(mut key, u32(type_.parameters.len))
			for value in type_.parameters { roller.serialize_value(mut key, value)! }
			append_type_key_u32(mut key, u32(type_.results.len))
			for value in type_.results { roller.serialize_value(mut key, value)! }
		}
		.struct_ {
			key << u8(`S`)
			append_type_key_u32(mut key, u32(type_.fields.len))
			for field in type_.fields { roller.serialize_field(mut key, field)! }
		}
		.array {
			key << u8(`A`)
			roller.serialize_field(mut key, type_.fields[0])!
		}
	}
}

fn (roller BinaryGroupRoller) substituted_index(index u32, base u32) !u32 {
	use := roller.roll(index)!
	return if use.recursive { base + use.index } else { use.index }
}

fn (roller BinaryGroupRoller) substituted_value(type_ BinaryValueType, base u32) !BinaryValueType {
	if type_.kind != .type_use_reference { return type_ }
	return BinaryValueType{ kind: .type_use_reference, type_index: roller.substituted_index(type_.type_index, base)!, nullable: type_.nullable }
}

fn (roller BinaryGroupRoller) substituted_type(type_ BinaryDefinedType, base u32) !BinaryDefinedType {
	mut supertypes := []u32{}
	for index in type_.supertypes { supertypes << roller.substituted_index(index, base)! }
	mut parameters := []BinaryValueType{}
	for value in type_.parameters { parameters << roller.substituted_value(value, base)! }
	mut results := []BinaryValueType{}
	for value in type_.results { results << roller.substituted_value(value, base)! }
	mut fields := []BinaryFieldType{}
	for field in type_.fields {
		fields << BinaryFieldType{ mutable_: field.mutable_, type_: roller.substituted_value(field.type_, base)! }
	}
	return BinaryDefinedType{ kind: type_.kind, parameters: parameters, results: results, fields: fields, supertypes: supertypes, is_final: type_.is_final }
}

fn (mut registry BinaryTypeRegistry) intern_group(types []BinaryDefinedType, group BinaryRecGroupSpan, resolved []&BinaryCanonicalType) ![]&BinaryCanonicalType {
	roller := BinaryGroupRoller{ group: group, resolved: resolved }
	mut key := []u8{}
	append_type_key_u32(mut key, group.count)
	for index in group.start .. group.start + group.count {
		roller.serialize_type(mut key, types[index])!
	}
	key_string := key.bytestr()
	registry.mutex.lock()
	defer { registry.mutex.unlock() }
	mut base := registry.interned_groups[key_string] or {
		u32(registry.types.len)
	}
	if key_string !in registry.interned_groups {
		for index in group.start .. group.start + group.count {
			mut sub_type := roller.substituted_type(types[index], base)!
			sub_type.rec_group = BinaryRecGroupSpan{ start: base, count: group.count }
			registry.types << &BinaryCanonicalType{ sub_type_: sub_type, registry_index_: base + index - group.start }
		}
		for index in 0 .. group.count {
			mut defined := registry.types[base + index]
			if defined.sub_type_.supertypes.len > 0 {
				super_index := defined.sub_type_.supertypes[0]
				if super_index >= base + index {
					return error('CompileError: Invalid supertype ${super_index}, supertypes must precede their subtypes')
				}
				defined.supertype_ = registry.types[super_index]
				defined.subtyping_depth_ = defined.supertype_.subtyping_depth_ + 1
				defined.ancestors_ << defined.supertype_.ancestors_
			}
			defined.ancestors_ << defined
		}
		registry.interned_groups[key_string] = base
	}
	mut result := []&BinaryCanonicalType{}
	for index in 0 .. group.count { result << registry.types[base + index] }
	return result
}

pub fn canonicalize_binary_module_types(types []BinaryDefinedType) ![]&BinaryCanonicalType {
	validate_binary_subtyping_depths(types)!
	mut resolved := []&BinaryCanonicalType{}
	mut type_index := u32(0)
	for u64(type_index) < u64(types.len) {
		group := types[type_index].rec_group
		if group.start != type_index || u64(group.start) + group.count > u64(types.len) {
			return error('CompileError: malformed recursive type group spans')
		}
		mut registry := binary_type_registry_
		resolved << registry.intern_group(types, group, resolved)!
		type_index += group.count
	}
	return resolved
}

pub fn canonicalized_binary_type(type_ BinaryValueType, context BinaryTypeContext) BinaryValueType {
	if type_.kind != .type_use_reference || context.types.len == 0 { return type_ }
	resolved := context.resolve(type_.type_index) or { panic('unresolved canonical type') }
	return BinaryValueType{ kind: .type_use_reference, type_index: resolved.registry_index_, nullable: type_.nullable }
}

pub fn canonicalize_binary_type(type_ BinaryDefinedType, context BinaryTypeContext) &BinaryCanonicalType {
	mut supertypes := []u32{}
	for index in type_.supertypes {
		resolved := context.resolve(index) or { panic('unresolved canonical supertype') }
		supertypes << resolved.registry_index_
	}
	mut parameters := []BinaryValueType{}
	for value in type_.parameters { parameters << canonicalized_binary_type(value, context) }
	mut results := []BinaryValueType{}
	for value in type_.results { results << canonicalized_binary_type(value, context) }
	mut fields := []BinaryFieldType{}
	for field in type_.fields {
		fields << BinaryFieldType{ mutable_: field.mutable_, type_: canonicalized_binary_type(field.type_, context) }
	}
	closed := BinaryDefinedType{ kind: type_.kind, parameters: parameters, results: results, fields: fields, supertypes: supertypes, is_final: type_.is_final, rec_group: BinaryRecGroupSpan{ count: 1 } }
	mut registry := binary_type_registry_
	// Preserve the pinned source's singleton intern_group(..., {0,1}, {}) call,
	// including VERIFY on failure for closed references outside that group.
	resolved := registry.intern_group([closed], BinaryRecGroupSpan{ count: 1 }, []) or { panic(err.msg()) }
	return resolved[0]
}
