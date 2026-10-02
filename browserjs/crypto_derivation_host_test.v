// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import webcrypto

fn derivation_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{'https://derivation-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn derivation_host_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) ! {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
}

fn derivation_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 1000 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('derivation jobs did not drain')
}

fn derivation_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		for _ in 0 .. 1000 {
			task := queue.dequeue() or { break }
			assert task.source() == .unspecified
			task.execute()
		}
		derivation_host_jobs(owner)
		if queue.is_empty() { return }
	}
	panic('derivation tasks did not drain')
}

fn test_native_derivation_hkdf_vector_length_idl_order_copied_parameters_and_deferred_settlement() {
	$if !darwin {
		return
	}
	mut runtime, host := derivation_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	derivation_host_expose(mut runtime, '__hkdfBase', webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: 'HKDF' }, [
		.derive_bits,
		.derive_key,
	], []u8{len: 22, init: 11}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.derivationOrder=[];globalThis.nativeDerivedBits=null;globalThis.hkdfSalt=Uint8Array.from({length:13},(_,i)=>i);globalThis.hkdfInfo=Uint8Array.from({length:10},(_,i)=>i+240);
 const parameters={get name(){derivationOrder.push("name");return "HKDF"},get hash(){derivationOrder.push("hash");return {get name(){derivationOrder.push("hash name");return "SHA-256"}}},get salt(){derivationOrder.push("salt");return new DataView(hkdfSalt.buffer)},get info(){derivationOrder.push("info");hkdfSalt.fill(255);return hkdfInfo}};
 const length={valueOf(){derivationOrder.push("length");return 4294967632.9}};
 globalThis.nativeDerivedPromise=crypto.subtle.deriveBits(parameters,__hkdfBase(),length,"ignored");nativeDerivedPromise.then(value=>nativeDerivedBits=value);hkdfInfo.fill(255);
 return nativeDerivedPromise instanceof Promise&&SubtleCrypto.prototype.deriveBits.length===2&&SubtleCrypto.prototype.deriveKey.length===5&&derivationOrder.join(",")==="length,name,hash,hash name,salt,info"&&nativeDerivedBits===null;
 })()')! == 'true'
	mut queue := owner.task_queue()
	work := queue.dequeue() or { panic('missing derive work') }
	assert work.source() == .unspecified
	work.execute()
	assert queue.is_empty()
	assert runtime.evaluate_host('nativeDerivedBits===null')! == 'true'
	derivation_host_jobs(owner)
	assert runtime.evaluate_host('nativeDerivedBits instanceof ArrayBuffer&&Array.from(new Uint8Array(nativeDerivedBits),x=>x.toString(16).padStart(2,"0")).join("")==="3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"')! == 'true'
}

fn test_native_derive_key_reads_destination_twice_and_keeps_distinct_import_and_length_snapshots() {
	$if !darwin {
		return
	}
	mut runtime, host := derivation_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	derivation_host_expose(mut runtime, '__hkdfBase', webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: 'HKDF' }, [.derive_key], []u8{len: 22, init: 11}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.derivedKeyOrder=[];globalThis.nativeDerivedKey=null;let hashReads=0;
 const algorithm={get name(){derivedKeyOrder.push("base name");return "HKDF"},get hash(){derivedKeyOrder.push("base hash");return "SHA-256"},get salt(){derivedKeyOrder.push("base salt");return new Uint8Array(13)},get info(){derivedKeyOrder.push("base info");return new Uint8Array(0)}};
 const destination=new Proxy({get name(){return "HMAC"},get hash(){return ++hashReads===1?"SHA-1":"SHA-512"}},{get(target,name){derivedKeyOrder.push("destination "+name);return target[name]},has(target,name){derivedKeyOrder.push("has "+name);return name in target}});
 const usages={[Symbol.iterator](){derivedKeyOrder.push("usages");return ["verify","sign"][Symbol.iterator]()}};
 globalThis.derivedKeyPromise=crypto.subtle.deriveKey(algorithm,__hkdfBase(),destination,{valueOf(){throw "boolean"}},usages);derivedKeyPromise.then(key=>nativeDerivedKey=key);
 return derivedKeyPromise instanceof Promise&&nativeDerivedKey===null&&derivedKeyOrder.join(",")==="usages,base name,base hash,base salt,base info,destination name,destination hash,has length,destination name,destination hash,has length";
 })()')! == 'true'
	derivation_host_tasks(owner)
	assert runtime.evaluate_host('nativeDerivedKey instanceof CryptoKey&&nativeDerivedKey.algorithm.name==="HMAC"&&nativeDerivedKey.algorithm.hash.name==="SHA-1"&&nativeDerivedKey.algorithm.length===1024&&nativeDerivedKey.extractable&&nativeDerivedKey.usages.join(",")==="sign,verify"')! == 'true'
	assert runtime.native_crypto_key(runtime.evaluate_host_value('nativeDerivedKey')!)!.handle().len == 128
	runtime.evaluate_host('globalThis.distinctDestinationFailure=null;let calls=0;crypto.subtle.deriveKey({name:"HKDF",hash:"SHA-256",salt:new Uint8Array(),info:new Uint8Array()},__hkdfBase(),{get name(){return ++calls===1?"AES-GCM":"HMAC"},hash:"SHA-256"},false,["encrypt"]).catch(reason=>distinctDestinationFailure=reason);')!
	derivation_host_tasks(owner)
	assert runtime.evaluate_host('distinctDestinationFailure instanceof DOMException&&distinctDestinationFailure.name==="DataError"&&distinctDestinationFailure.message==="Invalid key length \'512\' bits (must be either 128, 192, or 256 bits)"')! == 'true'
}

