module mediasourceextensions

import dom
import fileapi
import html
import math

// Media source algorithms queue their steps and events; run them before observing the results.
fn run_media_source_tasks() {
	mut event_loop := html.main_thread_event_loop()
	queue := event_loop.task_queue()
	event_loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
}

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
	assert MediaSource.is_type_supported('video/mp4; codecs="av01.0.00M.08,mp4a.40.2"')
	assert MediaSource.is_type_supported('video/mp4; codecs="avc1.640028"')
	assert !MediaSource.is_type_supported('application/future-media')
	assert MediaSource.is_type_supported('video/webm; codecs="vp9,opus"')
	assert MediaSource.is_type_supported('video/webm; codecs="vp09.00.10.08"')
	assert MediaSource.is_type_supported('audio/webm; codecs="opus"')
	assert !MediaSource.is_type_supported('video/webm')
	for type_ in [
		'video/webm; codecs="vp8"',
		'video/webm; codecs="vorbis"',
		'video/webm; codecs="vp8,vorbis"',
		'video/webm; codecs="vorbis, vp8"',
		'audio/webm; codecs="vorbis"',
		'AUDIO/WEBM; CODECS="vorbis"',
		'audio/webm; codecs=vorbis; test="6"',
		'video/webm; codecs="opus"',
	] {
		assert MediaSource.is_type_supported(type_)
	}
	for type_ in [
		'video/mp4; codecs="avc1.4d001e"',
		'video/mp4; codecs="avc1.42001e"',
		'audio/mp4; codecs="mp4a.40.2"',
		'audio/mp4; codecs="mp4a.40.5"',
		'audio/mp4; codecs="mp4a.67"',
		'video/mp4; codecs="mp4a.40.2"',
		'video/mp4; codecs="avc1.4d001e,mp4a.40.2"',
		'video/mp4; codecs="mp4a.40.2 , avc1.4d001e "',
		'audio/mp4; codecs="Opus"',
		'video/mp4; codecs="fLaC"',
		'video/mp4; codecs="hvc1.1.6.L93.B0"',
		'video/mp4; codecs="hev1.A12.80000000.H255.90.12.34.56.78.9a"',
		'video/mp4; codecs="vp09.00.00.08"',
		'video/mp4; codecs="vp09.01.41.08.03.22.18.14.00"',
		'video/mp4; codecs="av01.0.31M.08"',
		'video/mp4; codecs="av01.1.08H.10.0.000.01.01.00.1"',
	] {
		assert MediaSource.is_type_supported(type_)
	}
	for type_ in [
		'audio/webm; codecs="vp8"',
		'audio/mp4; codecs="avc1.4d001e"',
		'audio/mp4; codecs="vorbis"',
		'audio/webm; codecs="mp4a.40.2"',
		'video/mp4; codecs="vp8"',
		'video/mp4; codecs="vorbis"',
		'video/webm; codecs="mp4a.40.2"',
		'audio/mp4; codecs="mp4a"',
		'audio/mp4; codecs="mp4a.40"',
		'audio/mp4; codecs="mp4a.40."',
		'audio/mp4; codecs="mp4a.67.3"',
		'video/mp4; codecs="avc1.nothex"',
		'video/webm; codecs="vp09.00.99.08"',
		'video/mp4; codecs="av01.0.00M"',
		'video/mp4; codecs="vp09.00.41.10"',
		'video/mp4; codecs="vp09.01.41.08.01.01.01.01.00"',
		'video/mp4; codecs="vp09.01.41.08.03.03.01.01.00"',
		'video/mp4; codecs="vp09.01.41.08.02.01.01.00.00"',
		'video/mp4; codecs="av01.3.05M.08"',
		'video/mp4; codecs="av01.0.24M.08"',
		'video/mp4; codecs="av01.0.05H.08"',
		'video/mp4; codecs="av01.0.05M.12"',
		'video/mp4; codecs="av01.2.08M.12.0.010.01.01.01.0"',
		'video/mp4; codecs="av01.0.08M.10.0.110.03.01.01.0"',
		'video/mp4; codecs="hvc1.32.6.L93.B0"',
		'video/mp4; codecs="hvc1.1.6.L256.B0"',
		'video/mp4; codecs="hvc1.1.6.L93.B0.00.00.00.00.00.00"',
	] {
		assert !MediaSource.is_type_supported(type_), 'unexpectedly supported ${type_}'
	}
	capabilities := MediaSource.decoder_capabilities_for_type('video/mp4; codecs="avc1.640028"') or {
		panic('expected decoder capabilities')
	}
	assert capabilities.smooth
	assert !capabilities.power_efficient
	assert MediaSource.decoder_capabilities_for_type('video/mp4; codecs="avc1"') == none
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
	run_media_source_tasks()

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
	run_media_source_tasks()
	assert second_media.network_state() == .no_source
	assert second_media.error()?.message == 'MediaSource is not closed'
}

