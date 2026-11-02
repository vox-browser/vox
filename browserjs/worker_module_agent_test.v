module browserjs

import dom
import fetch
import html
import http
import platform
import time

@[heap]
struct ModuleWorkerNetwork {
mut:
	sources   map[string]string
	redirects map[string]string
	requests  []&fetch.Request
	mime      string = 'text/javascript'
	headers   []http.Header
}

fn module_worker_agent(network &ModuleWorkerNetwork) !&WorkerAgentRuntime {
	url := dom.URL{ value: 'https://module-worker.test/entry.js' }
	transport := &fetch.FetchHost{
		perform: fn [network] (request &fetch.Request) !&fetch.Response {
			mut state := unsafe { &ModuleWorkerNetwork(network) }
			state.requests << request.clone()
			mut response := fetch.Response.create()
			address := request.current_url().serialize()
			if redirect := state.redirects[address] {
				response.status = 302
				response.header_list.append(http.Header{ name: 'Location', value: redirect })
				return response
			}
			response.header_list.append(http.Header{ name: 'Content-Type', value: state.mime })
			for header in state.headers { response.header_list.append(header) }
			if source := state.sources[address] {
				response.set_body_bytes(source.bytes())
			} else {
				response.status = 404
				response.set_body_bytes('missing'.bytes())
			}
			return response
		}
	}
	return WorkerAgentRuntime.create(url, html.WorkerOptions{ type_: .module_, credentials: .omit, name: 'module test' }, html.SerializedEnvironmentSettingsObject{
		creation_url:     url
		api_base_url:     dom.URL{ value: 'https://module-worker.test/assets/' }
		origin:           url.origin()
		policy_container: html.SerializedPolicyContainer{ referrer_policy: .strict_origin_when_cross_origin }
		global:           html.SerializedWindow{
			associated_document: html.SerializedDocument{
				url:                                        dom.URL{ value: 'https://module-worker.test/owner?lang=en#private' }
				relevant_settings_object_is_secure_context: true
			}
		}
	}, 12, transport)
}

fn test_module_worker_redirects_imports_cycles_and_import_meta_use_the_actual_worker_map() {
	network := &ModuleWorkerNetwork{
		redirects: {
			'https://module-worker.test/entry.js': '/modules/main.js'
		}
		sources:   {
			'https://module-worker.test/modules/main.js':  'import {answer} from "./value.js";globalThis.answer=answer;globalThis.entryURL=import.meta.url;globalThis.importScriptsRejected=false;globalThis.importScriptsError="";try{importScripts()}catch(e){importScriptsRejected=e instanceof TypeError;importScriptsError=e.name+":"+e.message}postMessage(answer);'
			'https://module-worker.test/modules/value.js': 'import {plus} from "./cycle.js";export const answer=plus(41);'
			'https://module-worker.test/modules/cycle.js': 'import {answer} from "./value.js";export function plus(value){return value+1;}'
		}
	}
	mut agent := module_worker_agent(network)!
	defer { agent.close() }
	agent.load_entry()!
	assert agent.state() == .ready
	assert agent.runtime.evaluate_host('answer===42&&entryURL==="https://module-worker.test/modules/main.js"&&location.href===entryURL&&name==="module test"&&typeof document==="undefined"&&importScriptsRejected')! == 'true', agent.runtime.evaluate_host('JSON.stringify({answer,entryURL,location:location.href,name,document:typeof document,importScriptsRejected,importScriptsError})')!
	assert agent.take_outgoing().len == 1
	assert network.requests.len == 4
	assert network.requests[0].mode == .same_origin
	assert network.requests[0].destination? == .worker
	assert network.requests[0].reserved_client != none
	assert network.requests[0].header_list.get('Referer')? == 'https://module-worker.test/owner?lang=en'
	for request in network.requests {
		assert request.credentials_mode == .omit
	}
	assert agent.runtime.module_host_?.errors() == []string{}
	assert agent.environment.settings.realm().reported_exceptions.len == 0
	assert agent.runtime.evaluate_host('self===globalThis&&typeof({}).postMessage==="undefined"&&typeof({}).self==="undefined"&&Object.prototype.toString.call(self)==="[object DedicatedWorkerGlobalScope]"')! == 'true'
}

