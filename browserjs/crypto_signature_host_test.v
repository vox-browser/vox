// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import webcrypto

fn signature_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{value: 'https://signature-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn signature_host_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) ! {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
}

fn signature_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 1000 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('signature jobs did not drain')
}

fn signature_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 1000 {
			task := queue.dequeue() or { break }
			assert task.source() in [.unspecified, .crypto]
			task.execute()
		}
		signature_host_jobs(owner)
		if queue.is_empty() { return }
	}
	panic('signature tasks did not drain')
}

fn test_native_signature_known_vectors_source_parameter_copy_order_and_crypto_settlement() {
	$if !darwin {
		return
	}
	mut runtime, host := signature_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	signature_host_expose(mut runtime, '__hmacKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.HmacKeyAlgorithm{ name: 'HMAC', length: 144, hash: 'SHA-256' }, [
		.sign,
		.verify,
	], 'Well Hello Friends'.bytes()))!
	signature_host_expose(mut runtime, '__kmacKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.KmacKeyAlgorithm{ name: 'KMAC128', length: 256 }, [
		.sign,
		.verify,
	], []u8{len: 32, init: u8(index + 0x40)}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.nativeHmacSignature=null;globalThis.nativeKmacSignature=null;globalThis.signatureOrder=[];globalThis.kmacMessage=new Uint8Array([9,9,9,9]);
 globalThis.hmacMessage=new Uint8Array([83,111,109,101,32,98,111,103,117,115,32,100,97,116,97]);
 crypto.subtle.sign("hMaC",__hmacKey(),new DataView(hmacMessage.buffer)).then(value=>nativeHmacSignature=value);
 const parameters=new Proxy({name:"KMAC128",outputLength:{valueOf(){signatureOrder.push("number");return 256.9}},get customization(){kmacMessage.set([0,1,2,3]);return new Uint8Array(0)}},{get(target,name){signatureOrder.push("get "+name);return target[name]},has(target,name){signatureOrder.push("has "+name);return name in target}});
 globalThis.kmacSignaturePromise=crypto.subtle.sign(parameters,__kmacKey(),kmacMessage);kmacSignaturePromise.then(value=>nativeKmacSignature=value);kmacMessage.fill(9);hmacMessage.fill(9);
 return kmacSignaturePromise instanceof Promise&&SubtleCrypto.prototype.sign.length===3&&SubtleCrypto.prototype.verify.length===4&&signatureOrder.join(",")==="get name,has outputLength,get outputLength,number,has customization,get customization"&&nativeHmacSignature===null&&nativeKmacSignature===null;
 })()')! == 'true'
	mut queue := owner.task_queue()
	for _ in 0 .. 2 {
		work := queue.dequeue() or { panic('missing signature work') }
		assert work.source() == .unspecified
		work.execute()
	}
	for _ in 0 .. 2 {
		settle := queue.dequeue() or { panic('missing signature settlement') }
		assert settle.source() == .crypto
		settle.execute()
	}
	assert queue.is_empty()
	assert runtime.evaluate_host('nativeHmacSignature===null&&nativeKmacSignature===null')! == 'true'
	signature_host_jobs(owner)
	assert runtime.evaluate_host('nativeHmacSignature instanceof ArrayBuffer&&nativeKmacSignature instanceof ArrayBuffer&&Array.from(new Uint8Array(nativeHmacSignature),x=>x.toString(16).padStart(2,"0")).join("")==="1af22062de3b8465c125239976151bec1521821f23ca1166dd8c6ef1813b7f1b"&&Array.from(new Uint8Array(nativeKmacSignature),x=>x.toString(16).padStart(2,"0")).join("")==="e5780b0d3ea6f7d3a429c5706aa43a00fadbd7d49628839e3187243f456ee14e"')! == 'true'
	runtime.evaluate_host(r'globalThis.nativeVerification=null;const signature=new Uint8Array(nativeHmacSignature),message=new Uint8Array(15);const algorithm={get name(){message.set([83,111,109,101,32,98,111,103,117,115,32,100,97,116,97]);return "HMAC"}};crypto.subtle.verify(algorithm,__hmacKey(),signature,message).then(value=>nativeVerification=value);signature.fill(0);message.fill(0);')!
	signature_host_tasks(owner)
	assert runtime.evaluate_host('nativeVerification===true')! == 'true'
}

