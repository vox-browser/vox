// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import webcrypto

fn export_host_fixture() (&Runtime, &CryptoHost) {
	url := dom.URL{'https://export-binding.example/'}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn export_host_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) ! {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
}

fn export_host_jobs(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	for _ in 0 .. 100 {
		job := loop.dequeue_microtask() or { return }
		job.execute()
	}
	panic('export jobs did not drain')
}

fn export_host_tasks(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 100 {
		task := queue.dequeue() or { break }
		assert task.source() == .unspecified
		task.execute()
	}
	export_host_jobs(owner)
}

fn test_native_export_key_owning_deferred_work_actual_arraybuffer_and_source_jwk_order() {
	$if !darwin {
		return
	}
	mut runtime, host := export_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	key := webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.decrypt,
		.encrypt,
	], []u8{len: 16, init: u8(index)})
	export_host_expose(mut runtime, '__exportKey', key)!
	assert runtime.evaluate_host(r'(function(){
 globalThis.nativeExportKey=__exportKey();globalThis.exportOrder=[];globalThis.rawExport=null;globalThis.jwkExport=null;
 nativeExportKey.algorithm.name="fake";nativeExportKey.algorithm.length=7;
 const format={toString(){exportOrder.push("format");return "raw-secret"}};
 globalThis.exportPromise=crypto.subtle.exportKey(format,nativeExportKey,"ignored");exportPromise.then(value=>rawExport=value);crypto.subtle.exportKey("jwk",nativeExportKey).then(value=>jwkExport=value);
 return exportPromise instanceof Promise&&SubtleCrypto.prototype.exportKey.length===2&&exportOrder.join(",")==="format"&&rawExport===null&&jwkExport===null;
 })()')! == 'true'
	mut queue := owner.task_queue()
	for _ in 0 .. 2 {
		task := queue.dequeue() or { panic('missing export work') }
		assert task.source() == .unspecified
		task.execute()
	}
	assert queue.is_empty()
	assert runtime.evaluate_host('rawExport===null&&jwkExport===null')! == 'true'
	export_host_jobs(owner)
	assert runtime.evaluate_host('rawExport instanceof ArrayBuffer&&new Uint8Array(rawExport).join(",")==="0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15"&&Object.getPrototypeOf(jwkExport)===Object.prototype&&Object.keys(jwkExport).join(",")==="alg,ext,k,key_ops,kty"&&jwkExport.alg==="A128GCM"&&jwkExport.ext===true&&jwkExport.k==="AAECAwQFBgcICQoLDA0ODw"&&jwkExport.kty==="oct"&&jwkExport.key_ops.join(",")==="decrypt,encrypt"&&Object.keys(jwkExport).every(name=>{const p=Object.getOwnPropertyDescriptor(jwkExport,name);return p.writable&&p.enumerable&&p.configurable})')! == 'true'
	runtime.evaluate_host('new Uint8Array(rawExport)[0]=255;jwkExport.key_ops.push("sign");')!
	assert key.handle()[0] == 0
	assert key.usages == [webcrypto.KeyUsage.decrypt, .encrypt]
}

fn test_native_export_key_idl_error_precedence_and_deferred_normalization_extractability() {
	$if !darwin {
		return
	}
	mut runtime, host := export_host_fixture()
	defer { runtime.close() }
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	export_host_expose(mut runtime, '__extractable', webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [.encrypt], []u8{len: 16}))!
	export_host_expose(mut runtime, '__unextractable', webcrypto.CryptoKey.create(.secret, false, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [.encrypt], []u8{len: 16}))!
	export_host_expose(mut runtime, '__unregistered', webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: 'unregistered' }, [], []u8{}))!
	assert runtime.evaluate_host(r'(function(){
 globalThis.exportFailures=[];globalThis.exportMarker={original:true};let formatReads=0;
 function reject(call){try{const p=call();p.catch(reason=>exportFailures.push(reason));return p instanceof Promise}catch(reason){return false}}
 const calls=[()=>crypto.subtle.exportKey(),()=>SubtleCrypto.prototype.exportKey.call({}, {toString(){formatReads++;return "jwk"}},{}),()=>crypto.subtle.exportKey("invalid",{}),()=>crypto.subtle.exportKey({toString(){throw exportMarker}},{}),()=>crypto.subtle.exportKey("raw",Object.create(CryptoKey.prototype)),()=>crypto.subtle.exportKey(Symbol("format"),__extractable())];
 return calls.every(reject)&&formatReads===0&&exportFailures.length===0;
 })()')! == 'true'
	assert owner.task_queue().is_empty()
	export_host_jobs(owner)
	assert runtime.evaluate_host('exportFailures.length===6&&exportFailures[0] instanceof TypeError&&exportFailures[0].message==="exportKey() needs 2 arguments"&&exportFailures[1] instanceof TypeError&&exportFailures[2].message==="Invalid value \'invalid\' for enumeration type \'KeyFormat\'"&&exportFailures[3]===exportMarker&&exportFailures[4] instanceof TypeError&&exportFailures[5] instanceof TypeError')! == 'true'
	runtime.evaluate_host('globalThis.deferredExportFailures=[];for(const key of [__extractable(),__unextractable(),__unregistered()])crypto.subtle.exportKey("pkcs8",key).catch(reason=>deferredExportFailures.push(reason));')!
	assert runtime.evaluate_host('deferredExportFailures.length===0')! == 'true'
	export_host_tasks(owner)
	assert runtime.evaluate_host('deferredExportFailures.length===3&&deferredExportFailures.every(reason=>reason instanceof DOMException)&&deferredExportFailures[0].name==="NotSupportedError"&&deferredExportFailures[0].message==="Cannot export to unsupported format"&&deferredExportFailures[1].name==="InvalidAccessError"&&deferredExportFailures[1].message==="Key is not extractable"&&deferredExportFailures[2].name==="NotSupportedError"')! == 'true'
}

fn test_native_export_key_captured_property_construction_and_close_skips_engine_settlement() {
	$if !darwin {
		return
	}
	mut runtime, host := export_host_fixture()
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	export_host_expose(mut runtime, '__exportKey', webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [.encrypt], []u8{len: 16}))!
	runtime.evaluate_host(r'globalThis.poisonedExport=null;Object.defineProperty(Object.prototype,"kty",{set(){throw "setter"},configurable:true});Object.defineProperty=()=>{throw "define"};crypto.subtle.exportKey("jwk",__exportKey()).then(value=>poisonedExport=value);')!
	export_host_tasks(owner)
	assert runtime.evaluate_host('poisonedExport.kty==="oct"&&poisonedExport.k==="AAAAAAAAAAAAAAAAAAAAAA"')! == 'true'
	runtime.evaluate_host('crypto.subtle.exportKey("raw",__exportKey())')!
	runtime.close()
	export_host_tasks(owner)
}
