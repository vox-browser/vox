module css

import dom
import platform

fn (mut filter CountingBloomFilter) update_element_hashes_legacy(element &dom.Element, adding bool) {
	filter.update_element_hash(selector_string_hash(to_ascii_lowercase(element.local_name())), adding)
	quirks := element.document() != unsafe { nil } && element.document().in_quirks_mode()
	if id := element.id() {
		name := if quirks { to_ascii_lowercase(id) } else { id }
		filter.update_element_hash(selector_string_hash(name), adding)
	}
	if class_attribute := element.get_attribute('class') {
		for class_name in class_attribute.fields() {
			name := if quirks { to_ascii_lowercase(class_name) } else { class_name }
			filter.update_element_hash(selector_string_hash(name), adding)
		}
	}
	if attributes := element.attribute_list() {
		for index in 0 .. attributes.length() {
			if attribute := attributes.item(index) {
				filter.update_element_hash(selector_string_hash(to_ascii_lowercase(attribute.name())), adding)
			}
		}
	}
}

fn test_ascii_folded_ancestor_hash_matches_string_folding_for_every_byte() {
	for code in 0 .. 256 {
		value := [u8(code), `A`, `Z`, u8(code)].bytestr()
		assert selector_ascii_lowercase_hash(value) == selector_string_hash(to_ascii_lowercase(value))
	}
	for value in ['', 'Étage', 'ÉTAGE', '日本語ABC😀', 'aB\u0000Z'] {
		assert selector_ascii_lowercase_hash(value) == selector_string_hash(to_ascii_lowercase(value))
	}
}

fn test_borrowed_ancestor_class_spans_preserve_legacy_whitespace_names_and_counts_without_growth() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		if quirks { document.set_quirks_mode(.yes) }
		mut element := document.create_element_ns('http://www.w3.org/2000/svg', 'linearGradient')!
		element.set_attribute_value('id', 'PaReNtÉ')
		element.set_attribute_value('DATA-Mixed', 'value')
		for classes in ['', 'One one one', '  A\tB\nC\rD\fE\vF\u00a0G  A ', 'Étage ÉTAGE'] {
			element.set_attribute_value('class', classes)
			mut actual := CountingBloomFilter.new()
			mut expected := CountingBloomFilter.new()
			actual.update_element_hashes(element, true)
			expected.update_element_hashes_legacy(element, true)
			assert actual.buckets == expected.buckets
			actual.update_element_hashes(element, false)
			expected.update_element_hashes_legacy(element, false)
			assert actual.buckets == expected.buckets
			assert actual.buckets.all(it == 0)
			before := platform.thread_arena_usage().used
			for _ in 0 .. 128 {
				actual.update_element_hashes(element, true)
				actual.update_element_hashes(element, false)
			}
			$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
			assert actual.buckets.all(it == 0)
		}
	}
}
