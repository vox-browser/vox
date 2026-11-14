// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fetch
import html
import json2
import os
import platform
import processmetrics

$if darwin {
	// The V8 backend implements this interface itself (v8/jsc_on_v8.cpp);
	// the Objective-C loader uses JavaScriptCore's JSScript SPI.
	$if !vox_v8 ? {
		#flag darwin -framework Foundation
		#flag darwin @DIR/module_loader_darwin.m
	}
	#include "module_loader_darwin.h"
}

fn C.vox_module_loader_install(voidptr, voidptr, voidptr, fn (voidptr, &char, u32, bool)) voidptr
fn C.vox_module_loader_close(voidptr, voidptr)
fn C.vox_module_loader_evaluate(voidptr, &char, uint, &voidptr) voidptr
fn C.vox_module_loader_supply(voidptr, voidptr, &char, uint, &char, uint, &voidptr) voidptr
fn C.vox_module_loader_supply_value(voidptr, voidptr, voidptr, &char, uint, bool, &voidptr) voidptr
fn C.JSObjectDeleteProperty(voidptr, voidptr, voidptr, &voidptr) bool
fn C.JSContextGetGroup(voidptr) voidptr

const retain_utf8_module_source = os.getenv('VOX_RETAIN_UTF8_MODULE_SOURCE') != ''
const module_source_value_diagnostics = os.getenv('VOX_MODULE_SOURCE_VALUE_DIAGNOSTICS') != ''
const retain_duplicate_module_normalization = os.getenv('VOX_RETAIN_DUPLICATE_MODULE_NORMALIZATION') != ''
const module_normalization_diagnostics = os.getenv('VOX_MODULE_NORMALIZATION_DIAGNOSTICS') != ''
const retain_realm_module_helper = os.getenv('VOX_RETAIN_REALM_MODULE_HELPER') != ''

pub fn (mut host ModuleHost) install(mut runtime Runtime) ! {
	if runtime.engine == .libjs { host.install_libjs(mut runtime)!; return }
	$if !darwin {
		return error('Native module loading is currently available on macOS only')
	}
	$if darwin {
		runtime.require_javascript_value_context()!
		if runtime.module_host_ != none { return error('A module loader is already installed') }
		host.runtime = &runtime
		// Each realm keeps its own lexical binding and resolver closure, while
		// its agent's VM can reuse compiled module source across navigations.
		// A per-host suffix made otherwise identical transformed source differ
		// on every new document and defeated that VM's source/code cache.
		identity := if retain_realm_module_helper { voidptr(host) } else { C.JSContextGetGroup(runtime.context) }
		host.helper_name = '__voxModuleImport_${uint(identity)}'
		owner := voidptr(host)
		fetcher := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &ModuleHost(owner) }
			if host.closed || args.len != 3 { return error('Invalid module fetch callback') }
			host.load(host.runtime.binding_dom_string(args[0])!, args[1], args[2])!
			return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
		})!
		host.native_loader = C.vox_module_loader_install(runtime.context, fetcher, owner, module_evaluation_notification)
		if host.native_loader == unsafe { nil } {
			return error('This JavaScriptCore version has no native module loader')
		}
		mut installed := false
		defer {
			if !installed {
				C.vox_module_loader_close(runtime.context, host.native_loader)
				host.native_loader = unsafe { nil }
			}
		}
		resolver := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &ModuleHost(owner) }
			if host.closed || args.len != 3 { return error('Invalid module resolution callback') }
			specifier := host.runtime.binding_dom_string(args[0])!
			base := host.runtime.binding_dom_string(args[1])!
			key := host.runtime.binding_dom_string(args[2])!
			resolved := host.resolve(specifier, base, key) or {
				return host.runtime.event_binding_type_error(err.msg())
			}
			return host.runtime.binding_string(resolved)
		})!
		factory := runtime.evaluate_host_value(module_source_factory())!
		defer { runtime.release_javascript_value(factory) }
		copy_source := runtime.module_lexer_copy_function()!
		functions := runtime.retain_javascript_value(runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context),
			[resolver, runtime.binding_string(host.helper_name), copy_source])!)!
		defer { runtime.release_javascript_value(functions) }
		mut exception := unsafe { nil }
		host.transform = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 0, &exception))!
		host.lexer_status = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 2, &exception))!
		dynamic := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 1, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		// A private global lexical binding survives page lockdown without adding
		// a non-configurable implementation property to the global object. The
		// temporary initializer is removed before any author module executes.
		temporary := host.helper_name + '_initializer'
		property := js_source_string(temporary)
		defer { C.JSStringRelease(property) }
		global := C.JSContextGetGlobalObject(runtime.context)
		C.vox_jsc_JSObjectSetProperty(runtime.context, global, property, dynamic, 0, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		defer { C.JSObjectDeleteProperty(runtime.context, global, property, unsafe { nil }) }
		runtime.evaluate_host('const ${host.helper_name} = this[${json2.encode(temporary)}];')!
		runtime.module_host_ = host
		runtime.add_close_handler(fn [owner] () {
			mut host := unsafe { &ModuleHost(owner) }
			host.close()
		})
		installed = true
	}
}

