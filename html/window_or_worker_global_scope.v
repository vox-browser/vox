// Copyright (c) 2023, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023, Luke Wilde <lukew@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WindowOrWorkerGlobalScopeMixin.{h,cpp}. Host services which belong
// to Fetch, WebSockets, or LibJS are represented by explicit callbacks.
module html

import dom
import fetch
import highresolutiontime
import performancetimeline
import platform
import indexeddb
import math
import serviceworker
import storageapi
import resourcetiming
import trustedtypes
import webcrypto
import webidl
import contentsecuritypolicy

pub type TimerScriptEvaluator = fn (string) !

pub struct TimerHandler {
pub:
	callback ?&dom.CallbackType
	callback_record ?webidl.CallbackType
	callback_this_value webidl.Value
	source   ?string
}

pub fn timer_webidl_callback_handler(callback webidl.CallbackType, receiver webidl.Value) TimerHandler {
	return TimerHandler{callback_record: callback, callback_this_value: receiver}
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

pub enum TimerThrottlingClass {
	immediate
	delayed
	chained
}

struct GlobalScopeTimer {
mut:
	id               i32
	handler          TimerHandler
	timeout_ms       i64
	deadline_ms      f64
	due_time_ms      f64
	arguments        []dom.JSValue
	repeat           bool
	nesting_level    u32
	throttling_class TimerThrottlingClass = .delayed
	clock_           ?&Timer
}

pub struct PerformanceEntry {
pub:
	name       string
	entry_type string
	start_time f64
	duration   f64
	native_entry ?&performancetimeline.PerformanceEntry
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
	highresolutiontime.Performance
mut:
	resource_handler_ ?highresolutiontime.ResourceTimingBufferFullHandler
}

@[heap]
pub struct GlobalScopeIndexedDBFactory {
	indexeddb.IDBFactory
}

@[heap]
pub struct GlobalScopeCrypto {
	implementation &webcrypto.Crypto @[required]
	subtle_ &webcrypto.SubtleCryptoBinding @[required]
}

@[heap]
pub struct GlobalScopeCacheStorage {
	serviceworker.CacheStorage
}

@[heap]
pub struct GlobalScopeTrustedTypePolicyFactory {
	trustedtypes.TrustedTypePolicyFactory
}

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
	manual_timer_clock_              ?f64
	timer_script_evaluator_         ?TimerScriptEvaluator
	timer_classic_script_evaluator_ ?ScriptEvaluationHook
	embedding_timer_compilation_exception_value_ ?fn (IError) webidl.Value
	embedding_timer_removed_        ?fn (i32)
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
	error_reporting_target_         ?&dom.EventTarget
	error_reporting_realm_          ?&ScriptingRealm
	dedicated_worker_               ?&DedicatedWorkerGlobalScope
	performance_                    ?&GlobalScopePerformance
	resource_timing_context_        ?&resourcetiming.ResourceTimingContext
	indexed_db_                     ?&GlobalScopeIndexedDBFactory
	crypto_                         ?&GlobalScopeCrypto
	queuing_strategy_size_functions_ &GlobalQueuingStrategySizeFunctions = unsafe { nil }
	caches_                         ?&GlobalScopeCacheStorage
	trusted_types_                  ?&GlobalScopeTrustedTypePolicyFactory
	fetch_host_                     voidptr
	associated_window_                         ?&WindowModel
	responsible_event_loop_                    ?&EventLoop
	hidden_timer_wake_up_interval_             i64 = 1_000
	intensive_timer_wake_up_interval_          i64 = 60_000
	intensive_timer_grace_loaded_ms_            i64 = 60_000
	intensive_timer_grace_loading_ms_           i64 = 300_000
	intensive_timer_grace_deadline_ms_          ?f64
	chained_timers_intensively_throttled_       bool
	last_chained_timer_wake_up_ms_              ?f64
	intensive_timer_grace_timer_                ?&platform.Timer
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

pub fn (scope &WindowOrWorkerGlobalScopeMixin) responsible_event_loop() &EventLoop {
	return scope.responsible_event_loop_ or { main_thread_event_loop() }
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

fn global_scope_now_ms() f64 {
	return highresolutiontime.unsafe_shared_current_time()
}

// process_timers() supplies this explicit clock adapter for deterministic
// embedders; production uses the same actual monotonic clock as native timers.
fn (scope &WindowOrWorkerGlobalScopeMixin) timer_now_ms() f64 {
	return scope.manual_timer_clock_ or { highresolutiontime.unsafe_shared_current_time() }
}

fn timer_wake_up_at_or_after(time_ms f64, origin_ms f64, interval_ms f64) f64 {
	return origin_ms + math.ceil((time_ms - origin_ms) / interval_ms) * interval_ms
}

fn (scope &WindowOrWorkerGlobalScopeMixin) document_is_hidden() bool {
	window := scope.associated_window_ or { return false }
	document := window.associated_document()
	return document.is_fully_active() && document.hidden()
}

fn (scope &WindowOrWorkerGlobalScopeMixin) timers_are_throttled() bool {
	window := scope.associated_window_ or { return false }
	return scope.document_is_hidden() && !window.associated_document().is_playing_audio()
}

fn (scope &WindowOrWorkerGlobalScopeMixin) hidden_timer_grid_origin_ms() f64 {
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
	return window.environment_settings_.time_origin()
}

fn (scope &WindowOrWorkerGlobalScopeMixin) timer_due_time(throttling_class TimerThrottlingClass, deadline_ms f64, now_ms f64) f64 {
	if throttling_class == .immediate || !scope.timers_are_throttled() {
		return deadline_ms
	}
	due := if deadline_ms > now_ms { deadline_ms } else { now_ms }
	origin := scope.hidden_timer_grid_origin_ms()
	mut wake_up := timer_wake_up_at_or_after(due, origin, f64(scope.hidden_timer_wake_up_interval_))
	if throttling_class == .chained && scope.chained_timers_intensively_throttled_ {
		intensive_wake_up := timer_wake_up_at_or_after(due, origin, f64(scope.intensive_timer_wake_up_interval_))
		ordinary_wake_up_from := if last_wake_up := scope.last_chained_timer_wake_up_ms_ {
			minimum := last_wake_up + f64(scope.intensive_timer_wake_up_interval_)
			if minimum > due { minimum } else { due }
		} else {
			due
		}
		exception_wake_up := timer_wake_up_at_or_after(ordinary_wake_up_from, origin, f64(scope.hidden_timer_wake_up_interval_))
		wake_up = if intensive_wake_up < exception_wake_up {
			intensive_wake_up
		} else {
			exception_wake_up
		}
	}
	return wake_up
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_hidden_document_timer_wake_up_interval(milliseconds i64) {
	assert milliseconds > 0
	scope.hidden_timer_wake_up_interval_ = milliseconds
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_hidden_document_intensive_timer_throttling(wake_up_interval i64, grace_period_once_loaded i64, grace_period_while_loading i64) {
	assert wake_up_interval > 0
	assert grace_period_once_loaded >= 0
	assert grace_period_while_loading >= 0
	scope.intensive_timer_wake_up_interval_ = wake_up_interval
	scope.intensive_timer_grace_loaded_ms_ = grace_period_once_loaded
	scope.intensive_timer_grace_loading_ms_ = grace_period_while_loading
}

fn (mut scope WindowOrWorkerGlobalScopeMixin) realign_timers(now_ms f64) {
	for id, timer in scope.active_timers_ {
		mut realigned := timer
		realigned.due_time_ms = scope.timer_due_time(timer.throttling_class, timer.deadline_ms, now_ms)
		if mut clock := timer.clock_ {
			// A fired one-shot has a task queued and is done with the clock.
			if clock.is_active() { clock.restart(timer_delay_from(realigned.due_time_ms - now_ms)) }
		}
		scope.active_timers_[id] = realigned
	}
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) document_visibility_state_changed() {
	now_ms := global_scope_now_ms()
	scope.chained_timers_intensively_throttled_ = false
	if scope.document_is_hidden() {
		window := scope.associated_window_ or { return }
		grace_period := if window.associated_document().readiness() == .complete {
			scope.intensive_timer_grace_loaded_ms_
		} else {
			scope.intensive_timer_grace_loading_ms_
		}
		scope.intensive_timer_grace_deadline_ms_ = now_ms + f64(grace_period)
		if scope.intensive_timer_grace_timer_ == none {
			owner_handle := voidptr(&scope)
			scope.intensive_timer_grace_timer_ = platform.Timer.create_single_shot(0, fn [owner_handle] () {
				mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
				owner.chained_timers_intensively_throttled_ = true
				owner.intensive_timer_grace_deadline_ms_ = none
				owner.realign_timers(owner.timer_now_ms())
			})
		}
		mut grace_timer := scope.intensive_timer_grace_timer_ or { panic('missing timer throttling grace clock') }
		grace_timer.restart_with_interval(int(timer_delay_from(f64(grace_period))))
	} else {
		scope.intensive_timer_grace_deadline_ms_ = none
		if mut grace_timer := scope.intensive_timer_grace_timer_ { grace_timer.stop() }
	}
	scope.realign_timers(now_ms)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) document_audio_play_state_changed() {
	scope.realign_timers(global_scope_now_ms())
}

fn (mut scope WindowOrWorkerGlobalScopeMixin) update_intensive_timer_throttling(now_ms f64) {
	grace_deadline := scope.intensive_timer_grace_deadline_ms_ or { return }
	if now_ms < grace_deadline || !scope.document_is_hidden() {
		return
	}
	scope.intensive_timer_grace_deadline_ms_ = none
	if mut grace_timer := scope.intensive_timer_grace_timer_ { grace_timer.stop() }
	scope.chained_timers_intensively_throttled_ = true
	scope.realign_timers(now_ms)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timer_script_evaluator(evaluator ?TimerScriptEvaluator) {
	scope.timer_script_evaluator_ = evaluator
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timer_classic_script_evaluator(evaluator ?ScriptEvaluationHook) {
	scope.timer_classic_script_evaluator_ = evaluator
}

// The compact engine projects the source realm's EvalError into its actual
// JavaScript object. The native CSP algorithm and its task ordering stay here.
pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timer_compilation_exception_value_converter(converter ?fn (IError) webidl.Value) {
	scope.embedding_timer_compilation_exception_value_ = converter
}

// Native engine roots have the same lifetime as the source timer handle,
// including cancellation outside the script-visible clearTimeout adapter.
pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timer_removed_handler(handler ?fn (i32)) {
	scope.embedding_timer_removed_ = handler
}

fn (mut scope WindowOrWorkerGlobalScopeMixin) remove_timer(id i32) {
	if id !in scope.active_timers_ { return }
	scope.active_timers_.delete(id)
	if handler := scope.embedding_timer_removed_ { handler(id) }
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
	current_nesting := if task := scope.responsible_event_loop().currently_running_task() {
		task.timer_nesting_level()
	} else {
		u32(0)
	}
	mut normalized_timeout := if timeout < 0 { i32(0) } else { timeout }
	if current_nesting > 5 && normalized_timeout < 4 { normalized_timeout = 4 }
	throttling_class := if current_nesting > 5 {
		TimerThrottlingClass.chained
	} else if normalized_timeout == 0 {
		TimerThrottlingClass.immediate
	} else {
		TimerThrottlingClass.delayed
	}
	owner_handle := voidptr(&scope)
	nesting_level := current_nesting + 1
	initiating_script := if realm := scope.error_reporting_realm_ { realm.active_classic_script_ } else { ?&ClassicScript(none) }
	task_steps := fn [owner_handle, handler, normalized_timeout, arguments, repeat, id, initiating_script] () {
		mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
		// The handle remains in the map after clock firing until the queued task
		// completes; clearTimeout cancels even a task already queued.
		if id !in owner.active_timers_ { return }
		if callback := handler.callback_record {
			mut values := []webidl.Value{cap: arguments.len}
			for argument in arguments {
				values << (argument.as_webidl_value() or { panic('timer argument requires its actual WebIDL value') })
			}
			_ = webidl.invoke_callback(callback, handler.callback_this_value, values) or {
				owner.report_an_exception(dom.js_webidl_value(webidl.exception_value(err)), false)
				webidl.undefined_value()
			}
		} else if callback := handler.callback {
			if call := callback.call_with_arguments { _ = call(arguments) }
		} else if source := handler.source {
			if evaluator := owner.timer_classic_script_evaluator_ {
				mut realm := owner.error_reporting_realm_ or { panic('timer classic script requires its relevant realm') }
				settings := settings_object_of_realm(realm) or { panic('timer classic script requires its relevant settings') }
				mut global := settings.fetch_request_client_csp_global()
				contentsecuritypolicy.ensure_csp_does_not_block_string_compilation(mut global, contentsecuritypolicy.CompilationInput{
					body_string: source
					code_string: source
					type_: .timer
				}) or {
					compilation_exception := err
					exception := if convert := owner.embedding_timer_compilation_exception_value_ { convert(compilation_exception) } else { webidl.exception_value(compilation_exception) }
					owner.report_an_exception(dom.js_webidl_value(exception), false)
					return
				}
				mut base_url := settings.api_base_url()
				if script := initiating_script { base_url = script.base_url() or { base_url } }
				// Upstream still leaves the TrustedScript sink conversion and the
				// initiating script's fetch-option propagation as explicit FIXMEs.
				mut script := ClassicScript.create(base_url.basename(), source, realm, base_url, 1, .no)
				script.set_evaluator(evaluator)
				_ = script.run(.no) or { dom.js_undefined() }
			} else if evaluator := owner.timer_script_evaluator_ {
				evaluator(source) or { owner.report_error(dom.js_webidl_value(webidl.exception_value(err))) }
			}
		}
		if id !in owner.active_timers_ { return }
		if repeat {
			owner.run_timer_initialization_steps(handler, normalized_timeout, arguments, true, id)
		} else {
			owner.remove_timer(id)
		}
	}
	completion := fn [owner_handle, task_steps, nesting_level] () {
		owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
		mut document := ?&dom.Document(none)
		if window := owner.associated_window_ { document = window.associated_document() }
		mut queued_task := Task.create(.timer_task, document, fn [owner_handle, task_steps] () {
			owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
			if mut realm := owner.error_reporting_realm_ {
				mut context := TemporaryExecutionContext.create(mut realm, .yes)
				defer { context.close() }
				task_steps()
			} else {
				task_steps()
			}
		})
		queued_task.set_timer_nesting_level(nesting_level)
		mut queue := owner.responsible_event_loop().task_queue()
		queue.add(queued_task)
	}
	scope.arm_timeout(normalized_timeout, completion, id, repeat, throttling_class)
	mut timer := scope.active_timers_[id] or { panic('missing initialized timer') }
	timer.handler = handler
	timer.arguments = arguments.clone()
	timer.nesting_level = nesting_level
	scope.active_timers_[id] = timer
	return id
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_timeout(handler TimerHandler, timeout i32, arguments []dom.JSValue) i32 {
	return scope.run_timer_initialization_steps(handler, timeout, arguments, false, none)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) set_interval(handler TimerHandler, timeout i32, arguments []dom.JSValue) i32 {
	return scope.run_timer_initialization_steps(handler, timeout, arguments, true, none)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_timeout(id i32) {
	if timer := scope.active_timers_[id] {
		if mut clock := timer.clock_ { clock.stop() }
	}
	scope.remove_timer(id)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_interval(id i32) { scope.clear_timeout(id) }

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) clear_map_of_active_timers() {
	for id in scope.active_timers_.keys() { scope.clear_timeout(id) }
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) active_timer_count() int {
	return scope.active_timers_.len
}

// Explicit monotonic-clock adapter. It fires the same completion as the native
// clock and runs the actual owner's runnable tasks, preserving task nesting and
// script cleanup. Production registration never calls this adapter.
pub fn (mut scope WindowOrWorkerGlobalScopeMixin) process_timers(now_ms f64) {
	previous_clock := scope.manual_timer_clock_
	scope.manual_timer_clock_ = now_ms
	defer { scope.manual_timer_clock_ = previous_clock }
	scope.update_intensive_timer_throttling(now_ms)
	mut due_ids := []int{}
	for id, timer in scope.active_timers_ {
		if timer.due_time_ms <= now_ms { due_ids << int(id) }
	}
	due_ids.sort()
	for raw_id in due_ids {
		timer := scope.active_timers_[i32(raw_id)] or { continue }
		if mut clock := timer.clock_ { clock.fire() }
	}
	mut event_loop := scope.responsible_event_loop()
	for event_loop.task_queue().has_runnable_tasks() { event_loop.process() }
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) run_all_timers() {
	scope.process_timers(f64(max_i64))
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
	queue_a_task(.performance_timeline, scope.responsible_event_loop(), none, fn [mut scope] () {
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
		queue_a_task(.performance_timeline, scope.responsible_event_loop(), none, fn [mut scope] () {
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

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) run_steps_after_a_timeout(timeout i32, completion_step fn ()) i32 {
	id := scope.next_timer_id_
	scope.next_timer_id_++
	owner_handle := voidptr(&scope)
	remove_timer_and_complete := fn [owner_handle, id, completion_step] () {
		mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
		owner.remove_timer(id)
		completion_step()
	}
	scope.arm_timeout(timeout, remove_timer_and_complete, id, false, .chained)
	return id
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) run_steps_after_a_timeout_impl(timeout i32, completion_step fn (), timer_key ?i32, repeat bool) i32 {
	id := timer_key or {
		new_id := scope.next_timer_id_
		scope.next_timer_id_++
		new_id
	}
	scope.arm_timeout(timeout, completion_step, id, repeat, .chained)
	return id
}

fn timer_delay_from(milliseconds f64) i32 {
	if milliseconds < 0 { return 0 }
	if milliseconds > max_i32 { return max_i32 }
	return i32(math.ceil(milliseconds))
}

fn (mut scope WindowOrWorkerGlobalScopeMixin) arm_timeout(timeout i32, completion_step fn (), id i32, repeat bool, throttling_class TimerThrottlingClass) {
	normalized_timeout := i64(if timeout < 0 { 0 } else { timeout })
	now_ms := scope.timer_now_ms()
	deadline_ms := now_ms + f64(normalized_timeout)
	due_time_ms := scope.timer_due_time(throttling_class, deadline_ms, now_ms)
	owner_handle := voidptr(&scope)
	completion := fn [owner_handle, throttling_class, completion_step] () {
		mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
		if throttling_class == .chained && owner.timers_are_throttled() {
			owner.last_chained_timer_wake_up_ms_ = owner.timer_now_ms()
		}
		completion_step()
	}
	previous := scope.active_timers_[id] or { GlobalScopeTimer{} }
	mut clock := previous.clock_ or {
		Timer.create_with_parameters(timer_delay_from(due_time_ms - now_ms), completion, id, if repeat {
			TimerRepeating.yes
		} else {
			TimerRepeating.no
		}, throttling_class, deadline_ms)
	}
	clock.set_callback(completion)
	clock.set_throttling_class(throttling_class)
	clock.set_deadline(deadline_ms)
	if previous.clock_ != none {
		if throttling_class != .immediate && scope.timers_are_throttled() {
			clock.restart(timer_delay_from(due_time_ms - now_ms))
		} else {
			clock.set_interval(i32(normalized_timeout))
		}
	}
	scope.active_timers_[id] = GlobalScopeTimer{
		id:               id
		timeout_ms:       normalized_timeout
		deadline_ms:      deadline_ms
		due_time_ms:      due_time_ms
		repeat:           repeat
		throttling_class: throttling_class
		clock_:           clock
	}
	// Keep repeating timers on their existing schedule, as upstream does.
	if previous.clock_ == none { clock.start() }
	// Upstream still leaves fully-active/non-suspended elapsed time, ordering
	// identifiers and the optional additional wait as explicit FIXMEs.
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) report_error(error dom.JSValue) {
	scope.report_an_exception(error, false)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) report_an_exception(exception dom.JSValue, omit_error bool) {
	realm := scope.error_reporting_realm_
	context := if current_realm := realm {
		if extract := current_realm.error_extraction_context_ { extract(exception) } else { ErrorExtractionContext{} }
	} else { ErrorExtractionContext{} }
	information := extract_error_information(exception, context)
	mut message := information.message
	mut filename := information.filename
	mut lineno := information.lineno
	mut colno := information.colno
	mut reported_value := information.error
	if current_realm := realm {
		if script := current_realm.active_classic_script_ {
			if script.muted_errors() == .yes {
				reported_value = dom.js_null()
				message = 'Script error.'
				filename = ''
				lineno = 0
				colno = 0
			}
		}
	}
	if omit_error { reported_value = dom.js_null() }
	mut not_handled := true
	if !scope.error_reporting_mode_ {
		scope.error_reporting_mode_ = true
		event := dom.ErrorEvent.create('error', dom.ErrorEventInit{
			EventInit: dom.EventInit{ cancelable: true }
			message: message
			filename: filename
			lineno: u32(lineno)
			colno: u32(colno)
			error: reported_value
		})
		target := scope.error_reporting_target_ or { unsafe { &dom.EventTarget(scope) } }
		not_handled = target.dispatch_event(unsafe { &dom.Event(event) })
		scope.error_reporting_mode_ = false
	}
	if not_handled {
		if worker := scope.dedicated_worker_ {
			worker.report_unhandled_exception(message, filename, u32(lineno), u32(colno))
			return
		}
		scope.reported_errors_ << exception
		if current_realm := realm {
			mut mutable_realm := unsafe { &ScriptingRealm(current_realm) }
			report_exception_to_console(exception, mut mutable_realm, .no)
		}
	}
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) reported_errors() []dom.JSValue {
	return scope.reported_errors_.clone()
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) performance() &GlobalScopePerformance {
	if value := scope.performance_ {
		return value
	}
	value := create_global_scope_performance(&scope)
	scope.performance_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) indexed_db() &GlobalScopeIndexedDBFactory {
	if value := scope.indexed_db_ {
		return value
	}
	origin := if window := scope.associated_window_ {
		window.associated_document().origin()
	} else {
		scope.origin_
	}
	storage_key := if typed := origin.liburl_origin() {
		storageapi.obtain_a_storage_key(storageapi.StorageEnvironment{ origin: typed })
	} else {
		// Explicit standalone DOM-origin adapter: it has no typed native origin
		// owner, so preserve its existing unavailable-storage result.
		?storageapi.StorageKey(none)
	}
	loop := scope.responsible_event_loop()
	mut document := ?&dom.Document(none)
	if window := scope.associated_window_ {
		document = window.associated_document()
	}
	global_scope := &indexeddb.IndexedDBGlobalScope{
		storage_key: if key := storage_key { key.to_string() } else { '' }
		event_loop_handle: voidptr(loop)
		queue_database_task: fn [loop, document] (task indexeddb.DatabaseTask) {
			queue_a_task(.database_access, loop, document, fn [document, task] () {
				mut allocation_scope := platform.RetainedArenaScope{}
				if owner := document {
					mut storage := owner.native_storage()
					if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
				}
				defer { allocation_scope.finish() }
				task()
			})
		}
	}
	factory := indexeddb.IDBFactory.create_for_global_scope(global_scope) or { panic(err) }
	value := &GlobalScopeIndexedDBFactory{IDBFactory: *factory}
	scope.indexed_db_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) crypto() &GlobalScopeCrypto {
	if value := scope.crypto_ {
		return value
	}
	value := GlobalScopeCrypto.create(scope.responsible_event_loop(), u64(voidptr(scope)))
	scope.crypto_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) caches() &GlobalScopeCacheStorage {
	if value := scope.caches_ {
		return value
	}
	storage := serviceworker.CacheStorage.create()
	value := &GlobalScopeCacheStorage{CacheStorage: *storage}
	scope.caches_ = value
	return value
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) trusted_types() &GlobalScopeTrustedTypePolicyFactory {
	if value := scope.trusted_types_ {
		return value
	}
	target := scope.error_reporting_target_ or { unsafe { &dom.EventTarget(scope) } }
	mut realm_handle := voidptr(unsafe { nil })
	if realm := scope.error_reporting_realm_ { realm_handle = voidptr(realm) }
	scope_pointer := voidptr(&scope)
	factory := trustedtypes.TrustedTypePolicyFactory.create_for_global(&trustedtypes.TrustedTypesGlobalContext{
		global:               voidptr(target)
		realm:                realm_handle
		current_csp_policies: fn [scope_pointer] () []trustedtypes.TrustedTypesCSPPolicy {
			return global_scope_trusted_types_policies(unsafe { &WindowOrWorkerGlobalScopeMixin(scope_pointer) })
		}
	})
	value := &GlobalScopeTrustedTypePolicyFactory{ TrustedTypePolicyFactory: *factory }
	scope.trusted_types_ = value
	return value
}

pub fn (scope &WindowOrWorkerGlobalScopeMixin) supported_entry_types() []string {
	return ['element', 'event', 'first-input', 'largest-contentful-paint', 'layout-shift',
		'long-animation-frame', 'longtask', 'mark', 'measure', 'navigation', 'paint', 'resource',
		'taskattribution', 'visibility-state']
}
