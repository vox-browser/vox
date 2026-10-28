// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaCapture/{MediaDeviceInfo,MediaDevices,MediaStream,
// MediaStreamTrack,MediaStreamTrackEvent}.{h,cpp,idl}. Platform audio devices
// and capture startup enter through MediaCaptureEnvironment; DOM-visible state,
// request gating, task ordering, tracks, and frame fan-out stay typed here.
@[has_globals]
module mediacapture

import dom
import permissionsapi
import rand

pub enum MediaDeviceKind {
	audioinput
	audiooutput
	videoinput
}

pub enum MediaStreamTrackKind {
	audio
	video
}

pub enum MediaStreamTrackState {
	live
	ended
}

pub enum MediaPromiseState {
	pending
	fulfilled
	rejected
}

pub struct MediaDeviceInfoJSON {
pub:
	device_id string
	kind      string
	label     string
	group_id  string
}

@[heap]
pub struct MediaDeviceInfo {
pub:
	device_id_ string
	kind_      MediaDeviceKind
	label_     string
	group_id_  string
}

pub fn MediaDeviceInfo.create(device_id string, kind MediaDeviceKind, label string, group_id string) &MediaDeviceInfo {
	return &MediaDeviceInfo{
		device_id_: device_id
		kind_: kind
		label_: label
		group_id_: group_id
	}
}

pub fn (device &MediaDeviceInfo) device_id() string {
	return device.device_id_
}

pub fn (device &MediaDeviceInfo) kind() MediaDeviceKind {
	return device.kind_
}

pub fn (device &MediaDeviceInfo) label() string {
	return device.label_
}

pub fn (device &MediaDeviceInfo) group_id() string {
	return device.group_id_
}

pub fn (device &MediaDeviceInfo) to_json() MediaDeviceInfoJSON {
	return MediaDeviceInfoJSON{
		device_id: device.device_id_
		kind: device.kind_.str()
		label: device.label_
		group_id: device.group_id_
	}
}

pub struct ULongRange {
pub:
	min ?u32
	max ?u32
}

pub struct DoubleRange {
pub:
	min ?f64
	max ?f64
}

pub struct DOMStringValues {
pub:
	single ?string
	list   []string
}

pub struct ConstrainDOMStringParameters {
pub:
	exact ?DOMStringValues
	ideal ?DOMStringValues
}

pub enum ConstrainDOMStringKind {
	string_value
	sequence
	parameters
}

pub struct ConstrainDOMString {
pub:
	kind       ConstrainDOMStringKind
	value      string
	values     []string
	parameters ConstrainDOMStringParameters
}

pub fn ConstrainDOMString.exact(values []string) ConstrainDOMString {
	return ConstrainDOMString{
		kind: .parameters
		parameters: ConstrainDOMStringParameters{
			exact: DOMStringValues{ list: values.clone() }
		}
	}
}

pub fn ConstrainDOMString.ideal(values []string) ConstrainDOMString {
	return ConstrainDOMString{
		kind: .parameters
		parameters: ConstrainDOMStringParameters{
			ideal: DOMStringValues{ list: values.clone() }
		}
	}
}

pub struct MediaTrackConstraintSet {
pub:
	width             ?u32
	height            ?u32
	aspect_ratio      ?f64
	frame_rate        ?f64
	facing_mode       ?ConstrainDOMString
	resize_mode       ?ConstrainDOMString
	sample_rate       ?u32
	sample_size       ?u32
	echo_cancellation ?bool
	auto_gain_control ?bool
	noise_suppression ?bool
	latency           ?f64
	channel_count     ?u32
	device_id         ?ConstrainDOMString
	group_id          ?ConstrainDOMString
	background_blur   ?bool
}

pub struct MediaTrackConstraints {
	MediaTrackConstraintSet
pub:
	advanced []MediaTrackConstraintSet
}

pub struct MediaTrackSettings {
pub:
	width             ?u32
	height            ?u32
	aspect_ratio      ?f64
	frame_rate        ?f64
	facing_mode       ?string
	resize_mode       ?string
	sample_rate       ?u32
	sample_size       ?u32
	echo_cancellation ?bool
	auto_gain_control ?bool
	noise_suppression ?bool
	latency           ?f64
	channel_count     ?u32
	device_id         ?string
	group_id          ?string
	background_blur   ?bool
}

pub struct MediaTrackCapabilities {
pub:
	width         ?ULongRange
	height        ?ULongRange
	aspect_ratio  ?DoubleRange
	frame_rate    ?DoubleRange
	sample_rate   ?ULongRange
	channel_count ?ULongRange
}