fn module_evaluation_notification(owner voidptr, bytes &char, length u32, starting bool) {
	mut host := unsafe { &ModuleHost(owner) }
	if host.closed { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if mut entry := host.worker_entry {
		if starting { entry.evaluated = true }
	}
	if mut document := host.settings.responsible_document() {
		if starting {
			host.current_scripts << BrowserModuleCurrentScript{ script: document.current_script() }
			document.set_current_script(none)
		} else if host.current_scripts.len > 0 {
			document.set_current_script(host.current_scripts.pop().script)
		}
	}
	if !starting { host.evaluated(unsafe { bytes.vstring_with_len(int(length)) }.clone()) }
}

pub fn (mut host ModuleHost) close() {
	if host.closed { return }
	host.closed = true
	for mut execution in host.executions { host.release_execution(mut execution) }
	for operation in host.operations {
		if mut controller := operation.controller { controller.stop_fetch() }
	}
	if mut connection := host.connection { connection.close() }
	$if darwin {
		if host.native_loader != unsafe { nil } {
			C.vox_module_loader_close(host.runtime.context, host.native_loader)
			host.native_loader = unsafe { nil }
		}
	}
	host.operations = []
	host.in_flight = {}
	host.executions = []
	host.sources = {}
}

fn (mut host ModuleHost) resolve(specifier string, base string, parent string) !string {
	import_map := host.settings.universal_global_scope().import_map()
	resolution := if retain_duplicate_module_normalization {
		resolved := html.resolve_module_specifier(import_map, dom.URL{ value: base }, specifier)!
		as_url := html.resolve_url_like_module_specifier(specifier, dom.URL{ value: base })
		html.ResolvedModuleSpecifier{
			url: resolved
			normalized_specifier: if address := as_url { address.serialize() } else { specifier }
			url_like: as_url
		}
	} else {
		html.resolve_module_specifier_with_metadata(import_map, dom.URL{ value: base }, specifier)!
	}
	resolved := resolution.url
	key := resolved.serialize()
	mut settings := unsafe { &html.EnvironmentSettingsObject(host.settings) }
	settings.add_module_to_resolved_module_set(base, resolution.normalized_specifier, resolution.url_like)
	if module_normalization_diagnostics && !retain_duplicate_module_normalization && !host.normalization_reported {
		host.normalization_reported = true
		eprintln('Vox module resolution: reused normalized URL metadata')
	}
	if key !in host.sources {
		options := if source := host.sources[parent] {
			html.get_descendant_script_fetch_options(source.options, resolved, host.settings)
		} else {
			html.default_script_fetch_options()
		}
		host.sources[key] = BrowserModuleSource{
			base:     key
			options:  options
			referrer: fetch.Referrer{ url: dom.URL{ value: base } }
		}
	}
	return key
}

fn (mut host ModuleHost) rewrite(code string, base string, key string, is_module bool) !string {
	value := host.rewrite_value(code, base, key, is_module)!
	defer { host.runtime.release_javascript_value(value) }
	return host.runtime.binding_dom_string(value)
}

// The caller owns this root until native script construction finishes. Keep the
// transformed engine string intact instead of encoding it back to V UTF-8.
fn (mut host ModuleHost) rewrite_value(code string, base string, key string, is_module bool) !voidptr {
	if host.runtime == unsafe { nil } { return error('Module loader is not installed') }
	host.runtime.require_javascript_value_context()!
	skip_specifier_lexer := host.can_skip_keyword_free_module_lexer(code, is_module)
	value := host.runtime.call_javascript_function(host.transform,
		C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [
			host.runtime.binding_string(code),
			host.runtime.binding_string(base),
			host.runtime.binding_string(key),
			C.vox_jsc_JSValueMakeBoolean(host.runtime.context, is_module),
			C.vox_jsc_JSValueMakeBoolean(host.runtime.context, skip_specifier_lexer),
		])!
	if !C.JSValueIsString(host.runtime.context, value) {
		return error('Module transform returned a non-string source')
	}
	host.runtime.retain_javascript_value(value)!
	if !skip_specifier_lexer && !host.lexer_reported && module_lexer_diagnostics {
		status := host.runtime.call_javascript_function(host.lexer_status,
			C.vox_jsc_JSValueMakeUndefined(host.runtime.context), []) or {
			host.runtime.release_javascript_value(value)
			return err
		}
		backend := host.runtime.binding_dom_string(status) or {
			host.runtime.release_javascript_value(value)
			return err
		}
		host.lexer_reported = true
		eprintln('Vox module lexer: backend=${backend} specifier parse executed')
	}
	if skip_specifier_lexer { report_keyword_free_module_lexer_skip() }
	return value
}

fn (mut host ModuleHost) transform_classic(source ScriptSource) !ScriptSource {
	if !source.code.contains('import') { return source }
	if classic_source_can_skip_import_lexer(source.code) { return source }
	base := if source.url == '' { host.settings.api_base_url().serialize() } else { source.url }
	return ScriptSource{ ...source, code: host.rewrite(source.code, base, base, false)! }
}

fn (mut host ModuleHost) execute(source ScriptSource, stringify_result bool) !string {
	if host.runtime.engine == .libjs { return host.execute_libjs(source,stringify_result) }
	$if darwin {
		if host.closed { return error('Module loader is closed') }
		mut key := source.url
		mut base := if key == '' { host.settings.api_base_url().serialize() } else { key }
		mut options := html.default_script_fetch_options()
		mut external := false
		if element := source.element {
			external = element.has_attribute('src')
			options.cryptographic_nonce = element.cryptographic_nonce()
			options.integrity_metadata = element.get_attribute_value('integrity')
			options.referrer_policy = element.get_attribute_value('referrerpolicy')
			options.credentials_mode = if element.get_attribute_value('crossorigin').to_lower() == 'use-credentials' {
				.include
			} else {
				.same_origin
			}
			if !external {
				host.next_inline++
				base = element.document().base_url().serialize()
				key = base.all_before('#') + '#vox-inline-${host.next_inline}'
			}
		}
		if key == '' {
			host.next_inline++
			key = base.all_before('#') + '#vox-inline-${host.next_inline}'
		}
		if key !in host.sources {
			host.sources[key] = BrowserModuleSource{
				base:      base
				options:   options
				top_level: .yes
				code:      if external { none } else { source.code }
			}
		}
		mut execution := &BrowserModuleExecution{
			key:              key
			element:          source.external_element
			blocks_readiness: if element := source.element {
				if element.is_html_element() && element.local_name() == 'script'
					&& !element.has_attribute('async') {
					model := html.html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(element) })
					model.is_parser_inserted()
				} else { false }
			} else {
				false
			}
		}
		if mut document := host.settings.responsible_document() {
			execution.delayer = dom.DocumentLoadEventDelayer.new(mut document)
			if execution.blocks_readiness { document.begin_module_readiness_delay() }
		}
		host.executions << execution
		host.pending_scripts++
		runtime := host.runtime
		runtime.prepare_html_script()
		defer { runtime.clean_up_html_script() }
		mut exception := unsafe { nil }
		promise := C.vox_module_loader_evaluate(host.runtime.context, key.str, uint(key.len), &exception)
		if exception != unsafe { nil } {
			host.release_execution(mut execution)
			return error(js_exception_message(host.runtime.context, exception))
		}
		if promise == unsafe { nil } {
			host.release_execution(mut execution)
			return error('Native module evaluation failed')
		}
		defer { C.JSValueUnprotect(runtime.context, promise) }
		owner := voidptr(host)
		entry := voidptr(execution)
		fulfilled := fn [owner, entry] (_ voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &ModuleHost(owner) }
			mut execution := unsafe { &BrowserModuleExecution(entry) }
			host.finish_script(mut execution, '')
			return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
		}
		rejected := fn [owner, entry] (_ voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &ModuleHost(owner) }
			mut execution := unsafe { &BrowserModuleExecution(entry) }
			message := if args.len > 0 {
				js_exception_message(host.runtime.context, args[0])
			} else {
				'Module evaluation failed'
			}
			host.finish_script(mut execution, message)
			return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
		}
		mut mutable_runtime := unsafe { &Runtime(runtime) }
		mutable_runtime.own_closure(voidptr(fulfilled))
		mutable_runtime.own_closure(voidptr(rejected))
		mutable_runtime.observe_javascript_promise(promise, fulfilled, rejected)!
		_ = stringify_result
		return ''
	}
	return error('Native module execution is unavailable on this platform')
}

