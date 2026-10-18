module html

import css
import dom
import page

@[heap]
struct ControlsFrameProbe {
mut:
	times []f64
}

fn frame_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing frame controls task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn frame_controls_owner(kind string, playing bool) !(&dom.Document, &HTMLMediaElement, &MediaControls, &WindowModel) {
	url := dom.URL{value: 'https://frame-controls.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing media model') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(0, 20)
	media.seekable_.add_range(100, 200)
	media.set_current_playback_position(125)
	media.set_official_playback_position(125)
	media.set_paused(!playing)
	controls := MediaControls.create(media)
	frame_controls_drain(media)
	native := document.get_window() or { return error('Missing actual Window') }
	return document, media, controls, unsafe { &WindowModel(native) }
}

fn frame_controls_cleanup(mut controls MediaControls) {
	controls.remove_event_listeners()
	if mut timer := controls.hover_timer_ { timer.stop() }
	if mut timer := controls.scrub_seek_preemption_timer_ { timer.stop() }
}

fn frame_controls_assert(controls &MediaControls, percentage f64, width string) {
	assert controls.timeline_percentage == percentage
	fill := controls.dom_.timeline_fill or { panic('Missing timeline fill') }
	assert css.element_style(fill).get_property_value('width') == width
}

fn test_controls_initialize_one_frame_and_rearm_only_on_the_next_window_frame() {
	for kind in ['video', 'audio'] {
		mut document, mut media, mut controls, mut window := frame_controls_owner(kind, true)!
		defer { frame_controls_cleanup(mut controls); document.finalize() }
		initial := controls.request_animation_frame_id_
		assert initial != 0 && window.has_pending_animation_frame_callback(initial)
		assert window.animation_driver_.callbacks_.len == 1
		for _ in 0 .. 3 {
			media.fire_event('playing')
			controls.request_timeline_update()
		}
		assert controls.request_animation_frame_id_ == initial
		assert window.animation_driver_.callbacks_.len == 1
		fill := controls.dom_.timeline_fill?
		mut style := css.element_style(fill)
		style.set_property('height', '3px', '')!
		media.set_current_playback_position(150)
		media.set_official_playback_position(150)
		frame_controls_assert(controls, 25, '25%')
		window.run_animation_frame_callbacks(16)
		frame_controls_assert(controls, 50, '50%')
		assert style.get_property_value('height') == '3px'
		assert controls.timestamp == '02:05 / 03:20' // Frames update the fill, not the timestamp.
		next := controls.request_animation_frame_id_
		assert next != initial && next != 0 && window.has_pending_animation_frame_callback(next)
		assert !window.has_pending_animation_frame_callback(initial)
		assert window.animation_driver_.callbacks_.len == 1
		media.set_current_playback_position(175)
		media.set_official_playback_position(175)
		window.run_animation_frame_callbacks(32)
		frame_controls_assert(controls, 75, '75%')
		assert controls.request_animation_frame_id_ != next
		assert window.animation_driver_.callbacks_.len == 1
	}
}

fn test_controls_playing_starts_the_loop_and_pause_end_or_blocking_stops_rearming() {
	for stop in ['pause', 'ended', 'blocked'] {
		mut document, mut media, mut controls, mut window := frame_controls_owner('audio', false)!
		defer { frame_controls_cleanup(mut controls); document.finalize() }
		assert controls.request_animation_frame_id_ == 0 && !window.has_animation_frame_callbacks()
		media.fire_event('playing')
		assert controls.request_animation_frame_id_ == 0
		mut native := document.get_window()?
		native.set_last_activation_timestamp(dom.current_high_resolution_time(native))
		assert native.has_sticky_activation()
		promise := media.play()
		assert !media.paused() && controls.request_animation_frame_id_ == 0
		frame_controls_drain(media) // Actual queued playing delivery starts the loop.
		assert promise.state() == .fulfilled
		pending := controls.request_animation_frame_id_
		assert pending != 0 && window.has_pending_animation_frame_callback(pending)
		match stop {
			'pause' { media.pause() }
			'ended' { media.set_ended(true) }
			else { media.set_ready_state(.have_current_data) }
		}
		assert !media.potentially_playing()
		media.set_official_playback_position(150)
		window.run_animation_frame_callbacks(16)
		frame_controls_assert(controls, 50, '50%') // The already pending frame still runs once.
		assert controls.request_animation_frame_id_ == 0 && !window.has_animation_frame_callbacks()
		media.fire_event('playing')
		assert controls.request_animation_frame_id_ == 0
		media.set_paused(false)
		media.set_ended(false)
		media.set_ready_state(.have_enough_data)
		frame_controls_drain(media)
		media.fire_event('playing')
		assert controls.request_animation_frame_id_ != 0
		assert window.animation_driver_.callbacks_.len == 1
	}
}

