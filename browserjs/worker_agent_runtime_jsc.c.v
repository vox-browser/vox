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
mut:
	runtime &Runtime
	global &WorkerGlobalHost
	scripts &WorkerScriptHost = unsafe { nil }
	fetcher &WorkerScriptFetcher = unsafe { nil }
	outside &html.EnvironmentSettingsSnapshot
	entry_url dom.URL
	state_ WorkerAgentState
}

@[heap]
struct WorkerEntryFetchResult {
mut:
	script ?&html.ClassicScript
}

// A worker owns one transport for both synchronous script loading and fetch().
// A supplied transport is useful for deterministic replay; otherwise use Curl.
pub fn WorkerAgentRuntime.create(url dom.URL, options html.WorkerOptions, outside html.SerializedEnvironmentSettingsObject, creation_time f64, transport ?&fetch.FetchHost) !&WorkerAgentRuntime {
	if options.type_ != .classic { return error('Module worker execution is not implemented') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// The caller can release its startup frame or scratch arena immediately.
	owned := html.decode_serialized_environment_settings_object(html.encode_serialized_environment_settings_object(outside))!
	entry_url := dom.URL{value: url.serialize().clone()}
	mut realm := &html.ScriptingRealm{}
	mut scope := html.DedicatedWorkerGlobalScope.create(entry_url, html.WorkerOptions{...options, name: options.name.clone()}, realm)
	scope.owner_set_ << match owned.global {
		html.SerializedWindow { html.WorkerGlobalOwner(owned.global.associated_document) }
		html.SerializedWorkerGlobalScope { html.WorkerGlobalOwner(owned.global) }
	}
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm, owned, creation_time)
	mut runtime := Runtime.create_for_worker()
	mut global := WorkerGlobalHost.create(environment)!
	mut agent := &WorkerAgentRuntime{
		environment: environment
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
	mut timers := TimerHost.create_for_settings(settings)!
	timers.install(mut runtime)!
	mut streams := TransformStreamHost.create_for_settings(settings)!
	streams.install(mut runtime)!
	mut strategies := QueuingStrategyHost.create_for_settings(settings)!
	strategies.install(mut runtime)!
	mut blobs := BlobHost.create_for_settings(settings)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut params := URLSearchParamsHost.create_for_settings(settings)!
	params.install(mut runtime)!
	mut urls := URLHost.create_for_settings(settings)!
	urls.install(mut runtime)!
	mut network := FetchHost.create_for_settings(settings, agent.fetcher.transport)!
	network.install(mut runtime)!
	mut crypto := CryptoHost.create_for_settings(settings)!
	crypto.install(mut runtime)!
}

fn (mut agent WorkerAgentRuntime) perform_script_fetch(request &fetch.Request, top html.TopLevelModule) !&fetch.Response {
	entry := top == .yes && if destination := request.destination { destination == .worker } else { false }
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
	result := &WorkerEntryFetchResult{}
	result_ptr := voidptr(result)
	complete := fn [result_ptr] (script ?&html.Script) {
		mut result := unsafe { &WorkerEntryFetchResult(result_ptr) }
		if actual := script { result.script = unsafe { &html.ClassicScript(actual) } }
	}
	defer { platform.release_closure(voidptr(complete)) }
	html.fetch_classic_worker_script(agent.entry_url, agent.outside, .worker, agent.environment.settings, agent.scripts.perform_fetch, complete)!
	mut script := result.script or { return error('NetworkError: worker entry script could not be loaded') }
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
	agent.state_ = .ready
	// HTML reports a runtime exception through the worker global. Such an
	// exception does not discard an otherwise successfully loaded worker.
	script.run(.no) or {}
}

pub fn (mut agent WorkerAgentRuntime) queue_message(bytes []u8) ! {
	if agent.state_ in [.failed, .closed] { return }
	agent.global.queue_message(bytes)!
}

pub fn (mut agent WorkerAgentRuntime) take_outgoing() [][]u8 {
	return agent.global.take_outgoing()
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
