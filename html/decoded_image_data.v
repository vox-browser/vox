// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/DecodedImageData.{h,cpp},
// BitmapDecodedImageData.{h,cpp}, and AnimatedDecodedImageData.{h,cpp}.
@[has_globals]
module html

import dom
import painting
import platform

pub struct BitmapRect {
pub:
	x      int
	y      int
	width  int
	height int
}

// The common DecodedImageData contract. Painting remains at the layout/Gfx
// boundary; consumers obtain the selected decoded frame and destination
// metadata from this interface.
pub interface DecodedImageData {
	external_memory_size() usize
	has_clients() bool
	is_cors_cross_origin() bool
	set_is_cors_cross_origin(value bool)
	frame(frame_index usize) ?&dom.DecodedImageFrame_
	frame_duration(frame_index usize) int
	frame_count() usize
	loop_count() usize
	is_animated() bool
	intrinsic_width() ?f64
	intrinsic_height() ?f64
	intrinsic_aspect_ratio() ?f64
	frame_rect(frame_index usize) ?BitmapRect
}

// DecodedImageData's default virtual keeps the caller's frame index. Animated
// implementations override this when advancing their ring buffer.
pub fn decoded_image_data_notify_frame_advanced(_ DecodedImageData, frame_index usize) usize {
	return frame_index
}

pub struct BitmapDecodedImageFrame {
pub:
	frame    ?&dom.DecodedImageFrame_
	duration int
}

@[heap]
pub struct BitmapDecodedImageData {
mut:
	frames_               []BitmapDecodedImageFrame
	loop_count_           usize
	animated_             bool
	clients               map[u64]DecodedImageClientUpdateCallback
	is_cors_cross_origin_ bool
}

pub fn BitmapDecodedImageData.create(frames []BitmapDecodedImageFrame, loop_count usize, animated bool) &BitmapDecodedImageData {
	return &BitmapDecodedImageData{
		frames_:     frames.clone()
		loop_count_: loop_count
		animated_:   animated
		clients:     map[u64]DecodedImageClientUpdateCallback{}
	}
}

pub fn (data &BitmapDecodedImageData) external_memory_size() usize {
	mut size := usize(0)
	for retained_frame in data.frames_ {
		frame := retained_frame.frame or { continue }
		frame_size := usize(frame.bitmap().data.len)
		if usize(-1) - size < frame_size {
			return usize(-1)
		}
		size += frame_size
	}
	return size
}

pub fn (data &BitmapDecodedImageData) has_clients() bool {
	return data.clients.len != 0
}

pub fn (data &BitmapDecodedImageData) is_cors_cross_origin() bool {
	return data.is_cors_cross_origin_
}

pub fn (data &BitmapDecodedImageData) set_is_cors_cross_origin(value bool) {
	mut mutable_data := unsafe { &BitmapDecodedImageData(data) }
	mutable_data.is_cors_cross_origin_ = value
}

pub fn (data &BitmapDecodedImageData) register_client(client_id u64, callback DecodedImageClientUpdateCallback) {
	mut mutable_data := unsafe { &BitmapDecodedImageData(data) }
	mutable_data.clients[client_id] = callback
}

pub fn (data &BitmapDecodedImageData) unregister_client(client_id u64) {
	mut mutable_data := unsafe { &BitmapDecodedImageData(data) }
	mutable_data.clients.delete(client_id)
}

pub fn (data &BitmapDecodedImageData) frame(frame_index usize) ?&dom.DecodedImageFrame_ {
	if frame_index >= usize(data.frames_.len) {
		return none
	}
	return data.frames_[frame_index].frame
}

pub fn (data &BitmapDecodedImageData) frame_duration(frame_index usize) int {
	if frame_index >= usize(data.frames_.len) {
		return 0
	}
	return data.frames_[frame_index].duration
}

pub fn (data &BitmapDecodedImageData) frame_count() usize {
	return usize(data.frames_.len)
}

pub fn (data &BitmapDecodedImageData) loop_count() usize {
	return data.loop_count_
}

pub fn (data &BitmapDecodedImageData) is_animated() bool {
	return data.animated_
}

fn bitmap_data_first_frame(data &BitmapDecodedImageData) ?&dom.DecodedImageFrame_ {
	if data.frames_.len == 0 {
		return none
	}
	return data.frames_[0].frame
}