pub struct MediaTrackSupportedConstraints {
pub:
	width             bool = true
	height            bool = true
	aspect_ratio      bool = true
	frame_rate        bool = true
	facing_mode       bool = true
	resize_mode       bool = true
	sample_rate       bool = true
	sample_size       bool = true
	echo_cancellation bool = true
	auto_gain_control bool = true
	noise_suppression bool = true
	latency           bool = true
	channel_count     bool = true
	device_id         bool = true
	group_id          bool = true
	background_blur   bool = true
}

pub enum MediaConstraint {
	disabled
	enabled
	constrained
}

pub struct MediaStreamConstraints {
pub:
	audio             MediaConstraint
	video             MediaConstraint
	audio_constraints MediaTrackConstraints
	video_constraints MediaTrackConstraints
}

pub struct AudioFrame {
pub:
	samples       []f32
	frame_count   int
	channel_count u8
	sample_rate   u32
}

pub type AudioFramesCallback = fn ([]f32, int, u8, u32)

@[heap]
pub struct AudioFrameSink {
pub mut:
	on_frames     AudioFramesCallback = unsafe { nil }
	has_on_frames bool
	frames        []AudioFrame
	active        bool = true
}

pub fn AudioFrameSink.create(callback ?AudioFramesCallback) &AudioFrameSink {
	if on_frames := callback {
		return &AudioFrameSink{
			on_frames: on_frames
			has_on_frames: true
		}
	}
	return &AudioFrameSink{}
}

pub fn (mut sink AudioFrameSink) deliver(samples []f32, frames int, channels u8, rate u32) {
	if !sink.active {
		return
	}
	working_copy := samples.clone()
	sink.frames << AudioFrame{
		samples: working_copy
		frame_count: frames
		channel_count: channels
		sample_rate: rate
	}
	if sink.has_on_frames {
		sink.on_frames(working_copy, frames, channels, rate)
	}
}

pub fn (mut sink AudioFrameSink) deactivate() {
	sink.active = false
	sink.has_on_frames = false
}

@[heap]
pub struct AudioFrameFanout {
mut:
	sinks    []&AudioFrameSink
	silenced bool
}

pub fn AudioFrameFanout.create() &AudioFrameFanout {
	result := &AudioFrameFanout{}
	return result
}

pub fn (mut fanout AudioFrameFanout) add_sink(sink &AudioFrameSink) bool {
	fanout.sinks << sink
	return fanout.sinks.len == 1
}

pub fn (mut fanout AudioFrameFanout) remove_sink(sink &AudioFrameSink) bool {
	mut mutable_sink := unsafe { &AudioFrameSink(sink) }
	mutable_sink.deactivate()
	fanout.sinks = fanout.sinks.filter(it != sink)
	return fanout.sinks.len == 0
}

pub fn (mut fanout AudioFrameFanout) set_silenced(silenced bool) {
	fanout.silenced = silenced
}

pub fn (mut fanout AudioFrameFanout) deliver(samples []f32, frame_count int, channel_count u8, sample_rate u32) {
	if frame_count == 0 || channel_count == 0 || fanout.sinks.len == 0 {
		return
	}
	channels := int(channel_count)
	for offset := 0; offset < frame_count; offset += 1024 {
		frames := if frame_count - offset > 1024 { 1024 } else { frame_count - offset }
		start := offset * channels
		end := start + frames * channels
		if start < 0 || end > samples.len {
			return
		}
		mut chunk := samples[start..end].clone()
		if fanout.silenced {
			for index in 0 .. chunk.len {
				chunk[index] = 0
			}
		}
		for sink in fanout.sinks.clone() {
			mut mutable_sink := unsafe { &AudioFrameSink(sink) }
			mutable_sink.deliver(chunk, frames, channel_count, sample_rate)
		}
	}
}

@[heap]
pub struct MediaStreamTrack {
	dom.EventTarget
pub:
	kind_        MediaStreamTrackKind
	id_          string
	label_       string
	provider_id_ u64
mut:
	enabled_                    bool = true
	muted_                      bool
	state_                      MediaStreamTrackState
	constraints_                MediaTrackConstraints
	settings_                   MediaTrackSettings
	audio_fanout                &AudioFrameFanout = AudioFrameFanout.create()
	audio_capture_stream_active bool
	audio_capture_start_pending bool
	audio_capture_request_id    u64
}

fn next_provider_id() u64 {
	provider_id := media_capture_next_provider_id
	media_capture_next_provider_id++
	return provider_id
}

__global media_capture_next_provider_id = u64(1)

// https://w3c.github.io/mediacapture-main/#mediastreamtrack
pub fn MediaStreamTrack.create(kind MediaStreamTrackKind, label ?string, muted bool) &MediaStreamTrack {
	mut track := &MediaStreamTrack{
		kind_: kind
		id_: rand.uuid_v4()
		label_: label or { '' }
		provider_id_: next_provider_id()
		muted_: muted
		state_: .live
	}
	track.update_audio_silence_state()
	return track
}

