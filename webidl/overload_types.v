// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/WebIDL/OverloadTypes.{h,cpp}.
module webidl

pub enum TypeKind {
	plain
	enumeration
	parameterized
	union
}

@[heap]
pub struct Type {
mut:
	kind_          TypeKind
	name_          string
	nullable_      bool
	parameterized_ ?&ParameterizedType
	union_         ?&UnionType
}

pub fn Type.new(name string, nullable bool) &Type {
	return &Type{
		kind_: .plain
		name_: name
		nullable_: nullable
	}
}

pub fn Type.new_enumeration(name string, nullable bool) &Type {
	return &Type{
		kind_: .enumeration
		name_: name
		nullable_: nullable
	}
}

pub fn (type_ &Type) is_plain() bool {
	return type_.kind_ == .plain
}

pub fn (type_ &Type) is_enumeration() bool {
	return type_.kind_ == .enumeration
}

pub fn (type_ &Type) is_parameterized() bool {
	return type_.kind_ == .parameterized
}

pub fn (type_ &Type) as_parameterized() &ParameterizedType {
	return type_.parameterized_ or { panic('WebIDL type is not parameterized') }
}

pub fn (type_ &Type) is_union() bool {
	return type_.kind_ == .union
}

pub fn (type_ &Type) as_union() &UnionType {
	return type_.union_ or { panic('WebIDL type is not a union') }
}

pub fn (type_ &Type) name() string {
	return type_.name_
}

pub fn (type_ &Type) is_nullable() bool {
	return type_.nullable_
}

pub fn (type_ &Type) includes_nullable_type() bool {
	if type_.is_nullable() {
		return true
	}
	if type_.is_union() && type_.as_union().number_of_nullable_member_types() == 1 {
		return true
	}
	return false
}

pub fn (type_ &Type) includes_undefined() bool {
	if type_.is_undefined() {
		return true
	}
	if type_.is_union() {
		for member in type_.as_union().member_types() {
			if member.includes_undefined() {
				return true
			}
		}
	}
	return false
}

pub fn (type_ &Type) is_any() bool {
	return type_.is_plain() && type_.name_ == 'any'
}

pub fn (type_ &Type) is_undefined() bool {
	return type_.is_plain() && type_.name_ == 'undefined'
}

pub fn (type_ &Type) is_boolean() bool {
	return type_.is_plain() && type_.name_ == 'boolean'
}

pub fn (type_ &Type) is_bigint() bool {
	return type_.is_plain() && type_.name_ == 'bigint'
}

pub fn (type_ &Type) is_object() bool {
	return type_.is_plain() && type_.name_ == 'object'
}

pub fn (type_ &Type) is_symbol() bool {
	return type_.is_plain() && type_.name_ == 'symbol'
}

pub fn (type_ &Type) is_string() bool {
	return type_.is_enumeration() || (type_.is_plain()
		&& type_.name_ in ['ByteString', 'DOMString', 'USVString'])
}

pub fn (type_ &Type) is_integer() bool {
	return type_.is_plain() && type_.name_ in ['byte', 'octet', 'short', 'unsigned short', 'long',
		'unsigned long', 'long long', 'unsigned long long']
}

pub fn (type_ &Type) is_numeric() bool {
	return type_.is_plain() && (type_.is_integer() || type_.is_floating_point())
}

pub fn (type_ &Type) is_sequence() bool {
	return type_.is_parameterized() && type_.name_ == 'sequence'
}

pub fn (type_ &Type) is_buffer() bool {
	return type_.name_ in ['ArrayBuffer', 'SharedArrayBuffer']
}

pub fn (type_ &Type) is_typed_array() bool {
	return type_.name_ in ['Int8Array', 'Int16Array', 'Int32Array', 'Uint8Array', 'Uint16Array',
		'Uint32Array', 'Uint8ClampedArray', 'BigInt64Array', 'BigUint64Array', 'Float16Array',
		'Float32Array', 'Float64Array']
}

pub fn (type_ &Type) is_buffer_view() bool {
	return type_.name_ == 'DataView' || type_.is_typed_array()
}

