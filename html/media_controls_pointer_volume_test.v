module html

import css
import dom

@[heap]
struct PointerVolumeProbe {
mut:
	position f64 = 125
	volumes []f64
	seeks []f64
	outside int
	adopted bool
}

fn pointer_volume_drain(media &HTMLMediaElement, allowed []&dom.Document) []&dom.Document {
	mut owners := []&dom.Document{}
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return owners }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing pointer volume task') }
		owner := task.document() or { panic('Missing pointer volume task owner') }
		assert task.source() == .media_element && owner in allowed
		owners << owner
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
	return owners
}

fn pointer_volume_geometry(element &dom.Element, rect dom.Rect) {
	mut node := element.as_node()
	node.set_layout_node(&dom.LayoutNode{dom_node_: node, has_geometry_: true, border_box_: rect})
	actual := element.get_bounding_client_rect()
	assert actual.x == rect.x && actual.width == rect.width
}

fn pointer_volume_window(document &dom.Document) &dom.EventTarget {
	window := document.get_window() or { panic('Missing pointer volume Window') }
	return unsafe { &dom.EventTarget(window) }
}

fn pointer_volume_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls, &PointerVolumeProbe) {
	url := dom.URL{value: 'https://pointer-volume.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing pointer volume owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing pointer volume media') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(100, 200)
	media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
	}
	media.set_show_poster(false)
	media.set_volume(0.75)!
	media.set_muted(true)
	probe := &PointerVolumeProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [probe] () f64 { return probe.position }
		set_volume: fn [probe] (value f64) {
			mut state := unsafe { &PointerVolumeProbe(probe) }
			state.volumes << value
		}
		seek: fn [probe] (value f64, mode MediaPlaybackSeekMode) {
			assert mode == .accurate
			mut state := unsafe { &PointerVolumeProbe(probe) }
			state.seeks << value
			state.position = value
		}
	})
	media.set_current_playback_position(125)
	media.set_official_playback_position(125)
	controls := MediaControls.create(media)
	pointer_volume_drain(media, [document])
	area := controls.dom_.volume_area or { return error('Missing volume area') }
	volume := controls.dom_.volume_element or { return error('Missing volume element') }
	pointer_volume_geometry(area, dom.Rect{0, 0, 1000, 40})
	pointer_volume_geometry(volume, dom.Rect{40, 10, 200, 20})
	return document, media, controls, probe
}

fn pointer_volume_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
	if mut timer := controls.scrub_seek_preemption_timer_ { timer.stop() }
}

fn pointer_volume_dispatch(target &dom.EventTarget, event &dom.Event, handled bool) {
	assert !event.is_trusted()
	assert target.dispatch_event(event) == !handled && event.default_prevented() == handled
}

fn pointer_volume_mouse(target &dom.EventTarget, name string, x f64, handled bool) {
	event := dom.MouseEvent.construct_impl(name, dom.MouseEventInit{client_x: x, bubbles: true, cancelable: true, button: 2}) or { panic(err) }
	pointer_volume_dispatch(target, unsafe { &dom.Event(event) }, handled)
}

fn test_volume_drag_uses_the_inner_slider_unmutes_and_updates_live_geometry_without_seeking() {
	for kind in ['audio', 'video'] {
		mut document, media, mut controls, probe := pointer_volume_owner(kind)!
		defer { pointer_volume_cleanup(mut controls); document.finalize() }
		fill := controls.dom_.volume_fill?
		volume := controls.dom_.volume_element?
		mut button := controls.dom_.mute_button?
		mut classes := button.class_list()
		classes.add(['retained'])!
		mut style := css.element_style(fill)
		style.set_property('height', '3px', 'important')!
		window := pointer_volume_window(document)
		controls.hide_controls()
		assert !controls.visible && controls.hover_timer_ == none
		before := media.event_count('volumechange')
		count := controls.registered_event_listeners_.len
		pointer_volume_mouse(unsafe { &dom.EventTarget(fill.as_node()) }, 'mousedown', 90, true)
		assert controls.scrubbing_volume && controls.visible && controls.hover_timer_ != none
		assert media.volume() == 0.25 && !media.muted() && controls.volume_percentage == 25
		assert probe.volumes == [0.0, 0.25] && media.event_count('volumechange') == before
		assert controls.registered_event_listeners_.len == count + 2
		assert style.get_property_value('width') == '25%' && !controls.was_muted
		controls.hide_controls()
		assert controls.visible // A live volume drag protects the bar from hiding.
		pointer_volume_drain(media, [document])
		assert media.event_count('volumechange') == before + 2
		pointer_volume_mouse(window, 'mousemove', 1000, true)
		assert media.volume() == 1 && probe.volumes.last() == 1
		pointer_volume_geometry(volume, dom.Rect{20, 10, 400, 20})
		pointer_volume_mouse(window, 'mousemove', 220, true)
		assert media.volume() == 0.5 && controls.volume_percentage == 50
		pointer_volume_mouse(window, 'mouseup', -1000, true)
		assert media.volume() == 0 && !media.muted() && !controls.scrubbing_volume
		assert style.get_property_value('width') == '0%' && style.get_property_value('height') == '3px'
		assert style.get_property_priority('height') == 'important' && classes.contains('retained')
		pointer_volume_mouse(window, 'mousemove', 220, false)
		pointer_volume_mouse(window, 'mouseup', 220, false)
		assert media.volume() == 0 && probe.seeks == [] && media.current_time() == 125 && media.paused()
		controls.hide_controls()
		assert !controls.visible && controls.hover_timer_ == none
		pointer_volume_drain(media, [document])
	}
}

