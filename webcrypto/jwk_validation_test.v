// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

fn test_shared_jwk_source_key_operation_groups_optional_and_unknown_members() {
	validate_jwk_key_ops(JsonWebKey{}, [.encrypt])!
	for operations in [['sign', 'verify'], ['encrypt', 'decrypt'],
		['wrapKey', 'unwrapKey'], ['deriveKey', 'deriveBits'],
		['unrecognized', 'deriveKey']] {
		validate_jwk_key_ops(JsonWebKey{ key_ops: operations }, [])!
	}
	for use in ['sig', 'enc', 'other'] {
		validate_jwk_key_ops(JsonWebKey{ use: use, key_ops: ['deriveKey', 'deriveBits'] }, [
			.derive_key,
			.derive_bits,
		])!
	}
	if _ := validate_jwk_key_ops(JsonWebKey{ use: 'sig', key_ops: ['sign', 'sign', 'encrypt'] }, [
		.verify,
	])
	{
		assert false
	} else {
		assert err.msg() == 'DataError: Duplicate key operation: sign'
	}
	for operations in [['sign', 'encrypt'], ['encrypt', 'wrapKey'],
		['verify', 'unwrapKey']] {
		if _ := validate_jwk_key_ops(JsonWebKey{ use: 'sig', key_ops: operations }, [
			.decrypt,
		])
		{
			assert false
		} else {
			assert err.msg() == 'DataError: Multiple unrelated key operations are specified'
		}
	}
	if _ := validate_jwk_key_ops(JsonWebKey{ use: 'sig', key_ops: ['unknown'] }, [
		.verify,
	])
	{
		assert false
	} else {
		assert err.msg() == "DataError: use=sig but key_ops does not contain 'sign' or 'verify'"
	}
	if _ := validate_jwk_key_ops(JsonWebKey{ use: 'enc', key_ops: ['sign'] }, [
		.encrypt,
	])
	{
		assert false
	} else {
		assert err.msg() == "DataError: use=enc but key_ops contains 'sign' or 'verify'"
	}
	if _ := validate_jwk_key_ops(JsonWebKey{ key_ops: ['decrypt'] }, [.encrypt, .wrap_key]) {
		assert false
	} else {
		assert err.msg() == 'DataError: Missing key_ops usage: encrypt'
	}
}

fn test_shared_jwk_source_diagnostics_reach_aes_ec_and_hmac_imports() {
	subtle := SubtleCrypto.create()
	aes := JsonWebKey{
		kty:     'oct'
		k:       base64url_encode([]u8{len: 16})
		alg:     'A128GCM'
		use:     'enc'
		key_ops: ['sign']
	}
	if _ := subtle.import_jwk(aes, 'AES-GCM', true, [.encrypt], '') {
		assert false
	} else {
		assert err.msg() == "DataError: use=enc but key_ops contains 'sign' or 'verify'"
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...aes, key_ops: ['decrypt'] }, 'AES-GCM', true, [
		.encrypt,
	], '')
	{
		assert false
	} else {
		assert err.msg() == 'DataError: Missing key_ops usage: encrypt'
	}
	hmac := JsonWebKey{
		kty:     'oct'
		k:       base64url_encode([]u8{len: 16})
		alg:     'HS256'
		use:     'sign'
		key_ops: ['verify']
	}
	if _ := subtle.import_jwk(hmac, 'HMAC', true, [.sign], 'SHA-256') {
		assert false
	} else {
		assert err.msg() == 'DataError: Missing key_ops usage: sign'
	}
	pair := subtle.generate_key(EcKeyGenParams{ name: 'ECDSA', named_curve: 'P-256' }, true, [
		.sign,
		.verify,
	])!.pair or { panic('pair') }
	jwk := subtle.export_jwk(pair.public_key)!
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, use: 'sig', key_ops: ['encrypt'] }, EcKeyImportParams{
		name:        'ECDSA'
		named_curve: 'P-256'
	}, true, [.verify], '')
	{
		assert false
	} else {
		assert err.msg() == "DataError: use=sig but key_ops does not contain 'sign' or 'verify'"
	}
}
