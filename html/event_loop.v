// Copyright (c) 2021-2025, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/EventLoop/{Task,TaskQueue,EventLoop}.{h,cpp}.
@[has_globals]
module html

import css
import dom
import fetch
import highresolutiontime
import indexeddb
import libjs
import math
import platform
import processmetrics
import time

pub enum EventLoopType {
	window
	worker
	worklet
}

pub struct RenderingSchedulerCounters {
pub mut:
	update_requests                                u64
	coalesced_update_requests                      u64
	update_requests_while_rendering                 u64
	opportunities_received                         u64
	opportunities_that_queued_a_task               u64
	watchdog_opportunities                         u64
	updates_run                                    u64
	updates_skipped_as_unnecessary                 u64
	update_microseconds                            u64
	tasks_between_updates                          u64
	task_microseconds_between_updates              u64
	posted_message_tasks_between_updates           u64
	posted_message_task_microseconds_between_updates u64
	timer_tasks_between_updates                    u64
	timer_task_microseconds_between_updates        u64
	networking_tasks_between_updates               u64
	networking_task_microseconds_between_updates   u64
	dom_manipulation_tasks_between_updates         u64
	dom_manipulation_task_microseconds_between_updates u64
	paints                                         u64
}

pub enum TaskSource {
	unspecified
	dom_manipulation
	user_interaction
	networking
	history_traversal
	idle_task
	posted_message
	microtask
	timer_task
	javascript_engine
	geolocation
	bitmap_task
	navigation_and_traversal
	file_reading
	intersection_observer
	performance_timeline
	canvas_blob_serialization_task
	clipboard
	permissions
	font_loading
	remote_event
	rendering
	database_access
	web_socket
	media_capabilities
	media_element
	gamepad
	crypto
	unique_task_source_start
}

pub const dom_manipulation_task_source = TaskSource.dom_manipulation

__global (
	html_next_task_id           = u64(1)
	html_main_thread_event_loop &EventLoop
)

fn init() {
	if !platform.EventLoopPlugin.is_installed() {
		platform.EventLoopPlugin.install(platform.EventLoopPlugin.new())
	}
	html_main_thread_event_loop = EventLoop.create(.window)
	dom.install_element_cloning_steps(html_element_cloning_steps)
	html_broadcast_channel_repository = BroadcastChannelRepository.create()
	css.install_css_fetch_client_provider(css_fetch_client_for_document)
	css.install_font_loading_task_provider(font_loading_task_for_document)
	css.install_font_loading_promise_context_provider(font_loading_promise_context_for_document)
	css.install_font_loading_event_time_stamp_provider(font_loading_event_time_stamp_for_document)
	fetch.install_parallel_queue_factory(create_fetch_parallel_queue)
	dom.install_main_thread_documents_provider(main_thread_documents_for_dom)
	install_html_element_activation_behavior()
	install_custom_element_registry_dom_hooks()
	dom.install_run_focusing_steps(dom_run_focusing_steps_callback)
	dom.install_pointer_light_dismiss_callback(platform_pointer_light_dismiss)
}

fn main_thread_documents_for_dom() []&dom.Document {
	return main_thread_event_loop().documents_in_this_event_loop_matching(fn (_ &dom.Document) bool { return true })
}

fn allocate_task_id() u64 {
	id := html_next_task_id
	html_next_task_id++
	return id
}

@[heap]
pub struct Task {
pub:
	id     u64
	source TaskSource
mut:
	steps     fn() @[required]
	document_ ?&dom.Document
	timer_nesting_level_ u32
	allocation_owner &platform.RetainedArena = unsafe { nil }
}

pub fn Task.create(source TaskSource, document ?&dom.Document, steps fn()) &Task {
	mut owner := platform.current_retained_arena()
	if target := document {
		storage := target.native_storage()
		if storage != unsafe { nil } { owner = storage }
	}
	if source == .rendering { owner = unsafe { nil } }
	return Task.create_with_storage(source, document, steps, owner)
}

fn Task.create_with_storage(source TaskSource, document ?&dom.Document, steps fn(), storage &platform.RetainedArena) &Task {
	mut owner := unsafe { &platform.RetainedArena(storage) }
	if owner != unsafe { nil } { owner.retain() }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &Task{
		id: allocate_task_id()
		source: source
		document_: document
		steps: steps
		allocation_owner: owner
	}
}

pub fn (task &Task) execute() {
	load_instruction_stage := processmetrics.begin_instruction_stage(match task.source {
		.networking { 'html_networking_task' }
		.timer_task { 'html_timer_task' }
		.rendering { 'html_rendering_task' }
		.posted_message { 'html_posted_message_task' }
		else { 'html_other_task' }
	})
	defer { load_instruction_stage.finish() }
	if task.is_permanently_unrunnable() { task.cancel(); return }
	defer { task.cancel() }
	task.steps()
}

fn (task &Task) cancel() {
	mut mutable_task := unsafe { &Task(task) }
	mut owner := mutable_task.allocation_owner
	mutable_task.allocation_owner = unsafe { nil }
	if owner != unsafe { nil } { owner.release() }
}

pub fn (task &Task) id() u64 {
	return task.id
}

pub fn (task &Task) source() TaskSource {
	return task.source
}