fn test_native_derivation_all_eight_registered_names_use_native_kdf_and_exchange_results() {
	$if !darwin {
		return
	}
	mut runtime, host := derivation_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.derivationFamilies=[];globalThis.derivationFamilyErrors=[];
 const cases=[["HKDF",new Uint8Array(22).fill(11),{name:"HKDF",hash:"SHA-256",salt:Uint8Array.from({length:13},(_,i)=>i),info:Uint8Array.from({length:10},(_,i)=>i+240)},336,"3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"],["PBKDF2",new Uint8Array([112,97,115,115,119,111,114,100]),{name:"PBKDF2",salt:new Uint8Array([115,97,108,116]),iterations:1,hash:"SHA-256"},160,"120fb6cffcf8b32c43e7225256c4f837a86548c9"],...["Argon2d","Argon2i","Argon2id"].map((name,i)=>[name,new Uint8Array(32).fill(1),{name,nonce:new Uint8Array(16).fill(2),parallelism:4,memory:32,passes:3,version:19,secretValue:new Uint8Array(8).fill(3),associatedData:new Uint8Array(12).fill(4)},256,["512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb","c814d9d1dc7f37aa13f0d77f2494bda1c8de6b016dd388d29952a4c4672b6ce8","0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659"][i]])];
 for(const [name,input,parameters,length,expected]of cases)crypto.subtle.importKey("raw-secret",input,name,false,["deriveBits","deriveKey"]).then(base=>crypto.subtle.deriveBits(parameters,base,length)).then(bits=>derivationFamilies.push({name,valid:bits instanceof ArrayBuffer&&Array.from(new Uint8Array(bits),x=>x.toString(16).padStart(2,"0")).join("")===expected}),reason=>derivationFamilyErrors.push({name,reason}));
 for(const [name,generation]of [["ECDH",{name:"ECDH",namedCurve:"P-256"}],["X25519","X25519"],["X448","X448"]])crypto.subtle.generateKey(generation,false,["deriveBits"]).then(first=>crypto.subtle.generateKey(generation,false,["deriveBits"]).then(second=>crypto.subtle.deriveBits({name,public:second.publicKey},first.privateKey).then(left=>crypto.subtle.deriveBits({name,public:first.publicKey},second.privateKey).then(right=>({name,valid:left instanceof ArrayBuffer&&right instanceof ArrayBuffer&&left.byteLength>0&&new Uint8Array(left).every((value,i)=>value===new Uint8Array(right)[i])}))))).then(result=>derivationFamilies.push(result),reason=>derivationFamilyErrors.push({name,reason}));
 ')!
	derivation_host_tasks(owner)
	assert runtime.evaluate_host('JSON.stringify(derivationFamilyErrors.map(({name,reason})=>({name,type:reason.name,message:reason.message})))')! == '[]'
	assert runtime.evaluate_host('derivationFamilies.length===8&&derivationFamilies.every(({valid})=>valid===true)')! == 'true'
}

