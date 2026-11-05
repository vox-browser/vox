module css

import dom
import html
import platform

fn short_attribute_test_selector(text string) Selector {
	return (parse_selector_with_parser(text, {'a': true, 'b': true}) or { panic(text) }).selectors[0]
}

fn test_short_attribute_memo_matches_the_byte_oracle_at_every_storage_boundary() {
	mut memo := &ShortAttributeMatchMemo{}
	for length in [16, 17, 31, 32, 63, 127, 255, 256] {
		for pattern_size in [1, 2, 3, 8, 16, 31, 32] {
			for pattern in ['A'.repeat(pattern_size - 1) + 'z', 'éÉKk', '\x00X'] {
				if pattern.len > 32 { continue }
				for text in ['q'.repeat(length), 'q'.repeat(length - 8) + 'MiXeDzZz'] {
					for sensitivity in [SelectorCaseSensitivity.case_sensitive, .case_insensitive] {
						expected := if sensitivity == .case_sensitive { text.contains(pattern) }
							else { to_ascii_lowercase(text).contains(to_ascii_lowercase(pattern)) }
						assert memo.contains(text, pattern, sensitivity) == expected
						before := memo.hits
						assert memo.contains(text.clone(), pattern.clone(), sensitivity) == expected
						assert memo.hits == before + 1
					}
				}
			}
		}
	}
	for byte in 0 .. 256 {
		pattern := [u8(byte)].bytestr()
		value := '12345678' + pattern + 'abcdefgh'
		for sensitivity in [SelectorCaseSensitivity.case_sensitive, .case_insensitive] {
			assert memo.contains(value, pattern, sensitivity)
			assert memo.contains(value, pattern, sensitivity)
		}
	}
}

fn test_short_attribute_memo_checks_interior_bytes_despite_fingerprint_collisions() {
	mut memo := &ShortAttributeMatchMemo{}
	present := '12345678NEEDLE__abcdefgh'
	absent := '12345678absent__abcdefgh'
	assert short_attribute_match_slot(present, 'NEEDLE', .case_sensitive)
		== short_attribute_match_slot(absent, 'NEEDLE', .case_sensitive)
	for _ in 0 .. 8 {
		assert memo.contains(present, 'NEEDLE', .case_sensitive)
		assert !memo.contains(absent, 'NEEDLE', .case_sensitive)
		assert memo.contains(present, 'NEEDLE', .case_sensitive)
	}
	value := '12345678__AXC___abcdefgh'
	assert short_attribute_match_slot(value, 'AXC', .case_sensitive)
		== short_attribute_match_slot(value, 'AYC', .case_sensitive)
	assert memo.contains(value, 'AXC', .case_sensitive)
	assert !memo.contains(value, 'AYC', .case_sensitive)
	assert !memo.contains(value, 'axc', .case_sensitive)
	assert memo.contains(value, 'axc', .case_insensitive)
}

fn test_short_attribute_memo_owns_scratch_inputs_and_overwrites_without_allocating() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computer := StyleComputer.new(document)
	original := '12345678NEEDLE__abcdefgh'
	mut scratch := platform.begin_thread_scratch('attribute memo producer')
	mut input := original.bytes()
	mut pattern_bytes := 'NEEDLE'.bytes()
	pattern := unsafe { tos(pattern_bytes.data, pattern_bytes.len) }
	view := unsafe { tos(input.data, input.len) }
	mut memo := computer.short_attribute_match_memo()
	assert memo.contains(view, pattern, .case_sensitive)
	input[8] = `X`
	pattern_bytes[0] = `X`
	assert view != original && pattern != 'NEEDLE'
	hits_before_mutation := memo.hits
	assert memo.contains(original, 'NEEDLE', .case_sensitive)
	assert memo.hits == hits_before_mutation + 1
	scratch.finish()
	gc_collect()
	mut overwrite := platform.begin_thread_scratch('attribute memo overwrite')
	_ = []u8{len: 4096, init: 0xa5}
	before := memo.hits
	assert memo.contains(original, 'NEEDLE', .case_sensitive)
	assert memo.hits == before + 1
	allocation_before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		assert !memo.contains('12345678absent__abcdefgh', 'NEEDLE', .case_sensitive)
		assert memo.contains(original, 'NEEDLE', .case_sensitive)
	}
	$if prealloc { assert platform.thread_arena_usage().used == allocation_before }
	overwrite.finish()
}

