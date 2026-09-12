module css

fn test_valid_custom_ident_rejects_reserved_keywords() {
	assert is_valid_custom_ident('fade-in', [])
	assert !is_valid_custom_ident('initial', [])
	assert !is_valid_custom_ident('InHeRiT', [])
	assert !is_valid_custom_ident('DEFAULT', [])
}

fn test_valid_custom_ident_applies_case_insensitive_blacklist() {
	assert is_valid_custom_ident('visible', ['none', 'hidden'])
	assert !is_valid_custom_ident('NONE', ['none', 'hidden'])
	assert !is_valid_custom_ident('Hidden', ['none', 'hidden'])
}
