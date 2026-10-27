// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fileapi
import html
import libjs
import math
import webidl
import webcrypto


fn C.JSValueIsArray(context voidptr, value voidptr) bool

pub fn StructuredCloneBridge.create(runtime &Runtime) !&StructuredCloneBridge {
	runtime.require_javascript_value_context()!
	mut owner := unsafe { &Runtime(runtime) }
	return &StructuredCloneBridge{runtime: runtime, intrinsic_: owner.evaluate_host_value(structured_clone_projection_intrinsic)!}
}

fn (bridge &StructuredCloneBridge) engine(name string, arguments []voidptr) !voidptr {
	bridge.runtime.require_javascript_value_context()!
	key := js_source_string(name)
	defer { C.JSStringRelease(key) }
	mut exception := unsafe { nil }
	function := C.JSObjectGetProperty(bridge.runtime.context, bridge.intrinsic_, key, &exception)
	if exception != unsafe { nil } { return bridge.runtime.actual_javascript_exception(exception) }
	return bridge.runtime.call_engine_function(function, arguments)
}

fn (bridge &StructuredCloneBridge) number(value voidptr) !f64 {
	bridge.runtime.require_javascript_value_context()!
	mut exception := unsafe { nil }
	result := C.JSValueToNumber(bridge.runtime.context, value, &exception)
	if exception != unsafe { nil } { return bridge.runtime.actual_javascript_exception(exception) }
	return result
}

fn native_clone_unsupported(message string) IError {
	return webidl.throw_value(webidl.dom_exception_value(webidl.DOMException.create('DataCloneError', message)))
}

struct NativeCloneProjection {
	bridge &StructuredCloneBridge
mut:
	input_memory map[u64]&dom.JSValue
	output_memory map[u64]voidptr
	roots []voidptr
}

fn (mut projection NativeCloneProjection) root(value voidptr) !voidptr {
	mut owner := unsafe { &Runtime(projection.bridge.runtime) }
	retained := owner.retain_javascript_value(value)!
	projection.roots << retained
	return retained
}

fn (mut projection NativeCloneProjection) adopt_root(value voidptr) voidptr {
	// Public Runtime value factories already protected this actual value.
	// Transfer that one temporary root to the projection's cleanup list.
	projection.roots << value
	return value
}

fn (bridge &StructuredCloneBridge) bigint(value voidptr) !&libjs.BigInt {
	// The captured engine BigInt primitive operation exposes its full integer
	// through the arithmetic ABI, never a surrogate returned JavaScript value.
	text := bridge.runtime.native_utf16_string(bridge.engine('bigint_text', [value])!)!
	return libjs.string_to_bigint(text) or { return error('Actual BigInt primitive could not be projected') }
}

fn (mut projection NativeCloneProjection) release_roots() {
	mut owner := unsafe { &Runtime(projection.bridge.runtime) }
	for value in projection.roots { owner.release_javascript_value(value) }
	projection.roots.clear()
}

