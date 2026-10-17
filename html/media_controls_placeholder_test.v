module html

import css
import dom

fn placeholder_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://placeholder-controls.example/'}
	mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media owner') }
	media := html_media_element_for_dom_element(element) or { return error('Missing media model') }
	controls := MediaControls.create(media)
	return document, media, controls
}

fn placeholder_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing placeholder media task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn placeholder_controls_bitmap(_ dom.URL) !&dom.Bitmap_ {
	return &dom.Bitmap_{width: 1, height: 1, pitch: 4, data: [u8(0), 0, 0, 255]}
}

fn test_media_controls_placeholder_follows_all_video_representations() {
	mut document, mut media, mut controls := placeholder_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	video := media.video_element_model_ or { panic('Missing concrete video model') }
	element := document.get_element_by_id('player')?
	assert unsafe { &dom.HTMLVideoElement(element) }.video_element_model_ == voidptr(video)
	assert video.poster_fetch_generation_ == 0 && video.poster_frame() == none
	assert media.network_state() == .empty && !document.anything_is_delaying_the_load_event()
	assert video.current_representation() == .transparent_black && controls.placeholder_visible
	media.set_show_poster(false)
	media.set_ready_state(.have_enough_data)
	controls.update_placeholder_visibility()
	assert video.current_representation() == .transparent_black && controls.placeholder_visible
	media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
	controls.update_placeholder_visibility()
	assert video.current_representation() == .video_frame && !controls.placeholder_visible
	media.set_show_poster(true)
	controls.update_placeholder_visibility()
	assert video.current_representation() == .first_video_frame && controls.placeholder_visible
	mut mutable_video := unsafe { &HTMLVideoElementModel(video) }
	mutable_video.set_poster_fetch_hook(placeholder_controls_bitmap)
	mutable_video.set_poster('/poster.png')
	controls.update_placeholder_visibility()
	assert video.current_representation() == .poster_frame && controls.placeholder_visible
	media.set_current_playback_position(1)
	controls.update_placeholder_visibility()
	assert media.show_poster() && video.current_representation() == .video_frame && !controls.placeholder_visible
	media.set_current_playback_position(0)
	media.set_paused(false)
	controls.update_placeholder_visibility()
	assert media.show_poster() && video.current_representation() == .video_frame && !controls.placeholder_visible
	placeholder_controls_drain(media)
}

fn test_media_controls_placeholder_events_preserve_unrelated_inline_style() {
	mut document, mut media, mut controls := placeholder_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	placeholder := controls.dom_.placeholder_circle or { panic('Missing placeholder') }
	mut style := css.element_style(placeholder)
	style.set_property('color', 'red', 'important')!
	assert style.get_property_value('display') == 'flex'
	media.set_ready_state(.have_enough_data)
	media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
	media.set_paused(false)
	media.fire_event('playing')
	assert !controls.placeholder_visible && style.get_property_value('display') == 'none'
	media.set_paused(true)
	media.fire_event('pause')
	assert controls.placeholder_visible && style.get_property_value('display') == 'flex'
	media.set_current_playback_position(4)
	media.fire_event('seeked')
	assert !controls.placeholder_visible && style.get_property_value('display') == 'none'
	media.set_ready_state(.have_nothing)
	media.fire_event('emptied')
	assert controls.placeholder_visible && style.get_property_value('display') == 'flex'
	assert style.get_property_value('color') == 'red' && style.get_property_priority('color') == 'important'
	placeholder_controls_drain(media)
}

fn test_media_controls_cannot_hide_video_placeholder_or_active_scrub_and_hover() {
	mut document, mut media, mut controls := placeholder_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	controls.hide_controls()
	assert controls.visible
	media.set_ready_state(.have_enough_data)
	media.on_video_track_added(MediaTrackMetadata{identifier: 3, pixel_width: 320, pixel_height: 180})
	controls.hide_controls()
	assert controls.visible // First video frame still needs the placeholder.
	media.set_paused(false)
	for state in [MediaControlsScrubbing.while_paused, .while_playing] {
		controls.scrubbing_timeline = state
		controls.hide_controls()
		assert controls.visible
	}
	controls.scrubbing_timeline = .no
	controls.scrubbing_volume = true
	controls.hide_controls()
	assert controls.visible
	controls.scrubbing_volume = false
	controls.hovering_controls = true
	controls.hide_controls()
	assert controls.visible
	controls.hovering_controls = false
	// Query the live representation even before the cached placeholder flag refreshes.
	assert controls.placeholder_visible && media.show_poster()
	controls.hide_controls()
	assert !controls.visible
	controls.show_controls()
	assert controls.visible
	media.set_paused(true)
	controls.hide_controls()
	assert controls.visible
	placeholder_controls_drain(media)
}

fn test_media_controls_placeholder_is_video_only_and_ownerless_state_remains_compatible() {
	mut document, media, mut controls := placeholder_controls_owner('audio')!
	defer { controls.remove_event_listeners(); document.finalize() }
	assert media.video_element_model_ == none && controls.dom_.placeholder_circle == none
	assert !controls.should_show_placeholder() && !controls.placeholder_visible
	container := controls.dom_.container or { panic('Missing audio controls') }
	assert container.query_selector('.placeholder-circle') == none
	assert controls.dom_.play_pause_icon != none && controls.dom_.timeline_fill != none
	controls.hide_controls()
	assert !controls.visible
	mut ownerless := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless.example/'})
	mut adapter := MediaControls.create(ownerless)
	defer { adapter.remove_event_listeners() }
	assert adapter.should_show_placeholder() && adapter.dom_.placeholder_circle == none
	adapter.hide_controls()
	assert !adapter.visible
	ownerless.set_ready_state(.have_enough_data)
	ownerless.set_show_poster(false)
	adapter.update_placeholder_visibility()
	assert !adapter.placeholder_visible
	HTMLVideoElementModel.create(ownerless, dom.URL{value: 'https://ownerless.example/'})
	adapter.update_placeholder_visibility()
	assert adapter.placeholder_visible // No video channel: transparent black.
	placeholder_controls_drain(ownerless)
}
