// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Owning-realm generated bindings for WritableStream, default writer/controller.
// Stream state, queues, backpressure, abort and pending operations stay native.
@[has_globals]
module browserjs

import streams
import webidl

__global writable_stream_bindings_ = map[voidptr]&WritableStreamHost{}

pub fn (mut host WritableStreamHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner_handle := voidptr(&runtime)
	if existing := writable_stream_bindings_[owner_handle] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('WritableStream binding already belongs to this runtime')
	}
	if _ := abort_signal_bindings_[owner_handle] {
	} else {
		mut abort_host := AbortSignalHost.create_for_settings(host.settings)!
		abort_host.install(mut runtime)!
	}
	host.runtime = &runtime
	host.to_number_ = runtime.evaluate_host_value('(function(value){return +value})')!
	host_handle := voidptr(&host)
	create := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &WritableStreamHost(host_handle) }
		return host.construct(args) or { host.runtime.actual_javascript_exception(host.exception_value(err)) }
	})!
	operate := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &WritableStreamHost(host_handle) }
		return host.operate(args) or { host.runtime.actual_javascript_exception(host.exception_value(err)) }
	})!
	installer := runtime.evaluate_host_value(writable_stream_native_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	prototypes := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		create,
		operate,
	])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes) }
	for index, kind in [WritableStreamHostKind.stream, .default_writer, .default_controller] {
		mut exception := unsafe { nil }
		prototype := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, prototypes, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		host.prototypes[kind] = runtime.retain_javascript_value(prototype)!
	}
	writable_stream_bindings_[owner_handle] = &host
	runtime.add_close_handler(fn [host_handle, owner_handle] () {
		mut host := unsafe { &WritableStreamHost(host_handle) }
		host.close()
		writable_stream_bindings_.delete(owner_handle)
	})
}

fn (host &WritableStreamHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (mut host WritableStreamHost) exception_value(exception IError) voidptr {
	if exception is webidl.ValueException {
		return host.value(exception.value) or { host.runtime.binding_exception_value(err) }
	}
	return host.runtime.binding_exception_value(exception)
}

fn (host &WritableStreamHost) number(value voidptr) !f64 {
	// JSValueToNumber accepts BigInt; actual ECMAScript ToNumber must reject it.
	primitive := host.runtime.call_javascript_function(host.to_number_, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [value])!
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(host.runtime.context, primitive, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return number
}

fn (mut host WritableStreamHost) sink_callback(object voidptr, name string) !webidl.CallbackConversion {
	value := host.runtime.binding_property(object, name)!
	if C.JSValueIsUndefined(host.runtime.context, value) { return webidl.CallbackConversion{} }
	host_handle := voidptr(&host)
	callback := host.runtime.webidl_promise_callback(value, host.settings.stream_promise_context(), fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &WritableStreamHost(host_handle) }
		return host.value(value)
	})!
	return webidl.CallbackConversion{ callback: callback }
}

fn (mut host WritableStreamHost) strategy(object voidptr) !streams.QueuingStrategy {
	if C.JSValueIsUndefined(host.runtime.context, object) || C.JSValueIsNull(host.runtime.context, object) {
		return streams.QueuingStrategy{}
	}
	if !C.JSValueIsObject(host.runtime.context, object) {
		return error('TypeError: strategy must be a dictionary')
	}
	hwm_value := host.runtime.binding_property(object, 'highWaterMark')!
	mut high_water_mark := ?f64(none)
	if !C.JSValueIsUndefined(host.runtime.context, hwm_value) {
		high_water_mark = host.number(hwm_value)!
	}
	size := host.runtime.binding_property(object, 'size')!
	mut size_algorithm := ?streams.ValueSizeAlgorithm(none)
	if !C.JSValueIsUndefined(host.runtime.context, size) {
		if !C.JSValueIsObject(host.runtime.context, size) || !C.JSObjectIsFunction(host.runtime.context, size) {
			return error('TypeError: size must be callable')
		}
		host_handle := voidptr(&host)
		callback := host.runtime.webidl_callback(size, fn [host_handle] (value webidl.Value) !voidptr {
			mut host := unsafe { &WritableStreamHost(host_handle) }
			return host.value(value)
		})!
		size_algorithm = fn [host_handle, callback] (chunk streams.Value) !webidl.Value {
			mut host := unsafe { &WritableStreamHost(host_handle) }
			if host.closed { return webidl.undefined_value() }
			actual := host.stream_value(chunk)!
			return webidl.invoke_callback(callback, webidl.undefined_value(), [host.runtime.webidl_value(actual)!])
		}
	}
	return streams.QueuingStrategy{ high_water_mark: high_water_mark, size_value: size_algorithm }
}

