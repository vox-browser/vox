module webcrypto

fn ed25519_jwk_with_lengths(public_length int, private_length ?int) JsonWebKey {
	return JsonWebKey{
		kty: 'OKP'
		crv: 'Ed25519'
		x: base64url_encode([]u8{len: public_length})
		d: if length := private_length { base64url_encode([]u8{len: length}) } else { none }
	}
}

fn test_ed25519_jwk_import_validates_public_key_length() {
	subtle_crypto := SubtleCrypto.create()
	if _ := subtle_crypto.import_jwk(ed25519_jwk_with_lengths(31, none), 'Ed25519', false, [
		.verify,
	], '') {
		assert false, 'truncated public key was accepted'
	} else {
		assert err.msg() == 'DataError: Invalid key length'
	}

	if _ := subtle_crypto.import_jwk(ed25519_jwk_with_lengths(31, 32), 'Ed25519', false, [
		.sign,
	], '') {
		assert false, 'private JWK with a truncated public key was accepted'
	} else {
		assert err.msg() == 'DataError: Invalid key length'
	}
}

fn test_ed25519_jwk_import_validates_private_key_length() {
	subtle_crypto := SubtleCrypto.create()
	if _ := subtle_crypto.import_jwk(ed25519_jwk_with_lengths(32, 31), 'Ed25519', false, [
		.sign,
	], '') {
		assert false, 'truncated private key was accepted'
	} else {
		assert err.msg() == 'DataError: Invalid key length'
	}
}
