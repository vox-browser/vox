// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Actions.cpp:ActionExecutor. The platform timer adapter retains real monotonic
// deadlines; a fired timer queues a separate task before the next action tick.
module webdriver

import platform
import time

pub type ActionClock = fn () i64
pub type ActionTask = fn ()
pub type ActionEventHandler = fn (DispatchedEvent)
pub type ActionWindowOpen = fn () bool
pub type OnActionsComplete = fn (ActionsResult)

pub struct ActionsOptions {
pub:
	viewport       ?Rect
	is_window_open ?ActionWindowOpen
	dispatch_event ?ActionEventHandler
}

pub struct ActionsResult {
pub:
	events        []DispatchedEvent
	error_message string
}

struct ActionTimer {
	timer       &platform.Timer
	deadline_ms i64
}

@[heap]
pub struct ActionEventLoop {
mut:
	clock_  ActionClock = action_monotonic_time
	timers_ []ActionTimer
	tasks_  []ActionTask
}

fn action_monotonic_time() i64 {
	return time.sys_mono_now() / 1_000_000
}

pub fn ActionEventLoop.create() &ActionEventLoop {
	return &ActionEventLoop{}
}

pub fn ActionEventLoop.create_with_clock(clock ActionClock) &ActionEventLoop {
	return &ActionEventLoop{ clock_: clock }
}

fn (mut event_loop ActionEventLoop) schedule_timer(timer &platform.Timer, duration u64) {
	// Core::Timer uses a signed millisecond interval in the upstream executor.
	event_loop.timers_ << ActionTimer{
		timer:       timer
		deadline_ms: event_loop.clock_() + i64(int(duration))
	}
}

pub fn (mut event_loop ActionEventLoop) queue_task(task ActionTask) {
	event_loop.tasks_ << task
}

// Advance a task turn. Newly fired timer callbacks can only run their queued
// task on a subsequent turn, including timers with a zero interval.
pub fn (mut event_loop ActionEventLoop) process() {
	mut task := ?ActionTask(none)
	if event_loop.tasks_.len > 0 {
		task = event_loop.tasks_[0]
		event_loop.tasks_.delete(0)
	}
	now := event_loop.clock_()
	mut due := []&platform.Timer{}
	mut remaining := []ActionTimer{}
	for scheduled in event_loop.timers_ {
		if now >= scheduled.deadline_ms {
			due << scheduled.timer
		} else {
			remaining << scheduled
		}
	}
	event_loop.timers_ = remaining
	for timer in due {
		mut fired := unsafe { &platform.Timer(timer) }
		fired.fire()
	}
	if queued := task {
		queued()
	}
}

fn (mut event_loop ActionEventLoop) run_until_complete(executor &ActionExecutor) {
	for !executor.complete_ {
		event_loop.process()
		if !executor.complete_ && event_loop.tasks_.len == 0 {
			time.sleep(time.millisecond)
		}
	}
}

@[heap]
pub struct ActionExecutor {
mut:
	input_state_     &InputState = unsafe { nil }
	actions_by_tick_ [][]ActionObject
	current_tick_    int
	actions_options_ ActionsOptions
	event_loop_      &ActionEventLoop = unsafe { nil }
	on_complete_     ?OnActionsComplete
	timer_           ?&platform.Timer
	result_          ActionsResult
	complete_        bool
}

pub fn (executor &ActionExecutor) complete() bool {
	return executor.complete_
}

pub fn (executor &ActionExecutor) result() ActionsResult {
	return executor.result_
}

fn (mut executor ActionExecutor) finish(error_message string) {
	executor.complete_ = true
	executor.result_ = ActionsResult{
		events:        executor.result_.events
		error_message: error_message
	}
	if callback := executor.on_complete_ { callback(executor.result_) }
}

fn (mut executor ActionExecutor) process_next_tick() {
	if executor.current_tick_ >= executor.actions_by_tick_.len {
		executor.finish('')
		return
	}
	tick_actions := executor.actions_by_tick_[executor.current_tick_]
	executor.current_tick_++
	if is_open := executor.actions_options_.is_window_open {
		if !is_open() {
			executor.finish(WebDriverError.from_code(.no_such_window, 'Browsing context is no longer open').msg())
			return
		}
	}
	tick_duration := compute_tick_duration(tick_actions)
	mut input_state := executor.input_state_
	mut tick_events := []DispatchedEvent{}
	// Each action's platform events are delivered before the following action,
	// as in dispatch_tick_actions in Actions.cpp.
	for action in tick_actions {
		action_events := dispatch_tick_actions_with_viewport(mut input_state, [action], executor.actions_options_.viewport) or {
			executor.finish(err.msg())
			return
		}
		for event in action_events {
			if dispatch := executor.actions_options_.dispatch_event { dispatch(event) }
		}
		tick_events << action_events
	}
	mut events := executor.result_.events.clone()
	for event in tick_events {
		events << event
	}
	executor.result_ = ActionsResult{ events: events }
	executor_pointer := voidptr(&executor)
	mut timer := platform.Timer.create_single_shot(int(tick_duration), fn [executor_pointer] () {
		mut pending := unsafe { &ActionExecutor(executor_pointer) }
		pending.timer_ = none
		mut event_loop := pending.event_loop_
		event_loop.queue_task(fn [executor_pointer] () {
			mut next := unsafe { &ActionExecutor(executor_pointer) }
			next.process_next_tick()
		})
	})
	executor.timer_ = timer
	mut event_loop := executor.event_loop_
	event_loop.schedule_timer(timer, tick_duration)
	timer.start()
}

// Actions.cpp:dispatch_actions starts the executor and releases the token as
// soon as process_next_tick returns, matching the current upstream algorithm.
pub fn dispatch_actions_async(mut state InputState, ticks [][]ActionObject, event_loop &ActionEventLoop, options ActionsOptions, on_complete ?OnActionsComplete) &ActionExecutor {
	wait_for_an_action_queue_token(mut state)
	mut executor := &ActionExecutor{
		input_state_:     &state
		actions_by_tick_: ticks.clone()
		actions_options_: options
		event_loop_:      event_loop
		on_complete_:     on_complete
	}
	executor.process_next_tick()
	state.actions_queue.delete(0)
	return executor
}
