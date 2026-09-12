module mediasourceextensions

import dom
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
