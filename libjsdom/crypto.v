// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform
import webcrypto

fn crypto_array_kind(kind libjs.BufferElementType) webcrypto.RandomValuesArrayKind {
	return match kind {
		.int8 { .int8 } .uint8 { .uint8 } .uint8_clamped { .uint8_clamped }
		.int16 { .int16 } .uint16 { .uint16 } .int32 { .int32 } .uint32 { .uint32 }
		.big_int64 { .bigint64 } .big_uint64 { .biguint64 }
		.float16, .float32 { .float32 } .float64 { .float64 }
	}
}

fn (mut host Host) native_crypto(mut vm libjs.VM) !&html.GlobalScopeCrypto {
	window := host.frame_window(mut vm)!
	mut scope := window.window_or_worker_global_scope()
	return scope.crypto()
}

fn crypto_require_fixed_buffer(mut vm libjs.VM, buffer &libjs.ArrayBufferObject) ! {
	if buffer.is_shared_array_buffer() { return vm.throw_error(.type_error, 'Crypto view cannot use SharedArrayBuffer') }
	if !buffer.is_fixed_length() { return vm.throw_error(.type_error, 'Crypto requires a fixed-length ArrayBuffer view') }
}

fn (mut host Host) crypto_random_values(mut vm libjs.VM, value libjs.Value) !libjs.Value {
	if !value.is_object() { return vm.throw_error(.type_error, 'Expected an ArrayBufferView') }
	object := value.as_object()
	if view := object.slots.data_view {
		buffer := view.viewed_buffer or { return vm.throw_error(.type_error, 'DataView has no ArrayBuffer') }
		crypto_require_fixed_buffer(mut vm, buffer)!
		native := host.native_crypto(mut vm)!
		native.crypto().get_random_values_for_view(.data_view, false, 0) or { return host.dom_error(mut vm, err) }
		return vm.throw_error(.internal_error, 'Crypto unexpectedly accepted DataView')
	}
	array := object.typed_array or { return vm.throw_error(.type_error, 'Expected an ArrayBufferView') }
	crypto_require_fixed_buffer(mut vm, array.viewed_buffer)!
	witness := libjs.make_typed_array_with_buffer_witness_record(array, .seq_cst)
	out_of_bounds := libjs.is_typed_array_out_of_bounds(witness)
	length := libjs.typed_array_byte_length(witness)
	native := host.native_crypto(mut vm)!
	bytes := native.crypto().get_random_values_for_view(crypto_array_kind(array.kind), out_of_bounds, u64(length)) or { return host.dom_error(mut vm, err) }
	mut buffer := array.viewed_buffer
	buffer.overwrite(uint(array.byte_offset), bytes)
	return value
}

fn (mut host Host) install_crypto() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	object := libjs.Object.create(host.realm, prototype)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal Crypto constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal Crypto constructor') }, 0, libjs.PropertyName.from_str('Crypto')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('Crypto')), libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Crypto'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut global, 'crypto', fn [host, object, global] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		receiver := vm.this_value()
		if !receiver.is_object() || voidptr(receiver.as_object()) != voidptr(global) { return vm.throw_error(.type_error, 'Crypto global requires Window') }
		return libjs.Value.from_object(object)
	}, unsafe { nil })
	mut names := ['getRandomValues']
	settings_record := host.document.relevant_settings_object()
	if settings_record != unsafe { nil } {
		settings := unsafe { &html.EnvironmentSettingsObject(settings_record) }
		if settings.is_secure_context() { names << 'randomUUID' }
	}
	for name in names {
		host.method_attributes(mut prototype, name, if name == 'getRandomValues' { 1 } else { 0 }, fn [host, object, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			receiver := vm.this_value()
			if !receiver.is_object() || voidptr(receiver.as_object()) != voidptr(object) { return vm.throw_error(.type_error, 'Crypto member requires Crypto') }
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name == 'getRandomValues' {
				if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'getRandomValues requires an ArrayBufferView') }
				return owner.crypto_random_values(mut vm, vm.argument(0))
			}
			native := owner.native_crypto(mut vm)!
			text := native.random_uuid() or { return owner.dom_error(mut vm, err) }
			return libjs.Value.from_string(vm.create_string_from_str(text))
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
