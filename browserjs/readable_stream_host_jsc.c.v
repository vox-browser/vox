// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Owning-realm generated binding adaptation for ReadableStream.cpp,
// ReadableStreamDefaultReader.cpp, generic reader and default controller IDL.
// The constructor/controller/reader algorithms execute their native records.
@[has_globals]
module browserjs

import streams
import webidl


__global readable_stream_bindings_ = map[voidptr]&ReadableStreamHost{}

fn C.JSObjectSetPrototype(context voidptr, object voidptr, prototype voidptr)
fn C.JSObjectGetPropertyAtIndex(context voidptr, object voidptr, index u32, exception &voidptr) voidptr
fn C.JSObjectMake(context voidptr, object_class voidptr, data voidptr) voidptr
fn C.JSObjectSetProperty(context voidptr, object voidptr, name voidptr, value voidptr, attributes u32, exception &voidptr)
fn C.JSValueIsUndefined(context voidptr, value voidptr) bool
fn C.JSValueIsNull(context voidptr, value voidptr) bool
fn C.JSValueMakeNull(context voidptr) voidptr
fn C.JSValueMakeBoolean(context voidptr, value bool) voidptr
fn C.JSValueMakeNumber(context voidptr, value f64) voidptr
fn C.JSValueToNumber(context voidptr, value voidptr, exception &voidptr) f64
fn C.JSObjectMakeTypedArray(context voidptr, type_ int, length uint, exception &voidptr) voidptr
fn C.JSObjectGetTypedArrayBytesPtr(context voidptr, object voidptr, exception &voidptr) voidptr

