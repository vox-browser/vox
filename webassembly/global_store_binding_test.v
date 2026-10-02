module webassembly

import math
import webidl

fn test_global_binding_and_machine_write_share_actual_store_record() {
	mut global := construct_global_for_realm('actual-global-store-binding', GlobalDescriptor{
		value:    .i32
		mutable_: true
	}, webidl.string_value('4294967297'))!
	assert global.address() == 0
	owner := global.cache()
	mut instance := owner.abstract_machine_.store().get_global(0) or { panic('missing actual Store global') }
	assert voidptr(instance) == voidptr(global.machine_instance()!)
	assert instance.value().to_i32() == 1
	instance.set_value(BinaryMachineValue.from_i32(-7))
	assert global.value()!.number_value == -7
	global.set_value(webidl.boolean_value(true))!
	assert instance.value().to_i32() == 1
	mut store := owner.abstract_machine_.store()
	for _ in 0 .. 128 {
		store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .f64 } }, BinaryMachineValue.from_f64(3.5)) or { panic('allocation failed') }
	}
	assert voidptr(instance) == voidptr(global.machine_instance()!)
	assert voidptr(owner.get_global_instance(0) or { panic('missing cached wrapper') }) == voidptr(global)
	other := construct_global_for_realm('other-actual-global-store-binding', GlobalDescriptor{ value: .i32 }, webidl.number_value(99))!
	assert other.address() == 0
	assert voidptr(other.machine_instance()!) != voidptr(instance)
	assert other.value()!.number_value == 99
}

fn test_wrapped_global_reads_source_type_value_and_error_order() {
	cache := WebAssemblyCache.create()
	mut store := cache.abstract_machine_.store()
	address := store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .f64 }, mutable_: true }, BinaryMachineValue.from_f64(-0.0)) or { panic('allocation failed') }
	mut global := Global.create_for_store_address(cache, address)
	assert math.signbit(global.value()!.number_value)
	global.set_machine_value(BinaryMachineValue.from_f64(1.5))!
	assert global.value_of()!.number_value == 1.5
	vector_address := store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .v128 } }, BinaryMachineValue{}) or { panic('allocation failed') }
	mut vector := Global.create_for_store_address(cache, vector_address)
	assert vector.type()!.type_.kind == .v128
	if _ := vector.machine_value() {
		assert false
	} else {
		assert err.msg() == 'TypeError: V128 is not supported as a global value type'
	}
	if _ := vector.set_value(webidl.runtime_value(webidl.RuntimeValue{
		number_conversion: fn () !f64 { panic('V128 gate must precede conversion') }
		string_conversion: fn () !string { panic('V128 gate must precede conversion') }
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot set the value of a V128 global'
	}
	missing := Global.create_for_store_address(cache, 500)
	if _ := missing.type() {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the global instance'
	}
	if _ := missing.machine_value() {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the global instance'
	}
	if _ := missing.set_machine_value(BinaryMachineValue{}) {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the global instance'
	}
}

fn test_external_global_uses_owner_cache_reference_and_store_mutability() {
	mut global := construct_global_for_realm('actual-extern-global-store-binding', GlobalDescriptor{ value: .externref, mutable_: true }, none)!
	assert global.value()!.kind == .undefined
	initial := global.machine_value()!.to_reference() as BinaryExternReference
	assert global.cache().get_extern_value(initial.address) or { panic('missing actual cached undefined') } == webidl.undefined_value()
	global.set_value(webidl.string_value('retained external'))!
	reference := global.machine_value()!.to_reference() as BinaryExternReference
	assert reference.address != initial.address
	assert global.value()!.string_value == 'retained external'
	global.set_value(webidl.null_value())!
	assert global.machine_value()!.to_reference() is BinaryNullReference
	assert global.value()!.kind == .null_
	first := webidl.platform_object_value_with_id(101)
	second := webidl.platform_object_value_with_id(102)
	global.set_value(first)!
	first_reference := global.machine_value()!.to_reference() as BinaryExternReference
	global.set_value(second)!
	second_reference := global.machine_value()!.to_reference() as BinaryExternReference
	assert first_reference.address != second_reference.address
	assert global.value()!.opaque_id == 102
	global.set_value(first)!
	assert global.value()!.opaque_id == 101
	reused_reference := global.machine_value()!.to_reference() as BinaryExternReference
	assert reused_reference.address == first_reference.address
	immutable := construct_global_for_realm('actual-immutable-global-store-binding', GlobalDescriptor{ value: .i32 }, none)!
	if _ := immutable.set_machine_value(BinaryMachineValue.from_i32(2)) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot set the value of a const global'
	}
	assert immutable.machine_value()!.to_i32() == 0
	if _ := Global.construct(GlobalDescriptor{ value: .v128 }, webidl.undefined_value()) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot convert a vector value to a javascript value'
	}
	if _ := Global.construct(GlobalDescriptor{ value: .anyfunc }, webidl.callback_value()) {
		assert false
	} else {
		assert err.msg() == 'TypeError: anyfunc requires null or an exported function'
	}
}