pub fn (track &MediaStreamTrack) track_kind() MediaStreamTrackKind {
	return track.kind_
}

pub fn (track &MediaStreamTrack) id() string {
	return track.id_
}

pub fn (track &MediaStreamTrack) label() string {
	return track.label_
}

pub fn (track &MediaStreamTrack) enabled() bool {
	return track.enabled_
}

pub fn (mut track MediaStreamTrack) set_enabled(enabled bool) {
	track.enabled_ = enabled
	track.update_audio_silence_state()
}

pub fn (track &MediaStreamTrack) muted() bool {
	return track.muted_
}

pub fn (track &MediaStreamTrack) track_ready_state() MediaStreamTrackState {
	return track.state_
}

pub fn (mut track MediaStreamTrack) stop() {
	if track.state_ == .ended {
		return
	}
	track.stop_audio_capture()
	track.state_ = .ended
	track.update_audio_silence_state()
}

pub fn (mut track MediaStreamTrack) end() {
	if track.state_ == .ended {
		return
	}
	track.stop()
	track.EventTarget.dispatch_event(dom.Event.create('ended', dom.EventInit{}))
}

pub fn (track &MediaStreamTrack) clone() &MediaStreamTrack {
	mut clone := MediaStreamTrack.create(track.kind_, track.label_, track.muted_)
	clone.state_ = track.state_
	clone.constraints_ = track.constraints_
	clone.settings_ = track.settings_
	clone.enabled_ = track.enabled_
	clone.update_audio_silence_state()
	return clone
}

pub fn (track &MediaStreamTrack) is_audio() bool {
	return track.kind_ == .audio
}

pub fn (track &MediaStreamTrack) is_video() bool {
	return track.kind_ == .video
}

pub fn (track &MediaStreamTrack) get_capabilities() MediaTrackCapabilities {
	capabilities := MediaTrackCapabilities{}
	return capabilities
}

pub fn (track &MediaStreamTrack) get_constraints() MediaTrackConstraints {
	return track.constraints_
}

pub fn (track &MediaStreamTrack) get_settings() MediaTrackSettings {
	return track.settings_
}

pub fn (mut track MediaStreamTrack) apply_constraints(constraints ?MediaTrackConstraints) &MediaVoidPromise {
	track.apply_constraints_impl(constraints)
	return MediaVoidPromise.fulfilled()
}

pub fn (mut track MediaStreamTrack) apply_constraints_impl(constraints ?MediaTrackConstraints) {
	if value := constraints {
		track.constraints_ = value
	}
}

pub fn (mut track MediaStreamTrack) set_settings(settings MediaTrackSettings) {
	track.settings_ = settings
}

pub fn (track &MediaStreamTrack) device_id() ?string {
	return track.settings_.device_id
}

pub fn (track &MediaStreamTrack) sample_rate_hz() u32 {
	return track.settings_.sample_rate or { 0 }
}

pub fn (track &MediaStreamTrack) channel_count() u32 {
	return track.settings_.channel_count or { 0 }
}

pub fn (track &MediaStreamTrack) provider_id() u64 {
	return track.provider_id_
}

pub fn (mut track MediaStreamTrack) add_audio_sink(sink &AudioFrameSink) {
	if track.audio_fanout.add_sink(sink) && track.is_audio() && track.state_ == .live
		&& track.device_id() != none {
		track.ensure_audio_capture_started()
	}
}

pub fn (mut track MediaStreamTrack) remove_audio_sink(sink &AudioFrameSink) {
	if track.audio_fanout.remove_sink(sink) {
		track.stop_audio_capture()
	}
}

pub fn (mut track MediaStreamTrack) deliver_audio_frames(samples []f32, frame_count int, channel_count u8, sample_rate u32) {
	track.audio_fanout.deliver(samples, frame_count, channel_count, sample_rate)
}

pub fn (mut track MediaStreamTrack) ensure_audio_capture_started() {
	if track.audio_capture_stream_active || track.audio_capture_start_pending {
		return
	}
	track.audio_capture_start_pending = true
	track.audio_capture_request_id++
}

pub fn (mut track MediaStreamTrack) complete_audio_capture_start(request_id u64, succeeded bool) {
	if request_id != track.audio_capture_request_id {
		return
	}
	track.audio_capture_start_pending = false
	if succeeded && track.state_ == .live {
		track.audio_capture_stream_active = true
	}
}

pub fn (mut track MediaStreamTrack) stop_audio_capture() {
	track.audio_capture_start_pending = false
	track.audio_capture_request_id++
	track.audio_capture_stream_active = false
}

