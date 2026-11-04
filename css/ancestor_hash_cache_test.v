module css

import dom
import platform

// Independent original algorithm: own strings/tokens, then hash the exact
// sequence, including duplicate classes and saturated counting buckets.
fn ancestor_cache_reference(mut filter CountingBloomFilter, element &dom.Element, adding bool) {
	filter.update_element_hash(selector_string_hash(to_ascii_lowercase(element.local_name())), adding)
	quirks := element.document().in_quirks_mode()
	if id := element.id() {
		filter.update_element_hash(selector_string_hash(if quirks {
			to_ascii_lowercase(id)
		} else {
			id
		}), adding)
	}
	if classes := element.get_attribute('class') {
		for name in classes.fields() {
			filter.update_element_hash(selector_string_hash(if quirks {
				to_ascii_lowercase(name)
			} else {
				name
			}), adding)
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

fn ancestor_cache_check_visit(mut computer StyleComputer, element &dom.Element) {
	mut expected := CountingBloomFilter.new()
	ancestor_cache_reference(mut expected, element, true)
	computer.push_ancestor(element)
	for index, wanted in expected.buckets {
		actual := computer.ancestor_filter_.buckets[index]
		assert actual == wanted, 'push bucket ${index}; element ${element.as_node().unique_id()}'
	}
	computer.pop_ancestor(element)
	ancestor_cache_reference(mut expected, element, false)
	for index, wanted in expected.buckets {
		actual := computer.ancestor_filter_.buckets[index]
		assert actual == wanted, 'pop bucket ${index}; element ${element.as_node().unique_id()}'
	}
	computer.reset_ancestor_filter()
}

fn ancestor_cache_element(mut document dom.Document, name string, classes string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/2000/svg', name) or { panic(err) }
	element.set_attribute_value('id', 'PaReNtÉ')
	element.set_attribute_value('class', classes)
	element.set_attribute_value('DATA-Mixed', 'value')
	return element
}

fn test_ancestor_hash_cache_preserves_names_whitespace_duplicates_and_quirks_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut computer := StyleComputer.new(document)
	for classes in ['', 'A a a\tB\nC\rD\fE\vF\u00a0G A', 'Étage ÉTAGE 中😀'] {
		element := ancestor_cache_element(mut document, 'linearGradient', classes)
		for quirks in [dom.QuirksMode.no, .yes, .limited, .no] {
			document.set_quirks_mode(quirks)
			for _ in 0 .. 3 { ancestor_cache_check_visit(mut computer, element) }
		}
	}
}

fn test_ancestor_hash_cache_observes_named_map_token_list_and_unrelated_attribute_edits() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut computer := StyleComputer.new(document)
	mut element := ancestor_cache_element(mut document, 'g', 'old old')
	mut other := document.create_element('div') or { panic(err) }
	for _ in 0 .. 2 { ancestor_cache_check_visit(mut computer, element) }
	element.set_attribute_value('id', 'changed')
	ancestor_cache_check_visit(mut computer, element)
	mut tokens := element.class_list()
	tokens.set_value('new new OTHER')
	ancestor_cache_check_visit(mut computer, element)
	mut attributes := element.attributes()
	attributes.set_attribute(&dom.Attr_{ name_: 'class', local_name_: 'class', value_: 'replaced' }) or { panic(err) }
	ancestor_cache_check_visit(mut computer, element)
	element.remove_attribute('DATA-Mixed')
	element.set_attribute_value_ns('fresh', 'value', 'p', 'urn:attributes')
	ancestor_cache_check_visit(mut computer, element)
	other.set_attribute_value('class', 'unrelated epoch')
	ancestor_cache_check_visit(mut computer, element)
	for name in ['id', 'class', 'p:fresh'] {
		element.remove_attribute(name)
		ancestor_cache_check_visit(mut computer, element)
	}
}

fn test_ancestor_hash_cache_distinguishes_adopted_documents_with_equal_attribute_epochs() {
	mut first := dom.Document.create(dom.url_about_blank())
	mut second := dom.Document.create(dom.URL{ value: 'https://adoption.test/' })
	defer {
		first.finalize()
		second.finalize()
	}
	mut element := ancestor_cache_element(mut first, 'path', 'MiXeD mixed')
	second.set_quirks_mode(.yes)
	for second.attribute_version() < first.attribute_version() { second.bump_attribute_version() }
	assert first.attribute_version() == second.attribute_version()
	mut computer := StyleComputer.new(first)
	for _ in 0 .. 2 { ancestor_cache_check_visit(mut computer, element) }
	second.adopt_node(element.as_node())
	for _ in 0 .. 2 { ancestor_cache_check_visit(mut computer, element) }
	second.set_quirks_mode(.no)
	ancestor_cache_check_visit(mut computer, element)
	first.adopt_node(element.as_node())
	ancestor_cache_check_visit(mut computer, element)
}

fn test_ancestor_hash_cache_collisions_and_oversized_saturated_inputs_preserve_the_filter() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut by_slot := map[int]&dom.Element{}
	mut first := unsafe { &dom.Element(nil) }
	mut second := unsafe { &dom.Element(nil) }
	for index in 0 .. ancestor_hash_cache_slots + 1 {
		element := ancestor_cache_element(mut document, 'path', 'class-${index}')
		slot := ancestor_hash_cache_slot(element.as_node().unique_id())
		if previous := by_slot[slot] {
			first = previous
			second = element
			break
		}
		by_slot[slot] = element
	}
	assert first != unsafe { nil } && second != unsafe { nil }
	mut computer := StyleComputer.new(document)
	for element in [first, second, first, second] {
		for _ in 0 .. 2 { ancestor_cache_check_visit(mut computer, element) }
	}
	oversized := ancestor_cache_element(mut document, 'g', 'same '.repeat(300))
	for _ in 0 .. 3 { ancestor_cache_check_visit(mut computer, oversized) }
	cache := computer.ancestor_filter_.ancestor_hash_cache_
	if cache != unsafe { nil } {
		for entry in cache.entries {
			assert entry.hashes.len <= ancestor_hash_cache_max_hashes
		}
	}
}

