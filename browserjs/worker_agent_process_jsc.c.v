// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import browsersettings
import fetch
import platform
import time

// One session belongs to one child process. Keeping its protocol turn separate
// from the descriptor loop also permits replay through the actual worker realm.
@[heap]
pub struct WorkerChildSession {
mut:
	transport ?&fetch.FetchHost
	agent ?&WorkerAgentRuntime
	started bool
	finished bool
	outgoing []WorkerProcessFrame
}

pub fn WorkerChildSession.create(transport ?&fetch.FetchHost) &WorkerChildSession {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerChildSession{transport: transport}
}

fn (mut child WorkerChildSession) send(kind WorkerAgentFrameKind, bytes []u8) {
	child.outgoing << WorkerProcessFrame{kind: u32(kind), bytes: bytes}
}

fn (mut child WorkerChildSession) start(bytes []u8) ! {
	if child.started { return error('Worker startup frame was repeated') }
	child.started = true
	startup := decode_worker_startup(bytes)!
	mut agent := (if startup.is_shared {
		WorkerAgentRuntime.create_shared(startup.url, startup.options, startup.outside, startup.creation_time, child.transport)
	} else {
		WorkerAgentRuntime.create(startup.url, startup.options, startup.outside, startup.creation_time, child.transport)
	}) or {
		child.send(.load_failure, [])
		child.finished = true
		return
	}
	child.agent = agent
	agent.load_entry() or {
		child.send(.load_failure, [])
		child.finished = true
		return
	}
	child.send(.ready, [])
	child.collect()
}

pub fn (mut child WorkerChildSession) accept(frame WorkerProcessFrame) ! {
	if child.finished { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	match frame.kind {
		u32(WorkerAgentFrameKind.start) { child.start(frame.bytes)! }
		u32(WorkerAgentFrameKind.message) {
			mut agent := child.agent or { return error('Worker message preceded startup') }
			agent.queue_message(frame.bytes)!
		}
		u32(WorkerAgentFrameKind.port_message) {
			mut agent := child.agent or { return error('Worker port message preceded startup') }
			agent.queue_port_message(frame.bytes)!
		}
		u32(WorkerAgentFrameKind.shutdown) {
			if frame.bytes.len != 0 { return error('Invalid worker shutdown frame') }
			child.close()
		}
		else { return error('Unexpected parent worker frame') }
	}
}

fn (mut child WorkerChildSession) collect() {
	if mut agent := child.agent {
		for bytes in agent.take_outgoing() { child.send(.message, bytes) }
		frames := agent.take_outgoing_port_messages() or {
			agent.close()
			child.send(.load_failure, [])
			child.finished = true
			return
		}
		for bytes in frames { child.send(.port_message, bytes) }
		if agent.environment.global_scope.is_closing() { child.finished = true }
	}
}

pub fn (mut child WorkerChildSession) process() {
	if child.finished { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if mut agent := child.agent { agent.process() }
	child.collect()
}

pub fn (mut child WorkerChildSession) take_outgoing() []WorkerProcessFrame {
	frames := child.outgoing
	child.outgoing = []
	return frames
}

pub fn (child &WorkerChildSession) is_finished() bool { return child.finished }

pub fn (mut child WorkerChildSession) close() {
	child.finished = true
	child.outgoing = []
	if mut agent := child.agent { agent.close() }
}

// Recognize the signed executable's private role before browser or GUI setup.
// A separate process owns every HTML/JSC object and pumps only its own loop.
pub fn run_worker_process_role(arguments []string) ?int {
	if arguments.len < 2 || arguments[1] != '--vox-script-worker-v1' { return none }
	if arguments.len != 2 { return 2 }
	_ = platform.initialize_browser_heap_policy()
	// The private role runs before main's window setup, including its settings
	// initialization. Native worker fetches need the same saved proxy policy.
	browsersettings.initialize(browsersettings.default_path()) or { return 1 }
	mut channel := WorkerProcess.begin_child() or { return 1 }
	defer { channel.close() }
	mut child := WorkerChildSession.create(none)
	defer { child.close() }
	startup_deadline := time.sys_mono_now() + 30 * time.second
	for {
		// Bound each read turn even when the parent keeps the socket readable.
		for _ in 0 .. 64 {
			read := channel.receive() or { return 1 }
			if read.ended { return 0 }
			if frame := read.frame {
				child.accept(frame) or { return 1 }
			} else { break }
			if child.is_finished() { break }
		}
		child.process()
		for frame in child.take_outgoing() {
			channel.queue(frame.kind, frame.bytes) or { return 1 }
		}
		drained := channel.flush() or { return 1 }
		if child.is_finished() && drained { return 0 }
		if !child.started && time.sys_mono_now() >= startup_deadline { return 1 }
		// Timers and native Fetch callbacks must advance even without IPC input.
		platform.pump_native_events(0.001)
		channel.wait(1) or { return 1 }
	}
	return 0
}
