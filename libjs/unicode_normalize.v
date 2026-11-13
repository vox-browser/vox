module libjs

import vunicode

fn unicode_string_normalize(text Utf16String, form StringNormalizationForm) Utf16String {
	normalized := vunicode.normalize(vunicode.decode_utf16(text.data), match form {
		.nfd { .nfd }
		.nfc { .nfc }
		.nfkd { .nfkd }
		.nfkc { .nfkc }
	})
	return Utf16String.from_slice(vunicode.encode_utf16(normalized))
}
