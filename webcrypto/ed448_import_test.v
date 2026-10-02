module webcrypto

fn test_ed448_raw_import_accepts_456_bit_public_keys() {
	subtle_crypto := SubtleCrypto.create()
	material := []u8{len: 57, init: 0x5a}
	key := subtle_crypto.import_key(.raw, material, 'Ed448', true, [.verify], '') or {
		panic(err)
	}

	assert key.type_ == .public_key
	assert key.algorithm_name() == 'Ed448'
	assert key.extractable
	assert key.usages == [KeyUsage.verify]
	assert key.handle() == material
}

fn test_ed448_raw_import_rejects_448_bit_public_keys() {
	subtle_crypto := SubtleCrypto.create()
	if _ := subtle_crypto.import_key(.raw, []u8{len: 56}, 'Ed448', false, [.verify], '') {
		assert false, '448-bit Ed448 public key was accepted'
	} else {
		assert err.msg() == 'DataError: Invalid key length'
	}
}