fn (mut host WritableStreamHost) construct(args []voidptr) !voidptr {
	if host.closed { return error('WritableStream binding is closed') }
	object := host.argument(args, 0)
	// The generated constructor converts its object argument, then its strategy
	// dictionary. WritableStream::create_for_constructor converts UnderlyingSink.
	if !C.JSValueIsUndefined(host.runtime.context, object) && !C.JSValueIsObject(host.runtime.context, object) {
		return error('TypeError: underlyingSink must be an object')
	}
	strategy := host.strategy(host.argument(args, 1))!
	mut sink := streams.UnderlyingSink{ underlying_sink_value: webidl.null_value() }
	if !C.JSValueIsUndefined(host.runtime.context, object) {
		// Source generated dictionary conversion visits member names alphabetically.
		abort := host.sink_callback(object, 'abort')!
		close := host.sink_callback(object, 'close')!
		start := host.sink_callback(object, 'start')!
		type_value := host.runtime.binding_property(object, 'type')!
		write := host.sink_callback(object, 'write')!
		// Reserved any-valued type is checked for presence without coercing it.
		mut type_ := ?webidl.Value(none)
		if !C.JSValueIsUndefined(host.runtime.context, type_value) {
			type_ = host.runtime.webidl_value(type_value)!
		}
		sink = streams.UnderlyingSink{
			underlying_sink_value: host.runtime.webidl_value(object)!
			abort_callback:        abort.callback
			close_callback:        close.callback
			start_callback:        start.callback
			write_callback:        write.callback
			type_value:            type_
		}
	}
	stream := host.settings.create_writable_stream(sink, strategy)!
	return host.wrap(.stream, voidptr(stream), host.argument(args, 2))
}

fn (mut host WritableStreamHost) wrap(kind WritableStreamHostKind, native voidptr, desired_prototype voidptr) !voidptr {
	if existing := host.records[native] {
		if existing.kind != kind { return error('WritableStream native interface mismatch') }
		return existing.object
	}
	mut record := &WritableStreamHostRecord{ host: host, kind: kind, native: native }
	object := host.runtime.make_native_stream_wrapper(record)!
	mut prototype := host.prototypes[kind] or { return error('WritableStream prototype is missing') }
	if desired_prototype != unsafe { nil } && C.JSValueIsObject(host.runtime.context, desired_prototype) {
		prototype = desired_prototype
	}
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = object
	host.records[native] = record
	return object
}

fn (host &WritableStreamHost) record(value voidptr, kind WritableStreamHostKind) !&WritableStreamHostRecord {
	if host.closed { return error('WritableStream binding is closed') }
	data := host.runtime.native_stream_wrapper_record(value)
	if data == unsafe { nil } {
		return error('TypeError: Illegal WritableStream interface receiver')
	}
	record := unsafe { &WritableStreamHostRecord(data) }
	if voidptr(record.host) != voidptr(host) || record.kind != kind {
		return error('TypeError: Illegal WritableStream interface receiver')
	}
	return record
}

pub fn (runtime &Runtime) native_writable_stream(value voidptr) !&streams.WritableStream {
	host := writable_stream_bindings_[voidptr(runtime)] or { return error('WritableStream binding is unavailable') }
	return unsafe { &streams.WritableStream(host.record(value, .stream)!.native) }
}

pub fn (mut runtime Runtime) javascript_writable_stream(stream &streams.WritableStream) !voidptr {
	runtime.require_javascript_value_context()!
	mut host := writable_stream_bindings_[voidptr(&runtime)] or { return error('WritableStream binding is unavailable') }
	return host.wrap(.stream, voidptr(stream), unsafe { nil })
}

fn (runtime &Runtime) writable_stream_host() ?&WritableStreamHost {
	return writable_stream_bindings_[voidptr(runtime)] or { return none }
}

