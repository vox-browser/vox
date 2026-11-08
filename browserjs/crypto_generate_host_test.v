// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

fn generation_host_fixture() (&Runtime, &html.EventLoop) {
	url := dom.URL{value: 'https://generation-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host.settings.responsible_event_loop()
}

fn generation_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 100 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('generation jobs did not drain')
}

fn generation_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		task := queue.dequeue() or { break }
		assert task.source() == .unspecified
		task.execute()
	}
	generation_host_jobs(owner)
}

fn test_native_crypto_numeric_ranges_reject_before_scheduling_backend_work() {
	$if !darwin { return }
	mut runtime, mut owner := generation_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.rangeErrors=[];globalThis.rangeCount=0;
 function check(algorithm){rangeCount++;const promise=crypto.subtle.generateKey(algorithm,true,[algorithm.name.startsWith("RSA")?"sign":algorithm.name.startsWith("AES")?"encrypt":"sign"]);promise.catch(error=>rangeErrors.push(error));if(!(promise instanceof Promise))throw new Error("not a Promise")}
 for(const name of ["AES-CBC","AES-CTR","AES-GCM"])for(const length of [-1,NaN,Infinity,65536+128,2**32+128])check({name,length});
 for(const name of ["HMAC","KMAC128","KMAC256"])for(const length of [-1,NaN,Infinity,2**32+128])check({name,length,hash:"SHA-256"});
 for(const name of ["RSA-PSS","RSASSA-PKCS1-v1_5"])for(const modulusLength of [-1,NaN,Infinity,2**32+1024])check({name,modulusLength,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"});
 return rangeCount===35&&rangeErrors.length===0;
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	generation_host_jobs(owner)
	assert runtime.evaluate_host('rangeErrors.length===rangeCount&&rangeErrors.every(error=>error instanceof TypeError)')! == 'true'
}

fn test_native_generate_key_source_argument_conversion_parameter_order_and_deferred_key_record() {
	$if !darwin {
		return
	}
	mut runtime, mut owner := generation_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.generationOrder=[];globalThis.generatedKey=null;
 const algorithm={get name(){generationOrder.push("name");return "aes-gcm"},get length(){generationOrder.push("length");return {valueOf(){generationOrder.push("number");return 128.9}}}};
 const usages={[Symbol.iterator](){generationOrder.push("iterator");let index=0;return {next(){generationOrder.push("next");return index++===0?{value:{toString(){generationOrder.push("usage");return "decrypt"}},done:false}:index===2?{value:"encrypt",done:false}:{done:true}}}}};
 globalThis.generatedPromise=crypto.subtle.generateKey(algorithm,{valueOf(){throw "boolean conversion"}},usages);generatedPromise.then(key=>generatedKey=key);
 return generatedPromise instanceof Promise&&SubtleCrypto.prototype.generateKey.length===3&&generationOrder.join(",")==="iterator,next,usage,next,next,name,length,number"&&generatedKey===null;
 })()')! == 'true'
	mut queue := owner.task_queue()
	task := queue.dequeue() or { panic('missing generation work') }
	assert task.source() == .unspecified
	task.execute()
	assert queue.is_empty()
	assert runtime.evaluate_host('generatedKey===null')! == 'true'
	generation_host_jobs(owner)
	// Upstream normalized_key_usages sorts in KeyUsage enum order.
	assert runtime.evaluate_host('generatedKey instanceof CryptoKey&&generatedKey.type==="secret"&&generatedKey.extractable===true&&generatedKey.algorithm.name==="AES-GCM"&&generatedKey.algorithm.length===128&&generatedKey.usages.join(",")==="encrypt,decrypt"')! == 'true'
	actual := runtime.evaluate_host_value('generatedKey')!
	assert runtime.native_crypto_key(actual)!.algorithm_name() == 'AES-GCM'
}

fn test_native_generate_rsa_reads_exponent_bytes_after_nested_hash_normalization() {
	$if !darwin {
		return
	}
	mut runtime, mut owner := generation_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.rsaGenerationOrder=[];globalThis.rsaGeneratedPair=null;const exponent=new Uint8Array([0,0,5]);
 const algorithm={get name(){rsaGenerationOrder.push("name");return "RSA-PSS"},get modulusLength(){rsaGenerationOrder.push("modulus");return 1024},get publicExponent(){rsaGenerationOrder.push("exponent");return exponent},get hash(){rsaGenerationOrder.push("hash");return {get name(){rsaGenerationOrder.push("hash name");exponent[2]=3;return "SHA-256"}}}};
 crypto.subtle.generateKey(algorithm,false,["verify","sign"]).then(pair=>rsaGeneratedPair=pair);exponent[2]=17;
 ')!
	assert runtime.evaluate_host('rsaGenerationOrder.join(",")==="name,modulus,exponent,hash,hash name"&&rsaGeneratedPair===null')! == 'true'
	generation_host_tasks(owner)
	assert runtime.evaluate_host('rsaGeneratedPair.publicKey instanceof CryptoKey&&rsaGeneratedPair.privateKey instanceof CryptoKey&&rsaGeneratedPair.publicKey.type==="public"&&rsaGeneratedPair.publicKey.extractable&&rsaGeneratedPair.privateKey.type==="private"&&!rsaGeneratedPair.privateKey.extractable&&rsaGeneratedPair.publicKey.algorithm.modulusLength===1024&&rsaGeneratedPair.publicKey.algorithm.publicExponent instanceof Uint8Array&&rsaGeneratedPair.publicKey.algorithm.publicExponent.join(",")==="3"&&rsaGeneratedPair.publicKey.algorithm.hash.name==="SHA-256"&&rsaGeneratedPair.publicKey.usages.join(",")==="verify"&&rsaGeneratedPair.privateKey.usages.join(",")==="sign"')! == 'true'
}

