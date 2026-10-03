module webcrypto

import libjs

fn test_source_algorithm_object_properties_keep_raw_utf16_name_hash_curve_and_cache_ids() {
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	other := libjs.utf16_string_from_code_units([u16(0xdc00), 0])
	for algorithm in [
		CryptoKeyAlgorithm(KeyAlgorithm{ name: name.str(), name_utf16_: name }),
		CryptoKeyAlgorithm(RsaHashedKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: other.str(), hash_utf16_: other }),
		CryptoKeyAlgorithm(HmacKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: other.str(), hash_utf16_: other }),
		CryptoKeyAlgorithm(EcKeyAlgorithm{ name: name.str(), name_utf16_: name, named_curve: other.str(), named_curve_utf16_: other }),
	] {
		mut key := CryptoKey.create(.secret, false, algorithm, [], [])
		first := key.algorithm_for_realm('raw-source-realm')!
		assert first.object_value['name'].string_utf16().code_units() == name.code_units()
		assert key.algorithm_for_realm('raw-source-realm')!.opaque_id == first.opaque_id
		if algorithm is RsaHashedKeyAlgorithm || algorithm is HmacKeyAlgorithm {
			assert first.object_value['hash'].object_value['name'].string_utf16().code_units() == other.code_units()
		}
		if algorithm is EcKeyAlgorithm {
			assert first.object_value['namedCurve'].string_utf16().code_units() == other.code_units()
		}
		key.set_algorithm(KeyAlgorithm{ name: 'new source algorithm' })
		replacement := key.algorithm_for_realm('raw-source-realm')!
		assert replacement.opaque_id != first.opaque_id
		assert replacement.object_value['name'].string_utf16().str() == 'new source algorithm'
	}
}
