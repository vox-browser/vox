module browserjs

import dom

@[heap]
struct ElementLookupFixture {
mut:
	elements       map[string]&dom.Element
	snapshot_calls int
}

fn test_keyed_element_lookup_observes_live_maps_without_materializing_snapshots() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element('canvas') or { panic(err) }
	second := document.create_element('img') or { panic(err) }
	mut fixture := &ElementLookupFixture{ elements: {
		'key': first
	} }
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.add_canvas_element_provider_with_lookup(fn [mut fixture] () map[string]&dom.Element {
		fixture.snapshot_calls++
		return fixture.elements.clone()
	}, fn [fixture] (key string) ?&dom.Element {
		if key !in fixture.elements { return none }
		return unsafe { fixture.elements[key] }
	})
	for _ in 0 .. 100 {
		assert voidptr(runtime.canvas_element_for_binding('key') or { panic('missing element') }) == voidptr(first)
		assert runtime.canvas_element_for_binding('missing') == none
	}
	assert fixture.snapshot_calls == 0
	fixture.elements['key'] = second
	assert voidptr(runtime.canvas_element_for_binding('key') or { panic('missing replacement') }) == voidptr(second)
	assert voidptr(runtime.canvas_elements_for_binding()['key'] or { panic('missing snapshot') }) == voidptr(second)
	assert fixture.snapshot_calls == 1
	fixture.elements.delete('key')
	assert runtime.canvas_element_for_binding('key') == none
}

fn test_keyed_element_lookup_preserves_provider_precedence_and_legacy_fallback() {
	document := dom.Document.create(dom.url_about_blank())
	first := document.create_element('canvas') or { panic(err) }
	second := document.create_element('img') or { panic(err) }
	mut fixture := &ElementLookupFixture{ elements: {
		'key': second
	} }
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.add_canvas_element_provider(fn [first] () map[string]&dom.Element {
		return {
			'key': first
		}
	})
	runtime.add_canvas_element_provider_with_lookup(fn [fixture] () map[string]&dom.Element {
		return fixture.elements.clone()
	}, fn [fixture] (key string) ?&dom.Element {
		if key !in fixture.elements { return none }
		return unsafe { fixture.elements[key] }
	})
	assert voidptr(runtime.canvas_element_for_binding('key') or { panic('missing later provider') }) == voidptr(second)
	fixture.elements.delete('key')
	assert voidptr(runtime.canvas_element_for_binding('key') or { panic('missing fallback') }) == voidptr(first)
	runtime.add_canvas_element_provider(fn [second] () map[string]&dom.Element {
		return {
			'key': second
		}
	})
	assert voidptr(runtime.canvas_element_for_binding('key') or { panic('missing last provider') }) == voidptr(second)
}
