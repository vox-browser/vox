// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import webcrypto

fn cipher_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{value: 'https://cipher-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn cipher_host_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) ! {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
}

fn cipher_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 1000 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('cipher jobs did not drain')
}

fn cipher_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 1000 {
			task := queue.dequeue() or { break }
			assert task.source() in [.unspecified, .crypto]
			task.execute()
		}
		cipher_host_jobs(owner)
		if queue.is_empty() { return }
	}
	panic('cipher tasks did not drain')
}

fn test_native_cipher_source_parameter_copy_order_gcm_vector_and_crypto_settlement_task() {
	$if !darwin {
		return
	}
	mut runtime, host := cipher_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	cipher_host_expose(mut runtime, '__cipherKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.encrypt,
		.decrypt,
	], []u8{len: 16}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.cipherOrder=[];globalThis.nativeCiphertext=null;globalThis.cipherData=new Uint8Array(16);const iv=new Uint8Array(12),aad=new Uint8Array(0);
 const algorithm=new Proxy({name:"aEs-GcM",iv,additionalData:aad,tagLength:{valueOf(){cipherOrder.push("number");iv.fill(255);cipherData.fill(0);return 128.9}}},{get(target,name){cipherOrder.push("get "+name);return target[name]},has(target,name){cipherOrder.push("has "+name);return name in target}});
 cipherData.fill(255);globalThis.cipherPromise=crypto.subtle.encrypt(algorithm,__cipherKey(),new DataView(cipherData.buffer),"ignored");cipherPromise.then(value=>nativeCiphertext=value);cipherData.fill(255);
 return cipherPromise instanceof Promise&&SubtleCrypto.prototype.encrypt.length===3&&SubtleCrypto.prototype.decrypt.length===3&&nativeCiphertext===null&&cipherOrder.join(",")==="get name,get iv,has additionalData,get additionalData,has tagLength,get tagLength,number";
 })()')! == 'true'
	mut queue := owner.task_queue()
	work := queue.dequeue() or { panic('missing cipher work') }
	assert work.source() == .unspecified
	work.execute()
	assert runtime.evaluate_host('nativeCiphertext===null')! == 'true'
	settle := queue.dequeue() or { panic('missing crypto settlement') }
	assert settle.source() == .crypto
	settle.execute()
	assert queue.is_empty()
	assert runtime.evaluate_host('nativeCiphertext===null')! == 'true'
	cipher_host_jobs(owner)
	assert runtime.evaluate_host('nativeCiphertext instanceof ArrayBuffer&&Array.from(new Uint8Array(nativeCiphertext),value=>value.toString(16).padStart(2,"0")).join("")==="0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf"')! == 'true'
	runtime.evaluate_host('globalThis.nativePlaintext=null;crypto.subtle.decrypt({name:"AES-GCM",iv:new Uint8Array(12)},__cipherKey(),nativeCiphertext).then(value=>nativePlaintext=value);')!
	cipher_host_tasks(owner)
	assert runtime.evaluate_host('nativePlaintext instanceof ArrayBuffer&&nativePlaintext.byteLength===16&&new Uint8Array(nativePlaintext).every(value=>value===0)')! == 'true'
}

