// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import webcrypto

fn wrapping_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{value: 'https://wrapping-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn wrapping_host_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) ! {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
}

fn wrapping_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 1000 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('wrapping jobs did not drain')
}

fn wrapping_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 1000 {
			task := queue.dequeue() or { break }
			assert task.source() == .unspecified
			task.execute()
		}
		wrapping_host_jobs(owner)
		if queue.is_empty() { return }
	}
	panic('wrapping tasks did not drain')
}

fn test_native_wrapping_rfc3394_vector_real_key_unwrap_and_deferred_task_settlement() {
	$if !darwin {
		return
	}
	mut runtime, host := wrapping_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	wrapping_host_expose(mut runtime, '__wrappingKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-KW', length: 128 }, [
		.wrap_key,
		.unwrap_key,
	], []u8{len: 16, init: u8(index)}))!
	wrapping_host_expose(mut runtime, '__wrappedKey', webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [.encrypt], []u8{len: 16, init: u8(index * 17)}))!
	assert runtime.evaluate_host('globalThis.nativeWrapped=null;globalThis.nativeUnwrapped=null;globalThis.wrappingPromise=crypto.subtle.wrapKey("raw-secret",__wrappedKey(),__wrappingKey(),"AES-KW");wrappingPromise.then(value=>nativeWrapped=value);wrappingPromise instanceof Promise&&SubtleCrypto.prototype.wrapKey.length===4&&SubtleCrypto.prototype.unwrapKey.length===7&&nativeWrapped===null')! == 'true'
	mut queue := owner.task_queue()
	work := queue.dequeue() or { panic('missing wrap work') }
	assert work.source() == .unspecified
	work.execute()
	assert queue.is_empty()
	assert runtime.evaluate_host('nativeWrapped===null')! == 'true'
	wrapping_host_jobs(owner)
	assert runtime.evaluate_host('nativeWrapped instanceof ArrayBuffer&&Array.from(new Uint8Array(nativeWrapped),x=>x.toString(16).padStart(2,"0")).join("")==="1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5"')! == 'true'
	runtime.evaluate_host('crypto.subtle.unwrapKey("raw-secret",nativeWrapped,__wrappingKey(),"AES-KW","AES-GCM",false,["decrypt","encrypt"]).then(key=>nativeUnwrapped=key);new Uint8Array(nativeWrapped).fill(0);')!
	wrapping_host_tasks(owner)
	assert runtime.evaluate_host('nativeUnwrapped instanceof CryptoKey&&!nativeUnwrapped.extractable&&nativeUnwrapped.algorithm.name==="AES-GCM"&&nativeUnwrapped.usages.join(",")==="encrypt,decrypt"')! == 'true'
	assert runtime.native_crypto_key(runtime.evaluate_host_value('nativeUnwrapped')!)!.handle() == []u8{len: 16, init: u8(index * 17)}
}