fn test_pending_controls_frame_keeps_scrub_preview_while_refreshing_buffered_ranges() {
	mut document, mut media, mut controls, mut window := frame_controls_owner('video', true)!
	defer { frame_controls_cleanup(mut controls); document.finalize() }
	assert controls.request_animation_frame_id_ != 0
	controls.begin_timeline_scrubbing(160)
	assert controls.scrubbing_timeline == .while_playing && media.paused()
	frame_controls_assert(controls, 60, '60%')
	media.set_current_playback_position(140)
	media.set_official_playback_position(140)
	media.buffered_.add_range(100, 180)
	window.run_animation_frame_callbacks(16)
	frame_controls_assert(controls, 60, '60%')
	assert controls.timestamp == '02:40 / 03:20'
	assert controls.buffered_ranges_.len == 1
	buffered := controls.buffered_ranges_[0].element
	style := css.element_style(buffered)
	assert style.get_property_value('width') == '80%'
	assert controls.request_animation_frame_id_ == 0 && !window.has_animation_frame_callbacks()
}

fn test_controls_use_the_adopted_owner_window_and_cleanup_preserves_other_callbacks() {
	mut first, mut media, mut controls, mut first_window := frame_controls_owner('audio', true)!
	mut second, _, mut other_controls, mut second_window := frame_controls_owner('audio', false)!
	defer {
		frame_controls_cleanup(mut controls)
		frame_controls_cleanup(mut other_controls)
		first.finalize()
		second.finalize()
	}
	assert controls.relevant_window()? == first_window
	element := first.get_element_by_id('player')?
	second.adopt_node(element.as_node())
	assert media.document()? == second && controls.relevant_window()? == second_window
	media.set_paused(false) // Resume after adoption's removal pause before the pending frame.
	first_window.run_animation_frame_callbacks(16)
	assert !first_window.has_animation_frame_callbacks()
	pending := controls.request_animation_frame_id_
	assert pending != 0 && second_window.has_pending_animation_frame_callback(pending)
	probe := &ControlsFrameProbe{}
	unrelated := second_window.request_animation_frame(fn [probe] (now f64) {
		mut state := unsafe { &ControlsFrameProbe(probe) }
		state.times << now
	})
	controls.remove_event_listeners()
	assert !second_window.has_pending_animation_frame_callback(pending)
	assert second_window.has_pending_animation_frame_callback(unrelated)
	media.set_official_playback_position(175)
	media.fire_event('playing')
	second_window.run_animation_frame_callbacks(32)
	assert probe.times == [32.0] && !second_window.has_animation_frame_callbacks()
	frame_controls_assert(controls, 25, '25%')
	mut ownerless := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-frame.example/'})
	ownerless.set_ready_state(.have_enough_data)
	ownerless.set_paused(false)
	mut adapter := MediaControls.create(ownerless)
	defer { adapter.remove_event_listeners() }
	assert adapter.relevant_window() == none && adapter.request_animation_frame_id_ == 0
	ownerless.fire_event('playing')
	assert adapter.request_animation_frame_id_ == 0
}

fn test_controls_timeline_updates_through_actual_rendering_opportunities() {
	mut document, mut media, mut controls, window := frame_controls_owner('video', true)!
	defer { frame_controls_cleanup(mut controls); document.finalize() }
	mut owner := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	owner.set_local_root_navigable(window.navigable() or { panic('Missing navigable') })!
	document.update_the_visibility_state(.visible)
	mut client := owner.client()
	client.set_manual_rendering_opportunities(true)
	mut event_loop := EventLoop.create(.window)
	event_loop.register_document(document)
	media.set_current_playback_position(150)
	media.set_official_playback_position(150)
	client.request_frame()
	client.inject_rendering_opportunity(150)
	event_loop.update_the_rendering()
	frame_controls_assert(controls, 50, '50%')
	assert window.has_pending_animation_frame_callback(controls.request_animation_frame_id_)
	assert window.animation_driver_.callbacks_.len == 1
}
