// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Table.{h,cpp}.
module webassembly

import webidl

pub enum AddressType {
	i32
	i64
}

pub enum TableKind {
	externref
	anyfunc
}

pub fn table_kind_to_value_type(kind TableKind) ValueType {
	return match kind {
		.externref { .externref }
		.anyfunc { .anyfunc }
	}
}

pub struct TableDescriptor {
pub:
	element TableKind
	initial u64
	maximum ?u64
	address ?AddressType
}

@[heap]
pub struct Table {
pub:
	element       TableKind
	maximum       ?u64
	address_type_ AddressType
	cache_        &WebAssemblyCache
mut:
	elements []webidl.Value
}

pub fn Table.construct(descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	return table_construct_with_cache(get_cache(), descriptor, initial)
}

fn table_construct_with_cache(cache &WebAssemblyCache, descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	address_type := descriptor.address or { AddressType.i32 }
	if address_type == .i32 && descriptor.initial > u64(max_u32) {
		return error('TypeError: Table size is too large')
	}
	if maximum := descriptor.maximum {
		if address_type == .i32 && maximum > u64(max_u32) {
			return error('TypeError: Table size is too large')
		}
		if maximum < descriptor.initial {
			return error('RangeError: Maximum should not be less than initial in table type')
		}
	}
	if descriptor.initial > u64(max_int) {
		return error('RangeError: Wasm Table allocation failed')
	}
	default_value := if descriptor.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	value := validate_table_value(descriptor.element, initial or { default_value })!
	table_ := &Table{
		element: descriptor.element
		maximum: descriptor.maximum
		address_type_: address_type
		cache_: cache
		elements: []webidl.Value{len: int(descriptor.initial), init: value}
	}
	unsafe {
		cache.add_table_instance(table_.address(), table_)
	}
	return table_
}

pub fn Table.create(element_type ValueType, address_type AddressType, initial u64, maximum ?u64, reference webidl.Value) !&Table {
	return table_create_with_cache(get_cache(), element_type, address_type, initial, maximum, reference)
}

fn table_create_with_cache(cache &WebAssemblyCache, element_type ValueType, address_type AddressType, initial u64, maximum ?u64, reference webidl.Value) !&Table {
	element := match element_type {
		.externref { TableKind.externref }
		.anyfunc { TableKind.anyfunc }
		else {
			return error('TypeError: Table element type must be a reference type')
		}
	}
	return table_construct_with_cache(cache, TableDescriptor{
		element: element
		initial: initial
		maximum: maximum
		address: address_type
	}, reference)
}

pub fn Table.construct_impl(descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	return Table.construct(descriptor, initial)
}

pub fn (table &Table) address() u64 {
	return u64(voidptr(table))
}

pub fn (table &Table) cache() &WebAssemblyCache {
	return table.cache_
}

fn validate_table_value(kind TableKind, value webidl.Value) !webidl.Value {
	if kind == .anyfunc && value.kind !in [.null_, .callback] {
		return error('TypeError: anyfunc table values must be null or exported functions')
	}
	return value
}

pub fn (mut table Table) grow(delta u64, initial ?webidl.Value) !u64 {
	previous := table.length()
	if delta > u64(max_int) || previous > u64(max_int) - delta {
		return error('RangeError: Failed to grow table')
	}
	new_length := previous + delta
	if maximum := table.maximum {
		if new_length > maximum {
			return error('RangeError: Failed to grow table')
		}
	}
	default_value := if table.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	value := validate_table_value(table.element, initial or { default_value })!
	table.elements << []webidl.Value{len: int(delta), init: value}
	return previous
}

pub fn (table &Table) get(index u64) !webidl.Value {
	if index >= u64(table.elements.len) {
		return error('RangeError: Table element index out of range')
	}
	return table.elements[int(index)]
}

pub fn (mut table Table) set(index u64, value ?webidl.Value) ! {
	if index >= u64(table.elements.len) {
		return error('RangeError: Table element index out of range')
	}
	default_value := if table.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	table.elements[int(index)] = validate_table_value(table.element, value or { default_value })!
}

pub fn (table &Table) length() u64 {
	return u64(table.elements.len)
}

pub fn (table &Table) address_type() AddressType {
	return table.address_type_
}

pub fn (table &Table) element_type() ValueType {
	return table_kind_to_value_type(table.element)
}

pub fn address_type_from_bindings(address_type AddressType) AddressType {
	return address_type
}

pub fn address_value_to_u64(value webidl.Value, address_type AddressType) !u64 {
	if address_type == .i64 {
		if value.kind != .bigint {
			return error('TypeError: Table size requires a BigInt')
		}
		if value.bigint_value < 0 {
			return error('TypeError: Table size must be non-negative')
		}
		return u64(value.bigint_value)
	}
	// Table.cpp::AddressValueToU64 delegates i32 addresses to the unsigned-long
	// EnforceRange conversion, including ToNumber and truncation before bounds.
	number := webidl.convert_to_int(value, 32, false, .yes, .no)!
	return u64(number)
}

pub fn table_limit_to_js_value(value u64, address_type AddressType) webidl.Value {
	if address_type == .i64 {
		return webidl.bigint_value(i64(value))
	}
	return webidl.number_value(f64(u32(value)))
}

pub fn construct_table(descriptor TableDescriptor, value ?webidl.Value) !&Table {
	return Table.construct(descriptor, value)
}

pub fn construct_table_for_realm(realm string, descriptor TableDescriptor, value ?webidl.Value) !&Table {
	return table_construct_with_cache(get_cache_for_realm(realm), descriptor, value)
}

pub fn table(table_ &Table) &Table {
	return table_
}

pub fn value_to_table_reference(table_ &Table, value ?webidl.Value) !webidl.Value {
	default_value := if table_.element == .externref {
		webidl.undefined_value()
	} else {
		webidl.null_value()
	}
	return validate_table_value(table_.element, value or { default_value })
}
