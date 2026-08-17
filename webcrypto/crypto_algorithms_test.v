module webcrypto

import encoding.hex

fn must_hex(value string) []u8 {
	return hex.decode(value) or { panic(err) }
}

fn test_digest_known_vectors_and_case_insensitive_normalization() {
	subtle_crypto := SubtleCrypto.create()
	assert subtle_crypto.digest('sha-256', 'abc'.bytes())!.hex() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
	assert subtle_crypto.digest('SHA3-256', 'abc'.bytes())!.hex() == '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532'
	if _ := subtle_crypto.digest('MD5', []) {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
}

fn test_aes_ctr_nist_vector() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw, must_hex('2b7e151628aed2a6abf7158809cf4f3c'), 'AES-CTR',
		false, [.encrypt, .decrypt], '')!
	params := AesCtrParams{
		counter: must_hex('f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff')
		length:  128
	}
	plaintext := must_hex('6bc1bee22e409f96e93d7e117393172a')
	ciphertext := subtle_crypto.encrypt(params, key, plaintext)!
	assert ciphertext.hex() == '874d6191b620e3261bef6864990db6ce'
	assert subtle_crypto.decrypt(params, key, ciphertext)! == plaintext
}

fn test_aes_cbc_round_trip_and_padding_validation() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw, must_hex('2b7e151628aed2a6abf7158809cf4f3c'), 'AES-CBC',
		false, [.encrypt, .decrypt], '')!
	params := AesCbcParams{
		iv: must_hex('000102030405060708090a0b0c0d0e0f')
	}
	plaintext := 'CBC uses WebCrypto PKCS#7 padding.'.bytes()
	ciphertext := subtle_crypto.encrypt(params, key, plaintext)!
	assert ciphertext.len % 16 == 0
	assert subtle_crypto.decrypt(params, key, ciphertext)! == plaintext
	mut corrupted := ciphertext.clone()
	corrupted[corrupted.len - 1] ^= 1
	if _ := subtle_crypto.decrypt(params, key, corrupted) {
		assert false
	} else {
		assert err.msg().starts_with('OperationError:')
	}
}

fn test_aes_gcm_nist_vector_and_authentication_failure() {
	subtle_crypto := SubtleCrypto.create()
	key :=
		subtle_crypto.import_key(.raw, []u8{len: 16}, 'AES-GCM', false, [.encrypt, .decrypt], '')!
	params := AesGcmParams{
		iv: []u8{len: 12}
	}
	ciphertext := subtle_crypto.encrypt(params, key, []u8{len: 16})!
	assert ciphertext.hex() == '0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf'
	assert subtle_crypto.decrypt(params, key, ciphertext)! == []u8{len: 16}
	mut corrupted := ciphertext.clone()
	corrupted[0] ^= 1
	if _ := subtle_crypto.decrypt(params, key, corrupted) {
		assert false
	} else {
		assert err.msg() == 'OperationError: AES-GCM authentication failed'
	}
}

fn test_aes_gcm_accepts_general_iv_and_spec_tag_lengths() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw, []u8{len: 24, init: 0x5a}, 'AES-GCM', false, [
		.encrypt,
		.decrypt,
	], '')!
	params := AesGcmParams{
		iv:              'non-96-bit-iv'.bytes()
		additional_data: 'associated'.bytes()
		tag_length:      64
	}
	plaintext := 'authenticated plaintext'.bytes()
	ciphertext := subtle_crypto.encrypt(params, key, plaintext)!
	assert ciphertext.len == plaintext.len + 8
	assert subtle_crypto.decrypt(params, key, ciphertext)! == plaintext
	mut corrupted := ciphertext.clone()
	corrupted[corrupted.len - 1] ^= 1
	if _ := subtle_crypto.decrypt(params, key, corrupted) {
		assert false
	} else {
		assert err.msg().contains('authentication failed')
	}
}

fn test_chacha20_poly1305_rfc_vector() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw,
		must_hex('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f'),
		'ChaCha20-Poly1305', false, [.encrypt, .decrypt], '')!
	params := AeadParams{
		name:            'ChaCha20-Poly1305'
		iv:              must_hex('a0a1a2a31011121314151617')
		additional_data: must_hex('c0c1c2c3c4c5c6c7d0d1d2d3d4d5d6d72e202500000000090000004529000029')
	}
	plaintext := must_hex('0000000c000040010000000a00')
	ciphertext := subtle_crypto.encrypt(params, key, plaintext)!
	assert ciphertext.hex() == '610394701f8d017f7c129248896b71bfe25236efd7cdc67066906315b2'
	assert subtle_crypto.decrypt(params, key, ciphertext)! == plaintext
}

