// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Native-value host transport for WebIDL callback/Promise contracts. These
// handles are actual values in the owning JSC context, never JSON identifiers.
module browserjs

pub type ValueHostFunction = fn (receiver voidptr, arguments []voidptr) !voidptr

@[heap]
struct ValueHostFunctionRecord {
	runtime &Runtime
	@[required]
	callback ValueHostFunction
	diagnostic &HostCallbackDiagnostic = unsafe { nil }
}

struct JavaScriptValueException {
	context voidptr
	value voidptr
}

fn (exception JavaScriptValueException) msg() string {
	return 'JavaScript callback threw an actual runtime value'
}

fn (exception JavaScriptValueException) code() int { return 0 }

pub fn (mut runtime Runtime) define_value_host_function(name string, callback ValueHostFunction) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		record := &ValueHostFunctionRecord{ runtime: runtime, callback: callback, diagnostic: new_host_callback_diagnostic(name) }
		if !C.vox_install_js_value_host_function(runtime.context, name.str, record) {
			return error('JavaScriptCore native-value host function installation failed')
		}
		runtime.value_host_functions_ << record
	}
}

fn (runtime &Runtime) require_javascript_value_context() ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	if runtime.engine != .javascriptcore { return error('Native JavaScriptCore values require the JavaScriptCore backend') }
	$if !darwin && !linux && !windows { return error('Native JavaScriptCore values are available on macOS only') }
	if runtime.context == unsafe { nil } { return error('JavaScriptCore context creation failed') }
}

pub struct JavaScriptPromiseCapability {
pub:
	context voidptr
	promise voidptr
	resolve voidptr
	reject voidptr
}

@[heap]
struct JavaScriptPromiseObservation {
	runtime &Runtime
	capability JavaScriptPromiseCapability
mut:
	fulfilled voidptr
	rejected voidptr
	released bool
}
