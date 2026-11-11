// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_native_hkdf_source_rfc5869_vectors_present_salt() {
	key1 := SubtleCrypto.create().import_key(.raw, hex.decode('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b')!, 'HKDF', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(HkdfParams{ hash: 'SHA-256', salt: hex.decode('000102030405060708090a0b0c')!, info: hex.decode('f0f1f2f3f4f5f6f7f8f9')! }, key1, 336)!.hex() == '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865'
	key2 := SubtleCrypto.create().import_key(.raw, hex.decode('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f')!, 'HKDF', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(HkdfParams{ hash: 'SHA-256', salt: hex.decode('606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeaf')!, info: hex.decode('b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff')! }, key2, 656)!.hex() == 'b11e398dc80327a1c8e7f78c596a49344f012eda2d4efad8a050cc4c19afa97c59045a99cac7827271cb41c65e590e09da3275600c2f09b8367793a9aca3db71cc30c58179ec3e87c14c01d5c1f3434f1d87'
	key3 := SubtleCrypto.create().import_key(.raw, hex.decode('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b')!, 'HKDF', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(HkdfParams{ hash: 'SHA-256', salt: hex.decode('')!, info: hex.decode('')! }, key3, 336)!.hex() == '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8'
	key4 := SubtleCrypto.create().import_key(.raw, hex.decode('0b0b0b0b0b0b0b0b0b0b0b')!, 'HKDF', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(HkdfParams{ hash: 'SHA-1', salt: hex.decode('000102030405060708090a0b0c')!, info: hex.decode('f0f1f2f3f4f5f6f7f8f9')! }, key4, 336)!.hex() == '085a01ea1b10f36933068b56efa5ad81a4f14b822f5b091568a9cdd4f155fda2c22e422478d305f3f896'
	key5 := SubtleCrypto.create().import_key(.raw, hex.decode('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f')!, 'HKDF', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(HkdfParams{ hash: 'SHA-1', salt: hex.decode('606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeaf')!, info: hex.decode('b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff')! }, key5, 656)!.hex() == '0bd770a74d1160f7c9f12cd5912a06ebff6adcae899d92191fe4305673ba2ffe8fa3f1a4e5ad79f3f334b3b202b2173c486ea37ce3d397ed034c7f9dfeb15c5e927336d0441f4c4300e2cff0d0900b52d3b4'
	key6 := SubtleCrypto.create().import_key(.raw, hex.decode('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b')!, 'HKDF', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(HkdfParams{ hash: 'SHA-1', salt: hex.decode('')!, info: hex.decode('')! }, key6, 336)!.hex() == '0ac1af7002b3d761d1e55298da9d0506b9ae52057220a306e07b6b87e8df21d0ea00033de03984d34918'
}

fn test_native_pbkdf2_source_vectors_with_nul_and_multiblock_output() {
	key0 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('70617373776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-1', salt: hex.decode('73616c74')!, iterations: 1 }, key0, 160)!.hex() == '0c60c80f961f0e71f3a9b524af6012062fe037a6'
	key1 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('70617373776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-1', salt: hex.decode('73616c74')!, iterations: 2 }, key1, 160)!.hex() == 'ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957'
	key2 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('70617373776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-256', salt: hex.decode('73616c74')!, iterations: 1 }, key2, 160)!.hex() == '120fb6cffcf8b32c43e7225256c4f837a86548c9'
	key3 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('70617373776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-256', salt: hex.decode('73616c74')!, iterations: 2 }, key3, 160)!.hex() == 'ae4d0c95af6b46d32d0adff928f06dd02a303f8e'
	key4 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('70617373776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-256', salt: hex.decode('73616c74')!, iterations: 4096 }, key4, 160)!.hex() == 'c5e478d59288c841aa530db6845c4c8d962893a0'
	key5 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('70617373776f726450415353574f524470617373776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-256', salt: hex.decode('73616c7453414c5473616c7453414c5473616c7453414c5473616c7453414c5473616c74')!, iterations: 4096 }, key5, 200)!.hex() == '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c'
	key6 := SubtleCrypto.create().import_key(.raw_secret, hex.decode('7061737300776f7264')!, 'PBKDF2', false, [.derive_bits], '')!
	assert SubtleCrypto.create().derive_bits(Pbkdf2Params{ hash: 'SHA-256', salt: hex.decode('7361006c74')!, iterations: 4096 }, key6, 128)!.hex() == '89b69d0516f829893c696226650a8687'
}

