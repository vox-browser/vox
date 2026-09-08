// Copyright (c) 2021-2025, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/EventLoop/{Task,TaskQueue,EventLoop}.{h,cpp}.
@[has_globals]
module html

import dom
import time

pub enum EventLoopType {
	window
	worker
	worklet
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
	html_main_thread_event_loop = EventLoop.create(.window)
	html_broadcast_channel_repository = BroadcastChannelRepository.create()
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
}

pub fn Task.create(source TaskSource, document ?&dom.Document, steps fn()) &Task {
	return &Task{
		id: allocate_task_id()
		source: source
		document_: document
		steps: steps
	}
}

pub fn (task &Task) execute() {
	task.steps()
}

pub fn (task &Task) id() u64 {
	return task.id
}

pub fn (task &Task) source() TaskSource {
	return task.source
}

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
pub struct ParallelQueue {}

pub fn ParallelQueue.create() &ParallelQueue {
	return &ParallelQueue{}
}

pub fn (_ &ParallelQueue) enqueue(algorithm fn()) u64 {
	mut event_loop := main_thread_event_loop()
	task := Task.create(.unspecified, none, algorithm)
	mut queue := event_loop.task_queue()
	queue.add(task)
	return task.id
}

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
	if document := task.document() {
		if document.is_temporary_document_for_fragment_parsing() {
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
			queue.tasks.delete(index)
		} else {
			index++
		}
	}
}

pub fn (mut queue TaskQueue) take_tasks_matching(predicate fn(&Task) bool) []&Task {
	mut matching_tasks := []&Task{}
	mut index := 0
	for index < queue.tasks.len {
		task := queue.tasks[index]
		if task.is_permanently_unrunnable() {
			queue.tasks.delete(index)
			continue
		}
		if predicate(task) {
			matching_tasks << task
			queue.tasks.delete(index)
		} else {
			index++
		}
	}
	return matching_tasks
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
	reached_step_1_tasks                  []fn()
	performing_a_microtask_checkpoint     bool
	documents_                            []&dom.Document
	related_environment_settings_objects_ []&EnvironmentSettingsObject
	backup_incumbent_realm_stack_         []&ScriptingRealm
	last_render_opportunity_time_         f64
	last_idle_period_start_time_          f64
	execution_paused                      bool
	skip_event_loop_processing_steps      bool
	running_rendering_task                bool
	scheduled                             bool
	input_events_hook_                    ?EventLoopInputEventsHook
	rendering_hook_                       ?EventLoopRenderingHook
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
	event_loop.reached_step_1_tasks << steps
}

pub fn (mut event_loop EventLoop) schedule() {
	event_loop.scheduled = true
}

pub fn (mut event_loop EventLoop) enqueue_microtask(task &Task) {
	event_loop.microtask_queue << task
}

pub fn (event_loop &EventLoop) microtask_queue_empty() bool {
	return event_loop.microtask_queue.len == 0
}