pub fn (mut track MediaStreamTrack) update_audio_silence_state() {
	track.audio_fanout.set_silenced(!track.enabled_ || track.muted_ || track.state_ == .ended)
}

pub fn (mut track MediaStreamTrack) finalize() {
	track.stop_audio_capture()
}

pub fn (track &MediaStreamTrack) capture_request_id() u64 {
	return track.audio_capture_request_id
}

pub fn (track &MediaStreamTrack) capture_start_pending() bool {
	return track.audio_capture_start_pending
}

pub fn (track &MediaStreamTrack) capture_stream_active() bool {
	return track.audio_capture_stream_active
}

@[heap]
pub struct MediaVoidPromise {
mut:
	state_  MediaPromiseState
	reason_ string
}

fn MediaVoidPromise.fulfilled() &MediaVoidPromise {
	return &MediaVoidPromise{ state_: .fulfilled }
}

pub fn (promise &MediaVoidPromise) state() MediaPromiseState {
	return promise.state_
}

pub fn (promise &MediaVoidPromise) reason() string {
	return promise.reason_
}

pub struct MediaStreamTrackEventInit {
	dom.EventInit
pub:
	track &MediaStreamTrack @[required]
}

@[heap]
pub struct MediaStreamTrackEvent {
	dom.Event
pub:
	track_ &MediaStreamTrack
}

pub fn MediaStreamTrackEvent.track_offset() uint {
	event_storage_size := sizeof(dom.Event)
	return uint(event_storage_size)
}

pub fn MediaStreamTrackEvent.create(event_name string, event_init MediaStreamTrackEventInit, time_stamp f64) &MediaStreamTrackEvent {
	mut event := dom.Event.new_with_init(event_name, event_init.EventInit)
	event.set_time_stamp(time_stamp)
	return &MediaStreamTrackEvent{
		Event: event
		track_: event_init.track
	}
}

pub fn (event &MediaStreamTrackEvent) track() &MediaStreamTrack {
	return event.track_
}

@[heap]
pub struct MediaStream {
	dom.EventTarget
pub:
	id_ string
mut:
	tracks_ []&MediaStreamTrack
}

pub fn MediaStream.create(tracks []&MediaStreamTrack) &MediaStream {
	mut stream := &MediaStream{ id_: rand.uuid_v4() }
	for track in tracks {
		stream.add_track(track)
	}
	return stream
}

pub fn MediaStream.create_empty() &MediaStream {
	return MediaStream.create([]&MediaStreamTrack{})
}

pub fn (stream &MediaStream) id() string {
	return stream.id_
}

pub fn (stream &MediaStream) get_audio_tracks() []&MediaStreamTrack {
	return stream.tracks_.filter(it.is_audio())
}

pub fn (stream &MediaStream) get_video_tracks() []&MediaStreamTrack {
	return stream.tracks_.filter(it.is_video())
}

pub fn (stream &MediaStream) get_tracks() []&MediaStreamTrack {
	return stream.tracks_.clone()
}

pub fn (stream &MediaStream) get_track_by_id(track_id string) ?&MediaStreamTrack {
	for track in stream.tracks_ {
		if track.id_ == track_id {
			return track
		}
	}
	return none
}

pub fn (mut stream MediaStream) add_track(track &MediaStreamTrack) {
	if stream.tracks_.any(it == track) {
		return
	}
	stream.tracks_ << track
	event := MediaStreamTrackEvent.create('addtrack', MediaStreamTrackEventInit{ track: track }, 0)
	stream.EventTarget.dispatch_event(unsafe { &dom.Event(event) })
}

pub fn (mut stream MediaStream) append_track(track &MediaStreamTrack) {
	if !stream.tracks_.any(it == track) {
		stream.tracks_ << track
	}
}

pub fn (mut stream MediaStream) remove_track(track &MediaStreamTrack) {
	if !stream.tracks_.any(it == track) {
		return
	}
	stream.tracks_ = stream.tracks_.filter(it != track)
	event := MediaStreamTrackEvent.create('removetrack', MediaStreamTrackEventInit{ track: track }, 0)
	stream.EventTarget.dispatch_event(unsafe { &dom.Event(event) })
}

pub fn (stream &MediaStream) clone() &MediaStream {
	mut clone := MediaStream.create_empty()
	for track in stream.tracks_ {
		clone.append_track(track.clone())
	}
	return clone
}

pub fn (stream &MediaStream) active() bool {
	return stream.tracks_.any(it.track_ready_state() != .ended)
}

pub fn (stream &MediaStream) onaddtrack() ?&dom.CallbackType {
	return stream.EventTarget.event_handler_attribute('addtrack')
}

pub fn (stream &MediaStream) set_onaddtrack(event_handler ?&dom.CallbackType) {
	stream.EventTarget.set_event_handler_attribute('addtrack', event_handler)
}

