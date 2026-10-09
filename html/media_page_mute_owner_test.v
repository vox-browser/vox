module html

import dom
import math
import page

@[heap]
struct PageMuteObservation {
mut:
	volumes []f64
	audibility_at_volume []bool
	events []string
}

fn page_mute_drain(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn page_mute_document(owner &page.Page, tag string) !&dom.Document {
	url := dom.URL{ value: 'https://page-mute.example.test/' }
	mut document := parse_navigation_document('<${tag} id="player"></${tag}>', url, url.origin(), none)!
	document.set_page(unsafe { &dom.Page(owner) })
	return document
}

fn page_mute_load(document &dom.Document, ready MediaReadyState) !&HTMLMediaElement {
	element := document.get_element_by_id('player') or { return error('missing media') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing model') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{
			mime_type: 'video/mp4'
			duration: 20
			audio_tracks: [MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
			video_tracks: [MediaTrackMetadata{ identifier: 2, name: 'Video', pixel_width: 320, pixel_height: 180 }]
		}
	})
	media.set_source('/movie.mp4')
	media.load()!
	page_mute_drain(media)
	media.set_ready_state(ready)
	media.set_show_poster(false)
	page_mute_drain(media)
	return media
}

fn page_mute_observe(mut media HTMLMediaElement) &PageMuteObservation {
	observation := &PageMuteObservation{}
	document := media.document() or { panic('missing document') }
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_volume: fn [observation, document] (volume f64) {
			mut state := unsafe { &PageMuteObservation(observation) }
			state.volumes << volume
			state.audibility_at_volume << document.is_playing_audio()
		}
	})
	media.set_on_event('volumechange', &dom.CallbackType{
		handle_event: fn [observation] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &PageMuteObservation(observation) }
			state.events << 'volumechange'
			return dom.js_undefined()
		}
	})
	return observation
}

fn test_page_mute_updates_each_actual_owner_without_volume_events_or_wake_lock_changes() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut owner := page.Page.create(1)!
	first_document := page_mute_document(owner, 'video')!
	second_document := page_mute_document(owner, 'audio')!
	mut first := page_mute_load(first_document, .have_future_data)!
	mut second := page_mute_load(second_document, .have_future_data)!
	first.set_volume(0.5)!
	second.set_volume(0.25)!
	first.play()
	second.play()
	page_mute_drain(first)
	page_mute_drain(second)
	first_state := page_mute_observe(mut first)
	second_state := page_mute_observe(mut second)
	assert first_document.is_playing_audio() && second_document.is_playing_audio()
	assert owner.is_screen_wake_lock_active()
	owner.set_page_mute_state(.muted)
	assert first.effective_media_volume() == 0 && second.effective_media_volume() == 0
	assert first_state.volumes == [f64(0)] && second_state.volumes == [f64(0)]
	assert !first.is_playing_audio() && !second.is_playing_audio()
	assert !first_document.is_playing_audio() && !second_document.is_playing_audio()
	assert !first.paused() && !second.paused() && owner.is_screen_wake_lock_active()
	assert !first.muted() && !second.muted() && first.volume() == 0.5 && second.volume() == 0.25
	owner.set_page_mute_state(.muted)
	assert first_state.volumes.len == 1 && second_state.volumes.len == 1
	owner.toggle_page_mute_state()
	assert first_state.volumes == [f64(0), 0.5] && second_state.volumes == [f64(0), 0.25]
	assert first_state.audibility_at_volume == [true, false] && second_state.audibility_at_volume == [true, false]
	assert first_document.is_playing_audio() && second_document.is_playing_audio()
	assert owner.client().events.filter(it.name == 'change-audio-play-state').map(it.text) == ['playing', 'playing', 'paused', 'paused', 'playing', 'playing']
	assert owner.client().events.filter(it.name == 'change-screen-wake-lock-state').len == 1
	page_mute_drain(first)
	page_mute_drain(second)
	assert first_state.events == [] && second_state.events == []
	first.pause()
	second.pause()
	page_mute_drain(first)
	page_mute_drain(second)
}

