module fetch

import mimesniff

fn test_legacy_extract_uses_charset_parameter() {
	mime := mimesniff.MimeType.parse('text/html;charset=utf-8') or { panic('parse failed') }
	// The charset resolves through the Encoding label table, ignoring the fallback.
	assert legacy_extract_an_encoding(mime, 'windows-1252') == 'UTF-8'
}

fn test_legacy_extract_charset_is_standardized() {
	shift := mimesniff.MimeType.parse('text/plain;charset=Shift_JIS') or { panic('parse failed') }
	assert legacy_extract_an_encoding(shift, 'windows-1252') == 'Shift_JIS'
	latin := mimesniff.MimeType.parse('text/plain;charset=latin1') or { panic('parse failed') }
	assert legacy_extract_an_encoding(latin, 'utf-8') == 'windows-1252'
}

fn test_legacy_extract_failure_mime_returns_fallback() {
	assert legacy_extract_an_encoding(none, 'windows-1252') == 'windows-1252'
}

fn test_legacy_extract_no_charset_returns_fallback() {
	mime := mimesniff.MimeType.parse('text/html') or { panic('parse failed') }
	assert legacy_extract_an_encoding(mime, 'utf-8') == 'utf-8'
}

fn test_legacy_extract_unrecognized_charset_returns_fallback() {
	mime := mimesniff.MimeType.parse('text/html;charset=not-a-real-encoding') or {
		panic('parse failed')
	}
	assert legacy_extract_an_encoding(mime, 'windows-1252') == 'windows-1252'
}
