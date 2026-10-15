module browserjs

import dom

@[heap]
struct BatchedElementLookupFixture {
mut:
	elements       map[string]&dom.Element
	snapshot_calls int
	lookup_calls   int
}

fn test_batched_element_lookup_retains_only_requested_live_native_elements() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element('canvas')!
	second := document.create_element('img')!
	mut fixture := &BatchedElementLookupFixture{
		elements: {
			'one':    first
			'unused': second
		}
	}
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.add_canvas_element_provider_with_lookup(fn [mut fixture] () map[string]&dom.Element {
		fixture.snapshot_calls++
		return fixture.elements.clone()
	}, fn [mut fixture] (key string) ?&dom.Element {
		fixture.lookup_calls++
		return fixture.elements[key] or { return none }
	})
	first_batch := runtime.canvas_elements_for_keys(['one', 'missing'])
	assert first_batch.len == 1
	assert voidptr(first_batch['one'] or { panic('missing requested element') }) == voidptr(first)
	assert fixture.snapshot_calls == 0
	assert fixture.lookup_calls == 2
	fixture.elements['one'] = second
	second_batch := runtime.canvas_elements_for_keys(['one'])
	assert voidptr(second_batch['one'] or { panic('missing live replacement') }) == voidptr(second)
	assert voidptr(first_batch['one'] or { panic('missing retained result') }) == voidptr(first)
}

fn test_batched_element_lookup_preserves_priority_and_snapshots_legacy_providers_once() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element('canvas')!
	second := document.create_element('img')!
	mut legacy := &BatchedElementLookupFixture{
		elements: {
			'one': first
			'two': second
		}
	}
	mut native := &BatchedElementLookupFixture{
		elements: {
			'one': second
		}
	}
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.add_canvas_element_provider(fn [mut legacy] () map[string]&dom.Element {
		legacy.snapshot_calls++
		return legacy.elements.clone()
	})
	runtime.add_canvas_element_provider_with_lookup(fn [mut native] () map[string]&dom.Element {
		native.snapshot_calls++
		return native.elements.clone()
	}, fn [mut native] (key string) ?&dom.Element {
		native.lookup_calls++
		return native.elements[key] or { return none }
	})
	assert runtime.canvas_elements_for_keys([]).len == 0
	assert legacy.snapshot_calls == 0
	assert native.lookup_calls == 0
	batch := runtime.canvas_elements_for_keys(['one', 'two', 'missing'])
	assert batch.len == 2
	assert voidptr(batch['one'] or { panic('missing later provider') }) == voidptr(second)
	assert voidptr(batch['two'] or { panic('missing legacy provider') }) == voidptr(second)
	assert legacy.snapshot_calls == 1
	assert native.snapshot_calls == 0
	native.elements.delete('one')
	fallback := runtime.canvas_elements_for_keys(['one'])
	assert voidptr(fallback['one'] or { panic('missing fallback') }) == voidptr(first)
	assert legacy.snapshot_calls == 2
}
