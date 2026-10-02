// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

fn test_source_json_parser_requires_kty_but_import_dictionary_leaves_it_optional() {
	assert decode_json_web_key_dictionary('{}'.bytes())!.kty == none
	if _ := JsonWebKey.parse('{}'.bytes()) {
		assert false
	} else {
		assert err.msg() == 'DataError: kty field is not defined'
	}
	assert decode_json_web_key_dictionary('{"ext":false,"key_ops":[]}'.bytes())! == JsonWebKey{ ext: false, key_ops: []string{} }
}

fn test_source_class_import_dictionary_checks_usages_before_missing_key_type() {
	for name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW', 'AES-OCB'] {
		allowed := if name == 'AES-KW' { KeyUsage.wrap_key } else { KeyUsage.encrypt }
		if _ := import_aes_key(name, .jwk, '{}'.bytes(), true, [allowed]) {
			assert false
		} else {
			assert err.msg() == 'DataError: Invalid key type'
		}
		if _ := import_aes_key(name, .jwk, '{}'.bytes(), true, [.sign]) {
			assert false
		} else {
			assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
		}
	}
	if _ := import_hmac_key(HmacImportParams{ hash: 'SHA-256' }, .jwk, '{}'.bytes(), true, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key type'
	}
	if _ := import_kmac_key(KmacImportParams{ name: 'KMAC128' }, .jwk, '{}'.bytes(), true, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key type'
	}
	for name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
		usage := if name == 'RSA-OAEP' { KeyUsage.encrypt } else { KeyUsage.verify }
		if _ := import_rsa_key(RsaHashedImportParams{ name: name, hash: 'SHA-256' }, .jwk, '{}'.bytes(), true, [usage]) {
			assert false
		} else {
			assert err.msg() == 'DataError: Invalid key type'
		}
	}
	if _ := import_ec_key(EcKeyImportParams{ name: 'ECDSA', named_curve: 'P-256' }, .jwk, '{}'.bytes(), true, [.verify]) {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key type'
	}
	if _ := import_ed25519_key(.jwk, '{}'.bytes(), true, [.verify]) {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key type'
	}
}