pub fn (data &BitmapDecodedImageData) intrinsic_width() ?f64 {
	frame := bitmap_data_first_frame(data) or { return none }
	return f64(frame.width())
}

pub fn (data &BitmapDecodedImageData) intrinsic_height() ?f64 {
	frame := bitmap_data_first_frame(data) or { return none }
	return f64(frame.height())
}

pub fn (data &BitmapDecodedImageData) intrinsic_aspect_ratio() ?f64 {
	frame := bitmap_data_first_frame(data) or { return none }
	if frame.height() == 0 {
		return none
	}
	return f64(frame.width()) / f64(frame.height())
}

pub fn (data &BitmapDecodedImageData) frame_rect(frame_index usize) ?BitmapRect {
	frame := data.frame(frame_index) or { return none }
	return BitmapRect{
		width:  frame.width()
		height: frame.height()
	}
}

pub fn (data &AnimatedDecodedImageData) session_id() i64 {
	return data.session_id
}

pub fn (data &BitmapDecodedImageData) paint(mut recorder painting.DisplayListRecorder, frame_index usize, destination painting.IntRect, clip_rect painting.IntRect, scaling_mode painting.ScalingMode) bool {
	frame := data.frame(frame_index) or { return false }
	return recorder.draw_scaled_decoded_image_frame(painting.DrawScaledDecodedImageFrame{
		destination: destination
		clip_rect:   clip_rect
		frame:       frame
		scaling:     scaling_mode
	})
}

const animated_decoded_image_buffer_pool_size = 8
const animated_decoded_image_request_batch_size = 4

pub struct AnimatedBitmapSlot {
mut:
	frame_index ?u32
	frame       ?&dom.DecodedImageFrame_
	generation  u64
}

pub type AnimationFrameRequestCallback = fn (i64, u32, u32)

pub type AnimationStopCallback = fn (i64)

pub type DecodedImageClientUpdateCallback = fn ()

pub struct AnimatedImageDebugState {
pub:
	timer_active    bool
	session_id      i64
	frame_index     u32
	frame_count     u32
	loops_completed u32
	loop_count      u32
	client_count    usize
}

@[heap]
pub struct AnimatedDecodedImageData {
pub:
	session_id i64
mut:
	frame_count_               u32
	loop_count_                u32
	width_                     int
	height_                    int
	color_space_               dom.DecodedImageColorSpace
	durations_                 []u32
	buffer_slots               []AnimatedBitmapSlot
	last_displayed_frame       ?&dom.DecodedImageFrame_
	write_generation           u64
	request_in_flight          bool
	current_frame_index        u32
	last_requested_start_frame u32
	highest_requested_frame    u32
	request_frames             ?AnimationFrameRequestCallback
	stop_animation_decode      ?AnimationStopCallback
	animation_timer            &platform.Timer = unsafe { nil }
	clients                    map[u64]DecodedImageClientUpdateCallback
	is_cors_cross_origin_      bool
	loops_completed_           u32
	document_                  ?&dom.Document
	document_observer          ?&dom.DocumentObserver
}

__global (
	html_animated_image_sessions                    map[i64]&AnimatedDecodedImageData
	html_animated_frame_delivery_callback_installed bool
)

pub fn AnimatedDecodedImageData.session_registry() map[i64]&AnimatedDecodedImageData {
	return html_animated_image_sessions.clone()
}

pub fn AnimatedDecodedImageData.install_frame_delivery_callback() {
	if html_animated_frame_delivery_callback_installed {
		return
	}
	html_animated_frame_delivery_callback_installed = true
}