fn test_module_worker_top_level_await_keeps_the_worker_loop_and_dynamic_imports_live() {
	network := &ModuleWorkerNetwork{
		sources: {
			'https://module-worker.test/entry.js': 'globalThis.complete=false;onmessage=e=>postMessage(complete);await new Promise(resolve=>setTimeout(resolve,60));globalThis.dynamic=(await import("./later.js")).value;globalThis.handled=false;try{await import("./rejected.js")}catch(error){handled=true}complete=true;'
			'https://module-worker.test/later.js': 'export const value=73;'
			'https://module-worker.test/rejected.js': 'throw new Error("handled module failure");'
		}
	}
	mut agent := module_worker_agent(network)!
	defer { agent.close() }
	mut sender := Runtime.create()
	defer { sender.close() }
	transfer := ArrayBufferTransferBridge.create(sender)!
	agent.queue_message(encode_worker_message(transfer.serialize(sender.evaluate_host_value('1')!, [])!)!)!
	agent.load_entry()!
	assert agent.state() == .ready
	assert agent.runtime.evaluate_host('complete')! == 'false'
	agent.process()
	frames := agent.take_outgoing()
	assert frames.len == 1
	actual := transfer.deserialize(decode_worker_message(frames[0])!)!
	sender.define_value_host_function('__moduleDuringAwait', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert sender.evaluate_host('__moduleDuringAwait()===false')! == 'true'
	deadline := time.sys_mono_now() + 5 * time.second
	for agent.runtime.evaluate_host('complete')! != 'true' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.001)
		agent.process()
	}
	assert agent.runtime.evaluate_host('complete&&dynamic===73&&handled')! == 'true', agent.runtime.evaluate_host('JSON.stringify({complete,dynamic,handled})')!
	assert agent.environment.settings.realm().reported_exceptions.len == 0
	assert network.requests.len == 3
	assert network.requests[1].credentials_mode == .omit
}

fn test_module_worker_rejects_fetch_parse_policy_and_cross_origin_entry_failures() {
	for failure in ['missing', 'mime', 'syntax', 'dependency-syntax', 'sandbox', 'foreign-redirect'] {
		mut network := &ModuleWorkerNetwork{}
		if failure != 'missing' {
			network.sources['https://module-worker.test/entry.js'] = 'postMessage("must not execute");'
		}
		if failure == 'mime' { network.mime = 'text/plain' }
		if failure == 'syntax' {
			network.sources['https://module-worker.test/entry.js'] = 'export const = ;'
		}
		if failure == 'dependency-syntax' {
			network.sources['https://module-worker.test/entry.js'] = 'import "./bad.js";postMessage("must not execute");'
			network.sources['https://module-worker.test/bad.js'] = 'export const = ;'
		}
		if failure == 'sandbox' {
			network.headers << http.Header{ name: 'Content-Security-Policy', value: 'sandbox allow-same-origin' }
		}
		if failure == 'foreign-redirect' {
			network.redirects['https://module-worker.test/entry.js'] = 'https://other-worker.test/entry.js'
		}
		mut agent := module_worker_agent(network)!
		defer { agent.close() }
		if _ := agent.load_entry() {
			assert false, failure
		}
		assert agent.state() == .failed, failure
		assert agent.runtime.closed && agent.environment.settings.environment().discarded, failure
		assert agent.take_outgoing().len == 0, failure
	}
}

fn test_module_worker_reports_runtime_exceptions_instead_of_failing_script_loading() {
	network := &ModuleWorkerNetwork{ sources: {
		'https://module-worker.test/entry.js': 'globalThis.began=true;throw new Error("worker module runtime");'
	} }
	mut agent := module_worker_agent(network)!
	defer { agent.close() }
	agent.runtime.evaluate_host('globalThis.moduleErrors=[];addEventListener("error",event=>{moduleErrors.push(event.error);event.preventDefault()});')!
	agent.load_entry()!
	assert agent.state() == .ready
	assert agent.runtime.evaluate_host('began')! == 'true'
	assert agent.runtime.evaluate_host('moduleErrors.length===1&&moduleErrors[0] instanceof Error&&moduleErrors[0].message==="worker module runtime"')! == 'true'
	assert agent.environment.settings.realm().reported_exceptions.len == 0
}

fn test_module_worker_reports_a_later_top_level_await_error_once() {
	network := &ModuleWorkerNetwork{ sources: {
		'https://module-worker.test/entry.js': 'await new Promise(resolve=>setTimeout(resolve,10));throw new Error("late worker module runtime");'
	} }
	mut agent := module_worker_agent(network)!
	defer { agent.close() }
	agent.runtime.evaluate_host('globalThis.moduleErrors=[];addEventListener("error",event=>{moduleErrors.push(event.error);event.preventDefault()});')!
	agent.load_entry()!
	deadline := time.sys_mono_now() + 5 * time.second
	for agent.runtime.evaluate_host('moduleErrors.length')! == '0' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.001)
		agent.process()
	}
	assert agent.state() == .ready
	assert agent.runtime.evaluate_host('moduleErrors.length===1&&moduleErrors[0] instanceof Error&&moduleErrors[0].message==="late worker module runtime"')! == 'true'
	agent.process()
	assert agent.runtime.evaluate_host('moduleErrors.length')! == '1'
	assert agent.environment.settings.realm().reported_exceptions.len == 0
}
