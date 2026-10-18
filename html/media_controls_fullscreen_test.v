module html

import dom
import math

@[heap]
struct FullscreenControlsProbe {
mut:
	changes int
}

fn fullscreen_controls_document() !(&dom.Document, &dom.Window) {
	url := dom.URL{value: 'https://fullscreen-controls.example/'}
	document := parse_navigation_document('<!doctype html><video id="first" preload="none"></video><video id="second" preload="none"></video><audio id="audio" preload="none"></audio>', url, url.origin(), none)!
	window := document.get_window() or { return error('Missing fullscreen Window') }
	assert document.is_fully_active()
	assert (window.associated_document() or { return error('Missing Window document') }) == document
	return document, window
}

fn fullscreen_controls_media(document &dom.Document, id string) &HTMLMediaElement {
	element := document.get_element_by_id(id) or { panic('Missing fullscreen media owner') }
	return html_media_element_for_dom_element(element) or { panic('Missing fullscreen media model') }
}

fn fullscreen_controls_assert_icon(controls &MediaControls, active bool) {
	mut icon := controls.dom_.fullscreen_icon or { panic('Missing fullscreen icon') }
	assert icon.document() == (controls.media.document() or { panic('Missing fullscreen document') })
	assert icon.is_html_element() && icon.local_name() == 'button'
	assert controls.fullscreen == active && icon.class_list().contains('fullscreen') == active
	assert icon.class_list().contains('fullscreen-icon')
}

fn fullscreen_controls_key(media &HTMLMediaElement) {
	event := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{
		key_code: u32(dom.KeyCode.f)
		cancelable: true
	})
	base := unsafe { &dom.Event(event) }
	default_allowed := media.event_target().dispatch_event_binding(base) or { panic(err) }
	assert !default_allowed && base.default_prevented() && !base.is_trusted()
}

fn test_fullscreen_controls_follow_document_entry_exit_and_the_actual_media_identity() {
	mut document, _ := fullscreen_controls_document()!
	first := fullscreen_controls_media(document, 'first')
	second := fullscreen_controls_media(document, 'second')
	mut first_element := document.get_element_by_id('first')?
	mut second_element := document.get_element_by_id('second')?
	// The public WebDriver boundary bypasses activation, using real fullscreen DOM steps.
	assert first_element.request_fullscreen(.web_driver).state() == .fulfilled
	mut first_controls := MediaControls.create(first)
	mut second_controls := MediaControls.create(second)
	defer { first_controls.remove_event_listeners(); second_controls.remove_event_listeners(); document.finalize() }
	fullscreen_controls_assert_icon(first_controls, true)
	fullscreen_controls_assert_icon(second_controls, false)
	mut icon := first_controls.dom_.fullscreen_icon?
	mut classes := icon.class_list()
	classes.add(['retained', 'custom-icon'])!
	assert document.exit_fullscreen().state() == .fulfilled
	fullscreen_controls_assert_icon(first_controls, false)
	fullscreen_controls_assert_icon(second_controls, false)
	assert first_element.request_fullscreen(.web_driver).state() == .fulfilled
	fullscreen_controls_assert_icon(first_controls, true)
	assert classes.contains('retained') && classes.contains('custom-icon')
	assert document.exit_fullscreen().state() == .fulfilled
	assert second_element.request_fullscreen(.web_driver).state() == .fulfilled
	assert (document.fullscreen_element() or { panic('Missing fullscreen owner') }) == second_element
	fullscreen_controls_assert_icon(first_controls, false)
	fullscreen_controls_assert_icon(second_controls, true)
	assert document.exit_fullscreen().state() == .fulfilled
	fullscreen_controls_assert_icon(second_controls, false)
	assert classes.contains('retained') && classes.contains('custom-icon')
	assert first.paused() && second.paused() && first.current_src() == '' && second.current_src() == ''
}

