module mediasourceextensions

import dom
import html
import page

struct BufferTaskOwner {
	source   &MediaSource
	media    &html.HTMLMediaElement
	document &dom.Document
}

fn drain_buffer_owner_tasks() {
	mut event_loop := html.main_thread_event_loop()
	queue := event_loop.task_queue()
	event_loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
}

fn create_buffer_task_owner() !BufferTaskOwner {
	address := dom.URL{
		value: 'https://buffer-task-owner.example.test/page'
	}
	owner := page.Page.create(1)!
	document := html.create_navigation_document_for_page(address, address.origin(), none,
		unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	source := MediaSource.create_for_constructor(settings.global_object())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html.html_media_element_for_dom_element(element) or {
		return error('missing actual media owner')
	}
	media.set_src_object(source.as_media_provider())!
	drain_buffer_owner_tasks()
	assigned := source.media_element_assigned_to() or {
		return error('source was not attached to the actual media owner')
	}
	assert assigned == media
	assert source.relevant_global_impl() == settings.global_object()
	return BufferTaskOwner{
		source:   source
		media:    media
		document: document
	}
}

fn close_buffer_task_owner(owner BufferTaskOwner) {
	mut media := owner.media
	media.set_src_object(none) or {}
	drain_buffer_owner_tasks()
	mut document := owner.document
	document.finalize()
}

@[heap]
struct BufferTaskEvents {
mut:
	names      []string
	identities []bool
}

fn observe_buffer_task_events(buffer &SourceBuffer, abort_on_start bool) &BufferTaskEvents {
	seen := &BufferTaskEvents{}
	expected := voidptr(&buffer.EventTarget)
	callback := &dom.CallbackType{
		handle_event: fn [seen, expected, buffer, abort_on_start] (event &dom.Event, receiver ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &BufferTaskEvents(seen) }
			observation.names << event.type_name()
			target := event.target() or { return dom.js_undefined() }
			current := event.current_target() or { return dom.js_undefined() }
			callback_receiver := receiver or { return dom.js_undefined() }
			observation.identities << (voidptr(target) == expected && voidptr(current) == expected
				&& voidptr(callback_receiver) == expected)
			if abort_on_start && event.type_name() == 'updatestart' {
				mut actual := unsafe { &SourceBuffer(buffer) }
				actual.abort() or { panic(err) }
			}
			return dom.js_undefined()
		}
	}
	for name in ['updatestart', 'update', 'updateend', 'abort', 'error'] {
		buffer.set_event_handler_attribute(name, callback)
	}
	return seen
}

fn test_buffer_append_events_keep_the_actual_source_buffer_identity() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_task_events(buffer, false)
	buffer.append_buffer([u8(0x1a), 0x45])!
	assert seen.names == []
	drain_buffer_owner_tasks()
	assert seen.names == ['updatestart', 'update', 'updateend']
	assert seen.identities == [true, true, true]
	assert !buffer.updating()
}

fn test_abort_before_append_task_cancels_the_original_generation() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_task_events(buffer, false)
	buffer.append_buffer([u8(0x1a), 0x45])!
	buffer.abort()!
	drain_buffer_owner_tasks()
	assert seen.names == ['updatestart', 'abort', 'updateend']
	assert seen.identities == [true, true, true]
	assert buffer.input_buffer_length() == 0
	assert !buffer.updating()
}

fn test_abort_from_updatestart_cancels_the_original_append_task() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_task_events(buffer, true)
	buffer.append_buffer([u8(0x1a), 0x45])!
	drain_buffer_owner_tasks()
	assert seen.names == ['updatestart', 'abort', 'updateend']
	assert seen.identities == [true, true, true]
	assert buffer.input_buffer_length() == 0
	assert !buffer.updating()
}