fn test_muted_page_precedes_model_creation_and_stays_isolated_from_other_pages() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut owner := page.Page.create(1)!
	owner.set_page_mute_state(.muted)
	document := page_mute_document(owner, 'audio')!
	mut media := page_mute_load(document, .have_future_data)!
	mut other_owner := page.Page.create(1)!
	other_document := page_mute_document(other_owner, 'audio')!
	mut other := page_mute_load(other_document, .have_future_data)!
	assert media.effective_media_volume() == 0 && other.effective_media_volume() == 1
	media.play()
	other.play()
	assert !document.is_playing_audio() && other_document.is_playing_audio()
	media.set_volume(0.75)!
	assert media.volume() == 0.75 && media.effective_media_volume() == 0
	media.set_muted(true)
	owner.set_page_mute_state(.unmuted)
	assert media.effective_media_volume() == 0 && !document.is_playing_audio()
	media.set_muted(false)
	assert document.is_playing_audio() && other_document.is_playing_audio()
	media.set_page_muted(true)
	assert owner.page_mute_state() == .muted && other_owner.page_mute_state() == .unmuted
	media.set_page_muted(false)
	assert owner.page_mute_state() == .unmuted && document.is_playing_audio()
	media.pause()
	other.pause()
	page_mute_drain(media)
	page_mute_drain(other)
}

fn test_page_mute_realigns_actual_hidden_timers_only_when_audibility_changes() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut owner := page.Page.create(1)!
	mut document := page_mute_document(owner, 'audio')!
	mut media := page_mute_load(document, .have_future_data)!
	window := unsafe { &WindowModel(document.get_window()?) }
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(1_000)
	scope.set_hidden_document_intensive_timer_throttling(60_000, 1_000, 1_000)
	document.update_the_visibility_state(.hidden)
	grace := scope.intensive_timer_grace_deadline_ms_
	id := scope.set_timeout(timer_source_handler(''), 25, [])
	media.play()
	audible := scope.active_timers_[id] or { panic('missing audible timer') }
	assert audible.due_time_ms == audible.deadline_ms
	owner.set_page_mute_state(.muted)
	silent := scope.active_timers_[id] or { panic('missing silent timer') }
	assert !document.is_playing_audio() && !media.is_playing_audio()
	assert math.fmod(silent.due_time_ms - scope.hidden_timer_grid_origin_ms(), 1_000) == 0
	owner.set_page_mute_state(.unmuted)
	restored := scope.active_timers_[id] or { panic('missing restored timer') }
	assert document.is_playing_audio() && restored.due_time_ms == restored.deadline_ms
	assert scope.intensive_timer_grace_deadline_ms_ == grace
	scope.clear_timeout(id)
	media.pause()
	page_mute_drain(media)
}

fn test_registered_silent_owner_receives_page_volume_updates_and_finalize_unregisters_it() {
	mut owner := page.Page.create(1)!
	mut document := page_mute_document(owner, 'audio')!
	mut media := page_mute_load(document, .have_metadata)!
	element := document.get_element_by_id('player')?
	mut node := element.as_node()
	node.remove(false)
	page_mute_drain(media)
	state := page_mute_observe(mut media)
	id := u64(node.unique_id().value())
	assert id in owner.media_elements
	owner.set_page_mute_state(.muted)
	assert state.volumes == [f64(0)] && !media.is_playing_audio()
	assert owner.client().events.filter(it.name == 'change-audio-play-state').len == 0
	media.finalize()
	media.finalize()
	assert id !in owner.media_elements
	owner.set_page_mute_state(.unmuted)
	assert state.volumes == [f64(0)] && state.events == []
}

fn test_effective_volume_queries_the_current_document_page_after_adoption() {
	mut first_owner := page.Page.create(1)!
	mut first_document := page_mute_document(first_owner, 'audio')!
	mut media := page_mute_load(first_document, .have_metadata)!
	mut second_owner := page.Page.create(1)!
	second_owner.set_page_mute_state(.muted)
	mut second_document := page_mute_document(second_owner, 'audio')!
	element := first_document.get_element_by_id('player')?
	mut node := element.as_node()
	node.remove(false)
	page_mute_drain(media)
	media.set_volume(0.5)!
	second_document.adopt_node(node)
	assert media.effective_media_volume() == 0 && !media.muted()
	first_owner.set_page_mute_state(.muted)
	first_owner.set_page_mute_state(.unmuted)
	assert media.effective_media_volume() == 0
	first_document.adopt_node(node)
	assert media.effective_media_volume() == 0.5
	page_mute_drain(media)
	mut standalone := HTMLMediaElement.create(none, dom.URL{ value: 'https://adapter.example.test/' })
	standalone.set_page_muted(true)
	assert standalone.effective_media_volume() == 0
	standalone.set_page_muted(false)
	assert standalone.effective_media_volume() == 1
}
