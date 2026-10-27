// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Table.{h,cpp}.
module webassembly

import webidl
import libjs
import math.big
import strconv

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
	cache_   &WebAssemblyCache
	address_ u64
}

pub fn Table.construct(descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	return table_construct_with_cache(get_cache(), descriptor, initial)
}

fn table_construct_with_cache(cache &WebAssemblyCache, descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	address_type := descriptor.address or { AddressType.i32 }
	// The typed descriptor already contains converted u64 limits. Retain the
	// i32 binding range gate before converting its optional reference value.
	if address_type == .i32 && descriptor.initial > u64(max_u32) {
		return error('TypeError: Table size is too large')
	}
	if maximum := descriptor.maximum {
		if address_type == .i32 && maximum > u64(max_u32) {
			return error('TypeError: Table size is too large')
		}
	}
	element_type := table_kind_to_value_type(descriptor.element)
	value := if supplied := initial {
		to_webassembly_value(supplied, element_type)!
	} else {
		default_webassembly_value(element_type)!
	}
	reference := machine_global_value_from_binding(cache, value)!.to_reference()
	return Table.create_machine(cache, binary_type_for_global_binding(element_type), address_type,
		descriptor.initial, descriptor.maximum, reference)
}

// Table.cpp's source factory allocates and fills the actual Store table.
pub fn Table.create_machine(cache &WebAssemblyCache, element_type BinaryValueType, address_type AddressType, initial u64, maximum ?u64, reference BinaryMachineReference) !&Table {
	if limit := maximum {
		if limit < initial {
			return error('RangeError: Maximum should not be less than initial in table type')
		}
	}
	mut store := cache.abstract_machine_.store()
	address := store.allocate_table(BinaryTableType{
		element_type: element_type
		limits:       WasmLimits{ address_type: address_type, minimum: initial, maximum: maximum }
	}) or { return error('RangeError: Wasm Table allocation failed') }
	mut instance := store.get_table(address) or { panic('allocated table missing from Store') }
	for index in 0 .. instance.elements().values.len {
		instance.set_element(uint(index), reference, unsafe { nil })
	}
	return Table.create_for_store_address(cache, address)
}

pub fn Table.create_for_store_address(cache &WebAssemblyCache, address u64) &Table {
	if cache.get_table_instance(address) != none { panic('Table address already has a wrapper') }
	table_ := &Table{ cache_: cache, address_: address }
	unsafe { cache.add_table_instance(address, table_) }
	return table_
}

pub fn Table.create(element_type ValueType, address_type AddressType, initial u64, maximum ?u64, reference webidl.Value) !&Table {
	if element_type !in [.externref, .anyfunc] {
		return error('TypeError: Table element type must be a reference type')
	}
	cache := get_cache()
	value := to_webassembly_value(reference, element_type)!
	machine_reference := machine_global_value_from_binding(cache, value)!.to_reference()
	return Table.create_machine(cache, binary_type_for_global_binding(element_type), address_type,
		initial, maximum, machine_reference)
}

pub fn Table.construct_impl(descriptor TableDescriptor, initial ?webidl.Value) !&Table {
	return Table.construct(descriptor, initial)
}

pub fn (table &Table) address() u64 { return table.address_ }

pub fn (table &Table) cache() &WebAssemblyCache { return table.cache_ }

pub fn (table &Table) machine_instance() !&BinaryMachineTableInstance {
	return table.cache_.abstract_machine_.store().get_table(table.address()) or {
		return error('RangeError: Could not find the memory table')
	}
}

pub fn (table &Table) grow_reference(delta u64, reference BinaryMachineReference) !u64 {
	mut instance := table.cache_.abstract_machine_.store().get_table(table.address()) or {
		return error('RangeError: Could not find the memory table to grow')
	}
	previous := u64(instance.elements().values.len)
	// Pinned Table::grow(u64) calls TableInstance::grow(u32). Preserve its
	// narrowing, including a 2^32 delta becoming zero, rather than changing it.
	grew := instance.grow(u32(delta), reference, unsafe { nil })
	if !grew { return error('RangeError: Failed to grow table') }
	return previous
}

pub fn (table &Table) get_reference(index u64) !BinaryMachineReference {
	mut instance := table.machine_instance()!
	if instance.type_().element_type.kind == .exception_reference {
		return error('TypeError: Cannot get an exnref table element')
	}
	if u64(instance.elements().values.len) <= index {
		return error('RangeError: Table element index out of range')
	}
	return instance.elements().values[int(index)]
}

