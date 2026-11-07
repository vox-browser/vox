// Retain native canvas element identity across the compact DOM replay pass.
module browserjs

import dom
import platform

pub type CanvasElementProvider = fn () map[string]&dom.Element

pub type CanvasElementLookup = fn (string) ?&dom.Element

pub type CanvasElementIdentityLookup = fn (&dom.Element) []string

// Writes a provider's wrappers into the registry without first copying them.
pub type CanvasElementMerge = fn (&CanvasElementRegistry)

@[heap]
pub struct CanvasElementRegistry {
mut:
	elements map[string]&dom.Element
}

pub fn (registry &CanvasElementRegistry) set(key string, element &dom.Element) {
	mut owner := unsafe { &CanvasElementRegistry(registry) }
	owner.elements[key] = element
}

struct CanvasElementBindingProvider {
	@[required]
	snapshot CanvasElementProvider
	lookup   CanvasElementLookup = unsafe { nil }
	identity CanvasElementIdentityLookup = unsafe { nil }
	merge    CanvasElementMerge = unsafe { nil }
}

// DOM identity is the native address. V's equality for &Element compares the
// complete record and can allocate copies of its maps on every candidate.
// Preserve every alias in map order so registry precedence remains unchanged.
fn native_canvas_element_identity_keys(elements map[string]&dom.Element, element &dom.Element) []string {
	// The old compiler clones every named string key in a map loop, even on
	// a miss. Inspect values first so unrelated native hosts allocate nothing.
	mut found := false
	for _, candidate in elements {
		if voidptr(candidate) == voidptr(element) { found = true; break }
	}
	if !found { return []string{} }
	mut keys := []string{}
	for key, candidate in elements {
		if voidptr(candidate) == voidptr(element) { keys << key }
	}
	return keys
}

pub fn (mut runtime Runtime) add_canvas_element_provider(provider CanvasElementProvider) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{ snapshot: provider }
}

pub fn (mut runtime Runtime) add_canvas_element_provider_with_lookup(provider CanvasElementProvider, lookup CanvasElementLookup) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{ snapshot: provider, lookup: lookup }
}

pub fn (mut runtime Runtime) add_canvas_element_provider_with_identity_lookup(provider CanvasElementProvider,
	lookup CanvasElementLookup, identity CanvasElementIdentityLookup) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{
		snapshot: provider
		lookup: lookup
		identity: identity
	}
}

pub fn (mut runtime Runtime) add_canvas_element_provider_with_merge(provider CanvasElementProvider,
	lookup CanvasElementLookup, identity CanvasElementIdentityLookup, merge CanvasElementMerge) {
	runtime.canvas_element_providers_ << CanvasElementBindingProvider{
		snapshot: provider
		lookup: lookup
		identity: identity
		merge: merge
	}
}

// Merge every registered wrapper into `elements` exactly as copying
// canvas_elements_for_binding() into it would: later providers win and new
// keys keep their first-seen order. Providers only drop wrappers when the
// runtime closes, so the runtime's registry keeps the complete union and is
// refreshed in place. Hosts call this for each newly seen event target or
// canvas call; copying every provider's map each time made a GitHub page load
// allocate hundreds of megabytes that the prealloc arena never reclaims.
pub fn (runtime &Runtime) merge_canvas_elements_into(mut elements map[string]&dom.Element) {
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &Runtime(runtime) }
	if owner.canvas_element_registry_ == unsafe { nil } {
		owner.canvas_element_registry_ = &CanvasElementRegistry{}
	}
	registry := owner.canvas_element_registry_
	for provider in runtime.canvas_element_providers_ {
		if provider.merge != unsafe { nil } {
			provider.merge(registry)
		} else {
			for key, element in provider.snapshot() {
				registry.set(key, element)
			}
		}
	}
	for key, element in registry.elements {
		elements[key] = element
	}
}

// Reverse indexes supply every alias they own. Resolve candidates through the
// registry so later providers retain key precedence. An indexed miss does not
// require copying that provider's complete map. Keep provider order when an
// element has different aliases in legacy and indexed providers.
pub fn (runtime &Runtime) canvas_element_key_for_binding(element &dom.Element) ?string {
	for provider in runtime.canvas_element_providers_ {
		if provider.identity != unsafe { nil } {
			for key in provider.identity(element) {
				registered := runtime.canvas_element_for_binding(key) or { continue }
				if voidptr(registered) == voidptr(element) { return key }
			}
		} else {
			for key, candidate in provider.snapshot() {
				if voidptr(candidate) != voidptr(element) { continue }
				registered := runtime.canvas_element_for_binding(key) or { continue }
				if voidptr(registered) == voidptr(element) { return key }
			}
		}
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