pub fn (mut host ReadableStreamHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner_handle := voidptr(&runtime)
	if existing := readable_stream_bindings_[owner_handle] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('ReadableStream binding already belongs to this runtime')
	}
	host.runtime = &runtime
	host.read_loop_byte_copy = runtime.evaluate_host_value(read_loop_byte_copy_intrinsic)!
	host_handle := voidptr(&host)
	create := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ReadableStreamHost(host_handle) }
		return host.construct(args) or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	operate := runtime.make_value_host_function(fn [host_handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &ReadableStreamHost(host_handle) }
		return host.operate(args) or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	installer := runtime.evaluate_host_value(readable_stream_native_bootstrap)!
	prototypes := runtime.call_javascript_function(installer, C.JSValueMakeUndefined(runtime.context), [create, operate])!
	runtime.retain_javascript_value(prototypes)!
	defer { runtime.release_javascript_value(prototypes); runtime.release_javascript_value(installer) }
	for index, kind in [ReadableStreamHostKind.stream, .default_reader, .default_controller, .byte_controller, .byob_reader] {
		mut exception := unsafe { nil }
		prototype := C.JSObjectGetPropertyAtIndex(runtime.context, prototypes, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		host.prototypes[kind] = runtime.retain_javascript_value(prototype)!
	}
	readable_stream_bindings_[owner_handle] = &host
	runtime.add_close_handler(fn [host_handle, owner_handle] () {
		mut host := unsafe { &ReadableStreamHost(host_handle) }
		host.close()
		readable_stream_bindings_.delete(owner_handle)
	})
}

pub fn (mut runtime Runtime) javascript_readable_stream(stream &streams.ReadableStream) !voidptr {
	runtime.require_javascript_value_context()!
	mut host := readable_stream_bindings_[voidptr(&runtime)] or { return error('ReadableStream binding is unavailable') }
	return host.wrap(.stream, voidptr(stream))
}

fn (runtime &Runtime) readable_stream_host() ?&ReadableStreamHost {
	return readable_stream_bindings_[voidptr(runtime)] or { return none }
}

pub fn (runtime &Runtime) native_readable_stream(value voidptr) !&streams.ReadableStream {
	host := readable_stream_bindings_[voidptr(runtime)] or { return error('ReadableStream binding is unavailable') }
	return unsafe { &streams.ReadableStream(host.record(value, .stream)!.native) }
}

fn (host &ReadableStreamHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (host &ReadableStreamHost) property(object voidptr, name string) !voidptr {
	key := js_source_string(name)
	defer { C.JSStringRelease(key) }
	mut exception := unsafe { nil }
	value := C.JSObjectGetProperty(host.runtime.context, object, key, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return value
}

fn (mut host ReadableStreamHost) number(value voidptr) !f64 {
	return webidl.value_to_number(host.runtime.webidl_value(value)!)
}

fn (mut host ReadableStreamHost) text(value voidptr) !string {
	wrapped := host.runtime.webidl_value(value)!
	return webidl.to_string(wrapped)
}

fn (mut host ReadableStreamHost) source_callback(object voidptr, name string) !webidl.CallbackConversion {
	value := host.property(object, name)!
	if C.JSValueIsUndefined(host.runtime.context, value) { return webidl.CallbackConversion{} }
	host_handle := voidptr(&host)
	callback := host.runtime.webidl_promise_callback(value, host.settings.stream_promise_context(), fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &ReadableStreamHost(host_handle) }
		return host.value(value)
	})!
	return webidl.CallbackConversion{ callback: callback }
}

fn (mut host ReadableStreamHost) construct(args []voidptr) !voidptr {
	if host.closed { return error('ReadableStream binding is closed') }
	object := host.argument(args, 0)
	if !C.JSValueIsUndefined(host.runtime.context, object) && !C.JSValueIsObject(host.runtime.context, object) { return error('TypeError: underlyingSource must be an object') }
	// Generated constructor converts strategy before source factory dictionary.
	strategy_value := host.argument(args, 1)
	mut strategy := streams.QueuingStrategy{}
	if !C.JSValueIsUndefined(host.runtime.context, strategy_value) && !C.JSValueIsNull(host.runtime.context, strategy_value) {
		if !C.JSValueIsObject(host.runtime.context, strategy_value) { return error('TypeError: strategy must be a dictionary') }
		hwm := host.property(strategy_value, 'highWaterMark')!
		mut high_water_mark := ?f64(none)
		if !C.JSValueIsUndefined(host.runtime.context, hwm) { high_water_mark = host.number(hwm)! }
		size := host.property(strategy_value, 'size')!
		mut size_algorithm := ?streams.ValueSizeAlgorithm(none)
		if !C.JSValueIsUndefined(host.runtime.context, size) {
			if !C.JSValueIsObject(host.runtime.context, size) || !C.JSObjectIsFunction(host.runtime.context, size) { return error('TypeError: size must be callable') }
			host_handle := voidptr(&host)
			callback := host.runtime.webidl_callback(size, fn [host_handle] (value webidl.Value) !voidptr {
				mut host := unsafe { &ReadableStreamHost(host_handle) }
				return host.value(value)
			})!
			size_algorithm = fn [host_handle, callback] (chunk streams.Value) !webidl.Value {
				mut host := unsafe { &ReadableStreamHost(host_handle) }
				if host.closed { return webidl.undefined_value() }
				value := host.stream_value(chunk)!
				return webidl.invoke_callback(callback, webidl.undefined_value(), [host.runtime.webidl_value(value)!])
			}
		}
		strategy = streams.QueuingStrategy{ high_water_mark: high_water_mark, size_value: size_algorithm }
	}
	mut source := streams.UnderlyingSource{ underlying_source_value: webidl.null_value() }
	if !C.JSValueIsUndefined(host.runtime.context, object) {
		mut auto_allocate := ?u64(none)
		auto_value := host.property(object, 'autoAllocateChunkSize')!
		if !C.JSValueIsUndefined(host.runtime.context, auto_value) {
			auto_allocate = u64(webidl.convert_to_int(webidl.number_value(host.number(auto_value)!), 64, false, .yes, .no)!)
		}
		// Generated dictionary conversion follows the source member-name order.
		cancel := host.source_callback(object, 'cancel')!
		pull := host.source_callback(object, 'pull')!
		start := host.source_callback(object, 'start')!
		type_value := host.property(object, 'type')!
		mut type_ := streams.UnderlyingSourceType.default_source
		if !C.JSValueIsUndefined(host.runtime.context, type_value) {
			if host.text(type_value)! != 'bytes' { return error('TypeError: Invalid ReadableStreamType value') }
			type_ = .bytes
		}
		source = streams.UnderlyingSource{
			underlying_source_value: host.runtime.webidl_value(object)!
			auto_allocate_chunk_size: auto_allocate
			cancel_callback: cancel.callback
			pull_callback: pull.callback
			start_callback: start.callback
			type_: type_
		}
	}
	stream := streams.ReadableStream.create_for_constructor(host.read_loop_realm(), source, strategy)!
	return host.wrap_with_prototype(.stream, voidptr(stream), host.argument(args, 2))
}

fn (mut host ReadableStreamHost) wrap(kind ReadableStreamHostKind, native voidptr) !voidptr {
	return host.wrap_with_prototype(kind, native, unsafe { nil })
}

fn (mut host ReadableStreamHost) wrap_with_prototype(kind ReadableStreamHostKind, native voidptr, desired_prototype voidptr) !voidptr {
	if record := host.records[native] {
		if record.kind != kind { return error('ReadableStream native wrapper interface mismatch') }
		return record.object
	}
	mut record := &ReadableStreamHostRecord{ host: host, kind: kind, native: native }
	object := host.runtime.make_native_stream_wrapper(record)!
	mut prototype := host.prototypes[kind] or { return error('ReadableStream native prototype is missing') }
	if desired_prototype != unsafe { nil } && C.JSValueIsObject(host.runtime.context, desired_prototype) { prototype = desired_prototype }
	C.JSObjectSetPrototype(host.runtime.context, object, prototype)
	record.object = object
	host.records[native] = record
	return object
}

fn (host &ReadableStreamHost) record(value voidptr, kind ReadableStreamHostKind) !&ReadableStreamHostRecord {
	if host.closed { return error('ReadableStream binding is closed') }
	data := host.runtime.native_stream_wrapper_record(value)
	if data == unsafe { nil } { return error('TypeError: Invalid ReadableStream interface receiver') }
	record := unsafe { &ReadableStreamHostRecord(data) }
	if voidptr(record.host) != voidptr(host) || record.kind != kind { return error('TypeError: Invalid ReadableStream interface receiver') }
	return record
}

fn (mut host ReadableStreamHost) promise(native &webidl.Promise) !voidptr {
	host_handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise_with_converters(native, fn [host_handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &ReadableStreamHost(host_handle) }; return host.value(value)
	}, fn [host_handle] (reason webidl.Value) !voidptr {
		mut host := unsafe { &ReadableStreamHost(host_handle) }
		// Author JS reasons are actual runtime values, including string reasons.
		// Only the native model's SimpleException string boundary selects Error.
		if reason.kind == .string_ && (reason.string_value.starts_with('TypeError:') || reason.string_value.starts_with('RangeError:')) {
			return host.runtime.binding_exception_value(error(reason.string_value))
		}
		return host.value(reason)
	})
}

