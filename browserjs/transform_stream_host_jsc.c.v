// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Generated-binding adaptation for TransformStream/Transformer/controller IDL.
// Both component wrappers are prepared at the source point before start.
@[has_globals]
module browserjs

import streams
import webidl

__global transform_stream_bindings_ = map[voidptr]&TransformStreamHost{}

pub fn (mut host TransformStreamHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner_handle := voidptr(&runtime)
	if existing := transform_stream_bindings_[owner_handle] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('TransformStream binding already belongs to this runtime')
	}
	if _ := runtime.readable_stream_host() {
	} else {
		mut readable := ReadableStreamHost.create_for_settings(host.settings)!
		readable.install(mut runtime)!
	}
	if existing := runtime.writable_stream_host() {
		host.writable_host = existing
	} else {
		mut writable := WritableStreamHost.create_for_settings(host.settings)!
		writable.install(mut runtime)!
		host.writable_host = writable
	}
	host.runtime = &runtime
	host_handle := voidptr(&host)
	create := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &TransformStreamHost(host_handle) }
		return host.construct(args) or { host.runtime.actual_javascript_exception(host.exception_value(err)) }
	})!
	operate := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &TransformStreamHost(host_handle) }
		return host.operate(args) or { host.runtime.actual_javascript_exception(host.exception_value(err)) }
	})!
	installer := runtime.evaluate_host_value(transform_stream_native_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	prototypes := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		create,
		operate,
	])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes) }
	for index, kind in [TransformStreamHostKind.stream, .default_controller] {
		mut exception := unsafe { nil }
		prototype := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, prototypes, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		host.prototypes[kind] = runtime.retain_javascript_value(prototype)!
	}
	transform_stream_bindings_[owner_handle] = &host
	runtime.add_close_handler(fn [host_handle, owner_handle] () {
		mut host := unsafe { &TransformStreamHost(host_handle) }
		host.close()
		transform_stream_bindings_.delete(owner_handle)
	})
	runtime.install_compression_stream_binding()!
}

fn (host &TransformStreamHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host TransformStreamHost) exception_value(exception IError) voidptr {
	if exception is webidl.ValueException {
		return host.value(exception.value) or { host.runtime.binding_exception_value(err) }
	}
	return host.runtime.binding_exception_value(exception)
}

fn (mut host TransformStreamHost) transformer_callback(object voidptr, name string) !webidl.CallbackConversion {
	value := host.runtime.binding_property(object, name)!
	if C.JSValueIsUndefined(host.runtime.context, value) { return webidl.CallbackConversion{} }
	host_handle := voidptr(&host)
	callback := host.runtime.webidl_promise_callback(value, host.settings.stream_promise_context(), fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &TransformStreamHost(host_handle) }
		return host.value(value)
	})!
	return webidl.CallbackConversion{ callback: callback }
}

fn (mut host TransformStreamHost) construct(args []voidptr) !voidptr {
	if host.closed { return error('TransformStream binding is closed') }
	object := host.argument(args, 0)
	if !C.JSValueIsUndefined(host.runtime.context, object) && !C.JSValueIsObject(host.runtime.context, object) {
		return error('TypeError: transformer must be an object')
	}
	writable_strategy := host.writable_host.strategy(host.argument(args, 1))!
	readable_strategy := host.writable_host.strategy(host.argument(args, 2))!
	mut transformer := streams.Transformer{ transformer_value: webidl.null_value() }
	if !C.JSValueIsUndefined(host.runtime.context, object) {
		cancel := host.transformer_callback(object, 'cancel')!
		flush := host.transformer_callback(object, 'flush')!
		readable_type := host.runtime.binding_property(object, 'readableType')!
		mut readable_value := ?webidl.Value(none)
		if !C.JSValueIsUndefined(host.runtime.context, readable_type) {
			readable_value = host.runtime.webidl_value(readable_type)!
		}
		start := host.transformer_callback(object, 'start')!
		transform := host.transformer_callback(object, 'transform')!
		writable_type := host.runtime.binding_property(object, 'writableType')!
		mut writable_value := ?webidl.Value(none)
		if !C.JSValueIsUndefined(host.runtime.context, writable_type) {
			writable_value = host.runtime.webidl_value(writable_type)!
		}
		transformer = streams.Transformer{
			transformer_value:   host.runtime.webidl_value(object)!
			cancel_callback:     cancel.callback
			flush_callback:      flush.callback
			start_callback:      start.callback
			transform_callback:  transform.callback
			readable_type_value: readable_value
			writable_type_value: writable_value
		}
	}
	host_handle := voidptr(&host)
	realm := host.settings.stream_realm().with_transform_wrapper_preparer(fn [host_handle] (stream &streams.TransformStream) {
		mut host := unsafe { &TransformStreamHost(host_handle) }
		// Source Bindings::wrap is infallible at this prepared owning realm.
		host.runtime.javascript_readable_stream(stream.readable()) or { panic(err) }
		host.runtime.javascript_writable_stream(stream.writable()) or { panic(err) }
	})
	stream := streams.TransformStream.create_for_constructor(realm, transformer, writable_strategy, readable_strategy)!
	return host.wrap(.stream, voidptr(stream), host.argument(args, 3))
}

