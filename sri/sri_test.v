module sri

fn test_apply_algorithm_known_sha256_vectors() {
	// SHA-256 of "" and "abc", base64-encoded (well-known test vectors).
	assert apply_algorithm_to_bytes('sha256', [])! == '47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='
	assert apply_algorithm_to_bytes('sha256', 'abc'.bytes())! == 'ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0='
}

fn test_apply_algorithm_supports_384_and_512() {
	// Just check they produce base64 of the right length (48 → 64 chars, 64 → 88 chars).
	sha384 := apply_algorithm_to_bytes('sha384', 'abc'.bytes())!
	sha512 := apply_algorithm_to_bytes('sha512', 'abc'.bytes())!
	assert sha384.len == 64
	assert sha512.len == 88
}

fn test_apply_algorithm_rejects_unknown() {
	assert is_supported_hash_function('sha256')
	assert is_supported_hash_function('sha384')
	assert is_supported_hash_function('sha512')
	assert !is_supported_hash_function('sha1')
	assert is_supported_hash_function('SHA256')
	if _ := apply_algorithm_to_bytes('md5', 'abc'.bytes()) {
		assert false, 'md5 must not be supported'
	}
}

fn test_parse_metadata_basic() {
	result := parse_metadata('sha256-abc123')
	assert result.len == 1
	assert result[0].algorithm == 'sha256'
	assert result[0].base64_value == 'abc123'
}

fn test_parse_metadata_multiple_and_options() {
	result := parse_metadata('sha256-aaa?foo=bar sha512-bbb')
	assert result.len == 2
	assert result[0].algorithm == 'sha256'
	// The "?..." options token is stripped from the hash expression.
	assert result[0].base64_value == 'aaa'
	assert result[1].algorithm == 'sha512'
	assert result[1].base64_value == 'bbb'
}

fn test_parse_metadata_filters_unsupported_and_empty() {
	// md5 is unsupported; extra spaces yield empty items that are dropped.
	result := parse_metadata('md5-xyz   sha384-good')
	assert result.len == 1
	assert result[0].algorithm == 'sha384'
	assert result[0].base64_value == 'good'
}

fn test_get_strongest_prefers_higher_strength() {
	set := [
		Metadata{
			algorithm: 'sha256'
			base64_value: 'a'
		},
		Metadata{
			algorithm: 'sha512'
			base64_value: 'b'
		},
	]
	strongest := get_strongest_metadata_from_set(set)
	assert strongest.len == 1
	assert strongest[0].algorithm == 'sha512'
	assert strongest[0].base64_value == 'b'
}

fn test_get_strongest_keeps_equal_strength() {
	set := [
		Metadata{
			algorithm: 'sha256'
			base64_value: 'a'
		},
		Metadata{
			algorithm: 'sha256'
			base64_value: 'b'
		},
	]
	strongest := get_strongest_metadata_from_set(set)
	assert strongest.len == 2
}

fn test_do_bytes_match_metadata_list() {
	bytes := 'abc'.bytes()
	correct256 := apply_algorithm_to_bytes('sha256', bytes)!
	correct512 := apply_algorithm_to_bytes('sha512', bytes)!

	// A correct hash matches.
	assert do_bytes_match_metadata_list(bytes, 'sha256-${correct256}')! == true
	// Algorithm names are case-insensitive; URL-safe unpadded digests match too.
	url_safe := correct256.trim_right('=').replace('+', '-').replace('/', '_')
	assert do_bytes_match_metadata_list(bytes, 'SHA256-${url_safe}')! == true
	// A wrong hash does not.
	assert do_bytes_match_metadata_list(bytes, 'sha256-AAAA')! == false
	// Empty metadata list always matches.
	assert do_bytes_match_metadata_list(bytes, '')! == true
	// Only the strongest metadata is checked: a wrong sha256 alongside a correct sha512 matches.
	assert do_bytes_match_metadata_list(bytes, 'sha256-WRONG sha512-${correct512}')! == true
	// A wrong sha512 (the strongest) fails even with a correct sha256 present.
	assert do_bytes_match_metadata_list(bytes, 'sha256-${correct256} sha512-WRONG')! == false
}
