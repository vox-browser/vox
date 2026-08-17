module webcrypto

fn symmetric_jwk(key []u8) JsonWebKey {
	return JsonWebKey{
		kty:     'oct'
		k:       base64url_encode(key)
		alg:     'A128GCM'
		use:     'enc'
		key_ops: ['encrypt']
		ext:     true
	}
}

fn test_symmetric_jwk_metadata_is_validated_and_exported() {
	subtle_crypto := SubtleCrypto.create()
	key := subtle_crypto.import_jwk(symmetric_jwk([]u8{len: 16}), 'AES-GCM', true, [
		.encrypt,
	], '')!
	assert !key.permits(.decrypt)
	exported := subtle_crypto.export_jwk(key)!
	assert exported.kty? == 'oct'
	assert exported.alg? == 'A128GCM'
	assert exported.key_ops? == ['encrypt']
	assert exported.k? == base64url_encode([]u8{len: 16})

	mut wrong_algorithm := symmetric_jwk([]u8{len: 16})
	wrong_algorithm.alg = 'A256GCM'
	if _ := subtle_crypto.import_jwk(wrong_algorithm, 'AES-GCM', true, [.encrypt], '') {
		assert false
	} else {
		assert err.msg().contains('alg contradicts')
	}

	mut wrong_use := symmetric_jwk([]u8{len: 16})
	wrong_use.use = 'sig'
	if _ := subtle_crypto.import_jwk(wrong_use, 'AES-GCM', true, [.encrypt], '') {
		assert false
	} else {
		assert err.msg().contains('use')
	}
}

fn test_jwk_key_ops_duplicates_relationships_and_requested_usages_are_checked() {
	subtle_crypto := SubtleCrypto.create()
	mut duplicate := symmetric_jwk([]u8{len: 16})
	duplicate.key_ops = ['encrypt', 'encrypt']
	if _ := subtle_crypto.import_jwk(duplicate, 'AES-GCM', true, [.encrypt], '') {
		assert false
	} else {
		assert err.msg().contains('Duplicate key operation')
	}

	mut unrelated := symmetric_jwk([]u8{len: 16})
	unrelated.key_ops = ['encrypt', 'sign']
	if _ := subtle_crypto.import_jwk(unrelated, 'AES-GCM', true, [.encrypt], '') {
		assert false
	} else {
		assert err.msg().contains('unrelated')
	}

	if _ := subtle_crypto.import_jwk(symmetric_jwk([]u8{len: 16}), 'AES-GCM', true, [
		.decrypt,
	], '')
	{
		assert false
	} else {
		assert err.msg().contains('absent from JWK key_ops')
	}
}

fn test_ed25519_jwk_requires_public_component_and_honors_extractability() {
	subtle_crypto := SubtleCrypto.create()
	seed := []u8{len: 32, init: 7}
	missing_public := JsonWebKey{
		kty:     'OKP'
		crv:     'Ed25519'
		alg:     'Ed25519'
		d:       base64url_encode(seed)
		use:     'sig'
		key_ops: ['sign']
		ext:     false
	}
	if _ := subtle_crypto.import_jwk(missing_public, 'Ed25519', false, [.sign], '') {
		assert false
	} else {
		assert err.msg().contains('has no x member')
	}

	public_material := []u8{len: 32, init: 9}
	public_jwk := JsonWebKey{
		kty:     'OKP'
		crv:     'Ed25519'
		alg:     'EdDSA'
		x:       base64url_encode(public_material)
		use:     'sig'
		key_ops: ['verify']
		ext:     false
	}
	key := subtle_crypto.import_jwk(public_jwk, 'Ed25519', false, [.verify], '')!
	assert !key.extractable
	assert key.handle() == public_material
}

fn test_derivation_jwk_and_empty_private_or_secret_usages_are_rejected() {
	subtle_crypto := SubtleCrypto.create()
	kdf_jwk := JsonWebKey{
		kty: 'oct'
		k:   base64url_encode('secret'.bytes())
	}
	if _ := subtle_crypto.import_jwk(kdf_jwk, 'PBKDF2', false, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
	if _ := subtle_crypto.import_key(.raw, []u8{len: 16}, 'AES-GCM', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
	if _ := subtle_crypto.import_key(.raw_seed, []u8{len: 32}, 'Ed25519', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
}

fn test_derive_bits_and_derive_key_require_their_exact_usage() {
	subtle_crypto := SubtleCrypto.create()
	derive_key_only := subtle_crypto.import_key(.raw, 'password'.bytes(), 'PBKDF2', false, [
		.derive_key,
	], '')!
	params := Pbkdf2Params{
		hash:       'SHA-256'
		salt:       'salt'.bytes()
		iterations: 2
	}
	if _ := subtle_crypto.derive_bits(params, derive_key_only, 128) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidAccessError:')
	}
	derived := subtle_crypto.derive_key(params, derive_key_only, 'AES-GCM', 128, false, [
		.encrypt,
	])!
	assert derived.algorithm_name() == 'AES-GCM'
	assert derived.handle().len == 16

	derive_bits_only := subtle_crypto.import_key(.raw, 'password'.bytes(), 'PBKDF2', false, [
		.derive_bits,
	], '')!
	if _ := subtle_crypto.derive_key(params, derive_bits_only, 'AES-GCM', 128, false, [
		.encrypt,
	])
	{
		assert false
	} else {
		assert err.msg().starts_with('InvalidAccessError:')
	}
}
