module css

import dom
import platform

fn ancestor_visit_element(mut document dom.Document, tag string, classes string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/2000/svg', tag) or { panic(err) }
	element.set_attribute_value('id', 'PaReNt')
	element.set_attribute_value('class', classes)
	element.set_attribute_value('DATA-Mixed', 'value')
	return element
}

fn test_saved_ancestor_hashes_preserve_counts_folding_saturation_and_non_lifo_removal() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		if quirks { document.set_quirks_mode(.yes) }
		first := ancestor_visit_element(mut document, 'linearGradient', 'A a a\tB\nC\rD\fE Étage ÉTAGE')
		second := ancestor_visit_element(mut document, 'clipPath', 'x '.repeat(260))
		third := ancestor_visit_element(mut document, 'path', 'third third')
		mut computer := StyleComputer.new(document)
		mut expected := CountingBloomFilter.new()
		for element in [first, second, third, first] {
			computer.push_ancestor(element)
			expected.update_element_hashes(element, true)
			assert computer.ancestor_filter_.buckets == expected.buckets
		}
		for element in [second, first, third, first] {
			computer.pop_ancestor(element)
			expected.update_element_hashes(element, false)
			assert computer.ancestor_filter_.buckets == expected.buckets
		}
		assert computer.ancestor_filter_.ancestor_visits.len == 0
		assert computer.ancestor_filter_.ancestor_hashes.len == 0
		computer.reset_ancestor_filter()
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
}

fn test_saved_ancestor_removal_uses_the_hashes_added_before_synchronous_attribute_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := ancestor_visit_element(mut document, 'g', 'old old')
	mut computer := StyleComputer.new(document)
	mut expected := CountingBloomFilter.new()
	computer.push_ancestor(element)
	expected.update_element_hashes(element, true)
	element.set_attribute_value('id', 'different')
	element.set_attribute_value('class', 'new')
	element.remove_attribute('DATA-Mixed')
	element.set_attribute_value('data-new', 'new')
	computer.pop_ancestor(element)
	if retain_ancestor_rehash {
		expected.update_element_hashes(element, false)
		assert computer.ancestor_filter_.buckets == expected.buckets
	} else {
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
	computer.reset_ancestor_filter()
	computer.push_ancestor(element)
	computer.pop_ancestor(element)
	assert computer.ancestor_filter_.buckets.all(it == 0)
}

fn test_saved_ancestor_buffers_reuse_capacity_and_clear_discards_retired_frames() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := ancestor_visit_element(mut document, 'g', 'first first')
	second := ancestor_visit_element(mut document, 'path', 'second')
	mut computer := StyleComputer.new(document)
	computer.push_ancestor(first)
	computer.push_ancestor(second)
	computer.reset_ancestor_filter()
	assert computer.ancestor_filter_.ancestor_visits.len == 0
	assert computer.ancestor_filter_.ancestor_hashes.len == 0
	frame_backing := computer.ancestor_filter_.ancestor_visits.data
	hash_backing := computer.ancestor_filter_.ancestor_hashes.data
	mut scope := document.enter_native_storage()
	defer { scope.finish() }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 512 {
		computer.push_ancestor(first)
		computer.push_ancestor(second)
		computer.pop_ancestor(first)
		computer.pop_ancestor(second)
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
	assert computer.ancestor_filter_.ancestor_visits.data == frame_backing
	assert computer.ancestor_filter_.ancestor_hashes.data == hash_backing
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 1024
	}
}

fn test_saved_ancestor_hash_buffers_outlive_the_query_scratch_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer {
		document.finalize()
		document.release_native_storage()
	}
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut computer := StyleComputer.new(document)
	element := ancestor_visit_element(mut document, 'g', 'retained retained')
	owner.finish()
	scratch := platform.begin_thread_scratch('ancestor query hash publication')
	computer.push_ancestor(element)
	scratch.finish()
	$if prealloc {
		if !retain_ancestor_rehash {
			assert document.native_storage().arena.contains(computer.ancestor_filter_.ancestor_visits.data)
			assert document.native_storage().arena.contains(computer.ancestor_filter_.ancestor_hashes.data)
		}
	}
	computer.pop_ancestor(element)
	assert computer.ancestor_filter_.buckets.all(it == 0)
}
