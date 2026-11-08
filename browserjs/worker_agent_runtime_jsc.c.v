// SPDX-License-Identifier: BSD-2-Clause
// Dedicated-worker realm, response policy initialization and classic entry execution.
module browserjs

import dom
import fetch
import html
import platform

fn C.vox_jsc_JSCheckScriptSyntax(voidptr, voidptr, voidptr, i32, &voidptr) bool

pub enum WorkerAgentState {
	prepared
	loading
	ready
	failed
	closed
}

@[heap]
pub struct WorkerAgentRuntime {
pub:
	environment &html.WorkerEnvironmentSettingsObject
	options html.WorkerOptions
mut:
	runtime &Runtime
	global &WorkerGlobalHost
	scripts &WorkerScriptHost = unsafe { nil }
	fetcher &WorkerScriptFetcher = unsafe { nil }
	outside &html.EnvironmentSettingsSnapshot
	entry_url dom.URL
	state_ WorkerAgentState
	pending_messages [][]u8
}

@[heap]
struct WorkerEntryFetchResult {
mut:
	script ?&html.Script
}

// A worker owns one transport for both synchronous script loading and fetch().
// A supplied transport is useful for deterministic replay; otherwise use Curl.
pub fn WorkerAgentRuntime.create(url dom.URL, options html.WorkerOptions, outside html.SerializedEnvironmentSettingsObject, creation_time f64, transport ?&fetch.FetchHost) !&WorkerAgentRuntime {
	return WorkerAgentRuntime.create_kind(url, options, outside, creation_time, transport, false)
}

pub fn WorkerAgentRuntime.create_shared(url dom.URL, options html.WorkerOptions, outside html.SerializedEnvironmentSettingsObject, creation_time f64, transport ?&fetch.FetchHost) !&WorkerAgentRuntime {
	return WorkerAgentRuntime.create_kind(url, options, outside, creation_time, transport, true)
}

fn WorkerAgentRuntime.create_kind(url dom.URL, options html.WorkerOptions, outside html.SerializedEnvironmentSettingsObject, creation_time f64, transport ?&fetch.FetchHost, is_shared bool) !&WorkerAgentRuntime {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// The caller can release its startup frame or scratch arena immediately.
	owned := html.decode_serialized_environment_settings_object(html.encode_serialized_environment_settings_object(outside))!
	entry_url := dom.URL{value: url.serialize().clone()}
	mut realm := &html.ScriptingRealm{}
	mut shared_scope := ?&html.SharedWorkerGlobalScope(none)
	mut scope := if is_shared {
		secure := match owned.global {
			html.SerializedWindow { owned.global.associated_document.relevant_settings_object_is_secure_context }
			html.SerializedWorkerGlobalScope { owned.global.relevant_settings_object_is_secure_context }
		}
		actual := html.SharedWorkerGlobalScope.create(entry_url, html.WorkerOptions{...options, name: options.name.clone()}, owned.origin.serialize(), secure, realm)
		shared_scope = actual
		&actual.WorkerGlobalScope
	} else {
		actual := html.DedicatedWorkerGlobalScope.create(entry_url, html.WorkerOptions{...options, name: options.name.clone()}, realm)
		&actual.WorkerGlobalScope
	}
	scope.owner_set_ << match owned.global {
		html.SerializedWindow { html.WorkerGlobalOwner(owned.global.associated_document) }
		html.SerializedWorkerGlobalScope { html.WorkerGlobalOwner(owned.global) }
	}
	environment := html.WorkerEnvironmentSettingsObject.setup(scope, mut realm, owned, creation_time)
	mut runtime := if options.type_ == .module_ { Runtime.create_for_module_worker() } else if is_shared { Runtime.create_for_shared_worker() } else { Runtime.create_for_worker() }
	mut global := if actual := shared_scope { WorkerGlobalHost.create_shared(environment, actual)! } else { WorkerGlobalHost.create(environment)! }
	mut agent := &WorkerAgentRuntime{
		environment: environment
		options: html.WorkerOptions{...options, name: options.name.clone()}
		runtime: runtime
		global: global
		outside: html.EnvironmentSettingsSnapshot.create_for_worker_fetch(owned)
		entry_url: entry_url
	}
	agent.install(transport) or {
		agent.state_ = .failed
		agent.shutdown()
		return err
	}
	return agent
}

