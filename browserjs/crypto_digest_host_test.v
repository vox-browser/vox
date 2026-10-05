// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

fn digest_host_fixture() (&Runtime, &CryptoHost, &html.EventLoop) {
	url := dom.URL{value: 'https://digest-binding.example/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(document) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host, host.settings.responsible_event_loop()
}

fn digest_host_task(owner &html.EventLoop, expected html.TaskSource) {
	mut queue := owner.task_queue()
	task := queue.dequeue() or { panic('missing native digest task') }
	assert task.source() == expected
	task.execute()
}

fn digest_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 100 {
		job := loop.dequeue_microtask() or { return }
		assert job.source() == .microtask
		job.execute()
	}
	panic('native digest microtasks did not drain')
}

fn digest_host_drain(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		task := queue.dequeue() or { break }
		task.execute()
	}
	digest_host_jobs(owner)
}

fn test_native_digest_real_promise_source_task_order_buffer_result_and_copied_span() {
	$if !darwin {
		return
	}
	mut runtime, _, mut owner := digest_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'
 globalThis.digestOrder=[];globalThis.digestResult=null;
 const backing=new Uint8Array([9,97,98,99,9]);const input=new DataView(backing.buffer,1,3);Object.defineProperty(input,"byteLength",{get(){throw "author length"}});
 globalThis.digestPromise=crypto.subtle.digest("sHa-256",input);digestPromise.then(value=>{digestResult=value;digestOrder.push("reaction")});backing.fill(0);digestOrder.push("return");
 digestPromise instanceof Promise&&SubtleCrypto.prototype.digest.length===2&&digestOrder.join(",")==="return";
 ')! == 'true'
	assert !owner.task_queue().is_empty()
	digest_host_task(owner, .unspecified)
	assert runtime.evaluate_host('digestResult===null&&digestOrder.join(",")==="return"')! == 'true'
	assert owner.microtask_queue_empty()
	digest_host_task(owner, .crypto)
	assert runtime.evaluate_host('digestResult===null')! == 'true'
	assert !owner.microtask_queue_empty()
	digest_host_jobs(owner)
	assert runtime.evaluate_host('digestResult instanceof ArrayBuffer&&Array.from(new Uint8Array(digestResult),byte=>byte.toString(16).padStart(2,"0")).join("")==="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"&&digestOrder.join(",")==="return,reaction"')! == 'true'
}

fn test_native_digest_algorithm_getters_before_copy_detachment_and_buffer_brands() {
	$if !darwin {
		return
	}
	mut runtime, _, mut owner := digest_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.digestCases=[];const bytes=new Uint8Array([97,98,99]);let gets=0;
 crypto.subtle.digest({get name(){gets++;bytes[0]=122;return "SHA-256"}},bytes).then(buffer=>digestCases.push(Array.from(new Uint8Array(buffer),byte=>byte.toString(16).padStart(2,"0")).join("")));
 globalThis.digestNameGets=gets;
 const view=new Uint8Array([97,98,99]);crypto.subtle.digest({get name(){view.buffer.transfer();return "SHA-256"}},view).then(buffer=>digestCases.push(Array.from(new Uint8Array(buffer),byte=>byte.toString(16).padStart(2,"0")).join("")));
 const detachedBuffer=new ArrayBuffer(3);detachedBuffer.transfer();crypto.subtle.digest("SHA-256",detachedBuffer).then(buffer=>digestCases.push(Array.from(new Uint8Array(buffer),byte=>byte.toString(16).padStart(2,"0")).join("")));
 const dv=new DataView(new ArrayBuffer(3));dv.buffer.transfer();crypto.subtle.digest("SHA-256",dv).then(buffer=>digestCases.push(Array.from(new Uint8Array(buffer),byte=>byte.toString(16).padStart(2,"0")).join("")));
 ')!
	digest_host_drain(owner)
	assert runtime.evaluate_host('digestNameGets===1&&digestCases.length===4&&digestCases[0]==="a0a88f6841488d9622285fbce55a40ae387ba8b5f02a9ca72fcb742d5d67f8fe"&&digestCases.slice(1).every(hash=>hash==="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")')! == 'true'
}