pub fn (event_loop &EventLoop) currently_running_task() ?&Task {
	return event_loop.currently_running_task_
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

// Run tasks from one task source while the embedding platform waits for the
// supplied goal condition. In the standalone V runtime, exhausting the source
// queue yields to the caller instead of entering a host event-loop wait.
pub fn (mut event_loop EventLoop) spin_processing_tasks_with_source_until(source TaskSource, goal_condition fn() bool) {
	event_loop.perform_a_microtask_checkpoint()
	old_skip := event_loop.skip_event_loop_processing_steps
	event_loop.skip_event_loop_processing_steps = true
	for !goal_condition() {
		mut queue := event_loop.task_queue_
		tasks := queue.take_tasks_matching(fn [source] (task &Task) bool {
			return task.source == source && task.is_runnable()
		})
		if tasks.len == 0 {
			break
		}
		for task in tasks {
			event_loop.currently_running_task_ = task
			task.execute()
			event_loop.currently_running_task_ = none
		}
	}
	event_loop.skip_event_loop_processing_steps = old_skip
	event_loop.schedule()
}

// https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model
pub fn (mut event_loop EventLoop) process() {
	if event_loop.skip_event_loop_processing_steps {
		return
	}
	event_loop.scheduled = false
	reached_step_1_tasks := event_loop.reached_step_1_tasks.clone()
	event_loop.reached_step_1_tasks.clear()
	for steps in reached_step_1_tasks {
		steps()
	}

	if event_loop.task_queue_.has_runnable_tasks() {
		mut queue := event_loop.task_queue_
		if task := queue.take_first_runnable() {
			event_loop.currently_running_task_ = task
			task.execute()
			event_loop.currently_running_task_ = none
			event_loop.perform_a_microtask_checkpoint()
		}
	}
	if event_loop.task_queue_.has_runnable_tasks() || (event_loop.microtask_queue.len > 0 && !event_loop.performing_a_microtask_checkpoint) {
		event_loop.schedule()
	}
	if event_loop.type_ == .window && !event_loop.task_queue_.has_runnable_tasks() {
		event_loop.last_idle_period_start_time_ = unsafe_shared_current_time_ms()
	}
}

// Queue rendering tasks for registered active documents.
pub fn (mut event_loop EventLoop) queue_task_to_update_the_rendering() {
	event_loop.last_render_opportunity_time_ = unsafe_shared_current_time_ms()
	if event_loop.task_queue_.has_rendering_tasks() {
		return
	}
	documents := event_loop.documents_in_this_event_loop_matching(fn (document &dom.Document) bool {
		return document.is_fully_active() && !document.is_decoded_svg()
	})
	for document in documents {
		task := Task.create(.rendering, document, fn [mut event_loop] () {
			event_loop.update_the_rendering()
		})
		mut queue := event_loop.task_queue_
		queue.add(task)
	}
}

pub fn (event_loop &EventLoop) process_input_events() {
	documents := event_loop.documents_in_this_event_loop_matching(fn (document &dom.Document) bool {
		return document.is_fully_active() && !document.is_decoded_svg()
	})
	if hook := event_loop.input_events_hook_ {
		hook(documents)
	}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering
pub fn (mut event_loop EventLoop) update_the_rendering() {
	assert !event_loop.running_rendering_task
	event_loop.running_rendering_task = true
	event_loop.process_input_events()
	frame_timestamp := event_loop.last_render_opportunity_time_
	documents := event_loop.documents_in_this_event_loop_matching(fn (document &dom.Document) bool {
		return document.is_fully_active() && !document.is_decoded_svg() && !document.is_render_blocked() && !document.hidden()
	})
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.run_the_resize_steps()
		mutable_document.run_the_scroll_steps()
		mutable_document.evaluate_media_queries_and_report_changes()
		mutable_document.update_animations_and_send_events(frame_timestamp)
		mutable_document.run_fullscreen_steps()
	}
	for window in event_loop.same_loop_windows() {
		if window.associated_document() in documents {
			mut mutable_window := unsafe { &WindowModel(window) }
			mutable_window.run_animation_frame_callbacks(frame_timestamp)
		}
	}
	for document in documents {
		mut mutable_document := unsafe { &dom.Document(document) }
		// Recalculate layout until every initially visible
		// content-visibility:auto box has had its proximity determined, and until
		// ResizeObserver delivery reaches a fixed point. The viewport paintable
		// owns the filtered box list populated by Document::update_layout().
		mut resize_observer_depth := 0
		for {
			mutable_document.update_layout(.html_event_loop_rendering_update)

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
	if hook := event_loop.rendering_hook_ {
		hook(documents, frame_timestamp)
	}
	event_loop.running_rendering_task = false
}

// https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint
pub fn (mut event_loop EventLoop) perform_a_microtask_checkpoint() {
	if event_loop.execution_paused || event_loop.performing_a_microtask_checkpoint {
		return
	}
	event_loop.performing_a_microtask_checkpoint = true
	for event_loop.microtask_queue.len > 0 {
		task := event_loop.microtask_queue[0]
		event_loop.microtask_queue.delete(0)
		event_loop.currently_running_task_ = task
		task.execute()
		event_loop.currently_running_task_ = none
	}
	event_loop.performing_a_microtask_checkpoint = false
}

pub fn (event_loop &EventLoop) documents_in_this_event_loop_matching(callback fn(&dom.Document) bool) []&dom.Document {
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
	event_loop.documents_ << document
}

pub fn (mut event_loop EventLoop) unregister_document(document &dom.Document) {
	for index, entry in event_loop.documents_ {
		if entry == document {
			event_loop.documents_.delete(index)
			return
		}
	}
	assert false, 'document was not registered with this event loop'
}

pub fn (mut event_loop EventLoop) push_onto_backup_incumbent_realm_stack(realm &ScriptingRealm) {
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
	for window in event_loop.same_loop_windows() {
		if window.has_animation_frame_callbacks() {
			has_pending_renders = true
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
		event_loop.update_the_rendering()
	}
	return &PauseHandle{
		event_loop: event_loop
		time_before_pause: time_before_pause
	}
}

pub fn (mut event_loop EventLoop) unpause(handle &PauseHandle) {
	assert handle.event_loop == event_loop
	event_loop.execution_paused = false
	_ = unsafe_shared_current_time_ms() - handle.time_before_pause
}

pub fn main_thread_event_loop() &EventLoop {
	return html_main_thread_event_loop
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task
pub fn queue_a_task(source TaskSource, event_loop ?&EventLoop, document ?&dom.Document, steps fn()) u64 {
	mut responsible_event_loop := event_loop or { main_thread_event_loop() }
	task := Task.create(source, document, steps)
	if source == .microtask {
		responsible_event_loop.enqueue_microtask(task)
	} else {
		mut queue := responsible_event_loop.task_queue()
		queue.add(task)
	}
	return task.id
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