fn (mut host ModuleHost) release_execution(mut execution BrowserModuleExecution) {
	if execution.finished { return }
	execution.finished = true
	if mut delayer := execution.delayer {
		delayer.finish()
		execution.delayer = none
	}
	if execution.blocks_readiness {
		if mut document := host.settings.responsible_document() {
			document.end_module_readiness_delay()
		}
	}
	host.pending_scripts--
}

fn (mut host ModuleHost) evaluated(key string) {
	for mut execution in host.executions {
		if execution.key != key || execution.evaluated || execution.finished { continue }
		execution.evaluated = true
		owner := voidptr(host)
		entry := voidptr(execution)
		// didEvaluateModule fires when native evaluation starts, including a
		// suspended top-level await. Readiness must not wait for that promise.
		html.queue_a_task(.dom_manipulation, host.settings.responsible_event_loop(), host.settings.responsible_document(), fn [owner, entry] () {
			mut host := unsafe { &ModuleHost(owner) }
			mut execution := unsafe { &BrowserModuleExecution(entry) }
			if !host.closed { host.finish_script(mut execution, '') }
		})
	}
}

fn (mut host ModuleHost) finish_script(mut execution BrowserModuleExecution, message string) {
	if host.closed { return }
	was_finished := execution.finished
	host.release_execution(mut execution)
	if message != '' {
		host.diagnostics << message
		if host.runtime.engine == .libjs {
			mut owner := unsafe { &Runtime(host.runtime) }
			owner.libjs_messages_ << 'JavaScript (LibJS): '+execution.key+': '+message
		} else { host.runtime.evaluate_host('console.error(${json2.encode(message)})') or {} }
	}
	mut runtime := unsafe { &Runtime(host.runtime) }
	if !was_finished {
		if element := execution.element {
			runtime.dispatch_external_script_event(element, if message == '' || execution.evaluated {
				'load'
			} else {
				'error'
			}) or {}
		}
	}
	if host.deferred_readiness.len > 0 {
		pending := host.deferred_readiness.clone()
		host.deferred_readiness = []
		for name in pending {
			if name == 'load' {
				if document := host.settings.responsible_document() {
					if document.anything_is_delaying_the_load_event() { continue }
				}
			}
			runtime.dispatch_document_readiness_event(name) or {}
		}
	}
	runtime.mark_document_state_dirty()
}

