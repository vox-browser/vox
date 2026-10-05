module browserjs

import dom
import libjs
import webcrypto

fn raw_crypto_key_host_fixture(address string) (&Runtime, &CryptoHost) {
	url := dom.URL{value: address}
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{url: url, origin_: url.origin()}) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime, host
}

fn raw_crypto_key_expose(mut runtime Runtime, name string, key &webcrypto.CryptoKey) !voidptr {
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	return wrapper
}

fn test_native_crypto_key_algorithm_getters_preserve_actual_raw_utf16_and_mutable_cache_identity() {
	$if !darwin {
		return
	}
	mut runtime, _ := raw_crypto_key_host_fixture('https://raw-crypto-key.example/')
	defer { runtime.close() }
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	other := libjs.utf16_string_from_code_units([u16(0xdc00), 0xd801])
	algorithms := [
		webcrypto.CryptoKeyAlgorithm(webcrypto.KeyAlgorithm{ name: name.str(), name_utf16_: name }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.RsaKeyAlgorithm{ name: name.str(), name_utf16_: name }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.RsaHashedKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: other.str(), hash_utf16_: other }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.EcKeyAlgorithm{ name: name.str(), name_utf16_: name, named_curve: other.str(), named_curve_utf16_: other }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.AesKeyAlgorithm{ name: name.str(), name_utf16_: name }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.HmacKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: other.str(), hash_utf16_: other }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.KmacKeyAlgorithm{ name: name.str(), name_utf16_: name }),
	]
	mut keys := []&webcrypto.CryptoKey{}
	for index, algorithm in algorithms {
		key := webcrypto.CryptoKey.create(.secret, false, algorithm, [], [])
		keys << key
		raw_crypto_key_expose(mut runtime, '__rawAlgorithm${index}', key)!
	}
	assert runtime.evaluate_host(r'(function(){const keys=[__rawAlgorithm0(),__rawAlgorithm1(),__rawAlgorithm2(),__rawAlgorithm3(),__rawAlgorithm4(),__rawAlgorithm5(),__rawAlgorithm6()];const algorithms=keys.map(key=>key.algorithm);return algorithms.every((value,i)=>value.name===String.fromCharCode(0xd800,0)&&keys[i].algorithm===value)&&algorithms[2].hash.name===String.fromCharCode(0xdc00,0xd801)&&algorithms[3].namedCurve===String.fromCharCode(0xdc00,0xd801)&&algorithms[5].hash.name===String.fromCharCode(0xdc00,0xd801)})()')! == 'true'
	assert runtime.evaluate_host(r'{globalThis.__rawCachedAlgorithm=__rawAlgorithm2().algorithm;__rawCachedAlgorithm.name="author name";__rawCachedAlgorithm.hash.name="author hash";__rawAlgorithm2().algorithm===__rawCachedAlgorithm&&__rawAlgorithm2().algorithm.name==="author name"&&__rawAlgorithm2().algorithm.hash.name==="author hash"}')! == 'true'
	assert keys[2].internal_algorithm().name_utf16().code_units() == name.code_units()
	mut key := keys[2]
	key.set_algorithm(webcrypto.RsaHashedKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: other.str(), hash_utf16_: other })
	assert runtime.evaluate_host(r'__rawAlgorithm2().algorithm!==__rawCachedAlgorithm&&__rawAlgorithm2().algorithm.name===String.fromCharCode(0xd800,0)&&__rawAlgorithm2().algorithm.hash.name===String.fromCharCode(0xdc00,0xd801)')! == 'true'
}