fn (mut agent WorkerAgentRuntime) install(transport ?&fetch.FetchHost) ! {
	settings := agent.environment.settings
	mut runtime := agent.runtime
	mut global := agent.global
	global.install(mut runtime)!
	agent.fetcher = if actual := transport {
		WorkerScriptFetcher.create(settings, actual, 30000)!
	} else {
		WorkerScriptFetcher.create_native(settings, 30000)!
	}
	handle := voidptr(&agent)
	perform := fn [handle] (request &fetch.Request, top html.TopLevelModule) !&fetch.Response {
		mut agent := unsafe { &WorkerAgentRuntime(handle) }
		return agent.perform_script_fetch(request, top)
	}
	runtime.own_closure(voidptr(perform))
	mut scripts := WorkerScriptHost.create(agent.environment, perform)!
	scripts.install(mut runtime)!
	agent.scripts = scripts
	runtime.install_base64_binding()!
	runtime.install_text_encoder_binding()!
	runtime.install_text_decoder_binding()!
	runtime.install_microtask_binding()!
	runtime.install_message_channel_binding()!
	runtime.install_performance_binding()!
	mut timers := TimerHost.create_for_settings(settings)!
	timers.install(mut runtime)!
	mut streams := TransformStreamHost.create_for_settings(settings)!
	streams.install(mut runtime)!
	mut strategies := QueuingStrategyHost.create_for_settings(settings)!
	strategies.install(mut runtime)!
	mut blobs := BlobHost.create_for_settings(settings)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	runtime.install_file_reader_sync_binding()!
	mut files := FileHost.create_for_settings(settings)!
	files.install(mut runtime)!
	files.install_constructor()!
	mut file_list := FileListHost.create_for_settings(settings)!
	file_list.install(mut runtime)!
	file_list.install_constructor()!
	mut params := URLSearchParamsHost.create_for_settings(settings)!
	params.install(mut runtime)!
	mut urls := URLHost.create_for_settings(settings)!
	urls.install(mut runtime)!
	mut network := FetchHost.create_for_settings(settings, agent.fetcher.transport)!
	network.install(mut runtime)!
	mut crypto := CryptoHost.create_for_settings(settings)!
	crypto.install(mut runtime)!
	runtime.install_indexed_db_binding()!
}

fn (mut agent WorkerAgentRuntime) perform_script_fetch(request &fetch.Request, top html.TopLevelModule) !&fetch.Response {
	entry := top == .yes && if destination := request.destination { destination in [.worker, .shared_worker] } else { false }
	if agent.options.type_ == .module_ {
		mut actual := unsafe { &fetch.Request(request) }
		actual.credentials_mode = worker_module_credentials(agent.options.credentials)
		if entry {
			actual.set_client(agent.outside)
			actual.referrer = fetch.Referrer{}
		}
	}
	if entry {
		mut actual := unsafe { &fetch.Request(request) }
		actual.reserved_client = agent.environment.settings.environment()
	}
	mut response := agent.fetcher.perform(request)!
	if !entry { return response }
	if final_url := response.unsafe_response().url() {
		mut scope := agent.environment.global_scope
		scope.set_url(final_url)
		mut environment := agent.environment.settings.environment()
		environment.creation_url = final_url
		scope.initialize_policy_container(response, agent.environment.settings)
		if scope.run_csp_initialization() == .blocked {
			response = fetch.Response.network_error('Blocked by Content Security Policy')
		}
	}
	return response
}

pub fn (agent &WorkerAgentRuntime) state() WorkerAgentState { return agent.state_ }