fn (mut projection NativeCloneProjection) project(value voidptr) !&dom.JSValue {
	bridge := projection.bridge
	projection.root(value)!
	identity := u64(value)
	if C.JSValueIsObject(bridge.runtime.context, value) {
		if existing := projection.input_memory[identity] { return existing }
	}
	tag := int(bridge.number(bridge.engine('classify', [value])!)!)
	mut primitive := dom.js_undefined()
	match tag {
		1 { return &primitive }
		2 { primitive = dom.js_null(); return &primitive }
		3 { primitive = dom.js_bool(C.JSValueToBoolean(bridge.runtime.context, value)); return &primitive }
		4 { primitive = dom.js_number(bridge.number(value)!); return &primitive }
		5 { primitive = dom.js_utf16_string(bridge.runtime.native_utf16_string(value)!); return &primitive }
		6 {
			integer := bridge.bigint(value)!
			primitive = dom.js_webidl_value(webidl.bigint_value_for_record(integer))
			return &primitive
		}
		-1 { return native_clone_unsupported('Cannot serialize Symbol') }
		-2 { return native_clone_unsupported('Cannot serialize functions') }
		20 { return native_clone_unsupported('Native SharedArrayBuffer isolation and sharing slots are not yet bound') }
		else {}
	}
	mut kind := html.StructuredObjectKind.object
	mut native_exception := ?&webidl.DOMException(none)
	mut native_quota := ?&webidl.QuotaExceededError(none)
	mut native_key := ?&webcrypto.CryptoKey(none)
	mut native_blob := ?&fileapi.Blob(none)
	mut native_file := ?&fileapi.File(none)
	mut native_file_list := ?&fileapi.FileList(none)
	match tag {
		7 { kind = .boolean_object }
		8 { kind = .number_object }
		9 { kind = .string_object }
		10 { kind = .big_int_object }
		11 { kind = .date }
		13 { kind = .map }
		14 { kind = .set }
		16 { kind = .error_object }
		22 { kind = .array_buffer }
		23 { kind = .array_buffer_view }
		17 {
			// C API checks the actual JSArray record. Array.isArray would also
			// accept Proxy(Array), unlike source is<JS::Array>.
			if C.JSValueIsArray(bridge.runtime.context, value) {
				kind = .array
			} else {
				candidate := bridge.runtime.native_clone_dom_exception(value)!
				if quota := candidate.quota {
					kind = .serializable_object
					native_quota = quota
				} else if exception := candidate.value {
					kind = .serializable_object
					native_exception = exception
				} else if key := bridge.runtime.native_clone_crypto_key(value) {
					kind = .serializable_object
					native_key = key
				} else if list := bridge.runtime.native_clone_file_list(value) {
					kind = .serializable_object
					native_file_list = list
				} else if file := bridge.runtime.native_clone_file(value) {
					kind = .serializable_object
					native_file = file
				} else if blob := bridge.runtime.native_clone_blob(value) {
					kind = .serializable_object
					native_blob = blob
				} else {
					bridge.runtime.require_native_clone_non_platform(value)!
				}
			}
		}
		else { return native_clone_unsupported('Source native projection for this JavaScript family is not yet bound') }
	}
	mut object := html.StructuredObject.create(kind)
	result := html.structured_object_value(object)
	projection.input_memory[identity] = &result
	if list := native_file_list {
		object.serializable_interface_ = .file_list
		object.file_list_ = list
		return &result
	}
	if file := native_file {
		object.serializable_interface_ = .file
		object.file_ = file
		return &result
	}
	if blob := native_blob {
		object.serializable_interface_ = .blob
		object.blob_ = blob
		return &result
	}
	if key := native_key {
		object.serializable_interface_ = .crypto_key
		object.crypto_key_ = key
		return &result
	}
	if quota := native_quota {
		object.serializable_interface_ = .quota_exceeded_error
		object.quota_exceeded_error_ = quota
		return &result
	}
	if exception := native_exception {
		object.serializable_interface_ = .dom_exception
		object.dom_exception_ = exception
		return &result
	}
	if tag >= 7 && tag <= 10 {
		internal := projection.root(bridge.engine('boxed_value', [value, C.JSValueMakeNumber(bridge.runtime.context, f64(tag))])!)!
		match kind {
			.boolean_object { object.boolean_data = C.JSValueToBoolean(bridge.runtime.context, internal) }
			.number_object { object.number_data = bridge.number(internal)! }
			.string_object { object.string_utf16_ = bridge.runtime.native_utf16_string(internal)! }
			.big_int_object {
				object.bigint_data = bridge.bigint(internal)!
			}
			else {}
		}
		return &result
	}
	if kind == .date {
		object.number_data = bridge.number(bridge.engine('date_value', [value])!)!
		return &result
	}
	if kind == .error_object {
		projection.project_error(value, mut object)!
		return &result
	}
	if kind == .array_buffer {
		projection.project_array_buffer(value, mut object)!
		return &result
	}
	if kind == .array_buffer_view {
		projection.project_array_buffer_view(value, mut object)!
		return &result
	}
	if kind == .map || kind == .set {
		// Source copiedList is complete before any nested getters execute.
		snapshot := projection.root(bridge.engine(if kind == .map { 'map_snapshot' } else { 'set_snapshot' }, [value])!)!
		count := int(bridge.number(bridge.engine('list_length', [snapshot])!)!)
		for index in 0 .. count {
			first := bridge.engine('list_item', [snapshot, C.JSValueMakeNumber(bridge.runtime.context, f64(index))])!
			if kind == .map {
				key := projection.project(bridge.engine('list_item', [first, C.JSValueMakeNumber(bridge.runtime.context, 0)])!)!
				item := projection.project(bridge.engine('list_item', [first, C.JSValueMakeNumber(bridge.runtime.context, 1)])!)!
				object.entries << html.StructuredMapEntry{key: key, value: item}
			} else {
				object.values << projection.project(first)!
			}
		}
		return &result
	}
	if kind == .array {
		object.array_length = u32(bridge.number(bridge.engine('array_length', [value])!)!)
	}
	keys := projection.root(bridge.engine('enumerable_keys', [value])!)!
	count := int(bridge.number(bridge.engine('list_length', [keys])!)!)
	for index in 0 .. count {
		key := bridge.engine('list_item', [keys, C.JSValueMakeNumber(bridge.runtime.context, f64(index))])!
		if !C.JSValueToBoolean(bridge.runtime.context, bridge.engine('has_own', [value, key])!) { continue }
		// Source HasOwnProperty, Get(receiver=value), recursive serialize, key.
		item := projection.project(bridge.engine('get', [value, key])!)!
		text := bridge.runtime.native_utf16_string(key)!
		object.properties << html.StructuredProperty{key: text.str(), key_utf16_: text, value: item}
	}
	return &result
}