fn (mut host ModuleHost) reject(mut operation BrowserModuleOperation, message string) {
	if operation.finished || host.closed { return }
	operation.finished = true
	if host.runtime.engine == .libjs { host.reject_libjs_import(operation,message); return }
	mut runtime := unsafe { &Runtime(host.runtime) }
	value := runtime.call_javascript_function(runtime.value_error_intrinsic_,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [runtime.binding_string('TypeError'),
			runtime.binding_string(message)]) or { return }
	runtime.call_javascript_function(operation.reject, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value]) or {}
	runtime.release_javascript_value(operation.resolve)
	runtime.release_javascript_value(operation.reject)
}

fn (mut host ModuleHost) supply(mut operation BrowserModuleOperation, code string, base string) {
	if operation.finished || host.closed { return }
	load_instruction_stage := processmetrics.begin_instruction_stage('javascript_module_completion')
	defer { load_instruction_stage.finish() }
	// An asynchronous Fetch task can enter the backend without an outer
	// evaluate() call. Module bodies and the jobs drained by this API entry
	// still need their owning HTML realm on the execution-context stack.
	host.runtime.prepare_html_script()
	defer { host.runtime.clean_up_html_script() }
	if html.can_run_script_for_settings(host.settings) != .run {
		host.reject(mut operation, 'Module execution is disabled for its document')
		return
	}
	mut runtime := unsafe { &Runtime(host.runtime) }
	// The specifier rewrite of the module's source, apart from the engine's
	// own parse and evaluation of the result.
	rewrite_stage := processmetrics.begin_instruction_stage('javascript_module_source_rewrite')
	transformed := host.rewrite_value(code, base, operation.key, true) or {
		rewrite_stage.finish()
		host.reject(mut operation, js_exception_or_message(runtime.context, err))
		return
	}
	rewrite_stage.finish()
	defer { runtime.release_javascript_value(transformed) }
	$if darwin {
		mut exception := unsafe { nil }
		result := if retain_utf8_module_source {
			text := runtime.binding_dom_string(transformed) or {
				host.reject(mut operation, js_exception_or_message(runtime.context, err))
				return
			}
			C.vox_module_loader_supply(runtime.context, operation.resolve, text.str, uint(text.len),
				operation.key.str, uint(operation.key.len), &exception)
		} else {
			C.vox_module_loader_supply_value(runtime.context, operation.resolve, transformed,
				operation.key.str, uint(operation.key.len),
				module_source_value_diagnostics && !host.source_value_reported, &exception)
		}
		if exception != unsafe { nil } || result == unsafe { nil } {
			host.reject(mut operation, 'Unable to supply native module ${operation.key}')
			return
		}
		if !retain_utf8_module_source { host.source_value_reported = true }
	}
	operation.finished = true
	runtime.release_javascript_value(operation.resolve)
	runtime.release_javascript_value(operation.reject)
}

