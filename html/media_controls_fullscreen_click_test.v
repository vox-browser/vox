module html

import dom
import math

@[heap]
struct FullscreenClickProbe {
mut:
	clicks int
}

fn fullscreen_click_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing fullscreen click media task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn fullscreen_click_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://fullscreen-click.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing fullscreen click owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing fullscreen click media') }
	media.set_duration(60)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(0, 60)
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
	}
	media.set_show_poster(false)
	controls := MediaControls.create(media)
	fullscreen_click_drain(media)
	return document, media, controls
}

fn fullscreen_click_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
}

fn fullscreen_click_activation(document &dom.Document, available bool) {
	mut window := document.get_window() or { panic('Missing fullscreen click Window') }
	window.set_last_activation_timestamp(if available { dom.current_high_resolution_time(window) } else { math.inf(1) })
	assert window.has_transient_activation() == available
}

fn fullscreen_click_send(element &dom.Element, name string, cancelable bool, bubbles bool, handled bool) {
	event := dom.Event.construct_impl(name, dom.EventInit{cancelable: cancelable, bubbles: bubbles}) or { panic(err) }
	assert !event.is_trusted()
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !(handled && cancelable)
	assert event.default_prevented() == (handled && cancelable)
}

fn fullscreen_click_icon(controls &MediaControls, active bool) {
	mut button := controls.dom_.fullscreen_button or { panic('Missing fullscreen click button') }
	mut icon := controls.dom_.fullscreen_icon or { panic('Missing fullscreen click icon') }
	assert button.is_html_element() && button.local_name() == 'button'
	assert controls.fullscreen == active && icon.class_list().contains('fullscreen') == active
	for name in ['control-button', 'fullscreen-button'] { assert button.class_list().contains(name) }
	assert !button.class_list().contains('fullscreen') && icon.class_list().contains('fullscreen-icon')
}

fn test_fullscreen_button_click_obeys_activation_and_preserves_hidden_controls_and_playback() {
	mut document, media, mut controls := fullscreen_click_owner('video')!
	defer { fullscreen_click_cleanup(mut controls); document.finalize() }
	mut button := controls.dom_.fullscreen_button?
	element := document.get_element_by_id('player')?
	mut classes := button.class_list()
	classes.add(['retained'])!
	controls.hide_controls()
	assert !controls.visible && controls.hover_timer_ == none
	fullscreen_click_activation(document, false)
	fullscreen_click_send(button, 'click', true, false, true)
	assert document.fullscreen_element() == none && !document.get_window()?.has_transient_activation()
	fullscreen_click_icon(controls, false)
	fullscreen_click_activation(document, true)
	fullscreen_click_send(button, 'click', true, false, true)
	assert (document.fullscreen_element() or { panic('Missing clicked fullscreen owner') }) == element
	fullscreen_click_icon(controls, true)
	// Exiting fullscreen does not require a fresh activation.
	fullscreen_click_activation(document, false)
	fullscreen_click_send(button, 'click', false, false, true)
	assert document.fullscreen_element() == none
	fullscreen_click_icon(controls, false)
	assert classes.contains('retained') && !controls.visible && controls.hover_timer_ == none
	assert media.paused() && media.current_time() == 0 && media.pending_play_promises_.len == 0
	assert media.queued_media_task_ids_.len == 0 && media.current_src() == ''
}

fn test_overlay_double_click_bubbles_once_and_stays_separate_from_bar_and_single_clicks() {
	mut document, media, mut controls := fullscreen_click_owner('video')!
	defer { fullscreen_click_cleanup(mut controls); document.finalize() }
	overlay := controls.dom_.video_overlay?
	placeholder := controls.dom_.placeholder_circle?
	element := document.get_element_by_id('player')?
	overlay_target := unsafe { &dom.EventTarget(overlay.as_node()) }
	assert controls.registered_event_listeners_.filter(it.target == overlay_target && it.event_name == 'dblclick').len == 1
	fullscreen_click_activation(document, false)
	fullscreen_click_send(overlay, 'dblclick', true, false, true)
	assert document.fullscreen_element() == none && media.paused()
	// A native double-click sequence includes its two ordinary playback clicks.
	fullscreen_click_send(overlay, 'click', true, true, true)
	assert !media.paused() && document.fullscreen_element() == none
	fullscreen_click_drain(media)
	fullscreen_click_send(overlay, 'click', true, true, true)
	assert media.paused() && document.fullscreen_element() == none
	fullscreen_click_drain(media)
	fullscreen_click_activation(document, true)
	fullscreen_click_send(placeholder, 'dblclick', true, true, true)
	assert (document.fullscreen_element() or { panic('Missing overlay fullscreen owner') }) == element
	fullscreen_click_icon(controls, true)
	for part in [controls.dom_.control_bar?, controls.dom_.play_button?, controls.dom_.container?] {
		fullscreen_click_send(part, 'dblclick', true, true, false)
		assert (document.fullscreen_element() or { panic('Lost fullscreen owner') }) == element
	}
	fullscreen_click_send(overlay, 'dblclick', false, false, true)
	assert document.fullscreen_element() == none && media.paused()
	fullscreen_click_icon(controls, false)
	assert media.event_count('play') == 1 && media.event_count('pause') == 1
}

