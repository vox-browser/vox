// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom

fn native_crypto_binding_document(address string) &dom.Document {
	url := dom.URL{value: address}
	return &dom.Document{ url: url, origin_: url.origin() }
}

fn test_native_crypto_same_source_records_integer_views_and_uuid() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := CryptoHost.create(native_crypto_binding_document('https://crypto-binding.example/'))!
	host.install(mut runtime)!
	crypto := runtime.evaluate_host_value('crypto')!
	subtle := runtime.evaluate_host_value('crypto.subtle')!
	assert voidptr(runtime.native_crypto(crypto)!) == voidptr(host.service.crypto())
	assert voidptr(runtime.native_subtle_crypto(subtle)!) == voidptr(host.service.crypto().subtle())
	assert runtime.evaluate_host(r'(function(){
 const types=[Int8Array,Uint8Array,Uint8ClampedArray,Int16Array,Uint16Array,Int32Array,Uint32Array,BigInt64Array,BigUint64Array];
 const views=types.every(Type=>{const backing=new Uint8Array(160).fill(170),view=new Type(backing.buffer,8,16);Object.defineProperty(view,"byteLength",{get(){throw "shadow length"}});const same=crypto.getRandomValues(view)===view;const end=8+16*Type.BYTES_PER_ELEMENT;return same&&backing.slice(0,8).every(byte=>byte===170)&&backing.slice(end).every(byte=>byte===170)&&backing.slice(8,end).some(byte=>byte!==170)});
 const uuid=crypto.randomUUID();
 return views&&crypto===crypto&&crypto.subtle===crypto.subtle&&crypto instanceof Crypto&&crypto.subtle instanceof SubtleCrypto&&Object.prototype.toString.call(crypto)==="[object Crypto]"&&Object.prototype.toString.call(crypto.subtle)==="[object SubtleCrypto]"&&Crypto.prototype.getRandomValues.length===1&&Crypto.prototype.randomUUID.length===0&&/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(uuid)&&crypto.getRandomValues(new Uint8Array(0)).length===0;
})()')! == 'true'
}

fn test_native_crypto_actual_view_brands_error_types_and_quota_subclass() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := CryptoHost.create(native_crypto_binding_document('https://crypto-errors.example/'))!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'(function(){
 const invalid=[undefined,null,{},new ArrayBuffer(8),new Proxy(new Uint8Array(8),{})];
 const brands=invalid.every(value=>{try{crypto.getRandomValues(value);return false}catch(error){return error instanceof TypeError&&error.message==="No union types matched"}});
 const floats=[new Float32Array(8),new Float64Array(8),new DataView(new ArrayBuffer(8))];
 const kinds=floats.every(view=>{try{crypto.getRandomValues(view);return false}catch(error){return error instanceof DOMException&&error.name==="TypeMismatchError"&&error.code===17&&error.message==="array must be one of Int8Array, Uint8Array, Uint8ClampedArray, Int16Array, Uint16Array, Int32Array, Uint32Array, BigInt64Array, or BigUint64Array"}});
 let quota;try{crypto.getRandomValues(new Uint32Array(20000))}catch(error){quota=error}
 const receivers=[()=>new Crypto(),()=>new SubtleCrypto(),()=>Crypto.prototype.getRandomValues.call(Object.create(Crypto.prototype),new Uint8Array(8)),()=>Crypto.prototype.randomUUID.call({}),()=>Object.getOwnPropertyDescriptor(Crypto.prototype,"subtle").get.call({}),()=>Object.getOwnPropertyDescriptor(globalThis,"crypto").get.call({})];
 return brands&&kinds&&quota instanceof QuotaExceededError&&quota instanceof DOMException&&quota.code===22&&quota.quota===null&&quota.requested===null&&quota.message==="array\u0027s byteLength may not be greater than 65536"&&receivers.every(test=>{try{test();return false}catch(error){return error instanceof TypeError}});
})()')! == 'true'
}