fn (mut projection NativeCloneProjection) reconstruct(value dom.JSValue) !voidptr {
	bridge := projection.bridge
	mut owner := unsafe { &Runtime(bridge.runtime) }
	match value.kind {
		.undefined { return C.JSValueMakeUndefined(owner.context) }
		.null_ { return C.JSValueMakeNull(owner.context) }
		.boolean { return C.JSValueMakeBoolean(owner.context, value.boolean_data) }
		.number { return C.JSValueMakeNumber(owner.context, value.number_data) }
		.string { return projection.adopt_root(owner.javascript_utf16_string(value.string_utf16_ or { libjs.utf16_string(value.string_data) })!) }
		.runtime_value { return projection.adopt_root(owner.javascript_bigint(value.as_webidl_value()!)!) }
		else {}
	}
	object := html.structured_object_from_value(value)!
	identity := u64(voidptr(object))
	if existing := projection.output_memory[identity] { return existing }
	if object.kind == .serializable_object {
		interface_name := object.serializable_interface_ or { return native_clone_unsupported('Source native serializable object has no primary interface') }
		mut actual := unsafe { nil }
		if interface_name == .dom_exception {
			exception := object.dom_exception_ or { return native_clone_unsupported('Source DOMException has no native payload record') }
			actual = projection.root(owner.javascript_dom_exception(webidl.dom_exception_value_for_record(exception))!)!
		} else if interface_name == .quota_exceeded_error {
			exception := object.quota_exceeded_error_ or { return native_clone_unsupported('Source QuotaExceededError has no native payload record') }
			actual = projection.root(owner.javascript_quota_exceeded_error(exception)!)!
		} else if interface_name == .crypto_key {
			key := object.crypto_key_ or { return native_clone_unsupported('Source CryptoKey has no native payload record') }
			actual = projection.root(owner.javascript_crypto_key(key)!)!
		} else if interface_name == .file_list {
			list := object.file_list_ or { return native_clone_unsupported('Source FileList has no native payload record') }
			actual = projection.root(owner.javascript_file_list(list)!)!
		} else if interface_name == .file {
			file := object.file_ or { return native_clone_unsupported('Source File has no native payload record') }
			actual = projection.root(owner.javascript_file(file)!)!
		} else if interface_name == .blob {
			blob := object.blob_ or { return native_clone_unsupported('Source Blob has no native payload record') }
			actual = projection.root(owner.javascript_blob(blob)!)!
		} else {
			return native_clone_unsupported('Source native primary serializable interface is not yet bound')
		}
		projection.output_memory[identity] = actual
		return actual
	}
	if object.kind == .error_object {
		actual := projection.root(projection.reconstruct_error(object)!)!
		projection.output_memory[identity] = actual
		return actual
	}
	if object.kind == .array_buffer {
		actual := projection.reconstruct_array_buffer(object)!
		projection.output_memory[identity] = actual
		return actual
	}
	if object.kind == .array_buffer_view {
		actual := projection.reconstruct_array_buffer_view(object)!
		projection.output_memory[identity] = actual
		return actual
	}
	mut data := C.JSValueMakeUndefined(owner.context)
	mut tag := 17
	match object.kind {
		.boolean_object { tag = 7; data = C.JSValueMakeBoolean(owner.context, object.boolean_data) }
		.number_object { tag = 8; data = C.JSValueMakeNumber(owner.context, object.number_data) }
		.string_object { tag = 9; data = projection.adopt_root(owner.javascript_utf16_string(object.string_utf16_ or { libjs.utf16_string(object.string_data) })!) }
		.big_int_object {
			tag = 10
			integer := object.bigint_data or { return native_clone_unsupported('Missing source boxed BigInt record') }
			data = projection.adopt_root(owner.javascript_bigint(webidl.bigint_value_for_record(integer))!)
		}
		.date {
			// Source Date::create installs the raw decoded double. JSC's native
			// constructor TimeClips it; reject values that would silently change.
			date := object.number_data
			if !math.is_nan(date) && (math.is_inf(date, 0) || math.abs(date) > 8640000000000000.0
				|| math.trunc(date) != date || (date == 0 && math.signbit(date))) {
				return native_clone_unsupported('Source Date value cannot be installed exactly by this native constructor')
			}
			tag = 11
			data = C.JSValueMakeNumber(owner.context, date)
		}
		.map { tag = 13 }
		.set { tag = 14 }
		.array { tag = 15; data = C.JSValueMakeNumber(owner.context, f64(object.array_length or { u32(object.values.len) })) }
		.object { data = C.JSValueMakeBoolean(owner.context, object.null_prototype) }
		else { return native_clone_unsupported('Source native reconstruction for this JavaScript family is not yet bound') }
	}
	actual := projection.root(bridge.engine('create', [C.JSValueMakeNumber(owner.context, f64(tag)), data])!)!
	projection.output_memory[identity] = actual
	if object.kind == .map {
		for entry in object.entries {
			key := projection.reconstruct(*entry.key)!
			item := projection.reconstruct(*entry.value)!
			bridge.engine('map_insert', [actual, key, item])!
		}
	} else if object.kind == .set {
		for item in object.values { bridge.engine('set_insert', [actual, projection.reconstruct(*item)!])! }
	} else if object.kind == .object || object.kind == .array {
		for index, item in object.values {
			// Source decoder retains a dense prefix in the compatibility DTO.
			key := projection.adopt_root(owner.javascript_utf16_string(libjs.utf16_string(index.str()))!)
			bridge.engine('define', [actual, key, projection.reconstruct(*item)!])!
		}
		for property in object.properties {
			key := projection.adopt_root(owner.javascript_utf16_string(property.key_utf16_ or { libjs.utf16_string(property.key) })!)
			if !C.JSValueToBoolean(owner.context, bridge.engine('define', [actual, key, projection.reconstruct(*property.value)!])!) {
				return native_clone_unsupported('Invalid serialized property')
			}
		}
	}
	return actual
}

