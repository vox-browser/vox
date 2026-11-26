// Compact Element wheel listeners retain the actual owning DOM EventTarget.
module browserjs

import css
import dom
import html
import os

pub type ElementWheelReplayHook = fn (&Runtime) !

@[heap]
pub struct ElementWheelHost {
	document &dom.Document
	settings &html.EnvironmentSettingsObject
	replay   ?ElementWheelReplayHook
mut:
	runtime  &Runtime = unsafe { nil }
	elements map[string]&dom.Element
	records  map[voidptr]&dom.Element
	resolver voidptr
	closed   bool
}

pub fn ElementWheelHost.create(document &dom.Document) !&ElementWheelHost {
	return ElementWheelHost.create_with_replay(document, none)
}

pub fn ElementWheelHost.create_with_replay(document &dom.Document, replay ?ElementWheelReplayHook) !&ElementWheelHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	mut host := &ElementWheelHost{
		document: document
		settings: unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		replay:   replay
	}
	for index, element in css.query_selector_all(unsafe { &dom.Node(document) }, '*') {
		host.elements['__element_${index}'] = element
		invalidate_element_key_index(voidptr(host))
	}
	return host
}

pub fn (host &ElementWheelHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

fn (mut host ElementWheelHost) refresh_elements() {
	host.runtime.merge_canvas_elements_into(mut host.elements)
	invalidate_element_key_index(voidptr(host))
}

// Same-binary control: refresh the host's map from every provider and scan it
// for each event target without a wrapper, as before.
const retain_wheel_element_refresh = os.getenv('VOX_RETAIN_WHEEL_ELEMENT_REFRESH') != ''

__global wheel_element_key_counts [2]u64

// Wrapper keys resolved from the providers' single key, and resolved by
// refreshing the host's map, in this process (tests and diagnostics).
pub fn wheel_element_key_statistics() (u64, u64) {
	return wheel_element_key_counts[0], wheel_element_key_counts[1]
}

// The key the wrapper resolver receives for `element`: the first key naming
// it in the host's map refreshed from every provider. Copying every
// provider's map and scanning the result cost each new custom element and
// each first event target O(elements) (13 million instructions per
// createElement of a custom element on a 2,700-element page), and each
// refresh made the next identity lookup index the maps again.
//
// The refreshed map names `element` by exactly the keys a provider maps to
// it (providers only add keys; the last provider with a key wins, as in
// canvas_element_for_binding()). With one such key, which the providers
// resolve to `element`, that key is the answer, and it is the one entry the
// refresh would add or change for this element. No key leaves nothing to find.
// Several keys keep the refresh, whose map order picks among them.
fn (mut host ElementWheelHost) wheel_element_key(element &dom.Element) ?string {
	if !retain_wheel_element_refresh {
		keys := host.runtime.canvas_element_keys_for_binding(element)
		if keys.len == 0 { return none }
		if keys.len == 1 {
			key := keys[0]
			if resolved := host.runtime.canvas_element_for_binding(key) {
				if voidptr(resolved) == voidptr(element) {
					wheel_element_key_counts[0]++
					if existing := host.elements[key] {
						if voidptr(existing) == voidptr(element) { return key }
					}
					host.elements[key] = element
					note_element_key_write(voidptr(host), key, element, host.elements.len)
					return key
				}
			}
		}
	}
	wheel_element_key_counts[1]++
	host.refresh_elements()
	for key, candidate in host.elements {
		if voidptr(candidate) == voidptr(element) { return key }
	}
	return none
}

fn event_target_is_element(target &dom.EventTarget) bool {
	if target.data.kind != .node { return false }
	return unsafe { &dom.Node(target) }.is_element()
}

fn (mut host ElementWheelHost) element_for_wheel_binding(key string, tag string, namespace string) !&dom.Element {
	if element := host.runtime.canvas_element_for_binding(key) {
		host.elements[key] = element
		note_element_key_write(voidptr(host), key, element, host.elements.len)
	}
	if element := host.elements[key] {
		// Wrapper state names a prefixed element by its qualified name.
		name := if key.starts_with('__created_') || element.prefix() != none {
			element.qualified_name_str()
		} else {
			element.local_name()
		}
		// The realm registry also owns elements in createHTMLDocument() trees.
		// Adoption changes their document without changing their native identity.
		if name != tag || (element.namespace_uri() or {
			''
		}) != namespace {
			return error('TypeError: Element wrapper metadata does not match its native owner')
		}
		if element.is_html_element() && element.local_name() in ['audio', 'video'] {
			return error('TypeError: Media elements retain their native media binding')
		}
		return element
	}
	if !key.starts_with('__created_') {
		return error('TypeError: Element wrapper has no owning native element')
	}
	optional_namespace := if namespace == '' { ?string(none) } else { ?string(namespace) }
	element := host.document.create_element_ns(optional_namespace, tag)!
	if element.qualified_name_str() != tag || (element.namespace_uri() or { '' }) != namespace {
		return error('TypeError: Created Element namespace or local name does not match')
	}
	if element.is_html_element() && element.local_name() in ['audio', 'video'] {
		return error('TypeError: Media elements retain their native media binding')
	}
	host.elements[key] = element
	note_element_key_write(voidptr(host), key, element, host.elements.len)
	return element
}
