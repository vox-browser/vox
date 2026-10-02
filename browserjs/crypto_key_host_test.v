// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import webcrypto

fn crypto_key_host_fixture(address string) (&Runtime, &CryptoHost) {
	url := dom.URL{address}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() }) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn crypto_key_test_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) !voidptr {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	return wrapper
}

fn test_native_crypto_key_actual_record_wrapper_identity_brands_and_cached_mutable_algorithm() {
	$if !darwin {
		return
	}
	mut runtime, _ := crypto_key_host_fixture('https://key-binding.example/')
	defer { runtime.close() }
	mut key := webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 }, [
		.decrypt,
		.encrypt,
	], []u8{len: 16})
	actual := crypto_key_test_expose(mut runtime, '__testCryptoKey', key)!
	assert voidptr(runtime.native_crypto_key(actual)!) == voidptr(key)
	assert runtime.javascript_crypto_key(key)! == actual
	assert runtime.evaluate_host(r'(function(){
 globalThis.nativeKey=__testCryptoKey();globalThis.originalAlgorithm=nativeKey.algorithm;globalThis.originalUsages=nativeKey.usages;
 originalAlgorithm.name="author display name";originalAlgorithm.custom=true;let constructors=0;for(const call of [()=>new CryptoKey(),()=>CryptoKey(),()=>Object.getOwnPropertyDescriptor(CryptoKey.prototype,"type").get.call(Object.create(CryptoKey.prototype)),()=>Object.getOwnPropertyDescriptor(CryptoKey.prototype,"algorithm").get.call(new Proxy(nativeKey,{}))]){try{call()}catch(error){if(error instanceof TypeError)constructors++}}
 return nativeKey instanceof CryptoKey&&Object.prototype.toString.call(nativeKey)==="[object CryptoKey]"&&nativeKey===__testCryptoKey()&&nativeKey.type==="secret"&&nativeKey.extractable===true&&nativeKey.algorithm===originalAlgorithm&&nativeKey.algorithm.name==="author display name"&&nativeKey.algorithm.length===128&&nativeKey.algorithm.custom&&nativeKey.usages===originalUsages&&Array.isArray(originalUsages)&&Object.isFrozen(originalUsages)&&originalUsages.join(",")==="decrypt,encrypt"&&constructors===4&&["type","extractable","algorithm","usages"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(CryptoKey.prototype,name);return descriptor.enumerable&&descriptor.configurable&&descriptor.set===undefined&&descriptor.get.name==="get "+name&&descriptor.get.length===0});
 })()')! == 'true'
	assert key.algorithm_name() == 'AES-GCM'
	key.set_algorithm(webcrypto.AesKeyAlgorithm{ name: 'AES-CBC', length: 256 })
	key.set_usages([.wrap_key])
	assert runtime.evaluate_host('nativeKey.algorithm!==originalAlgorithm&&nativeKey.algorithm.name==="AES-CBC"&&nativeKey.algorithm.length===256&&nativeKey.usages===originalUsages&&nativeKey.usages.join(",")==="decrypt,encrypt"')! == 'true'
}

fn test_native_crypto_key_algorithm_shapes_and_real_public_exponent_array() {
	$if !darwin {
		return
	}
	mut runtime, _ := crypto_key_host_fixture('https://key-algorithms.example/')
	defer { runtime.close() }
	algorithms := [
		webcrypto.CryptoKeyAlgorithm(webcrypto.KeyAlgorithm{ name: 'Ed25519' }),
		webcrypto.RsaKeyAlgorithm{ name: 'RSA', modulus_length: 1024, public_exponent: [
			u8(1),
			0,
			1,
		] },
		webcrypto.RsaHashedKeyAlgorithm{ name: 'RSA-PSS', modulus_length: 2048, public_exponent: [
			u8(1),
			0,
			1,
		], hash: 'SHA-256' },
		webcrypto.EcKeyAlgorithm{ name: 'ECDSA', named_curve: 'P-256' },
		webcrypto.AesKeyAlgorithm{ name: 'AES-GCM', length: 128 },
		webcrypto.HmacKeyAlgorithm{ name: 'HMAC', length: 512, hash: 'SHA-384' },
		webcrypto.KmacKeyAlgorithm{ name: 'KMAC128', length: 256 },
	]
	for index, algorithm in algorithms {
		key := webcrypto.CryptoKey.create(.public_key, false, algorithm, [.verify], []u8{})
		crypto_key_test_expose(mut runtime, '__algorithmKey${index}', key)!
	}
	assert runtime.evaluate_host(r'(function(){
 const keys=[__algorithmKey0(),__algorithmKey1(),__algorithmKey2(),__algorithmKey3(),__algorithmKey4(),__algorithmKey5(),__algorithmKey6()],alg=keys.map(key=>key.algorithm);
 const exponent=alg[2].publicExponent;exponent[0]=7;
 return keys.every(key=>key.type==="public"&&key.extractable===false)&&Object.keys(alg[0]).join(",")==="name"&&alg[1].name==="RSA"&&alg[1].modulusLength===1024&&alg[1].publicExponent instanceof Uint8Array&&alg[1].publicExponent.join(",")==="1,0,1"&&alg[2].name==="RSA-PSS"&&alg[2].modulusLength===2048&&alg[2].hash.name==="SHA-256"&&alg[2].hash===keys[2].algorithm.hash&&keys[2].algorithm.publicExponent===exponent&&exponent.join(",")==="7,0,1"&&alg[3].namedCurve==="P-256"&&alg[4].length===128&&alg[5].hash.name==="SHA-384"&&alg[5].length===512&&alg[6].length===256;
 })()')! == 'true'
}

