// SPDX-License-Identifier: BSD-2-Clause
// Fetch/link the entry before accepting parent messages. Once module evaluation
// begins, the worker event loop also services a suspended top-level await.
module browserjs

import dom
import fetch
import html
import platform
import time

@[heap]
struct WorkerModuleEntryResult {
mut:
	done      bool
	evaluated bool
	exception voidptr
	reported  bool
}

fn worker_module_credentials(value html.WorkerCredentials) fetch.CredentialsMode {
	return match value {
		.omit { .omit }
		.include { .include }
		.same_origin { .same_origin }
	}
}

fn (mut host ModuleHost) begin_worker_module_entry(script &html.JavaScriptModuleScript, options html.ScriptFetchOptions) !&WorkerModuleEntryResult {
	$if darwin {
		if host.settings.responsible_document() != none || host.settings.responsible_event_loop().type_() != .worker {
			return error('Module worker entry requires its own worker event loop')
		}
		key := script.filename()
		host.sources[key] = BrowserModuleSource{
			base:      (script.base_url or { dom.URL{ value: key } }).serialize()
			options:   options
			top_level: .yes
			code:      script.source
		}
		mut result := &WorkerModuleEntryResult{}
		host.worker_entry = result
		mut runtime := host.runtime
		runtime.prepare_html_script()
		defer { runtime.clean_up_html_script() }
		mut exception := unsafe { nil }
		promise := C.vox_module_loader_evaluate(runtime.context, key.str, uint(key.len), &exception)
		if promise == unsafe { nil } {
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			return error('Native worker module evaluation failed')
		}
		if exception != unsafe { nil } {
			result.exception = runtime.retain_javascript_value(exception)!
			result.done = true
		}
		defer { C.JSValueUnprotect(runtime.context, promise) }
		owner := voidptr(runtime)
		result_handle := voidptr(result)
		fulfilled := fn [result_handle, owner] (_ voidptr, _ []voidptr) !voidptr {
			mut result := unsafe { &WorkerModuleEntryResult(result_handle) }
			result.done = true
			runtime := unsafe { &Runtime(owner) }
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		rejected := fn [result_handle, owner] (_ voidptr, args []voidptr) !voidptr {
			mut result := unsafe { &WorkerModuleEntryResult(result_handle) }
			mut runtime := unsafe { &Runtime(owner) }
			result.exception = runtime.retain_javascript_value(if args.len > 0 {
				args[0]
			} else {
				C.vox_jsc_JSValueMakeUndefined(runtime.context)
			})!
			result.done = true
			if result.evaluated && !result.reported {
				result.reported = true
				value := runtime.webidl_value(result.exception)!
				settings := runtime.scripting_settings_ or { return error('Missing worker module settings') }
				settings.report_an_exception(dom.js_webidl_value(value), false)
			}
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		runtime.own_closure(voidptr(fulfilled))
		runtime.own_closure(voidptr(rejected))
		runtime.observe_javascript_promise(promise, fulfilled, rejected)!
		if result.evaluated && result.exception != unsafe { nil } && !result.reported {
			result.reported = true
			host.report_worker_module_exception(result.exception)!
		}
		return result
	}
	return error('Native module worker execution is currently available on macOS only')
}

fn (host &ModuleHost) report_worker_module_exception(exception voidptr) ! {
	value := host.runtime.webidl_value(exception)!
	host.settings.report_an_exception(dom.js_webidl_value(value), false)
}

fn (mut host ModuleHost) run_worker_module_entry(script &html.JavaScriptModuleScript, options html.ScriptFetchOptions, timeout_ms int) ! {
	result := host.begin_worker_module_entry(script, options)!
	defer { host.worker_entry = none }
	deadline := time.sys_mono_now() + i64(timeout_ms) * time.millisecond
	mut loop := host.settings.responsible_event_loop()
	for !result.done && !result.evaluated && !host.closed && time.sys_mono_now() < deadline {
		loop.process()
		platform.pump_native_events(0.001)
	}
	if host.closed { return error('Worker module loader closed during startup') }
	if !result.done && !result.evaluated { return error('Module worker entry linking timed out') }
	if result.exception != unsafe { nil } && !result.evaluated {
		return error(js_exception_message(host.runtime.context, result.exception))
	}
}