fn js_exception_or_message(context voidptr, err IError) string {
	if err is JavaScriptValueException { return js_exception_message(context, err.value) }
	return err.msg()
}

fn (mut host ModuleHost) consume_script(mut operation BrowserModuleOperation, script ?&html.Script) {
	if host.closed { return }
	if host.runtime.engine == .libjs { host.consume_libjs_script(operation,script); return }
	mut waiters := host.in_flight[operation.key] or { [&operation] }
	host.in_flight.delete(operation.key)
	if source := script {
		module_script := unsafe { &html.JavaScriptModuleScript(source) }
		if module_script.kind == .javascript {
			for mut waiting in waiters {
				host.supply(mut waiting, module_script.source, (module_script.base_url or { dom.URL{ value: operation.key } }).serialize())
			}
			return
		}
	}
	for mut waiting in waiters {
		host.reject(mut waiting, 'Failed to fetch JavaScript module ${operation.key}')
	}
}

fn (mut host ModuleHost) fail_load(operation &BrowserModuleOperation, message string) {
	if operation.preload {
		// A failed preload leaves the module map empty, as if it never ran:
		// the imports that joined it fetch the module themselves.
		mut waiters := host.in_flight[operation.key] or { return }
		host.in_flight.delete(operation.key)
		if waiters.len == 0 { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		host.in_flight[operation.key] = waiters
		mut first := waiters[0]
		host.fetch_module(mut first)
		return
	}
	mut waiters := host.in_flight[operation.key] or { [operation] }
	host.in_flight.delete(operation.key)
	for mut waiting in waiters { host.reject(mut waiting, message) }
}

// https://html.spec.whatwg.org/multipage/links.html#link-type-modulepreload
// JavaScriptCore requests an import only after parsing its importer, so a
// page's preloaded chunks would otherwise arrive one import level at a time.
// The preload fills the module map; an import that arrives while it is in
// flight joins it instead of starting a second fetch.
pub fn (mut host ModuleHost) preload(key string, options html.ScriptFetchOptions) {
	if host.closed || host.runtime == unsafe { nil } || key in host.in_flight { return }
	if host.settings.module_map().get(dom.URL{ value: key }, 'javascript-or-wasm') != none { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut operation := &BrowserModuleOperation{
		key:      key
		source:   BrowserModuleSource{ base: key, options: options }
		preload:  true
		finished: true
	}
	host.operations << operation
	host.in_flight[key] = []&BrowserModuleOperation{}
	host.fetch_module(mut operation)
}

fn (mut host ModuleHost) load(key string, resolve voidptr, reject voidptr) ! {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut runtime := unsafe { &Runtime(host.runtime) }
	entry := host.sources[key] or { BrowserModuleSource{ base: key, options: html.default_script_fetch_options() } }
	mut operation := &BrowserModuleOperation{
		key:     key
		source:  entry
		resolve: runtime.retain_javascript_value(resolve)!
		reject:  runtime.retain_javascript_value(reject)!
	}
	host.operations << operation
	if code := entry.code {
		host.supply(mut operation, code, entry.base)
		return
	}
	if pending := host.in_flight[key] {
		mut waiters := pending.clone()
		waiters << operation
		host.in_flight[key] = waiters
		return
	}
	host.in_flight[key] = [operation]
	host.fetch_module(mut operation)
}

fn (mut host ModuleHost) fetch_module(mut operation BrowserModuleOperation) {
	mut runtime := unsafe { &Runtime(host.runtime) }
	key := operation.key
	entry := operation.source
	url := dom.URL{ value: key }
	owner := voidptr(host)
	op := voidptr(operation)
	callback := fn [owner, op] (script ?&html.Script) {
		mut host := unsafe { &ModuleHost(owner) }
		mut operation := unsafe { &BrowserModuleOperation(op) }
		host.consume_script(mut operation, script)
	}
	runtime.own_closure(voidptr(callback))
	if host.settings.module_map().get(url, 'javascript-or-wasm') != none {
		html.fetch_single_module_script(host.settings.realm(), url, host.settings, .script, entry.options,
			host.settings.realm(), entry.referrer, none, entry.top_level, none, callback)
		return
	}
	mut request := fetch.Request.create()
	request.set_url(url)
	request.set_client(host.settings)
	request.mode = .cors
	request.destination = .script
	request.initiator_type = .script
	request.referrer = entry.referrer
	html.set_up_module_script_request(mut request, entry.options)
	consume := fn [owner, op, callback] (response &fetch.Response, body fetch.BodyBytes) {
		mut host := unsafe { &ModuleHost(owner) }
		mut operation := unsafe { &BrowserModuleOperation(op) }
		if host.closed { return }
		if body.kind != .bytes {
			reason := response.unsafe_response().network_error_message or { 'Module response body failed' }
			host.fail_load(operation, '${operation.key}: ${reason}')
			return
		}
		mut actual := unsafe { &fetch.Response(response.unsafe_response()) }
		actual.set_body_bytes(body.bytes)
		provided := fn [response] (_ &fetch.Request, _ html.TopLevelModule) !&fetch.Response {
			return response
		}
		mut runtime := unsafe { &Runtime(host.runtime) }
		runtime.own_closure(voidptr(provided))
		entry := operation.source
		html.fetch_single_module_script(host.settings.realm(), dom.URL{ value: operation.key }, host.settings,
			.script, entry.options, host.settings.realm(), entry.referrer, none, entry.top_level, provided, callback)
	}
	runtime.own_closure(voidptr(consume))
	operation.controller = fetch.fetch(request, fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response_consume_body: consume
	}), host.transport, .no)
}
