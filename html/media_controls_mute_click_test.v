module html

import css
import dom

@[heap]
struct MuteClickProbe {
mut:
	targets []&dom.EventTarget
}

fn mute_click_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing mute click task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn mute_click_owner(kind string, with_audio bool) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://mute-click.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing media model') }
	media.set_volume(0.5)!
	media.set_ready_state(.have_enough_data)
	if with_audio { media.on_audio_track_added(MediaTrackMetadata{identifier: 1}) }
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
		media.set_show_poster(false)
	}
	controls := MediaControls.create(media)
	mute_click_drain(media)
	return document, media, controls
}

fn mute_click_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
}

fn mute_click_indicator(controls &MediaControls, muted bool, width string) {
	mut button := controls.dom_.mute_button or { panic('Missing mute button') }
	fill := controls.dom_.volume_fill or { panic('Missing volume fill') }
	assert controls.was_muted == muted && button.class_list().contains('muted') == muted
	assert css.element_style(fill).get_property_value('width') == width
}

fn test_mute_click_toggles_media_immediately_and_defers_the_indicator_without_showing_controls() {
	for kind in ['audio', 'video'] {
		mut document, media, mut controls := mute_click_owner(kind, true)!
		defer { mute_click_cleanup(mut controls); document.finalize() }
		mut button := controls.dom_.mute_button?
		assert button.is_html_element() && button.local_name() == 'button'
		mut classes := button.class_list()
		assert classes.contains('control-button') && classes.contains('mute-button')
		classes.add(['retained'])!
		target := unsafe { &dom.EventTarget(button.as_node()) }
		assert controls.registered_event_listeners_.filter(it.target == target && it.event_name == 'click').len == 1
		controls.hide_controls()
		assert !controls.visible && controls.hover_timer_ == none
		before := media.event_count('volumechange')
		event := dom.Event.create('click', dom.EventInit{cancelable: true})
		assert !target.dispatch_event(event) && event.default_prevented()
		assert media.muted() && media.volume() == 0.5 && media.paused()
		assert media.event_count('volumechange') == before
		mute_click_indicator(controls, false, '50%')
		assert !controls.visible && controls.hover_timer_ == none
		mute_click_drain(media)
		mute_click_indicator(controls, true, '0px')
		assert media.event_count('volumechange') == before + 1
		// Source's no-argument callback also handles a non-cancelable ordinary Event.
		next := dom.Event.create('click', dom.EventInit{})
		assert target.dispatch_event(next) && !next.default_prevented()
		assert !media.muted() && media.volume() == 0.5
		mute_click_indicator(controls, true, '0px')
		mute_click_drain(media)
		mute_click_indicator(controls, false, '50%')
		assert classes.contains('retained') && classes.contains('low')
		assert !controls.visible && controls.hover_timer_ == none
		assert media.current_src() == '' && !document.anything_is_delaying_the_load_event()
	}
}

fn test_mute_button_accepts_bubbling_descendant_clicks_and_native_click_honors_disabled() {
	mut document, media, mut controls := mute_click_owner('audio', true)!
	defer { mute_click_cleanup(mut controls); document.finalize() }
	mut button := controls.dom_.mute_button?
	target := unsafe { &dom.EventTarget(button.as_node()) }
	probe := &MuteClickProbe{}
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert (current or { panic('Missing current target') }) == target
			assert event.default_prevented() && !event.is_trusted()
			mut state := unsafe { &MuteClickProbe(probe) }
			state.targets << (event.target() or { panic('Missing click target') })
			return dom.js_undefined()
		}
	})
	target.add_event_listener_without_options('click', outside)
	defer { target.remove_event_listener_without_options('click', outside) }
	button.set_attribute_value('disabled', '')
	html_element_click(unsafe { &dom.HTMLElement(button) })
	assert !media.muted() && probe.targets.len == 0
	button.remove_attribute('disabled')
	child := document.create_element('span')!
	mut node := button.as_node()
	node.append_child(child.as_node())!
	event := dom.MouseEvent.construct_impl('click', dom.MouseEventInit{bubbles: true, cancelable: true})!
	assert !unsafe { &dom.EventTarget(child.as_node()) }.dispatch_event(unsafe { &dom.Event(event) })
	assert media.muted()
	html_element_click(unsafe { &dom.HTMLElement(button) })
	assert !media.muted()
	assert probe.targets == [unsafe { &dom.EventTarget(child.as_node()) }, target]
	mute_click_drain(media)
	mute_click_indicator(controls, false, '50%')
}

fn test_mute_click_cleanup_keeps_unrelated_listeners_and_does_not_refresh_a_removed_indicator() {
	mut document, mut media, mut controls := mute_click_owner('audio', true)!
	defer { mute_click_cleanup(mut controls); document.finalize() }
	button := controls.dom_.mute_button?
	target := unsafe { &dom.EventTarget(button.as_node()) }
	probe := &MuteClickProbe{}
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &MuteClickProbe(probe) }
			state.targets << (event.target() or { panic('Missing cleanup target') })
			return dom.js_undefined()
		}
	})
	target.add_event_listener_without_options('click', outside)
	defer { target.remove_event_listener_without_options('click', outside) }
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	event := dom.Event.create('click', dom.EventInit{cancelable: true})
	assert target.dispatch_event(event) && !event.default_prevented()
	assert !media.muted() && probe.targets == [target]
	media.set_muted(true)
	mute_click_drain(media)
	mute_click_indicator(controls, false, '50%')
	controls.update_volume_and_mute_indicator()
	mute_click_indicator(controls, true, '0px')
}

fn test_mute_click_follows_the_actual_adopted_owner_and_skips_missing_widgets() {
	mut first, first_media, mut controls := mute_click_owner('video', true)!
	mut second, second_media, mut other := mute_click_owner('audio', false)!
	defer {
		mute_click_cleanup(mut controls)
		mute_click_cleanup(mut other)
		first.finalize()
		second.finalize()
	}
	button := controls.dom_.mute_button?
	owner := first.get_element_by_id('player')?
	second.adopt_node(owner.as_node())
	assert button.document() == second && first_media.document()? == second
	event := dom.Event.create('click', dom.EventInit{cancelable: true})
	assert !unsafe { &dom.EventTarget(button.as_node()) }.dispatch_event(event)
	assert first_media.muted() && !second_media.muted()
	mute_click_drain(first_media)
	mute_click_indicator(controls, true, '0px')
	// No audio does not suppress the native mute state transition.
	other_button := other.dom_.mute_button?
	html_element_click(unsafe { &dom.HTMLElement(other_button) })
	assert second_media.muted()
	mute_click_drain(second_media)
	mute_click_indicator(other, true, '0px')
	mut ownerless := MediaControls.create(HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-mute.example/'}))
	defer { ownerless.remove_event_listeners() }
	assert ownerless.dom_.mute_button == none && ownerless.registered_event_listeners_.len == 13
	mut element := second.create_element('video')!
	root := element.attach_a_user_agent_shadow_root(.named)
	mut preserving := MediaControls.create(html_media_element_for_dom_element(element)?)
	defer { preserving.remove_event_listeners() }
	assert element.shadow_root()? == root && preserving.dom_.mute_button == none
	assert preserving.registered_event_listeners_.len == 13
}