pub fn (task &Task) timer_nesting_level() u32 { return task.timer_nesting_level_ }
pub fn (mut task Task) set_timer_nesting_level(level u32) { task.timer_nesting_level_ = level }

pub fn (task &Task) document() ?&dom.Document {
	return task.document_
}

// https://html.spec.whatwg.org/multipage/webappapis.html#concept-task-runnable
pub fn (task &Task) is_runnable() bool {
	if document := task.document_ {
		return document.is_fully_active()
	}
	return true
}

pub fn (task &Task) is_permanently_unrunnable() bool {
	if document := task.document_ {
		return document.has_been_destroyed()
	}
	return false
}

@[heap]
pub struct ParallelQueue {
	task_source_ UniqueTaskSource
}

pub fn ParallelQueue.create() &ParallelQueue {
	return &ParallelQueue{ task_source_: UniqueTaskSource.create() }
}

pub fn (queue &ParallelQueue) enqueue(algorithm fn()) u64 {
	mut event_loop := main_thread_event_loop()
	task := Task.create(queue.task_source_.source, none, algorithm)
	mut task_queue := event_loop.task_queue()
	task_queue.add(task)
	return task.id
}

pub fn (queue &ParallelQueue) task_source() TaskSource { return queue.task_source_.source }

pub fn (queue &ParallelQueue) finalize() { queue.task_source_.finalize() }

pub type EventLoopInputEventsHook = fn([]&dom.Document)

pub type EventLoopRenderingHook = fn([]&dom.Document, f64)

@[heap]
pub struct PauseHandle {
pub:
	event_loop        &EventLoop
	time_before_pause f64
}

@[heap]
pub struct TaskQueue {
mut:
	event_loop &EventLoop = unsafe { nil }
	tasks      []&Task
}

pub fn (queue &TaskQueue) is_empty() bool {
	return queue.tasks.len == 0
}

pub fn (mut queue TaskQueue) add(task &Task) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if document := task.document() {
		if document.is_temporary_document_for_fragment_parsing() || document.has_been_destroyed() {
			task.cancel()
			return
		}
	}
	queue.tasks << task
	queue.event_loop.schedule()
}

pub fn (queue &TaskQueue) has_runnable_tasks() bool {
	if queue.event_loop.execution_paused {
		return false
	}
	for task in queue.tasks {
		if queue.event_loop.running_rendering_task && task.source == .rendering {
			continue
		}
		if task.is_runnable() {
			return true
		}
	}
	return false
}

pub fn (queue &TaskQueue) has_rendering_tasks() bool {
	for task in queue.tasks {
		if task.source == .rendering {
			return true
		}
	}
	return false
}

pub fn (mut queue TaskQueue) take_first_runnable() ?&Task {
	if queue.event_loop.execution_paused {
		return none
	}
	mut index := 0
	for index < queue.tasks.len {
		task := queue.tasks[index]
		if queue.event_loop.running_rendering_task && task.source == .rendering {
			index++
			continue
		}
		if task.is_runnable() {
			queue.tasks.delete(index)
			return task
		}
		if task.is_permanently_unrunnable() {
			queue.tasks.delete(index)
			task.cancel()
			continue
		}
		index++
	}
	return none
}

pub fn (mut queue TaskQueue) enqueue(task &Task) {
	queue.add(task)
}

pub fn (mut queue TaskQueue) dequeue() ?&Task {
	if queue.tasks.len == 0 {
		return none
	}
	task := queue.tasks[0]
	queue.tasks.delete(0)
	return task
}

pub fn (mut queue TaskQueue) remove_tasks_matching(predicate fn(&Task) bool) {
	mut index := 0
	for index < queue.tasks.len {
		if predicate(queue.tasks[index]) {
			queue.tasks[index].cancel()
			queue.tasks.delete(index)
		} else {
			index++
		}
	}
}

pub fn (mut queue TaskQueue) take_first_runnable_matching(predicate fn(&Task) bool) ?&Task {
	if queue.event_loop.execution_paused {
		return none
	}
	mut index := 0
	for index < queue.tasks.len {
		task := queue.tasks[index]
		if queue.event_loop.running_rendering_task && task.source == .rendering {
			index++
			continue
		}
		if task.is_runnable() && predicate(task) {
			queue.tasks.delete(index)
			return task
		}
		if task.is_permanently_unrunnable() {
			queue.tasks.delete(index)
			continue
		}
		index++
	}
	return none
}

pub fn (queue &TaskQueue) last_added_task() ?&Task {
	if queue.tasks.len == 0 {
		return none
	}
	return queue.tasks.last()
}

@[heap]
pub struct EventLoop {
pub:
	type_ EventLoopType
pub mut:
	termination_nesting_level int
mut:
	task_queue_                           &TaskQueue = unsafe { nil }
	microtask_queue                       []&Task
	currently_running_task_               ?&Task
	task_generation_                      u64
	reached_step_1_tasks                  []&Task
	performing_a_microtask_checkpoint     bool
	documents_                            []&dom.Document
	documents_sort_dirty_                 bool = true
	related_environment_settings_objects_ []&EnvironmentSettingsObject
	microtask_settings_snapshot_          []&EnvironmentSettingsObject
	backup_incumbent_realm_stack_         []&ScriptingRealm
	last_render_opportunity_time_         f64
	last_idle_period_start_time_          f64
	execution_paused                      bool
	running_rendering_task                bool
	running_synchronous_rendering_update_ bool
	scheduled                             bool
	input_events_hook_                    ?EventLoopInputEventsHook
	rendering_hook_                       ?EventLoopRenderingHook
	rendering_update_requested_           bool
	rendering_task_queued_                bool
	rendering_scheduler_counters_         RenderingSchedulerCounters
	idle_period_timer_                    ?&platform.Timer
	vm_                                  ?&libjs.VM
	embedding_vms_                        []&libjs.VM
	system_event_loop_timer_              ?&platform.Timer
}