fn test_native_signature_all_registered_families_verify_and_reject_tampered_signatures() {
	$if !darwin {
		return
	}
	mut runtime, host := signature_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.signatureFamilies=[];globalThis.signatureFamilyErrors=[];
 const cases=[[{name:"HMAC",hash:"SHA-256"},"HMAC"],[{name:"KMAC128",length:256},{name:"KMAC128",outputLength:256,customization:new Uint8Array([4])}],["KMAC256",{name:"KMAC256",outputLength:512}],[{name:"RSA-PSS",modulusLength:1024,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},{name:"RSA-PSS",saltLength:32}],[{name:"RSASSA-PKCS1-v1_5",modulusLength:1024,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},"RSASSA-PKCS1-v1_5"],[{name:"ECDSA",namedCurve:"P-256"},{name:"ECDSA",hash:"SHA-256"}],["Ed25519","Ed25519"],["Ed448",{name:"Ed448",context:new Uint8Array([4,5])}],...["ML-DSA-44","ML-DSA-65","ML-DSA-87"].map(name=>[name,{name,context:new Uint8Array([4,5])}])];
 for(const [generation,parameters]of cases){const name=typeof generation==="string"?generation:generation.name;crypto.subtle.generateKey(generation,false,["sign","verify"]).then(key=>{const message=new Uint8Array([1,2,3]);return crypto.subtle.sign(parameters,key.privateKey||key,message).then(signature=>{if(!(signature instanceof ArrayBuffer))throw "signature brand";return crypto.subtle.verify(parameters,key.publicKey||key,signature,message).then(valid=>{const corrupt=new Uint8Array(signature);corrupt[0]^=1;return crypto.subtle.verify(parameters,key.publicKey||key,corrupt,message).then(invalid=>({name,valid,invalid}))})})}).then(result=>signatureFamilies.push(result),reason=>signatureFamilyErrors.push({name,reason}))}
 ')!
	signature_host_tasks(owner)
	assert runtime.evaluate_host('JSON.stringify(signatureFamilyErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('signatureFamilies.length===11&&signatureFamilies.every(({valid,invalid})=>valid===true&&invalid===false)')! == 'true'
}

fn test_native_signature_binding_and_parameter_errors_precede_deferred_key_usage_checks() {
	$if !darwin {
		return
	}
	mut runtime, host := signature_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	signature_host_expose(mut runtime, '__signingKey', webcrypto.CryptoKey.create(.secret, false, webcrypto.KmacKeyAlgorithm{ name: 'KMAC128', length: 256 }, [
		.sign,
		.verify,
	], []u8{len: 32}))!
	signature_host_expose(mut runtime, '__noSigningUsage', webcrypto.CryptoKey.create(.secret, false, webcrypto.KmacKeyAlgorithm{ name: 'KMAC128', length: 256 }, [], []u8{len: 32}))!
	signature_host_expose(mut runtime, '__wrongSigningAlgorithm', webcrypto.CryptoKey.create(.secret, false, webcrypto.HmacKeyAlgorithm{ name: 'HMAC', length: 256, hash: 'SHA-256' }, [], []u8{len: 32}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.signatureFailures=[];globalThis.signatureMarker={original:true};globalThis.signatureNameReads=0;
 function reject(call){try{const p=call();p.catch(reason=>signatureFailures.push(reason));return p instanceof Promise}catch(reason){return false}}
 const algorithm={get name(){signatureNameReads++;return "KMAC128"}};
 const calls=[()=>crypto.subtle.sign(),()=>crypto.subtle.verify(),()=>SubtleCrypto.prototype.sign.call({},algorithm,{},null),()=>crypto.subtle.sign(Symbol(),{},null),()=>crypto.subtle.sign(algorithm,Object.create(CryptoKey.prototype),null),()=>crypto.subtle.verify(algorithm,__signingKey(),null,new Uint8Array()),()=>crypto.subtle.verify(algorithm,__signingKey(),new Uint8Array(),null),()=>crypto.subtle.sign({name:"KMAC128"},__signingKey(),new Uint8Array()),()=>crypto.subtle.sign({name:"KMAC128",outputLength:-1},__signingKey(),new Uint8Array()),()=>crypto.subtle.sign({name:"KMAC128",get outputLength(){throw signatureMarker}},__signingKey(),new Uint8Array()),()=>crypto.subtle.sign({name:"KMAC128",outputLength:256,customization:undefined},__signingKey(),new Uint8Array()),()=>crypto.subtle.sign({name:"Ed448",context:null},__signingKey(),new Uint8Array()),()=>crypto.subtle.sign({name:"RSA-PSS",saltLength:1n},__signingKey(),new Uint8Array()),()=>crypto.subtle.sign({name:"ECDSA",get hash(){throw signatureMarker}},__signingKey(),new Uint8Array())];
 return calls.every(reject)&&signatureFailures.length===0&&signatureNameReads===0;
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	signature_host_jobs(owner)
	assert runtime.evaluate_host('signatureFailures.length===14&&signatureFailures[0].message==="sign() needs 3 arguments"&&signatureFailures[1].message==="verify() needs 4 arguments"&&signatureFailures[5].message==="No union types matched"&&signatureFailures[6].message==="No union types matched"&&signatureFailures[7].message==="Required property outputLength is missing or undefined"&&signatureFailures[9]===signatureMarker&&signatureFailures[10].message==="Not an object of type BufferSource"&&signatureFailures[11].message==="Not an object of type BufferSource"&&signatureFailures[13]===signatureMarker&&signatureFailures.every((reason,index)=>[9,13].includes(index)||reason instanceof TypeError)')! == 'true'
	runtime.evaluate_host('globalThis.signatureDeferredFailures=[];for(const key of [__wrongSigningAlgorithm(),__noSigningUsage(),__signingKey()])crypto.subtle.sign({name:"KMAC128",outputLength:7},key,new Uint8Array()).catch(reason=>signatureDeferredFailures.push(reason));crypto.subtle.verify({name:"KMAC128",outputLength:256},__noSigningUsage(),new Uint8Array(),new Uint8Array()).catch(reason=>signatureDeferredFailures.push(reason));')!
	signature_host_tasks(owner)
	assert runtime.evaluate_host('signatureDeferredFailures.length===4&&signatureDeferredFailures.every(reason=>reason instanceof DOMException)&&signatureDeferredFailures[0].message==="Algorithm mismatch"&&signatureDeferredFailures[1].message==="Key does not support signing"&&signatureDeferredFailures[2].name==="OperationError"&&signatureDeferredFailures[3].message==="Key does not support verification"')! == 'true'
}
