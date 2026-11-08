// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the WebAssemblyCache and host/runtime helpers in
// WebAssembly/WebAssembly.{h,cpp}. LibWasm execution remains the platform
// boundary, while cache identity and JS API conversion semantics live here.
@[has_globals]
module webassembly

import webidl
import math

pub type HostEnsureCanCompileWasmBytesHook = fn () !

pub type HostCallable = fn ([]webidl.Value) !webidl.Value

pub struct FunctionType {
pub:
	parameters []ValueType
	results    []ValueType
}

pub struct HostFunction {
pub:
	realm          string
	type_          FunctionType
	function_index uint
	callable       HostCallable @[required]
}

pub fn (function HostFunction) invoke(arguments []WasmValue) ![]WasmValue {
	if arguments.len != function.type_.parameters.len {
		return error('RuntimeError: Host function expected ${function.type_.parameters.len} arguments, got ${arguments.len}')
	}
	mut argument_values := []webidl.Value{cap: arguments.len}
	for index, argument in arguments {
		if argument.type_ != function.type_.parameters[index] {
			return error('TypeError: Host function argument ${index} has the wrong WebAssembly type')
		}
		argument_values << to_js_value(argument)!
	}
	result := function.callable(argument_values)!
	if function.type_.results.len == 0 {
		return []WasmValue{}
	}
	if function.type_.results.len == 1 {
		return [to_webassembly_value(result, function.type_.results[0])!]
	}
	if result.kind != .sequence {
		return error('TypeError: Multi-value WebAssembly host function result is not iterable')
	}
	if result.sequence_value.len != function.type_.results.len {
		return error('TypeError: Invalid number of return values for multi-value WebAssembly return: expected ${function.type_.results.len}, got ${result.sequence_value.len}')
	}
	mut values := []WasmValue{cap: result.sequence_value.len}
	for index, value in result.sequence_value {
		values << to_webassembly_value(value, function.type_.results[index])!
	}
	return values
}

pub fn create_host_function(realm string, callable HostCallable, type_ FunctionType, function_index uint) HostFunction {
	return HostFunction{
		realm: realm
		type_: type_
		function_index: function_index
		callable: callable
	}
}

__global (
	webassembly_global_cache                 &WebAssemblyCache
	host_ensure_can_compile_wasm_bytes_hook_ ?HostEnsureCanCompileWasmBytesHook = none
)
__global (
	webassembly_realm_caches = map[string]&WebAssemblyCache{}
	webassembly_live_caches_ = []&WebAssemblyCache{}
)

pub struct AbstractMachine {
mut:
	store_ &BinaryMachineStore = BinaryMachineStore.create()
pub mut:
	compiled_modules u64
	instances        u64
}

pub fn (machine &AbstractMachine) store() &BinaryMachineStore { return machine.store_ }

@[heap]
pub struct ExportedWasmFunction {
pub:
	name  string
	realm string
mut:
	exported_address_ u64
}

pub fn ExportedWasmFunction.create(name string, exported_address u64) &ExportedWasmFunction {
	return ExportedWasmFunction.create_for_realm('default', name, exported_address)
}

pub fn ExportedWasmFunction.create_for_realm(realm string, name string, exported_address u64) &ExportedWasmFunction {
	return &ExportedWasmFunction{
		name: name
		realm: realm
		exported_address_: exported_address
	}
}

pub fn (function &ExportedWasmFunction) exported_address() u64 {
	return function.exported_address_
}

@[heap]
pub struct WebAssemblyCache {
mut:
	function_instances_ map[u64]&ExportedWasmFunction
	extern_values_      map[u64]webidl.Value
	inverse_extern_     map[string]u64
	global_instances_   map[u64]&Global
	memory_instances_   map[u64]&Memory
	table_instances_    map[u64]&Table
	compiled_modules_   []&Module
	imported_objects_   []webidl.Value
	abstract_machine_   AbstractMachine
}

pub fn WebAssemblyCache.create() &WebAssemblyCache {
	cache := &WebAssemblyCache{
		function_instances_: map[u64]&ExportedWasmFunction{}
		extern_values_: map[u64]webidl.Value{}
		inverse_extern_: map[string]u64{}
		global_instances_: map[u64]&Global{}
		memory_instances_: map[u64]&Memory{}
		table_instances_: map[u64]&Table{}
	}
	webassembly_live_caches_ << cache
	return cache
}

pub fn get_cache() &WebAssemblyCache {
	return get_cache_for_realm('default')
}

pub fn get_cache_for_realm(realm string) &WebAssemblyCache {
	if cache := webassembly_realm_caches[realm] {
		return cache
	}
	mut cache := WebAssemblyCache.create()
	webassembly_realm_caches[realm] = cache
	if realm == 'default' {
		webassembly_global_cache = cache
	}
	return cache
}

pub fn live_caches() []&WebAssemblyCache {
	return webassembly_live_caches_.clone()
}

pub fn (mut cache WebAssemblyCache) add_compiled_module(module_ &Module) {
	cache.compiled_modules_ << module_
	cache.abstract_machine_.compiled_modules++
}

pub fn (mut cache WebAssemblyCache) add_function_instance(address u64, function &ExportedWasmFunction) {
	cache.function_instances_[address] = function
}

pub fn (mut cache WebAssemblyCache) add_imported_object(object webidl.Value) {
	cache.imported_objects_ << object
}

