module main

import os

fn test_http_brotli_import_requires_one_known_codec() {
	source := 'module http\n\nimport compress.brotli\nimport compress.gzip\n'
	expected := source.replace('import compress.brotli', 'import x.compress.brotli')
	assert http_patch_response(source)! == expected
	assert http_patch_response(expected)! == expected
	for unknown in ['module http\n', 'import compress.brotli\nimport compress.brotli\n',
		'import x.compress.brotli\nimport x.compress.brotli\n',
		'import compress.brotli\nimport x.compress.brotli\n'] {
		if _ := http_patch_response(unknown) {
			assert false, 'ambiguous or absent Brotli import was accepted'
		}
	}
}

fn test_http_brotli_encoder_removes_only_the_known_native_fast_path() {
	source := 'module brotli\nimport compress.brotli as native_brotli\n' +
		'pub fn compress(data []u8, params CompressParams) ![]u8 {\n' +
		'\tif data.len > 4096 && params.comment.len == 0 {\n' +
		'\t\tif compressed := native_brotli.compress(data,\n' +
		'\t\t\tquality: params.quality\n\t\t) {\n\t\t\treturn compressed\n\t\t}\n\t}\n' +
		'\treturn compress_general(data, params, window_bits)!\n}\n'
	patched := http_patch_brotli_compressor(source)!
	assert !patched.contains('native_brotli')
	assert patched.contains('return compress_general(data, params, window_bits)!')
	assert http_patch_brotli_compressor(patched)! == patched
	if _ := http_patch_brotli_compressor(source.replace('if compressed :=', 'if result :=')) {
		assert false, 'unknown native encoder fast path was accepted'
	}
}

fn test_http_private_helpers_keep_references_and_remove_their_comments() {
	declaration := '// Helper description.\n@[inline]\nfn helper(value string) string {\n\treturn value\n}\n'
	unused := 'module http\n\n' + declaration + '\n// helper() was used by an old API.\n'
	assert remove_unused_private_helper(unused, 'helper')! == 'module http\n\n// helper() was used by an old API.\n'
	for reference in ["fn caller() string {\n\treturn helper('value')\n}\n",
		"fn caller() {\n\tcallback := helper\n\tcallback('value')\n}\n"] {
		used := unused + reference
		assert remove_unused_private_helper(used, 'helper')! == used
	}
	assert remove_unused_private_helper('module http\n', 'helper')! == 'module http\n'
	if _ := remove_unused_private_helper(unused + declaration, 'helper') {
		assert false, 'duplicate private helpers were accepted'
	}
}

fn test_http_function_replacement_rejects_ambiguous_and_unrecognized_bodies() {
	source := 'module http\nfn example() string {\n\treturn "old"\n}\n'
	replacement := 'fn example() string {\n\treturn "new"\n}'
	assert replace_function(source, 'fn example() string', replacement)! == 'module http\n' + replacement + '\n'
	for invalid in [source + source, 'fn example() string INVALID {\n}\n', 'module http\n'] {
		if _ := replace_function(invalid, 'fn example() string', replacement) {
			assert false, 'unknown or ambiguous function was replaced'
		}
	}
}

fn test_http_request_target_preserves_raw_query_and_current_cookie_api() {
	source := 'fn (req &Request) method_and_url_to_response(method Method, url urllib.URL, data string, header Header) !Response {\n' +
		"\tp := url.escaped_path().trim_left('/')\n" +
		"\tpath := if url.query().len > 0 { '/\${p}?\${url.query().encode()}' } else { '/\${p}' }\n" +
		'\t// cookie_header_value_with_header(header)\n}\n'
	patched := http_patch_request(source)!
	assert patched.contains('path := url.request_uri()')
	assert !patched.contains('url.query()')
	assert http_patch_request(patched)! == patched
	cast := 'cookie_header_value_with_header(header)\nu64(usize(data.str))'
	assert http_patch_request(cast)! == 'cookie_header_value_with_header(header)\nu64(voidptr(data.str))'
	// The compatibility rewrite only recognizes a simple expression, never a
	// nested call whose parentheses require a different source transformation.
	assert http_patch_pointer_casts('u64(usize(call(data)))') == 'u64(usize(call(data)))'
	if _ := http_patch_request('fn (req &Request) method_and_url_to_response() {}') {
		assert false, 'unknown request-target implementation was accepted'
	}
}

fn test_http_proxy_pool_keeps_proxy_identity_in_connection_keys() {
	source := "fn transport_pool_key(req &Request) string {\n\treturn '\${req.in_memory_verification}'\n}\n" +
		"fn (mut t Transport) dial_h1_tcp(req &Request) ! {\n\tmut client := net.dial_tcp('\${host}:\${port}')!\n}\n"
	// The supported pool key contains a preceding delimiter, as in upstream.
	input := source.replace("return '\${req.in_memory_verification}'", "return '|\${req.in_memory_verification}'")
	patched := http_patch_pooled_proxy_transport(input)!
	assert patched.contains('|\${pk_part(vox_transport_proxy_key(req))}')
	assert patched.contains('vox_http_dial_tcp(req, host, port)!')
	assert !patched.contains('net.dial_tcp(')
	if _ := http_patch_pooled_proxy_transport(source) {
		assert false, 'unknown pool-key layout was accepted'
	}
}

fn test_http_staging_removes_stale_links_without_removing_their_targets() {
	root := make_temp_directory(os.temp_dir(), 'vox-http-staging-test-')!
	defer { os.rmdir_all(root) or {} }
	original := os.join_path(root, 'original')
	target := os.join_path(root, 'target')
	make_directory(original)!
	make_directory(target)!
	os.write_file(os.join_path(original, 'request.v'), 'current request')!
	os.write_file(os.join_path(target, 'request.v'), 'patched request')!
	os.write_file(os.join_path(target, 'vox_h2_wake.h'), 'generated helper')!
	old := os.join_path(root, 'old_reverse_proxy.v')
	os.write_file(old, 'old compiler source')!
	os.symlink(old, os.join_path(target, 'reverse_proxy.v'))!
	stale_dir := os.join_path(target, 'old_directory')
	make_directory(stale_dir)!
	os.write_file(os.join_path(stale_dir, 'stale.v'), 'obsolete')!
	http_remove_obsolete_entries(target, original)!
	mut names := os.ls(target)!
	names.sort()
	assert names == ['request.v', 'vox_h2_wake.h']
	assert os.is_file(old)
	assert os.read_file(os.join_path(target, 'request.v'))! == 'patched request'
	current := os.join_path(original, 'request.v')
	link := os.join_path(target, 'request.v')
	http_link(current, link)!
	assert os.is_link(link)
	assert os.real_path(link) == current
	http_link(current, link)!
	assert os.read_file(link)! == 'current request'
}
