module libjs

fn regexp_preparation_fixture_units(text string) !Utf16String {
	mut units := []u16{}
	if text != '-' {
		assert text.len % 4 == 0
		for offset := 0; offset < text.len; offset += 4 {
			units << u16(text[offset..offset + 4].parse_uint(16, 16)!)
		}
	}
	return Utf16String{
		data: units
	}
}

fn test_regexp_preparation_matches_pinned_native_libjs_and_ak_corpus_exactly() {
	corpus := $embed_file('testdata/regexp-preparation.tsv').to_string()
	mut count := 0
	for row in corpus.split_into_lines() {
		if row.len == 0 || row.starts_with('#') { continue
		 }
		fields := row.split('\t')
		assert fields.len == 6, row
		input := regexp_preparation_fixture_units(fields[3])!
		original := input.data.clone()
		match fields[0] {
			'flags' {
				if result := validate_regexp_flags(input) {
					assert fields[4] == 'ok' && int(result) == fields[5].int(), row
				} else {
					assert fields[4] == 'error' && err is RegExpFlagError, row
					if err is RegExpFlagError {
						assert err.message == regexp_preparation_fixture_units(fields[5])!, row
					}
				}
			}
			'bits' {
				assert int(regexp_to_flag_bits(input)) == fields[5].int(), row
			}
			'parse' {
				if result := parse_regex_pattern(input, fields[1] == '1', fields[2] == '1') {
					assert fields[4] == 'ok'
						&& result == regexp_preparation_fixture_units(fields[5])!, row
				} else {
					assert fields[4] == 'error' && err is ParseRegexPatternError, row
					if err is ParseRegexPatternError {
						assert err.error == regexp_preparation_fixture_units(fields[5])!, row
					}
				}
			}
			'escape' {
				assert fields[4] == 'ok', row
				assert escape_regexp_pattern(input) == regexp_preparation_fixture_units(fields[5])!, row
			}
			else {
				assert false, row
			}
		}

		assert input.data == original, row
		count++
	}
	assert count == 9202
}
