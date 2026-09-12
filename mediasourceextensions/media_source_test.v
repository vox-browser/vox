module mediasourceextensions

import dom
import fileapi
import html

@[heap]
struct EventObservation {
mut:
	count      int
	interface_ dom.EventInterface
}

fn observer_callback(observation &EventObservation) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			_ = current_target
			mut seen := unsafe { &EventObservation(observation) }
			seen.count++
			seen.interface_ = event.interface_
			return dom.js_undefined()
		}
	}
}

fn test_event_name_and_enum_registries() {
	assert event_names.len == 13
	assert event_names[0] == 'abort'
	assert event_names#[-1] == 'updatestart'
	assert ReadyState.ended.webidl_name() == 'ended'
	assert ready_state_from_webidl('open')! == .open
	assert EndOfStreamError.decode.webidl_name() == 'decode'
	assert end_of_stream_error_from_webidl('network')! == .network
	assert AppendMode.sequence.webidl_name() == 'sequence'
	assert append_mode_from_webidl('segments')! == .segments
}

fn test_media_source_type_support_and_worker_flag() {
	assert !MediaSource.can_construct_in_dedicated_worker()
	assert !MediaSource.is_type_supported('')
	assert !MediaSource.is_type_supported('not a mime')
	assert !MediaSource.is_type_supported('video/mp4; codecs="avc1"')
	assert !MediaSource.is_type_supported('application/future-media')
	assert MediaSource.is_type_supported('video/webm; codecs="vp9,opus"')
	assert MediaSource.is_type_supported('video/webm; codecs="vp09.00.10.08"')
	assert MediaSource.is_type_supported('audio/webm; codecs="opus"')
	assert !MediaSource.is_type_supported('video/webm')
	assert !MediaSource.is_type_supported('video/webm; codecs="vp8"')
	assert !MediaSource.is_type_supported('audio/webm; codecs="vorbis"')
}

fn test_media_source_handlers_participate_in_dispatch() {
	source := MediaSource.create()
	observation := &EventObservation{}
	handler := observer_callback(observation)
	source.set_onsourceopen(handler)
	assert source.onsourceopen() or { panic('missing handler') } == handler
	source.dispatch_event(dom.Event.construct_impl('sourceopen', dom.EventInit{})!)
	assert observation.count == 1
	source.set_onsourceopen(none)
	assert source.onsourceopen() == none
}

fn test_media_source_can_be_assigned_to_media_element_src_object() {
	mut source := MediaSource.create()
	observation := &EventObservation{}
	source.set_onsourceopen(observer_callback(observation))
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_source('/remote.webm')
	media.set_src_object(source.as_media_provider())!

	provider := media.src_object() or { panic('missing assigned media provider') }
	assert provider.kind == .media_source
	assert provider.media_source_handle == voidptr(source)
	assert media.current_src() == ''
	assert media.network_state() == .loading
	assert source.ready_state() == .open
	assert source.has_ever_been_attached()
	assert source.media_element_assigned_to()? == media
	assert observation.count == 1

	mut second_media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	second_media.set_src_object(source.as_media_provider())!
	assert second_media.network_state() == .no_source
	assert second_media.error()?.message == 'MediaSource is not closed'
}

fn test_media_source_blob_url_loads_as_a_local_resource() {
	mut document := dom.Document.create(dom.URL{'https://example.test/page'})
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	video_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html.html_media_element_for_dom_element(video_element) or {
		panic('missing media element model')
	}
	mut source := MediaSource.create()
	origin := document.origin()
	blob_url := fileapi.add_entry_to_blob_url_store(source.blob_url_object('media-source-url'), fileapi.BlobURLEnvironment{
		id: document.url_string()
		origin: origin.serialize()
		storage_key: origin.serialize_for_ipc()
	})!
	defer {
		fileapi.remove_entry_from_blob_url_store(blob_url)
	}

	media.set_source(blob_url)
	media.load()!
	assert media.current_src() == blob_url
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media
}