fn test_native_derivation_length_and_parameter_errors_preserve_source_binding_and_task_order() {
	$if !darwin {
		return
	}
	mut runtime, host := derivation_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	derivation_host_expose(mut runtime, '__hkdfBase', webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: 'HKDF' }, [
		.derive_bits,
		.derive_key,
	], [u8(1)]))!
	derivation_host_expose(mut runtime, '__noDerivationUsage', webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: 'HKDF' }, [], [u8(1)]))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.derivationFailures=[];globalThis.derivationMarker={original:true};globalThis.derivationNameReads=0;
 function reject(call){try{const p=call();p.catch(reason=>derivationFailures.push(reason));return p instanceof Promise}catch(reason){return false}}
 const algorithm={get name(){derivationNameReads++;return "HKDF"}};
 const calls=[()=>crypto.subtle.deriveBits(),()=>crypto.subtle.deriveKey(),()=>crypto.subtle.deriveBits(Symbol(),{},1),()=>crypto.subtle.deriveBits(algorithm,{},1),()=>crypto.subtle.deriveBits(algorithm,__hkdfBase(),1n),()=>crypto.subtle.deriveKey(algorithm,__hkdfBase(),Symbol(),false,[]),()=>crypto.subtle.deriveBits({get name(){throw derivationMarker}},__hkdfBase(),8),()=>crypto.subtle.deriveBits({name:"ECDH",public:null},__hkdfBase(),8),()=>crypto.subtle.deriveBits({name:"Argon2id"},__hkdfBase(),8),()=>crypto.subtle.deriveBits({name:"Argon2id",nonce:new Uint8Array(16),parallelism:-1},__hkdfBase(),8)];
 return calls.every(reject)&&derivationFailures.length===0&&derivationNameReads===0;
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	derivation_host_jobs(owner)
	assert runtime.evaluate_host('derivationFailures.length===10&&derivationFailures[0].message==="deriveBits() needs 2 arguments"&&derivationFailures[1].message==="deriveKey() needs 5 arguments"&&derivationFailures[6]===derivationMarker&&derivationFailures[7].message==="ToObject on null or undefined"&&derivationFailures[8].message==="Required property nonce is missing or undefined"&&derivationFailures.every((reason,index)=>index===6||reason instanceof TypeError)')! == 'true'
	runtime.evaluate_host('globalThis.derivationDeferredFailures=[];const parameters={name:"HKDF",hash:"SHA-256",salt:new Uint8Array(),info:new Uint8Array()};for(const length of [undefined,null])crypto.subtle.deriveBits(parameters,__hkdfBase(),length).catch(reason=>derivationDeferredFailures.push(reason));crypto.subtle.deriveBits(parameters,__noDerivationUsage(),8).catch(reason=>derivationDeferredFailures.push(reason));crypto.subtle.deriveKey(parameters,__noDerivationUsage(),{name:"AES-GCM",length:7},false,["encrypt"]).catch(reason=>derivationDeferredFailures.push(reason));crypto.subtle.deriveKey(parameters,__hkdfBase(),{name:"AES-GCM",length:128},false,[]).catch(reason=>derivationDeferredFailures.push(reason));')!
	derivation_host_tasks(owner)
	assert runtime.evaluate_host('derivationDeferredFailures.length===5&&derivationDeferredFailures.every(reason=>reason instanceof DOMException)&&derivationDeferredFailures[0].message==="Length must be specified and divisible by 8"&&derivationDeferredFailures[1].message==="Length must be specified and divisible by 8"&&derivationDeferredFailures[2].message==="Key does not support deriving bits"&&derivationDeferredFailures[3].message==="Key does not support deriving keys"&&derivationDeferredFailures[4].message==="usages must not be empty"')! == 'true'
	assert runtime.evaluate_host(r'(function(){globalThis.omittedLengthFailure=null;let reads=0;Object.defineProperty(Object.prototype,"2",{get(){reads++;throw "inherited arguments"},configurable:true});let promise;try{promise=crypto.subtle.deriveBits({name:"HKDF",hash:"SHA-256",salt:new Uint8Array(),info:new Uint8Array()},__hkdfBase())}finally{delete Object.prototype["2"]}promise.catch(reason=>omittedLengthFailure=reason);return promise instanceof Promise&&reads===0})()')! == 'true'
	derivation_host_tasks(owner)
	assert runtime.evaluate_host('omittedLengthFailure instanceof DOMException&&omittedLengthFailure.message==="Length must be specified and divisible by 8"')! == 'true'
}