fn test_native_generate_key_every_registered_family_reaches_native_backend_and_real_key_wrappers() {
	$if !darwin {
		return
	}
	mut runtime, mut owner := generation_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.familyGenerationResults=[];globalThis.familyGenerationErrors=[];
 const cases=[...["AES-CBC","AES-CTR","AES-GCM","AES-KW","AES-OCB"].map(name=>[{name,length:128},[name==="AES-KW"?"wrapKey":"encrypt"]]),[{name:"HMAC",hash:"SHA-256"},["sign"]],[{name:"KMAC128",length:256},["sign"]],[{name:"KMAC256"},["sign"]],["ChaCha20-Poly1305",["encrypt"]],...["RSA-OAEP","RSA-PSS","RSASSA-PKCS1-v1_5"].map(name=>[{name,modulusLength:1024,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},name==="RSA-OAEP"?["encrypt","decrypt"]:["sign","verify"]]),[{name:"ECDSA",namedCurve:"P-256"},["sign","verify"]],[{name:"ECDH",namedCurve:"P-384"},["deriveBits"]],["Ed25519",["sign","verify"]],["Ed448",["sign","verify"]],["X25519",["deriveBits"]],["X448",["deriveBits"]],...["ML-DSA-44","ML-DSA-65","ML-DSA-87"].map(name=>[name,["sign","verify"]]),...["ML-KEM-512","ML-KEM-768","ML-KEM-1024"].map(name=>[name,["encapsulateBits","decapsulateBits"]])];
 for(const [algorithm,usages]of cases){const name=typeof algorithm==="string"?algorithm:algorithm.name;crypto.subtle.generateKey(algorithm,false,usages).then(result=>familyGenerationResults.push({name,result}),reason=>familyGenerationErrors.push({name,reason}))}
 ')!
	generation_host_tasks(owner)
	assert runtime.evaluate_host('JSON.stringify(familyGenerationErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('familyGenerationResults.length')! == '24'
	assert runtime.evaluate_host(r'
 familyGenerationErrors.length===0&&familyGenerationResults.length===24&&familyGenerationResults.every(({name,result})=>{if(result instanceof CryptoKey)return result.type==="secret"&&!result.extractable&&result.algorithm.name===name&&Object.isFrozen(result.usages);return result.publicKey instanceof CryptoKey&&result.privateKey instanceof CryptoKey&&result.publicKey.type==="public"&&result.privateKey.type==="private"&&result.publicKey.extractable&&!result.privateKey.extractable&&result.publicKey.algorithm.name===name&&result.privateKey.algorithm.name===name&&result.privateKey.usages.length>0});
 ')! == 'true'
}

fn test_native_generation_promise_rejections_preserve_source_iteration_and_validation_precedence() {
	$if !darwin {
		return
	}
	mut runtime, mut owner := generation_host_fixture()
	defer { runtime.close() }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.generationFailures=[];globalThis.generationMarker={original:true};globalThis.generationCloseCount=0;globalThis.generationNameCount=0;
 function reject(call){try{const promise=call();promise.catch(reason=>generationFailures.push(reason));return promise instanceof Promise}catch(reason){return false}}
 const invalid={[Symbol.iterator](){return {next(){return {value:"invalid usage",done:false}},return(){generationCloseCount++;return {done:true}}}}};
 const immediate=[()=>crypto.subtle.generateKey(),()=>SubtleCrypto.prototype.generateKey.call({},"AES-GCM",true,[]),()=>crypto.subtle.generateKey({get name(){generationNameCount++;return "AES-GCM"}},true,invalid),()=>crypto.subtle.generateKey({get name(){throw generationMarker}},true,[]),()=>crypto.subtle.generateKey(Symbol("name"),true,{get [Symbol.iterator](){throw "later iterator"}}),()=>crypto.subtle.generateKey("AES-GCM",true,null)];
 return immediate.every(reject)&&generationFailures.length===0&&generationNameCount===0&&generationCloseCount===0;
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	generation_host_jobs(owner)
	assert runtime.evaluate_host('generationFailures.length===6&&generationFailures[0] instanceof TypeError&&generationFailures[0].message==="generateKey() needs 3 arguments"&&generationFailures[1] instanceof TypeError&&generationFailures[2] instanceof TypeError&&generationFailures[2].message==="Invalid value \'invalid usage\' for enumeration type \'KeyUsage\'"&&generationFailures[3]===generationMarker&&generationFailures[4] instanceof TypeError&&generationFailures[5] instanceof TypeError&&generationFailures[5].message==="null is not an object"')! == 'true'
	runtime.evaluate_host('globalThis.deferredGenerationErrors=[];for(const algorithm of [{name:"AES-GCM",length:7},{name:"ECDSA",namedCurve:42},{name:"AES-GCM",length:128}])crypto.subtle.generateKey(algorithm,true,[]).catch(reason=>deferredGenerationErrors.push(reason));')!
	assert runtime.evaluate_host('deferredGenerationErrors.length===0')! == 'true'
	generation_host_tasks(owner)
	assert runtime.evaluate_host('deferredGenerationErrors.length===3&&deferredGenerationErrors[0] instanceof DOMException&&deferredGenerationErrors[0].name==="OperationError"&&deferredGenerationErrors[1] instanceof DOMException&&deferredGenerationErrors[1].name==="NotSupportedError"&&deferredGenerationErrors[2] instanceof DOMException&&deferredGenerationErrors[2].name==="SyntaxError"&&deferredGenerationErrors[2].message==="usages must not be empty"')! == 'true'
}