pub fn (bridge &StructuredCloneBridge) serialize(value voidptr, for_storage bool) !html.SerializationRecord {
	bridge.runtime.require_javascript_value_context()!
	mut projection := NativeCloneProjection{bridge: bridge}
	defer { projection.release_roots() }
	source_value := projection.project(value)!
	return if for_storage { html.structured_serialize_for_storage(*source_value)! } else { html.structured_serialize(*source_value)! }
}

pub fn (bridge &StructuredCloneBridge) deserialize(record html.SerializationRecord) !voidptr {
	bridge.runtime.require_javascript_value_context()!
	// Source structured_deserialize enters the actual target realm's
	// TemporaryExecutionContext with callbacks disabled.
	bridge.runtime.prepare_html_script()
	defer { bridge.runtime.clean_up_html_script() }
	context := bridge.runtime.native_clone_deserialization_context()
	source_value := if record.type_ == .ipc {
		html.structured_deserialize_ipc_with_context(record, context) or { return native_clone_unsupported(err.msg()) }
	} else {
		html.structured_deserialize_with_context(record, context) or { return native_clone_unsupported(err.msg()) }
	}
	mut projection := NativeCloneProjection{bridge: bridge}
	defer { projection.release_roots() }
	actual := projection.reconstruct(source_value)!
	mut owner := unsafe { &Runtime(bridge.runtime) }
	return owner.retain_javascript_value(actual)
}