fn (mut host ReadableStreamHost) value(value webidl.Value) !voidptr {
	if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
	if value.simple_exception_ != none { return host.runtime.javascript_simple_exception(value) }
	context := host.runtime.context
	match value.kind {
		.runtime_value { return host.runtime.actual_webidl_value(value) }
		.undefined { return C.JSValueMakeUndefined(context) }
		.null_ { return C.JSValueMakeNull(context) }
		.boolean { return C.JSValueMakeBoolean(context, value.boolean_value) }
		.number { return C.JSValueMakeNumber(context, value.number_value) }
		.string_ {
			text := js_source_string(value.string_value)
			defer { C.JSStringRelease(text) }
			return C.JSValueMakeString(context, text)
		}
		.object {
			object := C.JSObjectMake(context, unsafe { nil }, unsafe { nil })
			for name, property in value.object_value {
				actual := host.value(property)!
				key := js_source_string(name)
				mut exception := unsafe { nil }
				C.JSObjectSetProperty(context, object, key, actual, 0, &exception)
				C.JSStringRelease(key)
				if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
			}
			return object
		}
		.platform_object {
			if value.platform_interfaces.contains('ReadableStreamDefaultController') { return host.wrap(.default_controller, voidptr(value.opaque_id)) }
			if value.platform_interfaces.contains('ReadableByteStreamController') { return host.wrap(.byte_controller, voidptr(value.opaque_id)) }
		}
		.promise { return host.promise(value.promise_value_ or { return error('Missing native readable Promise capability') }) }
		.buffer_source {
			buffer := value.buffer_value or { return error('Missing native readable buffer') }
			if buffer.kind != .uint8_array { return error('Native readable result requires an unsigned-byte view') }
			bytes := webidl.get_buffer_source_copy(buffer)
			mut exception := unsafe { nil }
			object := C.JSObjectMakeTypedArray(context, C.kJSTypedArrayTypeUint8Array, uint(bytes.len), &exception)
			if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
			data := C.JSObjectGetTypedArrayBytesPtr(context, object, &exception)
			if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
			if bytes.len > 0 { unsafe { vmemcpy(data, bytes.data, bytes.len) } }
			return object
		}
		else {}
	}
	return error('Value is outside the installed readable binding conversions')
}