pub fn EventLoop.create(type_ EventLoopType) &EventLoop {
	mut event_loop := &EventLoop{
		type_: type_
	}
	event_loop.task_queue_ = &TaskQueue{
		event_loop: event_loop
	}
	return event_loop
}

pub fn (event_loop &EventLoop) task_queue() &TaskQueue {
	return event_loop.task_queue_
}

pub fn (event_loop &EventLoop) type_() EventLoopType {
	return event_loop.type_
}

// The embedding supplies the agent VM which executes this loop's JavaScript.
pub fn (mut event_loop EventLoop) bind_vm(vm ?&libjs.VM) {
	event_loop.vm_ = vm
}

pub fn (mut event_loop EventLoop) unbind_vm(vm &libjs.VM) {
	if bound := event_loop.vm_ {
		if voidptr(bound) == voidptr(vm) { event_loop.vm_ = none }
	}
}

// The compact JSC host has a separate translated embedding VM per Runtime.
// Retain actual attached identities without replacing the source agent VM.
pub fn (mut event_loop EventLoop) attach_embedding_vm(vm &libjs.VM) {
	for attached in event_loop.embedding_vms_ {
		if voidptr(attached) == voidptr(vm) { return }
	}
	event_loop.embedding_vms_ << vm
}

pub fn (mut event_loop EventLoop) detach_embedding_vm(vm &libjs.VM) {
	event_loop.embedding_vms_ = event_loop.embedding_vms_.filter(voidptr(it) != voidptr(vm))
}

// These VM operations cannot execute author code or alter the attached set.
// Visit that set directly; only an additional primary VM needs a separate read.
fn (event_loop &EventLoop) primary_vm_not_embedded() ?&libjs.VM {
	if primary := event_loop.vm_ {
		for attached in event_loop.embedding_vms_ {
			if voidptr(attached) == voidptr(primary) { return none }
		}
		return primary
	}
	return none
}

// Host-backed script execution still owns a real translated VM embedding
// context. Cleanup must wait for that outer context before running jobs.
pub fn (event_loop &EventLoop) has_running_execution_context() bool {
	for vm in event_loop.embedding_vms_ {
		if vm.has_running_execution_context() { return true }
	}
	if primary := event_loop.primary_vm_not_embedded() {
		return primary.has_running_execution_context()
	}
	return false
}

pub fn (mut event_loop EventLoop) dequeue_microtask() ?&Task {
	if event_loop.microtask_queue.len == 0 {
		return none
	}
	task := event_loop.microtask_queue[0]
	event_loop.microtask_queue.delete(0)
	return task
}

pub fn (mut event_loop EventLoop) increment_termination_nesting_level() {
	event_loop.termination_nesting_level++
}

pub fn (mut event_loop EventLoop) decrement_termination_nesting_level() {
	event_loop.termination_nesting_level--
}

pub fn (mut event_loop EventLoop) run_upon_reaching_step_1(steps fn()) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.reached_step_1_tasks << Task.create(.unspecified, none, steps)
}

pub fn (mut event_loop EventLoop) schedule() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.scheduled = true
	if event_loop.system_event_loop_timer_ == none {
		event_loop.system_event_loop_timer_ = platform.Timer.create_single_shot(0, fn [mut event_loop] () {
			event_loop.process()
		})
	}
	mut timer := event_loop.system_event_loop_timer_ or { return }
	if !timer.is_active() { timer.restart() }
}

pub fn (mut event_loop EventLoop) enqueue_microtask(task &Task) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.microtask_queue << task
}

pub fn (event_loop &EventLoop) microtask_queue_empty() bool {
	return event_loop.microtask_queue.len == 0
}

pub fn (event_loop &EventLoop) currently_running_task() ?&Task {
	return event_loop.currently_running_task_
}

pub fn (event_loop &EventLoop) task_generation() u64 {
	return event_loop.task_generation_
}

fn (event_loop &EventLoop) idle_period_timer_active() bool {
	if timer := event_loop.idle_period_timer_ {
		return timer.is_active()
	}
	return false
}

fn unsafe_shared_current_time_ms() f64 {
	return f64(time.sys_mono_now()) / 1_000_000.0
}

pub fn (mut event_loop EventLoop) set_input_events_hook(hook ?EventLoopInputEventsHook) {
	event_loop.input_events_hook_ = hook
}

pub fn (mut event_loop EventLoop) set_rendering_hook(hook ?EventLoopRenderingHook) {
	event_loop.rendering_hook_ = hook
}

pub fn (event_loop &EventLoop) execution_paused() bool {
	return event_loop.execution_paused
}

pub fn (event_loop &EventLoop) running_rendering_task() bool {
	return event_loop.running_rendering_task
}

