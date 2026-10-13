// HTMLMediaElement transport; the actual HTML model owns media state and ranges.
module browserjs

import css
import dom
import html

// The compact prototype exposes this media-event subset of GlobalEventHandlers.
const media_element_event_handler_names = ['abort', 'canplay', 'canplaythrough', 'durationchange',
	'emptied', 'ended', 'error', 'loadeddata', 'loadedmetadata', 'loadstart', 'pause', 'play',
	'playing', 'progress', 'ratechange', 'resize', 'seeked', 'seeking', 'stalled', 'suspend',
	'timeupdate', 'volumechange', 'waiting', 'pointerdown', 'pointerup', 'mousedown', 'mouseup',
	'click', 'auxclick', 'dblclick']

pub type MediaElementReplayHook = fn (&Runtime) !

@[heap]
pub struct MediaElementHost {
	document &dom.Document
	settings &html.EnvironmentSettingsObject
	replay   ?MediaElementReplayHook
mut:
	runtime   &Runtime = unsafe { nil }
	prototype voidptr
	elements  map[string]&dom.Element
	records   map[voidptr]&html.HTMLMediaElement
	closed    bool
}

pub fn MediaElementHost.create(document &dom.Document, replay ?MediaElementReplayHook) !&MediaElementHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	mut host := &MediaElementHost{
		document: document
		settings: unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		replay:   replay
	}
	for index, element in css.query_selector_all(unsafe { &dom.Node(document) }, '*') {
		host.elements['__element_${index}'] = element
	}
	return host
}

pub fn (host &MediaElementHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

pub fn (host &MediaElementHost) media_element_for_binding(wrapper voidptr) !&html.HTMLMediaElement {
	if host.closed { return error('Media element binding is closed') }
	return host.records[wrapper] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
}

fn (mut host MediaElementHost) element_for_binding(key string, tag string) !&dom.Element {
	for known_key, element in host.runtime.canvas_elements_for_binding() {
		host.elements[known_key] = element
	}
	if element := host.elements[key] {
		if element.is_html_element() && element.local_name() in ['audio', 'video']
			&& element.local_name() == tag {
			return element
		}
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	if !key.starts_with('__created_') || tag !in ['audio', 'video'] {
		return error('TypeError: Media wrapper has no owning native element')
	}
	element := dom.create_element(host.document, tag, 'http://www.w3.org/1999/xhtml', none, none,
		false)!
	host.elements[key] = element
	return element
}