pub fn (mut agent WorkerAgentRuntime) load_entry() ! {
	if agent.state_ != .prepared { return error('Worker entry can only be loaded once') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	agent.state_ = .loading
	defer {
		if agent.state_ == .loading {
			agent.state_ = .failed
			agent.shutdown()
		}
	}
	if agent.options.type_ == .module_ {
		agent.load_module_entry()!
		agent.complete_startup()!
		return
	}
	result := &WorkerEntryFetchResult{}
	result_ptr := voidptr(result)
	complete := fn [result_ptr] (script ?&html.Script) {
		mut result := unsafe { &WorkerEntryFetchResult(result_ptr) }
		result.script = script
	}
	defer { platform.release_closure(voidptr(complete)) }
	destination := if agent.global.shared_scope != none { fetch.Destination.shared_worker } else { fetch.Destination.worker }
	html.fetch_classic_worker_script(agent.entry_url, agent.outside, destination, agent.environment.settings, agent.scripts.perform_fetch, complete)!
	actual := result.script or { return error('NetworkError: worker entry script could not be loaded') }
	mut script := unsafe { &html.ClassicScript(actual) }
	if reason := script.error_to_rethrow() { return error(reason) }
	// JSC evaluates source lazily. Check syntax before marking the environment
	// ready so malformed entries follow the worker startup-failure path.
	source := js_source_string(script.source)
	filename := js_source_string(script.filename())
	defer { C.JSStringRelease(source); C.JSStringRelease(filename) }
	mut exception := unsafe { nil }
	if !C.vox_jsc_JSCheckScriptSyntax(agent.runtime.context, source, filename, 1, &exception) {
		return error('SyntaxError: worker entry script could not be parsed')
	}
	script.set_evaluator(agent.scripts.evaluator or { return error('Missing worker script evaluator') })
	mut environment := agent.environment.settings.environment()
	environment.execution_ready = true
	agent.complete_startup()!
	// HTML reports a runtime exception through the worker global. Such an
	// exception does not discard an otherwise successfully loaded worker.
	script.run(.no) or {}
}

pub fn (mut agent WorkerAgentRuntime) queue_message(bytes []u8) ! {
	if agent.state_ in [.failed, .closed] { return }
	if agent.state_ != .ready {
		_ = decode_worker_message(bytes)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		agent.pending_messages << bytes.clone()
		return
	}
	agent.global.queue_message(bytes)!
}

fn (mut agent WorkerAgentRuntime) complete_startup() ! {
	for bytes in agent.pending_messages { agent.global.queue_message(bytes)! }
	agent.pending_messages = []
	agent.state_ = .ready
}

fn (mut agent WorkerAgentRuntime) load_module_entry() ! {
	result := &WorkerEntryFetchResult{}
	result_handle := voidptr(result)
	mut module_script := ?&html.JavaScriptModuleScript(none)
	// Fetching and linking populate the actual worker module map. Native JSC
	// then consumes those same sources and owns syntax and module evaluation.
	handle := voidptr(&agent)
	complete := fn [result_handle] (script ?&html.Script) {
		mut result := unsafe { &WorkerEntryFetchResult(result_handle) }
		result.script = script
	}
	defer { platform.release_closure(voidptr(complete)) }
	perform := fn [handle] (request &fetch.Request, top html.TopLevelModule) !&fetch.Response {
		mut agent := unsafe { &WorkerAgentRuntime(handle) }
		return agent.perform_script_fetch(request, top)
	}
	defer { platform.release_closure(voidptr(perform)) }
	destination := if agent.global.shared_scope != none { fetch.Destination.shared_worker } else { fetch.Destination.worker }
	html.fetch_module_worker_script_graph(agent.entry_url, agent.environment.settings,
		destination, agent.environment.settings, perform, complete)!
	if actual := result.script { module_script = unsafe { &html.JavaScriptModuleScript(actual) } }
	script := module_script or { return error('NetworkError: worker module graph could not be loaded') }
	if script.kind != .javascript { return error('Worker entry must be a JavaScript module') }
	mut environment := agent.environment.settings.environment()
	environment.execution_ready = true
	mut modules := ModuleHost.create(agent.environment.settings, agent.fetcher.transport)
	modules.install(mut agent.runtime)!
	mut options := html.default_script_fetch_options()
	options.credentials_mode = worker_module_credentials(agent.options.credentials)
	modules.run_worker_module_entry(script, options, agent.fetcher.timeout_ms)!
}

pub fn (mut agent WorkerAgentRuntime) take_outgoing() [][]u8 {
	return agent.global.take_outgoing()
}

pub fn (mut agent WorkerAgentRuntime) queue_port_message(bytes []u8) ! {
	if agent.state_ in [.failed, .closed] { return }
	agent.global.ports.queue_incoming(bytes)!
}

pub fn (mut agent WorkerAgentRuntime) take_outgoing_port_messages() ![][]u8 {
	return agent.global.ports.take_outgoing()
}

pub fn (mut agent WorkerAgentRuntime) process() {
	if agent.state_ != .ready || agent.environment.global_scope.is_closing() { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut loop := agent.environment.settings.responsible_event_loop()
	loop.process()
}

fn (mut agent WorkerAgentRuntime) shutdown() {
	if agent.fetcher != unsafe { nil } { agent.fetcher.close() }
	agent.runtime.close()
	mut settings := agent.environment.settings
	settings.discard_environment()
}

pub fn (mut agent WorkerAgentRuntime) close() {
	if agent.state_ == .closed { return }
	agent.state_ = .closed
	agent.shutdown()
}