fn test_media_source_detaches_and_removes_source_buffers_when_media_is_reset() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	mut active_buffers := source.active_source_buffers()
	active_buffers.append(buffer)

	close := &EventObservation{}
	source_remove := &EventObservation{}
	active_remove := &EventObservation{}
	abort := &EventObservation{}
	update_end := &EventObservation{}
	source.set_onsourceclose(observer_callback(close))
	source.source_buffers().set_onremovesourcebuffer(observer_callback(source_remove))
	source.active_source_buffers().set_onremovesourcebuffer(observer_callback(active_remove))
	buffer.set_onabort(observer_callback(abort))
	buffer.set_onupdateend(observer_callback(update_end))
	buffer.processor_.append_to_input_buffer([u8(1), 2, 3])
	buffer.processor_.set_updating(true)

	media.set_src_object(none)!
	run_media_source_tasks()

	assert source.ready_state() == .closed
	assert math.is_nan(source.duration())
	assert source.media_element_assigned_to() == none
	assert source.source_buffers().length() == 0
	assert source.active_source_buffers().length() == 0
	assert !buffer.updating()
	assert close.count == 1
	assert source_remove.count == 1
	assert active_remove.count == 1
	assert abort.count == 1
	assert update_end.count == 1
	buffer.append_buffer([u8(4)]) or {
		assert err.msg() == 'InvalidStateError: SourceBuffer has been removed'
	}
	run_media_source_tasks()
	buffer.buffered() or {
		assert err.msg() == 'InvalidStateError: SourceBuffer has been removed'
	}
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
	blob_url := fileapi.add_legacy_entry_to_blob_url_store(source.blob_url_object('media-source-url'), fileapi.LegacyBlobURLEnvironment{
		id: document.url_string()
		origin: origin.serialize()
		storage_key: origin.serialize_for_ipc()
	})!
	defer {
		fileapi.remove_legacy_entry_from_blob_url_store(blob_url)
	}

	media.set_source(blob_url)
	media.load()!
	assert media.current_src() == blob_url
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media

	media.set_source(none)
	media.load()!
	assert source.ready_state() == .closed
	assert source.media_element_assigned_to() == none
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
	run_media_source_tasks()
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

fn test_media_source_duration_mode_and_change_type() {
	mut source := MediaSource.create()
	assert math.is_nan(source.duration())
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	source.set_duration(-1) or {
		assert err.msg() == 'TypeError: duration must not be negative or NaN'
	}
	source.set_duration(4)!
	assert source.duration() == 4
	assert media.duration() == 4

	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	assert buffer.mode() == .segments
	buffer.set_mode(.sequence)!
	assert buffer.mode() == .sequence
	buffer.change_type('') or { assert err.msg() == 'TypeError: Type cannot be empty' }
	buffer.change_type('video/mp4; codecs="avc1"') or {
		assert err.msg() == 'NotSupportedError: Type is not supported'
	}
	buffer.change_type('video/webm; codecs="vp09.00.10.08"')!
	assert buffer.mode() == .sequence
}

fn test_source_buffer_append_error_and_end_of_stream_algorithms() {
	mut unattached := SourceBuffer.create_internal()
	unattached.append_buffer('data'.bytes()) or {
		assert err.msg() == 'InvalidStateError: Unsupported in workers'
	}
	run_media_source_tasks()

	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
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
	run_media_source_tasks()
	assert !buffer.updating()
	assert buffer.input_buffer_length() == 'not yet demuxed'.len
	assert update_start.count == 1
	assert append_error.count == 0
	assert update_end.count == 1
	assert source_ended.count == 0
	assert source.ready_state() == .open

	source.end_of_stream(none)!
	run_media_source_tasks()
	assert source_ended.count == 1
	source.end_of_stream(none) or {
		assert err.msg() == 'InvalidStateError: MediaSource is not open'
	}
	run_media_source_tasks()
	mut mutable_processor := buffer.processor_
	mutable_processor.set_updating(true)
	mut mutable_source := source
	mutable_source.set_ready_state_to_open_and_fire_sourceopen_event()
	run_media_source_tasks()
	source.end_of_stream(none) or {
		assert err.msg() == 'InvalidStateError: A SourceBuffer is still updating'
	}
	run_media_source_tasks()
	mutable_processor.set_updating(false)
	source.end_of_stream(none)!
	run_media_source_tasks()
	assert source.ready_state() == .ended
}