pub fn (stream &MediaStream) onremovetrack() ?&dom.CallbackType {
	return stream.EventTarget.event_handler_attribute('removetrack')
}

pub fn (stream &MediaStream) set_onremovetrack(event_handler ?&dom.CallbackType) {
	stream.EventTarget.set_event_handler_attribute('removetrack', event_handler)
}

pub struct StoredDevice {
pub:
	dom_device_id  string
	kind           MediaDeviceKind
	label          string
	group_id       string
	is_default     bool
	sample_rate_hz u32
	channel_count  u32
}

@[heap]
// The platform side of media capture: the audio device cache, the microphone permission, and test mode. The
// window-side state (full activity, visibility, focus, and permissions policy) comes from MediaDevices' Document.
pub struct MediaCaptureEnvironment {
pub mut:
	test_mode                bool
	audio_device_cache_ready bool = true
	microphone_permission    permissionsapi.PermissionState = .prompt
	audio_devices            []StoredDevice
}

@[heap]
pub struct MediaDeviceListPromise {
mut:
	state_   MediaPromiseState
	devices_ []&MediaDeviceInfo
	reason_  string
}

fn MediaDeviceListPromise.pending() &MediaDeviceListPromise {
	promise := &MediaDeviceListPromise{}
	return promise
}

pub fn (promise &MediaDeviceListPromise) state() MediaPromiseState {
	return promise.state_
}

pub fn (promise &MediaDeviceListPromise) devices() []&MediaDeviceInfo {
	return promise.devices_.clone()
}

pub fn (promise &MediaDeviceListPromise) reason() string {
	return promise.reason_
}

@[heap]
pub struct MediaStreamPromise {
mut:
	state_  MediaPromiseState
	stream_ &MediaStream = unsafe { nil }
	reason_ string
}

fn MediaStreamPromise.pending() &MediaStreamPromise {
	promise := &MediaStreamPromise{}
	return promise
}

pub fn (promise &MediaStreamPromise) state() MediaPromiseState {
	return promise.state_
}

pub fn (promise &MediaStreamPromise) stream() ?&MediaStream {
	if isnil(promise.stream_) {
		return none
	}
	return promise.stream_
}

pub fn (promise &MediaStreamPromise) reason() string {
	return promise.reason_
}

fn resolve_media_stream_promise(mut promise MediaStreamPromise, stream &MediaStream) {
	if promise.state_ == .pending {
		promise.stream_ = stream
		promise.state_ = .fulfilled
	}
}

fn resolve_media_device_info_list_promise(mut promise MediaDeviceListPromise, devices []&MediaDeviceInfo) {
	if promise.state_ == .pending {
		promise.devices_ = devices.clone()
		promise.state_ = .fulfilled
	}
}

fn (mut promise MediaStreamPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.reason_ = reason
		promise.state_ = .rejected
	}
}

enum MediaDevicesTaskKind {
	enumerate_devices
	get_user_media
	device_change
}

struct MediaDevicesTask {
	kind                 MediaDevicesTaskKind
	device_promise       &MediaDeviceListPromise = unsafe { nil }
	stream_promise       &MediaStreamPromise = unsafe { nil }
	requested_device_ids ?[]string
}

struct PendingGetUserMediaRequest {
	promise              &MediaStreamPromise
	requested_device_ids ?[]string
}

@[heap]
pub struct MediaDevices {
	dom.EventTarget
pub:
	// MediaDevices' Window, represented by its associated Document; DOM cannot name the HTML Window.
	document_   &dom.Document
	environment &MediaCaptureEnvironment
mut:
	devices_live_map                     map[string]bool
	devices_accessible_map               map[string]bool
	stored_device_list                   []StoredDevice
	can_expose_camera_info               bool
	can_expose_microphone_info           bool
	media_stream_track_sources           map[u64]bool
	pending_enumerate_devices_requests   []&MediaDeviceListPromise
	pending_get_user_media_requests      []PendingGetUserMediaRequest
	pending_request_state_change_listener_ ?&dom.IDLEventListener
	tasks                                []MediaDevicesTask
	device_change_event_count            int
}

pub fn MediaDevices.create(document &dom.Document, environment &MediaCaptureEnvironment) &MediaDevices {
	mut media_devices := &MediaDevices{
		document_: document
		environment: environment
	}
	media_devices.initialize_pending_request_state_change_listener()
	media_devices.did_observe_audio_device_cache_update()
	return media_devices
}

