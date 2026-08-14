// Copyright (c) 2021-2025, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/EventLoop/{Task,TaskQueue,EventLoop}.{h,cpp}.
@[has_globals]
module html

import dom

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
}

@[heap]
pub struct Task {
pub:
	id     u64
	source TaskSource
mut:
	steps     fn () @[required]
	document_ ?&dom.Document
}

pub fn Task.create(source TaskSource, document ?&dom.Document, steps fn ()) &Task {
	id := html_next_task_id
	html_next_task_id++
	return &Task{
		id:        id
		source:    source
		document_: document
		steps:     steps
	}
}

pub fn (task &Task) execute() {
	task.steps()
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

pub fn (mut queue TaskQueue) remove_tasks_matching(predicate fn (&Task) bool) {
	mut index := 0
	for index < queue.tasks.len {
		if predicate(queue.tasks[index]) {
			queue.tasks.delete(index)
		} else {
			index++
		}
	}
}

pub fn (mut queue TaskQueue) take_tasks_matching(predicate fn (&Task) bool) []&Task {
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
	task_queue_                       &TaskQueue = unsafe { nil }
	microtask_queue                   []&Task
	currently_running_task_           ?&Task
	reached_step_1_tasks              []fn ()
	performing_a_microtask_checkpoint bool
	execution_paused                  bool
	running_rendering_task            bool
	scheduled                         bool
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

pub fn (mut event_loop EventLoop) increment_termination_nesting_level() {
	event_loop.termination_nesting_level++
}

pub fn (mut event_loop EventLoop) decrement_termination_nesting_level() {
	event_loop.termination_nesting_level--
}

pub fn (mut event_loop EventLoop) run_upon_reaching_step_1(steps fn ()) {
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

// https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model
pub fn (mut event_loop EventLoop) process() {
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
	if event_loop.task_queue_.has_runnable_tasks()
		|| (event_loop.microtask_queue.len > 0 && !event_loop.performing_a_microtask_checkpoint) {
		event_loop.schedule()
	}
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

pub fn main_thread_event_loop() &EventLoop {
	return html_main_thread_event_loop
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task
pub fn queue_a_task(source TaskSource, event_loop ?&EventLoop, document ?&dom.Document, steps fn ()) u64 {
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
pub fn queue_global_task(source TaskSource, global_object &dom.Window, steps fn ()) u64 {
	document := if global_object.associated_document_ == unsafe { nil } {
		none
	} else {
		?&dom.Document(global_object.associated_document_)
	}
	return queue_a_task(source, main_thread_event_loop(), document, steps)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-microtask
pub fn queue_a_microtask(document ?&dom.Document, steps fn ()) {
	queue_a_task(.microtask, main_thread_event_loop(), document, steps)
}

pub fn perform_a_microtask_checkpoint() {
	mut event_loop := main_thread_event_loop()
	event_loop.perform_a_microtask_checkpoint()
}