// Spin the event loop while an algorithm waits for a condition that can be
// satisfied by queued work. The browser host can continue waiting when there
// is no runnable work; the standalone runtime yields back to its caller.
pub fn (mut event_loop EventLoop) spin_until(goal_condition fn() bool) {
	event_loop.perform_a_microtask_checkpoint()
	for !goal_condition() {
		mut queue := event_loop.task_queue_
		task := queue.take_first_runnable() or {
			if platform.native_timer_scheduling_available() {
				platform.pump_native_events(0.05)
				continue
			}
			break
		}
		event_loop.currently_running_task_ = task
		task.execute()
		event_loop.currently_running_task_ = none
		event_loop.perform_a_microtask_checkpoint()
	}
	event_loop.schedule()
}

// https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model
pub fn (mut event_loop EventLoop) process() {
	load_instruction_stage := processmetrics.begin_instruction_stage('html_event_loop')
	defer { load_instruction_stage.finish() }
	if event_loop.execution_paused { return }
	if mut timer := event_loop.system_event_loop_timer_ { timer.stop() }
	event_loop.task_generation_++
	event_loop.scheduled = false
	reached_step_1_tasks := event_loop.reached_step_1_tasks.clone()
	event_loop.reached_step_1_tasks.clear()
	for steps in reached_step_1_tasks {
		steps.execute()
	}

	if event_loop.task_queue_.has_runnable_tasks() {
		mut queue := event_loop.task_queue_
		if task := queue.take_first_runnable() {
			task_start_time := unsafe_shared_current_time_ms()
			event_loop.currently_running_task_ = task
			task.execute()
			event_loop.currently_running_task_ = none
			event_loop.perform_a_microtask_checkpoint()
			if task.source() != .rendering {
				duration_microseconds := u64((unsafe_shared_current_time_ms() - task_start_time) * 1000.0)
				event_loop.rendering_scheduler_counters_.tasks_between_updates++
				event_loop.rendering_scheduler_counters_.task_microseconds_between_updates += duration_microseconds
				match task.source() {
					.posted_message {
						event_loop.rendering_scheduler_counters_.posted_message_tasks_between_updates++
						event_loop.rendering_scheduler_counters_.posted_message_task_microseconds_between_updates += duration_microseconds
					}
					.timer_task {
						event_loop.rendering_scheduler_counters_.timer_tasks_between_updates++
						event_loop.rendering_scheduler_counters_.timer_task_microseconds_between_updates += duration_microseconds
					}
					.networking {
						event_loop.rendering_scheduler_counters_.networking_tasks_between_updates++
						event_loop.rendering_scheduler_counters_.networking_task_microseconds_between_updates += duration_microseconds
					}
					.dom_manipulation {
						event_loop.rendering_scheduler_counters_.dom_manipulation_tasks_between_updates++
						event_loop.rendering_scheduler_counters_.dom_manipulation_task_microseconds_between_updates += duration_microseconds
					}
					else {}
				}
			}
		}
	}
	if event_loop.task_queue_.has_runnable_tasks() || (event_loop.microtask_queue.len > 0 && !event_loop.performing_a_microtask_checkpoint) {
		event_loop.schedule()
	}
	if event_loop.type_ == .window && !event_loop.task_queue_.has_runnable_tasks()
		&& !event_loop.idle_period_timer_active() && event_loop.has_active_idle_callbacks() {
		windows := event_loop.same_loop_windows()
		mut has_idle_callbacks := false
		for window in windows {
			if !window.associated_document().hidden() && window.has_idle_callbacks() {
				has_idle_callbacks = true
				break
			}
		}
		if has_idle_callbacks {
			// Callbacks registered while this idle period runs belong to the next
			// period. Keep this single-shot timer active for the whole 50 ms budget
			// so self-scheduling callbacks cannot spin continuously.
			if event_loop.idle_period_timer_ == none {
				event_loop_pointer := unsafe { &EventLoop(event_loop) }
				event_loop.idle_period_timer_ = platform.Timer.create_single_shot(50, fn [event_loop_pointer] () {
					mut mutable_event_loop := unsafe { &EventLoop(event_loop_pointer) }
					mutable_event_loop.schedule()
				})
			}
			if mut timer := event_loop.idle_period_timer_ {
				timer.restart()
			}
			event_loop.last_idle_period_start_time_ = unsafe_shared_current_time_ms()
			for window in windows {
				mut mutable_window := unsafe { &WindowModel(window) }
				mutable_window.start_an_idle_period()
			}
		}
	}
}

// Queue rendering tasks for registered active documents.
pub fn (mut event_loop EventLoop) queue_task_to_update_the_rendering() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.request_rendering_update()
	event_loop.rendering_opportunity(unsafe_shared_current_time_ms(), false)
}

pub fn (mut event_loop EventLoop) request_rendering_update() {
	event_loop.rendering_scheduler_counters_.update_requests++
	if event_loop.running_rendering_task {
		event_loop.rendering_scheduler_counters_.update_requests_while_rendering++
	}
	if event_loop.rendering_update_requested_ || event_loop.rendering_task_queued_ {
		event_loop.rendering_scheduler_counters_.coalesced_update_requests++
		return
	}
	event_loop.rendering_update_requested_ = true
}