@[heap]
struct AncestorCacheReentry {
mut:
	computer    &StyleComputer
	element     &dom.Element
	calls       int
	observed_id string
}

fn ancestor_cache_reenter_id_change(opaque voidptr) {
	mut context := unsafe { &AncestorCacheReentry(opaque) }
	context.calls++
	context.observed_id = context.element.id() or { '' }
	ancestor_cache_check_visit(mut context.computer, context.element)
}

fn test_ancestor_hash_cache_rechecks_derived_id_after_reentrant_attribute_callbacks() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := ancestor_cache_element(mut document, 'g', 'kept')
	mut computer := StyleComputer.new(document)
	ancestor_cache_check_visit(mut computer, element)
	mut context := &AncestorCacheReentry{ computer: computer, element: element }
	document.set_editing_history_hook(dom.DocumentEditingHistoryHook{
		target:              context
		notify_dom_mutation: ancestor_cache_reenter_id_change
	})
	element.set_attribute_value('id', 'new-id')
	assert context.calls == 1
	assert context.observed_id == 'PaReNtÉ'
	assert (element.id() or { '' }) == 'new-id'
	// The callback saw the new epoch and the old derived ID. The post-callback
	// query must not reuse that result when the epoch itself has not changed.
	ancestor_cache_check_visit(mut computer, element)
}

fn test_ancestor_hash_cache_owns_scalar_payloads_and_reuses_bounded_storage() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer {
		document.finalize()
		document.release_native_storage()
	}
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	mut computer := StyleComputer.new(document)
	mut element := ancestor_cache_element(mut document, 'g', 'kept kept')
	scope.finish()
	scratch := platform.begin_thread_scratch('ancestor cache publication')
	computer.push_ancestor(element)
	computer.pop_ancestor(element)
	scratch.finish()
	ancestor_cache_check_visit(mut computer, element)
	if !retain_ancestor_hash_recompute {
		cache := computer.ancestor_filter_.ancestor_hash_cache_
		assert cache != unsafe { nil }
		slot := ancestor_hash_cache_slot(element.as_node().unique_id())
		backing := cache.entries[slot].hashes.data
		$if prealloc {
			assert document.native_storage().arena.contains(voidptr(cache))
			assert document.native_storage().arena.contains(backing)
		}
		mut owner := document.enter_native_storage()
		before := platform.thread_arena_usage().used
		for _ in 0 .. 128 {
			computer.push_ancestor(element)
			computer.pop_ancestor(element)
		}
		$if prealloc {
			assert platform.thread_arena_usage().used - before < 1024
		}
		assert cache.entries[slot].hashes.data == backing
		// A same-sized replacement invalidates the epoch but reuses the slot's
		// private buffer; no old strings or DOM references need to stay alive.
		element.set_attribute_value('class', 'next next')
		computer.push_ancestor(element)
		computer.pop_ancestor(element)
		assert cache.entries[slot].hashes.data == backing
		owner.finish()
	}
}
