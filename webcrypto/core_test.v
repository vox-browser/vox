module webcrypto

fn test_crypto_random_values_uint8_quota_and_uuid_shape() {
	crypto := Crypto.create()
	assert crypto.subtle() == crypto.subtle()

	mut bytes := []u8{len: 64}
	returned := crypto.get_random_values(mut bytes)!
	assert returned == bytes
	assert bytes.any(it != 0)

	mut too_large := []u8{len: maximum_random_values_length + 1}
	if _ := crypto.get_random_values(mut too_large) {
		assert false, 'oversized random request must fail'
	} else {
		assert err.msg().starts_with('QuotaExceededError:')
	}

	for _ in 0 .. 16 {
		uuid := crypto.random_uuid()!
		assert uuid.len == 36
		assert uuid[8] == `-`
		assert uuid[13] == `-`
		assert uuid[18] == `-`
		assert uuid[23] == `-`
		assert uuid[14] == `4`
		assert uuid[19] in [`8`, `9`, `a`, `b`]
	}
}

fn test_crypto_random_values_integer_views_and_error_precedence() {
	crypto := Crypto.create()
	for kind in [RandomValuesArrayKind.int8, .uint8, .uint8_clamped, .int16, .uint16, .int32, .uint32,
		.bigint64, .biguint64] {
		mut backing := []u8{len: 18, init: 0xaa}
		mut view := RandomValuesArrayView.create(kind, backing, 1, 16)!
		view = crypto.get_random_values_view(mut view)!
		assert view.buffer[0] == 0xaa
		assert view.buffer[17] == 0xaa
		assert view.buffer[1..17].any(it != 0xaa)
	}

	for kind in [RandomValuesArrayKind.float32, .float64, .data_view] {
		mut view := RandomValuesArrayView.create(kind, []u8{len: 8}, 0, 8)!
		if _ := crypto.get_random_values_view(mut view) {
			assert false, 'non-integer view must fail'
		} else {
			assert err.msg().starts_with('TypeMismatchError:')
		}
	}

	mut out_of_bounds := RandomValuesArrayView{
		kind:          .uint8
		buffer:        []u8{len: 4}
		byte_offset:   3
		byte_length:   2
		out_of_bounds: true
	}
	if _ := crypto.get_random_values_view(mut out_of_bounds) {
		assert false, 'out-of-bounds view must fail'
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}

	mut too_large := RandomValuesArrayView.create(.uint8,
		[]u8{len: maximum_random_values_length + 1}, 0, maximum_random_values_length + 1)!
	if _ := crypto.get_random_values_view(mut too_large) {
		assert false, 'oversized view must fail'
	} else {
		assert err.msg().starts_with('QuotaExceededError:')
	}
}