fn (mut host TransformStreamHost) wrap(kind TransformStreamHostKind, native voidptr, desired_prototype voidptr) !voidptr {
	if existing := host.records[native] {
		if existing.kind != kind { return error('TransformStream native interface mismatch') }
		return existing.object
	}
	mut record := &TransformStreamHostRecord{ host: host, kind: kind, native: native }
	object := host.runtime.make_native_stream_wrapper(record)!
	mut prototype := host.prototypes[kind] or { return error('TransformStream prototype is missing') }
	if desired_prototype != unsafe { nil } && C.JSValueIsObject(host.runtime.context, desired_prototype) {
		prototype = desired_prototype
	}
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = object
	host.records[native] = record
	return object
}

fn (host &TransformStreamHost) record(value voidptr, kind TransformStreamHostKind) !&TransformStreamHostRecord {
	if host.closed { return error('TransformStream binding is closed') }
	data := host.runtime.native_stream_wrapper_record(value)
	if data == unsafe { nil } {
		return error('TypeError: Illegal TransformStream interface receiver')
	}
	record := unsafe { &TransformStreamHostRecord(data) }
	if voidptr(record.host) != voidptr(host) || record.kind != kind {
		return error('TypeError: Illegal TransformStream interface receiver')
	}
	return record
}

pub fn (runtime &Runtime) native_transform_stream(value voidptr) !&streams.TransformStream {
	host := transform_stream_bindings_[voidptr(runtime)] or { return error('TransformStream binding is unavailable') }
	return unsafe { &streams.TransformStream(host.record(value, .stream)!.native) }
}

fn (mut host TransformStreamHost) value(value webidl.Value) !voidptr {
	if value.kind == .platform_object && value.platform_interfaces.contains('TransformStreamDefaultController') {
		return host.wrap(.default_controller, voidptr(value.opaque_id), unsafe { nil })
	}
	return host.writable_host.value(value)
}

fn (mut host TransformStreamHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('TransformStream binding is closed') }
	object := host.argument(args, 0)
	operation := host.runtime.binding_dom_string(host.argument(args, 1))!
	argument := host.argument(args, 2)
	if operation.starts_with('stream.') {
		record := host.record(object, .stream)!
		stream := unsafe { &streams.TransformStream(record.native) }
		match operation {
			'stream.readable' { return host.runtime.javascript_readable_stream(stream.readable()) }
			'stream.writable' { return host.runtime.javascript_writable_stream(stream.writable()) }
			else {}
		}
	}
	if operation.starts_with('controller.') {
		record := host.record(object, .default_controller)!
		mut controller := unsafe { &streams.TransformStreamDefaultController(record.native) }
		match operation {
			'controller.desiredSize' {
				if size := controller.desired_size() {
					return C.vox_jsc_JSValueMakeNumber(host.runtime.context, size)
				}
				return C.vox_jsc_JSValueMakeNull(host.runtime.context)
			}
			'controller.enqueue' {
				controller.enqueue(streams.runtime_value(host.runtime.webidl_value(argument)!))!
				return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
			}
			'controller.error' {
				streams.transform_stream_default_controller_error(mut controller, streams.runtime_value(host.runtime.webidl_value(argument)!))
				return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
			}
			'controller.terminate' {
				streams.transform_stream_default_controller_terminate(mut controller)
				return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
			}
			else {}
		}
	}
	return error('Unknown TransformStream interface operation')
}

const transform_stream_native_bootstrap = r'(function(create,operate){
 const define=Object.defineProperty,Type=TypeError,ConstructProxy=Proxy;
 const TransformStream=new ConstructProxy(function TransformStream(){throw new Type("TransformStream requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;return create(args[0],args[1],args[2],prototype)}});
 define(TransformStream.prototype,"constructor",{value:TransformStream,writable:true,configurable:true});
 const TransformStreamDefaultController=new ConstructProxy(function TransformStreamDefaultController(){throw new Type("TransformStreamDefaultController requires new")},{construct(){throw new Type("Illegal constructor")}});
  define(TransformStreamDefaultController.prototype,"constructor",{value:TransformStreamDefaultController,writable:true,configurable:true});
 const attribute=(prototype,name,operation)=>define(prototype,name,{enumerable:true,configurable:true,get(){return operate(this,operation)}});
 const method=(prototype,name,value)=>define(prototype,name,{value,writable:true,enumerable:true,configurable:true});
 attribute(TransformStream.prototype,"readable","stream.readable");attribute(TransformStream.prototype,"writable","stream.writable");
 attribute(TransformStreamDefaultController.prototype,"desiredSize","controller.desiredSize");
 method(TransformStreamDefaultController.prototype,"enqueue",function enqueue(chunk){return operate(this,"controller.enqueue",chunk)});
 method(TransformStreamDefaultController.prototype,"error",function error(reason){return operate(this,"controller.error",reason)});
 method(TransformStreamDefaultController.prototype,"terminate",function terminate(){return operate(this,"controller.terminate")});
 for(const name of ["enqueue","error"])define(TransformStreamDefaultController.prototype[name],"length",{value:0,configurable:true});
 for(const [Constructor,name] of [[TransformStream,"TransformStream"],[TransformStreamDefaultController,"TransformStreamDefaultController"]]){define(Constructor,"prototype",{writable:false});define(Constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});define(globalThis,name,{value:Constructor,writable:true,configurable:true})}
 return [TransformStream.prototype,TransformStreamDefaultController.prototype]
})'