pub fn (mut event_loop EventLoop) rendering_opportunity(frame_time f64, watchdog bool) bool {
	event_loop.rendering_scheduler_counters_.opportunities_received++
	if watchdog {
		event_loop.rendering_scheduler_counters_.watchdog_opportunities++
	}
	// EventLoop.cpp: delayed display delivery stays monotonic and cannot
	// publish a timestamp later than the actual shared monotonic clock.
	event_loop.last_render_opportunity_time_ = math.max(event_loop.last_render_opportunity_time_,
		math.min(frame_time, unsafe_shared_current_time_ms()))
	if event_loop.running_rendering_task {
		return false
	}
	event_loop.rendering_update_requested_ = false
	if event_loop.rendering_task_queued_ || event_loop.task_queue_.has_rendering_tasks() {
		return true
	}
	if !event_loop.has_document_with_rendering_opportunity() {
		return false
	}
	event_loop.rendering_task_queued_ = true
	task := Task.create(.rendering, none, fn [mut event_loop] () {
		event_loop.update_the_rendering()
	})
	mut queue := event_loop.task_queue_
	queue.add(task)
	event_loop.rendering_scheduler_counters_.opportunities_that_queued_a_task++
	return true
}

pub fn (event_loop &EventLoop) process_input_events() {
	if hook := event_loop.input_events_hook_ {
		documents := event_loop.documents_in_this_event_loop_matching(fn (document &dom.Document) bool {
			return document.is_fully_active() && !document.is_decoded_svg()
		})
		hook(documents)
	}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering
// https://html.spec.whatwg.org/multipage/interaction.html#flush-autofocus-candidates
pub fn flush_autofocus_candidates(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	if target := mutable_document.take_autofocus_candidate_to_focus() {
		mut manager := FocusManager.create()
		manager.currently_focused_area = document.focused_area()
		run_focusing_steps(mut manager, target.as_node(), none, .focus)
	}
}

pub fn (mut event_loop EventLoop) update_the_rendering() {
	assert !event_loop.running_rendering_task
	event_loop.rendering_task_queued_ = false
	event_loop.running_rendering_task = true
	notify_pages_of_rendering_update(true)
	defer {
		notify_pages_of_rendering_update(false)
	}
	update_start_time := unsafe_shared_current_time_ms()
	event_loop.rendering_scheduler_counters_.updates_run++
	event_loop.process_input_events()
	frame_timestamp := event_loop.last_render_opportunity_time_
	snapshot := event_loop.rendering_document_snapshot()
	defer { snapshot.scratch.finish() }
	documents := snapshot.documents
	for document in documents {
		navigable := document.navigable() or { continue }
		if !navigable.is_top_level_traversable() {
			continue
		}
		flush_autofocus_candidates(document)
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.run_the_resize_steps()
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		if navigable := document.navigable() {
			if model := navigable_model_for_host(navigable) {
				mut mutable_model := unsafe { &NavigableModel(model) }
				mutable_model.process_main_thread_smooth_scrolls()
			}
		}
		mutable_document.run_the_scroll_steps()
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.evaluate_media_queries_and_report_changes()
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_animations_and_send_events(relative_frame_timestamp_for(document, frame_timestamp))
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.run_fullscreen_steps()
	}
	for document in documents {
		settings_pointer := document.relevant_settings_object()
		if settings_pointer == unsafe { nil } {
			continue
		}
		settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
		if window := settings.window_ {
			mut mutable_window := unsafe { &WindowModel(window) }
			mutable_window.run_animation_frame_callbacks(relative_frame_timestamp_for(document, frame_timestamp))
		}
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		// Recalculate layout until every initially visible
		// content-visibility:auto box has had its proximity determined, and until
		// ResizeObserver delivery reaches a fixed point. The viewport paintable
		// owns the filtered box list populated by Document::update_layout().
		mut resize_observer_depth := 0
		mut did_snapshot_post_layout_state := false
		for {
			mutable_document.update_layout(.html_event_loop_rendering_update)
			// A callback can detach a document while this update is running.
			navigable := document.navigable() or { break }
			if !navigable.active_document_is(document) {
				break
			}

			if !did_snapshot_post_layout_state {
				did_snapshot_post_layout_state = true
				if mutable_document.snapshot_scroll_state_queries(false) { continue }
			}
			did_snapshot_post_layout_state = false

			mut had_initial_visible_content_visibility_determination := false
			if document.document_element() != none {
				if paintable := document.paintable() {
					for paintable_box in paintable.paintable_boxes_with_auto_content_visibility() {
						dom_node := paintable_box.dom_node_
						if dom_node == unsafe { nil } {
							continue
						}
						mut element := dom_node.as_element() or { continue }
						check_for_initial_determination := element.proximity_to_the_viewport() == .not_determined
							&& !element.is_relevant_to_the_user()
						element.determine_proximity_to_the_viewport()
						if check_for_initial_determination && element.is_relevant_to_the_user() {
							had_initial_visible_content_visibility_determination = true
						}
					}
				}
			}
			if had_initial_visible_content_visibility_determination {
				continue
			}

			mutable_document.record_last_successful_position_options()
			mutable_document.gather_active_observations_at_depth(resize_observer_depth)
			if mutable_document.has_active_resize_observations() {
				resize_observer_depth = mutable_document.broadcast_active_resize_observations()
				continue
			}
			break
		}
		// Upstream's resize-loop error delivery remains a FIXME, but execute the
		// skipped-observation check at the same point in the rendering pipeline.
		_ = mutable_document.has_skipped_resize_observations()
		mutable_document.perform_pending_transition_operations()
		mutable_document.update_layout(.html_event_loop_rendering_update)
		mutable_document.run_the_update_intersection_observations_steps(frame_timestamp)
		mutable_document.process_top_layer_removals()
	}
	// Hooks may retain their input, so their public snapshot remains durable.
	// Without a hook only the paint count is needed.
	mut documents_to_paint := []&dom.Document{cap: if event_loop.rendering_hook_ != none { documents.len } else { 0 }}
	mut paint_count := 0
	for document in documents {
		style_computer := css.css_style_computer_for(document)
		mut font_computer := unsafe { &css.FontComputer(style_computer.font_computer()) }
		if font_computer.should_defer_initial_paint() {
			continue
		}
		paint_count++
		if event_loop.rendering_hook_ != none { documents_to_paint << document }
	}
	if hook := event_loop.rendering_hook_ {
		hook(documents_to_paint, frame_timestamp)
	}
	// EventLoop.cpp: after rendering, update the source environment gate for
	// the actual FontFaceSet used by this document's style/font computer.
	event_loop.update_font_face_sets_pending_on_the_environment(documents)
	event_loop.rendering_scheduler_counters_.paints += u64(paint_count)
	event_loop.rendering_scheduler_counters_.update_microseconds += u64((unsafe_shared_current_time_ms() - update_start_time) * 1000.0)
	event_loop.running_rendering_task = false
}

fn notify_pages_of_rendering_update(begin bool) {
	scratch := platform.begin_thread_scratch('rendering navigable snapshot')
	models := all_navigable_models()
	scratch.leave()
	defer { scratch.finish() }
	for model in models {
		if model.is_local_root() {
			if page_ := model.page() {
				if begin { page_.client_will_begin_rendering_update() }
				else { page_.client_did_finish_rendering_update() }
			}
		}
	}
}

struct RenderingDocumentSnapshot {
	scratch platform.ThreadScratchScope
	documents []&dom.Document
}

fn (mut event_loop EventLoop) rendering_document_snapshot() RenderingDocumentSnapshot {
	// Sorting can replace the durable document cache. Only its pointer-vector
	// copy belongs to scratch storage; predicates and rendering can call out.
	event_loop.ensure_documents_sorted()
	scratch := platform.begin_thread_scratch('rendering document snapshot')
	mut documents := event_loop.documents_.clone()
	scratch.leave()
	mut count := 0
	for document in documents {
		if document.is_decoded_svg() || !document.is_fully_active()
			|| document.is_render_blocked() || document.hidden()
			|| document.rendering_suppression_for_view_transitions
			|| !document_has_a_rendering_opportunity(document) { continue }
		documents[count] = document
		count++
	}
	documents.trim(count)
	return RenderingDocumentSnapshot{scratch: scratch, documents: documents}
}

fn (event_loop &EventLoop) has_document_with_rendering_opportunity() bool {
	for document in event_loop.documents_ {
		if !document.is_decoded_svg() && document.is_fully_active()
			&& document_has_a_rendering_opportunity(document) { return true }
	}
	return false
}

fn (event_loop &EventLoop) has_active_idle_callbacks() bool {
	for settings in event_loop.related_environment_settings_objects_ {
		window := settings.window_ or { continue }
		document := window.associated_document()
		if document.is_fully_active() && !document.hidden() && window.has_idle_callbacks() { return true }
	}
	return false
}

pub fn (event_loop &EventLoop) update_font_face_sets_pending_on_the_environment(documents []&dom.Document) {
	for document in documents {
		context := document.begin_temporary_execution_context()
		mut owner := unsafe { &dom.Document(document) }
		mut fonts := unsafe { &css.FontFaceSet(owner.fonts().font_face_set_record()) }
		fonts.set_is_pending_on_the_environment(document.readiness() == .loading
			|| document.has_pending_style_sheet_requests() || !document.layout_is_up_to_date())
		document.end_temporary_execution_context(context)
	}
}

fn document_has_a_rendering_opportunity(document &dom.Document) bool {
	navigable := document.navigable() or { return false }
	if model := navigable_model_for_host(navigable) {
		return model.has_a_rendering_opportunity()
	}
	// DOM callers without an HTML model still consult their owning Page.
	if document.has_page() {
		return document.page().client_has_rendering_opportunity()
	}
	return false
}

fn relative_frame_timestamp_for(document &dom.Document, timestamp f64) f64 {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } {
		return math.max(0.0, timestamp)
	}
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	return math.max(0.0, highresolutiontime.relative_high_resolution_time(timestamp,
		highresolutiontime.TimeOriginContext{
			time_origin: settings.time_origin()
			cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
		}))
}