pub fn (table &Table) set_reference(index u64, reference BinaryMachineReference) ! {
	mut instance := table.machine_instance()!
	if instance.type_().element_type.kind == .exception_reference {
		return error('TypeError: Cannot set an exnref table element')
	}
	if u64(instance.elements().values.len) <= index {
		return error('RangeError: Table element index out of range')
	}
	instance.set_element(uint(index), reference, unsafe { nil })
}

pub fn (table &Table) grow(delta u64, initial ?webidl.Value) !u64 {
	reference := value_to_table_reference(table, initial)!
	return table.grow_reference(delta, reference)!
}

pub fn (table &Table) get(index u64) !webidl.Value {
	reference := table.get_reference(index)!
	element_type := table.element_type()!
	return machine_global_value_to_binding(table.cache_, BinaryMachineValue.from_reference(reference), element_type)!
}

pub fn (table &Table) set(index u64, value ?webidl.Value) ! {
	reference := value_to_table_reference(table, value)!
	table.set_reference(index, reference)!
}

pub fn (table &Table) length() !u64 {
	mut instance := table.machine_instance()!
	return u64(instance.elements().values.len)
}

pub fn (table &Table) address_type() !AddressType {
	instance := table.machine_instance()!
	return instance.type_().limits.address_type
}

pub fn (table &Table) element_type() !BinaryValueType {
	instance := table.machine_instance()!
	return instance.type_().element_type
}

// The actual JS binding order is address type, address conversion, reference
// conversion and finally the Store operation. The typed u64 methods above
// remain useful once an embedding has performed address conversion already.
pub fn (table &Table) grow_from_bindings(delta webidl.Value, initial ?webidl.Value) !webidl.Value {
	address_type := table.address_type()!
	converted_delta := address_value_to_u64(delta, address_type)!
	reference := value_to_table_reference(table, initial)!
	previous := table.grow_reference(converted_delta, reference)!
	return table_limit_to_js_value(previous, address_type)
}

pub fn (table &Table) get_from_bindings(index webidl.Value) !webidl.Value {
	address_type := table.address_type()!
	converted_index := address_value_to_u64(index, address_type)!
	return table.get(converted_index)!
}

pub fn (table &Table) set_from_bindings(index webidl.Value, value ?webidl.Value) ! {
	address_type := table.address_type()!
	converted_index := address_value_to_u64(index, address_type)!
	reference := value_to_table_reference(table, value)!
	table.set_reference(converted_index, reference)!
}

pub fn (table &Table) length_from_bindings() !webidl.Value {
	address_type := table.address_type()!
	length := table.length()!
	return table_limit_to_js_value(length, address_type)
}

pub fn address_type_from_bindings(address_type AddressType) AddressType {
	return address_type
}

pub fn address_value_to_u64(value webidl.Value, address_type AddressType) !u64 {
	if address_type == .i64 {
		integer := webidl.value_to_bigint(value)!
		if integer.big_integer.signum < 0 {
			return error('TypeError: Table size must be non-negative')
		}
		// Table.cpp converts the complete base-10 integer into u64 after
		// checking its sign. Never wrap modulo 2^64 before the bound check.
		return strconv.parse_uint(integer.big_integer.str(), 10, 64) or {
			return error('TypeError: Table size is too large')
		}
	}
	// Table.cpp::AddressValueToU64 delegates i32 addresses to the unsigned-long
	// EnforceRange conversion, including ToNumber and truncation before bounds.
	number := webidl.convert_to_int(value, 32, false, .yes, .no)!
	return u64(number)
}

pub fn table_limit_to_js_value(value u64, address_type AddressType) webidl.Value {
	if address_type == .i64 {
		return webidl.bigint_value_for_record(libjs.BigInt.create(big.integer_from_u64(value)))
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

pub fn value_to_table_reference(table_ &Table, value ?webidl.Value) !BinaryMachineReference {
	element_type := table_.element_type()!
	// Detail::to_webassembly_value ignores the given JS value for exnref and
	// returns its typed null. The actual get/set operation rejects this type.
	if element_type.kind == .exception_reference {
		return BinaryNullReference{ type_: element_type }
	}
	binding_type := global_binding_type(element_type)!
	converted := if supplied := value {
		to_webassembly_value(supplied, binding_type)!
	} else {
		default_webassembly_value(binding_type)!
	}
	return machine_global_value_from_binding(table_.cache_, converted)!.to_reference()
}
