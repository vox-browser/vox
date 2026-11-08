module webcrypto

fn test_subtle_crypto_operation_registry_matches_upstream() {
	expected := {
		'encrypt':        ['RSA-OAEP', 'AES-CTR', 'AES-CBC', 'AES-GCM', 'ChaCha20-Poly1305',
			'AES-OCB']
		'decrypt':        ['RSA-OAEP', 'AES-CTR', 'AES-CBC', 'AES-GCM', 'ChaCha20-Poly1305',
			'AES-OCB']
		'sign':           ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'ECDSA', 'HMAC', 'Ed25519', 'Ed448',
			'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'KMAC128', 'KMAC256']
		'verify':         ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'ECDSA', 'HMAC', 'Ed25519', 'Ed448',
			'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'KMAC128', 'KMAC256']
		'digest':         ['SHA-1', 'SHA-256', 'SHA-384', 'SHA-512', 'SHA3-256', 'SHA3-384',
			'SHA3-512', 'cSHAKE128', 'cSHAKE256']
		'deriveBits':     ['ECDH', 'HKDF', 'PBKDF2', 'X25519', 'X448', 'Argon2d', 'Argon2i',
			'Argon2id']
		'wrapKey':        ['AES-KW']
		'unwrapKey':      ['AES-KW']
		'generateKey':    ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
			'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'X25519', 'X448', 'Ed25519', 'Ed448', 'ML-DSA-44',
			'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'ChaCha20-Poly1305',
			'AES-OCB', 'KMAC128', 'KMAC256']
		'importKey':      ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
			'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2', 'X25519', 'X448', 'Ed25519',
			'Ed448', 'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024',
			'Argon2d', 'Argon2i', 'Argon2id', 'ChaCha20-Poly1305', 'AES-OCB', 'KMAC128', 'KMAC256']
		'exportKey':      ['RSASSA-PKCS1-v1_5', 'RSA-PSS', 'RSA-OAEP', 'ECDSA', 'ECDH', 'AES-CTR',
			'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'X25519', 'X448', 'Ed25519', 'Ed448', 'ML-DSA-44',
			'ML-DSA-65', 'ML-DSA-87', 'ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 'ChaCha20-Poly1305',
			'AES-OCB', 'KMAC128', 'KMAC256']
		'get key length': ['AES-CTR', 'AES-CBC', 'AES-GCM', 'AES-KW', 'HMAC', 'HKDF', 'PBKDF2',
			'Argon2d', 'Argon2i', 'Argon2id', 'ChaCha20-Poly1305', 'AES-OCB', 'KMAC128', 'KMAC256']
		'encapsulate':    ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']
		'decapsulate':    ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']
	}
	for operation, algorithms in expected {
		assert supported_algorithms_for_operation(operation) == algorithms
	}
	assert supported_algorithms_for_operation('unknown').len == 0

	// Callers cannot mutate the registry's backing lists.
	mut returned := supported_algorithms_for_operation('digest')
	returned.clear()
	assert supported_algorithms_for_operation('digest') == expected['digest']
}

