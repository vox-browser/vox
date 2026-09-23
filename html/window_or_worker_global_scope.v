// Copyright (c) 2023, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023, Luke Wilde <lukew@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WindowOrWorkerGlobalScopeMixin.{h,cpp}. Host services which belong
// to Fetch, WebSockets, or LibJS are represented by explicit callbacks.
module html

import dom
import fetch
import time

pub type TimerScriptEvaluator = fn (string) !

pub struct TimerHandler {
pub:
	callback ?&dom.CallbackType
	source   ?string
}

pub fn timer_callback_handler(callback &dom.CallbackType) TimerHandler {
	return TimerHandler{
		callback: callback
	}
}

pub fn timer_source_handler(source string) TimerHandler {
	return TimerHandler{
		source: source
	}
}

enum TimerThrottlingClass {
	immediate
	delayed
}

struct GlobalScopeTimer {
mut:
	id               i32
	handler          TimerHandler
	timeout_ms       i64
	deadline_ms      i64
	due_time_ms      i64
	arguments        []dom.JSValue
	repeat           bool
	nesting_level    u32
	throttling_class TimerThrottlingClass = .delayed
}

pub struct PerformanceEntry {
pub:
	name       string
	entry_type string
	start_time f64
	duration   f64
}

pub struct PerformanceEntryTuple {
pub mut:
	performance_entry_buffer []PerformanceEntry
	max_buffer_size          usize
}

pub type PerformanceObserverCallback = fn([]PerformanceEntry)

@[heap]
pub struct PerformanceObserverRecord {
pub:
	callback    PerformanceObserverCallback @[required]
	entry_types []string
mut:
	queued_entries []PerformanceEntry
}

pub struct GlobalScopeWebSocket {
pub:
	make_disappear ?fn() bool
}

@[heap]
pub struct GlobalScopePerformance {
	dom.EventTarget
}

@[heap]
pub struct GlobalScopeIndexedDBFactory {}

@[heap]
pub struct GlobalScopeCrypto {}

@[heap]
pub struct GlobalScopeCacheStorage {}

@[heap]
pub struct GlobalScopeTrustedTypePolicyFactory {}

pub struct ImageBitmapSource {
pub:
	bitmap           ?&dom.Bitmap_
	image_bitmap     ?&ImageBitmap
	image_data       ?&ImageData
	offscreen_canvas ?&OffscreenCanvas
}

@[heap]
pub struct WindowOrWorkerGlobalScopeMixin {
	dom.EventTarget
mut:
	origin_                         dom.Origin
	secure_context_                 bool
	cross_origin_isolated_          bool
	next_timer_id_                  i32 = 1
	active_timers_                  map[i32]GlobalScopeTimer
	currently_running_timer_nesting u32
	timer_script_evaluator_         ?TimerScriptEvaluator
	performance_entry_buffer_map_   map[string]&PerformanceEntryTuple
	registered_observers_           []&PerformanceObserverRecord
	observer_task_queued_           bool
	resource_timing_buffer_limit_   u32 = 250
	resource_timing_secondary_      []PerformanceEntry
	resource_timing_full_pending_   bool
	registered_event_sources_       []&EventSource
	registered_web_sockets_         []&GlobalScopeWebSocket
	reported_errors_                []dom.JSValue
	error_reporting_mode_           bool
	performance_                    ?&GlobalScopePerformance
	indexed_db_                     ?&GlobalScopeIndexedDBFactory
	crypto_                         ?&GlobalScopeCrypto
	caches_                         ?&GlobalScopeCacheStorage
	trusted_types_                  ?&GlobalScopeTrustedTypePolicyFactory
	fetch_host_                     voidptr
	associated_window_              ?&WindowModel
	hidden_timer_wake_up_interval_  i64 = 1_000
}

