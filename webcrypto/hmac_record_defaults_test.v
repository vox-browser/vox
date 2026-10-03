module webcrypto

fn test_source_hmac_algorithm_records_start_empty_and_operations_assign_name_explicitly() {
	assert HmacKeyAlgorithm{}.name() == ''
	assert HmacKeyAlgorithm.create().name() == ''
	assert CryptoKeyAlgorithm(HmacKeyAlgorithm{}).name_utf16().code_units().len == 0
	generated := generate_hmac_key(HmacKeyGenParams{hash: 'SHA-256', length: 128}, true, [.sign])!
	assert generated.algorithm_name() == 'HMAC'
	assert generated.hmac_algorithm().hash == 'SHA-256'
	assert generated.hmac_algorithm().length == 128
	imported := import_hmac_key(HmacImportParams{hash: 'SHA-256'}, .raw, [u8(7), 9], false, [.verify])!
	assert imported.algorithm_name() == 'HMAC'
	assert imported.hmac_algorithm().length == 16
	assert imported.handle() == [u8(7), 9]
}
