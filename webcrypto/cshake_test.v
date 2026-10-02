module webcrypto

fn test_cshake_upstream_empty_customization_vectors_and_dispatch() {
	subtle := SubtleCrypto.create()
	assert subtle.digest(CShakeParams{ name: 'cshake128', output_length: 256 }, []u8{})!.hex() == '7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26'
	assert subtle.digest(CShakeParams{ name: 'cSHAKE256', output_length: 512, function_name: []u8{}, customization: []u8{} }, []u8{})!.hex() == '46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762fd75dc4ddd8c0f200cb05019d67b592f6fc821c49479ab48640292eacb3b7c4be'
	assert CShake.create().digest(CShakeParams{ name: 'cSHAKE128', output_length: 0 }, 'abc'.bytes())!.len == 0
}

fn test_cshake_validation_matches_upstream_backend() {
	subtle := SubtleCrypto.create()
	for params in [CShakeParams{ name: 'cSHAKE128', output_length: 7 },
		CShakeParams{ name: 'cSHAKE256', output_length: 256, customization: 'domain'.bytes() },
		CShakeParams{ name: 'cSHAKE128', output_length: 256, function_name: 'function'.bytes() }] {
		if _ := subtle.digest(params, 'abc'.bytes()) {
			assert false
		} else {
			assert err.msg().starts_with('OperationError: Hash function failed:')
		}
	}
	if _ := subtle.digest('cSHAKE128', []u8{}) {
		assert false
	} else {
		assert err.msg() == 'TypeError: outputLength is required'
	}
}
