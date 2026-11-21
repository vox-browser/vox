// Retain native canvas element identity across the compact DOM replay pass.
module browserjs

import dom
import os
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
// Same-binary control: scan each host's element map for every lookup.
const retain_identity_key_scans = os.getenv('VOX_RETAIN_IDENTITY_KEY_SCANS') != ''

// Reverse index of one host's element map. Hosts register every element of
// the document when they are created (~2,700 on GitHub), so scanning five
// such maps made each element's first bridge key lookup cost ~200K
// instructions. The index owns its keys and is rebuilt when the map changes
// size; each candidate is checked against the map before it is returned.
struct ElementKeyIndex {
mut:
	length int = -1
	keys   map[u64][]string
}

__global element_key_indexes map[u64]&ElementKeyIndex

// Every write to an indexed host map calls this, so that the next lookup
// indexes the map again.
fn invalidate_element_key_index(owner voidptr) {
	if mut index := element_key_indexes[u64(owner)] {
		index.length = -1
	}
}

// After `elements[key] = element` on an indexed map whose new size is
// `length`: index the key incrementally. A key that moved keeps its old entry,
// which the lookup's check against the map drops.
fn note_element_key_write(owner voidptr, key string, element &dom.Element, length int) {
	mut index := element_key_indexes[u64(owner)] or { return }
	if index.length < 0 { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	element_id := u64(voidptr(element))
	if mut keys := index.keys[element_id] {
		if key !in keys { keys << key.clone() }
		index.keys[element_id] = keys
	} else {
		index.keys[element_id] = [key.clone()]
	}
	index.length = length
}

fn native_canvas_element_identity_keys(owner voidptr, elements map[string]&dom.Element, element &dom.Element) []string {
	if retain_identity_key_scans { return native_canvas_element_identity_keys_by_scan(elements, element) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut index := element_key_indexes[u64(owner)] or {
		created := &ElementKeyIndex{}
		element_key_indexes[u64(owner)] = created
		created
	}
	if index.length != elements.len {
		index.keys = map[u64][]string{}
		for key, candidate in elements {
			index.keys[u64(voidptr(candidate))] << key.clone()
		}
		index.length = elements.len
	}
	candidates := index.keys[u64(voidptr(element))] or { return []string{} }
	mut keys := []string{}
	for key in candidates {
		if found := elements[key] {
			if voidptr(found) == voidptr(element) { keys << key }
		}
	}
	return keys
}

fn native_canvas_element_identity_keys_by_scan(elements map[string]&dom.Element, element &dom.Element) []string {
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