pub fn WindowOrWorkerGlobalScopeMixin.create(origin dom.Origin, secure_context bool, cross_origin_isolated bool) &WindowOrWorkerGlobalScopeMixin {
	return &WindowOrWorkerGlobalScopeMixin{
		origin_: origin
		secure_context_: secure_context
		cross_origin_isolated_: cross_origin_isolated
	}
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) origin() string {
	return scope.origin_.serialize()
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) is_secure_context() bool {
	return scope.secure_context_
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) cross_origin_isolated() bool {
	return scope.cross_origin_isolated_
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_resource_timing_buffer_size_limit(limit u32) {
	scope.resource_timing_buffer_limit_ = limit
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) window_or_worker_global_scope_extract_an_origin() ?dom.Origin {
	if scope.origin_.is_opaque() {
		return none
	}
	return scope.origin_
}

fn global_scope_now_ms() i64 {
	return time.sys_mono_now() / 1_000_000
}

fn timer_saturating_add(base i64, delay i64) i64 {
	if delay > 0 && base > max_i64 - delay {
		return max_i64
	}
	return base + delay
}

fn timer_wake_up_at_or_after(time_ms i64, origin_ms i64, interval_ms i64) i64 {
	if time_ms <= origin_ms {
		return origin_ms
	}
	delta := time_ms - origin_ms
	whole_intervals := (delta - 1) / interval_ms + 1
	if whole_intervals > (max_i64 - origin_ms) / interval_ms {
		return max_i64
	}
	return origin_ms + whole_intervals * interval_ms
}

fn (scope &WindowOrWorkerGlobalScopeMixin) document_is_hidden() bool {
	window := scope.associated_window_ or { return false }
	document := window.associated_document()
	return document.is_fully_active() && document.hidden()
}

fn (scope &WindowOrWorkerGlobalScopeMixin) hidden_timer_grid_origin_ms() i64 {
	mut window := scope.associated_window_ or { return 0 }
	mut context := window.browsing_context()
	for {
		parent := context.parent() or { break }
		if parent_window := parent.active_window() {
			window = parent_window
		}
		context = parent
	}
	if window.environment_settings_ == unsafe { nil } {
		return 0
	}
	return i64(window.environment_settings_.time_origin())
}

fn (scope &WindowOrWorkerGlobalScopeMixin) timer_due_time(throttling_class TimerThrottlingClass, deadline_ms i64, now_ms i64) i64 {
	if throttling_class == .immediate || !scope.document_is_hidden() {
		return deadline_ms
	}
	due := if deadline_ms > now_ms { deadline_ms } else { now_ms }
	return timer_wake_up_at_or_after(due, scope.hidden_timer_grid_origin_ms(), scope.hidden_timer_wake_up_interval_)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_hidden_document_timer_wake_up_interval(milliseconds i64) {
	assert milliseconds > 0
	scope.hidden_timer_wake_up_interval_ = milliseconds
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) document_visibility_state_changed() {
	now_ms := global_scope_now_ms()
	for id, timer in scope.active_timers_ {
		mut realigned := timer
		realigned.due_time_ms = scope.timer_due_time(timer.throttling_class, timer.deadline_ms, now_ms)
		scope.active_timers_[id] = realigned
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timer_script_evaluator(evaluator ?TimerScriptEvaluator) {
	scope.timer_script_evaluator_ = evaluator
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_fetch_host(host ?&fetch.FetchHost) {
	if value := host {
		scope.fetch_host_ = voidptr(value)
	} else {
		unsafe {
			scope.fetch_host_ = nil
		}
	}
}

fn (mut scope WindowOrWorkerGlobalScopeMixin) run_timer_initialization_steps(handler TimerHandler, timeout i32, arguments []dom.JSValue, repeat bool, previous_id ?i32) i32 {
	id := previous_id or {
		new_id := scope.next_timer_id_
		scope.next_timer_id_++
		new_id
	}

	mut normalized_timeout := i64(if timeout < 0 { 0 } else { timeout })
	nesting := scope.currently_running_timer_nesting + 1
	if nesting > 5 && normalized_timeout < 4 {
		normalized_timeout = 4
	}
	now_ms := global_scope_now_ms()
	deadline_ms := timer_saturating_add(now_ms, normalized_timeout)
	throttling_class := if normalized_timeout == 0 {
		TimerThrottlingClass.immediate
	} else {
		TimerThrottlingClass.delayed
	}
	scope.active_timers_[id] = GlobalScopeTimer{
		id: id
		handler: handler
		timeout_ms: normalized_timeout
		deadline_ms: deadline_ms
		due_time_ms: scope.timer_due_time(throttling_class, deadline_ms, now_ms)
		arguments: arguments.clone()
		repeat: repeat
		nesting_level: nesting
		throttling_class: throttling_class
	}
	return id
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timeout(handler TimerHandler, timeout i32, arguments []dom.JSValue) i32 {
	return scope.run_timer_initialization_steps(handler, timeout, arguments, false, none)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_interval(handler TimerHandler, timeout i32, arguments []dom.JSValue) i32 {
	return scope.run_timer_initialization_steps(handler, timeout, arguments, true, none)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_timeout(id i32) {
	scope.active_timers_.delete(id)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_interval(id i32) {
	scope.clear_timeout(id)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_map_of_active_timers() {
	scope.active_timers_.clear()
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) active_timer_count() int {
	return scope.active_timers_.len
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) process_timers(now_ms i64) {
	mut due_ids := []int{}
	for id, timer in scope.active_timers_ {
		if timer.due_time_ms <= now_ms {
			due_ids << int(id)
		}
	}
	due_ids.sort()
	for raw_id in due_ids {
		id := i32(raw_id)
		timer := scope.active_timers_[id] or { continue }
		if !timer.repeat {
			scope.active_timers_.delete(id)
		}
		scope.currently_running_timer_nesting = timer.nesting_level
		if callback := timer.handler.callback {
			if call := callback.call_with_arguments {
				_ = call(timer.arguments)
			}
		} else if source := timer.handler.source {
			if evaluator := scope.timer_script_evaluator_ {
				evaluator(source) or { scope.report_error(dom.js_string(err.msg())) }
			}
		}
		scope.currently_running_timer_nesting = 0
		if timer.repeat && id in scope.active_timers_ {
			mut repeated := scope.active_timers_[id] or { continue }
			repeated.deadline_ms = timer_saturating_add(now_ms, timer.timeout_ms)
			repeated.due_time_ms = scope.timer_due_time(timer.throttling_class, repeated.deadline_ms, now_ms)
			scope.active_timers_[id] = repeated
		}
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) run_all_timers() {
	scope.process_timers(max_i64)
}

fn image_bitmap_source_bitmap(source ImageBitmapSource) !&dom.Bitmap_ {
	if bitmap := source.bitmap {
		return bitmap
	}
	if image_bitmap := source.image_bitmap {
		if image_bitmap.is_detached() {
			return error('InvalidStateError: ImageBitmap is detached')
		}
		return image_bitmap.bitmap() or { error('InvalidStateError: ImageBitmap has no bitmap') }
	}
	if image_data := source.image_data {
		bitmap := image_data.bitmap()
		return &dom.Bitmap_{
			width: int(bitmap.width)
			height: int(bitmap.height)
			pitch: int(bitmap.width) * 4
			data: bitmap.data.clone()
		}
	}
	if canvas := source.offscreen_canvas {
		return canvas.bitmap() or { error('InvalidStateError: OffscreenCanvas has no bitmap') }
	}
	return error('InvalidStateError: image source has no image data')
}

fn create_image_bitmap_pixels(source &dom.Bitmap_, sx i32, sy i32, sw i32, sh i32, options ImageBitmapOptions) !&dom.Bitmap_ {
	if sw == 0 || sh == 0 {
		return error('RangeError: source rectangle width and height must be nonzero')
	}
	left := if sw < 0 { sx + sw } else { sx }
	top := if sh < 0 { sy + sh } else { sy }
	source_width := if sw < 0 { -sw } else { sw }
	source_height := if sh < 0 { -sh } else { sh }
	resize_width := options.resize_width or {
		if height := options.resize_height {
			u32((u64(source_width) * u64(height) + u64(source_height) - 1) / u64(source_height))
		} else {
			u32(source_width)
		}
	}

	resize_height := options.resize_height or {
		if width := options.resize_width {
			u32((u64(source_height) * u64(width) + u64(source_width) - 1) / u64(source_width))
		} else {
			u32(source_height)
		}
	}

	if resize_width == 0 || resize_height == 0 {
		return error('InvalidStateError: resize dimensions must be nonzero')
	}
	byte_length := u64(resize_width) * u64(resize_height) * 4
	if byte_length > u64(max_int) {
		return error('InvalidStateError: resulting bitmap is too large')
	}
	mut output := []u8{len: int(byte_length)}
	for destination_y in 0 .. int(resize_height) {
		mut source_y := top + (destination_y * source_height) / int(resize_height)
		if options.image_orientation == .flip_y {
			source_y = top + source_height - 1 - (destination_y * source_height) / int(resize_height)
		}
		for destination_x in 0 .. int(resize_width) {
			source_x := left + (destination_x * source_width) / int(resize_width)
			if source_x < 0 || source_y < 0 || source_x >= source.width || source_y >= source.height {
				continue
			}
			source_offset := source_y * source.pitch + source_x * 4
			destination_offset := (destination_y * int(resize_width) + destination_x) * 4
			if source_offset + 4 <= source.data.len {
				for channel in 0 .. 4 {
					output[destination_offset + channel] = source.data[source_offset + channel]
				}
			}
		}
	}
	return &dom.Bitmap_{
		width: int(resize_width)
		height: int(resize_height)
		pitch: int(resize_width) * 4
		format: source.format
		alpha_type: source.alpha_type
		data: output
	}
}

fn crop_to_the_source_rectangle_with_formatting(input &dom.Bitmap_, sx ?i32, sy ?i32, sw ?i32, sh ?i32, options ?ImageBitmapOptions) !&dom.Bitmap_ {
	return create_image_bitmap_pixels(input, sx or { 0 }, sy or { 0 }, sw or { i32(input.width) }, sh or { i32(input.height) }, options or { ImageBitmapOptions{} })
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) create_image_bitmap(source ImageBitmapSource, options ImageBitmapOptions) !&ImageBitmap {
	return scope.create_image_bitmap_impl(source, none, none, none, none, options)
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) create_image_bitmap_with_crop(source ImageBitmapSource, sx i32, sy i32, sw i32, sh i32, options ImageBitmapOptions) !&ImageBitmap {
	return scope.create_image_bitmap_impl(source, sx, sy, sw, sh, options)
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) create_image_bitmap_impl(source ImageBitmapSource, sx ?i32, sy ?i32, sw ?i32, sh ?i32, options ImageBitmapOptions) !&ImageBitmap {
	_ = scope
	bitmap := image_bitmap_source_bitmap(source)!
	left := sx or { 0 }
	top := sy or { 0 }
	width := sw or { i32(bitmap.width) }
	height := sh or { i32(bitmap.height) }
	result_bitmap := crop_to_the_source_rectangle_with_formatting(bitmap, left, top, width, height, options)!
	mut result := ImageBitmap.create()
	result.set_bitmap(result_bitmap)
	return result
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) fetch(input fetch.RequestInput, init fetch.RequestInit) !&fetch.ResponseObject {
	if scope.fetch_host_ == unsafe { nil } {
		return error('NetworkError: no Fetch host is installed')
	}
	host := unsafe { &fetch.FetchHost(scope.fetch_host_) }
	return fetch.fetch_request(input, init, host)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) relevant_performance_entry_tuple(entry_type string) &PerformanceEntryTuple {
	if entry_type !in scope.performance_entry_buffer_map_ {
		scope.performance_entry_buffer_map_[entry_type] = &PerformanceEntryTuple{}
	}
	return scope.performance_entry_buffer_map_[entry_type] or { &PerformanceEntryTuple{} }
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) queue_performance_entry(entry PerformanceEntry) {
	for observer in scope.registered_observers_ {
		if entry.entry_type in observer.entry_types {
			mut mutable_observer := unsafe { &PerformanceObserverRecord(observer) }
			mutable_observer.queued_entries << entry
		}
	}
	scope.queue_the_performance_observer_task()
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) add_performance_entry(entry PerformanceEntry) {
	mut tuple := scope.relevant_performance_entry_tuple(entry.entry_type)
	if tuple.max_buffer_size == 0 || tuple.performance_entry_buffer.len < tuple.max_buffer_size {
		tuple.performance_entry_buffer << entry
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) process_performance_observers() {
	if !scope.observer_task_queued_ {
		return
	}
	scope.observer_task_queued_ = false
	for observer in scope.registered_observers_ {
		mut mutable_observer := unsafe { &PerformanceObserverRecord(observer) }
		if observer.queued_entries.len > 0 {
			entries := observer.queued_entries.clone()
			mutable_observer.queued_entries.clear()
			observer.callback(entries)
		}
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) register_performance_observer(observer &PerformanceObserverRecord) {
	if observer !in scope.registered_observers_ {
		scope.registered_observers_ << observer
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) unregister_performance_observer(observer &PerformanceObserverRecord) {
	scope.registered_observers_ = scope.registered_observers_.filter(it != observer)
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) has_registered_performance_observer(observer &PerformanceObserverRecord) bool {
	return observer in scope.registered_observers_
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) queue_the_performance_observer_task() {
	if scope.observer_task_queued_ {
		return
	}
	scope.observer_task_queued_ = true
	queue_a_task(.performance_timeline, main_thread_event_loop(), none, fn [mut scope] () {
		scope.process_performance_observers()
	})
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) filter_buffer_map_by_name_and_type(name ?string, type_ ?string) []PerformanceEntry {
	mut entries := []PerformanceEntry{}
	for entry_type, tuple in scope.performance_entry_buffer_map_ {
		if requested_type := type_ {
			if entry_type != requested_type {
				continue
			}
		}
		for entry in tuple.performance_entry_buffer {
			if requested_name := name {
				if entry.name != requested_name {
					continue
				}
			}
			entries << entry
		}
	}
	entries.sort_with_compare(fn (left &PerformanceEntry, right &PerformanceEntry) int {
		return if left.start_time < right.start_time {
			-1
		} else if left.start_time > right.start_time {
			1
		} else {
			0
		}
	})
	return entries
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_performance_entry_buffer(entry_type string) {
	scope.performance_entry_buffer_map_.delete(entry_type)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) remove_entries_from_performance_entry_buffer(entry_type string, entry_name string) {
	mut tuple := scope.performance_entry_buffer_map_[entry_type] or { return }
	tuple.performance_entry_buffer = tuple.performance_entry_buffer.filter(it.name != entry_name)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) add_resource_timing_entry(entry PerformanceEntry) {
	if scope.can_add_resource_timing_entry() && !scope.resource_timing_full_pending_ {
		scope.add_performance_entry(entry)
		return
	}
	if !scope.resource_timing_full_pending_ {
		scope.resource_timing_full_pending_ = true
		queue_a_task(.performance_timeline, main_thread_event_loop(), none, fn [mut scope] () {
			scope.fire_resource_timing_buffer_full_event()
		})
	}
	scope.resource_timing_secondary_ << entry
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) can_add_resource_timing_entry() bool {
	return scope.resource_timing_buffer_current_size() < usize(scope.resource_timing_buffer_limit_)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) resource_timing_buffer_current_size() usize {
	tuple := scope.relevant_performance_entry_tuple('resource')
	return usize(tuple.performance_entry_buffer.len)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) fire_resource_timing_buffer_full_event() {
	for scope.resource_timing_secondary_.len > 0 {
		before := scope.resource_timing_secondary_.len
		if !scope.can_add_resource_timing_entry() {
			event := dom.Event.create('resourcetimingbufferfull', dom.EventInit{})
			unsafe { &dom.EventTarget(scope.performance()) }
			.dispatch_event(event)
		}
		scope.copy_resource_timing_secondary_buffer()
		if before <= scope.resource_timing_secondary_.len {
			scope.resource_timing_secondary_.clear()
			break
		}
	}
	scope.resource_timing_full_pending_ = false
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) copy_resource_timing_secondary_buffer() {
	mut tuple := scope.relevant_performance_entry_tuple('resource')
	for scope.resource_timing_secondary_.len > 0 && scope.can_add_resource_timing_entry() {
		entry := scope.resource_timing_secondary_[0]
		scope.resource_timing_secondary_.delete(0)
		tuple.performance_entry_buffer << entry
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) register_event_source(source &EventSource) {
	if source !in scope.registered_event_sources_ {
		scope.registered_event_sources_ << source
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) unregister_event_source(source &EventSource) {
	scope.registered_event_sources_ = scope.registered_event_sources_.filter(it != source)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) forcibly_close_all_event_sources() {
	for source in scope.registered_event_sources_ {
		mut mutable_source := unsafe { &EventSource(source) }
		mutable_source.forcibly_close()
	}
	scope.registered_event_sources_.clear()
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) register_web_socket(socket &GlobalScopeWebSocket) {
	if socket !in scope.registered_web_sockets_ {
		scope.registered_web_sockets_ << socket
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) unregister_web_socket(socket &GlobalScopeWebSocket) {
	scope.registered_web_sockets_ = scope.registered_web_sockets_.filter(it != socket)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) make_disappear_all_web_sockets() bool {
	mut affected := false
	for socket in scope.registered_web_sockets_ {
		if callback := socket.make_disappear {
			affected = callback() || affected
		}
	}
	return affected
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) run_steps_after_a_timeout(timeout i32, completion_step fn()) i32 {
	return scope.run_steps_after_a_timeout_impl(timeout, completion_step, none, false)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) run_steps_after_a_timeout_impl(timeout i32, completion_step fn(), timer_key ?i32, repeat bool) i32 {
	id := timer_key or {
		new_id := scope.next_timer_id_
		scope.next_timer_id_++
		new_id
	}
	normalized_timeout := i64(if timeout < 0 { 0 } else { timeout })
	now_ms := global_scope_now_ms()
	deadline_ms := timer_saturating_add(now_ms, normalized_timeout)
	scope.active_timers_[id] = GlobalScopeTimer{
		id: id
		handler: timer_callback_handler(&dom.CallbackType{
			call_with_arguments: fn [completion_step] (_ []dom.JSValue) dom.JSValue {
				completion_step()
				return dom.js_undefined()
			}
		})
		timeout_ms: normalized_timeout
		deadline_ms: deadline_ms
		due_time_ms: scope.timer_due_time(.delayed, deadline_ms, now_ms)
		repeat: repeat
		throttling_class: .delayed
	}
	return id
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) report_error(error dom.JSValue) {
	scope.report_an_exception(error, false)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) report_an_exception(exception dom.JSValue, omit_error bool) {
	if scope.error_reporting_mode_ {
		return
	}
	scope.error_reporting_mode_ = true
	scope.reported_errors_ << exception
	if !omit_error {
		event := dom.Event.create('error', dom.EventInit{ cancelable: true })
		unsafe { &dom.EventTarget(scope) }
		.dispatch_event(event)
	}
	scope.error_reporting_mode_ = false
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) reported_errors() []dom.JSValue {
	return scope.reported_errors_.clone()
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) performance() &GlobalScopePerformance {
	if value := scope.performance_ {
		return value
	}
	value := &GlobalScopePerformance{
		EventTarget: dom.EventTarget{}
	}
	scope.performance_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) indexed_db() &GlobalScopeIndexedDBFactory {
	if value := scope.indexed_db_ {
		return value
	}
	value := &GlobalScopeIndexedDBFactory{}
	scope.indexed_db_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) crypto() &GlobalScopeCrypto {
	if value := scope.crypto_ {
		return value
	}
	value := &GlobalScopeCrypto{}
	scope.crypto_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) caches() &GlobalScopeCacheStorage {
	if value := scope.caches_ {
		return value
	}
	value := &GlobalScopeCacheStorage{}
	scope.caches_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) trusted_types() &GlobalScopeTrustedTypePolicyFactory {
	if value := scope.trusted_types_ {
		return value
	}
	value := &GlobalScopeTrustedTypePolicyFactory{}
	scope.trusted_types_ = value
	return value
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) supported_entry_types() []string {
	return ['element', 'event', 'first-input', 'largest-contentful-paint', 'layout-shift',
		'long-animation-frame', 'longtask', 'mark', 'measure', 'navigation', 'paint', 'resource',
		'taskattribution', 'visibility-state']
}
