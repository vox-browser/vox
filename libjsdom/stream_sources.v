// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import streams
import webidl

@[heap]
struct StreamSourceBinding {
mut:
	host ?&Host
	source libjs.Value = libjs.js_undefined()
	start libjs.Value = libjs.js_undefined()
	pull libjs.Value = libjs.js_undefined()
	cancel libjs.Value = libjs.js_undefined()
	size libjs.Value = libjs.js_undefined()
	handle ?streams.ReadableStreamControllerHandle
}

@[heap]
struct StreamSourceResult {
mut:
	promise ?&webidl.Promise
}

fn (mut source StreamSourceBinding) clear() {
	source.host = none; source.source = libjs.js_undefined()
	source.start = libjs.js_undefined(); source.pull = libjs.js_undefined()
	source.cancel = libjs.js_undefined(); source.size = libjs.js_undefined()
	source.handle = none
}

fn (mut source StreamSourceBinding) invoke_source(callback libjs.Value, handle ?streams.ReadableStreamControllerHandle, reason ?streams.Value) !&webidl.Promise {
	mut host := source.host or { return error('TypeError: Stream source runtime is closed') }
	if callback.is_undefined() { return webidl.create_resolved_promise_for(host.authored_stream_realm().promise_context(), webidl.undefined_value()) }
	mut output := &StreamSourceResult{}
	host.stream_entry(fn [mut host, source, callback, handle, reason, mut output] (mut vm libjs.VM) !libjs.Value {
		argument := if controller := handle { host.wrap_stream_controller(controller) }
			else if value := reason { host.stream_value_to_js(mut vm, value)! }
			else { libjs.js_undefined() }
		result := libjs.call(mut vm, callback, source.source, [argument])!
		output.promise = host.adopt_stream_callback_result(mut vm, result)!
		return libjs.js_undefined()
	}) or { return webidl.throw_value(host.stream_webidl_value(host.fetch_error_value(mut host.vm, err))) }
	return output.promise or { return error('TypeError: Stream source callback could not run') }
}

fn (mut source StreamSourceBinding) start_readable_source(handle streams.ReadableStreamControllerHandle) !&webidl.Promise {
	source.handle = handle
	return source.invoke_source(source.start, handle, none)
}

fn (mut source StreamSourceBinding) pull_readable_source(handle streams.ReadableStreamControllerHandle) !&webidl.Promise {
	return source.invoke_source(source.pull, handle, none)
}

fn (mut source StreamSourceBinding) cancel_readable_source(reason streams.Value) !&webidl.Promise {
	return source.invoke_source(source.cancel, none, reason)
}

fn (mut source StreamSourceBinding) invoke_size_algorithm(chunk streams.Value) !webidl.Value {
	mut host := source.host or { return error('TypeError: Stream size runtime is closed') }
	result := host.stream_entry(fn [mut host, source, chunk] (mut vm libjs.VM) !libjs.Value {
		argument := host.stream_value_to_js(mut vm, chunk)!
		value := libjs.call(mut vm, source.size, libjs.js_undefined(), [argument])!
		return value.to_number(mut vm)!
	}) or { return webidl.throw_value(host.stream_webidl_value(host.fetch_error_value(mut host.vm, err))) }
	return webidl.number_value(result.number)
}

fn stream_callback_member(mut vm libjs.VM, dictionary libjs.Value, name string) !libjs.Value {
	value := text_encoding_member(mut vm, dictionary, name)!
	if !value.is_undefined() && !value.is_function() { return vm.throw_error(.type_error, 'Stream ${name} callback must be callable') }
	return value
}

fn (mut host Host) construct_readable_stream(mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
	host.require_open(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.release_retired_stream_jobs()
	underlying := vm.argument(0)
	if !underlying.is_undefined() && !underlying.is_object() { return vm.throw_error(.type_error, 'ReadableStream source must be an object') }
	strategy := vm.argument(1)
	if !strategy.is_nullish() && !strategy.is_object() { return vm.throw_error(.type_error, 'ReadableStream strategy must be an object') }
	// WebIDL converts argument dictionaries before OrdinaryCreateFromConstructor.
	high_water_mark := text_encoding_member(mut vm, strategy, 'highWaterMark')!
	hwm := if high_water_mark.is_undefined() { ?f64(none) } else { ?f64(high_water_mark.to_number(mut vm)!.number) }
	size := stream_callback_member(mut vm, strategy, 'size')!
	parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
	// The native constructor then converts the source dictionary in IDL order.
	auto_value := text_encoding_member(mut vm, underlying, 'autoAllocateChunkSize')!
	auto_size := if auto_value.is_undefined() { ?u64(none) } else {
		number := auto_value.to_number(mut vm)!.number
		converted := webidl.convert_to_int(webidl.number_value(number), 64, false, .yes, .no) or { return libjs.throw_completion(host.fetch_error_value(mut vm, err)) }
		?u64(u64(converted))
	}
	cancel := stream_callback_member(mut vm, underlying, 'cancel')!
	pull := stream_callback_member(mut vm, underlying, 'pull')!
	start := stream_callback_member(mut vm, underlying, 'start')!
	type_value := text_encoding_member(mut vm, underlying, 'type')!
	type_ := if type_value.is_undefined() { streams.UnderlyingSourceType.default_source } else {
		if type_value.to_primitive_string(mut vm)!.str() != 'bytes' { return vm.throw_error(.type_error, 'Invalid readable source type') }
		streams.UnderlyingSourceType.bytes
	}
	mut source := &StreamSourceBinding{host: &host, source: underlying, start: start, pull: pull, cancel: cancel, size: size}
	host.stream_sources[voidptr(source)] = source
	options := streams.QueuingStrategy{high_water_mark: hwm, size_object: if size.is_undefined() { ?streams.SizeAlgorithmObject(none) } else { ?streams.SizeAlgorithmObject(source) }}
	native := streams.ReadableStream.create_for_constructor(host.authored_stream_realm(), streams.UnderlyingSource{
		type_: type_, auto_allocate_chunk_size: auto_size, native_callbacks: streams.ReadableSourceCallbacks(source)
	}, options) or {
		// start may have exposed its controller before throwing. Error that
		// stream and clear algorithms before detaching its author callbacks.
		if handle := source.handle {
			reason := if err is webidl.ValueException { err.value } else { host.stream_webidl_value(host.fetch_error_value(mut vm, err)) }
			if mut controller := handle.default_controller { controller.stream().error_value(reason) }
			if mut controller := handle.byte_controller { controller.stream().error_value(reason) }
		}
		source.clear(); host.stream_sources.delete(voidptr(source))
		if err is webidl.ValueException { return libjs.throw_completion(host.stream_error_value(mut vm, err.value)!) }
		return libjs.throw_completion(host.fetch_error_value(mut vm, err))
	}
	return host.wrap_readable_stream(native, if parent.is_object() { ?&libjs.Object(parent.as_object()) } else { none }).as_object()
}

fn (mut host Host) install_readable_stream_constructor(mut prototype libjs.Object) {
	mut vm := host.vm
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		mut owner := unsafe { &Host(host) }
		return owner.construct_readable_stream(mut vm, new_target)
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'ReadableStream requires new') }, construct, 0, libjs.PropertyName.from_str('ReadableStream')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(&prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('ReadableStream'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}