fn test_media_source_add_source_buffer_and_indexed_source_buffer_list() {
	mut source := MediaSource.create()
	source.add_source_buffer('') or {
		assert err.msg() == 'TypeError: SourceBuffer type must not be empty'
	}
	source.add_source_buffer('video/mp4; codecs="avc1"') or {
		assert err.msg() == 'NotSupportedError: Unsupported MIME type'
	}
	source.add_source_buffer('video/webm; codecs="vp9"') or {
		assert err.msg() == 'InvalidStateError: MediaSource is not open'
	}

	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	observation := &EventObservation{}
	source.source_buffers().set_onaddsourcebuffer(observer_callback(observation))
	buffer := source.add_source_buffer('video/webm; codecs="vp9,opus"')!
	assert source.source_buffers() == source.source_buffers()
	assert source.source_buffers().length() == 1
	assert source.source_buffers().item(0)? == buffer
	assert source.source_buffers().item(1) == none
	assert observation.count == 1
	assert observation.interface_ == .event
}

fn test_source_buffer_append_error_and_end_of_stream_algorithms() {
	mut unattached := SourceBuffer.create_internal()
	unattached.append_buffer('data'.bytes()) or {
		assert err.msg() == 'InvalidStateError: Unsupported in workers'
	}

	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	update_start := &EventObservation{}
	append_error := &EventObservation{}
	update_end := &EventObservation{}
	source_ended := &EventObservation{}
	buffer.set_onupdatestart(observer_callback(update_start))
	buffer.set_onerror(observer_callback(append_error))
	buffer.set_onupdateend(observer_callback(update_end))
	source.set_onsourceended(observer_callback(source_ended))

	buffer.append_buffer('not yet demuxed'.bytes())!
	assert !buffer.updating()
	assert buffer.input_buffer_length() == 0
	assert update_start.count == 1
	assert append_error.count == 1
	assert update_end.count == 1
	assert source_ended.count == 1
	assert source.ready_state() == .ended

	source.end_of_stream(none) or {
		assert err.msg() == 'InvalidStateError: MediaSource is not open'
	}
	mut mutable_processor := buffer.processor_
	mutable_processor.set_updating(true)
	mut mutable_source := source
	mutable_source.set_ready_state_to_open_and_fire_sourceopen_event()
	source.end_of_stream(none) or {
		assert err.msg() == 'InvalidStateError: A SourceBuffer is still updating'
	}
	mutable_processor.set_updating(false)
	source.end_of_stream(none)!
	assert source.ready_state() == .ended
}

fn test_buffered_change_event_preserves_base_init_and_identity() {
	mut added := &html.TimeRanges{}
	added.add_range(1, 2)
	event := BufferedChangeEvent.construct_impl('bufferedchange', BufferedChangeEventInit{
		EventInit:    dom.EventInit{
			bubbles:    true
			cancelable: true
			composed:   true
		}
		added_ranges: added
	})!
	assert event.interface_ == .buffered_change_event
	assert event.type_ == 'bufferedchange'
	assert event.bubbles()
	assert event.cancelable()
	assert event.composed()
}

fn test_all_source_buffer_handlers_and_managed_handlers() {
	handler := observer_callback(&EventObservation{})
	buffer := SourceBuffer.create_internal()
	buffer.set_onupdatestart(handler)
	buffer.set_onupdate(handler)
	buffer.set_onupdateend(handler)
	buffer.set_onerror(handler)
	buffer.set_onabort(handler)
	assert buffer.onupdatestart() or { panic('missing') } == handler
	assert buffer.onupdate() or { panic('missing') } == handler
	assert buffer.onupdateend() or { panic('missing') } == handler
	assert buffer.onerror() or { panic('missing') } == handler
	assert buffer.onabort() or { panic('missing') } == handler

	managed_buffer := ManagedSourceBuffer.create_internal()
	managed_buffer.set_onbufferedchange(handler)
	assert managed_buffer.onbufferedchange() or { panic('missing') } == handler

	list := SourceBufferList.create_internal()
	list.set_onaddsourcebuffer(handler)
	list.set_onremovesourcebuffer(handler)
	assert list.onaddsourcebuffer() or { panic('missing') } == handler
	assert list.onremovesourcebuffer() or { panic('missing') } == handler

	managed_source := ManagedMediaSource.create()
	managed_source.set_onstartstreaming(handler)
	managed_source.set_onendstreaming(handler)
	assert managed_source.onstartstreaming() or { panic('missing') } == handler
	assert managed_source.onendstreaming() or { panic('missing') } == handler
	assert managed_source.onsourceopen() == none
}

fn test_media_source_handle_is_opaque_and_transferable() {
	handle := MediaSourceHandle.create_internal()
	assert handle.is_transferable()
}
