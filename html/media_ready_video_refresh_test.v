module html

import dom
import page

struct ReadyVideoRefreshRow {
	state MediaReadyState
	tasks int
	step_one int
	load_delayed bool
	first_data bool
	wake_lock bool
}

@[heap]
struct ReadyVideoRefreshProbe {
mut:
	rows []ReadyVideoRefreshRow
}

fn ready_video_refresh_drain(media &HTMLMediaElement) {
	for _ in 0 .. 30 {
		if media.queued_media_task_ids_.len == 0 { return }
		mut queue := main_thread_event_loop().task_queue()
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing ready-video media task') }
		assert task.source() == media.media_element_event_task_source()
		assert voidptr(task.document() or { panic('Missing ready-video task document') }) == voidptr(media.document() or { panic('Missing ready-video document') })
		task.execute()
	}
	panic('Ready-video task queue did not drain')
}

fn ready_video_refresh_owner(loaded bool) !(&dom.Document, &page.Page, &HTMLMediaElement, &HTMLVideoElementModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://ready-video-refresh.example/player/'}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	parse_html_from_a_string(document, '<!doctype html><video id="player" preload="none"></video>')
	navigable := document.navigable() or { return error('Missing ready-video navigable') }
	assert voidptr(navigable.active_document() or { return error('Missing active ready-video document') }) == voidptr(document)
	assert document.get_window() != none && document.get_browsing_context() != none
	element := document.get_element_by_id('player') or { return error('Missing ready-video owner') }
	video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut media := video.media
	if loaded {
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
			return MediaResourceResponse{mime_type: 'video/mp4', duration: 100,
				audio_tracks: [MediaTrackMetadata{identifier: 1, name: 'Audio'}],
				video_tracks: [MediaTrackMetadata{identifier: 2, name: 'Video', pixel_width: 320, pixel_height: 180}]}
		})
		media.set_source('/movie.mp4')
		media.load()!
		ready_video_refresh_drain(media)
		assert media.ready_state() == .have_metadata && media.network_state() == .idle
		assert media.audio_tracks().has_enabled_track() && media.video_tracks().selected_index() == 0
	}
	return document, owner, media, video
}

fn ready_video_refresh_observe(mut video HTMLVideoElementModel, owner &page.Page) &ReadyVideoRefreshProbe {
	probe := &ReadyVideoRefreshProbe{}
	video.set_paint_facts_update_hook(fn [probe, owner] (element &dom.HTMLVideoElement) {
		model := html_video_element_model_for_dom_element(element)
		media := model.media
		mut seen := unsafe { &ReadyVideoRefreshProbe(probe) }
		seen.rows << ReadyVideoRefreshRow{state: media.ready_state(), tasks: media.queued_media_task_ids_.len,
			step_one: main_thread_event_loop().reached_step_1_tasks.len,
			load_delayed: media.delaying_load_event_ != none, first_data: media.first_data_load_event_since_load_start_,
			wake_lock: owner.is_screen_wake_lock_active()}
	})
	return probe
}

fn test_empty_network_video_refresh_follows_step_one_and_actual_page_wake_lock_updates() {
	mut document, owner, mut media, mut video := ready_video_refresh_owner(true)!
	defer { video.set_paint_facts_update_hook(none); media.finalize(); document.finalize() }
	media.network_state_ = .empty
	media.set_show_poster(false)
	media.set_paused(false)
	assert !owner.is_screen_wake_lock_active()
	probe := ready_video_refresh_observe(mut video, owner)
	before := main_thread_event_loop().reached_step_1_tasks.len
	media.set_ready_state(.have_future_data)
	assert probe.rows.len == 1 && probe.rows[0].wake_lock
	assert probe.rows[0].step_one == before + 1 && probe.rows[0].tasks == 0
	assert owner.is_screen_wake_lock_active() && media.ready_state() == .have_future_data
	media.set_ready_state(.have_current_data)
	assert probe.rows.len == 2 && !probe.rows[1].wake_lock
	assert probe.rows[1].step_one == before + 2 && probe.rows[1].tasks == 0
	assert !owner.is_screen_wake_lock_active() && media.event_count('waiting') == 0
	media.set_ready_state(.have_current_data)
	assert probe.rows.len == 2 && main_thread_event_loop().reached_step_1_tasks.len == before + 2
	assert owner.client().events.filter(it.name == 'change-screen-wake-lock-state').map(it.text) == ['acquired', 'released']
}

fn test_first_data_video_refresh_follows_load_blocker_release_and_all_queued_readiness_notifications() {
	for index, state in [MediaReadyState.have_current_data, .have_future_data, .have_enough_data] {
		mut document, owner, mut media, mut video := ready_video_refresh_owner(true)!
		defer { video.set_paint_facts_update_hook(none); media.finish_delaying_load_event(); media.remove_queued_media_element_tasks(); media.finalize(); document.finalize() }
		media.begin_delaying_load_event()
		assert document.anything_is_delaying_the_load_event() && media.first_data_load_event_since_load_start_
		probe := ready_video_refresh_observe(mut video, owner)
		before := main_thread_event_loop().reached_step_1_tasks.len
		media.set_ready_state(state)
		assert probe.rows.len == 1 && probe.rows[0].state == state
		assert !probe.rows[0].load_delayed && !probe.rows[0].first_data && !probe.rows[0].wake_lock
		assert probe.rows[0].step_one == before + 1 && probe.rows[0].tasks == index + 1
		assert !document.anything_is_delaying_the_load_event() && media.event_count('loadeddata') == 0
		ready_video_refresh_drain(media)
		assert media.event_count('loadeddata') == 1
		assert media.event_count('canplay') == if index > 0 { 1 } else { 0 }
		assert media.event_count('canplaythrough') == if index > 1 { 1 } else { 0 }
		assert probe.rows.len == 1 && media.queued_media_task_ids_.len == 0
		assert (video.natural_element_size() or { panic('Missing retained video size') }) == VideoDimensions{320, 180}
	}
}

fn test_metadata_early_return_refreshes_video_after_queueing_and_same_state_is_a_noop() {
	mut document, owner, mut media, mut video := ready_video_refresh_owner(false)!
	defer { video.set_paint_facts_update_hook(none); media.remove_queued_media_element_tasks(); media.finalize(); document.finalize() }
	media.network_state_ = .idle
	probe := ready_video_refresh_observe(mut video, owner)
	before := main_thread_event_loop().reached_step_1_tasks.len
	media.set_ready_state(.have_metadata)
	assert probe.rows.len == 1 && probe.rows[0].state == .have_metadata
	assert probe.rows[0].tasks == 1 && probe.rows[0].step_one == before + 1
	assert media.event_count('loadedmetadata') == 0 && video.natural_element_size() == none
	media.set_ready_state(.have_metadata)
	assert probe.rows.len == 1 && media.queued_media_task_ids_.len == 1
	ready_video_refresh_drain(media)
	assert media.event_count('loadedmetadata') == 1 && probe.rows.len == 1
}