pub fn (bridge &StructuredCloneBridge) clone(value voidptr) !voidptr {
	return bridge.deserialize(bridge.serialize(value, false)!)
}

// Captured engine operations are the actual-value projection ABI, not a
// serialization format. The only bytes are the translated source records.
const structured_clone_projection_intrinsic = r'(function(){
 const apply=Reflect.apply,ownKeys=Reflect.ownKeys,getOwn=Object.getOwnPropertyDescriptor,get=Reflect.get,define=Reflect.defineProperty,create=Object.create,objectPrototype=Object.prototype;
 const O=Object,A=Array,B=Boolean,N=Number,S=String,M=Map,T=Set,D=Date;
 const bv=B.prototype.valueOf,nv=N.prototype.valueOf,sv=S.prototype.valueOf,iv=BigInt.prototype.valueOf,integerText=BigInt.prototype.toString;
 const dateValue=Date.prototype.getTime,regexSource=getOwn(RegExp.prototype,"source").get;
 const AB=ArrayBuffer,U8=Uint8Array,bufferLength=getOwn(AB.prototype,"byteLength").get,isView=AB.isView;
 const bufferDetached=getOwn(AB.prototype,"detached"),bufferResizable=getOwn(AB.prototype,"resizable"),bufferMaximum=getOwn(AB.prototype,"maxByteLength");
 const sharedLength=typeof SharedArrayBuffer==="function"?getOwn(SharedArrayBuffer.prototype,"byteLength").get:undefined;
 const typedPrototype=Object.getPrototypeOf(Int8Array.prototype),typedBuffer=getOwn(typedPrototype,"buffer").get,typedLength=getOwn(typedPrototype,"byteLength").get,typedOffset=getOwn(typedPrototype,"byteOffset").get,typedCount=getOwn(typedPrototype,"length").get,typedName=getOwn(typedPrototype,Symbol.toStringTag).get,typedValues=typedPrototype.values,typedSet=typedPrototype.set;
 const DV=DataView,dataBuffer=getOwn(DV.prototype,"buffer").get,dataLength=getOwn(DV.prototype,"byteLength").get,dataOffset=getOwn(DV.prototype,"byteOffset").get;
 const viewConstructors={DataView:DV,Int8Array,Uint8Array,Uint8ClampedArray,Int16Array,Uint16Array,Int32Array,Uint32Array,Float16Array:typeof Float16Array==="function"?Float16Array:undefined,Float32Array,Float64Array,BigInt64Array,BigUint64Array};
 const mapSize=getOwn(M.prototype,"size").get,setSize=getOwn(T.prototype,"size").get;
 const mapEach=M.prototype.forEach,setEach=T.prototype.forEach,mapSet=M.prototype.set,setAdd=T.prototype.add,isError=Error.isError;
 const errorConstructors=[Error,EvalError,undefined,RangeError,ReferenceError,SyntaxError,TypeError,URIError],concat=S.prototype.concat;
 if(typeof isError!=="function")throw new TypeError("Exact native Error brand predicate is unavailable");
 const append=(array,value)=>define(array,array.length,{value,writable:true,enumerable:true,configurable:true});
 return {
  classify(value){
   switch(typeof value){case "undefined":return 1;case "boolean":return 3;case "number":return 4;case "string":return 5;case "bigint":return 6;case "symbol":return -1;case "function":return -2;}
   if(value===null)return 2;
   try{apply(bv,value,[]);return 7}catch(ignore){}
   try{apply(nv,value,[]);return 8}catch(ignore){}
   try{apply(sv,value,[]);return 9}catch(ignore){}
   try{apply(iv,value,[]);return 10}catch(ignore){}
   try{apply(dateValue,value,[]);return 11}catch(ignore){}
   try{apply(regexSource,value,[]);return 12}catch(ignore){}
   try{apply(bufferLength,value,[]);return 22}catch(ignore){}
   if(sharedLength!==undefined){try{apply(sharedLength,value,[]);return 20}catch(ignore){}}
   if(isView(value))return 23;
   try{apply(mapSize,value,[]);return 13}catch(ignore){}
   try{apply(setSize,value,[]);return 14}catch(ignore){}
   if(isError(value))return 16;
   return 17;
  },
  boxed_value(value,tag){return apply(tag===7?bv:tag===8?nv:tag===9?sv:iv,value,[])},
  bigint_text(value){return apply(integerText,value,[])},
  date_value(value){return apply(dateValue,value,[])},
  error_metadata(value){const name=get(value,"name",value);let message,cause;const messageDescriptor=getOwn(value,"message");if(messageDescriptor!==undefined&&getOwn(messageDescriptor,"value")!==undefined)message=apply(concat,"",[messageDescriptor.value]);const causeDescriptor=getOwn(value,"cause");if(causeDescriptor!==undefined&&getOwn(causeDescriptor,"value")!==undefined)cause=apply(concat,"",[causeDescriptor.value]);return [name,message,cause]},
  create_error(type,message,cause){const constructor=errorConstructors[type];if(constructor===undefined)return undefined;const value=new constructor();if(message!==undefined)define(value,"message",{value:message,writable:true,enumerable:false,configurable:true});if(cause!==undefined)define(value,"cause",{value:cause,writable:true,enumerable:false,configurable:true});return value},
  buffer_metadata(value){if(bufferDetached===undefined||bufferResizable===undefined||bufferMaximum===undefined)return undefined;const detached=apply(bufferDetached.get,value,[]);if(detached)return [true,false,undefined];const resizable=apply(bufferResizable.get,value,[]);return [false,resizable,resizable?apply(bufferMaximum.get,value,[]):undefined]},
  is_shared_buffer(value){if(sharedLength===undefined)return false;try{apply(sharedLength,value,[]);return true}catch(ignore){return false}},
  create_buffer(length,maximum){return maximum===undefined?new AB(length):new AB(length,{maxByteLength:maximum})},
  copy_buffer(value){return new U8(new U8(value))},
  write_buffer(value,bytes){apply(typedSet,new U8(value),[new U8(bytes)])},
  view_metadata(value){let buffer;try{buffer=apply(typedBuffer,value,[])}catch(ignore){try{return [apply(dataBuffer,value,[]),"DataView",apply(dataLength,value,[]),apply(dataOffset,value,[]),undefined]}catch(outOfBounds){return null}}try{apply(typedValues,value,[]);return [buffer,apply(typedName,value,[]),apply(typedLength,value,[]),apply(typedOffset,value,[]),apply(typedCount,value,[])]}catch(outOfBounds){return null}},
  create_view(buffer,name,offset,length){const constructor=viewConstructors[name];return constructor===undefined?undefined:new constructor(buffer,offset,length)},
  map_snapshot(value){const list=[];apply(mapEach,value,[function(item,key){append(list,[key,item])}]);return list},
  set_snapshot(value){const list=[];apply(setEach,value,[function(item){append(list,item)}]);return list},
  enumerable_keys(value){const list=[],keys=ownKeys(value);for(let index=0;index<keys.length;++index){const key=keys[index];if(typeof key==="string"){const descriptor=getOwn(value,key);if(descriptor!==undefined&&descriptor.enumerable)append(list,key)}}return list},
  has_own(value,key){return getOwn(value,key)!==undefined},
  get(value,key){return get(value,key,value)},
  array_length(value){return get(value,"length",value)},
  list_length(list){return list.length},
  list_item(list,index){return list[index]},
  create(tag,data){if(tag===7)return new B(data);if(tag===8)return new N(data);if(tag===9)return new S(data);if(tag===10)return O(data);if(tag===11)return new D(data);if(tag===13)return new M();if(tag===14)return new T();if(tag===15)return new A(data);return create(data?null:objectPrototype)},
  map_insert(value,key,item){return apply(mapSet,value,[key,item])},
  set_insert(value,item){return apply(setAdd,value,[item])},
  define(value,key,item){return define(value,key,{value:item,writable:true,enumerable:true,configurable:true})}
 };
})()'