fn (mut host WritableStreamHost) promise(native &webidl.Promise) !voidptr {
	host_handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise_with_converters(native, fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &WritableStreamHost(host_handle) }
		return host.value(value)
	}, fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &WritableStreamHost(host_handle) }
		if value.kind == .string_ && (value.string_value.starts_with('TypeError:') || value.string_value.starts_with('RangeError:')) {
			return host.runtime.binding_exception_value(error(value.string_value))
		}
		return host.value(value)
	})
}

fn (mut host WritableStreamHost) value(value webidl.Value) !voidptr {
	if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
	if value.simple_exception_ != none { return host.runtime.javascript_simple_exception(value) }
	return match value.kind {
		.runtime_value { host.runtime.actual_webidl_value(value)! }
		.undefined { C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		.null_ { C.vox_jsc_JSValueMakeNull(host.runtime.context) }
		.boolean { C.vox_jsc_JSValueMakeBoolean(host.runtime.context, value.boolean_value) }
		.number { C.vox_jsc_JSValueMakeNumber(host.runtime.context, value.number_value) }
		.string_ { host.runtime.binding_string(value.string_value) }
		.platform_object {
			if value.platform_interfaces.contains('WritableStreamDefaultController') {
				return host.wrap(.default_controller, voidptr(value.opaque_id), unsafe { nil })
			}
			return error('Missing actual writable platform wrapper')
		}
		.promise {
			host.promise(value.promise_value_ or { return error('Missing actual writable Promise capability') })!
		}
		else { return error('Value requires its actual writable JavaScript wrapper') }
	}
}

fn (mut host WritableStreamHost) stream_value(value streams.Value) !voidptr {
	if value.kind == .runtime_value {
		return host.value(value.runtime_value_ or { return error('Missing actual writable chunk') })
	}
	return match value.kind {
		.undefined { host.value(webidl.undefined_value())! }
		.null_ { host.value(webidl.null_value())! }
		.boolean { host.value(webidl.boolean_value(value.boolean))! }
		.number { host.value(webidl.number_value(value.number))! }
		.string_ { host.value(webidl.string_value(value.text))! }
		else { return error('Chunk requires its actual writable JavaScript value') }
	}
}

fn (mut host WritableStreamHost) operate(args []voidptr) !voidptr {
	if host.closed { return error('WritableStream binding is closed') }
	object := host.argument(args, 0)
	operation := host.runtime.binding_dom_string(host.argument(args, 1))!
	argument := host.argument(args, 2)
	if operation.starts_with('stream.') {
		record := host.record(object, .stream)!
		mut stream := unsafe { &streams.WritableStream(record.native) }
		match operation {
			'stream.locked' { return C.vox_jsc_JSValueMakeBoolean(host.runtime.context, stream.locked()) }
			'stream.abort' {
				return host.promise(stream.abort(streams.runtime_value(host.runtime.webidl_value(argument)!)).as_webidl_promise())
			}
			'stream.close' { return host.promise(stream.close().as_webidl_promise()) }
			'stream.getWriter', 'stream.writerConstructor' {
				writer := stream.get_writer()!
				mut prototype := unsafe { voidptr(nil) }
				if operation == 'stream.writerConstructor' { prototype = argument }
				return host.wrap(.default_writer, voidptr(writer), prototype)
			}
			else {}
		}
	}
	if operation.starts_with('writer.') {
		record := host.record(object, .default_writer)!
		mut writer := unsafe { &streams.WritableStreamDefaultWriter(record.native) }
		match operation {
			'writer.closed' { return host.promise(writer.closed().as_webidl_promise()) }
			'writer.ready' { return host.promise(writer.ready().as_webidl_promise()) }
			'writer.desiredSize' {
				if size := writer.desired_size_for_bindings()!.value {
					return C.vox_jsc_JSValueMakeNumber(host.runtime.context, size)
				}
				return C.vox_jsc_JSValueMakeNull(host.runtime.context)
			}
			'writer.write' {
				return host.promise(writer.write(streams.runtime_value(host.runtime.webidl_value(argument)!)).as_webidl_promise())
			}
			'writer.abort' {
				return host.promise(writer.abort(streams.runtime_value(host.runtime.webidl_value(argument)!)).as_webidl_promise())
			}
			'writer.close' { return host.promise(writer.close().as_webidl_promise()) }
			'writer.releaseLock' {
				writer.release_lock()
				return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
			}
			else {}
		}
	}
	if operation.starts_with('controller.') {
		record := host.record(object, .default_controller)!
		mut controller := unsafe { &streams.WritableStreamDefaultController(record.native) }
		match operation {
			'controller.signal' {
				return host.runtime.javascript_abort_signal(controller.signal().dom_signal())
			}
			'controller.error' {
				streams.writable_stream_default_controller_error_if_needed(mut controller, streams.runtime_value(host.runtime.webidl_value(argument)!))
				return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
			}
			else {}
		}
	}
	return error('Unknown WritableStream interface operation')
}

const writable_stream_native_bootstrap = r'(function(create,operate){
 const define=Object.defineProperty,Type=TypeError,Reject=Promise.reject.bind(Promise),ConstructProxy=Proxy;
 const promiseOperation=(self,name,args)=>{try{return operate(self,name,...args)}catch(reason){return Reject(reason)}};
 const WritableStream=new ConstructProxy(function WritableStream(){throw new Type("WritableStream requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;return create(args[0],args[1],prototype)}});
 const WritableStreamDefaultWriter=new ConstructProxy(function WritableStreamDefaultWriter(stream){throw new Type("WritableStreamDefaultWriter requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;if(args.length<1)throw new Type("WritableStreamDefaultWriter requires 1 argument");return operate(args[0],"stream.writerConstructor",prototype)}});
 define(WritableStream.prototype,"constructor",{value:WritableStream,writable:true,configurable:true});
 define(WritableStreamDefaultWriter.prototype,"constructor",{value:WritableStreamDefaultWriter,writable:true,configurable:true});
 const WritableStreamDefaultController=new ConstructProxy(function WritableStreamDefaultController(){throw new Type("WritableStreamDefaultController requires new")},{construct(){throw new Type("Illegal constructor")}});
  define(WritableStreamDefaultController.prototype,"constructor",{value:WritableStreamDefaultController,writable:true,configurable:true});
 const attribute=(prototype,name,operation)=>define(prototype,name,{enumerable:true,configurable:true,get(){return operate(this,operation)}});
 const method=(prototype,name,value)=>define(prototype,name,{value,writable:true,enumerable:true,configurable:true});
 attribute(WritableStream.prototype,"locked","stream.locked");
 method(WritableStream.prototype,"abort",function abort(reason){return promiseOperation(this,"stream.abort",[reason])});
 method(WritableStream.prototype,"close",function close(){return promiseOperation(this,"stream.close",[])});
 method(WritableStream.prototype,"getWriter",function getWriter(){return operate(this,"stream.getWriter")});
 attribute(WritableStreamDefaultWriter.prototype,"closed","writer.closed");
 attribute(WritableStreamDefaultWriter.prototype,"ready","writer.ready");
 attribute(WritableStreamDefaultWriter.prototype,"desiredSize","writer.desiredSize");
 method(WritableStreamDefaultWriter.prototype,"abort",function abort(reason){return promiseOperation(this,"writer.abort",[reason])});
 method(WritableStreamDefaultWriter.prototype,"close",function close(){return promiseOperation(this,"writer.close",[])});
 method(WritableStreamDefaultWriter.prototype,"write",function write(chunk){return promiseOperation(this,"writer.write",[chunk])});
 method(WritableStreamDefaultWriter.prototype,"releaseLock",function releaseLock(){return operate(this,"writer.releaseLock")});
 attribute(WritableStreamDefaultController.prototype,"signal","controller.signal");
 method(WritableStreamDefaultController.prototype,"error",function error(reason){return operate(this,"controller.error",reason)});
 for(const prototype of [WritableStream.prototype,WritableStreamDefaultWriter.prototype])for(const name of ["abort","write"])if(Object.prototype.hasOwnProperty.call(prototype,name))define(prototype[name],"length",{value:0,configurable:true});
 define(WritableStreamDefaultController.prototype.error,"length",{value:0,configurable:true});
 for(const [Constructor,name] of [[WritableStream,"WritableStream"],[WritableStreamDefaultWriter,"WritableStreamDefaultWriter"],[WritableStreamDefaultController,"WritableStreamDefaultController"]]){define(Constructor,"prototype",{writable:false});define(Constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});define(globalThis,name,{value:Constructor,writable:true,configurable:true})}
 return [WritableStream.prototype,WritableStreamDefaultWriter.prototype,WritableStreamDefaultController.prototype]
})'