fn (mut host ReadableStreamHost) stream_value(value streams.Value) !voidptr {
	if value.kind == .runtime_value { return host.value(value.runtime_value_ or { return error('Missing readable runtime chunk') }) }
	return match value.kind {
		.undefined { host.value(webidl.undefined_value())! }
		.null_ { host.value(webidl.null_value())! }
		.boolean { host.value(webidl.boolean_value(value.boolean))! }
		.number { host.value(webidl.number_value(value.number))! }
		.string_ { host.value(webidl.string_value(value.text))! }
		else { return error('Native scalar chunk is outside the installed readable binding') }
	}
}

fn (mut host ReadableStreamHost) operate(args []voidptr) !voidptr {
	object := host.argument(args, 0)
	operation := host.text(host.argument(args, 1))!
	argument := host.argument(args, 2)
	if operation.starts_with('stream.') {
		record := host.record(object, .stream)!
		mut stream := unsafe { &streams.ReadableStream(record.native) }
		match operation {
			'stream.locked' { return C.JSValueMakeBoolean(host.runtime.context, stream.locked()) }
			'stream.cancel' { return host.promise(stream.cancel(streams.runtime_value(host.runtime.webidl_value(argument)!)).as_webidl_promise()) }
			'stream.pipeTo', 'stream.pipeThrough' { return host.pipe_operation(mut stream, operation, argument, host.argument(args, 3)) }
			'stream.getReader', 'stream.readerConstructor' {
				mut mode := ?streams.ReadableStreamReaderMode(none)
				if operation == 'stream.getReader' && !C.JSValueIsUndefined(host.runtime.context, argument) && !C.JSValueIsNull(host.runtime.context, argument) {
					if !C.JSValueIsObject(host.runtime.context, argument) { return error('TypeError: reader options must be a dictionary') }
					value := host.property(argument, 'mode')!
					if !C.JSValueIsUndefined(host.runtime.context, value) {
						if host.text(value)! != 'byob' { return error('TypeError: Invalid ReadableStreamReaderMode value') }
						mode = .byob
					}
				}
				reader := stream.get_reader(streams.ReadableStreamGetReaderOptions{ mode: mode })!
				if reader.kind == .byob { return host.wrap(.byob_reader, voidptr(reader.byob_reader)) }
				mut prototype := unsafe { voidptr(nil) }
				if operation == 'stream.readerConstructor' { prototype = argument }
				return host.wrap_with_prototype(.default_reader, voidptr(reader.default_reader), prototype)
			}
			else {}
		}
	}
	if operation.starts_with('reader.') {
		record := host.record(object, .default_reader)!
		mut reader := unsafe { &streams.ReadableStreamDefaultReader(record.native) }
		match operation {
			'reader.closed' { return host.promise(reader.closed().as_webidl_promise()) }
			'reader.read' { return host.promise(reader.read().as_webidl_promise()) }
			'reader.cancel' { return host.promise(reader.cancel(streams.runtime_value(host.runtime.webidl_value(argument)!)).as_webidl_promise()) }
			'reader.releaseLock' { reader.release_lock()!; return C.JSValueMakeUndefined(host.runtime.context) }
			else {}
		}
	}
	if operation.starts_with('controller.') {
		record := host.record(object, .default_controller)!
		mut controller := unsafe { &streams.ReadableStreamDefaultController(record.native) }
		match operation {
			'controller.desiredSize' { if size := controller.desired_size() { return C.JSValueMakeNumber(host.runtime.context, size) }; return C.JSValueMakeNull(host.runtime.context) }
			'controller.close' { controller.close()!; return C.JSValueMakeUndefined(host.runtime.context) }
			'controller.enqueue' { controller.enqueue(streams.runtime_value(host.runtime.webidl_value(argument)!))!; return C.JSValueMakeUndefined(host.runtime.context) }
			'controller.error' { streams.readable_stream_default_controller_error(mut controller, streams.runtime_value(host.runtime.webidl_value(argument)!)); return C.JSValueMakeUndefined(host.runtime.context) }
			else {}
		}
	}
	if operation.starts_with('byteController.') {
		record := host.record(object, .byte_controller)!
		mut controller := unsafe { &streams.ReadableByteStreamController(record.native) }
		match operation {
			'byteController.desiredSize' { if size := controller.desired_size() { return C.JSValueMakeNumber(host.runtime.context, size) }; return C.JSValueMakeNull(host.runtime.context) }
			'byteController.close' { controller.close()!; return C.JSValueMakeUndefined(host.runtime.context) }
			'byteController.error' { streams.readable_byte_stream_controller_error(mut controller, streams.runtime_value(host.runtime.webidl_value(argument)!)); return C.JSValueMakeUndefined(host.runtime.context) }
			else {}
		}
	}
	return error('ReadableStream operation is outside the installed interface bindings')
}