pub fn (mut media_devices MediaDevices) initialize_pending_request_state_change_listener() {
	media_devices_pointer := voidptr(media_devices)
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [media_devices_pointer] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut devices := unsafe { &MediaDevices(media_devices_pointer) }
			devices.process_pending_enumerate_devices_requests()
			devices.process_pending_get_user_media_requests()
			return dom.js_undefined()
		}
	})
	media_devices.pending_request_state_change_listener_ = listener

	unsafe { &dom.EventTarget(media_devices.document_.as_node()) }.add_event_listener_without_options('visibilitychange',
		listener)
	if window := media_devices.document_.get_window() {
		window_target := unsafe { &dom.EventTarget(window) }
		window_target.add_event_listener_without_options('focus', listener)
		window_target.add_event_listener_without_options('blur', listener)
	}
}

pub fn (mut media_devices MediaDevices) finalize() {
	listener := media_devices.pending_request_state_change_listener_ or { return }
	unsafe { &dom.EventTarget(media_devices.document_.as_node()) }.remove_event_listener_without_options('visibilitychange',
		listener)
	if window := media_devices.document_.get_window() {
		window_target := unsafe { &dom.EventTarget(window) }
		window_target.remove_event_listener_without_options('focus', listener)
		window_target.remove_event_listener_without_options('blur', listener)
	}
	media_devices.pending_request_state_change_listener_ = none
}

pub fn (media_devices &MediaDevices) get_supported_constraints() MediaTrackSupportedConstraints {
	constraints := MediaTrackSupportedConstraints{}
	return constraints
}

pub fn (media_devices &MediaDevices) device_information_can_be_exposed() bool {
	return media_devices.camera_information_can_be_exposed()
		|| media_devices.microphone_information_can_be_exposed()
}

pub fn (media_devices &MediaDevices) microphone_information_can_be_exposed() bool {
	return media_devices.has_live_device_of_kind(.audioinput)
		|| media_devices.can_expose_microphone_info
}

pub fn (media_devices &MediaDevices) camera_information_can_be_exposed() bool {
	return media_devices.has_live_device_of_kind(.videoinput)
		|| media_devices.can_expose_camera_info
}

pub fn (media_devices &MediaDevices) can_use_microphone_feature() bool {
	return media_devices.document_.is_allowed_to_use_feature(.microphone)
}

pub fn (media_devices &MediaDevices) can_use_camera_feature() bool {
	return media_devices.document_.is_allowed_to_use_feature(.camera)
}

pub fn (media_devices &MediaDevices) device_enumeration_can_proceed() bool {
	return media_devices.device_information_can_be_exposed() || media_devices.is_in_view()
}

pub fn (media_devices &MediaDevices) get_user_media_can_proceed() bool {
	return media_devices.is_in_view() && media_devices.document_.has_focus()
}

pub fn (media_devices &MediaDevices) is_in_view() bool {
	document := media_devices.document_
	return document.is_fully_active() && document.visibility_state_value() == .visible
}

pub fn (media_devices &MediaDevices) has_live_device_of_kind(kind MediaDeviceKind) bool {
	for device in media_devices.stored_device_list {
		if device.kind == kind && (media_devices.devices_live_map[device.dom_device_id] or { false }) {
			return true
		}
	}
	return false
}

pub fn (mut media_devices MediaDevices) set_device_information_exposure(audio_requested bool, video_requested bool, value bool) {
	if video_requested {
		media_devices.can_expose_camera_info = value
	}
	if audio_requested {
		media_devices.can_expose_microphone_info = value
	}
	media_devices.process_pending_enumerate_devices_requests()
	media_devices.process_pending_get_user_media_requests()
}

pub fn (mut media_devices MediaDevices) enumerate_devices() &MediaDeviceListPromise {
	promise := MediaDeviceListPromise.pending()
	if !media_devices.device_enumeration_can_proceed()
		|| !media_devices.environment.audio_device_cache_ready {
		media_devices.pending_enumerate_devices_requests << promise
		return promise
	}
	media_devices.stored_device_list = media_devices.current_audio_device_snapshot()
	media_devices.queue_enumerate_devices_task(promise)
	return promise
}

pub fn (media_devices &MediaDevices) create_list_of_device_info_objects(device_list []StoredDevice) []&MediaDeviceInfo {
	mut microphone_list := []&MediaDeviceInfo{}
	mut camera_list := []&MediaDeviceInfo{}
	mut other_device_list := []&MediaDeviceInfo{}
	for device in device_list {
		if device.kind != .audioinput || !media_devices.can_use_microphone_feature() {
			continue
		}
		mut device_id := device.dom_device_id
		mut label := device.label
		mut group_id := device.group_id
		if !media_devices.microphone_information_can_be_exposed() {
			device_id = ''
			label = ''
			group_id = ''
		}
		info := MediaDeviceInfo.create(device_id, .audioinput, label, group_id)
		if device.is_default {
			microphone_list.prepend(info)
		} else {
			microphone_list << info
		}
	}
	if !media_devices.microphone_information_can_be_exposed() && microphone_list.len > 1 {
		microphone_list = microphone_list[..1].clone()
	}
	if !media_devices.camera_information_can_be_exposed() && camera_list.len > 1 {
		camera_list = camera_list[..1].clone()
	}
	for device in device_list {
		if device.kind in [.audioinput, .videoinput]
			|| !media_devices.device_information_can_be_exposed() {
			continue
		}
		info := MediaDeviceInfo.create(device.dom_device_id, device.kind, device.label, device.group_id)
		if device.kind == .audiooutput && device.is_default {
			other_device_list.prepend(info)
		} else {
			other_device_list << info
		}
	}
	mut result := []&MediaDeviceInfo{}
	result << microphone_list
	result << camera_list
	result << other_device_list
	return result
}

