module http

fn test_is_method_accepts_token_sequences() {
	assert is_method('GET')
	assert is_method('POST')
	assert is_method('x-custom-header')
	assert is_method('M123')
	// A run of token punctuation is valid.
	assert is_method('abc!#%&*+-.^_|~ABC')
	// The remaining token punctuation, individually.
	assert is_method("'")
	assert is_method('\$')
	assert is_method('`')
}

fn test_is_method_rejects_non_token_and_empty() {
	assert !is_method('')
	assert !is_method('GET POST') // space
	assert !is_method('a/b') // slash
	assert !is_method('a(b') // parenthesis
	assert !is_method('a\tb') // tab
	assert !is_method('a,b') // comma
}

fn test_is_cors_safelisted_method_is_case_sensitive() {
	assert is_cors_safelisted_method('GET')
	assert is_cors_safelisted_method('HEAD')
	assert is_cors_safelisted_method('POST')
	// Lowercase does not match; other methods are not safelisted.
	assert !is_cors_safelisted_method('get')
	assert !is_cors_safelisted_method('PUT')
	assert !is_cors_safelisted_method('DELETE')
}

fn test_is_forbidden_method_is_case_insensitive() {
	assert is_forbidden_method('CONNECT')
	assert is_forbidden_method('TRACE')
	assert is_forbidden_method('TRACK')
	assert is_forbidden_method('connect')
	assert is_forbidden_method('Trace')
	// Ordinary methods are not forbidden.
	assert !is_forbidden_method('GET')
	assert !is_forbidden_method('POST')
}

fn test_normalize_method_uppercases_standard_methods() {
	assert normalize_method('get') == 'GET'
	assert normalize_method('Post') == 'POST'
	assert normalize_method('delete') == 'DELETE'
	assert normalize_method('head') == 'HEAD'
	assert normalize_method('options') == 'OPTIONS'
	assert normalize_method('put') == 'PUT'
	// Already-uppercase standard methods are unchanged.
	assert normalize_method('GET') == 'GET'
}

fn test_normalize_method_leaves_other_methods_unchanged() {
	// Non-standard methods keep their original casing.
	assert normalize_method('patch') == 'patch'
	assert normalize_method('PATCH') == 'PATCH'
	assert normalize_method('x-custom') == 'x-custom'
}
