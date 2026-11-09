@[has_globals]
module browserjs

import compression
import platform

@[heap]
struct CompressionBindingRecord {
mut:
	decoder ?&compression.IncrementalDecompressor
	encoder ?&compression.CompressionStream
}

@[heap]
struct CompressionBinding {
	buffer_copy voidptr
mut:
	records map[voidptr]&CompressionBindingRecord
}

__global compression_bindings_ = map[voidptr]&CompressionBinding{}

pub fn (mut runtime Runtime) install_compression_stream_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in compression_bindings_ { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	intrinsics := runtime.evaluate_host_value(crypto_buffer_source_intrinsics)!
	defer { runtime.release_javascript_value(intrinsics) }
	mut binding := &CompressionBinding{
		buffer_copy: runtime.retain_javascript_value(runtime.binding_property(intrinsics, 'copy')!)!
	}
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return runtime.compression_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(compression_stream_binding_factory)!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [operation, intrinsics, global])!
	register_runtime_binding(mut compression_bindings_, owner, binding)
	runtime.add_close_handler(fn [owner, mut binding] () {
		for _, mut record in binding.records {
			if mut decoder := record.decoder { decoder.close() }
		}
		binding.records = {}
		unregister_runtime_binding(mut compression_bindings_, owner)
	})
}

fn (mut runtime Runtime) compression_operation(mut binding CompressionBinding, args []voidptr) !voidptr {
	operation := runtime.binding_dom_string(args[0])!
	key := args[1]
	if operation == 'create' {
		format := compression.parse_compression_format(runtime.binding_dom_string(args[2])!)!
		mut record := &CompressionBindingRecord{}
		if C.JSValueToBoolean(runtime.context, args[3]) {
			record.decoder = compression.IncrementalDecompressor.create(format)!
		} else { record.encoder = compression.CompressionStream.construct_impl(format)! }
		binding.records[key] = record
		runtime.retain_javascript_value(key)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	mut record := binding.records[key] or {
		if operation == 'cancel' { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		return error('TypeError: Compression stream is closed')
	}
	if operation == 'cancel' {
		if mut decoder := record.decoder { decoder.close() }
		binding.records.delete(key)
		runtime.release_javascript_value(key)
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	mut bytes := []u8{}
	if operation == 'write' {
		view := runtime.call_javascript_function(binding.buffer_copy,
			C.vox_jsc_JSValueMakeUndefined(runtime.context), [args[2]])!
		runtime.retain_javascript_value(view)!
		defer { runtime.release_javascript_value(view) }
		mut exception := unsafe { nil }
		length := C.vox_jsc_JSObjectGetTypedArrayByteLength(runtime.context, view, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		if length > uint(2147483647) { return error('RangeError: Chunk exceeds the native byte span') }
		bytes = []u8{len: int(length)}
		if length > 0 {
			pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			unsafe { C.memcpy(bytes.data, pointer, length) }
		}
	}
	mut output := []u8{}
	mut failure := ''
	if mut decoder := record.decoder {
		result := decoder.push(bytes, operation == 'finish')
		output = result.bytes
		failure = result.error_message
	} else if encoder := record.encoder {
		mut writable := encoder.writable()
		if operation == 'write' { writable.write(bytes)! } else { writable.close()! }
		mut readable := encoder.readable()
		output = readable.read_all()
	}
	if operation == 'finish' || failure != '' {
		binding.records.delete(key)
		runtime.release_javascript_value(key)
	}
	mut exception := unsafe { nil }
	view := C.vox_jsc_JSObjectMakeTypedArray(runtime.context, C.kJSTypedArrayTypeUint8Array, uint(output.len), &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(view)!
	defer { runtime.release_javascript_value(view) }
	if output.len > 0 {
		pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(runtime.context, view, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		unsafe { C.memcpy(pointer, output.data, uint(output.len)) }
	}
	values := [view, runtime.binding_string(failure)]
	result := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	return result
}

const compression_stream_binding_factory = r'(function(operate,intrinsics,global){
 const define=Object.defineProperty,get=Object.getOwnPropertyDescriptor,apply=Reflect.apply,T=TypeError,NativeTransform=TransformStream;
 const records=new WeakMap(),has=WeakMap.prototype.has,read=WeakMap.prototype.get,store=WeakMap.prototype.set,validate=intrinsics.validate,copy=intrinsics.copy;
 function sides(receiver){if(!apply(has,records,[receiver]))throw new T("Illegal compression stream receiver");return apply(read,records,[receiver]);}
 for(const [name,decompress] of [["CompressionStream",false],["DecompressionStream",true]]){
  const Constructor={[name]:function(format){
   if(!new.target)throw new T(name+" constructor requires new");
   if(arguments.length<1)throw new T(name+" requires a format");
   format=`${format}`;
   const key={};operate("create",key,format,decompress);
   function result(operation,chunk,controller){const [output,error]=operate(operation,key,chunk);if(output.length)controller.enqueue(output);if(error)throw new T(error.replace(/^TypeError: /,""));}
   const transform=new NativeTransform({
    transform(chunk,controller){try{validate(chunk,true);const input=copy(chunk);result("write",input,controller);}catch(error){operate("cancel",key);throw error;}},
    flush(controller){try{result("finish",undefined,controller);}finally{operate("cancel",key);}},
    cancel(){operate("cancel",key);}
   });
   apply(store,records,[this,transform]);
  }}[name];
  define(Constructor,"prototype",{writable:false});
  for(const side of ["readable","writable"]){const descriptor=get({get [side](){return sides(this)[side];}},side);define(Constructor.prototype,side,{get:descriptor.get,enumerable:true,configurable:true});}
  define(Constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  define(global,name,{value:Constructor,writable:true,configurable:true});
 }
})'