fn ebml_test_element(id []u8, payload []u8) []u8 {
	assert payload.len < 127
	mut bytes := id.clone()
	bytes << u8(0x80 | payload.len)
	bytes << payload
	return bytes
}

fn minimal_webm_initialization_segment() []u8 {
	timestamp_scale := ebml_test_element([u8(0x2a), 0xd7, 0xb1], [u8(0x0f), 0x42, 0x40])
	duration := ebml_test_element([u8(0x44), 0x89], [u8(0x40), 0x9f, 0x40, 0, 0, 0, 0, 0])
	mut info_payload := timestamp_scale.clone()
	info_payload << duration
	info := ebml_test_element([u8(0x15), 0x49, 0xa9, 0x66], info_payload)

	track_number := ebml_test_element([u8(0xd7)], [u8(1)])
	track_type := ebml_test_element([u8(0x83)], [u8(1)])
	codec := ebml_test_element([u8(0x86)], 'V_VP9'.bytes())
	default_duration := ebml_test_element([u8(0x23), 0xe3, 0x83], [u8(0x01), 0xfc, 0xa0, 0x55])
	mut entry_payload := track_number.clone()
	entry_payload << track_type
	entry_payload << codec
	entry_payload << default_duration
	entry := ebml_test_element([u8(0xae)], entry_payload)
	tracks := ebml_test_element([u8(0x16), 0x54, 0xae, 0x6b], entry)

	mut result := ebml_test_element([u8(0x1a), 0x45, 0xdf, 0xa3], []u8{})
	result << [u8(0x18), 0x53, 0x80, 0x67, 0xff]
	result << info
	result << tracks
	return result
}

fn minimal_webm_media_segment() []u8 {
	timecode := ebml_test_element([u8(0xe7)], [u8(0)])
	block := ebml_test_element([u8(0xa3)], [u8(0x81), 0, 0, 0x80, 1, 2])
	mut payload := timecode.clone()
	payload << block
	return ebml_test_element([u8(0x1f), 0x43, 0xb6, 0x75], payload)
}

fn test_webm_initialization_and_media_segments_create_tracks_and_coded_frames() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	update := &EventObservation{}
	append_error := &EventObservation{}
	buffer.set_onupdate(observer_callback(update))
	buffer.set_onerror(observer_callback(append_error))

	initialization := minimal_webm_initialization_segment()
	mut parser := WebMByteStreamParser.create()
	parser.parse_initialization_segment(initialization)!
	assert parser.codec_id_for_track(1) == 'V_VP9'
	assert parser.codec_initialization_data_for_track(1) == []
	assert parser.codec_id_for_track(99) == ''
	assert parser.video_tracks().len == 1
	assert parser.audio_tracks().len == 0
	assert parser.text_tracks().len == 0
	buffer.append_buffer(initialization[..initialization.len / 2])!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == initialization.len / 2
	assert buffer.video_tracks().length() == 0
	buffer.append_buffer(initialization[initialization.len / 2..])!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == 0
	assert buffer.video_tracks().length() == 1
	assert media.video_tracks().length() == 1
	assert media.video_tracks().item(0)?.base.kind() == 'main'
	assert source.active_source_buffers().item(0)? == buffer
	assert source.duration() == 2
	assert media.ready_state() == .have_metadata
	assert media.event_count('progress') == 0

	buffer.append_buffer(minimal_webm_media_segment())!
	run_media_source_tasks()
	track_buffer := buffer.processor_.track_buffers()[1] or { panic('missing track buffer') }
	assert track_buffer.demuxer.coded_frame_count() == 1
	frame := track_buffer.demuxer.coded_frames()[0]
	assert frame.codec_id == 'V_VP9'
	assert frame.new_codec_configuration != none
	assert frame.new_codec_configuration? == []
	assert frame.is_keyframe
	assert frame.data == [u8(1), 2]
	assert frame.timestamp == 0
	assert frame.duration > 0.033 && frame.duration < 0.034
	buffered := buffer.buffered()!
	assert buffered.length() == 1
	assert buffered.start(0)! == 0
	assert buffered.end(0)! > 0.033 && buffered.end(0)! < 0.034
	assert media.buffered().length() == 1
	assert media.event_count('progress') == 1
	assert append_error.count == 0
	assert update.count == 3
}

