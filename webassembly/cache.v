// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the WebAssemblyCache and host/runtime helpers in
// WebAssembly/WebAssembly.{h,cpp}. LibWasm execution remains the platform
// boundary, while cache identity and JS API conversion semantics live here.
@[has_globals]
module webassembly

import webidl

pub type HostEnsureCanCompileWasmBytesHook = fn () !

__global (
	webassembly_global_cache                 &WebAssemblyCache
	host_ensure_can_compile_wasm_bytes_hook_ ?HostEnsureCanCompileWasmBytesHook
)
__global (
	webassembly_realm_caches = map[string]&WebAssemblyCache{}
	webassembly_live_caches_ = []&WebAssemblyCache{}
)

pub struct AbstractMachine {
pub mut:
	compiled_modules u64
	instances        u64
}

@[heap]
pub struct ExportedWasmFunction {
pub:
	name string
mut:
	exported_address_ u64
}

pub fn ExportedWasmFunction.create(name string, exported_address u64) &ExportedWasmFunction {
	return &ExportedWasmFunction{
		name: name
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

fn extern_value_key(value webidl.Value) string {
	// JS::Value is identity-hashable upstream. webidl.Value is the standalone
	// typed boundary, so primitive values retain SameValue-like keys and opaque
	// object categories retain their category identity.
	return match value.kind {
		.undefined, .null_, .callback, .platform_object { value.kind.str() }
		.boolean { '${value.kind}:${value.boolean_value}' }
		.number { '${value.kind}:${value.number_value}' }
		.bigint { '${value.kind}:${value.bigint_value}' }
		.string_ { '${value.kind}:${value.string_value}' }
		else { '${value.kind}:${value}' }
	}
}

pub fn (mut cache WebAssemblyCache) add_extern_value(address u64, value webidl.Value) {
	if old := cache.extern_values_[address] {
		cache.inverse_extern_.delete(extern_value_key(old))
	}
	cache.extern_values_[address] = value
	cache.inverse_extern_[extern_value_key(value)] = address
}

pub fn (mut cache WebAssemblyCache) add_global_instance(address u64, global &Global) {
	cache.global_instances_[address] = global
}

pub fn (mut cache WebAssemblyCache) add_memory_instance(address u64, memory &Memory) {
	cache.memory_instances_[address] = memory
}

pub fn (cache &WebAssemblyCache) get_function_instance(address u64) ?&ExportedWasmFunction {
	return cache.function_instances_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) get_extern_value(address u64) ?webidl.Value {
	return cache.extern_values_[address]
}

pub fn (cache &WebAssemblyCache) get_global_instance(address u64) ?&Global {
	return cache.global_instances_[address] or { return none }
}

pub fn (cache &WebAssemblyCache) get_memory_instance(address u64) ?&Memory {
	return cache.memory_instances_[address] or { return none }
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
	mut cache := get_cache()
	if function := cache.get_function_instance(address) {
		return function
	}
	function := ExportedWasmFunction.create(name, address)
	cache.add_function_instance(address, function)
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
