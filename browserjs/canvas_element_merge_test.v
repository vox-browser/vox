module browserjs

import dom

@[heap]
struct CanvasMergeProbe {
mut:
	snapshots int
	elements  map[string]&dom.Element
}

fn install_canvas_merge_probe(mut runtime Runtime, probe &CanvasMergeProbe) {
	runtime.add_canvas_element_provider_with_merge(fn [probe] () map[string]&dom.Element {
		mut current := unsafe { &CanvasMergeProbe(probe) }
		current.snapshots++
		return current.elements.clone()
	}, fn [probe] (key string) ?&dom.Element {
		return probe.elements[key] or { return none }
	}, fn [probe] (element &dom.Element) []string {
		return native_canvas_element_identity_keys(probe.elements, element)
	}, fn [probe] (registry &CanvasElementRegistry) {
		for key, element in probe.elements { registry.set(key, element) }
	})
}

// Merging into a host's map must match copying canvas_elements_for_binding()
// into it: later providers win, new keys keep their first-seen order, and
// the providers' maps are not copied.
fn test_canvas_element_merge_matches_the_copied_snapshot_without_copies() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	a := document.create_element('a')!
	b := document.create_element('b')!
	c := document.create_element('i')!
	first := &CanvasMergeProbe{ elements: { 'shared': a, 'first': a } }
	second := &CanvasMergeProbe{ elements: { 'shared': b, 'second': c } }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_canvas_merge_probe(mut runtime, first)
	install_canvas_merge_probe(mut runtime, second)
	mut merged := map[string]&dom.Element{}
	merged['own'] = c
	runtime.merge_canvas_elements_into(mut merged)
	assert first.snapshots == 0 && second.snapshots == 0
	expected := runtime.canvas_elements_for_binding()
	assert merged.keys() == ['own', 'shared', 'first', 'second']
	for key, element in expected {
		assert voidptr(merged[key] or { panic(key) }) == voidptr(element), key
	}
	// A provider that later rebinds a key wins on the next merge.
	mut changed := unsafe { &CanvasMergeProbe(second) }
	changed.elements['second'] = a
	runtime.merge_canvas_elements_into(mut merged)
	assert voidptr(merged['second'] or { panic('second') }) == voidptr(a)
	assert voidptr(merged['shared'] or { panic('shared') }) == voidptr(b)
}

fn test_wheel_registry_refresh_skips_non_element_targets() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	assert event_target_is_element(unsafe { &dom.EventTarget(element) })
	assert !event_target_is_element(unsafe { &dom.EventTarget(document) })
	text := document.create_text_node('x')
	assert !event_target_is_element(unsafe { &dom.EventTarget(text) })
}
