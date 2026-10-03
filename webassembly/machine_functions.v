// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.h: WasmFunction, HostFunction;
// .cpp: Store function allocation and lookup.
module webassembly

import strconv

// The host callable receives the actual source-owned Configuration record.
// This is the stored callable; instruction execution remains a separate slice.
pub type BinaryMachineHostCallable = fn (mut BinaryMachineConfiguration, []BinaryMachineValue) BinaryMachineResult

pub struct BinaryMachineWasmFunction {
	type_            BinaryMachineFunctionType
	defined_type_    &BinaryCanonicalType
	module_          &Module
	module_instance_ &BinaryMachineModuleInstance
	code_            &BinaryFunctionBody
}

// These are the actual module/code owners. V currently retains these aliases;
// source WeakPtr/ref-counted expiration is a separate ownership boundary.
pub fn BinaryMachineWasmFunction.create(type_ BinaryMachineFunctionType, defined_type &BinaryCanonicalType, instance &BinaryMachineModuleInstance, module_ &Module, code &BinaryFunctionBody) BinaryMachineWasmFunction {
	return BinaryMachineWasmFunction{
		type_:            type_
		defined_type_:    defined_type
		module_:          module_
		module_instance_: instance
		// Source Code belongs to the retained Module's code section. Keep that
		// exact record, including subsequent compilation metadata, rather than
		// heap-copying its body. The owner must keep its code vector stable.
		code_:            unsafe { code }
	}
}

pub fn (function &BinaryMachineWasmFunction) type_() BinaryMachineFunctionType {
	return function.type_
}

pub fn (function &BinaryMachineWasmFunction) defined_type() &BinaryCanonicalType {
	return function.defined_type_
}

pub fn (function &BinaryMachineWasmFunction) module() &BinaryMachineModuleInstance {
	return function.module_instance_
}

pub fn (function &BinaryMachineWasmFunction) try_module() ?&BinaryMachineModuleInstance {
	if isnil(function.module_instance_) { return none }
	return function.module_instance_
}

pub fn (function &BinaryMachineWasmFunction) code() &BinaryFunctionBody { return function.code_ }

pub fn (function &BinaryMachineWasmFunction) module_ref() ?&Module {
	if isnil(function.module_) { return none }
	return function.module_
}

pub struct BinaryMachineHostFunction {
	function_ BinaryMachineHostCallable @[required]
	type_     BinaryMachineFunctionType
	name_     string
mut:
	defined_type_ &BinaryCanonicalType = unsafe { nil }
}

pub fn BinaryMachineHostFunction.create(function BinaryMachineHostCallable, type_ BinaryMachineFunctionType, name string) BinaryMachineHostFunction {
	return BinaryMachineHostFunction{ function_: function, type_: type_, name_: name }
}

pub fn (function &BinaryMachineHostFunction) function() BinaryMachineHostCallable {
	return function.function_
}

pub fn (function &BinaryMachineHostFunction) type_() BinaryMachineFunctionType {
	return function.type_
}

pub fn (function &BinaryMachineHostFunction) name() string { return function.name_ }

pub fn (function &BinaryMachineHostFunction) defined_type() &BinaryCanonicalType {
	return function.defined_type_
}

pub fn (mut function BinaryMachineHostFunction) set_defined_type(defined_type &BinaryCanonicalType) {
	function.defined_type_ = defined_type
}

pub type BinaryMachineFunctionInstance = BinaryMachineWasmFunction | BinaryMachineHostFunction

pub fn (mut store BinaryMachineStore) allocate_function(instance &BinaryMachineModuleInstance, module_ &Module, code &BinaryFunctionBody, type_index u32) ?u64 {
	address := u64(store.functions_.len)
	if u64(type_index) >= u64(instance.types().len) { return none }
	type_ := instance.types()[int(type_index)]
	assert type_.kind == .function_
	defined_type := instance.canonical_types()[int(type_index)]
	store.functions_ << BinaryMachineWasmFunction.create(BinaryMachineFunctionType{
		parameters: type_.parameters
		results:    type_.results
	}, defined_type, instance, module_, code)
	return address
}

pub fn (mut store BinaryMachineStore) allocate_host_function(input BinaryMachineHostFunction) ?u64 {
	address := u64(store.functions_.len)
	mut function := input
	if isnil(function.defined_type()) {
		type_ := function.type_()
		function.set_defined_type(canonicalize_binary_type(BinaryDefinedType{
			kind:       .function_
			parameters: type_.parameters
			results:    type_.results
		}, BinaryTypeContext{}))
	}
	store.functions_ << function
	return address
}

pub fn (store &BinaryMachineStore) get_function(address u64) ?&BinaryMachineFunctionInstance {
	if u64(store.functions_.len) <= address { return none }
	instance := &store.functions_[int(address)]
	if instance is BinaryMachineWasmFunction {
		if instance.try_module() == none { return none }
	}
	return instance
}

pub fn (store &BinaryMachineStore) unsafe_get_function(address u64) &BinaryMachineFunctionInstance {
	return unsafe { &store.functions_[int(address)] }
}

pub fn (store &BinaryMachineStore) get_module_for(address u64) ?&Module {
	function := store.get_function(address) or { return none }
	if function is BinaryMachineWasmFunction { return function.module_ref() }
	return none
}

pub fn (store &BinaryMachineStore) get_module_instance_for(address u64) ?&BinaryMachineModuleInstance {
	function := store.get_function(address) or { return none }
	if function is BinaryMachineWasmFunction { return function.try_module() }
	return none
}

// LibWeb/WebAssembly/WebAssembly.cpp::name_of_webassembly_function derives
// the function's source index, not an export label or the Store address.
pub fn name_of_webassembly_function(store &BinaryMachineStore, address u64) string {
	function := store.get_function(address) or { panic('Missing function instance') }
	index := match function {
		BinaryMachineHostFunction {
			strconv.parse_uint(function.name(), 10, 64) or { panic('Invalid host function index') }
		}
		BinaryMachineWasmFunction {
			mut found := ?u64(none)
			for position, stored_address in function.module().functions() {
				if stored_address == address {
					found = u64(position)
					break
				}
			}
			found or { panic('Function address is absent from its module') }
		}
	}
	return index.str()
}
