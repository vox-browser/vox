// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import webcrypto

fn kem_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{'https://kem-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn kem_host_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) ! {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
}

fn kem_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 1000 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('KEM jobs did not drain')
}

fn kem_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 1000 {
			task := queue.dequeue() or { break }
			assert task.source() in [.unspecified, .crypto]
			task.execute()
		}
		kem_host_jobs(owner)
		if queue.is_empty() { return }
	}
	panic('KEM tasks did not drain')
}

fn test_native_kem_actual_bits_object_and_crypto_settlement_then_copy_before_name_getter() {
	$if !darwin {
		return
	}
	mut runtime, host := kem_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host('globalThis.kemPair=null;crypto.subtle.generateKey("ML-KEM-512",false,["encapsulateBits","decapsulateBits"]).then(pair=>kemPair=pair);')!
	kem_host_tasks(owner)
	assert runtime.evaluate_host('globalThis.nativeEncapsulation=null;globalThis.kemPromise=crypto.subtle.encapsulateBits("mL-kEm-512",kemPair.publicKey);kemPromise.then(value=>nativeEncapsulation=value);kemPromise instanceof Promise&&SubtleCrypto.prototype.encapsulateBits.length===2&&SubtleCrypto.prototype.encapsulateKey.length===5&&SubtleCrypto.prototype.decapsulateBits.length===3&&SubtleCrypto.prototype.decapsulateKey.length===6&&nativeEncapsulation===null')! == 'true'
	mut queue := owner.task_queue()
	work := queue.dequeue() or { panic('missing KEM work') }
	assert work.source() == .unspecified
	work.execute()
	settle := queue.dequeue() or { panic('missing KEM settlement') }
	assert settle.source() == .crypto
	settle.execute()
	assert queue.is_empty()
	assert runtime.evaluate_host('nativeEncapsulation===null')! == 'true'
	kem_host_jobs(owner)
	assert runtime.evaluate_host('Object.getPrototypeOf(nativeEncapsulation)===Object.prototype&&Object.keys(nativeEncapsulation).join(",")==="sharedKey,ciphertext"&&nativeEncapsulation.sharedKey instanceof ArrayBuffer&&nativeEncapsulation.sharedKey.byteLength===32&&nativeEncapsulation.ciphertext instanceof ArrayBuffer&&nativeEncapsulation.ciphertext.byteLength===768')! == 'true'
	assert runtime.evaluate_host(r'(function(){globalThis.nativeDecapsulation=null;globalThis.kemCopyOrder=[];const ciphertext=new Uint8Array(nativeEncapsulation.ciphertext);const algorithm={get name(){kemCopyOrder.push("name");ciphertext.fill(0);return "ML-KEM-512"}};crypto.subtle.decapsulateBits(algorithm,kemPair.privateKey,new DataView(ciphertext.buffer)).then(value=>nativeDecapsulation=value);return kemCopyOrder.join(",")==="name"&&nativeDecapsulation===null})()')! == 'true'
	kem_host_tasks(owner)
	assert runtime.evaluate_host('nativeDecapsulation instanceof ArrayBuffer&&nativeDecapsulation.byteLength===32&&new Uint8Array(nativeDecapsulation).every((value,index)=>value===new Uint8Array(nativeEncapsulation.sharedKey)[index])')! == 'true'
}

