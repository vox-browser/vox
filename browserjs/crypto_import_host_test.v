// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

fn import_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{value: 'https://import-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn import_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 1000 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('import jobs did not drain')
}

fn import_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 1000 {
			task := queue.dequeue() or { break }
			assert task.source() == .unspecified
			task.execute()
		}
		import_host_jobs(owner)
		if queue.is_empty() { return }
	}
	panic('import tasks did not drain')
}

fn test_native_import_key_copies_data_after_idl_iteration_and_algorithm_getters() {
	$if !darwin {
		return
	}
	mut runtime, host := import_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.rawImportOrder=[];globalThis.importedRaw=null;globalThis.rawImportBacking=new Uint8Array(32);const view=new DataView(rawImportBacking.buffer,5,16);
 const algorithm={get name(){rawImportOrder.push("name");view.setUint8(0,9);return "aEs-GcM"}};
 const usages={[Symbol.iterator](){rawImportOrder.push("iterator");view.setUint8(0,5);return ["decrypt","encrypt","decrypt"][Symbol.iterator]()}};
 globalThis.rawImportPromise=crypto.subtle.importKey({toString(){rawImportOrder.push("format");return "raw-secret"}},view,algorithm,{valueOf(){throw "boolean"}},usages);rawImportPromise.then(key=>importedRaw=key);rawImportBacking.fill(255);
 return rawImportPromise instanceof Promise&&SubtleCrypto.prototype.importKey.length===5&&rawImportOrder.join(",")==="format,iterator,name"&&importedRaw===null;
 })()')! == 'true'
	assert !owner.task_queue().is_empty()
	import_host_tasks(owner)
	assert runtime.evaluate_host('importedRaw instanceof CryptoKey&&importedRaw.algorithm.name==="AES-GCM"&&importedRaw.algorithm.length===128&&importedRaw.extractable&&importedRaw.usages.join(",")==="encrypt,decrypt"')! == 'true'
	actual := runtime.evaluate_host_value('importedRaw')!
	key := runtime.native_crypto_key(actual)!
	mut expected := []u8{len: 16}
	expected[0] = 9
	assert key.handle() == expected
}

fn test_native_import_jwk_lexical_getters_domstring_sequences_nested_dictionary_and_coercion_order() {
	$if !darwin {
		return
	}
	mut runtime, host := import_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.jwkImportOrder=[];globalThis.importedJwk=null;
 const prime=new Proxy({d:{toString(){jwkImportOrder.push("prime d string");return "d"}},r:"r",t:undefined},{get(target,name){jwkImportOrder.push("prime "+name);return target[name]}});
 const dictionary=new Proxy({alg:{toString(){jwkImportOrder.push("alg string");return "A128GCM"}},ext:{valueOf(){throw "boolean"}},k:"AAECAwQFBgcICQoLDA0ODw",key_ops:[{toString(){jwkImportOrder.push("key_ops string");return "encrypt"}},"decrypt"],kty:{toString(){jwkImportOrder.push("kty string");return "oct"}},oth:[prime,null]}, {get(target,name){jwkImportOrder.push(name);return target[name]}});
 const algorithm={get name(){jwkImportOrder.push("algorithm");return "AES-GCM"}};
 const usages={[Symbol.iterator](){jwkImportOrder.push("usages");return ["decrypt","encrypt"][Symbol.iterator]()}};
 globalThis.jwkImportPromise=crypto.subtle.importKey("jwk",dictionary,algorithm,true,usages);jwkImportPromise.then(key=>importedJwk=key);
 return jwkImportPromise instanceof Promise&&importedJwk===null&&jwkImportOrder.join(",")==="alg,alg string,crv,d,dp,dq,e,ext,k,key_ops,key_ops string,kty,kty string,n,oth,prime d,prime d string,prime r,prime t,p,priv,pub,q,qi,use,x,y,usages,algorithm";
 })()')! == 'true'
	import_host_tasks(owner)
	assert runtime.evaluate_host('importedJwk instanceof CryptoKey&&importedJwk.algorithm.name==="AES-GCM"&&importedJwk.usages.join(",")==="encrypt,decrypt"')! == 'true'
	key := runtime.native_crypto_key(runtime.evaluate_host_value('importedJwk')!)!
	assert key.handle() == []u8{len: 16, init: u8(index)}
}

