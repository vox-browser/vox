module webcrypto

import libjs

fn test_source_internal_crypto_algorithm_utf16_names_survive_all_record_copies() {
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00, 0x41])
	algorithms := [
		CryptoKeyAlgorithm(KeyAlgorithm{ name: name.str(), name_utf16_: name }),
		CryptoKeyAlgorithm(RsaKeyAlgorithm{ name: name.str(), name_utf16_: name, public_exponent: [u8(3)] }),
		CryptoKeyAlgorithm(RsaHashedKeyAlgorithm{ name: name.str(), name_utf16_: name }),
		CryptoKeyAlgorithm(EcKeyAlgorithm{ name: name.str(), name_utf16_: name }),
		CryptoKeyAlgorithm(AesKeyAlgorithm{ name: name.str(), name_utf16_: name }),
		CryptoKeyAlgorithm(HmacKeyAlgorithm{ name: name.str(), name_utf16_: name }),
		CryptoKeyAlgorithm(KmacKeyAlgorithm{ name: name.str(), name_utf16_: name }),
	]
	for algorithm in algorithms {
		key := CryptoKey.create(.secret, false, algorithm, [], [])
		assert key.internal_algorithm().name_utf16().code_units() == name.code_units()
		assert key.clone_key().internal_algorithm().name_utf16().code_units() == name.code_units()
	}
}

fn test_source_internal_crypto_hash_curve_utf16_and_compatibility_setters() {
	text := libjs.utf16_string_from_code_units([u16(0xdc00), 0, 0xd801])
	mut rsa := RsaHashedKeyAlgorithm{ hash: text.str(), hash_utf16_: text }
	mut hmac := HmacKeyAlgorithm{ hash: text.str(), hash_utf16_: text }
	mut ec := EcKeyAlgorithm{ named_curve: text.str(), named_curve_utf16_: text }
	assert rsa.hash_utf16().code_units() == text.code_units()
	assert hmac.hash_utf16().code_units() == text.code_units()
	assert CryptoKeyAlgorithm(rsa.hash_algorithm()).name_utf16().code_units() == text.code_units()
	assert CryptoKeyAlgorithm(hmac.hash_algorithm()).name_utf16().code_units() == text.code_units()
	assert ec.named_curve_utf16().code_units() == text.code_units()
	for algorithm in [CryptoKeyAlgorithm(rsa), CryptoKeyAlgorithm(hmac), CryptoKeyAlgorithm(ec)] {
		copy := clone_key_algorithm(algorithm)
		match copy {
			RsaHashedKeyAlgorithm {
				assert copy.hash_utf16().code_units() == text.code_units()
			}
			HmacKeyAlgorithm {
				assert copy.hash_utf16().code_units() == text.code_units()
			}
			EcKeyAlgorithm {
				assert copy.named_curve_utf16().code_units() == text.code_units()
			}
			else {
				assert false
			}
		}
	}
	rsa.set_hash('SHA-512')
	hmac.set_hash('SHA-256')
	ec.set_named_curve('P-384')
	assert rsa.hash_utf16_ == none && rsa.hash_utf16().str() == 'SHA-512'
	assert hmac.hash_utf16_ == none && hmac.hash_utf16().str() == 'SHA-256'
	assert ec.named_curve_utf16_ == none && ec.named_curve_utf16().str() == 'P-384'
	mut aes := AesKeyAlgorithm{ name: text.str(), name_utf16_: text }
	aes.name = 'AES-GCM'
	assert CryptoKeyAlgorithm(aes).name_utf16().str() == 'AES-GCM'
	aes.set_name('AES-CBC')
	assert aes.name_utf16_ == none && CryptoKeyAlgorithm(aes).name_utf16().str() == 'AES-CBC'
}
