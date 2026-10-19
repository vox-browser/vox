module browserjs

import dom

@[heap]
struct ElementIdentityFixture {
mut:
	elements map[string]&dom.Element
	snapshots int
	identities int
}

fn install_element_identity_fixture(mut runtime Runtime, mut fixture ElementIdentityFixture) {
	runtime.add_canvas_element_provider_with_identity_lookup(fn [mut fixture] () map[string]&dom.Element {
		fixture.snapshots++
		return fixture.elements.clone()
	}, fn [fixture] (key string) ?&dom.Element {
		return fixture.elements[key] or { return none }
	}, fn [mut fixture] (element &dom.Element) []string {
		fixture.identities++
		mut keys := []string{}
		for key, candidate in fixture.elements {
			if voidptr(candidate) == voidptr(element) { keys << key }
		}
		return keys
	})
}

fn test_identity_lookup_keeps_live_host_keys_without_copying_element_maps() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas') or { panic(err) }
	second := document.create_element('img') or { panic(err) }
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut fixture := &ElementIdentityFixture{elements: {'created': first}}
	install_element_identity_fixture(mut runtime, mut fixture)
	for _ in 0 .. 100 {
		assert runtime.canvas_element_key_for_binding(first)? == 'created'
		assert runtime.canvas_element_key_for_binding(second) == none
	}
	assert fixture.snapshots == 0
	assert fixture.identities == 200
	fixture.elements['created'] = second
	assert runtime.canvas_element_key_for_binding(first) == none
	assert runtime.canvas_element_key_for_binding(second)? == 'created'
	fixture.elements.delete('created')
	assert runtime.canvas_element_key_for_binding(second) == none
	assert fixture.snapshots == 0
}

fn test_identity_lookup_rejects_shadowed_keys_and_uses_remaining_aliases() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas') or { panic(err) }
	second := document.create_element('img') or { panic(err) }
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut earlier := &ElementIdentityFixture{elements: {'shared': first, 'alias': first}}
	mut later := &ElementIdentityFixture{elements: {'shared': second}}
	install_element_identity_fixture(mut runtime, mut earlier)
	install_element_identity_fixture(mut runtime, mut later)
	assert runtime.canvas_element_key_for_binding(first)? == 'alias'
	assert runtime.canvas_element_key_for_binding(second)? == 'shared'
	earlier.elements.delete('alias')
	assert runtime.canvas_element_key_for_binding(first) == none
	later.elements.delete('shared')
	assert runtime.canvas_element_key_for_binding(first)? == 'shared'
	assert earlier.snapshots == 0 && later.snapshots == 0
}

fn test_identity_lookup_supports_legacy_providers() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('canvas') or { panic(err) }
	second := document.create_element('img') or { panic(err) }
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	runtime.add_canvas_element_provider(fn [first] () map[string]&dom.Element {
		return {'legacy': first}
	})
	assert runtime.canvas_element_key_for_binding(first)? == 'legacy'
	mut fixture := &ElementIdentityFixture{elements: {'legacy': second}}
	install_element_identity_fixture(mut runtime, mut fixture)
	assert runtime.canvas_element_key_for_binding(first) == none
	assert runtime.canvas_element_key_for_binding(second)? == 'legacy'
}
