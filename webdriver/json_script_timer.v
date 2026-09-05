// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of JSON, ExecuteScript, and HeapTimer.
module webdriver

import x.json2

pub fn json_clone(value json2.Any) !json2.Any {
	return match value {
		map[string]json2.Any {
			mut object := map[string]json2.Any{}
			for key, item in value {
				object[key] = json_clone(item)!
			}
			json2.Any(object)
		}
		[]json2.Any {
			mut array := []json2.Any{cap: value.len}
			for item in value {
				array << json_clone(item)!
			}
			json2.Any(array)
		}
		else {
			value
		}
	}
}

pub fn json_deserialize(value json2.Any) !json2.Any {
	return json_clone(value)
}

pub enum ExecutionState {
	pending
	fulfilled
	rejected
}

pub struct ExecutionResult {
pub:
	state ExecutionState
	value json2.Any = json2.null
}

pub type ScriptExecutor = fn(body string, arguments []json2.Any, async_ bool) !json2.Any

pub fn execute_script(body string, arguments []json2.Any, executor ScriptExecutor) ExecutionResult {
	value := executor(body, arguments, false) or {
		return ExecutionResult{
			state: .rejected
			value: err.msg()
		}
	}
	cloned := json_clone(value) or {
		return ExecutionResult{
			state: .rejected
			value: err.msg()
		}
	}
	return ExecutionResult{
		state: .fulfilled
		value: cloned
	}
}

pub fn execute_async_script(body string, arguments []json2.Any, executor ScriptExecutor) ExecutionResult {
	value := executor(body, arguments, true) or {
		return ExecutionResult{
			state: .rejected
			value: err.msg()
		}
	}
	cloned := json_clone(value) or {
		return ExecutionResult{
			state: .rejected
			value: err.msg()
		}
	}
	return ExecutionResult{
		state: .fulfilled
		value: cloned
	}
}

// The host event loop owns time. HeapTimer exposes the same one-shot lifecycle
// while tick() is the explicit embedder boundary.
pub struct HeapTimer {
pub mut:
	running    bool
	timeout_ms u64
	elapsed_ms u64
	fired      bool
}

pub fn (mut timer HeapTimer) start(timeout_ms u64) {
	timer.running = true
	timer.timeout_ms = timeout_ms
	timer.elapsed_ms = 0
}

pub fn (mut timer HeapTimer) tick(elapsed_ms u64) bool {
	if !timer.running {
		return false
	}
	timer.elapsed_ms += elapsed_ms
	if timer.elapsed_ms < timer.timeout_ms {
		return false
	}
	timer.running = false
	timer.fired = true
	return true
}

pub fn (mut timer HeapTimer) stop_and_fire_timeout_handler() bool {
	if !timer.running {
		return false
	}
	timer.running = false
	return true
}

pub fn (mut timer HeapTimer) stop() {
	timer.running = false
}
