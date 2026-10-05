module browserjs

import dom
import html
import libjs
import webcrypto
import webidl

fn clone_crypto_key_runtime(address string) &Runtime {
	url := dom.URL{value: address}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime
}

fn clone_crypto_key_expose(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn test_native_source_crypto_key_clone_uses_internal_slots_and_captured_target_factory() {
	$if !darwin {
		return
	}
	mut runtime := clone_crypto_key_runtime('https://source-crypto-clone.example/')
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	hash := libjs.utf16_string_from_code_units([u16(0xdc00), 0xd801])
	key := webcrypto.CryptoKey.create(.secret, false, webcrypto.HmacKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: hash.str(), hash_utf16_: hash, length: 16 }, [
		.verify,
		.verify,
		.sign,
	], [u8(7), 9])
	actual := runtime.javascript_crypto_key(key)!
	clone_crypto_key_expose(mut runtime, '__originalCloneKey', actual)!
	input := runtime.evaluate_host_value(r'{globalThis.__originalCryptoKey=CryptoKey;globalThis.__sourceCryptoCloneGets=0;const key=__originalCloneKey();key.algorithm.name="author algorithm";key.algorithm.hash.name="author hash";for(const name of ["type","extractable","algorithm","usages","custom"]){Object.defineProperty(key,name,{enumerable:true,get(){++__sourceCryptoCloneGets;throw "author key getter"}})}globalThis.CryptoKey=class FakeCryptoKey{};({key,again:key})}')!
	for for_storage in [false, true] {
		record := bridge.serialize(input, for_storage)!
		cloned := bridge.deserialize(record)!
		clone_crypto_key_expose(mut runtime, '__sourceCryptoClone', cloned)!
		assert runtime.evaluate_host(r'{const result=__sourceCryptoClone(),key=result.key;key===result.again&&key instanceof __originalCryptoKey&&Object.getPrototypeOf(key)===__originalCryptoKey.prototype&&key.type==="secret"&&key.extractable===false&&key.algorithm.name===String.fromCharCode(0xd800,0)&&key.algorithm.hash.name===String.fromCharCode(0xdc00,0xd801)&&key.algorithm.length===16&&key.usages.join(",")==="verify,verify,sign"&&Object.isFrozen(key.usages)&&!Object.hasOwn(key,"custom")&&__sourceCryptoCloneGets===0}')! == 'true'
		cloned_key := runtime.evaluate_host_value('__sourceCryptoClone().key')!
		native := runtime.native_crypto_key(cloned_key)!
		assert voidptr(native) != voidptr(key)
		assert native.handle() == [u8(7), 9]
		assert native.internal_algorithm().name_utf16().code_units() == name.code_units()
	}
	record := bridge.serialize(actual, false)!
	assert record.data[..3] == [u8(24), 21, 0]
}

fn test_native_source_crypto_key_target_exposure_is_actual_secure_global_state() {
	$if !darwin {
		return
	}
	mut source := clone_crypto_key_runtime('https://source-crypto-exposure.example/')
	defer { source.close() }
	key := webcrypto.CryptoKey.create(.private_key, false, webcrypto.EcKeyAlgorithm{ name: 'ECDH', named_curve: 'P-256' }, [.derive_bits], [u8(3)])
	actual := source.javascript_crypto_key(key)!
	source_bridge := StructuredCloneBridge.create(source)!
	for for_storage in [false, true] {
		record := source_bridge.serialize(actual, for_storage)!
		mut absent := Runtime.create()
		defer { absent.close() }
		absent_bridge := StructuredCloneBridge.create(absent)!
		absent.evaluate_host('globalThis.CryptoKey=function ForgedCryptoKey(){}')!
		if _ := absent_bridge.deserialize(record) {
			assert false
		} else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
		mut insecure := clone_crypto_key_runtime('http://insecure-crypto-exposure.example/')
		defer { insecure.close() }
		insecure_bridge := StructuredCloneBridge.create(insecure)!
		insecure.evaluate_host('globalThis.CryptoKey=function ForgedCryptoKey(){}')!
		if _ := insecure_bridge.deserialize(record) {
			assert false
		}
		mut target := clone_crypto_key_runtime('https://target-crypto-exposure.example/')
		defer { target.close() }
		target_bridge := StructuredCloneBridge.create(target)!
		target.evaluate_host('globalThis.__targetCryptoKey=CryptoKey;delete globalThis.CryptoKey')!
		cloned := target_bridge.deserialize(record)!
		clone_crypto_key_expose(mut target, '__exposureClonedCryptoKey', cloned)!
		assert target.evaluate_host('__exposureClonedCryptoKey() instanceof __targetCryptoKey&&__exposureClonedCryptoKey().type==="private"&&__exposureClonedCryptoKey().algorithm.namedCurve==="P-256"')! == 'true'
		assert target.native_crypto_key(cloned)!.handle() == [u8(3)]
		assert cloned != actual
	}
}

fn test_native_source_crypto_key_clone_retains_real_imported_hmac_operation_handle() {
	$if !darwin {
		return
	}
	mut runtime := clone_crypto_key_runtime('https://real-key-clone.example/')
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	subtle := webcrypto.SubtleCrypto.create()
	key := subtle.import_key(.raw, 'Well Hello Friends'.bytes(), webcrypto.HmacImportParams{ hash: 'SHA-256' }, false, [
		.sign,
		.verify,
	], '')!
	actual := runtime.javascript_crypto_key(key)!
	message := 'Some bogus data'.bytes()
	expected := subtle.sign('HMAC', key, message)!
	for for_storage in [false, true] {
		cloned := bridge.deserialize(bridge.serialize(actual, for_storage)!)!
		clone_key := runtime.native_crypto_key(cloned)!
		assert !clone_key.extractable && clone_key.algorithm_name() == 'HMAC'
		assert clone_key.handle() == key.handle()
		assert subtle.sign('HMAC', clone_key, message)! == expected
		assert subtle.verify('HMAC', clone_key, expected, message)!
		mut corrupt := bridge.serialize(actual, for_storage)!.data.clone()
		corrupt[corrupt.len - 1] ^= 1
		corrupted := bridge.deserialize(html.SerializationRecord{ data: corrupt, type_: if for_storage {
			.storage
		} else {
			.ipc
		} })!
		assert subtle.sign('HMAC', runtime.native_crypto_key(corrupted)!, message)! != expected
	}
}
