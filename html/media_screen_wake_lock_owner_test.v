module html

import dom
import page

@[heap]
struct MediaWakeLockObservation {
mut:
	starts int
	pauses int
}

fn media_wake_drain(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn media_wake_load(document &dom.Document, id string, audio bool, video bool, ready MediaReadyState) !&HTMLMediaElement {
	element := document.get_element_by_id(id) or { return error('missing media element') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	media.set_fetch_hook(fn [audio, video] (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{
			mime_type: 'video/mp4'
			duration: 20
			audio_tracks: if audio { [MediaTrackMetadata{ identifier: 1, name: 'Audio' }] } else { [] }
			video_tracks: if video { [MediaTrackMetadata{ identifier: 2, name: 'Video', pixel_width: 320, pixel_height: 180 }] } else { [] }
		}
	})
	media.set_source('/movie.mp4')
	media.load()!
	media_wake_drain(media)
	media.set_ready_state(ready)
	media.set_show_poster(false)
	media_wake_drain(media)
	return media
}

fn media_wake_owner(tag string, audio bool, video bool, ready MediaReadyState) !(&HTMLMediaElement, &page.Page) {
	url := dom.URL{ value: 'https://media-wake.example.test/' }
	mut document := parse_navigation_document('<${tag} id="player"></${tag}>', url, url.origin(), none)!
	owner := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	media := media_wake_load(document, 'player', audio, video, ready)!
	return media, owner
}

fn media_wake_client_states(owner &page.Page) []string {
	return owner.client().events.filter(it.name == 'change-screen-wake-lock-state').map(it.text)
}

fn test_video_play_eligibility_and_pause_release_follow_the_actual_caller_order() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media, owner := media_wake_owner('video', true, true, .have_future_data)!
	state := &MediaWakeLockObservation{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [owner, state, media] () {
			assert owner.is_screen_wake_lock_active() && !media.is_playing_audio()
			assert media_wake_client_states(owner) == ['acquired']
			mut observation := unsafe { &MediaWakeLockObservation(state) }
			observation.starts++
		}
		pause: fn [owner, state] () {
			assert owner.is_screen_wake_lock_active()
			mut observation := unsafe { &MediaWakeLockObservation(state) }
			observation.pauses++
		}
	})
	promise := media.play()
	assert state.starts == 1 && owner.is_screen_wake_lock_active()
	assert promise.state() == .pending && media.event_count('playing') == 0
	assert owner.client().events.filter(it.name in ['change-audio-play-state', 'change-screen-wake-lock-state']).map(it.text) == ['acquired', 'playing']
	media.pause()
	assert state.pauses == 1 && !owner.is_screen_wake_lock_active()
	assert owner.client().events.filter(it.name in ['change-audio-play-state', 'change-screen-wake-lock-state']).map(it.text) == ['acquired', 'playing', 'paused', 'released']
	media_wake_drain(media)
	assert promise.state() == .fulfilled && media.event_count('playing') == 1
	assert !owner.is_screen_wake_lock_active() && media_wake_client_states(owner) == ['acquired', 'released']
}

fn test_wake_lock_requires_video_and_both_track_roles_but_does_not_depend_on_muted_volume() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	for item in [['audio', 'both'], ['video', 'no-audio'], ['video', 'no-video']] {
		mut media, owner := media_wake_owner(item[0], item[1] != 'no-audio', item[1] != 'no-video', .have_future_data)!
		media.play()
		assert !owner.is_screen_wake_lock_active()
		media.pause()
		media_wake_drain(media)
	}
	mut media, owner := media_wake_owner('video', true, true, .have_future_data)!
	media.set_muted(true)
	media.set_volume(0)!
	media.play()
	assert owner.is_screen_wake_lock_active() && !media.is_playing_audio()
	mut audio := media.audio_tracks().item(0)?
	audio.set_enabled(false)
	assert !owner.is_screen_wake_lock_active()
	audio.set_enabled(true)
	assert owner.is_screen_wake_lock_active()
	mut video := media.video_tracks().item(0)?
	video.set_selected(false)
	assert !owner.is_screen_wake_lock_active() && media.selected_video_track_sink() == none
	video.set_selected(true)
	assert owner.is_screen_wake_lock_active()
	assert media.selected_video_track_sink()? == video
	media.on_video_track_added(MediaTrackMetadata{ identifier: 3, name: 'Alternate' })
	mut alternate := media.video_tracks().item(1)?
	alternate.set_selected(true)
	assert !video.selected && alternate.selected && owner.is_screen_wake_lock_active()
	assert media.selected_video_track_sink()? == alternate
	assert media_wake_client_states(owner) == ['acquired', 'released', 'acquired', 'released', 'acquired']
	media.pause()
	media_wake_drain(media)
}

