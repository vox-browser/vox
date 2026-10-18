module html

import css
import dom

@[heap]
struct LifecycleControlsProbe {
mut:
	seeks []f64
	outside int
}

fn lifecycle_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing lifecycle media task') }
		assert task.source() == .media_element
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn lifecycle_controls_owner(kind string, playing bool) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://controls-lifecycle.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing lifecycle owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing lifecycle model') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(100, 200)
	media.set_current_playback_position(125)
	media.set_official_playback_position(125)
	media.set_paused(!playing)
	media.create_controls()
	lifecycle_controls_drain(media)
	return document, media, media.controls_ or { return error('Missing owned controls') }
}

fn lifecycle_controls_event(target &dom.EventTarget, name string, handled bool) {
	event := dom.Event.create(name, dom.EventInit{cancelable: true})
	assert target.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn lifecycle_controls_mouse(target &dom.EventTarget, name string, x f64, handled bool) {
	event := dom.MouseEvent.construct_impl(name, dom.MouseEventInit{client_x: x, bubbles: true, cancelable: true}) or { panic(err) }
	assert target.dispatch_event(unsafe { &dom.Event(event) }) == !handled
}

fn lifecycle_controls_geometry(element &dom.Element) {
	mut node := element.as_node()
	node.set_layout_node(&dom.LayoutNode{dom_node_: node, has_geometry_: true, border_box_: dom.Rect{0, 0, 100, 20}})
	assert element.get_bounding_client_rect().width == 100
}

fn test_owned_controls_create_once_destroy_and_recreate_fresh_widgets() {
	for kind in ['audio', 'video'] {
		mut document, mut media, mut controls := lifecycle_controls_owner(kind, false)!
		defer { media.finalize(); document.finalize() }
		element := document.get_element_by_id('player')?
		root := element.shadow_root()?
		button := controls.dom_.mute_button?
		bar := controls.dom_.control_bar?
		count := controls.registered_event_listeners_.len
		media.create_controls()
		assert media.controls_? == controls && element.shadow_root()? == root
		assert controls.registered_event_listeners_.len == count
		lifecycle_controls_event(unsafe { &dom.EventTarget(button.as_node()) }, 'click', true)
		assert media.muted()
		media.destroy_controls()
		assert !media.has_controls() && media.controls_ == none
		assert element.shadow_root() == none && !unsafe { &dom.Node(root) }.is_connected()
		assert controls.destroyed_ && !controls.shadow_tree_created
		assert controls.registered_event_listeners_.len == 0 && controls.dom_.control_bar == none
		assert controls.owned_shadow_root_ == none && controls.buffered_ranges_.len == 0
		lifecycle_controls_event(unsafe { &dom.EventTarget(button.as_node()) }, 'click', false)
		assert media.muted()
		media.destroy_controls()
		controls.destroy()
		media.create_controls()
		next := media.controls_?
		assert next != controls && element.shadow_root()? != root
		assert next.dom_.control_bar? != bar && next.registered_event_listeners_.len == count
		lifecycle_controls_event(unsafe { &dom.EventTarget(next.dom_.mute_button?.as_node()) }, 'click', true)
		assert !media.muted()
	}
}

fn test_destroy_controls_stops_timer_roots_and_discards_pending_scrub_without_resuming() {
	mut document, mut media, mut controls := lifecycle_controls_owner('audio', true)!
	defer { media.finalize(); document.finalize() }
	probe := &LifecycleControlsProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		seek: fn [probe] (value f64, _ MediaPlaybackSeekMode) {
			mut state := unsafe { &LifecycleControlsProbe(probe) }
			state.seeks << value
		}
	})
	controls.begin_timeline_scrubbing(130)
	controls.seek_while_scrubbing(170)
	assert controls.scrubbing_timeline == .while_playing && media.paused()
	assert probe.seeks == [130.0] && controls.pending_scrub_seek_time_? == 170
	mut hover := controls.hover_timer_?
	mut scrub := controls.scrub_seek_preemption_timer_?
	assert hover.is_active() && hover.has_activity_root() && scrub.is_active() && scrub.has_activity_root()
	old_hover_callback := hover.on_timeout
	old_scrub_callback := scrub.on_timeout
	mut bar := controls.dom_.control_bar?
	fill := controls.dom_.timeline_fill?
	old_width := css.element_style(fill).get_property_value('width')
	media.destroy_controls()
	assert !hover.is_active() && !hover.has_activity_root() && !scrub.is_active() && !scrub.has_activity_root()
	assert hover.on_timeout == unsafe { nil } && scrub.on_timeout == unsafe { nil }
	assert controls.hover_timer_ == none && controls.scrub_seek_preemption_timer_ == none
	assert controls.pending_scrub_seek_time_ == none && controls.scrubbing_timeline == .no
	assert media.paused()
	// Retained snapshots of the native closures cannot touch the detached widgets.
	old_hover_callback()
	old_scrub_callback()
	hover.fire()
	scrub.fire()
	media.finish_seeking_element()
	media.set_official_playback_position(190)
	lifecycle_controls_drain(media)
	assert probe.seeks == [130.0] && media.paused()
	assert css.element_style(fill).get_property_value('width') == old_width
	assert bar.class_list().contains('visible')
	controls.show_controls()
	controls.create_shadow_tree()
	controls.set_up_event_listeners()
	assert controls.hover_timer_ == none && controls.registered_event_listeners_.len == 0
}