fn test_native_import_promise_union_checks_follow_all_idl_conversions_and_preserve_original_failures() {
	$if !darwin {
		return
	}
	mut runtime, host := import_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.importFailures=[];globalThis.importMarker={original:true};globalThis.importMismatchOrder=[];globalThis.importCloseCount=0;
 function reject(call){try{const p=call();p.catch(reason=>importFailures.push(reason));return p instanceof Promise}catch(reason){return false}}
 const usages={[Symbol.iterator](){importMismatchOrder.push("usages");return ["encrypt"][Symbol.iterator]()}};
 const algorithm={get name(){throw "late algorithm"}};
 const calls=[()=>crypto.subtle.importKey(),()=>SubtleCrypto.prototype.importKey.call({},"invalid",{},"AES-GCM",true,[]),()=>crypto.subtle.importKey("invalid",{get alg(){throw "late JWK"}},"AES-GCM",true,[]),()=>crypto.subtle.importKey("raw",42,"AES-GCM",true,[]),()=>crypto.subtle.importKey("jwk",{get alg(){throw importMarker}},Symbol(),true,[]),()=>crypto.subtle.importKey("raw",{get alg(){importMismatchOrder.push("dictionary");return undefined}},algorithm,true,usages),()=>crypto.subtle.importKey("jwk",new Uint8Array(16),algorithm,true,usages),()=>crypto.subtle.importKey("jwk",{oth:[7]},algorithm,true,[]),()=>crypto.subtle.importKey("jwk",{key_ops:[Symbol()]},algorithm,true,[])];
 return calls.every(reject)&&importFailures.length===0&&importMismatchOrder.join(",")==="dictionary,usages,usages";
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	import_host_jobs(owner)
	assert runtime.evaluate_host('importFailures.length===9&&importFailures[0].message==="importKey() needs 5 arguments"&&importFailures[1] instanceof TypeError&&importFailures[2].message==="Invalid value \'invalid\' for enumeration type \'KeyFormat\'"&&importFailures[3].message==="No union types matched"&&importFailures[4]===importMarker&&importFailures[5].message==="Not an object of type BufferSource"&&importFailures[6].message==="Not an object of type JsonWebKey"&&importFailures[7].message==="Not an object of type RsaOtherPrimesInfo"&&importFailures[8] instanceof TypeError')! == 'true'
	runtime.evaluate_host(r'globalThis.importDeferredFailures=[];for(const [data,usages]of [[null,["encrypt"]],[undefined,["sign"]],[{kty:"oct",k:"AAECAwQFBgcICQoLDA0ODw",alg:"A128GCM",ext:false},["encrypt"]],[{kty:"oct",k:"AAECAwQFBgcICQoLDA0ODw",alg:"A128GCM",key_ops:["unknown"]},["encrypt"]]])crypto.subtle.importKey("jwk",data,"AES-GCM",true,usages).catch(reason=>importDeferredFailures.push(reason));')!
	assert runtime.evaluate_host('importDeferredFailures.length===0')! == 'true'
	import_host_tasks(owner)
	assert runtime.evaluate_host('importDeferredFailures.length===4&&importDeferredFailures.every(reason=>reason instanceof DOMException)&&importDeferredFailures[0].message==="Invalid key type"&&importDeferredFailures[1].message==="Invalid key usage \'sign\'"&&importDeferredFailures[2].message==="Invalid ext field"&&importDeferredFailures[3].name==="DataError"')! == 'true'
}