fn test_native_crypto_binding_rejects_resizable_views_before_source_witness() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := CryptoHost.create(native_crypto_binding_document('https://crypto-witness.example/'))!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'(function(){
 const outOfBounds=view=>{try{crypto.getRandomValues(view);return false}catch(error){return error instanceof DOMException&&error.name==="InvalidStateError"&&error.message==="TypedArray contains a property which references a value at an index not contained within its buffer\u0027s bounds"}};
 const detached=new Uint8Array(8);detached.buffer.transfer();
 const buffer=new ArrayBuffer(16,{maxByteLength:32}),resized=new Uint8Array(buffer,8,8);buffer.resize(4);
 const floatBuffer=new ArrayBuffer(16,{maxByteLength:32}),float=new Float32Array(floatBuffer,8,2);floatBuffer.resize(4);let first;try{crypto.getRandomValues(float)}catch(error){first=error.name}
 let resizedError;try{crypto.getRandomValues(resized)}catch(error){resizedError=error}
 let detachedError;try{crypto.getRandomValues(detached)}catch(error){detachedError=error}
 return detachedError instanceof DOMException&&detachedError.name==="InvalidStateError"&&detachedError.message.startsWith("TypedArray contains a property")&&resizedError instanceof TypeError&&resizedError.message==="Not an object of type fixed-length Uint8Array"&&first==="TypeError";
})()')! == 'true'
}

fn test_native_crypto_secure_context_exposure_and_independent_global_objects() {
	$if !darwin {
		return
	}
	mut secure := Runtime.create()
	defer { secure.close() }
	mut insecure := Runtime.create()
	defer { insecure.close() }
	mut secure_host := CryptoHost.create(native_crypto_binding_document('https://secure-crypto.example/'))!
	mut insecure_host := CryptoHost.create(native_crypto_binding_document('http://insecure-crypto.example/'))!
	secure_host.install(mut secure)!
	insecure_host.install(mut insecure)!
	assert voidptr(secure_host.service.crypto()) != voidptr(insecure_host.service.crypto())
	assert secure.evaluate_host('typeof crypto.randomUUID==="function"&&crypto.subtle instanceof SubtleCrypto')! == 'true'
	assert insecure.evaluate_host('!("subtle" in crypto)&&!("randomUUID" in crypto)&&typeof SubtleCrypto==="undefined"&&crypto.getRandomValues(new Uint8Array(8)).byteLength===8')! == 'true'
}

fn test_native_random_binding_does_not_iterate_arguments_or_consult_author_view_metadata() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://random-intrinsics.example/'}
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() })!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'(function(){
 const input=new Uint8Array(32),iterator=Array.prototype[Symbol.iterator],isView=ArrayBuffer.isView;let calls=0;let same;
 Object.defineProperty(input,"buffer",{get(){calls++;throw "author buffer"}});Object.defineProperty(input,"byteOffset",{get(){calls++;throw "author offset"}});
 Array.prototype[Symbol.iterator]=function(){calls++;throw "author arguments iterator"};ArrayBuffer.isView=function(){calls++;throw "author view brand"};
 try{same=crypto.getRandomValues(input,"ignored extra argument")===input}finally{Array.prototype[Symbol.iterator]=iterator;ArrayBuffer.isView=isView}
 let count;try{crypto.getRandomValues()}catch(error){count=error}
 return same&&calls===0&&input.some(value=>value!==0)&&count instanceof TypeError&&count.message==="getRandomValues() needs one argument";
 })()')! == 'true'
}

// Rust's getrandom fills a view of WebAssembly.Memory, whose backing store
// JavaScriptCore does not expose as a raw pointer. Discord's libdiscore
// panicked on startup when this threw.
fn test_native_random_values_fill_views_of_webassembly_memory() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := CryptoHost.create(native_crypto_binding_document('https://random-wasm.example/'))!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'(function(){
 const memory=new WebAssembly.Memory({initial:1}),bytes=new Uint8Array(memory.buffer);bytes.fill(170);
 const view=new Uint32Array(memory.buffer,64,8);Object.defineProperty(view,"buffer",{get(){throw "author buffer"}});
 const same=crypto.getRandomValues(view)===view;
 const filled=bytes.slice(64,96).some(byte=>byte!==170),outside=bytes.slice(0,64).every(byte=>byte===170)&&bytes.slice(96,128).every(byte=>byte===170);
 const empty=crypto.getRandomValues(new Uint8Array(memory.buffer,8,0)).length===0;
 return same&&filled&&outside&&empty;
 })()')! == 'true'
}
