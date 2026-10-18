module html

import dom

@[heap]
struct PointerTimelineProbe {
mut:
	position f64 = 110
	seeks []f64
	starts int
	pauses int
	outside int
}

fn pointer_timeline_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing pointer timeline task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn pointer_timeline_geometry(controls &MediaControls, rect dom.Rect) {
	timeline := controls.dom_.timeline_element or { panic('Missing pointer timeline') }
	mut node := timeline.as_node()
	node.set_layout_node(&dom.LayoutNode{dom_node_: node, has_geometry_: true, border_box_: rect})
	actual := timeline.get_bounding_client_rect()
	assert actual.x == rect.x && actual.width == rect.width
}

fn pointer_timeline_window(document &dom.Document) &dom.EventTarget {
	window := document.get_window() or { panic('Missing pointer timeline Window') }
	return unsafe { &dom.EventTarget(window) }
}

fn pointer_timeline_owner(kind string, playing bool) !(&dom.Document, &HTMLMediaElement, &MediaControls, &PointerTimelineProbe) {
	url := dom.URL{value: 'https://pointer-timeline.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing pointer timeline owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing pointer timeline media') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(0, 20)
	media.seekable_.add_range(100, 200)
	media.set_show_poster(false)
	media.set_paused(!playing)
	probe := &PointerTimelineProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [probe] () f64 { return probe.position }
		seek: fn [probe] (time f64, mode MediaPlaybackSeekMode) {
			assert mode == .accurate
			mut state := unsafe { &PointerTimelineProbe(probe) }
			state.seeks << time
		}
		play: fn [probe] () {
			mut state := unsafe { &PointerTimelineProbe(probe) }
			state.starts++
		}
		pause: fn [probe] () {
			mut state := unsafe { &PointerTimelineProbe(probe) }
			state.pauses++
		}
	})
	media.set_current_playback_position(110)
	media.set_official_playback_position(110)
	controls := MediaControls.create(media)
	pointer_timeline_drain(media)
	pointer_timeline_geometry(controls, dom.Rect{40, 10, 200, 20})
	return document, media, controls, probe
}

fn pointer_timeline_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
	if mut timer := controls.scrub_seek_preemption_timer_ { timer.stop() }
}

fn pointer_timeline_dispatch(target &dom.EventTarget, event &dom.Event, handled bool) {
	assert !event.is_trusted()
	assert target.dispatch_event(event) == !handled && event.default_prevented() == handled
}

fn pointer_timeline_mouse(target &dom.EventTarget, name string, x f64, handled bool) {
	event := dom.MouseEvent.construct_impl(name, dom.MouseEventInit{client_x: x, bubbles: true, cancelable: true, button: 2}) or { panic(err) }
	pointer_timeline_dispatch(target, unsafe { &dom.Event(event) }, handled)
}

fn test_pointer_timeline_projects_live_geometry_coalesces_seeks_and_removes_window_drag_listeners() {
	for kind in ['audio', 'video'] {
		mut document, mut media, mut controls, mut probe := pointer_timeline_owner(kind, false)!
		defer { pointer_timeline_cleanup(mut controls); document.finalize() }
		fill := controls.dom_.timeline_fill?
		window := pointer_timeline_window(document)
		count := controls.registered_event_listeners_.len
		pointer_timeline_mouse(unsafe { &dom.EventTarget(fill.as_node()) }, 'mousedown', 90, true)
		assert controls.scrubbing_timeline == .while_paused && media.paused() && media.seeking()
		assert probe.seeks == [125.0] && controls.timeline_percentage == 25
		assert controls.timestamp == '02:05 / 03:20' && controls.registered_event_listeners_.len == count + 2
		pointer_timeline_mouse(window, 'mousemove', 200, true)
		assert probe.seeks == [125.0] && controls.pending_scrub_seek_time_? == 180
		assert controls.timeline_percentage == 80 && controls.timestamp == '03:00 / 03:20'
		media.set_duration(400)
		media.seekable_.clear()
		media.seekable_.add_range(0, 20)
		media.seekable_.add_range(200, 400)
		pointer_timeline_geometry(controls, dom.Rect{20, 10, 400, 20})
		pointer_timeline_mouse(window, 'mousemove', 220, true)
		assert controls.pending_scrub_seek_time_? == 300 && controls.timeline_percentage == 50
		assert controls.timestamp == '05:00 / 06:40'
		probe.position = 125
		media.set_official_playback_position(125)
		media.finish_seeking_element()
		pointer_timeline_drain(media)
		assert probe.seeks == [125.0, 300.0] && media.seeking()
		pointer_timeline_mouse(window, 'mouseup', 1000, true)
		assert probe.seeks == [125.0, 300.0, 400.0]
		assert controls.scrubbing_timeline == .no && controls.pending_scrub_seek_time_ == none
		assert controls.scrub_seek_preemption_timer_ == none && media.paused() && probe.starts == 0
		pointer_timeline_mouse(window, 'mousemove', -1000, false)
		pointer_timeline_mouse(window, 'mouseup', 0, false)
		assert probe.seeks == [125.0, 300.0, 400.0]
		probe.position = 400
		media.set_official_playback_position(400)
		media.finish_seeking_element()
		pointer_timeline_drain(media)
		assert controls.timeline_percentage == 100
	}
}