fn test_algorithm_normalization_is_case_insensitive_and_operation_specific() {
	assert normalize_an_algorithm('sha-256', 'digest')! == 'SHA-256'
	assert normalize_an_algorithm('CsHaKe128', 'digest')! == 'cSHAKE128'
	assert normalize_an_algorithm('aes-gcm', 'encrypt')! == 'AES-GCM'
	assert normalize_an_algorithm('ml-kem-768', 'decapsulate')! == 'ML-KEM-768'
	assert canonical_algorithm_name('rSaSsA-pKcS1-V1_5')! == 'RSASSA-PKCS1-v1_5'

	if _ := normalize_an_algorithm('SHA-256', 'encrypt') {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
	if _ := normalize_an_algorithm('AES-GCM', 'not-an-operation') {
		assert false
	} else {
		assert err.msg().contains("operation 'not-an-operation'")
	}
}

fn test_subtle_crypto_normalizes_usages_and_operation_access_is_checked() {
	key := CryptoKey.create(.secret, true, AesKeyAlgorithm{
		name:   'AES-GCM'
		length: 128
	}, [.encrypt, .decrypt], []u8{len: 16})
	assert key.usages == [KeyUsage.encrypt, .decrypt]
	assert key.permits(.encrypt)
	assert !key.permits(.sign)

	subtle_crypto := SubtleCrypto.create()
	imported := subtle_crypto.import_key(.raw, []u8{len: 16}, 'AES-GCM', true, [
		.decrypt,
		.encrypt,
		.decrypt,
	], '')!
	// The normalized usage intersection is an ordered set.
	assert imported.usages == [KeyUsage.encrypt, .decrypt]

	if _ := subtle_crypto.encrypt(AesCbcParams{
		iv: []u8{len: 16}
	}, key, [])
	{
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Algorithm mismatch'
	}

	decrypt_only := CryptoKey.create(.secret, true, AesKeyAlgorithm{
		name:   'AES-GCM'
		length: 128
	}, [.decrypt], []u8{len: 16})
	if _ := subtle_crypto.encrypt(AesGcmParams{
		iv: []u8{len: 12}
	}, decrypt_only, [])
	{
		assert false
	} else {
		assert err.msg().contains('does not support encrypt')
	}
}

fn test_export_checks_registry_and_extractability() {
	subtle_crypto := SubtleCrypto.create()
	extractable := CryptoKey.create(.secret, true, AesKeyAlgorithm{
		name:   'AES-GCM'
		length: 128
	}, [.encrypt], []u8{len: 16, init: 7})
	assert subtle_crypto.export_key(.raw, extractable)! == []u8{len: 16, init: 7}

	non_extractable := CryptoKey.create(.secret, false, AesKeyAlgorithm{
		name:   'AES-GCM'
		length: 128
	}, [.encrypt], []u8{len: 16})
	if _ := subtle_crypto.export_key(.raw, non_extractable) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not extractable'
	}

	unregistered := CryptoKey.create(.secret, true, KeyAlgorithm{
		name: 'Unregistered'
	}, [], [u8(1)])
	if _ := subtle_crypto.export_key(.raw, unregistered) {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
}

fn test_symmetric_jwk_import_validates_key_type_extractability_and_requested_operations() {
	subtle_crypto := SubtleCrypto.create()
	material := []u8{len: 16, init: 0xa5}
	key := subtle_crypto.import_jwk(JsonWebKey{
		kty:     'oct'
		use:     'enc'
		key_ops: ['encrypt', 'decrypt']
		alg:     'A128GCM'
		ext:     true
		k:       base64url_encode(material)
	}, 'aes-gcm', true, [.encrypt], '')!
	assert key.type_ == .secret
	assert key.extractable
	assert key.algorithm_name() == 'AES-GCM'
	assert key.usages == [.encrypt]
	assert key.handle() == material
	exported := subtle_crypto.export_jwk(key)!
	assert exported.kty or { panic('missing kty') } == 'oct'
	assert base64url_decode(exported.k or { panic('missing k') })! == material
	assert exported.key_ops or { panic('missing key_ops') } == ['encrypt']
	assert exported.ext or { false }

	if _ := subtle_crypto.import_jwk(JsonWebKey{
		kty: 'oct'
        alg: 'A128GCM'
		ext: false
		k:   base64url_encode(material)
	}, 'AES-GCM', true, [.encrypt], '')
	{
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid ext field'
	}
	if _ := subtle_crypto.import_jwk(JsonWebKey{
		kty:     'oct'
        alg: 'A128GCM'
		key_ops: ['decrypt']
		k:       base64url_encode(material)
	}, 'AES-GCM', false, [.encrypt], '')
	{
		assert false
	} else {
		assert err.msg().starts_with('DataError: Missing key_ops usage: ')
	}
	if _ := subtle_crypto.import_jwk(JsonWebKey{
		kty: 'RSA'
		k:   base64url_encode(material)
	}, 'AES-GCM', false, [.encrypt], '')
	{
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key type'
	}
}

fn test_ed25519_jwk_import_covers_public_and_private_material() {
	subtle_crypto := SubtleCrypto.create()
	public_material := []u8{len: 32, init: 3}
	public_key := subtle_crypto.import_jwk(JsonWebKey{
		kty:     'OKP'
		use:     'sig'
		key_ops: ['verify']
		alg:     'EdDSA'
		ext:     true
		crv:     'Ed25519'
		x:       base64url_encode(public_material)
	}, 'Ed25519', true, [.verify], '')!
	assert public_key.type_ == .public_key
	assert public_key.algorithm_name() == 'Ed25519'
	assert public_key.usages == [.verify]
	assert public_key.handle() == public_material
	exported_public := subtle_crypto.export_jwk(public_key)!
	assert exported_public.kty or { panic('missing kty') } == 'OKP'
	assert exported_public.crv or { panic('missing crv') } == 'Ed25519'
	assert base64url_decode(exported_public.x or { panic('missing x') })! == public_material

	seed := []u8{len: 32, init: 9}
	private_public_material := ed25519_public_key_from_seed(seed)!
	private_key := subtle_crypto.import_jwk(JsonWebKey{
		kty:     'OKP'
		key_ops: ['sign']
		crv:     'Ed25519'
		x:       base64url_encode(private_public_material)
		d:       base64url_encode(seed)
	}, 'ed25519', true, [.sign], '')!
	assert private_key.type_ == .private_key
	assert private_key.algorithm_name() == 'Ed25519'
	assert private_key.usages == [.sign]
	assert private_key.handle().len == 32

	if _ := subtle_crypto.import_jwk(JsonWebKey{
		kty: 'OKP'
		crv: 'X25519'
		x:   base64url_encode(public_material)
	}, 'Ed25519', true, [.verify], '')
	{
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid curve'
	}
}
