module browserjs

import dom

@[heap]
struct CanvasIdentityLookupProbe {
mut:
	snapshots int
	elements  map[string]&dom.Element
	keys      map[voidptr]string
}

fn install_canvas_identity_probe(mut runtime Runtime, probe &CanvasIdentityLookupProbe) {
	runtime.add_canvas_element_provider_with_identity_lookup(fn [probe] () map[string]&dom.Element {
		mut current := unsafe { &CanvasIdentityLookupProbe(probe) }
		current.snapshots++
		return current.elements.clone()
	}, fn [probe] (key string) ?&dom.Element {
		return probe.elements[key] or { return none }
	}, fn [probe] (element &dom.Element) []string {
		mut keys := []string{}
		if key := probe.keys[voidptr(element)] { keys << key }
		for key, candidate in probe.elements {
			if voidptr(candidate) == voidptr(element) && key !in keys { keys << key }
		}
		return keys
	})
}

fn test_canvas_identity_lookup_avoids_snapshots_and_preserves_distinct_equal_elements() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('button')!
	second := document.create_element('button')!
	probe := &CanvasIdentityLookupProbe{
		elements: {
			'first':  first
			'second': second
		}
		keys:     {
			voidptr(first):  'first'
			voidptr(second): 'second'
		}
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_canvas_identity_probe(mut runtime, probe)
	for _ in 0 .. 100 {
		assert runtime.canvas_element_key_for_binding(first)? == 'first'
		assert runtime.canvas_element_key_for_binding(second)? == 'second'
	}
	assert probe.snapshots == 0
}

fn test_canvas_identity_lookup_honors_later_collisions_and_legacy_provider_fallback() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('button')!
	second := document.create_element('button')!
	legacy_element := document.create_element('a')!
	first_probe := &CanvasIdentityLookupProbe{
		elements: {
			'shared': first
			'alias':  first
		}
		keys:     {
			voidptr(first): 'shared'
		}
	}
	second_probe := &CanvasIdentityLookupProbe{
		elements: {
			'shared': second
		}
		keys:     {
			voidptr(second): 'shared'
		}
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_canvas_identity_probe(mut runtime, first_probe)
	install_canvas_identity_probe(mut runtime, second_probe)
	assert runtime.canvas_element_key_for_binding(first)? == 'alias'
	assert runtime.canvas_element_key_for_binding(second)? == 'shared'
	runtime.add_canvas_element_provider(fn [legacy_element] () map[string]&dom.Element {
		return {
			'legacy': legacy_element
		}
	})
	assert runtime.canvas_element_key_for_binding(legacy_element)? == 'legacy'
	assert voidptr(runtime.canvas_element_for_binding('shared')?) == voidptr(second)
}

fn test_canvas_identity_lookup_missing_or_removed_owners_do_not_snapshot_indexed_providers() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := document.create_element('button')!
	missing := document.create_element('button')!
	mut probe := &CanvasIdentityLookupProbe{
		elements: {
			'first': first
		}
		keys:     {
			voidptr(first): 'first'
		}
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_canvas_identity_probe(mut runtime, probe)
	for _ in 0 .. 100 {
		assert runtime.canvas_element_key_for_binding(missing) == none
	}
	probe.elements.delete('first')
	probe.keys.delete(voidptr(first))
	assert runtime.canvas_element_key_for_binding(first) == none
	assert probe.snapshots == 0
}

fn test_canvas_identity_lookup_preserves_provider_order_across_legacy_and_indexed_aliases() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('button')!
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.add_canvas_element_provider(fn [element] () map[string]&dom.Element {
		return {'earlier': element}
	})
	probe := &CanvasIdentityLookupProbe{
		elements: {'later': element}
		keys: {voidptr(element): 'later'}
	}
	install_canvas_identity_probe(mut runtime, probe)
	assert runtime.canvas_element_key_for_binding(element)? == 'earlier'
}