fn test_pointer_release_resumes_user_play_without_a_promise_and_obeys_live_ended_loop_state() {
	mut policy := AutoplaySettings.the()
	previous := policy.policy()
	allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous, allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	for mode in ['playing', 'ended', 'loop'] {
		mut document, mut media, mut controls, probe := pointer_timeline_owner('audio', true)!
		defer { pointer_timeline_cleanup(mut controls); document.finalize() }
		timeline := controls.dom_.timeline_element?
		assert media.play().state() == .rejected
		pointer_timeline_mouse(unsafe { &dom.EventTarget(timeline.as_node()) }, 'mousedown', 90, true)
		assert controls.scrubbing_timeline == .while_playing && media.paused() && probe.pauses == 1
		media.set_ended(mode != 'playing')
		media.set_loop(mode == 'loop')
		// Release still clears drag state and considers resuming if the live range disappeared.
		media.seekable_.clear()
		pointer_timeline_mouse(pointer_timeline_window(document), 'mouseup', 240, true)
		assert controls.scrubbing_timeline == .no && controls.scrub_seek_preemption_timer_ == none
		expected_starts := if mode == 'ended' { 0 } else { 1 }
		assert media.paused() == (mode == 'ended') && probe.starts == expected_starts
		assert probe.seeks == [125.0] && media.pending_play_promises_.len == 0
		assert !document.get_window()?.has_sticky_activation() && !media.is_allowed_to_play()
	}
}

fn test_pointer_timeline_rejects_non_mouse_and_invalid_ranges_and_accepts_mouse_subclasses() {
	mut document, mut media, mut controls, probe := pointer_timeline_owner('audio', false)!
	defer { pointer_timeline_cleanup(mut controls); document.finalize() }
	timeline := controls.dom_.timeline_element?
	target := unsafe { &dom.EventTarget(timeline.as_node()) }
	base_count := controls.registered_event_listeners_.len
	plain := dom.Event.construct_impl('mousedown', dom.EventInit{cancelable: true})!
	pointer_timeline_dispatch(target, plain, false)
	for invalid in ['missing', 'zero'] {
		media.seekable_.clear()
		if invalid == 'zero' { media.seekable_.add_range(100, 100) }
		pointer_timeline_mouse(target, 'mousedown', 90, false)
		assert controls.scrubbing_timeline == .no && controls.registered_event_listeners_.len == base_count
	}
	media.seekable_.clear()
	media.seekable_.add_range(100, 200)
	pointer := dom.PointerEvent.construct_impl('mousedown', dom.PointerEventInit{client_x: -100, cancelable: true})!
	pointer_timeline_dispatch(target, unsafe { &dom.Event(pointer) }, true)
	assert probe.seeks == [100.0] && controls.timeline_percentage == 0
	wheel := dom.WheelEvent.construct_impl('mousemove', dom.WheelEventInit{client_x: 1000, cancelable: true})!
	pointer_timeline_dispatch(pointer_timeline_window(document), unsafe { &dom.Event(wheel) }, true)
	assert controls.pending_scrub_seek_time_? == 200 && controls.timeline_percentage == 100
	drag := DragEvent.construct_impl('mouseup', DragEventInit{client_x: 140, cancelable: true})!
	pointer_timeline_dispatch(pointer_timeline_window(document), unsafe { &dom.Event(drag) }, true)
	assert probe.seeks == [100.0, 150.0] && controls.scrubbing_timeline == .no
}