fn test_native_crypto_key_getters_create_data_properties_without_author_setters_or_freeze_hooks() {
	$if !darwin {
		return
	}
	mut runtime, _ := crypto_key_host_fixture('https://key-properties.example/')
	defer { runtime.close() }
	key := webcrypto.CryptoKey.create(.private_key, true, webcrypto.EcKeyAlgorithm{ name: 'ECDH', named_curve: 'P-384' }, [.derive_bits], []u8{})
	crypto_key_test_expose(mut runtime, '__propertyKey', key)!
	assert runtime.evaluate_host(r'(function(){
 const key=__propertyKey(),freeze=Object.freeze,define=Object.defineProperty;let calls=0;
 define(Object.prototype,"name",{set(){calls++;throw "author setter"},configurable:true});define(Object.prototype,"namedCurve",{set(){calls++;throw "author setter"},configurable:true});Object.freeze=function(){calls++;throw "author freeze"};Object.defineProperty=function(){calls++;throw "author define"};
 let algorithm,usages;try{algorithm=key.algorithm;usages=key.usages}finally{delete Object.prototype.name;delete Object.prototype.namedCurve;Object.freeze=freeze;Object.defineProperty=define}
 return calls===0&&key.type==="private"&&algorithm.name==="ECDH"&&algorithm.namedCurve==="P-384"&&Object.getOwnPropertyDescriptor(algorithm,"name").writable&&Object.getOwnPropertyDescriptor(algorithm,"name").enumerable&&Object.getOwnPropertyDescriptor(algorithm,"name").configurable&&Object.isFrozen(usages)&&usages[0]==="deriveBits";
 })()')! == 'true'
}

fn test_native_crypto_key_cache_ownership_and_secure_exposure_follow_actual_globals() {
	$if !darwin {
		return
	}
	mut first, first_host := crypto_key_host_fixture('https://first-key.example/')
	defer { first.close() }
	mut second, second_host := crypto_key_host_fixture('https://second-key.example/')
	defer { second.close() }
	mut insecure, _ := crypto_key_host_fixture('http://insecure-key.example/')
	defer { insecure.close() }
	key := webcrypto.CryptoKey.create(.secret, true, webcrypto.HmacKeyAlgorithm{ name: 'HMAC', hash: 'SHA-256', length: 256 }, [.sign], []u8{len: 32})
	first_wrapper := crypto_key_test_expose(mut first, '__ownedKey', key)!
	second_wrapper := crypto_key_test_expose(mut second, '__ownedKey', key)!
	assert first_wrapper != second_wrapper
	assert first.context != second.context
	assert first_host.settings.realm() != second_host.settings.realm()
	assert voidptr(first.native_crypto_key(first_wrapper)!) == voidptr(second.native_crypto_key(second_wrapper)!)
	first.evaluate_host('__ownedKey().algorithm.name="first owner mutation"')!
	assert second.evaluate_host('__ownedKey().algorithm.name==="HMAC"&&__ownedKey().usages[0]==="sign"')! == 'true'
	assert insecure.evaluate_host('typeof CryptoKey==="undefined"')! == 'true'
	if _ := insecure.javascript_crypto_key(key) {
		assert false
	} else {
		assert err.msg().contains('unavailable')
	}
}