pub fn AnimatedDecodedImageData.create(session_id i64, frame_count u32, loop_count u32, width int, height int, color_space dom.DecodedImageColorSpace, durations []u32, initial_bitmaps []&dom.Bitmap_, request_frames ?AnimationFrameRequestCallback, stop_animation_decode ?AnimationStopCallback) &AnimatedDecodedImageData {
	mut timer := platform.Timer.create_repeating(0, fn () {})
	mut data := &AnimatedDecodedImageData{
		session_id:            session_id
		frame_count_:          frame_count
		loop_count_:           loop_count
		width_:                width
		height_:               height
		color_space_:          color_space
		durations_:            durations.clone()
		buffer_slots:          []AnimatedBitmapSlot{len: animated_decoded_image_buffer_pool_size}
		request_frames:        request_frames
		stop_animation_decode: stop_animation_decode
		animation_timer:       timer
		clients:               map[u64]DecodedImageClientUpdateCallback{}
	}
	timer.on_timeout = fn [data] () {
		mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
		mutable_data.advance_animation()
	}
	for index, bitmap in initial_bitmaps {
		slot_index := index % animated_decoded_image_buffer_pool_size
		data.write_generation++
		data.buffer_slots[slot_index] = AnimatedBitmapSlot{
			frame_index: u32(index)
			frame:       dom.DecodedImageFrame_.create_with_color_space(bitmap, color_space)
			generation:  data.write_generation
		}
	}
	data.highest_requested_frame = u32(initial_bitmaps.len)
	if initial_bitmaps.len != 0 {
		data.last_displayed_frame = data.buffer_slots[0].frame
	}
	AnimatedDecodedImageData.install_frame_delivery_callback()
	persistent := platform.enter_persistent()
	html_animated_image_sessions[session_id] = data
	platform.leave_persistent(persistent)
	mut owner := platform.current_retained_arena()
	if owner != unsafe { nil } {
		owner.add_cleanup(fn [data] () {
			if live := html_animated_image_sessions[data.session_id] {
				if voidptr(live) == voidptr(data) {
					mut retiring := unsafe { &AnimatedDecodedImageData(data) }
					retiring.finalize()
				}
			}
		})
	}
	return data
}

pub fn (mut data AnimatedDecodedImageData) finalize() {
	data.animation_timer.stop()
	if mut observer := data.document_observer {
		observer.finalize()
	}
	html_animated_image_sessions.delete(data.session_id)
	if stop := data.stop_animation_decode {
		stop(data.session_id)
	}
}

pub fn (data &AnimatedDecodedImageData) debug_state() AnimatedImageDebugState {
	return AnimatedImageDebugState{
		timer_active:    data.animation_timer.is_active()
		session_id:      data.session_id
		frame_index:     data.current_frame_index
		frame_count:     data.frame_count_
		loops_completed: data.loops_completed_
		loop_count:      data.loop_count_
		client_count:    usize(data.clients.len)
	}
}

pub fn (data &AnimatedDecodedImageData) external_memory_size() usize {
	mut size := usize(data.durations_.len) * usize(sizeof(u32))
	for slot in data.buffer_slots {
		frame := slot.frame or { continue }
		frame_size := usize(frame.bitmap().data.len)
		if usize(-1) - size < frame_size {
			return usize(-1)
		}
		size += frame_size
	}
	return size
}

pub fn (data &AnimatedDecodedImageData) has_clients() bool {
	return data.clients.len != 0
}

pub fn (data &AnimatedDecodedImageData) is_cors_cross_origin() bool {
	return data.is_cors_cross_origin_
}

pub fn (data &AnimatedDecodedImageData) set_is_cors_cross_origin(value bool) {
	mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
	mutable_data.is_cors_cross_origin_ = value
}

pub fn decoded_image_animation_state(data DecodedImageData) ?AnimatedImageDebugState {
	if data is AnimatedDecodedImageData {
		return data.debug_state()
	}
	return none
}

pub fn (data &AnimatedDecodedImageData) register_client(client_id u64, callback DecodedImageClientUpdateCallback) {
	mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
	was_empty := mutable_data.clients.len == 0
	mutable_data.clients[client_id] = callback
	if was_empty {
		mutable_data.start_animation_if_needed()
	}
}

pub fn (data &AnimatedDecodedImageData) unregister_client(client_id u64) {
	mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
	mutable_data.clients.delete(client_id)
}

pub fn decoded_image_data_register_client(data DecodedImageData, client_id u64, callback DecodedImageClientUpdateCallback) {
	if data is BitmapDecodedImageData {
		data.register_client(client_id, callback)
	} else if data is AnimatedDecodedImageData {
		data.register_client(client_id, callback)
	} else if data is SVGDecodedImageData {
		data.register_client(client_id, callback)
	}
}

pub fn decoded_image_data_unregister_client(data DecodedImageData, client_id u64) {
	if data is BitmapDecodedImageData {
		data.unregister_client(client_id)
	} else if data is AnimatedDecodedImageData {
		data.unregister_client(client_id)
	} else if data is SVGDecodedImageData {
		data.unregister_client(client_id)
	}
}

pub fn decoded_image_data_restart_animation(data DecodedImageData) {
	if data is AnimatedDecodedImageData {
		mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
		mutable_data.restart_animation()
	}
}

