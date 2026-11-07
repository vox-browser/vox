// Compact Element wheel listeners retain the actual owning DOM EventTarget.
module browserjs

import css
import dom
import html

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
	}
	return host
}

pub fn (host &ElementWheelHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

fn (mut host ElementWheelHost) refresh_elements() {
	host.runtime.merge_canvas_elements_into(mut host.elements)
}

fn event_target_is_element(target &dom.EventTarget) bool {
	if target.data.kind != .node { return false }
	return unsafe { &dom.Node(target) }.is_element()
}

fn (mut host ElementWheelHost) element_for_wheel_binding(key string, tag string, namespace string) !&dom.Element {
	if element := host.runtime.canvas_element_for_binding(key) {
		host.elements[key] = element
	}
	if element := host.elements[key] {
		name := if key.starts_with('__created_') {
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
	return element
}