const readable_stream_native_bootstrap = '(function(create,operate){
  const Reject=Promise.reject.bind(Promise),Type=TypeError,ConstructProxy=Proxy,define=Object.defineProperty;
  const promiseOperation=(self,name,args)=>{try{return operate(self,name,...args)}catch(reason){return Reject(reason)}};
  const ReadableStream=new ConstructProxy(function ReadableStream(){throw new Type("ReadableStream requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;return create(args[0],args[1],prototype)}});
  const ReadableStreamDefaultReader=new ConstructProxy(function ReadableStreamDefaultReader(stream){throw new Type("ReadableStreamDefaultReader requires new")},{construct(target,args,newTarget){const prototype=newTarget.prototype;if(args.length<1)throw new Type("ReadableStreamDefaultReader requires 1 argument");return operate(args[0],"stream.readerConstructor",prototype)}});
  define(ReadableStream.prototype,"constructor",{value:ReadableStream,writable:true,configurable:true});
  define(ReadableStreamDefaultReader.prototype,"constructor",{value:ReadableStreamDefaultReader,writable:true,configurable:true});
  const ReadableStreamDefaultController=new ConstructProxy(function ReadableStreamDefaultController(){throw new Type("ReadableStreamDefaultController requires new")},{construct(){throw new Type("Illegal constructor")}});
  define(ReadableStreamDefaultController.prototype,"constructor",{value:ReadableStreamDefaultController,writable:true,configurable:true});
  const ReadableByteStreamController=new ConstructProxy(function ReadableByteStreamController(){throw new Type("ReadableByteStreamController requires new")},{construct(){throw new Type("Illegal constructor")}});
  define(ReadableByteStreamController.prototype,"constructor",{value:ReadableByteStreamController,writable:true,configurable:true});
  const byobPrototype=Object.create(Object.prototype);
  const attribute=(prototype,name,operation)=>Object.defineProperty(prototype,name,{enumerable:true,configurable:true,get(){return operate(this,operation)}});
  attribute(ReadableStream.prototype,"locked","stream.locked");
  ReadableStream.prototype.cancel=function(...args){return promiseOperation(this,"stream.cancel",args)};
  ReadableStream.prototype.getReader=function(...args){return operate(this,"stream.getReader",...args)};
  ReadableStream.prototype.pipeTo=function(destination,...args){return promiseOperation(this,"stream.pipeTo",[destination,...args])};
  ReadableStream.prototype.pipeThrough=function(transform,...args){return operate(this,"stream.pipeThrough",transform,...args)};
  attribute(ReadableStreamDefaultReader.prototype,"closed","reader.closed");
  ReadableStreamDefaultReader.prototype.read=function(){return promiseOperation(this,"reader.read",[])};
  ReadableStreamDefaultReader.prototype.cancel=function(...args){return promiseOperation(this,"reader.cancel",args)};
  ReadableStreamDefaultReader.prototype.releaseLock=function(){return operate(this,"reader.releaseLock")};
  attribute(ReadableStreamDefaultController.prototype,"desiredSize","controller.desiredSize");
  ReadableStreamDefaultController.prototype.close=function(){return operate(this,"controller.close")};
  ReadableStreamDefaultController.prototype.enqueue=function(...args){return operate(this,"controller.enqueue",...args)};
  ReadableStreamDefaultController.prototype.error=function(...args){return operate(this,"controller.error",...args)};
  attribute(ReadableByteStreamController.prototype,"desiredSize","byteController.desiredSize");
  ReadableByteStreamController.prototype.close=function(){return operate(this,"byteController.close")};
  ReadableByteStreamController.prototype.error=function(...args){return operate(this,"byteController.error",...args)};
  for(const [Constructor,name] of [[ReadableStream,"ReadableStream"],[ReadableStreamDefaultReader,"ReadableStreamDefaultReader"],[ReadableStreamDefaultController,"ReadableStreamDefaultController"],[ReadableByteStreamController,"ReadableByteStreamController"]]){
    define(Constructor,"prototype",{writable:false});
    Object.defineProperty(Constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
    Object.defineProperty(globalThis,name,{value:Constructor,writable:true,configurable:true});
  }
  return [ReadableStream.prototype,ReadableStreamDefaultReader.prototype,ReadableStreamDefaultController.prototype,ReadableByteStreamController.prototype,byobPrototype];
})'