fn test_native_wrapping_fallback_re_reads_original_algorithm_and_unwrap_copies_after_destination() {
	$if !darwin {
		return
	}
	mut runtime, host := wrapping_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	wrapping_host_expose(mut runtime, '__gcmWrappingKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.wrap_key,
		.unwrap_key,
	], []u8{len: 16}))!
	wrapping_host_expose(mut runtime, '__wrappedKey', webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [.encrypt], []u8{len: 16, init: u8(index)}))!
	assert runtime.evaluate_host(r'(function(){globalThis.wrappingOrder=[];globalThis.fallbackWrapped=null;let calls=0;const algorithm={get name(){wrappingOrder.push("name");if(++calls===1)throw {ignored:true};return "AES-GCM"},get iv(){wrappingOrder.push("iv");return new Uint8Array(12)}};crypto.subtle.wrapKey("raw",__wrappedKey(),__gcmWrappingKey(),algorithm).then(value=>fallbackWrapped=value);return wrappingOrder.join(",")==="name,name,iv"})()')! == 'true'
	wrapping_host_tasks(owner)
	assert runtime.evaluate_host('fallbackWrapped instanceof ArrayBuffer')! == 'true'
	assert runtime.evaluate_host(r'(function(){globalThis.unwrappingOrder=[];globalThis.fallbackUnwrapped=null;const correct=new Uint8Array(fallbackWrapped),bytes=new Uint8Array(correct.length);const algorithm={get name(){unwrappingOrder.push("name");return "AES-GCM"},get iv(){unwrappingOrder.push("iv");return new Uint8Array(12)}};const destination={get name(){unwrappingOrder.push("destination");bytes.set(correct);return "AES-GCM"}};const usages={[Symbol.iterator](){unwrappingOrder.push("usages");return ["encrypt"][Symbol.iterator]()}};crypto.subtle.unwrapKey("raw",bytes,__gcmWrappingKey(),algorithm,destination,false,usages).then(key=>fallbackUnwrapped=key);bytes.fill(0);return unwrappingOrder.join(",")==="usages,name,name,iv,destination"})()')! == 'true'
	wrapping_host_tasks(owner)
	assert runtime.evaluate_host('fallbackUnwrapped instanceof CryptoKey')! == 'true'
	assert runtime.native_crypto_key(runtime.evaluate_host_value('fallbackUnwrapped')!)!.handle() == []u8{len: 16, init: u8(index)}
}