fn test_webm_track_metadata_preserves_bcp47_language_and_kind() {
	track_number := ebml_test_element([u8(0xd7)], [u8(9)])
	track_type := ebml_test_element([u8(0x83)], [u8(17)])
	codec := ebml_test_element([u8(0x86)], 'D_WEBVTT/captions'.bytes())
	language := ebml_test_element([u8(0x22), 0xb5, 0x9c], 'de'.bytes())
	language_bcp47 := ebml_test_element([u8(0x22), 0xb5, 0x9d], 'fr-CA'.bytes())
	flag_default := ebml_test_element([u8(0x88)], [u8(0)])
	mut payload := track_number.clone()
	payload << track_type
	payload << codec
	payload << language_bcp47
	payload << language
	payload << flag_default
	entry_bytes := ebml_test_element([u8(0xae)], payload)
	entry := read_ebml_element_header(entry_bytes, 0)!
	track := parse_webm_track_entry(entry_bytes, entry)!

	assert track.language == 'fr-CA'
	assert !track.is_default
	assert webm_track_kind(track, true) == .captions
	assert media_track_kind_to_text_track_kind(.captions) == .captions
	assert media_track_kind_to_text_track_kind(.subtitles) == .subtitles
	assert media_track_kind_to_text_track_kind(.descriptions) == .descriptions
	assert media_track_kind_to_text_track_kind(.main) == .metadata
}

fn test_webm_rejects_an_unsupported_initialization_segment_codec() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	append_error := &EventObservation{}
	buffer.set_onerror(observer_callback(append_error))
	mut initialization := minimal_webm_initialization_segment()
	codec_offset := initialization.bytestr().index('V_VP9') or { panic('missing test codec') }
	replacement := 'V_VP7'.bytes()
	for index, byte in replacement {
		initialization[codec_offset + index] = byte
	}

	buffer.append_buffer(initialization)!
	run_media_source_tasks()

	assert append_error.count == 1
	assert source.ready_state() == .ended
	assert buffer.video_tracks().length() == 0
}

fn test_source_buffer_abort_resets_parser_and_queues_abort_events_when_updating() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	buffer.append_buffer([u8(0x1a), 0x45])!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == 2
	buffer.abort()!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == 0

	abort_event := &EventObservation{}
	update_end := &EventObservation{}
	buffer.set_onabort(observer_callback(abort_event))
	buffer.set_onupdateend(observer_callback(update_end))
	mut processor := buffer.processor_
	processor.set_updating(true)
	buffer.abort()!
	run_media_source_tasks()
	assert !buffer.updating()
	assert abort_event.count == 1
	assert update_end.count == 1

	source.end_of_stream(none)!
	run_media_source_tasks()
	buffer.abort() or { assert err.msg() == 'InvalidStateError: MediaSource is not open' }
	run_media_source_tasks()
}

fn test_source_buffer_abort_discards_a_partial_media_segment_before_the_next_append() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	buffer.append_buffer(minimal_webm_initialization_segment())!
	run_media_source_tasks()

	media_segment := minimal_webm_media_segment()
	buffer.append_buffer(media_segment[..media_segment.len / 2])!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == media_segment.len / 2
	buffer.abort()!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == 0

	buffer.append_buffer(media_segment)!
	run_media_source_tasks()
	track_buffer := buffer.processor_.track_buffers()[1] or { panic('missing track buffer') }
	assert track_buffer.demuxer.coded_frame_count() == 1
}

fn test_source_buffer_keeps_a_split_ignored_webm_element_until_it_is_complete() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	buffer.append_buffer(minimal_webm_initialization_segment())!
	run_media_source_tasks()

	// A Void element containing eight bytes, split after its header and two
	// payload bytes. The first append must leave the whole prefix untouched.
	buffer.append_buffer([u8(0xec), 0x88, 0, 0])!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == 4

	mut remainder := [u8(0), 0, 0, 0, 0, 0]
	remainder << minimal_webm_media_segment()
	buffer.append_buffer(remainder)!
	run_media_source_tasks()
	assert buffer.input_buffer_length() == 0
	track_buffer := buffer.processor_.track_buffers()[1] or { panic('missing track buffer') }
	assert track_buffer.demuxer.coded_frame_count() == 1
}