// Use the same origin and precision as rendering timestamps, including when
// an idle document has not received a recent display callback.
pub fn document_animation_clock_now(document &dom.Document) ?f64 {
	if document.relevant_settings_object() == unsafe { nil } { return none }
	return relative_frame_timestamp_for(document, unsafe_shared_current_time_ms())
}

pub fn (event_loop &EventLoop) rendering_scheduler_counters() RenderingSchedulerCounters {
	return event_loop.rendering_scheduler_counters_
}

pub fn (mut event_loop EventLoop) reset_rendering_scheduler_counters() {
	event_loop.rendering_scheduler_counters_ = RenderingSchedulerCounters{}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint
pub fn (mut event_loop EventLoop) perform_a_microtask_checkpoint() {
	if event_loop.execution_paused || event_loop.performing_a_microtask_checkpoint {
		return
	}
	for vm in event_loop.embedding_vms_ {
		assert vm.execution_context_stack().len == 0
		assert !vm.has_running_execution_context()
	}
	if primary := event_loop.primary_vm_not_embedded() {
		assert primary.execution_context_stack().len == 0
		assert !primary.has_running_execution_context()
	}
	event_loop.performing_a_microtask_checkpoint = true
	for event_loop.microtask_queue.len > 0 {
		task := event_loop.microtask_queue[0]
		event_loop.microtask_queue.delete(0)
		event_loop.currently_running_task_ = task
		task.execute()
		event_loop.currently_running_task_ = none
	}
	// Rejection notification can change the related settings set. The source
	// algorithm roots a snapshot before invoking each global's notification.
	// Checkpoint reentry is guarded for the entire notification phase, so this
	// private snapshot can retain its capacity without exposing a mutable list.
	persistent := platform.enter_persistent()
	for settings in event_loop.related_environment_settings_objects_ {
		event_loop.microtask_settings_snapshot_ << settings
	}
	platform.leave_persistent(persistent)
	for index in 0 .. event_loop.microtask_settings_snapshot_.len {
		settings := event_loop.microtask_settings_snapshot_[index]
		if settings.universal_global_scope_ != unsafe { nil } {
			mut scope := settings.universal_global_scope_
			scope.notify_about_rejected_promises()
		}
	}
	indexeddb.cleanup_indexed_database_transactions(voidptr(&event_loop))
	// ClearKeptObjects is represented by the real VM's execution generation.
	for vm_pointer in event_loop.embedding_vms_ {
		mut vm := unsafe { &libjs.VM(vm_pointer) }
		vm.finish_execution_generation()
	}
	if mut primary := event_loop.primary_vm_not_embedded() {
		primary.finish_execution_generation()
	}
	// clear() alone leaves scanned pointers in the retained backing allocation.
	for index in 0 .. event_loop.microtask_settings_snapshot_.len {
		event_loop.microtask_settings_snapshot_[index] = unsafe { nil }
	}
	event_loop.microtask_settings_snapshot_.clear()
	event_loop.performing_a_microtask_checkpoint = false
}

pub fn (event_loop &EventLoop) documents_in_this_event_loop_matching(callback fn(&dom.Document) bool) []&dom.Document {
	// C++ keeps the ordered document cache mutable in this const operation.
	mut mutable_event_loop := unsafe { &EventLoop(event_loop) }
	mutable_event_loop.ensure_documents_sorted()
	mut documents := []&dom.Document{}
	for document in event_loop.documents_ {
		if document.is_decoded_svg() || !callback(document) {
			continue
		}
		documents << document
	}
	return documents
}

pub fn (mut event_loop EventLoop) register_document(document &dom.Document) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.documents_ << document
	event_loop.documents_sort_dirty_ = true
}