fn test_native_import_hmac_numeric_fields_and_every_registered_import_family() {
	$if !darwin {
		return
	}
	mut runtime, host := import_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.hmacImportOrder=[];globalThis.importedHmac=null;crypto.subtle.importKey("raw",new Uint8Array([1,2]),{get name(){hmacImportOrder.push("name");return "HMAC"},get hash(){hmacImportOrder.push("hash");return {get name(){hmacImportOrder.push("hash name");return "SHA-256"}}},get length(){hmacImportOrder.push("length");return {valueOf(){hmacImportOrder.push("number");return 15.9}}}},false,["sign"]).then(key=>importedHmac=key);
 globalThis.nativeImportResults=[];globalThis.nativeImportErrors=[];
 const cases=[...["AES-CBC","AES-CTR","AES-GCM","AES-KW","AES-OCB"].map(name=>[{name,length:128},[name==="AES-KW"?"wrapKey":"encrypt"]]),[{name:"HMAC",hash:"SHA-256"},["sign"]],[{name:"KMAC128",length:256},["sign"]],[{name:"KMAC256"},["sign"]],["ChaCha20-Poly1305",["encrypt"]],...["RSA-OAEP","RSA-PSS","RSASSA-PKCS1-v1_5"].map(name=>[{name,modulusLength:1024,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},name==="RSA-OAEP"?["encrypt","decrypt"]:["sign","verify"]]),[{name:"ECDSA",namedCurve:"P-256"},["sign","verify"]],[{name:"ECDH",namedCurve:"P-384"},["deriveBits"]],["Ed25519",["sign","verify"]],["Ed448",["sign","verify"]],["X25519",["deriveBits"]],["X448",["deriveBits"]],...["ML-DSA-44","ML-DSA-65","ML-DSA-87"].map(name=>[name,["sign","verify"]]),...["ML-KEM-512","ML-KEM-768","ML-KEM-1024"].map(name=>[name,["encapsulateBits","decapsulateBits"]])];
 for(const [algorithm,usages]of cases){const name=typeof algorithm==="string"?algorithm:algorithm.name;crypto.subtle.generateKey(algorithm,true,usages).then(generated=>{const key=generated instanceof CryptoKey?generated:generated.publicKey,format=key.type==="secret"?"raw-secret":name.startsWith("RSA")||name==="RSASSA-PKCS1-v1_5"?"spki":name==="X448"||name==="Ed448"?"raw":"raw-public";return crypto.subtle.exportKey(format,key).then(data=>crypto.subtle.importKey(format,data,algorithm,false,key.usages))}).then(key=>nativeImportResults.push({name,key}),reason=>nativeImportErrors.push({name,reason}))}
 for(const name of ["HKDF","PBKDF2","Argon2d","Argon2i","Argon2id"])crypto.subtle.importKey("raw-secret",new Uint8Array([1,2,3]),name,false,["deriveBits"]).then(key=>nativeImportResults.push({name,key}),reason=>nativeImportErrors.push({name,reason}));
 ')!
	assert runtime.evaluate_host('hmacImportOrder.join(",")==="name,hash,hash name,length,number"')! == 'true'
	import_host_tasks(owner)
	assert runtime.evaluate_host('importedHmac instanceof CryptoKey&&importedHmac.algorithm.length===15&&importedHmac.algorithm.hash.name==="SHA-256"&&!importedHmac.extractable')! == 'true'
	assert runtime.native_crypto_key(runtime.evaluate_host_value('importedHmac')!)!.handle() == [u8(1)]
	assert runtime.evaluate_host('JSON.stringify(nativeImportErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('nativeImportResults.length===29&&nativeImportResults.every(({name,key})=>key instanceof CryptoKey&&!key.extractable&&key.algorithm.name===name&&Object.isFrozen(key.usages))')! == 'true'
}

fn test_native_import_buffer_restrictions_and_detachment_observe_source_copy_boundary() {
	$if !darwin {
		return
	}
	mut runtime, host := import_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.detachedImportedKey=null;globalThis.bufferImportFailures=[];globalThis.detachedCopySupported=typeof ArrayBuffer.prototype.transfer==="function";
 if(detachedCopySupported){const bytes=new Uint8Array(16);bytes[0]=5;crypto.subtle.importKey("raw",bytes,{get name(){bytes.buffer.transfer();return "AES-GCM"}},false,["encrypt"]).then(key=>detachedImportedKey=key,reason=>bufferImportFailures.push(reason));const detached=new ArrayBuffer(16);detached.transfer();crypto.subtle.importKey("raw",detached,"AES-GCM",false,["encrypt"]).catch(reason=>bufferImportFailures.push(reason))}
 globalThis.restrictedImportFailures=[];globalThis.restrictedImportNameReads=0;const algorithm={get name(){restrictedImportNameReads++;return "AES-GCM"}};
 if(typeof ArrayBuffer.prototype.resize==="function")for(const data of [new ArrayBuffer(16,{maxByteLength:32}),new Uint8Array(new ArrayBuffer(16,{maxByteLength:32}))])crypto.subtle.importKey("raw",data,algorithm,false,["encrypt"]).catch(reason=>restrictedImportFailures.push(reason));
 globalThis.sharedImportSupported=typeof SharedArrayBuffer==="function";if(sharedImportSupported){const shared=new SharedArrayBuffer(16);crypto.subtle.importKey("raw",shared,algorithm,false,["encrypt"]).catch(reason=>restrictedImportFailures.push(reason));crypto.subtle.importKey("raw",new Uint8Array(shared),algorithm,false,["encrypt"]).catch(reason=>restrictedImportFailures.push(reason));}
 ')!
	assert runtime.evaluate_host('restrictedImportNameReads===0')! == 'true'
	import_host_tasks(owner)
	assert runtime.evaluate_host('!detachedCopySupported||(detachedImportedKey===null&&bufferImportFailures.length===2&&bufferImportFailures.every(error=>error instanceof DOMException&&error.name==="DataError"))')! == 'true'
	assert runtime.evaluate_host('restrictedImportFailures.every(reason=>reason instanceof TypeError)&&restrictedImportFailures.every(reason=>reason.message.startsWith("Not an object of type fixed-length")||reason.message==="Not an object of type BufferSource"||reason.message==="The array buffer object cannot be a SharedArrayBuffer")')! == 'true'
}