fn test_ready_state_and_ended_transitions_release_and_reacquire_without_duplicate_locks() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media, owner := media_wake_owner('video', true, true, .have_metadata)!
	media.play()
	assert !owner.is_screen_wake_lock_active()
	media.set_ready_state(.have_future_data)
	assert owner.is_screen_wake_lock_active()
	media.set_ready_state(.have_enough_data)
	assert media_wake_client_states(owner) == ['acquired']
	media.set_ready_state(.have_current_data)
	assert !owner.is_screen_wake_lock_active() && media.is_playing_audio()
	media.set_ready_state(.have_future_data)
	assert owner.is_screen_wake_lock_active()
	media.set_ended(true)
	media.set_ended(true)
	assert !owner.is_screen_wake_lock_active()
	media.set_ended(false)
	media.set_ended(false)
	assert owner.is_screen_wake_lock_active()
	assert media_wake_client_states(owner) == ['acquired', 'released', 'acquired', 'released', 'acquired']
	media.pause()
	media_wake_drain(media)
}

fn test_two_media_owners_share_the_page_lock_and_resource_failure_releases_the_last_owner() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	url := dom.URL{ value: 'https://shared-media-wake.example.test/' }
	mut document := parse_navigation_document('<video id="first"></video><video id="second"></video>', url, url.origin(), none)!
	owner := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	mut first := media_wake_load(document, 'first', true, true, .have_future_data)!
	mut second := media_wake_load(document, 'second', true, true, .have_future_data)!
	first.play()
	second.play()
	assert owner.is_screen_wake_lock_active() && media_wake_client_states(owner) == ['acquired']
	first.pause()
	assert owner.is_screen_wake_lock_active() && media_wake_client_states(owner) == ['acquired']
	second.handle_media_source_failure([], 'unsupported resource')
	assert !second.paused() && !owner.is_screen_wake_lock_active()
	assert media_wake_client_states(owner) == ['acquired', 'released']
	media_wake_drain(first)
	media_wake_drain(second)
	assert !owner.is_screen_wake_lock_active()
	second.set_source('')
	second.load()!
	assert !owner.is_screen_wake_lock_active() && media_wake_client_states(owner) == ['acquired', 'released']
}

fn test_held_wake_lock_releases_the_original_page_and_reacquires_the_adopting_page() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media, first_owner := media_wake_owner('video', true, true, .have_future_data)!
	mut first := media.document()?
	element := first.get_element_by_id('player')?
	mut node := element.as_node()
	node.remove(false)
	media_wake_drain(media)
	media.play()
	assert first_owner.is_screen_wake_lock_active()
	url := dom.URL{ value: 'https://adopted-media-wake.example.test/' }
	mut second := parse_navigation_document('', url, url.origin(), none)!
	second_owner := page.Page.create(1)!
	second.set_page(unsafe { &dom.Page(second_owner) })
	second.adopt_node(node)
	assert !first_owner.is_screen_wake_lock_active() && second_owner.is_screen_wake_lock_active()
	assert media_wake_client_states(first_owner) == ['acquired', 'released']
	assert media_wake_client_states(second_owner) == ['acquired']
	// Source clears and recreates a held handle even between documents on one Page.
	mut third := parse_navigation_document('', url, url.origin(), none)!
	third.set_page(unsafe { &dom.Page(second_owner) })
	third.adopt_node(node)
	assert second_owner.is_screen_wake_lock_active()
	assert media_wake_client_states(second_owner) == ['acquired', 'released', 'acquired']
	media.pause()
	assert !second_owner.is_screen_wake_lock_active()
	media_wake_drain(media)
}