pub fn decoded_image_data_current_frame_index(data DecodedImageData) usize {
	if data is AnimatedDecodedImageData {
		return usize(data.current_frame_index)
	}
	return 0
}

pub fn decoded_image_data_advance_animation(data DecodedImageData) bool {
	if data is AnimatedDecodedImageData {
		mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
		mutable_data.advance_animation()
		return true
	}
	return false
}

pub fn (data &AnimatedDecodedImageData) observe_document(document &dom.Document) {
	mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
	if mutable_data.document_ != none {
		return
	}
	mut document_pointer := unsafe { &dom.Document(document) }
	mut observer := dom.DocumentObserver.create(mut document_pointer)
	observer.set_document_became_inactive(fn [data] () {
		mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
		mutable_data.stop_animation()
	})
	observer.set_document_became_active(fn [data] () {
		mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
		mutable_data.restart_animation()
	})
	observer.set_document_visibility_state_observer(fn [data] (state dom.VisibilityState) {
		mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
		if state == .hidden {
			mutable_data.stop_animation()
		} else {
			mutable_data.restart_animation()
		}
	})
	mutable_data.document_ = document
	mutable_data.document_observer = observer
}

fn (data &AnimatedDecodedImageData) may_animate() bool {
	if document := data.document_ {
		return document.is_fully_active() && !document.hidden()
	}
	return true
}

fn (mut data AnimatedDecodedImageData) start_animation_if_needed() {
	if data.clients.len == 0 || !data.may_animate() || data.frame_count_ <= 1 {
		return
	}
	data.animation_timer.start_with_interval(data.frame_duration(0))
}

fn (mut data AnimatedDecodedImageData) stop_animation() {
	data.animation_timer.stop()
}

pub fn (mut data AnimatedDecodedImageData) restart_animation() {
	data.stop_animation()
	data.current_frame_index = 0
	data.loops_completed_ = 0
	data.maybe_request_more_frames(data.current_frame_index)
	data.notify_clients_did_update()
	data.start_animation_if_needed()
}

fn (data &AnimatedDecodedImageData) animation_has_completed() bool {
	return data.loop_count_ > 0 && data.loops_completed_ == data.loop_count_
}

fn (data &AnimatedDecodedImageData) notify_clients_did_update() {
	for _, callback in data.clients {
		callback()
	}
}

pub fn (mut data AnimatedDecodedImageData) advance_animation() {
	if data.frame_count_ <= 1 || data.animation_has_completed() {
		data.stop_animation()
		return
	}
	data.current_frame_index = (data.current_frame_index + 1) % data.frame_count_
	data.maybe_request_more_frames(data.current_frame_index)
	current_duration := data.frame_duration(data.current_frame_index)
	if current_duration != data.animation_timer.interval() {
		data.animation_timer.restart_with_interval(current_duration)
	}
	if data.current_frame_index == data.frame_count_ - 1 {
		data.loops_completed_++
		if data.animation_has_completed() {
			data.stop_animation()
		}
	}
	data.notify_clients_did_update()
}

fn (data &AnimatedDecodedImageData) find_slot_index(frame_index u32) ?int {
	for index, slot in data.buffer_slots {
		if stored_frame_index := slot.frame_index {
			if stored_frame_index == frame_index && slot.frame != none {
				return index
			}
		}
	}
	return none
}

pub fn (data &AnimatedDecodedImageData) find_slot(frame_index u32) ?&AnimatedBitmapSlot {
	index := data.find_slot_index(frame_index) or { return none }
	return &data.buffer_slots[index]
}

fn (data &AnimatedDecodedImageData) oldest_slot_index() int {
	mut oldest := 0
	for index, slot in data.buffer_slots {
		if slot.generation < data.buffer_slots[oldest].generation {
			oldest = index
		}
	}
	return oldest
}

pub fn (mut data AnimatedDecodedImageData) evict_oldest_slot() &AnimatedBitmapSlot {
	index := data.oldest_slot_index()
	return &data.buffer_slots[index]
}

pub fn (data &AnimatedDecodedImageData) frame(frame_index usize) ?&dom.DecodedImageFrame_ {
	mut mutable_data := unsafe { &AnimatedDecodedImageData(data) }
	if frame_index >= usize(data.frame_count_) {
		return data.last_displayed_frame
	}
	if slot_index := data.find_slot_index(u32(frame_index)) {
		frame := data.buffer_slots[slot_index].frame
		mutable_data.last_displayed_frame = frame
		return frame
	}
	return data.last_displayed_frame
}