fn test_native_wrapping_all_seven_supported_native_operations_and_jwk_json_round_trip() {
	$if !darwin {
		return
	}
	mut runtime, host := wrapping_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	wrapping_host_expose(mut runtime, '__wrappedKey', webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.encrypt,
		.decrypt,
	], []u8{len: 16, init: u8(index)}))!
	runtime.evaluate_host(r'
 globalThis.wrappingFamilies=[];globalThis.wrappingFamilyErrors=[];globalThis.jwkUnwrapped=null;
 const cases=[[{name:"AES-KW",length:128},"AES-KW"],[{name:"AES-CBC",length:128},{name:"AES-CBC",iv:new Uint8Array(16)}],[{name:"AES-CTR",length:128},{name:"AES-CTR",counter:new Uint8Array(16),length:64}],[{name:"AES-GCM",length:128},{name:"AES-GCM",iv:new Uint8Array(12)}],[{name:"AES-OCB",length:128},{name:"AES-OCB",iv:new Uint8Array(12)}],["ChaCha20-Poly1305",{name:"ChaCha20-Poly1305",iv:new Uint8Array(12)}],[{name:"RSA-OAEP",modulusLength:1024,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},{name:"RSA-OAEP",label:null}]];
 for(const [generation,parameters]of cases){const name=typeof generation==="string"?generation:generation.name;crypto.subtle.generateKey(generation,false,["wrapKey","unwrapKey"]).then(key=>crypto.subtle.wrapKey("raw-secret",__wrappedKey(),key.publicKey||key,parameters).then(wrapped=>crypto.subtle.unwrapKey("raw-secret",wrapped,key.privateKey||key,parameters,"AES-GCM",true,["encrypt"]))).then(key=>crypto.subtle.exportKey("raw-secret",key).then(bytes=>wrappingFamilies.push({name,valid:bytes instanceof ArrayBuffer&&new Uint8Array(bytes).every((x,i)=>x===i)})),reason=>wrappingFamilyErrors.push({name,reason}))}
 crypto.subtle.generateKey({name:"AES-GCM",length:128},false,["wrapKey","unwrapKey"]).then(key=>{const algorithm={name:"AES-GCM",iv:new Uint8Array(12)};return crypto.subtle.wrapKey("jwk",__wrappedKey(),key,algorithm).then(bytes=>crypto.subtle.unwrapKey("jwk",bytes,key,algorithm,"AES-GCM",false,["decrypt"]))}).then(key=>jwkUnwrapped=key,reason=>wrappingFamilyErrors.push({name:"JWK",reason}));
 ')!
	wrapping_host_tasks(owner)
	assert runtime.evaluate_host('JSON.stringify(wrappingFamilyErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('wrappingFamilies.length===7&&wrappingFamilies.every(({valid})=>valid===true)&&jwkUnwrapped instanceof CryptoKey&&!jwkUnwrapped.extractable&&jwkUnwrapped.usages.join(",")==="decrypt"')! == 'true'
}

fn test_native_wrapping_source_conversion_errors_export_checks_and_jwk_parse_precedence() {
	$if !darwin {
		return
	}
	mut runtime, host := wrapping_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	wrapping_host_expose(mut runtime, '__unextractable', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [], []u8{len: 16}))!
	wrapping_host_expose(mut runtime, '__unregisteredExport', webcrypto.CryptoKey.create(.secret, true, webcrypto.KeyAlgorithm{ name: 'unregistered' }, [], []u8{len: 16}))!
	wrapping_host_expose(mut runtime, '__wrappingKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-KW', length: 128 }, [
		.wrap_key,
		.unwrap_key,
	], []u8{len: 16}))!
	wrapping_host_expose(mut runtime, '__noWrapUsage', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-KW', length: 128 }, [], []u8{len: 16}))!
	wrapping_host_expose(mut runtime, '__jsonCipherKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.encrypt,
		.unwrap_key,
	], []u8{len: 16}))!
	assert runtime.evaluate_host(r'(function(){globalThis.wrappingFailures=[];function reject(call){try{const p=call();p.catch(reason=>wrappingFailures.push(reason));return p instanceof Promise}catch(reason){return false}}return [()=>crypto.subtle.wrapKey(),()=>crypto.subtle.unwrapKey(),()=>crypto.subtle.wrapKey("invalid",{}, {},Symbol()),()=>crypto.subtle.unwrapKey("raw",null,{},Symbol(),Symbol(),false,[])].every(reject)&&wrappingFailures.length===0})()')! == 'true'
	assert owner.task_queue().is_empty()
	wrapping_host_jobs(owner)
	assert runtime.evaluate_host('wrappingFailures.length===4&&wrappingFailures.every(reason=>reason instanceof TypeError)&&wrappingFailures[0].message==="wrapKey() needs 4 arguments"&&wrappingFailures[1].message==="unwrapKey() needs 7 arguments"&&wrappingFailures[3].message==="No union types matched"')! == 'true'
	runtime.evaluate_host('globalThis.wrappingDeferredFailures=[];for(const [key,wrapping]of [[__unextractable(),__noWrapUsage()],[__unextractable(),__wrappingKey()],[__unregisteredExport(),__wrappingKey()]])crypto.subtle.wrapKey("raw",key,wrapping,"AES-KW").catch(reason=>wrappingDeferredFailures.push(reason));crypto.subtle.encrypt({name:"AES-GCM",iv:new Uint8Array(12)},__jsonCipherKey(),new Uint8Array([123,125])).then(wrapped=>crypto.subtle.unwrapKey("jwk",wrapped,__jsonCipherKey(),{name:"AES-GCM",iv:new Uint8Array(12)},"AES-GCM",false,["sign"])).catch(reason=>wrappingDeferredFailures.push(reason));')!
	// This case additionally exercises the source cipher work/crypto task pair.
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 100 {
			task := queue.dequeue() or { break }
			assert task.source() in [.unspecified, .crypto]
			task.execute()
		}
		wrapping_host_jobs(owner)
		if queue.is_empty() { break }
	}
	assert runtime.evaluate_host('wrappingDeferredFailures.length===4&&wrappingDeferredFailures.every(reason=>reason instanceof DOMException)&&wrappingDeferredFailures[0].message==="Key does not support wrapping keys"&&wrappingDeferredFailures[1].message==="Key is not extractable"&&wrappingDeferredFailures[2].name==="NotSupportedError"&&wrappingDeferredFailures[3].name==="DataError"&&wrappingDeferredFailures[3].message==="kty field is not defined"')! == 'true'
}
