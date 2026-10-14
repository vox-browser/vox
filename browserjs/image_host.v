// HTMLImageElement.idl binding transport. The real HTML model owns image
// selection, request state, decode microtasks/tasks and the Promise capability.
module browserjs

import css
import dom
import html

pub type ImageReplayHook = fn (&Runtime) !

@[heap]
struct ImageHostRecord {
	key     string
	element &dom.HTMLImageElement
	model   &html.HTMLImageElementModel
}

@[heap]
pub struct ImageHost {
	document   &dom.Document
	settings   &html.EnvironmentSettingsObject
	fetch_hook ?html.HTMLImageFetchHook
	replay     ?ImageReplayHook
mut:
	runtime   &Runtime = unsafe { nil }
	elements  map[string]&dom.Element
	records   map[voidptr]&ImageHostRecord
	prototype voidptr
	closed    bool
}

pub fn ImageHost.create(document &dom.Document, fetch_hook ?html.HTMLImageFetchHook, replay ?ImageReplayHook) !&ImageHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	mut host := &ImageHost{ document: document, settings: unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }, fetch_hook: fetch_hook, replay: replay }
	for index, element in css.query_selector_all(unsafe { &dom.Node(document) }, '*') {
		host.elements['__element_${index}'] = element
	}
	return host
}

pub fn (host &ImageHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

pub fn (host &ImageHost) image_for_binding(wrapper voidptr) !&dom.HTMLImageElement {
	record := host.records[wrapper] or { return error('TypeError: HTMLImageElement receiver is not an image') }
	return record.element
}

fn (mut host ImageHost) element_for_binding(key string) !&dom.Element {
	if element := host.runtime.canvas_element_for_binding(key) {
		host.elements[key] = element
	}
	if element := host.elements[key] {
		if element.is_html_element() && element.local_name() == 'img' { return element }
		return error('TypeError: HTMLImageElement receiver is not an image')
	}
	if !key.starts_with('__created_') {
		return error('TypeError: Image has no owning native element')
	}
	element := dom.create_element(host.document, 'img', 'http://www.w3.org/1999/xhtml', none, none, false)!
	host.elements[key] = element
	return element
}

fn (mut host ImageHost) replay_before_decode() ! {
	if replay := host.replay { replay(host.runtime)! }
}
