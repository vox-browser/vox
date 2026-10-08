module html

import dom

@[heap]
struct MetadataTaskObservation {
mut:
	events []string
	states []MediaReadyState
}

fn metadata_task_owner() !&HTMLMediaElement {
	url := dom.URL{
		value: 'https://metadata-task.example.test/'
	}
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	return html_media_element_for_dom_element(element) or { return error('missing media owner') }
}

fn metadata_task_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing metadata task') }
}

fn metadata_task_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 {
		metadata_task_take(media).execute()
	}
}

fn test_metadata_notification_uses_the_exact_readiness_and_network_gates() {
	for network in [MediaNetworkState.empty, .idle, .loading, .no_source] {
		for old in [MediaReadyState.have_nothing, .have_metadata, .have_current_data,
			.have_future_data, .have_enough_data] {
			mut media := metadata_task_owner()!
			media.network_state_ = network
			media.ready_state_ = old
			media.set_ready_state(.have_metadata)
			assert media.ready_state() == .have_metadata && media.event_count('loadedmetadata') == 0
			expected := if network != .empty && old == .have_nothing { 1 } else { 0 }
			assert media.queued_media_task_ids_.len == expected
			if expected == 1 {
				task := metadata_task_take(media)
				assert voidptr(task.document()?) == voidptr(media.document()?)
				assert task.source() == media.media_element_event_task_source()
				task.execute()
				assert media.event_count('loadedmetadata') == 1
			}
		}
	}
	for next in [MediaReadyState.have_current_data, .have_future_data, .have_enough_data] {
		mut media := metadata_task_owner()!
		media.network_state_ = .idle
		media.set_ready_state(next)
		metadata_task_drain(media)
		assert media.event_count('loadedmetadata') == 0
	}
}

fn test_fetch_metadata_and_first_data_wait_in_order_and_observe_live_owner_state() {
	mut media := metadata_task_owner()!
	observation := &MetadataTaskObservation{}
	for name in ['durationchange', 'loadedmetadata', 'loadeddata'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, observation] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut seen := unsafe { &MetadataTaskObservation(observation) }
				seen.events << name
				seen.states << media.ready_state()
				assert media.duration() == 20
				assert voidptr(event.target() or { panic('missing target') }) == voidptr(media.event_target())
				assert voidptr(current or { panic('missing current target') }) == voidptr(media.event_target())
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				return dom.js_undefined()
			}
		})
	}
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/movie.mp4')
	media.load()!
	assert media.ready_state() == .have_metadata && media.network_state() == .idle
	assert observation.events == [] && media.event_count('loadedmetadata') == 0
	media.set_ready_state(.have_current_data)
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert observation.events == []
	metadata_task_drain(media)
	assert observation.events == ['durationchange', 'loadedmetadata', 'loadeddata']
	assert observation.states == [MediaReadyState.have_current_data, .have_current_data,
		.have_current_data]
	assert media.event_count('loadedmetadata') == 1 && media.event_count('loadeddata') == 1
}

fn test_metadata_repetition_follows_readiness_and_reload_cancels_only_its_owner() {
	mut first := metadata_task_owner()!
	mut second := metadata_task_owner()!
	for owner in [first, second] {
		mut media := unsafe { &HTMLMediaElement(owner) }
		media.network_state_ = .idle
		media.set_ready_state(.have_metadata)
	}
	assert first.queued_media_task_ids_.len == 1 && second.queued_media_task_ids_.len == 1
	first.set_ready_state(.have_metadata)
	assert first.queued_media_task_ids_.len == 1
	first.load()!
	metadata_task_drain(first)
	assert first.event_count('loadedmetadata') == 0 && second.queued_media_task_ids_.len == 1
	metadata_task_drain(second)
	assert second.event_count('loadedmetadata') == 1
	second.set_ready_state(.have_nothing)
	second.set_ready_state(.have_metadata)
	metadata_task_drain(second)
	assert second.event_count('loadedmetadata') == 2
}

fn test_metadata_tasks_use_the_adopted_document_and_skip_inactive_delivery() {
	mut media := metadata_task_owner()!
	old_document := media.document()?
	url := dom.URL{
		value: 'https://adopted-metadata.example.test/'
	}
	mut new_document := parse_navigation_document('<body></body>', url, url.origin(), none)!
	new_document.adopt_node(old_document.get_element_by_id('player')?.as_node())
	media.network_state_ = .idle
	media.set_ready_state(.have_metadata)
	task := metadata_task_take(media)
	assert voidptr(task.document()?) == voidptr(new_document)
	mut navigable := new_document.navigable()?
	navigable.set_active_document(none)
	task.execute()
	assert media.event_count('loadedmetadata') == 0 && media.queued_media_task_ids_.len == 0
	navigable.set_active_document(new_document)
	media.set_ready_state(.have_metadata)
	assert media.queued_media_task_ids_.len == 0
	media.set_ready_state(.have_nothing)
	media.set_ready_state(.have_metadata)
	metadata_task_drain(media)
	assert media.event_count('loadedmetadata') == 1
}
