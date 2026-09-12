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
	if type_ == .v128 {
		return error('TypeError: V128 is not supported')
	}
	return WasmValue{
		type_:     type_
		reference: if type_ == .externref { webidl.undefined_value() } else { webidl.null_value() }
	}
}

pub fn to_webassembly_value(value webidl.Value, type_ ValueType) !WasmValue {
	return match type_ {
		.i32 {
			if value.kind != .number { return error('TypeError: i32 requires a number') }
			WasmValue{
				type_:     type_
				i32_value: i32(value.number_value)
			}
		}
		.i64 {
			if value.kind != .bigint {
				return error('TypeError: i64 requires a BigInt')
			}
			WasmValue{
				type_:     type_
				i64_value: value.bigint_value
			}
		}
		.f32 {
			if value.kind != .number { return error('TypeError: f32 requires a number') }
			WasmValue{
				type_:     type_
				f32_value: f32(value.number_value)
			}
		}
		.f64 {
			if value.kind != .number { return error('TypeError: f64 requires a number') }
			WasmValue{
				type_:     type_
				f64_value: value.number_value
			}
		}
		.v128 {
			return error('TypeError: V128 is not supported')
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

pub struct GlobalType {
pub:
	value_type ValueType
	mutable_   bool
}

@[heap]
pub struct Global {
pub:
	type_    ValueType
	mutable_ bool
mut:
	stored WasmValue
}

pub fn Global.create(descriptor GlobalDescriptor, value WasmValue) !&Global {
	if descriptor.value == .v128 {
		return error('TypeError: V128 is not supported as a global value type')
	}
	if value.type_ != descriptor.value {
		return error('TypeError: Initial value does not match the global value type')
	}
	global := &Global{
		type_: descriptor.value
		mutable_: descriptor.mutable_
		stored: value
	}
	mut cache := get_cache()
	cache.add_global_instance(global.address(), global)
	return global
}

pub fn Global.construct(descriptor GlobalDescriptor, initial ?webidl.Value) !&Global {
	if descriptor.value == .v128 {
		return error('TypeError: V128 is not supported as a global value type')
	}
	stored := if value := initial {
		to_webassembly_value(value, descriptor.value)!
	} else {
		default_webassembly_value(descriptor.value)!
	}
	return Global.create(descriptor, stored)
}

pub fn Global.construct_impl(descriptor GlobalDescriptor, initial ?webidl.Value) !&Global {
	return Global.construct(descriptor, initial)
}

pub fn (global &Global) address() u64 {
	return u64(voidptr(global))
}

pub fn (global &Global) cache() &WebAssemblyCache {
	_ = global
	return get_cache()
}

pub fn (global &Global) type() GlobalType {
	return GlobalType{
		value_type: global.type_
		mutable_: global.mutable_
	}
}

pub fn (global &Global) value_type() !ValueType {
	if global.type_ == .v128 {
		return error('TypeError: V128 is not supported as a global value type')
	}
	return global.type_
}

pub fn global_descriptor_from_bindings(descriptor GlobalDescriptor) GlobalDescriptor {
	return descriptor
}

pub fn construct_global(descriptor GlobalDescriptor, value ?webidl.Value) !&Global {
	return Global.construct(global_descriptor_from_bindings(descriptor), value)
}

pub fn get_global_value(global &Global) !webidl.Value {
	if global.type_ == .v128 {
		return error('TypeError: V128 is not supported as a global value type')
	}
	return global.stored.to_webidl_value()
}

pub fn (global &Global) value() !webidl.Value {
	return get_global_value(global)
}

pub fn (global &Global) value_of() !webidl.Value {
	return get_global_value(global)
}

pub fn (mut global Global) set_value(value webidl.Value) ! {
	if !global.mutable_ {
		return error('TypeError: Cannot set the value of a const global')
	}
	global.stored = to_webassembly_value(value, global.type_)!
}
