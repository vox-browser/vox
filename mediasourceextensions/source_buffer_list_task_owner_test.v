module mediasourceextensions

import dom
import html
import page

@[heap]
struct BufferListTaskEvents {
mut:
	identities []bool
	lengths    []u32
}

fn drain_buffer_list_owner_tasks() {
	mut event_loop := html.main_thread_event_loop()
	queue := event_loop.task_queue()
	event_loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
}

fn observe_buffer_list_tasks(list &SourceBufferList) &BufferListTaskEvents {
	seen := &BufferListTaskEvents{}
	expected := voidptr(&list.EventTarget)
	list.set_onaddsourcebuffer(&dom.CallbackType{
		handle_event: fn [seen, list, expected] (event &dom.Event, receiver ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &BufferListTaskEvents(seen) }
			target := event.target() or { return dom.js_undefined() }
			current := event.current_target() or { return dom.js_undefined() }
			callback_receiver := receiver or { return dom.js_undefined() }
			observation.identities << (voidptr(target) == expected && voidptr(current) == expected
				&& voidptr(callback_receiver) == expected)
			observation.lengths << list.length()
			return dom.js_undefined()
		}
	})
	return seen
}

fn test_add_source_buffer_queues_the_original_list_event() {
	mut source := MediaSource.create()
	source.set_ready_state_to_open_and_fire_sourceopen_event()
	drain_buffer_list_owner_tasks()
	list := source.source_buffers()
	seen := observe_buffer_list_tasks(list)
	buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	assert list.item(0)? == buffer
	assert seen.identities == []
	drain_buffer_list_owner_tasks()
	assert seen.identities == [true]
	assert seen.lengths == [u32(1)]
}

fn test_list_event_reads_the_live_list_at_task_execution() {
	mut source := MediaSource.create()
	source.set_ready_state_to_open_and_fire_sourceopen_event()
	drain_buffer_list_owner_tasks()
	mut list := source.source_buffers()
	seen := observe_buffer_list_tasks(list)
	_ := source.add_source_buffer('video/webm; codecs="vp9"')!
	_ := source.add_source_buffer('audio/webm; codecs="opus"')!
	list.remove_all_buffers()
	drain_buffer_list_owner_tasks()
	assert seen.identities == [true, true]
	assert seen.lengths == [u32(0), 0]
}

fn test_a_handler_installed_after_append_observes_the_queued_event() {
	mut source := MediaSource.create()
	source.set_ready_state_to_open_and_fire_sourceopen_event()
	drain_buffer_list_owner_tasks()
	_ := source.add_source_buffer('video/webm; codecs="vp9"')!
	seen := observe_buffer_list_tasks(source.source_buffers())
	drain_buffer_list_owner_tasks()
	assert seen.identities == [true]
	assert seen.lengths == [u32(1)]
}

fn test_first_active_track_preserves_both_pinned_source_notifications() {
	address := dom.URL{
		value: 'https://active-buffer-list-owner.example.test/page'
	}
	owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(address, address.origin(), none,
		unsafe { &dom.Page(owner) })!
	defer { document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut source := MediaSource.create_for_constructor(settings.global_object())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html.html_media_element_for_dom_element(element) or {
		panic('missing actual active-list media owner')
	}
	defer {
		media.set_src_object(none) or {}
		drain_buffer_list_owner_tasks()
	}
	media.set_src_object(source.as_media_provider())!
	drain_buffer_list_owner_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	drain_buffer_list_owner_tasks()
	track := WebMTrackInfo{
		number:   1
		type_:    .video
		codec_id: 'V_VP9'
	}
	buffer.processor_.track_buffers_[1] = TrackBuffer.create(track)
	list := source.active_source_buffers()
	seen := observe_buffer_list_tasks(list)
	buffer.on_first_initialization_segment_processed(4, [track])
	assert list.length() == 1 && list.item(0)? == buffer
	assert list.relevant_global_impl()? == settings.global_object()
	drain_buffer_list_owner_tasks()
	assert seen.identities == [true, true]
	assert seen.lengths == [u32(1), 1]
}