fn test_native_kem_all_three_families_bits_key_methods_and_implicit_rejection() {
	$if !darwin {
		return
	}
	mut runtime, host := kem_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.kemFamilies=[];globalThis.kemFamilyErrors=[];
 for(const name of ["ML-KEM-512","ML-KEM-768","ML-KEM-1024"])crypto.subtle.generateKey(name,false,["encapsulateBits","decapsulateBits","encapsulateKey","decapsulateKey"]).then(pair=>crypto.subtle.encapsulateBits(name,pair.publicKey).then(bits=>crypto.subtle.decapsulateBits(name,pair.privateKey,bits.ciphertext).then(secret=>{const valid=secret instanceof ArrayBuffer&&new Uint8Array(secret).every((value,i)=>value===new Uint8Array(bits.sharedKey)[i]);const corrupt=new Uint8Array(bits.ciphertext);corrupt[0]^=1;return crypto.subtle.decapsulateBits(name,pair.privateKey,corrupt).then(rejectedSecret=>{const implicit=rejectedSecret instanceof ArrayBuffer&&rejectedSecret.byteLength===32&&new Uint8Array(rejectedSecret).some((value,i)=>value!==new Uint8Array(bits.sharedKey)[i]);return crypto.subtle.encapsulateKey(name,pair.publicKey,{name:"AES-GCM",length:128},true,["encrypt","decrypt"]).then(keyResult=>{if(!(keyResult.sharedKey instanceof CryptoKey)||keyResult.sharedKey.algorithm.length!==256||!(keyResult.ciphertext instanceof ArrayBuffer)||Object.keys(keyResult).join(",")!=="sharedKey,ciphertext")throw "key result";return crypto.subtle.decapsulateKey(name,pair.privateKey,keyResult.ciphertext,"AES-GCM",true,["decrypt"]).then(key=>crypto.subtle.exportKey("raw-secret",keyResult.sharedKey).then(left=>crypto.subtle.exportKey("raw-secret",key).then(right=>({name,valid,implicit,keyValid:key instanceof CryptoKey&&key.algorithm.length===256&&key.usages.join(",")==="decrypt"&&new Uint8Array(left).every((value,i)=>value===new Uint8Array(right)[i])}))))})})}))).then(result=>kemFamilies.push(result),reason=>kemFamilyErrors.push({name,reason}));
 ')!
	kem_host_tasks(owner)
	assert runtime.evaluate_host('JSON.stringify(kemFamilyErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('kemFamilies.length===3&&kemFamilies.every(({valid,implicit,keyValid})=>valid===true&&implicit===true&&keyValid===true)')! == 'true'
}

fn test_native_kem_key_method_idl_order_copy_before_both_normalizations_and_empty_usages() {
	$if !darwin {
		return
	}
	mut runtime, host := kem_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host('globalThis.kemKeyPair=null;crypto.subtle.generateKey("ML-KEM-512",false,["encapsulateKey","decapsulateKey"]).then(pair=>kemKeyPair=pair);')!
	kem_host_tasks(owner)
	assert runtime.evaluate_host(r'(function(){globalThis.kemKeyOrder=[];globalThis.nativeKeyEncapsulation=null;const algorithm={get name(){kemKeyOrder.push("algorithm");return "ML-KEM-512"}};const destination={get name(){kemKeyOrder.push("destination");return "AES-GCM"}};const usages={[Symbol.iterator](){kemKeyOrder.push("usages");return [][Symbol.iterator]()}};crypto.subtle.encapsulateKey(algorithm,kemKeyPair.publicKey,destination,{valueOf(){throw "boolean"}},usages).then(result=>nativeKeyEncapsulation=result);return kemKeyOrder.join(",")==="usages,algorithm,destination"})()')! == 'true'
	kem_host_tasks(owner)
	assert runtime.evaluate_host('nativeKeyEncapsulation.sharedKey instanceof CryptoKey&&nativeKeyEncapsulation.sharedKey.extractable&&nativeKeyEncapsulation.sharedKey.usages.length===0')! == 'true'
	assert runtime.evaluate_host(r'(function(){globalThis.nativeKeyDecapsulation=null;globalThis.kemKeyCopyOrder=[];const bytes=new Uint8Array(nativeKeyEncapsulation.ciphertext);const algorithm={get name(){kemKeyCopyOrder.push("algorithm");bytes.fill(0);return "ML-KEM-512"}};const destination={get name(){kemKeyCopyOrder.push("destination");return "AES-GCM"}};const usages={[Symbol.iterator](){kemKeyCopyOrder.push("usages");return [][Symbol.iterator]()}};crypto.subtle.decapsulateKey(algorithm,kemKeyPair.privateKey,bytes,destination,true,usages).then(key=>nativeKeyDecapsulation=key);return kemKeyCopyOrder.join(",")==="usages,algorithm,destination"})()')! == 'true'
	kem_host_tasks(owner)
	assert runtime.evaluate_host('nativeKeyDecapsulation instanceof CryptoKey&&nativeKeyDecapsulation.usages.length===0&&nativeKeyDecapsulation.algorithm.length===256')! == 'true'
	encapsulated := runtime.native_crypto_key(runtime.evaluate_host_value('nativeKeyEncapsulation.sharedKey')!)!
	decapsulated := runtime.native_crypto_key(runtime.evaluate_host_value('nativeKeyDecapsulation')!)!
	assert encapsulated.handle() == decapsulated.handle()
}

fn test_native_kem_receiver_key_buffer_failures_and_source_deferred_usage_errors() {
	$if !darwin {
		return
	}
	mut runtime, host := kem_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	kem_host_expose(mut runtime, '__badKemKey', webcrypto.CryptoKey.create(.public_key, false, webcrypto.KeyAlgorithm{ name: 'ML-KEM-512' }, [], []u8{}))!
	kem_host_expose(mut runtime, '__wrongKemAlgorithm', webcrypto.CryptoKey.create(.public_key, false, webcrypto.KeyAlgorithm{ name: 'ML-KEM-768' }, [], []u8{}))!
	assert runtime.evaluate_host(r'(function(){globalThis.kemFailures=[];globalThis.kemMarker={original:true};let names=0;const algorithm={get name(){names++;return "ML-KEM-512"}};function reject(call){try{const p=call();p.catch(reason=>kemFailures.push(reason));return p instanceof Promise}catch(reason){return false}}const calls=[()=>crypto.subtle.encapsulateBits(),()=>crypto.subtle.encapsulateKey(),()=>crypto.subtle.decapsulateBits(),()=>crypto.subtle.decapsulateKey(),()=>crypto.subtle.encapsulateBits(Symbol(),{}),()=>crypto.subtle.encapsulateBits(algorithm,Object.create(CryptoKey.prototype)),()=>crypto.subtle.decapsulateBits(algorithm,__badKemKey(),null),()=>crypto.subtle.encapsulateKey(algorithm,__badKemKey(),Symbol(),false,[]),()=>crypto.subtle.encapsulateBits({get name(){throw kemMarker}},__badKemKey())];return calls.every(reject)&&names===0&&kemFailures.length===0})()')! == 'true'
	assert owner.task_queue().is_empty()
	kem_host_jobs(owner)
	assert runtime.evaluate_host('kemFailures.length===9&&kemFailures[0].message==="encapsulateBits() needs 2 arguments"&&kemFailures[1].message==="encapsulateKey() needs 5 arguments"&&kemFailures[2].message==="decapsulateBits() needs 3 arguments"&&kemFailures[3].message==="decapsulateKey() needs 6 arguments"&&kemFailures[6].message==="No union types matched"&&kemFailures[8]===kemMarker&&kemFailures.every((reason,index)=>index===8||reason instanceof TypeError)')! == 'true'
	runtime.evaluate_host('globalThis.kemDeferredFailures=[];crypto.subtle.encapsulateBits("ML-KEM-512",__wrongKemAlgorithm()).catch(reason=>kemDeferredFailures.push(reason));crypto.subtle.encapsulateBits("ML-KEM-512",__badKemKey()).catch(reason=>kemDeferredFailures.push(reason));crypto.subtle.encapsulateKey("ML-KEM-512",__badKemKey(),"AES-GCM",false,[]).catch(reason=>kemDeferredFailures.push(reason));crypto.subtle.decapsulateBits("ML-KEM-512",__badKemKey(),new Uint8Array()).catch(reason=>kemDeferredFailures.push(reason));')!
	kem_host_tasks(owner)
	assert runtime.evaluate_host('kemDeferredFailures.length===4&&kemDeferredFailures.every(reason=>reason instanceof DOMException)&&kemDeferredFailures[0].message==="Invalid encapsulation key algorithm"&&kemDeferredFailures[1].message==="Invalid encapsulation key usages"&&kemDeferredFailures[2].message==="Invalid encapsulation key usage"&&kemDeferredFailures[3].message==="Invalid key usages"')! == 'true'
}
