module webcrypto

fn test_ed25519_private_jwk_requires_matching_public_key() {
	subtle_crypto := SubtleCrypto.create()
	seed := []u8{len: 32, init: 0x42}
	public_key := ed25519_public_key_from_seed(seed) or { panic(err) }
	valid_jwk := JsonWebKey{
		kty: 'OKP'
		crv: 'Ed25519'
		x: base64url_encode(public_key)
		d: base64url_encode(seed)
	}
	key := subtle_crypto.import_jwk(valid_jwk, 'Ed25519', true, [.sign], '') or {
		panic(err)
	}
	assert key.type_ == .private_key

	mut mismatched_public_key := public_key.clone()
	mismatched_public_key[0] ^= 1
	invalid_jwk := JsonWebKey{
		...valid_jwk
		x: base64url_encode(mismatched_public_key)
	}
	if _ := subtle_crypto.import_jwk(invalid_jwk, 'Ed25519', true, [.sign], '') {
		assert false, 'inconsistent private JWK was accepted'
	} else {
		assert err.msg() == 'DataError: Invalid Ed25519 key pair'
	}
}