fn test_source_buffer_ignores_webm_elements_after_a_repeated_initialization_segment() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	initialization := minimal_webm_initialization_segment()
	media_segment := minimal_webm_media_segment()

	buffer.append_buffer(initialization)!
	run_media_source_tasks()
	buffer.append_buffer(media_segment)!
	run_media_source_tasks()
	buffer.append_buffer(initialization)!
	run_media_source_tasks()
	// Matroska muxers commonly emit Tags after Tracks. It remains an accepted
	// ignored element even when this initialization segment follows a Cluster.
	tags := ebml_test_element([u8(0x12), 0x54, 0xc3, 0x67], []u8{})
	buffer.append_buffer(tags)!
	run_media_source_tasks()
	buffer.append_buffer(media_segment)!
	run_media_source_tasks()

	assert buffer.input_buffer_length() == 0
	track_buffer := buffer.processor_.track_buffers()[1] or { panic('missing track buffer') }
	assert track_buffer.demuxer.coded_frame_count() == 1
}

fn test_webm_parser_only_ignores_cues_and_chapters_after_a_cluster() {
	mut parser := WebMByteStreamParser.create()
	parser.parse_initialization_segment(minimal_webm_initialization_segment())!
	parser.parse_media_segment(minimal_webm_media_segment())!

	tags := ebml_test_element([u8(0x12), 0x54, 0xc3, 0x67], []u8{})
	cues := ebml_test_element([u8(0x1c), 0x53, 0xbb, 0x6b], []u8{})
	chapters := ebml_test_element([u8(0x10), 0x43, 0xa7, 0x70], []u8{})
	assert parser.ignored_element_length(tags)! == 0
	assert parser.ignored_element_length(cues)! == cues.len
	assert parser.ignored_element_length(chapters)! == chapters.len

	parser.parse_initialization_segment(minimal_webm_initialization_segment())!
	assert parser.ignored_element_length(tags)! == tags.len
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

fn test_managed_media_source_initializes_its_base_source_buffer_lists() {
	mut source := ManagedMediaSource.create()
	assert source.source_buffers().length() == 0
	assert source.active_source_buffers().length() == 0

	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	assert source.source_buffers().length() == 1
	assert source.source_buffers().item(0)? == buffer
}

fn test_media_source_handle_is_opaque_and_transferable() {
	handle := MediaSourceHandle.create_internal()
	assert handle.is_transferable()
}

fn test_media_source_attachment_state_and_associated_events() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	assert !source.has_ever_been_attached()
	source.set_has_ever_been_attached()
	source.set_assigned_to_media_element(media)
	assert source.has_ever_been_attached()
	assert source.media_element_assigned_to()? == media
	event := source.create_associated_event('sourceopen')
	assert event.type_ == 'sourceopen'
	assert event.is_trusted()
}

fn test_media_source_relevant_global_is_shared_by_owned_objects() {
	global_object := &dom.EventTarget{}
	mut source := MediaSource.create_for_constructor(global_object)
	assert source.relevant_global_impl() == global_object
	assert source.relevant_global_object() == global_object
	assert source.source_buffers().relevant_global_impl()? == global_object
	assert source.active_source_buffers().relevant_global_impl()? == global_object

	buffer := SourceBuffer.create_internal_for_media_source(source)
	assert buffer.relevant_global_impl()? == global_object
	assert SourceBuffer.create_internal().relevant_global_impl() == none

	managed_source := ManagedMediaSource.create_for_constructor(global_object)
	assert managed_source.relevant_global_impl() == global_object
	assert managed_source.source_buffers().relevant_global_impl()? == global_object
}

fn test_source_buffer_append_runs_its_steps_and_events_as_queued_tasks() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	run_media_source_tasks()
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	update_start := &EventObservation{}
	update_end := &EventObservation{}
	buffer.set_onupdatestart(observer_callback(update_start))
	buffer.set_onupdateend(observer_callback(update_end))

	buffer.append_buffer('not yet demuxed'.bytes())!
	assert buffer.updating()
	assert update_start.count == 0
	assert update_end.count == 0

	run_media_source_tasks()
	assert !buffer.updating()
	assert update_start.count == 1
	assert update_end.count == 1
}
