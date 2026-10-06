module html

import dom

@[heap]
struct MediaTargetObservation {
mut:
	events []string
}

fn test_media_events_use_the_actual_dom_target_and_ancestor_capture_path() {
	mut document :=
		parse_document('<!doctype html><body><video id="player"></video><audio id="other"></audio></body>')
	element := document.get_element_by_id('player')?
	other := document.get_element_by_id('other')?
	mut media := html_media_element_for_dom_element(element)?
	other_media := html_media_element_for_dom_element(other)?
	target := unsafe { &dom.EventTarget(element) }
	assert voidptr(media.event_target()) == voidptr(target)
	assert voidptr(other_media.event_target()) == voidptr(other)
	assert voidptr(media.event_target()) != voidptr(other_media.event_target())
	state := &MediaTargetObservation{}
	document_target := unsafe { &dom.EventTarget(document) }
	document_target.add_event_listener('volumechange', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [state, target, document_target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			actual_target := event.target() or { panic('missing event target') }
			actual_current := current or { panic('missing current target') }
			assert voidptr(actual_target) == voidptr(target)
			assert voidptr(actual_current) == voidptr(document_target)
			mut result := unsafe { &MediaTargetObservation(state) }
			result.events << 'capture'
			return dom.js_undefined()
		}
	}), dom.AddEventListenerOptions{ capture: true })
	media.set_on_event('volumechange', &dom.CallbackType{
		handle_event: fn [state, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			actual_target := event.target() or { panic('missing event target') }
			actual_current := current or { panic('missing current target') }
			assert voidptr(actual_target) == voidptr(target)
			assert voidptr(actual_current) == voidptr(target)
			assert event.is_trusted()
			assert !event.bubbles() && !event.cancelable()
			mut result := unsafe { &MediaTargetObservation(state) }
			result.events << 'target'
			return dom.js_undefined()
		}
	})
	media.set_volume(0.5)!
	assert state.events == ['capture', 'target']
	assert media.event_count('volumechange') == 1
	assert other_media.event_count('volumechange') == 0
}

fn test_media_event_target_identity_survives_adoption_and_standalone_owners_stay_independent() {
	mut old_document := dom.Document.create(dom.url_about_blank())
	mut new_document := dom.Document.create(dom.URL{ value: 'https://adopted-media.example.test/' })
	element := old_document.create_element_ns(dom.namespace_html_uri, 'audio')!
	mut media := html_media_element_for_dom_element(element)?
	target := unsafe { &dom.EventTarget(element) }
	assert voidptr(media.event_target()) == voidptr(target)
	new_document.adopt_node(element.as_node())
	assert voidptr(media.event_target()) == voidptr(target)
	assert voidptr(media.document()?) == voidptr(new_document)
	assert voidptr(html_media_element_for_dom_element(element)?) == voidptr(media)
	first := HTMLMediaElement.create(none, dom.url_about_blank())
	second := HTMLMediaElement.create(none, dom.url_about_blank())
	assert voidptr(first.event_target()) != voidptr(second.event_target())
	assert voidptr(first.event_target()) != voidptr(target)
}