fn test_fullscreen_native_button_disabled_state_and_cleanup_preserve_outside_listeners() {
	mut document, media, mut controls := fullscreen_click_owner('video')!
	defer { fullscreen_click_cleanup(mut controls); document.finalize() }
	mut button := controls.dom_.fullscreen_button?
	overlay := controls.dom_.video_overlay?
	target := unsafe { &dom.EventTarget(button.as_node()) }
	assert controls.registered_event_listeners_.filter(it.target == target && it.event_name == 'click').len == 1
	probe := &FullscreenClickProbe{}
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert !event.is_trusted() && (current or { panic('Missing fullscreen click current target') }) == target
			mut state := unsafe { &FullscreenClickProbe(probe) }
			state.clicks++
			return dom.js_undefined()
		}
	})
	target.add_event_listener_without_options('click', outside)
	defer { target.remove_event_listener_without_options('click', outside) }
	fullscreen_click_activation(document, true)
	button.set_attribute_value('disabled', '')
	html_element_click(unsafe { &dom.HTMLElement(button) })
	assert document.fullscreen_element() == none && probe.clicks == 0
	button.remove_attribute('disabled')
	child := document.create_element('span')!
	mut node := button.as_node()
	node.append_child(child.as_node())!
	fullscreen_click_send(child, 'click', true, true, true)
	assert document.fullscreen_element() != none && probe.clicks == 1
	html_element_click(unsafe { &dom.HTMLElement(button) })
	assert document.fullscreen_element() == none && probe.clicks == 2
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	fullscreen_click_send(button, 'click', true, true, false)
	fullscreen_click_send(overlay, 'dblclick', true, true, false)
	assert document.fullscreen_element() == none && probe.clicks == 3 && media.paused()
}

fn test_fullscreen_click_uses_adopted_document_activation_and_skips_missing_video_widgets() {
	mut first, first_media, mut controls := fullscreen_click_owner('video')!
	mut second, _, mut other := fullscreen_click_owner('audio')!
	defer {
		fullscreen_click_cleanup(mut controls)
		fullscreen_click_cleanup(mut other)
		first.finalize()
		second.finalize()
	}
	owner := first.get_element_by_id('player')?
	second_owner := second.get_element_by_id('player')?
	second.adopt_node(owner.as_node())
	mut parent := second_owner.as_node().parent() or { panic('Missing adoption container') }
	parent.append_child(owner.as_node())!
	button := controls.dom_.fullscreen_button?
	overlay := controls.dom_.video_overlay?
	assert owner.is_connected() && button.document() == second && first_media.document()? == second
	fullscreen_click_activation(first, true)
	fullscreen_click_activation(second, false)
	fullscreen_click_send(button, 'click', true, true, true)
	assert first.fullscreen_element() == none && second.fullscreen_element() == none
	fullscreen_click_icon(controls, false)
	fullscreen_click_activation(second, true)
	fullscreen_click_send(button, 'click', true, true, true)
	assert first.fullscreen_element() == none && (second.fullscreen_element() or { panic('Missing adopted fullscreen owner') }) == owner
	fullscreen_click_icon(controls, true)
	fullscreen_click_send(overlay, 'dblclick', true, true, true)
	assert second.fullscreen_element() == none
	fullscreen_click_icon(controls, false)
	second.adopt_node(owner.as_node()) // A disconnected owner cannot enter fullscreen.
	assert !owner.is_connected()
	fullscreen_click_send(button, 'click', true, true, true)
	assert second.fullscreen_element() == none
	assert other.dom_.fullscreen_icon == none && other.dom_.video_overlay == none
	mut ownerless := MediaControls.create(HTMLMediaElement.create(none, dom.URL{value: 'https://unowned-fullscreen-click.example/'}))
	defer { ownerless.remove_event_listeners() }
	mut video := second.create_element('video')!
	root := video.attach_a_user_agent_shadow_root(.named)
	mut preserving := MediaControls.create(html_media_element_for_dom_element(video)?)
	defer { preserving.remove_event_listeners() }
	assert video.shadow_root()? == root
	for absent in [other, ownerless, preserving] {
		assert absent.dom_.fullscreen_icon == none && absent.registered_event_listeners_.filter(it.event_name == 'dblclick').len == 0
	}
}
