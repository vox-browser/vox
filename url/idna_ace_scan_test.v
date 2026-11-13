module url

// Exact original complete function retained independently of the byte scan.
fn idna_split_lower_original_domain_to_ascii(domain string, be_strict bool) ?string {
	// Preserve LibURL's ASCII fast path. xn-- labels still take the ICU path
	// so invalid Punycode is rejected.
	if !be_strict && domain.is_ascii() {
		if domain == '' {
			return none
		}
		mut needs_idna := false
		for part in domain.split('.') {
			if part.to_lower().starts_with('xn--') {
				needs_idna = true
				break
			}
		}
		if !needs_idna {
			return domain.to_lower()
		}
	}
	return idna_to_ascii(domain, be_strict)
}

fn assert_idna_scan_matches_original(input string, strict bool) {
	if expected := idna_split_lower_original_domain_to_ascii(input, strict) {
		actual := domain_to_ascii(input, strict) or { panic('candidate rejected original result') }
		assert actual == expected, '${input} strict=${strict}'
	} else {
		assert domain_to_ascii(input, strict) == none, '${input} strict=${strict}'
	}
}

fn test_idna_ace_scan_matches_original_for_every_short_ascii_label_input() {
	alphabet := '.xXnN-a'.bytes()
	mut combinations := 1
	for length in 0 .. 7 {
		for value in 0 .. combinations {
			mut remaining := value
			mut bytes := []u8{len: length}
			for index in 0 .. length {
				bytes[index] = alphabet[remaining % alphabet.len]
				remaining /= alphabet.len
			}
			input := bytes.bytestr()
			assert_idna_scan_matches_original(input, false)
			assert_idna_scan_matches_original(input, true)
		}
		combinations *= alphabet.len
	}
}

fn test_idna_ace_scan_matches_original_for_every_byte_at_label_boundaries() {
	for byte in 0 .. 256 {
		for prefix in ['', '.', 'a.', 'xn', 'xn-', 'a.xn--', 'xnxn--'] {
			for suffix in ['', '.', '..', '--', 'n--a', '.xn--a', '.com'] {
				input := prefix + [u8(byte)].bytestr() + suffix
				assert_idna_scan_matches_original(input, false)
				assert_idna_scan_matches_original(input, true)
			}
		}
	}
}

fn test_idna_ace_scan_preserves_case_and_only_checks_actual_label_starts() {
	for ace in ['xn--', 'Xn--', 'xN--', 'XN--'] {
		for suffix in ['', 'a', 'g6w251d', 'bcher-kva', 'fa-hia', '-a', '\x00', 'a.com.'] {
			for prefix in ['', '.', '..', 'a.', 'www.example.', 'a', 'ax', '-'] {
				input := prefix + ace + suffix
				assert_idna_scan_matches_original(input, false)
				assert_idna_scan_matches_original(input, true)
			}
		}
	}
	assert domain_to_ascii('Xn--G6W251D', false)? == 'xn--g6w251d'
	assert domain_to_ascii('aXN--a.COM', false)? == 'axn--a.com'
	assert domain_to_ascii('www.XN--a', false) == none
}

fn test_idna_ace_scan_keeps_strict_non_ascii_and_empty_inputs_on_original_paths() {
	for input in ['', '.', '..', 'EXAMPLE.COM.', 'a..B', 'a b', 'a\x00B', '\x00', '\x7f', '\xff',
		'a.\xc0\xaf', 'faß.de', '測試', 'bücher.example', 'пример.рф', 'example。com',
		'example．com', 'example｡com', 'ＸＮ--a', 'xn--fa-hia.de', 'a.\u200d.com', 'a.\u200c.com',
		'א.example', '١٢.example', '💩.example'] {
		assert_idna_scan_matches_original(input, false)
		assert_idna_scan_matches_original(input, true)
	}
	assert domain_to_ascii('EXAMPLE.COM', false)? == 'example.com'
	assert domain_to_ascii('faß.de', false)? == 'xn--fa-hia.de'
	assert domain_to_ascii('xn--a', false) == none
}

fn test_idna_ace_scan_preserves_long_labels_and_late_ace_prefixes() {
	for input in ['a'.repeat(4096), 'a.'.repeat(1024), 'label.'.repeat(120) + 'RU',
		'.'.repeat(1024) + 'Xn--g6w251d', 'a.'.repeat(120) + 'xN--a', 'a.'.repeat(120) + 'xn-',
		'a.'.repeat(120) + 'x', 'a.'.repeat(120) + 'xn'] {
		assert_idna_scan_matches_original(input, false)
		assert_idna_scan_matches_original(input, true)
	}
}
