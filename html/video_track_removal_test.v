module html

import dom

@[heap]
struct VideoTrackRemovalObservation {
mut:
	queued_changes int
	backend_clears int
	changes        int
}

fn vtr_media_owner() !&HTMLMediaElement {
	url := dom.URL{value: 'https://video-removal.example.test/'}
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing video element') }
	return html_media_element_for_dom_element(element) or { return error('Missing media owner') }
}

fn vtr_unexpected_change() {
	panic('Removing an unselected or detached video track must not queue change')
}

fn vtr_unexpected_backend(_ ?&VideoTrack) {
	panic('Removing an unselected video track must not update playback selection')
}

fn test_selected_video_removal_queues_one_owned_change_before_detaching_the_track() {
	mut media := vtr_media_owner()!
	mut list := media.video_tracks()
	target := &list.EventTarget
	state := &VideoTrackRemovalObservation{}
	mut first := VideoTrack.create(MediaTrackMetadata{identifier: 11, name: 'Alternate'},
		vtr_unexpected_change, vtr_unexpected_backend)
	// The native change-task hook is injected here; the automatic media track
	// factory still supplies its existing no-op queue callback.
	mut selected := VideoTrack.create(MediaTrackMetadata{identifier: 22, name: 'Main'},
		fn [media, list, target, state] () {
			mut result := unsafe { &VideoTrackRemovalObservation(state) }
			result.queued_changes++
			assert list.length() == 2 && list.selected_index() == 1
			track := list.item(1) or { panic('Selection disappeared before queueing') }
			assert voidptr(track.video_track_list or { panic('Detached before queueing') }) == voidptr(list)
			media.queue_a_media_element_task(fn [target] () {
				target.dispatch_event(dom.Event.new('change'))
			})
		}, fn [media, list] (track ?&VideoTrack) {
			assert track == none && list.length() == 2 && list.selected_index() == -1
			removed := list.item(1) or { panic('Track disappeared before backend clear') }
			assert !removed.selected
			assert voidptr(removed.video_track_list or { panic('Detached before backend clear') }) == voidptr(list)
			mut owner := unsafe { &HTMLMediaElement(media) }
			owner.set_selected_video_track(track)
		})
	first.base.set_media_element(media)
	selected.base.set_media_element(media)
	list.add_track(first)
	list.add_track(selected)
	selected.selected = true
	media.selected_video_track_ = selected
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_video_track: fn [media, state] (track ?&VideoTrack) {
			assert track == none && media.selected_video_track_ == none
			mut result := unsafe { &VideoTrackRemovalObservation(state) }
			result.backend_clears++
		}
	})
	target.add_event_listener_without_options('change', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [media, list, first, selected, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &VideoTrackRemovalObservation(state) }
			result.changes++
			assert event.type_name() == 'change'
			assert voidptr(event.target() or { panic('Missing change target') }) == voidptr(target)
			assert voidptr(current or { panic('Missing current target') }) == voidptr(target)
			assert list.length() == 0 && list.selected_index() == -1
			assert first.video_track_list == none && selected.video_track_list == none
			assert !first.selected && !selected.selected && media.selected_video_track_ == none
			assert media.queued_media_task_ids_.len == 0
			assert result.queued_changes == 1 && result.backend_clears == 1
			return dom.js_undefined()
		}
	}))
	assert list.selected_index() == 1 && media.queued_media_task_ids_.len == 0
	list.remove_all_tracks()
	assert state.queued_changes == 1 && state.backend_clears == 1 && state.changes == 0
	assert list.length() == 0 && list.selected_index() == -1 && list.item(0) == none
	assert first.video_track_list == none && selected.video_track_list == none
	assert !first.selected && !selected.selected && media.selected_video_track_ == none
	assert media.queued_media_task_ids_.len == 1
	list.remove_all_tracks()
	assert state.queued_changes == 1 && state.backend_clears == 1 && media.queued_media_task_ids_.len == 1
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.changes == 0
	mut queue := loop.task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('Missing owned track change task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('Missing task document') }) == voidptr(media.document() or { panic('Missing owner document') })
	task.execute()
	assert state.changes == 1 && state.queued_changes == 1 && state.backend_clears == 1
	assert media.queued_media_task_ids_.len == 0 && voidptr(media.video_tracks()) == voidptr(list)
	for track in [first, selected] {
		assert voidptr(track.base.media_element() or { panic('Lost retained media owner') }) == voidptr(media)
	}
	assert first.base.id == '11' && selected.base.id == '22'
	assert media.paused() && media.network_state() == .empty
}

fn test_unselected_video_removal_and_repeated_empty_removal_do_not_queue_or_clear_playback() {
	media := vtr_media_owner()!
	mut list := media.video_tracks()
	list.set_onchange(&dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			panic('Removing only unselected tracks must not dispatch change')
		}
	})
	list.remove_all_tracks()
	assert list.length() == 0 && list.selected_index() == -1 && media.queued_media_task_ids_.len == 0
	mut retained := []&VideoTrack{}
	for id in [31, 32] {
		mut track := VideoTrack.create(MediaTrackMetadata{identifier: id, name: 'Unselected ${id}'},
			vtr_unexpected_change, vtr_unexpected_backend)
		track.base.set_media_element(media)
		list.add_track(track)
		retained << track
		assert !track.selected
		assert voidptr(track.video_track_list or { panic('Missing initial list') }) == voidptr(list)
	}
	assert list.length() == 2 && list.selected_index() == -1
	list.remove_all_tracks()
	list.remove_all_tracks()
	assert list.length() == 0 && list.tracks().len == 0 && list.selected_index() == -1
	assert list.item(0) == none && list.get_track_by_id('31') == none && list.get_track_by_id('32') == none
	assert media.queued_media_task_ids_.len == 0 && media.selected_video_track_ == none
	assert voidptr(media.video_tracks()) == voidptr(list)
	for index, track in retained {
		assert track.video_track_list == none && !track.selected
		assert track.base.id == (31 + index).str() && track.base.label == 'Unselected ${31 + index}'
		assert voidptr(track.base.media_element() or { panic('Lost retained media owner') }) == voidptr(media)
	}
	assert media.paused() && media.network_state() == .empty
}