pub fn (type_ &Type) is_buffer_source() bool {
	return type_.is_buffer() || type_.is_buffer_view()
}

pub fn (type_ &Type) is_restricted_floating_point() bool {
	return type_.name_ in ['float', 'double']
}

pub fn (type_ &Type) is_unrestricted_floating_point() bool {
	return type_.name_ in ['unrestricted float', 'unrestricted double']
}

pub fn (type_ &Type) is_floating_point() bool {
	return type_.is_restricted_floating_point() || type_.is_unrestricted_floating_point()
}

@[heap]
pub struct ParameterizedType {
	Type
mut:
	parameters_ []&Type
}

pub fn ParameterizedType.new(name string, nullable bool, parameters []&Type) &ParameterizedType {
	mut parameterized := &ParameterizedType{
		Type: Type{
			kind_: .parameterized
			name_: name
			nullable_: nullable
		}
		parameters_: parameters.clone()
	}
	parameterized.Type.parameterized_ = parameterized
	return parameterized
}

pub fn (type_ &ParameterizedType) parameters() []&Type {
	return type_.parameters_.clone()
}

@[heap]
pub struct UnionType {
	Type
mut:
	member_types_ []&Type
}

pub fn UnionType.new(name string, nullable bool, member_types []&Type) &UnionType {
	mut union_type := &UnionType{
		Type: Type{
			kind_: .union
			name_: name
			nullable_: nullable
		}
		member_types_: member_types.clone()
	}
	union_type.Type.union_ = union_type
	return union_type
}

pub fn (type_ &UnionType) member_types() []&Type {
	return type_.member_types_.clone()
}

pub fn (type_ &UnionType) flattened_member_types() []&Type {
	mut types := []&Type{}
	for member in type_.member_types_ {
		if member.is_union() {
			types << member.as_union().flattened_member_types()
		} else {
			types << member
		}
	}
	return types
}

pub fn (type_ &UnionType) number_of_nullable_member_types() uint {
	mut count := uint(0)
	for member in type_.member_types_ {
		if member.is_nullable() {
			count++
		}
		if member.is_union() {
			count += member.as_union().number_of_nullable_member_types()
		}
	}
	return count
}

pub enum Optionality {
	required
	optional
	variadic
}

pub struct EffectiveOverloadSetItem {
pub:
	callable_id        int
	types              []&Type
	optionality_values []Optionality
}

pub struct EffectiveOverloadSet {
mut:
	items_                         []EffectiveOverloadSetItem
	distinguishing_argument_index_ uint
	last_matching_item_index_      ?int
}

pub fn EffectiveOverloadSet.new(items []EffectiveOverloadSetItem, distinguishing_argument_index uint) EffectiveOverloadSet {
	return EffectiveOverloadSet{
		items_: items.clone()
		distinguishing_argument_index_: distinguishing_argument_index
	}
}

pub fn (set &EffectiveOverloadSet) items() []EffectiveOverloadSetItem {
	return set.items_.clone()
}

pub fn (set &EffectiveOverloadSet) only_item() EffectiveOverloadSetItem {
	assert set.items_.len == 1
	return set.items_[0]
}

pub fn (set &EffectiveOverloadSet) is_empty() bool {
	return set.items_.len == 0
}

pub fn (set &EffectiveOverloadSet) size() uint {
	return uint(set.items_.len)
}

pub fn (set &EffectiveOverloadSet) distinguishing_argument_index() uint {
	return set.distinguishing_argument_index_
}

pub fn (mut set EffectiveOverloadSet) has_overload_with_matching_argument_at_index(index uint, matches fn (&Type, Optionality) bool) bool {
	for item_index, item in set.items_ {
		if index >= uint(item.types.len) || index >= uint(item.optionality_values.len) {
			continue
		}
		if matches(item.types[index], item.optionality_values[index]) {
			set.last_matching_item_index_ = item_index
			return true
		}
	}
	set.last_matching_item_index_ = none
	return false
}

pub fn (mut set EffectiveOverloadSet) remove_all_other_entries() {
	index := set.last_matching_item_index_ or {
		panic('no matching overload was selected')
	}
	set.items_ = [set.items_[index]]
}