fn extern_value_key(value webidl.Value) ?string {
	// WebAssemblyCache's JS::Value keys use primitive value/actual cell identity,
	// not an object's properties or its platform class. Typed DTOs without a
	// retained object record cannot provide that identity, so they remain
	// distinct retained extern entries rather than aliasing by category/content.
	return match value.kind {
		.undefined, .null_ { value.kind.str() }
		.boolean { '${value.kind}:${value.boolean_value}' }
		.number {
			if math.is_nan(value.number_value) {
				'number:NaN'
			} else {
				'number:${math.f64_bits(value.number_value)}'
			}
		}
		.bigint {
			if integer := value.bigint_record_ {
				'${value.kind}:${integer.big_integer.str()}'
			} else {
				'${value.kind}:${value.bigint_value}'
			}
		}
		.string_ { '${value.kind}:${value.string_value}' }
		.object, .sequence, .buffer_source, .callback, .platform_object {
			if value.opaque_id == 0 { return none }
			'${value.kind}:${value.opaque_id}'
		}
		.promise {
			promise := value.promise_value_ or { return none }
			'promise:${u64(voidptr(promise))}'
		}
		.runtime_value {
			actual := value.runtime_value_ or { return none }
			'runtime:${u64(actual.context)}:${u64(actual.value)}'
		}
	}
}

pub fn (mut cache WebAssemblyCache) add_extern_value(address u64, value webidl.Value) {
	if old := cache.extern_values_[address] {
		if key := extern_value_key(old) { cache.inverse_extern_.delete(key) }
	}
	cache.extern_values_[address] = value
	if key := extern_value_key(value) { cache.inverse_extern_[key] = address }
}

pub fn (cache &WebAssemblyCache) get_extern_address(value webidl.Value) ?u64 {
	key := extern_value_key(value) or { return none }
	return cache.inverse_extern_[key] or { return none }
}

pub fn (mut cache WebAssemblyCache) add_global_instance(address u64, global &Global) {
	cache.global_instances_[address] = global
}

pub fn (mut cache WebAssemblyCache) add_memory_instance(address u64, memory &Memory) {
	cache.memory_instances_[address] = memory
}

pub fn (mut cache WebAssemblyCache) add_table_instance(address u64, table &Table) {
	cache.table_instances_[address] = table
}

pub fn (cache &WebAssemblyCache) get_function_instance(address u64) ?&ExportedWasmFunction {
	return cache.function_instances_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) get_extern_value(address u64) ?webidl.Value {
	return cache.extern_values_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) get_global_instance(address u64) ?&Global {
	return cache.global_instances_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) get_memory_instance(address u64) ?&Memory {
	return cache.memory_instances_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) get_table_instance(address u64) ?&Table {
	return cache.table_instances_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) function_instances() map[u64]&ExportedWasmFunction {
	return cache.function_instances_.clone()
}

pub fn (cache &WebAssemblyCache) extern_values() map[u64]webidl.Value {
	return cache.extern_values_.clone()
}

pub fn (cache &WebAssemblyCache) inverse_extern_values() map[string]u64 {
	return cache.inverse_extern_.clone()
}

pub fn (cache &WebAssemblyCache) global_instances() map[u64]&Global {
	return cache.global_instances_.clone()
}

pub fn (cache &WebAssemblyCache) memory_instances() map[u64]&Memory {
	return cache.memory_instances_.clone()
}

pub fn (cache &WebAssemblyCache) table_instances() map[u64]&Table {
	return cache.table_instances_.clone()
}

pub fn (cache &WebAssemblyCache) imported_objects() []webidl.Value {
	return cache.imported_objects_.clone()
}

pub fn (mut cache WebAssemblyCache) abstract_machine() &AbstractMachine {
	return &cache.abstract_machine_
}

pub fn compile_a_webassembly_module(bytes []u8) !&Module {
	host_ensure_can_compile_wasm_bytes()!
	module_ := compile_module(bytes)!
	mut cache := get_cache()
	cache.add_compiled_module(module_)
	return module_
}

pub fn create_native_function(address u64, name string) &ExportedWasmFunction {
	return create_native_function_with_cache(get_cache(), 'default', address, name)
}

fn create_native_function_with_cache(cache &WebAssemblyCache, realm string, address u64, name string) &ExportedWasmFunction {
	if function := cache.get_function_instance(address) {
		return function
	}
	function := ExportedWasmFunction.create_for_realm(realm, name, address)
	unsafe {
		cache.add_function_instance(address, function)
	}
	return function
}

pub fn to_js_value(value WasmValue) !webidl.Value {
	return value.to_webidl_value()
}

pub fn host_ensure_can_compile_wasm_bytes() ! {
	// The native implementation asks the current Realm's CSP policy. The V
	// runtime exposes that realm lookup as a host hook while keeping the actual
	// allow/deny decision on every compilation path in this module.
	if hook := host_ensure_can_compile_wasm_bytes_hook_ {
		hook()!
	}
}

pub fn set_host_ensure_can_compile_wasm_bytes_hook(hook ?HostEnsureCanCompileWasmBytesHook) {
	host_ensure_can_compile_wasm_bytes_hook_ = hook
}

pub fn asynchronously_compile_webassembly_module(bytes []u8) !&Module {
	return compile_a_webassembly_module(bytes)
}

pub fn asynchronously_instantiate_webassembly_module(module_ &Module, imports ImportObject) !&Instance {
	mut cache := get_cache()
	cache.abstract_machine_.instances++
	return Instance.construct(module_, imports)
}

pub fn instantiate_promise_of_module(module_ &Module, imports ImportObject) !WebAssemblyInstantiatedSource {
	instance := asynchronously_instantiate_webassembly_module(module_, imports)!
	return WebAssemblyInstantiatedSource{
		module: module_
		instance: instance
	}
}

pub fn compile_potential_webassembly_response(response StreamingResponse) !&Module {
	return compile_streaming(response)
}

pub fn wasm_ordinary_create_from_constructor(prototype webidl.Value) webidl.Value {
	return if prototype.kind in [.object, .platform_object] {
		prototype
	} else {
		webidl.object_value({})
	}
}