pub fn (mut media_devices MediaDevices) queue_get_user_media_task(promise &MediaStreamPromise, requested_device_ids ?[]string) {
	media_devices.tasks << MediaDevicesTask{
		kind: .get_user_media
		stream_promise: promise
		requested_device_ids: requested_device_ids
	}
}

pub fn (mut media_devices MediaDevices) queue_enumerate_devices_task(promise &MediaDeviceListPromise) {
	media_devices.tasks << MediaDevicesTask{
		kind: .enumerate_devices
		device_promise: promise
	}
}

pub fn (mut media_devices MediaDevices) process_pending_enumerate_devices_requests() {
	if !media_devices.device_enumeration_can_proceed()
		|| !media_devices.environment.audio_device_cache_ready {
		return
	}
	media_devices.run_device_change_notification_steps(media_devices.current_audio_device_snapshot())
	pending := media_devices.pending_enumerate_devices_requests.clone()
	media_devices.pending_enumerate_devices_requests.clear()
	for promise in pending {
		media_devices.queue_enumerate_devices_task(promise)
	}
}

pub fn (mut media_devices MediaDevices) process_pending_get_user_media_requests() {
	if !media_devices.get_user_media_can_proceed()
		|| !media_devices.environment.audio_device_cache_ready {
		return
	}
	pending := media_devices.pending_get_user_media_requests.clone()
	media_devices.pending_get_user_media_requests.clear()
	for request in pending {
		media_devices.queue_get_user_media_task(request.promise, request.requested_device_ids)
	}
}

pub fn (mut media_devices MediaDevices) run_device_change_notification_steps(device_list []StoredDevice) {
	if !media_devices.device_enumeration_can_proceed() {
		return
	}
	old_devices := media_devices.create_list_of_device_info_objects(media_devices.stored_device_list)
	new_devices := media_devices.create_list_of_device_info_objects(device_list)
	if media_device_lists_equal(old_devices, new_devices) {
		return
	}
	media_devices.stored_device_list = device_list.clone()
	media_devices.tasks << MediaDevicesTask{ kind: .device_change }
}

fn media_device_lists_equal(a []&MediaDeviceInfo, b []&MediaDeviceInfo) bool {
	if a.len != b.len {
		return false
	}
	for index, device in a {
		other := b[index]
		if device.kind_ != other.kind_ || device.device_id_ != other.device_id_
			|| device.label_ != other.label_ || device.group_id_ != other.group_id_ {
			return false
		}
	}
	return true
}

pub fn (mut media_devices MediaDevices) get_user_media(constraints ?MediaStreamConstraints) &MediaStreamPromise {
	mut promise := MediaStreamPromise.pending()
	constraint_value := constraints or {
		promise.reject('TypeError: getUserMedia requires constraints')
		return promise
	}
	audio_requested := constraint_value.audio != .disabled
	video_requested := constraint_value.video != .disabled
	if !audio_requested && !video_requested {
		promise.reject('TypeError: No media types requested')
		return promise
	}
	if !media_devices.document_.is_fully_active() {
		promise.reject('InvalidStateError: Document is not fully active')
		return promise
	}
	if audio_requested && !media_devices.can_use_microphone_feature() {
		promise.reject('NotAllowedError: Permission denied')
		return promise
	}
	if video_requested && !media_devices.can_use_camera_feature() {
		promise.reject('NotAllowedError: Permission denied')
		return promise
	}
	if video_requested {
		promise.reject('NotSupportedError: Video capture is not supported')
		return promise
	}
	requested_device_ids := if constraint_value.audio == .constrained {
		extract_device_id_constraint(constraint_value.audio_constraints.device_id)
	} else {
		none
	}
	if !media_devices.get_user_media_can_proceed()
		|| !media_devices.environment.audio_device_cache_ready {
		media_devices.pending_get_user_media_requests << PendingGetUserMediaRequest{
			promise: promise
			requested_device_ids: requested_device_ids
		}
		return promise
	}
	media_devices.queue_get_user_media_task(promise, requested_device_ids)
	return promise
}