fn test_native_cipher_all_registered_backends_round_trip_actual_promise_buffers() {
	$if !darwin {
		return
	}
	mut runtime, host := cipher_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.cipherFamilies=[];globalThis.cipherFamilyErrors=[];
 const cases=[[{name:"AES-CBC",length:128},{name:"AES-CBC",iv:new Uint8Array(16)}],[{name:"AES-CTR",length:256},{name:"AES-CTR",counter:new Uint8Array(16),length:64}],[{name:"AES-GCM",length:192},{name:"AES-GCM",iv:new Uint8Array(12),tagLength:96}],[{name:"AES-OCB",length:128},{name:"AES-OCB",iv:new Uint8Array(12),tagLength:64,additionalData:new Uint8Array([4,5])}],["ChaCha20-Poly1305",{name:"ChaCha20-Poly1305",iv:new Uint8Array(12),tagLength:128,additionalData:new Uint8Array([4,5])}],[{name:"RSA-OAEP",modulusLength:1024,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},{name:"RSA-OAEP",label:new Uint8Array([1,2,3])}]];
 for(const [generation,parameters]of cases)crypto.subtle.generateKey(generation,false,["encrypt","decrypt"]).then(key=>crypto.subtle.encrypt(parameters,key.publicKey||key,new Uint8Array([1,2,3])).then(ciphertext=>{if(!(ciphertext instanceof ArrayBuffer))throw "ciphertext brand";return crypto.subtle.decrypt(parameters,key.privateKey||key,ciphertext)})).then(plaintext=>cipherFamilies.push({name:parameters.name,plaintext}),reason=>cipherFamilyErrors.push({name:parameters.name,reason}));
 ')!
	cipher_host_tasks(owner)
	assert runtime.evaluate_host('JSON.stringify(cipherFamilyErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('cipherFamilies.length===6&&cipherFamilies.every(({plaintext})=>plaintext instanceof ArrayBuffer&&new Uint8Array(plaintext).join(",")==="1,2,3")')! == 'true'
}

fn test_native_cipher_binding_precedence_original_getter_errors_and_deferred_key_authentication_failures() {
	$if !darwin {
		return
	}
	mut runtime, host := cipher_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	cipher_host_expose(mut runtime, '__goodCipherKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.encrypt,
		.decrypt,
	], []u8{len: 16}))!
	cipher_host_expose(mut runtime, '__noCipherUsage', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [.decrypt], []u8{len: 16}))!
	cipher_host_expose(mut runtime, '__mismatchedCipherKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-CBC', length: 128 }, [], []u8{len: 16}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.cipherFailures=[];globalThis.cipherMarker={original:true};globalThis.cipherNameReads=0;
 function reject(call){try{const p=call();p.catch(reason=>cipherFailures.push(reason));return p instanceof Promise}catch(reason){return false}}
 const algorithm={get name(){cipherNameReads++;return "AES-GCM"}};
 const calls=[()=>crypto.subtle.encrypt(),()=>crypto.subtle.decrypt(),()=>SubtleCrypto.prototype.encrypt.call({},algorithm,{},null),()=>crypto.subtle.encrypt(Symbol(),{},null),()=>crypto.subtle.encrypt(algorithm,Object.create(CryptoKey.prototype),null),()=>crypto.subtle.encrypt(algorithm,__goodCipherKey(),null),()=>crypto.subtle.encrypt({get name(){throw cipherMarker}},__goodCipherKey(),new Uint8Array()),()=>crypto.subtle.encrypt({name:"AES-GCM",iv:new Uint8Array(12),additionalData:undefined},__goodCipherKey(),new Uint8Array()),()=>crypto.subtle.encrypt({name:"AES-GCM",iv:new Uint8Array(12),tagLength:1n},__goodCipherKey(),new Uint8Array())];
 return calls.every(reject)&&cipherNameReads===0&&cipherFailures.length===0;
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	cipher_host_jobs(owner)
	assert runtime.evaluate_host('cipherFailures.length===9&&cipherFailures[0].message==="encrypt() needs 3 arguments"&&cipherFailures[1].message==="decrypt() needs 3 arguments"&&cipherFailures[2] instanceof TypeError&&cipherFailures[3] instanceof TypeError&&cipherFailures[4] instanceof TypeError&&cipherFailures[5].message==="No union types matched"&&cipherFailures[6]===cipherMarker&&cipherFailures[7].message==="Not an object of type BufferSource"&&cipherFailures[8] instanceof TypeError')! == 'true'
	runtime.evaluate_host('globalThis.cipherDeferredFailures=[];for(const key of [__mismatchedCipherKey(),__noCipherUsage()])crypto.subtle.encrypt({name:"AES-GCM",iv:new Uint8Array(0),tagLength:7},key,new Uint8Array()).catch(reason=>cipherDeferredFailures.push(reason));crypto.subtle.encrypt({name:"AES-GCM",iv:new Uint8Array(12),tagLength:7},__goodCipherKey(),new Uint8Array()).catch(reason=>cipherDeferredFailures.push(reason));crypto.subtle.decrypt({name:"AES-GCM",iv:new Uint8Array(12)},__goodCipherKey(),new Uint8Array(16)).catch(reason=>cipherDeferredFailures.push(reason));')!
	assert runtime.evaluate_host('cipherDeferredFailures.length===0')! == 'true'
	cipher_host_tasks(owner)
	assert runtime.evaluate_host('cipherDeferredFailures.length===4&&cipherDeferredFailures.every(reason=>reason instanceof DOMException)&&cipherDeferredFailures[0].name==="InvalidAccessError"&&cipherDeferredFailures[0].message==="Algorithm mismatch"&&cipherDeferredFailures[1].message==="Key does not support encryption"&&cipherDeferredFailures[2].message==="Invalid tag length"&&cipherDeferredFailures[3].name==="OperationError"&&cipherDeferredFailures[3].message==="Decryption failed"')! == 'true'
}
