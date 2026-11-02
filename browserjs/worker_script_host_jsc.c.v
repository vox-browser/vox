// SPDX-License-Identifier: BSD-2-Clause
// Classic worker scripts execute in the worker's actual HTML realm.
@[has_globals]
module browserjs

import dom
import html
import platform
import webidl

@[heap]
pub struct WorkerScriptHost {
	environment &html.WorkerEnvironmentSettingsObject
	perform_fetch ?html.PerformTheFetchHook
mut:
	runtime &Runtime = unsafe { nil }
	loader ?html.WorkerScriptFetchHook
	evaluator ?html.ScriptEvaluationHook
	closed bool
}

__global worker_script_bindings_ = map[voidptr]&WorkerScriptHost{}

pub fn WorkerScriptHost.create(environment &html.WorkerEnvironmentSettingsObject, perform_fetch ?html.PerformTheFetchHook) !&WorkerScriptHost {
	if environment.settings.responsible_document() != none ||
		voidptr(environment.settings.global_object()) != voidptr(environment.global_scope.this_impl()) {
		return error('Worker scripts require their own worker environment')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerScriptHost{environment: environment, perform_fetch: perform_fetch}
}

pub fn (mut host WorkerScriptHost) install(mut runtime Runtime) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.environment.settings)!
	owner := voidptr(&runtime)
	if host.closed { return error('Worker script binding is closed') }
	if existing := worker_script_bindings_[owner] {
		if voidptr(existing) == voidptr(&host) { return }
		return error('Worker script binding already belongs to this runtime')
	}
	if host.runtime != unsafe { nil } && voidptr(host.runtime) != owner {
		return error('Worker script binding already belongs to another runtime')
	}
	global := C.JSContextGetGlobalObject(runtime.context)
	if voidptr(runtime.native_event_target(global)!) != voidptr(host.environment.settings.global_object()) {
		return error('Worker scripts require the actual bound worker global')
	}
	runtime.install_dom_exception_binding()!
	host.runtime = &runtime
	handle := voidptr(&host)
	evaluator := fn [handle] (source string, realm &html.ScriptingRealm) !dom.JSValue {
		mut host := unsafe { &WorkerScriptHost(handle) }
		if host.closed { return error('Worker script binding is closed') }
		if voidptr(realm) != voidptr(host.environment.settings.realm()) {
			return error('Worker script requires its owning realm')
		}
		script := realm.active_classic_script_ or { return error('Missing active worker ClassicScript') }
		actual_source := js_source_string(source)
		actual_url := js_source_string(script.filename())
		defer { C.JSStringRelease(actual_source); C.JSStringRelease(actual_url) }
		mut exception := unsafe { nil }
		C.vox_jsc_JSEvaluateScript(host.runtime.context, actual_source, unsafe { nil }, actual_url, 1, &exception)
		if exception != unsafe { nil } {
			return webidl.throw_value(host.runtime.webidl_value(exception)!)
		}
		return dom.js_undefined()
	}
	runtime.own_closure(voidptr(evaluator))
	host.evaluator = evaluator
	loader := fn [handle] (url dom.URL, realm &html.ScriptingRealm) !&html.ClassicScript {
		mut host := unsafe { &WorkerScriptHost(handle) }
		if host.closed { return error('Worker script binding is closed') }
		if voidptr(realm) != voidptr(host.environment.settings.realm()) {
			return error('Worker script requires its owning realm')
		}
		mut script := html.fetch_a_classic_worker_imported_script(url, host.environment.settings, host.perform_fetch)!
		script.set_evaluator(host.evaluator or { return error('Missing worker script evaluator') })
		return script
	}
	runtime.own_closure(voidptr(loader))
	host.loader = loader
	operation := runtime.make_native_value_host_function('importScripts', 0, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &WorkerScriptHost(handle) }
		return host.import_scripts(receiver, args) or {
			// HTML URL and script-fetch failures are DOMExceptions. Actual thrown
			// JavaScript values retain their identity, including primitive values.
			if err is JavaScriptValueException || err is webidl.ValueException { return err }
			message := err.msg()
			for name in ['SyntaxError', 'NetworkError'] {
				if message.starts_with(name + ':') {
					value := webidl.dom_exception_value(webidl.DOMException.create(name, message[name.len + 1..].trim_left(' ')))
					return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(value)!)
				}
			}
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value('(function(method,moduleGlobal){const property={value:method,writable:true,enumerable:true,configurable:true};Object.defineProperty(WorkerGlobalScope.prototype,"importScripts",property);if(moduleGlobal)Object.defineProperty(globalThis,"importScripts",property)})')!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, global, [operation,
		C.JSValueMakeBoolean(runtime.context, runtime.worker_module_global)])!
	worker_script_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &WorkerScriptHost(handle) }
		host.closed = true
		host.loader = none
		host.evaluator = none
		worker_script_bindings_.delete(owner)
	})
}

fn (mut host WorkerScriptHost) import_scripts(receiver voidptr, args []voidptr) !voidptr {
	if host.closed { return error('Worker script binding is closed') }
	target := host.runtime.native_event_target(receiver)!
	if voidptr(target) != voidptr(host.environment.settings.global_object()) {
		return host.runtime.event_binding_type_error('Illegal importScripts receiver')
	}
	mut urls := []string{cap: args.len}
	for value in args { urls << host.runtime.binding_dom_string(value)! }
	mut scope := unsafe { &html.WorkerGlobalScope(host.environment.global_scope) }
	scope.import_scripts(urls, host.loader or { return error('Missing worker script loader') })!
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

// Entry loading and response policy initialization belong to the embedding.
// Once supplied, run the script through HTML's active-script and error rules.
pub fn (mut host WorkerScriptHost) run(source string, url dom.URL, rethrow html.RethrowErrors) ! {
	if host.closed || host.evaluator == none { return error('Worker script binding is not installed') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	owned_url := dom.URL{value: url.serialize().clone()}
	mut script := html.ClassicScript.create(owned_url.serialize(), source.clone(), host.environment.settings.realm(), owned_url, 1, .no)
	script.set_evaluator(host.evaluator or { return error('Missing worker script evaluator') })
	script.run(rethrow)!
}