fn test_a_new_append_after_abort_is_not_consumed_by_the_stale_task() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_task_events(buffer, false)
	buffer.append_buffer([u8(0x1a), 0x45])!
	buffer.abort()!
	buffer.append_buffer([u8(0x1a), 0x45])!
	drain_buffer_owner_tasks()
	assert seen.names == ['updatestart', 'abort', 'updateend', 'updatestart', 'update', 'updateend']
	assert seen.identities == [true, true, true, true, true, true]
	assert buffer.input_buffer_length() == 2
	assert !buffer.updating()
}

fn test_range_removal_completes_on_the_original_buffer_and_track() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	source.set_duration(10)!
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	mut track := TrackBuffer.create(WebMTrackInfo{ number: 1, type_: .text })
	buffer.processor_.track_buffers_[1] = track
	mut demuxer := track.demuxer
	for timestamp in [f64(0), 2] {
		demuxer.add_coded_frame(DemuxedCodedFrame{
			track_number: 1
			is_keyframe:  true
			data:         [u8(1)]
			timestamp:    timestamp
			duration:     1
		})
	}
	seen := observe_buffer_task_events(buffer, false)
	buffer.remove(1, 3)!
	assert buffer.range_removal_running_ && buffer.updating()
	drain_buffer_owner_tasks()
	assert demuxer.coded_frames().map(it.timestamp) == [f64(0)]
	assert !buffer.range_removal_running_ && !buffer.updating()
	assert seen.names == ['updatestart', 'update', 'updateend']
	assert seen.identities == [true, true, true]
	buffer.abort()!
}

fn test_range_removal_refreshes_actual_media_ranges_before_updateend() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	source.set_duration(10)!
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	mut track := TrackBuffer.create(WebMTrackInfo{ number: 1, type_: .video })
	buffer.processor_.track_buffers_[1] = track
	mut demuxer := track.demuxer
	for timestamp in [f64(0), 5] {
		demuxer.add_coded_frame(DemuxedCodedFrame{
			track_number: 1
			is_keyframe:  true
			data:         [u8(1)]
			timestamp:    timestamp
			duration:     1
		})
	}
	buffer.update_ready_state_and_duration_after_coded_frame_processing()
	saved := owner.media.buffered()
	assert saved.length() == 2
	mut seen := &BufferTaskEvents{}
	buffer.set_event_handler_attribute('updateend', &dom.CallbackType{
		handle_event: fn [seen, owner] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &BufferTaskEvents(seen) }
			ranges := owner.media.buffered()
			start := ranges.start(0) or { -1 }
			end := ranges.end(0) or { -1 }
			observation.identities << (ranges.length() == 1 && start == 0 && end == 1)
			return dom.js_undefined()
		}
	})
	buffer.remove(1, 6)!
	assert owner.media.buffered().length() == 2
	drain_buffer_owner_tasks()
	assert seen.identities == [true]
	assert owner.media.buffered().length() == 1
	assert saved.length() == 2
	assert saved.end(1)! == 6
}

fn test_append_error_events_keep_the_original_buffer() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_task_events(buffer, false)
	// A media Cluster before any initialization segment must fail the append.
	buffer.append_buffer([u8(0x1f), 0x43, 0xb6, 0x75, 0x80])!
	drain_buffer_owner_tasks()
	assert seen.names == ['updatestart', 'error', 'updateend']
	assert seen.identities == [true, true, true]
	assert source.ready_state() == .ended
}

fn test_actual_media_detachment_keeps_abort_event_target_identity() {
	owner := create_buffer_task_owner()!
	defer { close_buffer_task_owner(owner) }
	mut source := owner.source
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_task_events(buffer, false)
	buffer.append_buffer([u8(0x1a), 0x45])!
	mut media := owner.media
	media.set_src_object(none)!
	drain_buffer_owner_tasks()
	assert seen.names == ['updatestart', 'abort', 'updateend']
	assert seen.identities == [true, true, true]
	assert source.ready_state() == .closed
	assert source.source_buffers().length() == 0
}