fn test_short_attribute_matching_preserves_fallbacks_and_lazily_allocates_storage() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div') or { panic(err) }
	computer := StyleComputer.new(document)
	for text in ['short', 'x'.repeat(257), 'x'.repeat(32)] {
		element.set_attribute_value('data-value', text)
		attribute := element.get_attribute_node('data-value') or { panic('missing attribute') }
		for operation in [AttributeMatchType.has_attribute, .exact_value_match, .contains_word,
			.starts_with_string, .ends_with_string, .starts_with_segment] {
			selector := SelectorAttribute{match_type: operation, value: 'x'}
			assert matches_single_attribute_with_memo(selector, attribute, .case_sensitive, computer)
				== matches_single_attribute(selector, attribute, .case_sensitive)
		}
		for pattern in ['', 'x'.repeat(33)] {
			selector := SelectorAttribute{match_type: .contains_string, value: pattern}
			assert matches_single_attribute_with_memo(selector, attribute, .case_sensitive, computer)
				== matches_single_attribute(selector, attribute, .case_sensitive)
		}
	}
	assert computer.short_attribute_matches_ == unsafe { nil }
	element.set_attribute_value('data-value', '12345678needle__abcdefgh')
	selector := short_attribute_test_selector('[data-value*=needle]')
	for _ in 0 .. 2 {
		mut context := MatchContext{short_attribute_match_owner: computer}
		assert matches(selector, element, none, mut context, none, none, .normal, none)
	}
	assert (computer.short_attribute_matches_ != unsafe { nil }) == !retain_short_attribute_matching
	if !retain_short_attribute_matching { assert computer.short_attribute_matches_.hits > 0 }
}

fn test_short_attribute_matching_keeps_namespaces_case_and_live_mutations_on_both_paths() {
	for is_html in [true, false] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(if is_html { .html } else { .xml })
		computer := StyleComputer.new(document)
		for namespace in [dom.namespace_html_uri, 'http://www.w3.org/2000/svg'] {
			mut element := document.create_element_ns(namespace, 'g') or { panic(err) }
			element.set_attribute_ns_for_bindings('urn:a', 'a:data-key', '12345678Absent__abcdefgh') or { panic(err) }
			element.set_attribute_ns_for_bindings('urn:b', 'b:data-key', '12345678MiXeD___abcdefgh') or { panic(err) }
			sheet := parse_css_stylesheet_with_parser('@namespace a "urn:a";@namespace b "urn:b";', none)
			for value in ['12345678MiXeD___abcdefgh', '12345678absent__abcdefgh', '12345678MiXeD___abcdefgh'] {
				element.set_attribute_value('data-value', value)
				element.set_attribute_value('type', value)
				for expression in ['[data-value*=MiXeD]', '[data-value*=mixed i]', '[data-value*=mixed s]',
					'[type*=mixed]', '[*|data-key*=mixed i]', '[a|data-key*=mixed i]', '[b|data-key*=mixed i]'] {
					for suffix in ['', ':is(*)'] {
						selector := short_attribute_test_selector(expression + suffix)
						mut original := MatchContext{style_sheet_for_rule: sheet, subject: element}
						mut cached := MatchContext{style_sheet_for_rule: sheet, subject: element, short_attribute_match_owner: computer}
						expected := matches(selector, element, none, mut original, none, none, .normal, none)
						for _ in 0 .. 2 {
							assert matches(selector, element, none, mut cached, none, none, .normal, none) == expected
							assert cached.attempted_pseudo_class_matches == original.attempted_pseudo_class_matches
						}
					}
				}
			}
		}
	}
}

fn test_short_attribute_memo_is_used_by_the_cascade_and_rechecks_changed_values() {
	mut document := html.parse_document('<!doctype html><style>div{display:block}[data-value*="mixed" i]{display:flex}</style><div id="target" data-value="12345678MiXeD___abcdefgh"></div>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing target') }
	computer := css_style_computer_for(document)
	assert computed_value_for(target, .display) or { '' } == 'flex'
	for expected in ['flex', 'block', 'flex'] {
		mut element := unsafe { &dom.Element(target) }
		element.set_attribute_value('data-value', if expected == 'flex' { '12345678MiXeD___abcdefgh' } else { '12345678absent__abcdefgh' })
		for _ in 0 .. 2 {
			mut node := target.as_node()
			node.set_needs_style_update(true)
			assert computed_value_for(target, .display) or { '' } == expected
		}
	}
	assert (computer.short_attribute_matches_ != unsafe { nil }) == !retain_short_attribute_matching
	if !retain_short_attribute_matching { assert computer.short_attribute_matches_.hits > 0 }
}