fn test_crypto_binding_enum_round_trips() {
	for type_ in [KeyType.public_key, .private_key, .secret] {
		assert parse_key_type(key_type_string(type_))! == type_
	}
	for format in [KeyFormat.raw_public, .raw_private, .raw_seed, .raw_secret, .raw, .spki, .pkcs8,
		.jwk] {
		assert parse_key_format(key_format_string(format))! == format
	}
	for usage in [KeyUsage.encrypt, .decrypt, .sign, .verify, .derive_key, .derive_bits, .wrap_key,
		.unwrap_key, .encapsulate_key, .encapsulate_bits, .decapsulate_key, .decapsulate_bits] {
		assert parse_key_usage(key_usage_string(usage))! == usage
	}
	if _ := parse_key_usage('Encrypt') {
		assert false, 'IDL enum parsing is case-sensitive'
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_base64url_round_trip_and_strict_alphabet() {
	for bytes in [[]u8{}, [u8(0)], [u8(0xff)], 'Ladybird WebCrypto'.bytes()] {
		encoded := base64url_encode(bytes)
		assert !encoded.contains('=')
		assert base64url_decode(encoded)! == bytes
	}
	for invalid in ['=', '+', '/', 'a=', 'é', 'abcde'] {
		if _ := base64url_decode(invalid) {
			assert false, 'invalid base64url must fail: ${invalid}'
		} else {
			assert err.msg().starts_with('DataError:')
		}
	}
}

fn test_json_web_key_parse_to_object_and_round_trip() {
	json := '{"kty":"RSA","use":"sig","key_ops":["sign","verify"],"alg":"RS256","ext":true,"n":"abc","e":"AQAB","oth":[{"r":"r1","d":"d1","t":"t1"}],"pub":"pub-data","priv":"priv-data","unknown":42}'
	key := JsonWebKey.parse(json.bytes())!
	assert key.kty? == 'RSA'
	assert key.use? == 'sig'
	assert key.key_ops? == ['sign', 'verify']
	assert key.alg? == 'RS256'
	assert key.ext? == true
	assert key.n? == 'abc'
	assert key.e? == 'AQAB'
	other := key.oth?
	assert other.len == 1
	assert other[0].r? == 'r1'
	assert key.pub_? == 'pub-data'
	assert key.priv? == 'priv-data'

	object := key.to_object()
	assert object['kty']! is string
	assert (object['kty']! as string) == 'RSA'
	assert 'unknown' !in object
	reparsed := JsonWebKey.parse(key.to_json().bytes())!
	assert reparsed.key_ops? == ['sign', 'verify']
	assert reparsed.oth?[0].t? == 't1'
}

fn test_json_web_key_parse_errors_and_wrong_scalar_types() {
	for json in ['null', '[]', '{', '"RSA"'] {
		if _ := JsonWebKey.parse(json.bytes()) {
			assert false, 'non-object or malformed JSON must fail'
		} else {
			assert err.msg().starts_with('SyntaxError:')
		}
	}
	if _ := JsonWebKey.parse('{"alg":"HS256"}'.bytes()) {
		assert false, 'missing kty must fail'
	} else {
		assert err.msg().starts_with('DataError:')
	}
	if _ := JsonWebKey.parse('{"kty":"oct","key_ops":["sign",1]}'.bytes()) {
		assert false, 'non-string operation must fail conversion'
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	if _ := JsonWebKey.parse('{"kty":"RSA","oth":[7]}'.bytes()) {
		assert false, 'non-object other-prime entry must fail conversion'
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	wrong_scalars := JsonWebKey.parse('{"kty":"oct","alg":7,"ext":"yes","key_ops":7}'.bytes())!
	assert wrong_scalars.alg == none
	assert wrong_scalars.ext == none
	assert wrong_scalars.key_ops == none
	if _ := JsonWebKey.parse([u8(0xff), 0xfe]) {
		assert false, 'invalid UTF-8 must fail'
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
}

fn test_key_algorithm_records_setters_and_big_endian_exponent() {
	mut base := KeyAlgorithm.create()
	base.set_name('Ed25519')
	assert base.name == 'Ed25519'
	assert base.name() == 'Ed25519'

	mut rsa := RsaKeyAlgorithm.create()
	rsa.set_name('RSA-OAEP')
	rsa.set_modulus_length(2048)
	rsa.set_public_exponent([u8(0), 0, 1, 0, 1])
	assert rsa.name == 'RSA-OAEP'
	assert rsa.modulus_length == 2048
	assert rsa.public_exponent == [u8(1), 0, 1]
	assert rsa.name() == 'RSA-OAEP'
	assert rsa.modulus_length() == 2048
	assert rsa.public_exponent() == [u8(1), 0, 1]

	mut hashed := RsaHashedKeyAlgorithm.create()
	hashed.set_name('RSA-PSS')
	hashed.set_modulus_length(3072)
	hashed.set_public_exponent([u8(1), 0, 1])
	hashed.set_hash('SHA-256')
	assert hashed.hash_algorithm().name == 'SHA-256'
	assert hashed.name() == 'RSA-PSS'
	assert hashed.modulus_length() == 3072
	assert hashed.public_exponent() == [u8(1), 0, 1]
	assert hashed.hash() == 'SHA-256'

	mut ec := EcKeyAlgorithm.create()
	ec.set_name('ECDSA')
	ec.set_named_curve('P-256')
	assert ec.named_curve == 'P-256'
	assert ec.name() == 'ECDSA'
	assert ec.named_curve() == 'P-256'

	mut aes := AesKeyAlgorithm.create()
	aes.set_name('AES-GCM')
	aes.set_length(256)
	assert aes.length == 256
	assert aes.name() == 'AES-GCM'
	assert aes.length() == 256

	mut hmac := HmacKeyAlgorithm.create()
	hmac.set_hash('SHA-512')
	hmac.set_length(1024)
	assert hmac.name == 'HMAC'
	assert hmac.hash_algorithm().name == 'SHA-512'
	assert hmac.name() == 'HMAC'
	assert hmac.hash() == 'SHA-512'
	assert hmac.length() == 1024

	mut kmac := KmacKeyAlgorithm.create()
	kmac.set_name('KMAC256')
	kmac.set_length(512)
	assert kmac.length == 512
	assert kmac.name() == 'KMAC256'
	assert kmac.length() == 512
}

fn test_crypto_key_slots_usage_order_clone_and_pair() {
	mut source_handle := [u8(1), 2, 3, 4]
	key := CryptoKey.create(.secret, true, AesKeyAlgorithm{
		name:   'AES-GCM'
		length: 128
	}, [.decrypt, .encrypt, .decrypt], source_handle)
	source_handle[0] = 99
	assert key.handle() == [u8(1), 2, 3, 4]
	assert key.internal_usages() == [.decrypt, .encrypt, .decrypt]
	assert key.permits(.encrypt)
	assert key.algorithm_name() == 'AES-GCM'
	assert key.bindings_type() == .secret
	internal := key.internal_algorithm()
	assert internal is AesKeyAlgorithm
	assert (internal as AesKeyAlgorithm).length == 128

	rsa_hashed_key := CryptoKey.create(.public_key, true, RsaHashedKeyAlgorithm{
		name: 'RSA-PSS'
		hash: 'SHA-384'
	}, [.verify], [])
	assert rsa_hashed_key.rsa_hashed_algorithm().hash == 'SHA-384'
	ec_key := CryptoKey.create(.public_key, true, EcKeyAlgorithm{
		name: 'ECDSA'
		named_curve: 'P-384'
	}, [.verify], [])
	assert ec_key.ec_algorithm().named_curve == 'P-384'
	hmac_key := CryptoKey.create(.secret, true, HmacKeyAlgorithm{
		hash: 'SHA-256'
		length: 256
	}, [.sign], [])
	assert hmac_key.hmac_algorithm().length == 256

	mut returned_handle := key.handle()
	returned_handle[0] = 77
	assert key.handle()[0] == 1
	clone := key.clone_key()
	assert clone.handle() == key.handle()
	assert clone.internal_usages() == key.internal_usages()

	private_key := CryptoKey.create(.private_key, false, KeyAlgorithm{ name: 'Ed25519' }, [
		.sign,
	], [u8(8), 9])
	pair := CryptoKeyPair.create(key, private_key)
	assert pair.public_key_value() == key
	assert pair.private_key_value() == private_key
}

fn test_crypto_key_structured_serialization_preserves_handle_and_destroy_wipes() {
	mut key := CryptoKey.create(.private_key, false, RsaKeyAlgorithm{
		name:            'RSA-PSS'
		modulus_length:  2048
		public_exponent: [u8(1), 0, 1]
	}, [.sign, .sign], [u8(0xde), 0xad, 0xbe, 0xef])
	serialized := key.serialization_steps()
	assert serialized.type_ == .private_key
	assert !serialized.extractable
	assert serialized.usages == [.sign, .sign]
	restored := CryptoKey.deserialize(serialized)!
	assert restored.algorithm_name() == 'RSA-PSS'
	assert restored.internal_usages() == [.sign, .sign]
	assert restored.handle() == [u8(0xde), 0xad, 0xbe, 0xef]

	key.destroy()
	assert key.destroyed()
	assert key.handle().len == 0
	key.destroy()
}

fn test_crypto_key_json_handle_is_cloned_and_not_structured_serialized() {
	mut source := JsonWebKey{
		kty:     'oct'
		key_ops: ['sign']
		k:       'c2VjcmV0'
	}
	key := CryptoKey.create_from_json_web_key(.secret, true, HmacKeyAlgorithm{
		hash:   'SHA-256'
		length: 48
	}, [.sign], source)
	source.key_ops = ['verify']
	handle := key.json_web_key_handle() or { panic('missing JWK handle') }
	assert handle.key_ops? == ['sign']
	assert key.handle_kind() == .json_web_key
	restored := CryptoKey.deserialize(key.serialize())!
	assert restored.json_web_key_handle() == none
}
