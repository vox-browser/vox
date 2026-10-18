module css

import dom

fn test_selector_substring_search_respects_slice_bounds_and_pattern_sizes() {
	texts := ['', 'a', 'ababa', 'before-MiXeD-after', 'éÉKkİi', 'a'.repeat(80) + 'b',
		'0123456789'.repeat(8), 'before\x00after']
	for text in texts {
		for begin in 0 .. text.len + 1 {
			for end in begin .. text.len + 1 {
				needle := text[begin..end]
				for value in [text, text[..begin], text[end..], 'absent'] {
					assert selector_string_contains(value, needle, .case_sensitive) == value.contains(needle)
					assert selector_string_contains(value, needle, .case_insensitive) == to_ascii_lowercase(value).contains(to_ascii_lowercase(needle))
				}
			}
		}
	}
	backing := 'abcNEEDLE'
	assert !selector_string_contains(backing[..3], 'NEEDLE', .case_sensitive)
	for size in [1, 20, 21, 31, 32, 33, 64] {
		needle := 'a'.repeat(size) + 'b'
		assert !selector_string_contains('a'.repeat(512), needle, .case_sensitive)
		assert selector_string_contains('a'.repeat(512) + 'b', needle, .case_sensitive)
	}
}

fn test_attribute_substring_flags_fold_only_ascii_on_fast_and_general_paths() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('data-value', 'MiXeD-ÉK-end')
	for expression, expected in {
		'[data-value*=mixed i]':    true
		'[data-value*=mixed s]':    false
		'[data-value*=É i]':        true
		'[data-value*=é i]':        false
		'[data-value*=k i]':        false
		'[data-value^=mixed i]':    true
		'[data-value$=END i]':      true
		'[data-value$="éK-end" i]': false
		'[data-value*=""]':         false
		'[data-value^=""]':         false
		'[data-value$=""]':         false
	} {
		for suffix in ['', ':is(*)'] {
			list := parse_selector_with_parser(expression + suffix, {}) or { panic(expression) }
			selector := list.selectors[0]
			mut context := MatchContext{
				subject: element
			}
			assert matches(selector, element, none, mut context, none, none, .normal, none) == expected, expression + suffix
		}
	}
	element.set_attribute_value('data-value', 'A'.repeat(64) + 'É')
	assert selector_string_contains(element.get_attribute_value('data-value'),
		'a'.repeat(64) + 'É', .case_insensitive)
	assert !selector_string_contains(element.get_attribute_value('data-value'), 'a'.repeat(64) +
		'é', .case_insensitive)
}
