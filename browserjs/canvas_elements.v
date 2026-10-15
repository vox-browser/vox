// Retain native canvas element identity across the compact DOM replay pass.
module browserjs

import dom

pub type CanvasElementProvider = fn () map[string]&dom.Element

pub type CanvasElementLookup = fn (string) ?&dom.Element

struct CanvasElementBindingProvider {
	snapshot CanvasElementProvider
	lookup   CanvasElementLookup = unsafe { nil }
}

pub fn (mut runtime Runtime) add_canvas_element_provider(provider CanvasElementProvider) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{ snapshot: provider }
}

pub fn (mut runtime Runtime) add_canvas_element_provider_with_lookup(provider CanvasElementProvider, lookup CanvasElementLookup) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{ snapshot: provider, lookup: lookup }
}

pub fn (runtime &Runtime) canvas_elements_for_binding() map[string]&dom.Element {
	mut elements := map[string]&dom.Element{}
	for provider in runtime.canvas_element_providers_ {
		for key, element in provider.snapshot() {
			elements[key] = element
		}
	}
	return elements
}

// Replay only needs the wrappers named by its pending mutations. Batch legacy
// providers so they still produce one snapshot, while native providers resolve
// those keys without copying every retained element into temporary maps.
pub fn (runtime &Runtime) canvas_elements_for_keys(keys []string) map[string]&dom.Element {
	mut elements := map[string]&dom.Element{}
	if keys.len == 0 { return elements }
	for provider in runtime.canvas_element_providers_ {
		if provider.lookup != unsafe { nil } {
			for key in keys {
				if element := provider.lookup(key) {
					elements[key] = element
				}
			}
		} else {
			snapshot := provider.snapshot()
			for key in keys {
				if element := snapshot[key] {
					elements[key] = element
				}
			}
		}
	}
	return elements
}

// Resolve one wrapper without cloning every host's entire element map. Keep
// provider order and the legacy snapshot fallback: later providers still win.
pub fn (runtime &Runtime) canvas_element_for_binding(key string) ?&dom.Element {
	mut found := ?&dom.Element(none)
	for provider in runtime.canvas_element_providers_ {
		if provider.lookup != unsafe { nil } {
			if element := provider.lookup(key) {
				found = element
			}
		} else {
			elements := provider.snapshot()
			if key in elements {
				found = unsafe { elements[key] }
			}
		}
	}
	return found
}