pub fn (media_devices &MediaDevices) ondevicechange() ?&dom.CallbackType {
	return media_devices.EventTarget.event_handler_attribute('devicechange')
}

pub fn (media_devices &MediaDevices) set_ondevicechange(event_handler ?&dom.CallbackType) {
	media_devices.EventTarget.set_event_handler_attribute('devicechange', event_handler)
}

pub fn (media_devices &MediaDevices) current_audio_device_snapshot() []StoredDevice {
	return media_devices.environment.audio_devices.clone()
}

pub fn (mut media_devices MediaDevices) did_observe_audio_device_cache_update() {
	media_devices.process_pending_enumerate_devices_requests()
	media_devices.process_pending_get_user_media_requests()
}

pub fn (media_devices &MediaDevices) has_queued_tasks() bool {
	return media_devices.tasks.len > 0
}

pub fn (mut media_devices MediaDevices) run_next_task() bool {
	if media_devices.tasks.len == 0 {
		return false
	}
	task := media_devices.tasks[0]
	media_devices.tasks.delete(0)
	match task.kind {
		.enumerate_devices {
			mut promise := unsafe { &MediaDeviceListPromise(task.device_promise) }
			resolve_media_device_info_list_promise(mut promise, media_devices.create_list_of_device_info_objects(media_devices.stored_device_list))
		}
		.get_user_media {
			media_devices.run_get_user_media_task(task.stream_promise, task.requested_device_ids)
		}
		.device_change {
			media_devices.device_change_event_count++
			media_devices.EventTarget.dispatch_event(dom.Event.create('devicechange', dom.EventInit{}))
		}
	}
	return true
}

pub fn (mut media_devices MediaDevices) run_until_idle() {
	for media_devices.run_next_task() {
	}
}

fn (mut media_devices MediaDevices) run_get_user_media_task(promise_pointer &MediaStreamPromise, requested_device_ids ?[]string) {
	mut promise := unsafe { &MediaStreamPromise(promise_pointer) }
	mut candidates := media_devices.environment.audio_devices.filter(it.kind == .audioinput)
	if candidates.len == 0 {
		promise.reject('NotFoundError: No audio input devices available')
		return
	}
	if ids := requested_device_ids {
		if ids.len > 0 {
			candidates = candidates.filter(it.dom_device_id in ids)
			if candidates.len == 0 {
				promise.reject('NotFoundError: Requested audio input device not found')
				return
			}
		}
	}
	if media_devices.environment.microphone_permission == .denied {
		promise.reject('NotAllowedError: Permission denied')
		return
	}
	if media_devices.environment.test_mode
		&& media_devices.environment.microphone_permission == .prompt {
		mut environment := unsafe { &MediaCaptureEnvironment(media_devices.environment) }
		environment.microphone_permission = .granted
	}
	media_devices.set_device_information_exposure(true, false, true)
	mut selected := candidates[0]
	for candidate in candidates {
		if candidate.is_default {
			selected = candidate
			break
		}
	}
	media_devices.devices_live_map[selected.dom_device_id] = true
	media_devices.devices_accessible_map[selected.dom_device_id] = true
	mut track := MediaStreamTrack.create(.audio, selected.label, false)
	track.set_settings(MediaTrackSettings{
		device_id: selected.dom_device_id
		sample_rate: selected.sample_rate_hz
		channel_count: selected.channel_count
	})
	mut stream := MediaStream.create_empty()
	stream.append_track(track)
	media_devices.media_stream_track_sources[track.provider_id()] = true
	resolve_media_stream_promise(mut promise, stream)
}

pub fn dom_string_values_from_variant(value DOMStringValues) ?[]string {
	mut values := []string{}
	if single := value.single {
		if single.len > 0 {
			values << single
		}
	} else {
		values = value.list.filter(it.len > 0)
	}
	if values.len == 0 {
		return none
	}
	return values
}

pub fn extract_dom_string_constraint_values(constraint ConstrainDOMString) ?[]string {
	match constraint.kind {
		.parameters {
			if exact := constraint.parameters.exact {
				return dom_string_values_from_variant(exact)
			}
			if ideal := constraint.parameters.ideal {
				return dom_string_values_from_variant(ideal)
			}
			return none
		}
		.string_value {
			return dom_string_values_from_variant(DOMStringValues{ single: constraint.value })
		}
		.sequence {
			return dom_string_values_from_variant(DOMStringValues{ list: constraint.values })
		}
	}
}

pub fn extract_device_id_constraint(device_id_value ?ConstrainDOMString) ?[]string {
	value := device_id_value or { return none }
	return extract_dom_string_constraint_values(value)
}