fn test_kdf_source_validation_order_zero_absent_and_provider_failure() {
	key := CryptoKey.create(.secret, false, KeyAlgorithm{ name: 'HKDF' }, [], [])
	hkdf := HkdfParams{ hash: 'bad' }
	if _ := HKDF.create().derive_bits(hkdf, key, 0) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'bad'"
	}
	assert HKDF.create().derive_bits(HkdfParams{ hash: 'SHA-256' }, key, 0)!.len == 0
	if _ := HKDF.create().derive_bits(hkdf, key, none) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length must be specified and divisible by 8'
	}
	if _ := HKDF.create().derive_bits(hkdf, key, 1) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length must be specified and divisible by 8'
	}
	if _ := HKDF.create().derive_bits(hkdf, key, 8) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'bad'"
	}
	if _ := HKDF.create().derive_bits(HkdfParams{ hash: 'SHA-1' }, key, 255 * 20 * 8 + 8) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length is too large for the hash function'
	}
	pbkdf := Pbkdf2Params{ hash: 'bad' }
	if _ := PBKDF2.create().derive_bits(pbkdf, key, none) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length must be greater than 0 and divisible by 8'
	}
	if _ := PBKDF2.create().derive_bits(pbkdf, key, 0) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Iterations must be greater than 0'
	}
	if _ := PBKDF2.create().derive_bits(Pbkdf2Params{ ...pbkdf, iterations: 1 }, key, 8) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'bad'"
	}
	// The source calls EVP for zero PBKDF2 output; the installed provider accepts it.
	assert PBKDF2.create().derive_bits(Pbkdf2Params{ hash: 'SHA-256', iterations: 1 }, key, 0)!.len == 0
	assert HKDF.create().import_key(AlgorithmParams{}, .raw, [], false, [])!.usages.len == 0
	assert PBKDF2.create().import_key(AlgorithmParams{}, .raw_secret, [], false, [])!.handle().len == 0
	if _ := HKDF.create().import_key(AlgorithmParams{}, .jwk, [], true, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Only raw format is supported'
	}
	if _ := PBKDF2.create().import_key(AlgorithmParams{}, .raw, [], true, [.sign]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	if _ := PBKDF2.create().import_key(AlgorithmParams{}, .raw, [], true, [.derive_bits]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: extractable must be false'
	}
}

@[heap]
struct KdfBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_kdf_deferred_copy_validation_and_zero_hkdf_settlement() {
	mut host := &KdfBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	key := subtle.import_key(.raw, 'password'.bytes(), 'PBKDF2', false, [.derive_bits], '')!
	mut salt := webidl.BufferSource.array_buffer('salt'.bytes())
	algorithm := webidl.object_value({
		'name':       webidl.string_value('PBKDF2')
		'hash':       webidl.string_value('SHA-256')
		'salt':       webidl.buffer_source_value(salt)
		'iterations': webidl.number_value(1)
	})
	promise := binding.derive_bits(algorithm, key, 160)
	salt.write('bad!'.bytes(), 0)!
	assert promise.state == .pending
	host.work[0]()
	assert promise.state == .fulfilled && host.settle.len == 0
	bytes := promise.result.buffer_value or { panic('bytes') }
	assert webidl.get_buffer_source_copy(bytes).hex() == '120fb6cffcf8b32c43e7225256c4f837a86548c9'
	hkdf_key := subtle.import_key(.raw, [], 'HKDF', false, [.derive_bits], '')!
	hkdf_algorithm := webidl.object_value({
		'name': webidl.string_value('HKDF')
		'hash': webidl.string_value('SHA-256')
		'salt': webidl.buffer_source_value(webidl.BufferSource.array_buffer([]))
		'info': webidl.buffer_source_value(webidl.BufferSource.array_buffer([]))
	})
	zero := binding.derive_bits(hkdf_algorithm, hkdf_key, 0)
	absent := binding.derive_bits(hkdf_algorithm, hkdf_key, none)
	assert zero.state == .pending && absent.state == .pending
	host.work[1]()
	assert zero.state == .fulfilled && (zero.result.buffer_value or { panic('zero bytes') }).byte_length() == 0
	host.work[2]()
	assert absent.state == .rejected && absent.result.object_value['message'].string_value == 'Length must be specified and divisible by 8'
}