fn test_destroy_controls_cancels_the_scheduling_window_after_adoption_and_preserves_other_frames() {
	mut first, mut media, controls := lifecycle_controls_owner('audio', true)!
	url := dom.URL{value: 'https://second-controls-lifecycle.example/'}
	mut second := parse_navigation_document('<!doctype html><body></body>', url, url.origin(), none)!
	defer { media.finalize(); first.finalize(); second.finalize() }
	mut first_window := unsafe { &WindowModel(first.get_window()?) }
	mut second_window := unsafe { &WindowModel(second.get_window()?) }
	pending := controls.request_animation_frame_id_
	assert pending != 0 && first_window.has_pending_animation_frame_callback(pending)
	probe := &LifecycleControlsProbe{}
	other := second_window.request_animation_frame(fn [probe] (_ f64) {
		mut state := unsafe { &LifecycleControlsProbe(probe) }
		state.outside++
	})
	assert other == pending // Same numeric ID in a different Window must survive.
	element := first.get_element_by_id('player')?
	second.adopt_node(element.as_node())
	assert media.document()? == second && controls.relevant_window()? == second_window
	media.destroy_controls()
	assert controls.request_animation_frame_id_ == 0 && controls.animation_frame_window_ == none
	assert !first_window.has_pending_animation_frame_callback(pending)
	assert second_window.has_pending_animation_frame_callback(other)
	assert element.shadow_root() == none
	first_window.run_animation_frame_callbacks(16)
	second_window.run_animation_frame_callbacks(16)
	assert probe.outside == 1 && !first_window.has_animation_frame_callbacks()
}

fn test_destroy_controls_removes_both_window_drag_pairs_and_preserves_outside_listener() {
	mut document, mut media, mut controls := lifecycle_controls_owner('audio', false)!
	defer { media.finalize(); document.finalize() }
	timeline := controls.dom_.timeline_element?
	volume := controls.dom_.volume_element?
	lifecycle_controls_geometry(timeline)
	lifecycle_controls_geometry(volume)
	window := unsafe { &dom.EventTarget(document.get_window()?) }
	probe := &LifecycleControlsProbe{}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [probe] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &LifecycleControlsProbe(probe) }
			state.outside++
			return dom.js_undefined()
		}
	})
	window.add_event_listener('mousemove', listener, dom.AddEventListenerOptions{})
	defer { window.remove_event_listener_without_options('mousemove', listener) }
	lifecycle_controls_mouse(unsafe { &dom.EventTarget(timeline.as_node()) }, 'mousedown', 25, true)
	lifecycle_controls_mouse(unsafe { &dom.EventTarget(controls.dom_.volume_area?.as_node()) }, 'mousedown', 50, true)
	assert controls.scrubbing_timeline != .no && controls.scrubbing_volume
	assert controls.registered_event_listeners_.len == 21
	media.destroy_controls()
	assert !controls.scrubbing_volume && controls.scrubbing_timeline == .no
	before := media.volume()
	lifecycle_controls_mouse(window, 'mousemove', 90, false)
	lifecycle_controls_mouse(window, 'mouseup', 90, false)
	assert probe.outside == 1 && media.volume() == before
	assert controls.registered_event_listeners_.len == 0
}

fn test_controls_preserve_foreign_and_replacement_shadow_roots_and_ownerless_adapter() {
	mut document, mut media, controls := lifecycle_controls_owner('video', false)!
	defer { media.finalize(); document.finalize() }
	mut element := document.get_element_by_id('player')?
	old := element.shadow_root()?
	element.set_shadow_root(none)
	replacement := element.attach_a_user_agent_shadow_root(.named)
	assert replacement != old
	media.destroy_controls()
	assert controls.destroyed_ && element.shadow_root()? == replacement
	media.create_controls()
	preserving := media.controls_?
	assert preserving.owned_shadow_root_ == none && preserving.dom_.control_bar == none
	assert preserving.registered_event_listeners_.len == 13
	media.destroy_controls()
	assert element.shadow_root()? == replacement
	mut ownerless := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-lifecycle.example/'})
	ownerless.create_controls()
	adapter := ownerless.controls_?
	assert ownerless.has_controls() && adapter.registered_event_listeners_.len == 13
	assert adapter.owned_shadow_root_ == none && adapter.hover_timer_ == none
	ownerless.finalize()
	assert !ownerless.has_controls() && adapter.destroyed_ && adapter.registered_event_listeners_.len == 0
}

fn test_media_finalize_eagerly_destroys_owned_controls_and_is_idempotent() {
	mut document, mut media, controls := lifecycle_controls_owner('video', true)!
	defer { document.finalize() }
	element := document.get_element_by_id('player')?
	timer := controls.hover_timer_?
	mut window := unsafe { &WindowModel(document.get_window()?) }
	pending := controls.request_animation_frame_id_
	assert window.has_pending_animation_frame_callback(pending) && timer.is_active()
	media.finalize()
	assert !media.has_controls() && controls.destroyed_ && element.shadow_root() == none
	assert !timer.is_active() && !timer.has_activity_root()
	assert !window.has_pending_animation_frame_callback(pending)
	media.finalize()
	media.fire_event('playing')
	assert !window.has_animation_frame_callbacks() && controls.registered_event_listeners_.len == 0
}
