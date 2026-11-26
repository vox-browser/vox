// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import streams
import webidl

fn (mut host Host) wrap_stream_controller(handle streams.ReadableStreamControllerHandle) libjs.Value {
	key := if controller := handle.default_controller { voidptr(controller) } else if controller := handle.byte_controller { voidptr(controller) } else { panic('Missing readable controller') }
	if object := host.stream_controller_wrappers[key] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	is_byte := handle.byte_controller != none
	mut object := libjs.Object.create(host.realm, if is_byte { host.byte_controller_prototype } else { host.default_controller_prototype })
	object.class_name = if is_byte { 'ReadableByteStreamController' } else { 'ReadableStreamDefaultController' }
	if controller := handle.default_controller { host.stream_default_controllers[voidptr(object)] = controller }
	if controller := handle.byte_controller { host.stream_byte_controllers[voidptr(object)] = controller }
	host.stream_controller_wrappers[key] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) stream_controller_receiver(mut vm libjs.VM, byte bool) !streams.ReadableStreamControllerHandle {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		key := voidptr(vm.this_value().as_object())
		if byte { if controller := host.stream_byte_controllers[key] { return streams.ReadableStreamControllerHandle{byte_controller: controller} } }
		else { if controller := host.stream_default_controllers[key] { return streams.ReadableStreamControllerHandle{default_controller: controller} } }
	}
	return vm.throw_error(.type_error, 'Readable controller member called on incompatible receiver')
}

fn (mut host Host) enqueue_stream_bytes(mut vm libjs.VM, mut controller streams.ReadableByteStreamController, chunk libjs.Value) ! {
	if !chunk.is_object() || (chunk.as_object().typed_array == none && chunk.as_object().slots.data_view == none) {
		return vm.throw_error(.type_error, 'Byte stream enqueue requires an ArrayBufferView')
	}
	object := native_buffer_source(mut vm, chunk, false)!
	bytes := copy_native_buffer_source(mut vm, object)!
	if bytes.len == 0 { return vm.throw_error(.type_error, 'Byte stream chunk is empty or detached') }
	if controller.close_requested() || !controller.stream().is_readable() { return vm.throw_error(.type_error, 'Byte stream is not readable') }
	mut buffer := if array := object.typed_array { array.viewed_buffer }
		else { object.slots.data_view or { return vm.throw_error(.type_error, 'Expected an ArrayBufferView') }.viewed_buffer or { return vm.throw_error(.type_error, 'Uninitialized DataView') } }
	// Transfer before native enqueue can synchronously complete a pending read.
	libjs.detach_array_buffer(mut vm, mut buffer, none)!
	streams.readable_byte_stream_controller_enqueue_native_bytes(mut controller, bytes) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
}

fn (mut host Host) install_stream_controllers() {
	mut vm := host.vm
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	for byte in [false, true] {
		name := if byte { 'ReadableByteStreamController' } else { 'ReadableStreamDefaultController' }
		mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
		if byte { host.byte_controller_prototype = prototype } else { host.default_controller_prototype = prototype }
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal readable controller constructor') },
			fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal readable controller constructor') }, 0, libjs.PropertyName.from_str(name)).object
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		mut global := host.realm.global_object_record()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		host.accessor(mut prototype, 'desiredSize', fn [host, byte] (mut vm libjs.VM) !libjs.Value {
			handle := host.stream_controller_receiver(mut vm, byte)!
			size := if controller := handle.default_controller { controller.desired_size() }
				else if controller := handle.byte_controller { streams.readable_byte_stream_controller_get_desired_size(controller) }
				else { ?f64(none) }
			return if actual := size { libjs.Value.from_f64(actual) } else { libjs.js_null() }
		}, unsafe { nil })
		for method in ['close', 'enqueue', 'error'] {
			host.method_attributes(mut prototype, method, if byte && method == 'enqueue' { 1 } else { 0 }, fn [host, byte, method] (mut vm libjs.VM) !libjs.Value {
				handle := host.stream_controller_receiver(mut vm, byte)!
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				mut owner := unsafe { &Host(host) }
				if mut controller := handle.default_controller {
					if method == 'close' { controller.close() or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) } }
					else if method == 'enqueue' {
						controller.enqueue(streams.runtime_value(host.stream_webidl_value(vm.argument(0)))) or {
							return libjs.throw_completion(if err is webidl.ValueException { owner.stream_error_value(mut vm, err.value)! } else { host.fetch_error_value(mut vm, err) })
						}
					} else { streams.readable_stream_default_controller_error(mut controller, streams.runtime_value(host.stream_webidl_value(vm.argument(0)))) }
				}
				if mut controller := handle.byte_controller {
					if method == 'close' {
						if controller.close_requested() || !controller.stream().is_readable() { return vm.throw_error(.type_error, 'Byte stream is not readable') }
						streams.readable_byte_stream_controller_close(mut controller) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
					}
					else if method == 'enqueue' { owner.enqueue_stream_bytes(mut vm, mut controller, vm.argument(0))! }
					else { streams.readable_byte_stream_controller_error(mut controller, streams.runtime_value(host.stream_webidl_value(vm.argument(0)))) }
				}
				return libjs.js_undefined()
			}, attributes)
		}
	}
}
