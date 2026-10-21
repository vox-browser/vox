module layout

import dom
import platform

fn test_counter_keys_keep_elements_and_all_pseudo_element_types_distinct() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('div') or { panic(err) }
	second := document.create_element('div') or { panic(err) }
	mut keys := map[i64]bool{}
	for element in [first, second] {
		plain := dom.AbstractElement.new(element, none)
		plain_key := abstract_element_counter_key(plain)
		assert plain_key >= 0 && plain_key !in keys
		keys[plain_key] = true
		for index in 0 .. int(dom.PseudoElement.unknown_webkit) + 1 {
			pseudo := unsafe { dom.PseudoElement(index) }
			target := dom.AbstractElement.new(element, pseudo)
			key := abstract_element_counter_key(target)
			assert key >= 0 && key !in keys
			keys[key] = true
		}
	}
	assert keys.len == 2 * (int(dom.PseudoElement.unknown_webkit) + 2)
}

fn test_counter_lookup_keys_do_not_accumulate_formatted_strings() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div') or { panic(err) }
	plain := dom.AbstractElement.new(element, none)
	marker := dom.AbstractElement.new(element, .marker)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		assert abstract_element_counter_key(plain) >= 0
		assert abstract_element_counter_key(marker) != abstract_element_counter_key(plain)
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}