fn test_pointer_timeline_once_type_guard_and_cleanup_preserve_other_window_listeners() {
	mut document, _, mut controls, probe := pointer_timeline_owner('audio', false)!
	defer { pointer_timeline_cleanup(mut controls); document.finalize() }
	timeline := controls.dom_.timeline_element?
	window := pointer_timeline_window(document)
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &PointerTimelineProbe(probe) }
			state.outside++
			return dom.js_undefined()
		}
	})
	window.add_event_listener_without_options('mousemove', outside)
	defer { window.remove_event_listener_without_options('mousemove', outside) }
	pointer_timeline_mouse(unsafe { &dom.EventTarget(timeline.as_node()) }, 'mousedown', 90, true)
	plain := dom.Event.construct_impl('mousemove', dom.EventInit{cancelable: true})!
	pointer_timeline_dispatch(window, plain, false)
	assert controls.pending_scrub_seek_time_ == none && probe.outside == 1
	// DOM once removal precedes the typed callback, even for an unrelated Event type.
	up := dom.Event.construct_impl('mouseup', dom.EventInit{cancelable: true})!
	pointer_timeline_dispatch(window, up, false)
	pointer_timeline_mouse(window, 'mouseup', 200, false)
	assert controls.scrubbing_timeline == .while_paused
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	pointer_timeline_mouse(window, 'mousemove', 240, false)
	assert probe.seeks == [125.0] && probe.outside == 2
}

fn test_pointer_timeline_uses_the_adopted_owner_window_and_skips_unowned_widgets() {
	mut first, media, mut controls, probe := pointer_timeline_owner('audio', false)!
	mut second, _, mut other, _ := pointer_timeline_owner('audio', false)!
	defer {
		pointer_timeline_cleanup(mut controls)
		pointer_timeline_cleanup(mut other)
		first.finalize()
		second.finalize()
	}
	owner := first.get_element_by_id('player')?
	second.adopt_node(owner.as_node())
	native := second.get_window()?
	assert media.document()? == second && controls.relevant_window()? == unsafe { &WindowModel(native) }
	pointer_timeline_geometry(controls, dom.Rect{40, 10, 200, 20})
	timeline := controls.dom_.timeline_element?
	pointer_timeline_mouse(unsafe { &dom.EventTarget(timeline.as_node()) }, 'mousedown', 90, true)
	pointer_timeline_mouse(pointer_timeline_window(first), 'mousemove', 240, false)
	assert controls.pending_scrub_seek_time_ == none
	pointer_timeline_mouse(pointer_timeline_window(second), 'mousemove', 140, true)
	assert controls.pending_scrub_seek_time_? == 150
	pointer_timeline_mouse(pointer_timeline_window(second), 'mouseup', 190, true)
	assert probe.seeks == [125.0, 175.0] && controls.scrubbing_timeline == .no
	pointer_timeline_mouse(pointer_timeline_window(second), 'mousemove', 0, false)
	mut ownerless := MediaControls.create(HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-pointer.example/'}))
	defer { ownerless.remove_event_listeners() }
	mut element := second.create_element('audio')!
	root := element.attach_a_user_agent_shadow_root(.named)
	mut preserving := MediaControls.create(html_media_element_for_dom_element(element)?)
	defer { preserving.remove_event_listeners() }
	assert element.shadow_root()? == root
	for absent in [ownerless, preserving] {
		assert absent.dom_.timeline_element == none && absent.registered_event_listeners_.len == 13
		assert absent.registered_event_listeners_.filter(it.event_name == 'mousedown').len == 0
	}
}