fn test_fullscreen_listener_uses_the_document_and_cleanup_preserves_unrelated_listeners() {
	mut document, _ := fullscreen_controls_document()!
	media := fullscreen_controls_media(document, 'first')
	mut element := document.get_element_by_id('first')?
	mut controls := MediaControls.create(media)
	defer { controls.remove_event_listeners(); document.finalize() }
	target := unsafe { &dom.EventTarget(document) }
	assert controls.registered_event_listeners_.len == 26
	assert controls.registered_event_listeners_.filter(it.event_name == 'fullscreenchange' && it.target == target).len == 1
	probe := &FullscreenControlsProbe{}
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe, target, media] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert (current or { panic('Missing fullscreen current target') }) == target
			assert (event.target() or { panic('Missing fullscreen event target') }) == media.event_target()
			mut seen := unsafe { &FullscreenControlsProbe(probe) }
			seen.changes++
			return dom.js_undefined()
		}
	})
	// A Source no-argument callback accepts an ordinary cancelable Event too.
	event := dom.Event.create('fullscreenchange', dom.EventInit{cancelable: true})
	assert !target.dispatch_event(event) && event.default_prevented()
	target.add_event_listener_without_options('fullscreenchange', outside)
	defer { target.remove_event_listener_without_options('fullscreenchange', outside) }
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	assert element.request_fullscreen(.web_driver).state() == .fulfilled
	assert probe.changes == 1 && document.fullscreen_element() != none
	fullscreen_controls_assert_icon(controls, false)
	controls.update_fullscreen_icon()
	fullscreen_controls_assert_icon(controls, true)
	assert document.exit_fullscreen().state() == .fulfilled
	assert probe.changes == 2
	fullscreen_controls_assert_icon(controls, true)
	controls.update_fullscreen_icon()
	fullscreen_controls_assert_icon(controls, false)
}

fn test_fullscreen_widget_and_document_listener_are_absent_for_audio_and_unowned_controls() {
	mut document, _ := fullscreen_controls_document()!
	audio := fullscreen_controls_media(document, 'audio')
	mut audio_controls := MediaControls.create(audio)
	defer { audio_controls.remove_event_listeners(); document.finalize() }
	assert audio_controls.dom_.fullscreen_icon == none && audio_controls.dom_.placeholder_circle == none
	assert audio_controls.dom_.mute_button != none && audio_controls.dom_.timeline_track != none
	assert audio_controls.registered_event_listeners_.len == 17
	mut element := document.get_element_by_id('second')?
	root := element.attach_a_user_agent_shadow_root(.named)
	mut preserving := MediaControls.create(fullscreen_controls_media(document, 'second'))
	defer { preserving.remove_event_listeners() }
	assert element.shadow_root()? == root && unsafe { &dom.Node(root) }.children_as_vector().len == 0
	assert preserving.dom_.fullscreen_icon == none && preserving.registered_event_listeners_.len == 13
	mut ownerless := MediaControls.create(HTMLMediaElement.create(none, dom.URL{value: 'https://unowned-fullscreen.example/'}))
	defer { ownerless.remove_event_listeners() }
	assert ownerless.dom_.fullscreen_icon == none && ownerless.registered_event_listeners_.len == 13
	for controls in [audio_controls, preserving, ownerless] {
		assert controls.registered_event_listeners_.filter(it.event_name == 'fullscreenchange').len == 0
	}
	event := dom.Event.create('fullscreenchange', dom.EventInit{cancelable: true})
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(event) && !event.default_prevented()
}

fn test_fullscreen_keyboard_uses_real_activation_and_does_not_display_rejected_requests() {
	mut document, mut window := fullscreen_controls_document()!
	media := fullscreen_controls_media(document, 'first')
	element := document.get_element_by_id('first')?
	mut controls := MediaControls.create(media)
	defer { controls.remove_event_listeners(); document.finalize() }
	window.set_last_activation_timestamp(math.inf(1))
	assert !window.has_transient_activation()
	fullscreen_controls_key(media)
	assert document.fullscreen_element() == none
	fullscreen_controls_assert_icon(controls, false)
	mut native_window := document.get_window()?
	native_window.set_last_activation_timestamp(dom.current_high_resolution_time(native_window))
	assert native_window == window
	fullscreen_controls_key(media)
	assert (document.fullscreen_element() or { panic('Missing keyboard fullscreen owner') }) == element
	fullscreen_controls_assert_icon(controls, true)
	fullscreen_controls_key(media)
	assert document.fullscreen_element() == none
	fullscreen_controls_assert_icon(controls, false)
}
