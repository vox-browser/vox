// Retain native canvas element identity across the compact DOM replay pass.
module browserjs

import dom

pub type CanvasElementProvider = fn () map[string]&dom.Element

pub type CanvasElementLookup = fn (string) ?&dom.Element

pub type CanvasElementIdentityLookup = fn (&dom.Element) ?string

struct CanvasElementBindingProvider {
	snapshot CanvasElementProvider
	lookup   CanvasElementLookup = unsafe { nil }
	identity_lookup CanvasElementIdentityLookup = unsafe { nil }
}

pub fn (mut runtime Runtime) add_canvas_element_provider(provider CanvasElementProvider) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{ snapshot: provider }
}

pub fn (mut runtime Runtime) add_canvas_element_provider_with_lookup(provider CanvasElementProvider, lookup CanvasElementLookup) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{ snapshot: provider, lookup: lookup }
}

pub fn (mut runtime Runtime) add_canvas_element_provider_with_identity_lookup(provider CanvasElementProvider,
	lookup CanvasElementLookup, identity_lookup CanvasElementIdentityLookup) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{
		snapshot: provider
		lookup: lookup
		identity_lookup: identity_lookup
	}
}

// A provider's reverse index is a candidate, not an override of registry
// order. Validate its key through the normal lookup so later providers still
// win collisions. Legacy providers and newly materialized elements retain the
// complete snapshot fallback.
pub fn (runtime &Runtime) canvas_element_key_for_binding(element &dom.Element) ?string {
	for provider in runtime.canvas_element_providers_ {
		if provider.identity_lookup == unsafe { nil } { continue }
		key := provider.identity_lookup(element) or { continue }
		registered := runtime.canvas_element_for_binding(key) or { continue }
		if voidptr(registered) == voidptr(element) { return key }
	}
	for key, registered in runtime.canvas_elements_for_binding() {
		if voidptr(registered) == voidptr(element) { return key }
	}
	return none
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
