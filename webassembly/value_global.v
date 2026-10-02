// Copyright (c) 2024, Andrew Kaster <andrew@ladybird.org>
// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Global.{h,cpp} and value conversion helpers.
module webassembly

import webidl

pub enum ValueType {
	i32
	i64
	f32
	f64
	v128
	externref
	anyfunc
}

pub fn value_type_string(value ValueType) string {
	return match value {
		.i32 { 'i32' }
		.i64 { 'i64' }
		.f32 { 'f32' }
		.f64 { 'f64' }
		.v128 { 'v128' }
		.externref { 'externref' }
		.anyfunc { 'anyfunc' }
	}
}

pub fn to_value_type(type_ ValueType) ValueType {
	return type_
}

pub struct WasmValue {
pub:
	type_     ValueType
	i32_value i32
	i64_value i64
	f32_value f32
	f64_value f64
	reference webidl.Value
}

pub fn default_webassembly_value(type_ ValueType) !WasmValue {
	return WasmValue{
		type_:     type_
		reference: if type_ == .externref { webidl.undefined_value() } else { webidl.null_value() }
	}
}

pub fn to_webassembly_value(value webidl.Value, type_ ValueType) !WasmValue {
	return match type_ {
		.i32 {
			// WebAssembly.cpp delegates to JS::Value::to_i32. The WebIDL
			// signed, non-enforced 32-bit conversion uses that same ToInt32
			// algorithm after ToNumber, including wrapping and nonfinite zero.
			number := webidl.convert_to_int(value, 32, true, .no, .no)!
			WasmValue{
				type_:     type_
				i32_value: i32(number)
			}
		}
		.i64 {
			integer := webidl.value_to_bigint_int64(value)!
			WasmValue{
				type_:     type_
				i64_value: integer
			}
		}
		.f32 {
			number := webidl.value_to_number(value)!
			WasmValue{
				type_:     type_
				f32_value: f32(number)
			}
		}
		.f64 {
			number := webidl.value_to_number(value)!
			WasmValue{
				type_:     type_
				f64_value: number
			}
		}
		.v128 {
			return error('TypeError: Cannot convert a vector value to a javascript value')
		}
		.externref {
			WasmValue{
				type_:     type_
				reference: value
			}
		}
		.anyfunc {
			if value.kind !in [.null_, .callback] {
				return error('TypeError: anyfunc requires null or an exported function')
			}
			WasmValue{
				type_:     type_
				reference: value
			}
		}
	}
}

pub fn (value WasmValue) to_webidl_value() !webidl.Value {
	return match value.type_ {
		.i32 { webidl.number_value(value.i32_value) }
		.i64 { webidl.bigint_value(value.i64_value) }
		.f32 { webidl.number_value(f64(value.f32_value)) }
		.f64 { webidl.number_value(value.f64_value) }
		.v128 { return error('TypeError: V128 is not supported') }
		.externref, .anyfunc { value.reference }
	}
}

pub struct GlobalDescriptor {
pub:
	value    ValueType
	mutable_ bool
}

@[heap]
pub struct Global {
pub:
	cache_   &WebAssemblyCache
	address_ u64
}

pub fn Global.create(descriptor GlobalDescriptor, value WasmValue) !&Global {
	return global_create_with_cache(get_cache(), descriptor, value)
}

fn global_create_with_cache(cache &WebAssemblyCache, descriptor GlobalDescriptor, value WasmValue) !&Global {
	if descriptor.value == .v128 {
		return error('TypeError: V128 is not supported as a global value type')
	}
	if value.type_ != descriptor.value {
		return error('TypeError: Initial value does not match the global value type')
	}
	machine_value := machine_global_value_from_binding(cache, value)!
	mut store := cache.abstract_machine_.store()
	address := store.allocate_global(BinaryGlobalType{
		type_:    binary_type_for_global_binding(descriptor.value)
		mutable_: descriptor.mutable_
	}, machine_value) or { return error('TypeError: Wasm Global allocation failed') }
	return Global.create_for_store_address(cache, address)
}

// Global.cpp's address-taking factory. The actual Store owns the value and
// type; a wrapper retains only its owning cache and vector-index address.
pub fn Global.create_for_store_address(cache &WebAssemblyCache, address u64) &Global {
	if cache.get_global_instance(address) != none { panic('Global address already has a wrapper') }
	global := &Global{ cache_: cache, address_: address }
	unsafe { cache.add_global_instance(address, global) }
	return global
}

pub fn Global.construct(descriptor GlobalDescriptor, initial ?webidl.Value) !&Global {
	return global_construct_with_cache(get_cache(), descriptor, initial)
}

fn global_construct_with_cache(cache &WebAssemblyCache, descriptor GlobalDescriptor, initial ?webidl.Value) !&Global {
	stored := if value := initial {
		to_webassembly_value(value, descriptor.value)!
	} else {
		default_webassembly_value(descriptor.value)!
	}
	return global_create_with_cache(cache, descriptor, stored)
}

pub fn Global.construct_impl(descriptor GlobalDescriptor, initial ?webidl.Value) !&Global {
	return Global.construct(descriptor, initial)
}

pub fn (global &Global) address() u64 {
	return global.address_
}

pub fn (global &Global) cache() &WebAssemblyCache {
	return global.cache_
}

pub fn (global &Global) machine_instance() !&BinaryMachineGlobalInstance {
	return global.cache_.abstract_machine_.store().get_global(global.address()) or {
		return error('RangeError: Could not find the global instance')
	}
}

pub fn (global &Global) type() !BinaryGlobalType {
	instance := global.machine_instance()!
	return instance.type_()
}