pub fn (mut event_loop EventLoop) document_navigable_did_change() {
	event_loop.documents_sort_dirty_ = true
}

// EventLoop::ensure_documents_sorted(): visit a registered container before
// appending its child. Unrelated documents retain their registration order.
fn (mut event_loop EventLoop) ensure_documents_sorted() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if !event_loop.documents_sort_dirty_ {
		return
	}
	event_loop.documents_sort_dirty_ = false
	mut document_to_index := map[voidptr]int{}
	for index, document in event_loop.documents_ {
		document_to_index[voidptr(document)] = index
	}
	mut visited := []bool{len: event_loop.documents_.len}
	mut sorted := []&dom.Document{cap: event_loop.documents_.len}
	for index in 0 .. event_loop.documents_.len {
		visit_document_container_before_child(event_loop.documents_, document_to_index,
			mut visited, mut sorted, index)
	}
	event_loop.documents_ = sorted
}

fn visit_document_container_before_child(documents []&dom.Document, document_to_index map[voidptr]int,
	mut visited []bool, mut sorted []&dom.Document, index int) {
	if visited[index] {
		return
	}
	visited[index] = true
	if navigable := documents[index].navigable() {
		if container_document := navigable.container_document() {
			if container_index := document_to_index[voidptr(container_document)] {
				visit_document_container_before_child(documents, document_to_index,
					mut visited, mut sorted, container_index)
			}
		}
	}
	sorted << documents[index]
}

pub fn (mut event_loop EventLoop) unregister_document(document &dom.Document) {
	for index, entry in event_loop.documents_ {
		if voidptr(entry) == voidptr(document) {
			event_loop.documents_.delete(index)
			return
		}
	}
	assert false, 'document was not registered with this event loop'
}

pub fn (mut event_loop EventLoop) push_onto_backup_incumbent_realm_stack(realm &ScriptingRealm) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.backup_incumbent_realm_stack_ << realm
}

pub fn (mut event_loop EventLoop) pop_backup_incumbent_realm_stack() {
	assert event_loop.backup_incumbent_realm_stack_.len > 0
	event_loop.backup_incumbent_realm_stack_.delete_last()
}