fn test_volume_drag_mouse_subclasses_type_guards_and_once_cleanup_keep_outside_window_listeners() {
	mut document, media, mut controls, probe := pointer_volume_owner('audio')!
	defer { pointer_volume_cleanup(mut controls); document.finalize() }
	area := controls.dom_.volume_area?
	target := unsafe { &dom.EventTarget(area.as_node()) }
	window := pointer_volume_window(document)
	outside := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &PointerVolumeProbe(probe) }
			state.outside++
			return dom.js_undefined()
		}
	})
	window.add_event_listener_without_options('mousemove', outside)
	defer { window.remove_event_listener_without_options('mousemove', outside) }
	plain := dom.Event.construct_impl('mousedown', dom.EventInit{cancelable: true})!
	pointer_volume_dispatch(target, plain, false)
	assert !controls.scrubbing_volume && media.volume() == 0.75 && media.muted()
	pointer := dom.PointerEvent.construct_impl('mousedown', dom.PointerEventInit{client_x: 90, cancelable: true})!
	pointer_volume_dispatch(target, unsafe { &dom.Event(pointer) }, true)
	move := dom.Event.construct_impl('mousemove', dom.EventInit{cancelable: true})!
	pointer_volume_dispatch(window, move, false)
	assert media.volume() == 0.25 && probe.outside == 1
	wheel := dom.WheelEvent.construct_impl('mousemove', dom.WheelEventInit{client_x: 1000, cancelable: true})!
	pointer_volume_dispatch(window, unsafe { &dom.Event(wheel) }, true)
	drag := DragEvent.construct_impl('mouseup', DragEventInit{client_x: 140, cancelable: true})!
	pointer_volume_dispatch(window, unsafe { &dom.Event(drag) }, true)
	assert media.volume() == 0.5 && !controls.scrubbing_volume
	pointer_volume_mouse(window, 'mousemove', 0, false)
	assert probe.outside == 3
	pointer_volume_mouse(target, 'mousedown', 90, true)
	up := dom.Event.construct_impl('mouseup', dom.EventInit{cancelable: true})!
	pointer_volume_dispatch(window, up, false)
	pointer_volume_mouse(window, 'mouseup', 240, false)
	assert controls.scrubbing_volume // Once removal precedes the typed callback.
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
	pointer_volume_mouse(window, 'mousemove', 240, false)
	assert probe.outside == 4 && media.volume() == 0.25
	pointer_volume_drain(media, [document])
}

fn test_volume_and_timeline_drags_keep_independent_geometry_flags_and_release_callbacks() {
	mut document, mut media, mut controls, probe := pointer_volume_owner('video')!
	defer { pointer_volume_cleanup(mut controls); document.finalize() }
	timeline := controls.dom_.timeline_element?
	area := controls.dom_.volume_area?
	volume := controls.dom_.volume_element?
	pointer_volume_geometry(timeline, dom.Rect{40, 10, 200, 20})
	pointer_volume_geometry(volume, dom.Rect{300, 10, 100, 20})
	pointer_volume_mouse(unsafe { &dom.EventTarget(timeline.as_node()) }, 'mousedown', 140, true)
	pointer_volume_mouse(unsafe { &dom.EventTarget(area.as_node()) }, 'mousedown', 325, true)
	assert controls.scrubbing_timeline == .while_paused && controls.scrubbing_volume
	assert probe.seeks == [150.0] && media.volume() == 0.25
	controls.hide_controls()
	assert controls.visible
	window := pointer_volume_window(document)
	pointer_volume_mouse(window, 'mousemove', 350, true)
	assert controls.pending_scrub_seek_time_? == 200 && media.volume() == 0.5
	pointer_volume_mouse(window, 'mouseup', 375, true)
	assert controls.scrubbing_timeline == .no && !controls.scrubbing_volume
	assert probe.seeks == [150.0, 200.0] && media.volume() == 0.75
	pointer_volume_mouse(window, 'mousemove', 0, false)
	pointer_volume_mouse(window, 'mouseup', 0, false)
	controls.hide_controls()
	assert !controls.visible && media.paused()
	media.finish_seeking_element()
	pointer_volume_drain(media, [document])
}