pub fn (data &AnimatedDecodedImageData) frame_duration(frame_index usize) int {
	if frame_index >= usize(data.durations_.len) {
		return 0
	}
	return int(data.durations_[frame_index])
}

pub fn (data &AnimatedDecodedImageData) frame_count() usize {
	return usize(data.frame_count_)
}

pub fn (data &AnimatedDecodedImageData) loop_count() usize {
	return usize(data.loop_count_)
}

pub fn (_ &AnimatedDecodedImageData) is_animated() bool {
	return true
}

pub fn (data &AnimatedDecodedImageData) intrinsic_width() ?f64 {
	return f64(data.width_)
}

pub fn (data &AnimatedDecodedImageData) intrinsic_height() ?f64 {
	return f64(data.height_)
}

pub fn (data &AnimatedDecodedImageData) intrinsic_aspect_ratio() ?f64 {
	if data.height_ == 0 {
		return none
	}
	return f64(data.width_) / f64(data.height_)
}

pub fn (data &AnimatedDecodedImageData) frame_rect(_ usize) ?BitmapRect {
	return BitmapRect{
		width:  data.width_
		height: data.height_
	}
}

pub fn (data &AnimatedDecodedImageData) paint(mut recorder painting.DisplayListRecorder, frame_index usize, destination painting.IntRect, clip_rect painting.IntRect, scaling_mode painting.ScalingMode) bool {
	frame := data.frame(frame_index) or { return false }
	return recorder.draw_scaled_decoded_image_frame(painting.DrawScaledDecodedImageFrame{
		destination: destination
		clip_rect:   clip_rect
		frame:       frame
		scaling:     scaling_mode
	})
}

pub fn (mut data AnimatedDecodedImageData) receive_frames(bitmaps []&dom.Bitmap_, start_frame_index u32) {
	data.request_in_flight = false
	for offset, bitmap in bitmaps {
		frame_index := start_frame_index + u32(offset)
		if frame_index >= data.frame_count_ {
			break
		}
		if data.find_slot_index(frame_index) != none {
			continue
		}
		slot_index := data.oldest_slot_index()
		data.write_generation++
		data.buffer_slots[slot_index] = AnimatedBitmapSlot{
			frame_index: frame_index
			frame:       dom.DecodedImageFrame_.create_with_color_space(bitmap, data.color_space_)
			generation:  data.write_generation
		}
	}
}

pub fn animated_decoded_image_deliver_frames_for_session(session_id i64, bitmaps []&dom.Bitmap_) {
	AnimatedDecodedImageData.deliver_frames_for_session(session_id, bitmaps)
}

pub fn AnimatedDecodedImageData.deliver_frames_for_session(session_id i64, bitmaps []&dom.Bitmap_) {
	if data := html_animated_image_sessions[session_id] {
		mut mutable_data := data
		mutable_data.receive_frames(bitmaps, data.last_requested_start_frame)
	}
}

fn (mut data AnimatedDecodedImageData) maybe_request_more_frames(current_frame_index u32) {
	if data.request_in_flight || data.frame_count_ == 0 {
		return
	}
	mut frames_ahead := u32(0)
	for offset := u32(1); offset <= animated_decoded_image_buffer_pool_size; offset++ {
		future_index := (current_frame_index + offset) % data.frame_count_
		if data.find_slot_index(future_index) != none {
			frames_ahead++
		} else {
			break
		}
	}
	if frames_ahead >= animated_decoded_image_request_batch_size {
		return
	}
	request_start := (current_frame_index + frames_ahead + 1) % data.frame_count_
	data.request_in_flight = true
	data.last_requested_start_frame = request_start
	requested_end := request_start + animated_decoded_image_request_batch_size
	if requested_end > data.highest_requested_frame {
		data.highest_requested_frame = requested_end
	}
	if request := data.request_frames {
		request(data.session_id, request_start, animated_decoded_image_request_batch_size)
	}
}

pub fn (mut data AnimatedDecodedImageData) notify_frame_advanced(caller_frame_index usize) usize {
	if data.frame_count_ == 0 {
		return 0
	}
	expected_next := (data.current_frame_index + 1) % data.frame_count_
	if u32(caller_frame_index) == expected_next {
		data.current_frame_index = expected_next
		data.maybe_request_more_frames(expected_next)
	}
	return usize(data.current_frame_index)
}