pub fn (event_loop &EventLoop) top_of_backup_incumbent_realm_stack() &ScriptingRealm {
	assert event_loop.backup_incumbent_realm_stack_.len > 0
	return event_loop.backup_incumbent_realm_stack_.last()
}

pub fn (event_loop &EventLoop) is_backup_incumbent_realm_stack_empty() bool {
	return event_loop.backup_incumbent_realm_stack_.len == 0
}

pub fn (mut event_loop EventLoop) register_environment_settings_object(settings &EnvironmentSettingsObject) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	event_loop.related_environment_settings_objects_ << settings
}

pub fn (mut event_loop EventLoop) unregister_environment_settings_object(settings &EnvironmentSettingsObject) {
	for index, entry in event_loop.related_environment_settings_objects_ {
		if entry == settings {
			event_loop.related_environment_settings_objects_.delete(index)
			return
		}
	}
	assert false, 'environment settings object was not registered with this event loop'
}

pub fn (event_loop &EventLoop) same_loop_windows() []&WindowModel {
	mut windows := []&WindowModel{}
	for settings in event_loop.related_environment_settings_objects_ {
		window := settings.window_ or { continue }
		if !window.associated_document().is_fully_active() || window in windows {
			continue
		}
		windows << window
	}
	return windows
}

pub fn (event_loop &EventLoop) compute_deadline() f64 {
	mut deadline := event_loop.last_idle_period_start_time_ + 50.0
	mut has_pending_renders := false
	for settings in event_loop.related_environment_settings_objects_ {
		window := settings.window_ or { continue }
		if window.associated_document().is_fully_active() && window.has_animation_frame_callbacks() {
			has_pending_renders = true
			break
		}
	}
	if has_pending_renders {
		next_render_deadline := event_loop.last_render_opportunity_time_ + (1000.0 / 60.0)
		if next_render_deadline < deadline {
			deadline = next_render_deadline
		}
	}
	return deadline
}

pub fn (mut event_loop EventLoop) pause() &PauseHandle {
	event_loop.execution_paused = true
	time_before_pause := unsafe_shared_current_time_ms()
	if !event_loop.running_rendering_task {
		event_loop.running_synchronous_rendering_update_ = true
		event_loop.update_the_rendering()
		event_loop.running_synchronous_rendering_update_ = false
	}
	return &PauseHandle{
		event_loop: event_loop
		time_before_pause: time_before_pause
	}
}

pub fn (mut event_loop EventLoop) unpause(handle &PauseHandle) {
	// Identity, not `==`: V compares referenced values, which expands into a
	// multi-megabyte deep comparison of the whole event loop graph in C.
	assert voidptr(handle.event_loop) == voidptr(event_loop)
	event_loop.execution_paused = false
	event_loop.schedule()
	_ = unsafe_shared_current_time_ms() - handle.time_before_pause
}

pub fn main_thread_event_loop() &EventLoop {
	return html_main_thread_event_loop
}

pub fn run_when_event_loop_reaches_step_1(steps fn()) {
	mut event_loop := main_thread_event_loop()
	event_loop.run_upon_reaching_step_1(steps)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task
pub fn queue_a_task(source TaskSource, event_loop ?&EventLoop, document ?&dom.Document, steps fn()) u64 {
	return enqueue_owned_task(event_loop, Task.create(source, document, steps))
}

// A task's runnability association and the receiver's storage lifetime are
// separate. Parser and font progress checks intentionally have no association.
fn queue_a_task_with_storage(source TaskSource, event_loop ?&EventLoop, document ?&dom.Document, steps fn(), storage &platform.RetainedArena) u64 {
	return enqueue_owned_task(event_loop, Task.create_with_storage(source, document, steps, storage))
}

fn enqueue_owned_task(event_loop ?&EventLoop, task &Task) u64 {
	mut responsible_event_loop := event_loop or { main_thread_event_loop() }
	if task.source == .microtask {
		responsible_event_loop.enqueue_microtask(task)
	} else {
		mut queue := responsible_event_loop.task_queue()
		queue.add(task)
	}
	return task.id
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-an-element-task
// Element::queue_an_element_task(). DOM cannot import the event loop, so the element-owned operation lives here.
pub fn queue_an_element_task(element &dom.Element, source TaskSource, steps fn ()) u64 {
	return queue_a_task(source, main_thread_event_loop(), element.as_node().document(), steps)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task
pub fn queue_global_task(source TaskSource, global_object &dom.Window, steps fn()) u64 {
	document := if global_object.associated_document_ == unsafe { nil } {
		none
	} else {
		?&dom.Document(global_object.associated_document_)
	}
	return queue_a_task(source, main_thread_event_loop(), document, steps)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-microtask
pub fn queue_a_microtask(document ?&dom.Document, steps fn()) {
	queue_a_task(.microtask, main_thread_event_loop(), document, steps)
}

pub fn perform_a_microtask_checkpoint() {
	mut event_loop := main_thread_event_loop()
	event_loop.perform_a_microtask_checkpoint()
}

fn css_fetch_client_for_document(document &dom.Document) ?fetch.RequestClient {
	settings := document.relevant_settings_object()
	if settings == unsafe { nil } { return none }
	return fetch.RequestClient(unsafe { &EnvironmentSettingsObject(settings) })
}
