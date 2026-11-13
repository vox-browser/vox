module libjs

import encoding.hex
import vunicode

fn regex_property_fixture_bit(value bool) string {
	return if value { '1' } else { '0' }
}

fn regex_property_fixture_meta(name string, value ?string) string {
	resolved := if property := regex_resolve_property(name, value) {
		'${int(property.kind)}:${property.id}'
	} else {
		'-'
	}
	return '${resolved}:${regex_property_fixture_bit(regex_is_valid_ecma262_property(name, value))}:${regex_property_fixture_bit(regex_is_string_property(name))}'
}

fn regex_property_fixture_alias(kind u32, id u32, choice u32) string {
	aliases := match kind {
		0 { vunicode.category_aliases }
		1 { vunicode.property_aliases }
		else { vunicode.script_aliases }
	}
	if id >= u32(aliases.len) || choice > 2 { return '-' }
	name := aliases[int(id)][int(choice)]
	if name == '' { return '-' }
	variants := [name, name.to_lower(), name.to_upper(), name.replace('_', ''), name.replace('_', '-'),
		' ${name}', '${name} ', '${name}\x00']
	keys := match kind {
		0 { ['gc', 'General_Category'] }
		1 { []string{} }
		2 { ['sc', 'Script', 'scx', 'Script_Extensions'] }
		else { panic('Unknown alias kind') }
	}

	mut values := []string{}
	for variant in variants {
		values << regex_property_fixture_meta(variant, none)
		for key in keys {
			values << regex_property_fixture_meta(key, variant)
		}
	}
	return '${hex.encode(name.bytes())}|${values.join('|')}'
}

fn regex_property_fixture_bits(point u32) string {
	names := ['Lu', 'Ll', 'Letter', 'ASCII', 'Any', 'Assigned', 'Lowercase', 'gc', 'Script', 'scx',
		'Emoji', 'Full_Composition_Exclusion', 'unknown', 'gc', 'Cn', 'Uppercase']
	mut result := ''
	for index, name in names {
		value := match index {
			7 { ?string('Cs') }
			8 { ?string('Greek') }
			9 { ?string('Hira') }
			13 { ?string('') }
			else { ?string(none) }
		}

		resolved := if property := regex_resolve_property(name, value) {
			regex_resolved_property_matches(point, property)
		} else {
			false
		}
		n := u32(if regex_property_matches(point, name, value) { 1 } else { 0 }) | (u32(if regex_property_matches_case_insensitive(point,
			name, value)
		{
			1
		} else {
			0
		}) << 1) | (u32(if regex_property_all_case_equivalents_match(point, name, value) {
			1
		} else {
			0
		}) << 2) | (u32(if resolved { 1 } else { 0 }) << 3)
		result += n.hex()
	}
	return '${result}|${regex_property_fixture_bit(regex_has_space_separator_category(point))}${regex_property_fixture_bit(regex_has_identifier_start_property(point))}${regex_property_fixture_bit(regex_has_identifier_continue_property(point))}'
}

fn regex_property_fixture_result(fields []string) string {
	point := u32(fields[1].parse_uint(10, 32) or { panic(err) })
	a := u32(fields[2].parse_uint(10, 32) or { panic(err) })
	b := u32(fields[3].parse_uint(10, 32) or { panic(err) })
	return match fields[0] {
		'alias' {
			regex_property_fixture_alias(point, a, b)
		}
		'bits' {
			regex_property_fixture_bits(point)
		}
		'low' {
			matched := match a {
				0 { regex_unicode_has_general_category(point, b, fields[4] == '1') }
				1 { regex_unicode_has_property(point, b, fields[4] == '1') }
				2 { regex_unicode_has_script(point, b) }
				3 { regex_unicode_has_script_extension(point, b) }
				else { panic('Unknown low-level property kind') }
			}

			regex_property_fixture_bit(matched)
		}
		'strings' {
			data := regex_get_string_property_data(fields[4])
			capacity := match a {
				0 {
					0
				}
				1 {
					1
				}
				2 {
					if data.len == 0 { 0 } else { data.len - 1 }
				}
				3 {
					data.len
				}
				4 {
					data.len + 2
				}
				else {
					panic('Unknown buffer capacity selector')
				}
			}

			mut output := []u32{len: capacity, init: 0xffffffff}
			written := regex_get_string_property_data_into(fields[4], mut output)
			'${written}|${output.map(it.str()).join(',')}|${data.map(it.str()).join(',')}'
		}
		else {
			panic('Unknown Unicode property fixture ${fields[0]}')
		}
	}
}

fn test_regex_unicode_properties_match_every_native_output_exactly() {
	fixtures := [$embed_file('testdata/regex-properties.tsv').to_string(),
		$embed_file('testdata/regex-properties-bmp.tsv').to_string(),
		$embed_file('testdata/regex-properties-strings.tsv').to_string()]
	mut count := 0
	mut failures := 0
	for fixture in fixtures {
		for line in fixture.split_into_lines() {
			if line == '' || line.starts_with('#') {
				continue
			}
			fields := line.split('\t')
			assert fields.len == 6, line
			actual := regex_property_fixture_result(fields)
			if actual != fields[5] {
				if failures < 20 {
					mut first := 0
					for first < actual.len && first < fields[5].len && actual[first] == fields[5][first] {
						first++
					}
					end := if first + 60 < actual.len { first + 60 } else { actual.len }
					expected_end := if first + 60 < fields[5].len {
						first + 60
					} else {
						fields[5].len
					}
					eprintln('${fields[..5]} diff at ${first}, len=${actual.len}/${fields[5].len}: ${actual[first..end]} expected=${fields[5][first..expected_end]}')
				}
				failures++
			}
			count++
		}
	}
	assert count == 129233
	assert failures == 0
}