fn test_volume_drag_uses_the_adopted_window_and_skips_ownerless_or_preserved_widgets() {
	mut first, media, mut controls, _ := pointer_volume_owner('audio')!
	mut second, _, mut other, _ := pointer_volume_owner('audio')!
	defer { pointer_volume_cleanup(mut controls); pointer_volume_cleanup(mut other); first.finalize(); second.finalize() }
	owner := first.get_element_by_id('player')?
	second.adopt_node(owner.as_node())
	assert media.document()? == second
	area := controls.dom_.volume_area?
	volume := controls.dom_.volume_element?
	assert volume.document() == second && area.document() == second
	pointer_volume_geometry(volume, dom.Rect{40, 10, 200, 20})
	pointer_volume_mouse(unsafe { &dom.EventTarget(area.as_node()) }, 'mousedown', 90, true)
	pointer_volume_mouse(pointer_volume_window(first), 'mousemove', 240, false)
	assert media.volume() == 0.25
	pointer_volume_mouse(pointer_volume_window(second), 'mousemove', 240, true)
	assert media.volume() == 1
	pointer_volume_mouse(pointer_volume_window(second), 'mouseup', 140, true)
	assert media.volume() == 0.5 && !controls.scrubbing_volume
	pointer_volume_drain(media, [second])
	mut ownerless := MediaControls.create(HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-volume-drag.example/'}))
	defer { ownerless.remove_event_listeners() }
	mut element := second.create_element('audio')!
	root := element.attach_a_user_agent_shadow_root(.named)
	mut preserving := MediaControls.create(html_media_element_for_dom_element(element)?)
	defer { preserving.remove_event_listeners() }
	assert element.shadow_root()? == root
	for absent in [ownerless, preserving] {
		assert absent.dom_.volume_area == none && absent.dom_.volume_element == none
		assert absent.registered_event_listeners_.len == 13
		assert absent.registered_event_listeners_.filter(it.event_name == 'mousedown').len == 0
	}
}

fn test_volume_drag_selects_the_current_window_after_reentrant_backend_adoption() {
	mut first, mut media, mut controls, probe := pointer_volume_owner('audio')!
	mut second, _, mut other, _ := pointer_volume_owner('audio')!
	defer { pointer_volume_cleanup(mut controls); pointer_volume_cleanup(mut other); first.finalize(); second.finalize() }
	owner := first.get_element_by_id('player')?
	area := controls.dom_.volume_area?
	volume := controls.dom_.volume_element?
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_volume: fn [probe, second, owner] (value f64) {
			mut state := unsafe { &PointerVolumeProbe(probe) }
			state.volumes << value
			if !state.adopted {
				state.adopted = true
				mut document := unsafe { &dom.Document(second) }
				document.adopt_node(owner.as_node())
			}
		}
	})
	pointer_volume_mouse(unsafe { &dom.EventTarget(area.as_node()) }, 'mousedown', 90, true)
	assert probe.adopted && media.document()? == second && media.volume() == 0.25 && !media.muted()
	pointer_volume_geometry(volume, dom.Rect{40, 10, 200, 20})
	pointer_volume_mouse(pointer_volume_window(first), 'mousemove', 240, false)
	assert media.volume() == 0.25
	pointer_volume_mouse(pointer_volume_window(second), 'mousemove', 240, true)
	pointer_volume_mouse(pointer_volume_window(second), 'mouseup', 140, true)
	assert media.volume() == 0.5 && !controls.scrubbing_volume
	// Each queued task retains the document that owned the element when it was queued.
	owners := pointer_volume_drain(media, [first, second])
	assert owners[0] == first && second in owners
	pointer_volume_mouse(pointer_volume_window(second), 'mousemove', 0, false)
}
