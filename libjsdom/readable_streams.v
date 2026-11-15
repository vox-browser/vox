// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import streams
import webidl

fn (mut host Host) wrap_readable_stream(native &streams.ReadableStream, parent ?&libjs.Object) libjs.Value {
	if object := host.readable_stream_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, parent or { host.readable_stream_prototype })
	object.class_name = 'ReadableStream'
	host.readable_streams[voidptr(object)] = native
	host.readable_stream_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (mut host Host) wrap_stream_reader(native &streams.ReadableStreamDefaultReader, parent ?&libjs.Object) libjs.Value {
	if object := host.stream_reader_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, parent or { host.default_reader_prototype })
	object.class_name = 'ReadableStreamDefaultReader'
	host.stream_readers[voidptr(object)] = native
	host.stream_reader_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) readable_stream_receiver(mut vm libjs.VM, value libjs.Value) !&streams.ReadableStream {
	host.require_open(mut vm)!
	if value.is_object() { if native := host.readable_streams[voidptr(value.as_object())] { return native } }
	return vm.throw_error(.type_error, 'Expected a ReadableStream')
}

fn (host &Host) stream_reader_receiver(mut vm libjs.VM) !&streams.ReadableStreamDefaultReader {
	host.require_open(mut vm)!
	if vm.this_value().is_object() { if reader := host.stream_readers[voidptr(vm.this_value().as_object())] { return reader } }
	return vm.throw_error(.type_error, 'ReadableStreamDefaultReader member called on incompatible receiver')
}

fn (mut host Host) install_readable_streams() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	mut reader_prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.readable_stream_prototype, host.default_reader_prototype = prototype, reader_prototype
	host.install_stream_controllers()
	host.install_readable_stream_constructor(mut prototype)
	for name, object in {'ReadableStream': prototype, 'ReadableStreamDefaultReader': reader_prototype} {
		mut target := object
		target.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
	}
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.accessor(mut prototype, 'locked', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_bool(host.readable_stream_receiver(mut vm, vm.this_value())!.locked())
	}, unsafe { nil })
	host.method_attributes(mut prototype, 'getReader', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := unsafe { &streams.ReadableStream(host.readable_stream_receiver(mut vm, vm.this_value())!) }
		options := vm.argument(0)
		text_encoding_dictionary(mut vm, options)!
		mode := text_encoding_member(mut vm, options, 'mode')!
		if !mode.is_undefined() {
			text := mode.to_primitive_string(mut vm)!.str()
			if text != 'byob' { return vm.throw_error(.type_error, 'Invalid ReadableStream reader mode') }
			return vm.throw_error(.type_error, 'BYOB reader bindings are not implemented')
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		reader := native.get_default_reader() or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_stream_reader(reader, none)
	}, attributes)
	host.method_attributes(mut prototype, 'cancel', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		mut native := unsafe { &streams.ReadableStream(host.readable_stream_receiver(mut vm, vm.this_value()) or {
			capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
			owner.settle_fetch_error(capability, err); return capability.promise
		}) }
		return owner.wrap_stream_promise(mut vm, native.cancel(streams.runtime_value(host.stream_webidl_value(vm.argument(0)))).as_webidl_promise())
	}, attributes)
	host.method_attributes(mut prototype, 'tee', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := unsafe { &streams.ReadableStream(host.readable_stream_receiver(mut vm, vm.this_value())!) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		branches := streams.readable_stream_tee(mut native, false) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
		mut owner := unsafe { &Host(host) }
		return libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, [owner.wrap_readable_stream(branches.first, none), owner.wrap_readable_stream(branches.second, none)], host.realm.array_prototype_record())!.object)
	}, attributes)
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'ReadableStreamDefaultReader requires a stream') }
		mut native := unsafe { &streams.ReadableStream(host.readable_stream_receiver(mut vm, vm.argument(0))!) }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		reader := native.get_default_reader() or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_stream_reader(reader, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'ReadableStreamDefaultReader requires new') },
		construct, 1, libjs.PropertyName.from_str('ReadableStreamDefaultReader')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(reader_prototype), 0)
	reader_prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('ReadableStreamDefaultReader'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut reader_prototype, 'closed', fn [host] (mut vm libjs.VM) !libjs.Value {
		reader := host.stream_reader_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_stream_promise(mut vm, reader.closed().as_webidl_promise())
	}, unsafe { nil })
	host.method_attributes(mut reader_prototype, 'releaseLock', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut reader := unsafe { &streams.ReadableStreamDefaultReader(host.stream_reader_receiver(mut vm)!) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		reader.release_lock() or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
		return libjs.js_undefined()
	}, attributes)
	for method in ['read', 'cancel'] {
		host.method_attributes(mut reader_prototype, method, 0, fn [host, method] (mut vm libjs.VM) !libjs.Value {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			mut reader := unsafe { &streams.ReadableStreamDefaultReader(host.stream_reader_receiver(mut vm) or {
				capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
				owner.settle_fetch_error(capability, err); return capability.promise
			}) }
			if method == 'read' {
				capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
				owner.start_stream_read(mut vm, mut reader, capability); return capability.promise
			}
			return owner.wrap_stream_promise(mut vm, reader.cancel(streams.runtime_value(host.stream_webidl_value(vm.argument(0)))).as_webidl_promise())
		}, attributes)
	}
}

fn (mut host Host) close_readable_streams() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.close_stream_sources()
	for _, mut binding in host.stream_promises {
		mut promise := unsafe { &webidl.Promise(binding.native) }
		promise.remove_native_settlement_observer(binding.promise_observer_identity())
		binding.capability = none
	}
	for _, mut reader in host.stream_readers { reader.release_lock() or {} }
	reason := webidl.simple_exception_value(webidl.SimpleException{type_: .type_error, message: 'Document stream runtime is closed'})
	for _, mut native in host.readable_streams { native.error_value(reason) }
	for _, mut request in host.stream_reads { request.capability = none }
	host.stream_reads.clear()
	host.stream_promises.clear()
	host.stream_readers.clear()
	host.stream_reader_wrappers.clear()
	host.readable_streams.clear()
	host.readable_stream_wrappers.clear()
	host.stream_errors.clear()
	host.stream_default_controllers.clear()
	host.stream_byte_controllers.clear()
	host.stream_controller_wrappers.clear()
}
