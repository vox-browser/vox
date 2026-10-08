module html

import dom

@[heap]
struct LoadedDataObservation {
mut:
	states []MediaReadyState
}

fn loaded_data_owner(load_resource bool) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://loaded-data.example.test/' }
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	if load_resource {
		media.set_source('/metadata.mp4')
		media.load()!
		loaded_data_drain(media)
		assert media.ready_state() == .have_metadata && media.network_state() == .idle
	}
	return media
}

fn loaded_data_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing loadeddata task') }
}

fn loaded_data_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 { loaded_data_take(media).execute() }
}

fn test_first_decoded_data_queues_once_per_load_and_observes_live_state_at_delivery() {
	for state in [MediaReadyState.have_current_data, .have_future_data, .have_enough_data] {
		mut media := loaded_data_owner(true)!
		observation := &LoadedDataObservation{}
		media.set_on_event('loadeddata', &dom.CallbackType{
			handle_event: fn [media, observation] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut seen := unsafe { &LoadedDataObservation(observation) }
				seen.states << media.ready_state()
				assert voidptr(event.target() or { panic('missing target') }) == voidptr(media.event_target())
				assert voidptr(current or { panic('missing current target') }) == voidptr(media.event_target())
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				return dom.js_undefined()
			}
		})
		media.set_ready_state(state)
		assert media.ready_state() == state && media.event_count('loadeddata') == 0
		pending := if int(state) >= int(MediaReadyState.have_future_data) { 2 } else { 1 }
		assert observation.states == [] && media.queued_media_task_ids_.len == pending
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_current_data)
		media.set_ready_state(.have_current_data)
		assert media.queued_media_task_ids_.len == pending
		mut loop := main_thread_event_loop()
		loop.perform_a_microtask_checkpoint()
		assert observation.states == []
		task := loaded_data_take(media)
		assert voidptr(task.document()?) == voidptr(media.document()?)
		assert task.source() == media.media_element_event_task_source()
		task.execute()
		assert observation.states == [MediaReadyState.have_current_data]
		assert media.event_count('loadeddata') == 1 && media.queued_media_task_ids_.len == pending - 1
		loaded_data_drain(media)
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_enough_data)
		assert media.event_count('loadeddata') == 1 && media.queued_media_task_ids_.len == 1
		loaded_data_drain(media)
	}
}

fn test_first_data_requires_a_load_nonempty_network_and_the_exact_metadata_transition() {
	mut fresh := loaded_data_owner(false)!
	fresh.network_state_ = .idle
	fresh.set_ready_state(.have_metadata)
	assert fresh.event_count('loadedmetadata') == 0 && fresh.queued_media_task_ids_.len == 1
	loaded_data_drain(fresh)
	assert fresh.event_count('loadedmetadata') == 1
	fresh.set_ready_state(.have_current_data)
	assert fresh.event_count('loadeddata') == 0 && fresh.queued_media_task_ids_.len == 0
	mut media := loaded_data_owner(false)!
	media.load()!
	media.begin_delaying_load_event()
	media.set_ready_state(.have_metadata)
	media.set_ready_state(.have_current_data)
	assert media.network_state() == .empty && media.event_count('loadeddata') == 0
	assert media.queued_media_task_ids_.len == 0 && media.document()?.anything_is_delaying_the_load_event()
	media.network_state_ = .idle
	media.set_ready_state(.have_nothing)
	media.set_ready_state(.have_current_data)
	assert media.queued_media_task_ids_.len == 0 && media.document()?.anything_is_delaying_the_load_event()
	media.set_ready_state(.have_metadata)
	media.set_ready_state(.have_current_data)
	assert media.queued_media_task_ids_.len == 1 && !media.document()?.anything_is_delaying_the_load_event()
	loaded_data_drain(media)
	assert media.event_count('loadeddata') == 1
}

fn test_each_explicit_or_automatic_load_rearms_and_cancels_only_its_old_data_task() {
	mut first := loaded_data_owner(true)!
	mut second := loaded_data_owner(true)!
	first.set_ready_state(.have_current_data)
	second.set_ready_state(.have_current_data)
	assert first.queued_media_task_ids_.len == 1 && second.queued_media_task_ids_.len == 1
	first.load_element()!
	assert first.event_count('loadeddata') == 0 && second.queued_media_task_ids_.len == 1
	loaded_data_drain(first)
	assert first.event_count('loadeddata') == 0
	loaded_data_take(second).execute()
	assert second.event_count('loadeddata') == 1
	first.set_ready_state(.have_current_data)
	assert first.queued_media_task_ids_.len == 1
	first.load()!
	loaded_data_drain(first)
	assert first.event_count('loadeddata') == 0
	first.set_ready_state(.have_current_data)
	loaded_data_drain(first)
	assert first.event_count('loadeddata') == 1 && second.event_count('loadeddata') == 1
}

fn test_metadata_to_data_releases_only_the_current_documents_media_delay_even_after_first_delivery() {
	mut media := loaded_data_owner(true)!
	mut old_document := media.document()?
	mut independent := dom.DocumentLoadEventDelayer.new(mut old_document)
	media.begin_delaying_load_event()
	url := dom.URL{ value: 'https://adopted-loaded-data.example.test/' }
	mut new_document := parse_navigation_document('<body></body>', url, url.origin(), none)!
	element := old_document.get_element_by_id('player')?
	new_document.adopt_node(element.as_node())
	assert old_document.anything_is_delaying_the_load_event() && new_document.anything_is_delaying_the_load_event()
	media.set_ready_state(.have_current_data)
	assert media.event_count('loadeddata') == 0
	assert old_document.anything_is_delaying_the_load_event() && !new_document.anything_is_delaying_the_load_event()
	task := loaded_data_take(media)
	assert voidptr(task.document()?) == voidptr(new_document)
	task.execute()
	assert media.event_count('loadeddata') == 1
	media.begin_delaying_load_event()
	media.set_ready_state(.have_metadata)
	media.set_ready_state(.have_current_data)
	assert !new_document.anything_is_delaying_the_load_event()
	assert media.event_count('loadeddata') == 1 && media.queued_media_task_ids_.len == 0
	assert old_document.anything_is_delaying_the_load_event()
	independent.finish()
	assert !old_document.anything_is_delaying_the_load_event()
}

fn test_inactive_data_delivery_is_discarded_without_rearming_the_first_data_flag() {
	mut media := loaded_data_owner(true)!
	media.set_ready_state(.have_current_data)
	task := loaded_data_take(media)
	document := media.document()?
	mut navigable := document.navigable()?
	navigable.set_active_document(none)
	task.execute()
	assert media.event_count('loadeddata') == 0 && media.queued_media_task_ids_.len == 0
	navigable.set_active_document(document)
	media.set_ready_state(.have_metadata)
	media.set_ready_state(.have_current_data)
	assert media.queued_media_task_ids_.len == 0
	media.load()!
	loaded_data_drain(media)
	media.set_ready_state(.have_current_data)
	loaded_data_drain(media)
	assert media.event_count('loadeddata') == 1
}
