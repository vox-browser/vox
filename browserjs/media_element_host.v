// HTMLMediaElement transport; the actual HTML model owns media state and ranges.
module browserjs

import css
import dom
import html

// The compact prototype exposes this media, input and drag subset of GlobalEventHandlers.
const media_element_event_handler_names = ['abort', 'canplay', 'canplaythrough', 'durationchange',
	'emptied', 'ended', 'error', 'loadeddata', 'loadedmetadata', 'loadstart', 'pause', 'play',
	'playing', 'progress', 'ratechange', 'resize', 'seeked', 'seeking', 'stalled', 'suspend',
	'timeupdate', 'volumechange', 'waiting', 'pointerdown', 'pointerup', 'mousedown', 'mouseup',
	'click', 'auxclick', 'dblclick', 'pointermove', 'mousemove', 'drag', 'dragend', 'dragenter',
	'dragleave', 'dragover', 'dragstart', 'drop', 'wheel']

pub type MediaElementReplayHook = fn (&Runtime) !

// The native shell can configure its platform inputs before the first replay
// of attributes on a newly created, still-disconnected media owner. It also
// runs once for script-reachable owners that a native factory created before
// this host bound them (Document.createElement, fragment parsing), so it must
// be idempotent.
pub type MediaElementCreatedHook = fn (&dom.Element)

@[heap]
pub struct MediaElementHost {
	document &dom.Document
	settings &html.EnvironmentSettingsObject
	replay   ?MediaElementReplayHook
	created_element_hook ?MediaElementCreatedHook
mut:
	runtime        &Runtime = unsafe { nil }
	prototype      voidptr
	audio_prototype voidptr
	video_prototype voidptr
	elements       map[string]&dom.Element
	records        map[voidptr]&html.HTMLMediaElement
	bound_elements map[voidptr]&dom.Element
	attribute_sync voidptr
	audio_factory voidptr
	audio_factory_serial u64
	audio_track_prototype voidptr
	audio_list_wrap voidptr
	audio_lists map[voidptr]&html.AudioTrackList
	audio_tracks map[voidptr]&html.AudioTrack
	audio_owner_wrappers map[voidptr]voidptr
	video_track_prototype voidptr
	video_list_wrap voidptr
	video_lists map[voidptr]&html.VideoTrackList
	video_tracks map[voidptr]&html.VideoTrack
	video_owner_wrappers map[voidptr]voidptr
	text_track_prototype voidptr
	text_list_wrap voidptr
	text_lists map[voidptr]&html.TextTrackList
	text_tracks map[voidptr]&html.TextTrack
	text_owner_wrappers map[voidptr]voidptr
	track_element_prototype voidptr
	track_elements map[voidptr]&dom.HTMLTrackElement
	closed         bool
}

pub fn MediaElementHost.create(document &dom.Document, replay ?MediaElementReplayHook) !&MediaElementHost {
	return MediaElementHost.create_with_created_element_hook(document, replay, none)
}

pub fn MediaElementHost.create_with_created_element_hook(document &dom.Document,
	replay ?MediaElementReplayHook, created_element_hook ?MediaElementCreatedHook) !&MediaElementHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	mut host := &MediaElementHost{
		document: document
		settings: unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		replay:   replay
		created_element_hook: created_element_hook
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
	if element := host.runtime.canvas_element_for_binding(key) {
		configure := key !in host.elements && element.is_html_element()
			&& element.local_name() in ['audio', 'video'] && element.local_name() == tag
		host.elements[key] = element
		// Document.createElement() now builds the owner in the native document
		// factory, so it reaches this host already registered by another provider.
		// Configure it like an owner created here; otherwise its src never gets
		// a platform decoder (old Reddit's script-created HLS <video>).
		if configure {
			if hook := host.created_element_hook { hook(element) }
		}
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
	if hook := host.created_element_hook { hook(element) }
	return element
}
