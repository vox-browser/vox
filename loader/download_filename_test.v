module loader

import encoding.utf8

fn test_truncate_filename_preserves_utf8_boundaries() {
	assert truncate_filename_to_byte_length('short.txt', 255) == 'short.txt'
	assert truncate_filename_to_byte_length('a€b', 1) == 'a'
	assert truncate_filename_to_byte_length('a€b', 2) == 'a'
	assert truncate_filename_to_byte_length('a€b', 3) == 'a'
	assert truncate_filename_to_byte_length('a€b', 4) == 'a€'
	assert truncate_filename_to_byte_length('😀x', 1) == ''
	assert truncate_filename_to_byte_length('😀x', 4) == '😀'
}

fn test_sanitize_download_filename_uses_basename_and_safe_fallbacks() {
	assert sanitize_suggested_download_filename('/tmp/report.pdf') == 'report.pdf'
	assert sanitize_suggested_download_filename('unsafe\\name.txt') == 'unsafe_name.txt'
	assert sanitize_suggested_download_filename('nul\x00name') == 'nul_name'
	assert sanitize_suggested_download_filename('') == 'download'
	assert sanitize_suggested_download_filename('.') == 'download'
	assert sanitize_suggested_download_filename('..') == 'download'
	assert sanitize_suggested_download_filename('/directory/') == 'download'
}

fn test_sanitize_download_filename_preserves_extension_when_truncated() {
	long_title := 'é'.repeat(200)
	result := sanitize_suggested_download_filename('${long_title}.archive')
	assert result.ends_with('.archive')
	assert result.len <= maximum_filename_byte_length
	result_bytes := result.bytes()
	assert utf8.validate(result_bytes.data, result_bytes.len)

	long_extension := 'x'.repeat(255)
	without_preserved_extension := sanitize_suggested_download_filename('title.${long_extension}')
	assert without_preserved_extension.len == maximum_filename_byte_length
	assert !without_preserved_extension.ends_with('.${long_extension}')
}