fn test_hmac_sha256_rfc_4231_vector_and_usage_checks() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw, []u8{len: 20, init: 0x0b}, 'HMAC', false, [
		.sign,
		.verify,
	], 'SHA-256')!
	signature := subtle_crypto.sign('hmac', key, 'Hi There'.bytes())!
	assert signature.hex() == 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7'
	assert subtle_crypto.verify('HMAC', key, signature, 'Hi There'.bytes())!
	assert !subtle_crypto.verify('HMAC', key, signature, 'Not it'.bytes())!

	verify_only := subtle_crypto.import_key(.raw, [u8(1), 2, 3], 'HMAC', false, [
		.verify,
	], 'SHA-256')!
	if _ := subtle_crypto.sign('HMAC', verify_only, []) {
		assert false
	} else {
		assert err.msg().contains('does not support sign')
	}
}

fn test_hkdf_rfc_5869_vector() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw, []u8{len: 22, init: 0x0b}, 'HKDF', false, [
		.derive_bits,
	], '')!
	params := HkdfParams{
		hash: 'SHA-256'
		salt: must_hex('000102030405060708090a0b0c')
		info: must_hex('f0f1f2f3f4f5f6f7f8f9')
	}
	derived := subtle_crypto.derive_bits(params, key, 42 * 8)!
	assert derived.hex() == '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865'
}

fn test_pbkdf2_sha1_rfc_6070_vector() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_key(.raw, 'password'.bytes(), 'PBKDF2', false, [
		.derive_bits,
	], '')!
	params := Pbkdf2Params{
		hash:       'SHA-1'
		salt:       'salt'.bytes()
		iterations: 1
	}
	assert subtle_crypto.derive_bits(params, key, 160)!.hex() == '0c60c80f961f0e71f3a9b524af6012062fe037a6'
}

fn test_ed25519_rfc_8032_seed_sign_and_verify() {
	subtle_crypto := SubtleCrypto.create()
	seed := must_hex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')
	private_key := subtle_crypto.import_key(.raw_seed, seed, 'Ed25519', true, [.sign], '')!
	public_key := subtle_crypto.import_key(.raw_public,
		must_hex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'), 'Ed25519',
		true, [.verify], '')!
	signature := subtle_crypto.sign('Ed25519', private_key, [])!
	assert signature.hex() == 'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
	assert subtle_crypto.verify('Ed25519', public_key, signature, [])!
	assert subtle_crypto.export_key(.raw_seed, private_key)! == seed
}

fn test_key_generation_and_invalid_usages() {
	subtle_crypto := SubtleCrypto.create()
	generated := subtle_crypto.generate_key(AesKeyGenParams{
		name:   'AES-GCM'
		length: 256
	}, true, [.encrypt, .decrypt])!
	key := generated.key or { panic('missing generated key') }
	assert key.algorithm_name() == 'AES-GCM'
	assert key.handle().len == 32
	assert key.extractable
	if _ := subtle_crypto.generate_key(AesKeyGenParams{
		name:   'AES-GCM'
		length: 128
	}, true, [.sign])
	{
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
}

fn test_aes_kw_rfc_3394_vector_and_integrity_check() {
	subtle_crypto := SubtleCrypto.create()
	wrapping_key := subtle_crypto.import_key(.raw, must_hex('000102030405060708090a0b0c0d0e0f'),
		'AES-KW', false, [.wrap_key, .unwrap_key], '')!
	key_to_wrap := subtle_crypto.import_key(.raw, must_hex('00112233445566778899aabbccddeeff'),
		'AES-GCM', true, [.encrypt], '')!
	wrapped := subtle_crypto.wrap_key(.raw, key_to_wrap, wrapping_key, 'AES-KW')!
	assert wrapped.hex() == '1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5'
	unwrapped := subtle_crypto.unwrap_key(.raw, wrapped, wrapping_key, 'AES-KW', 'AES-GCM', true, [
		.encrypt,
	], '')!
	assert unwrapped.handle() == key_to_wrap.handle()
	mut corrupted := wrapped.clone()
	corrupted[0] ^= 1
	if _ := subtle_crypto.unwrap_key(.raw, corrupted, wrapping_key, 'AES-KW', 'AES-GCM', true, [
		.encrypt,
	], '')
	{
		assert false
	} else {
		assert err.msg().contains('integrity')
	}
}