fn test_native_digest_generated_binding_rejections_preserve_original_values_and_source_conversion_order() {
	$if !darwin {
		return
	}
	mut runtime, _, mut owner := digest_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'
 globalThis.digestFailures=[];globalThis.digestMarker={original:true};globalThis.digestConversions=[];
 function fail(call){try{const promise=call();if(!(promise instanceof Promise))return false;promise.catch(reason=>digestFailures.push(reason));return true}catch(reason){return false}}
 const calls=[()=>crypto.subtle.digest(),()=>SubtleCrypto.prototype.digest.call({}),()=>crypto.subtle.digest(Symbol("algorithm"),new Uint8Array()),()=>crypto.subtle.digest({get name(){throw digestMarker}},new Uint8Array()),()=>crypto.subtle.digest({get name(){digestConversions.push("name");return "SHA-256"}},{}),()=>crypto.subtle.digest({get name(){digestConversions.push("resizable name");return "SHA-256"}},new Uint8Array(new ArrayBuffer(8,{maxByteLength:16}))),()=>crypto.subtle.digest("unknown",new Uint8Array()),()=>crypto.subtle.digest("cSHAKE128",new Uint8Array()),()=>crypto.subtle.digest({name:"cSHAKE128",outputLength:1n},new Uint8Array()),()=>crypto.subtle.digest({name:"cSHAKE128",outputLength:256,functionName:undefined},new Uint8Array())];
 const real=calls.every(fail);digestConversions.push("returned");real&&digestFailures.length===0;
 ')! == 'true'
	assert owner.task_queue().is_empty()
	digest_host_jobs(owner)
	assert runtime.evaluate_host(r'
 digestFailures.length===10&&digestFailures[0] instanceof TypeError&&digestFailures[0].message==="digest() needs 2 arguments"&&digestFailures[1] instanceof TypeError&&digestFailures[1].message==="Not an object of type SubtleCrypto"&&digestFailures[2] instanceof TypeError&&digestFailures[3]===digestMarker&&digestFailures[4] instanceof TypeError&&digestFailures[4].message==="No union types matched"&&digestFailures[5] instanceof TypeError&&digestFailures[6] instanceof DOMException&&digestFailures[6].name==="NotSupportedError"&&digestFailures[7] instanceof TypeError&&digestFailures[7].message==="Required property outputLength is missing or undefined"&&digestFailures[8] instanceof TypeError&&digestFailures[9] instanceof TypeError&&digestConversions.join(",")==="returned";
 ')! == 'true'
}

fn test_native_digest_cshake_parameter_order_engine_number_conversion_and_crypto_rejection_task() {
	$if !darwin {
		return
	}
	mut runtime, _, mut owner := digest_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.cshakeOrder=[];globalThis.cshakeResult=null;globalThis.cshakeFailure=null;
 const params={get name(){cshakeOrder.push("name");return "cshake128"},get outputLength(){cshakeOrder.push("length");return {valueOf(){cshakeOrder.push("number");return 256.9}}},get functionName(){cshakeOrder.push("function");return new Uint8Array(0)},get customization(){cshakeOrder.push("customization");return new ArrayBuffer(0)}};
 crypto.subtle.digest(params,new Uint8Array(0)).then(buffer=>cshakeResult=Array.from(new Uint8Array(buffer),byte=>byte.toString(16).padStart(2,"0")).join(""));
 crypto.subtle.digest({name:"cSHAKE128",outputLength:7},new Uint8Array()).catch(reason=>cshakeFailure=reason);
 ')!
	assert runtime.evaluate_host('cshakeOrder.join(",")==="name,length,number,function,customization"&&cshakeResult===null&&cshakeFailure===null')! == 'true'
	digest_host_task(owner, .unspecified)
	digest_host_task(owner, .unspecified)
	assert runtime.evaluate_host('cshakeFailure===null')! == 'true'
	digest_host_task(owner, .crypto)
	digest_host_task(owner, .crypto)
	digest_host_jobs(owner)
	assert runtime.evaluate_host('cshakeResult==="7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"&&cshakeFailure instanceof DOMException&&cshakeFailure.name==="OperationError"&&cshakeFailure.message.startsWith("Hash function failed:")')! == 'true'
}

fn test_native_digest_worker_global_owns_independent_tasks_and_close_skips_released_engine() {
	$if !darwin {
		return
	}
	mut runtime, host, mut owner := digest_host_fixture()
	defer { runtime.close() }
	mut realm := &html.ScriptingRealm{}
	scope := html.WorkerGlobalScope.create(dom.URL{value: 'https://digest-binding.example/worker.js'}, .classic, 'digest worker', realm)
	settings := html.WorkerEnvironmentSettingsObject.setup(scope, mut realm, host.settings.serialize(), 12).settings
	mut worker_runtime := Runtime.create()
	mut worker_host := CryptoHost.create_for_settings(settings)!
	worker_host.install(mut worker_runtime)!
	mut worker_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	assert voidptr(owner) != voidptr(worker_loop)
	pause := owner.pause()
	worker_pause := worker_loop.pause()
	defer {
		owner.unpause(pause)
		worker_loop.unpause(worker_pause)
	}
	runtime.evaluate_host('globalThis.windowDigest=null;crypto.subtle.digest("SHA-256",new Uint8Array()).then(value=>windowDigest=value)')!
	worker_runtime.evaluate_host('globalThis.workerDigest=null;crypto.subtle.digest("SHA-256",new Uint8Array()).then(value=>workerDigest=value)')!
	digest_host_drain(worker_loop)
	assert worker_runtime.evaluate_host('workerDigest instanceof ArrayBuffer&&workerDigest.byteLength===32')! == 'true'
	assert runtime.evaluate_host('windowDigest===null')! == 'true'
	worker_runtime.evaluate_host('crypto.subtle.digest("SHA-512",new Uint8Array())')!
	worker_runtime.close()
	digest_host_drain(worker_loop)
	assert worker_host.closed
	digest_host_drain(owner)
	assert runtime.evaluate_host('windowDigest instanceof ArrayBuffer')! == 'true'
}

fn test_native_digest_captured_buffer_intrinsics_and_parameter_buffers_keep_source_restrictions() {
	$if !darwin {
		return
	}
	mut runtime, _, mut owner := digest_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.digestIntrinsicResult=null;globalThis.digestParameterResult=null;globalThis.digestSharedErrors=[];globalThis.digestSharedAvailable=typeof SharedArrayBuffer==="function";
 const input=new Uint8Array([97,98,99]);const originalIterator=Array.prototype[Symbol.iterator],originalValues=Int8Array.prototype.values,originalView=ArrayBuffer.isView,originalU8=Uint8Array;
 Array.prototype[Symbol.iterator]=function(){throw "author iterator"};Int8Array.prototype.values=function(){throw "author witness"};ArrayBuffer.isView=function(){throw "author isView"};globalThis.Uint8Array=function(){throw "author constructor"};
 crypto.subtle.digest("SHA-256",input).then(buffer=>digestIntrinsicResult=buffer);
 Array.prototype[Symbol.iterator]=originalIterator;Int8Array.prototype.values=originalValues;ArrayBuffer.isView=originalView;globalThis.Uint8Array=originalU8;
 const buffer=new ArrayBuffer(16,{maxByteLength:32}),outOfBounds=new Uint8Array(buffer,8,8);buffer.resize(4);
 crypto.subtle.digest({name:"cSHAKE128",outputLength:256,functionName:outOfBounds,customization:new ArrayBuffer(0)},new Uint8Array()).then(buffer=>digestParameterResult=buffer);
 if(digestSharedAvailable){const shared=new SharedArrayBuffer(8);crypto.subtle.digest("SHA-256",shared).catch(reason=>digestSharedErrors.push(reason));crypto.subtle.digest("SHA-256",new Uint8Array(shared)).catch(reason=>digestSharedErrors.push(reason));crypto.subtle.digest({name:"cSHAKE128",outputLength:256,functionName:new SharedArrayBuffer(0)},new Uint8Array()).then(buffer=>digestSharedErrors.push(buffer));}
 ')!
	digest_host_drain(owner)
	assert runtime.evaluate_host(r'
 const hex=buffer=>Array.from(new Uint8Array(buffer),byte=>byte.toString(16).padStart(2,"0")).join("");
 hex(digestIntrinsicResult)==="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"&&hex(digestParameterResult)==="7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"&&(!digestSharedAvailable||(digestSharedErrors.length===3&&digestSharedErrors[0] instanceof TypeError&&digestSharedErrors[0].message==="No union types matched"&&digestSharedErrors[1] instanceof TypeError&&digestSharedErrors[1].message==="The array buffer object cannot be a SharedArrayBuffer"&&hex(digestSharedErrors[2])==="7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"));
 ')! == 'true'
}