pub fn (global &Global) value_type() !BinaryValueType {
	type_ := global.type()!
	if type_.type_.kind == .v128 {
		return error('TypeError: V128 is not supported as a global value type')
	}
	return type_.type_
}

// Source Global::value(); value()/value_of() below are the JS binding adapter.
pub fn (global &Global) machine_value() !BinaryMachineValue {
	instance := global.machine_instance()!
	global.value_type()!
	return instance.value()
}

// Source Global::set_value(Wasm::Value), also used by imported Store globals.
pub fn (global &Global) set_machine_value(value BinaryMachineValue) ! {
	mut instance := global.machine_instance()!
	type_ := global.type()!
	if type_.type_.kind == .v128 {
		return error('TypeError: Cannot set the value of a V128 global')
	}
	if !type_.mutable_ {
		return error('TypeError: Cannot set the value of a const global')
	}
	instance.set_value(value)
}

pub fn global_descriptor_from_bindings(descriptor GlobalDescriptor) GlobalDescriptor {
	return descriptor
}

pub fn construct_global(descriptor GlobalDescriptor, value ?webidl.Value) !&Global {
	return Global.construct(global_descriptor_from_bindings(descriptor), value)
}

pub fn construct_global_for_realm(realm string, descriptor GlobalDescriptor, value ?webidl.Value) !&Global {
	return global_construct_with_cache(get_cache_for_realm(realm), global_descriptor_from_bindings(descriptor), value)
}

pub fn get_global_value(global &Global) !webidl.Value {
	value := global.machine_value()!
	type_ := global.value_type()!
	return machine_global_value_to_binding(global.cache_, value, type_)!
}

pub fn (global &Global) value() !webidl.Value {
	return get_global_value(global)
}

pub fn (global &Global) value_of() !webidl.Value {
	return get_global_value(global)
}

pub fn (mut global Global) set_value(value webidl.Value) ! {
	type_ := global.type()!
	if type_.type_.kind == .v128 {
		return error('TypeError: Cannot set the value of a V128 global')
	}
	if !type_.mutable_ {
		return error('TypeError: Cannot set the value of a const global')
	}
	converted := to_webassembly_value(value, global_binding_type(type_.type_)!)!
	machine_value := machine_global_value_from_binding(global.cache_, converted)!
	global.set_machine_value(machine_value)!
}

fn binary_type_for_global_binding(type_ ValueType) BinaryValueType {
	return BinaryValueType{
		kind: match type_ {
			.i32 { BinaryValueKind.i32 }
			.i64 { BinaryValueKind.i64 }
			.f32 { BinaryValueKind.f32 }
			.f64 { BinaryValueKind.f64 }
			.v128 { BinaryValueKind.v128 }
			.externref { BinaryValueKind.extern_reference }
			.anyfunc { BinaryValueKind.function_reference }
		}
	}
}

fn global_binding_type(type_ BinaryValueType) !ValueType {
	return match type_.kind {
		.i32 { ValueType.i32 }
		.i64 { ValueType.i64 }
		.f32 { ValueType.f32 }
		.f64 { ValueType.f64 }
		.v128 { ValueType.v128 }
		.extern_reference { ValueType.externref }
		.function_reference { ValueType.anyfunc }
		else { return error('TypeError: Unsupported heap reference') }
	}
}

// WebAssembly.cpp's value conversion into the actual untyped machine record.
// Externs use the owning cache. Genuine exported function objects and their
// defining-module lookup require the untranslated function Store/JS adapter;
// a plain typed callback marker does not pass the source exported-function brand.
fn machine_global_value_from_binding(cache &WebAssemblyCache, value WasmValue) !BinaryMachineValue {
	return match value.type_ {
		.i32 { BinaryMachineValue.from_i32(value.i32_value) }
		.i64 { BinaryMachineValue.from_i64(value.i64_value) }
		.f32 { BinaryMachineValue.from_f32(value.f32_value) }
		.f64 { BinaryMachineValue.from_f64(value.f64_value) }
		.v128 { BinaryMachineValue{} }
		.anyfunc {
			if value.reference.kind != .null_ {
				return error('TypeError: anyfunc requires null or an exported function')
			}
			BinaryMachineValue.from_type(BinaryValueType{ kind: .function_reference })
		}
		.externref {
			if value.reference.kind == .null_ {
				return BinaryMachineValue.from_type(BinaryValueType{ kind: .extern_reference })
			}
			mut address := u64(0)
			if existing := cache.get_extern_address(value.reference) {
				address = existing
			} else {
				address = u64(cache.extern_values_.len)
				unsafe { cache.add_extern_value(address, value.reference) }
			}
			BinaryMachineValue.from_reference(BinaryExternReference{ address: address })
		}
	}
}

fn machine_global_value_to_binding(cache &WebAssemblyCache, value BinaryMachineValue, type_ BinaryValueType) !webidl.Value {
	return match type_.kind {
		.i32 { webidl.number_value(value.to_i32()) }
		.i64 { webidl.bigint_value(value.to_i64()) }
		.f32 { webidl.number_value(f64(value.to_f32())) }
		.f64 { webidl.number_value(value.to_f64()) }
		.extern_reference, .function_reference {
			reference := value.to_reference()
			match reference {
				BinaryNullReference { return webidl.null_value() }
				BinaryExternReference {
					return cache.get_extern_value(reference.address) or {
						return error('RangeError: Could not find the external reference')
					}
				}
				else { return error('TypeError: anyfunc requires null or an exported function') }
			}
		}
		else { return error('TypeError: Unsupported heap reference') }
	}
}
