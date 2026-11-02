module browserjs

import dom
import fetch
import html
import http
import platform
import time

@[heap]
struct WorkerAgentTestNetwork {
mut:
	sources map[string]string
	redirects map[string]string
	headers []http.Header
	mime string = 'text/javascript'
	requests []&fetch.Request
}

@[heap]
struct WorkerAgentTestErrors {
mut:
	messages []string
}

fn worker_agent_test_outside() html.SerializedEnvironmentSettingsObject {
	url := dom.URL{value: 'https://worker-agent.test/original'}
	return html.SerializedEnvironmentSettingsObject{
		creation_url: url
		api_base_url: dom.URL{value: 'https://worker-agent.test/assets/'}
		origin: url.origin()
		policy_container: html.SerializedPolicyContainer{
			referrer_policy: .strict_origin_when_cross_origin
		}
		global: html.SerializedWindow{associated_document: html.SerializedDocument{
			url: dom.URL{value: 'https://worker-agent.test/maps/current?lang=ru#private'}
			relevant_settings_object_is_secure_context: true
		}}
	}
}

fn worker_agent_test_transport(state_ptr &WorkerAgentTestNetwork) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn [state_ptr] (request &fetch.Request) !&fetch.Response {
			mut state := unsafe { &WorkerAgentTestNetwork(state_ptr) }
			state.requests << request.clone()
			url := request.current_url().serialize()
			mut response := fetch.Response.create()
			if target := state.redirects[url] {
				response.status = 302
				response.header_list.append(http.Header{name: 'Location', value: target})
				return response
			}
			response.header_list.append(http.Header{name: 'Content-Type', value: state.mime})
			for header in state.headers { response.header_list.append(header) }
			if source := state.sources[url] {
				response.set_body_bytes(source.bytes())
			} else {
				response.status = 404
				response.set_body_bytes('missing'.bytes())
			}
			return response
		}
	}
}

fn worker_agent_test_create(state &WorkerAgentTestNetwork) !&WorkerAgentRuntime {
	return WorkerAgentRuntime.create(dom.URL{value: 'https://worker-agent.test/entry.js'},
		html.WorkerOptions{name: 'map content'}, worker_agent_test_outside(), 12,
		worker_agent_test_transport(state))
}

fn test_worker_agent_loads_redirected_entry_and_imports_in_its_actual_worker_realm() {
	state := &WorkerAgentTestNetwork{
		redirects: {'https://worker-agent.test/entry.js': '/agents/main.js'}
		sources: {
			'https://worker-agent.test/agents/main.js': 'globalThis.order=["entry"];importScripts("helper.js");postMessage({order:order.join(),url:location.href,name,origin,secure:isSecureContext});'
			'https://worker-agent.test/agents/helper.js': 'order.push("Санкт-Петербург 😀");'
		}
		headers: [http.Header{name: 'Referrer-Policy', value: 'no-referrer'}]
	}
	mut agent := worker_agent_test_create(state)!
	defer { agent.close() }
	assert agent.state() == .prepared
	assert !agent.environment.settings.execution_ready()
	assert agent.environment.settings.responsible_document() == none
	agent.load_entry()!
	assert agent.state() == .ready
	settings := agent.environment.settings
	assert settings.execution_ready()
	assert settings.api_base_url().serialize() == 'https://worker-agent.test/agents/main.js'
	assert settings.environment().creation_url == settings.api_base_url()
	assert settings.policy_container().referrer_policy == .no_referrer
	assert agent.environment.global_scope.owner_set().len == 1
	assert state.requests.len == 3
	assert (state.requests[0].destination or { panic("Missing script destination") }) == fetch.Destination.worker
	assert state.requests[0].reserved_client != none
	assert (state.requests[0].header_list.get('Referer') or { panic('Missing entry referrer') }) == 'https://worker-agent.test/maps/current?lang=ru'
	assert (state.requests[2].destination or { panic("Missing script destination") }) == fetch.Destination.script
	assert (state.requests[2].client_creation_url or { panic('Missing import client creation URL') }).serialize() == 'https://worker-agent.test/agents/main.js'
	assert !state.requests[2].header_list.contains('Referer')
	mut runtime := agent.runtime
	message := agent.global.transfer.deserialize(decode_worker_message(agent.take_outgoing()[0])!)!
	runtime.define_value_host_function('__entryMessage', fn [message] (_ voidptr, _ []voidptr) !voidptr { return message })!
	assert runtime.evaluate_host('const value=__entryMessage();value.order==="entry,Санкт-Петербург 😀"&&value.url===location.href&&value.name==="map content"&&value.origin==="https://worker-agent.test"&&value.secure&&typeof document==="undefined"&&typeof window==="undefined"')! == 'true'
	assert settings.realm().active_classic_script_ == none
	assert settings.realm().script_execution_depth == 0
}

fn test_worker_agent_posts_owned_transfer_messages_only_after_its_entry_handler_is_ready() {
	state := &WorkerAgentTestNetwork{sources: {
		'https://worker-agent.test/entry.js': 'onmessage=event=>{const value=event.data;value.trusted=event.isTrusted;value.receiver=value.buffer instanceof ArrayBuffer&&value.view instanceof Uint8Array&&value.view.buffer===value.buffer;postMessage(value,[value.buffer])};'
	}}
	mut agent := worker_agent_test_create(state)!
	defer { agent.close() }
	mut sender := Runtime.create()
	defer { sender.close() }
	transfer := ArrayBufferTransferBridge.create(sender)!
	value := sender.evaluate_host_value('globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);globalThis.value={buffer,view:new Uint8Array(buffer,1)};value.self=value;value')!
	record := transfer.serialize(value, [sender.evaluate_host_value('buffer')!])!
	agent.queue_message(encode_worker_message(record)!)!
	agent.process()
	assert agent.take_outgoing().len == 0
	agent.load_entry()!
	agent.process()
	frames := agent.take_outgoing()
	assert frames.len == 1
	message := transfer.deserialize(decode_worker_message(frames[0])!)!
	sender.define_value_host_function('__agentMessage', fn [message] (_ voidptr, _ []voidptr) !voidptr { return message })!
	assert sender.evaluate_host('const actual=__agentMessage();buffer.detached&&actual.self===actual&&actual.trusted&&actual.receiver&&actual.buffer instanceof ArrayBuffer&&actual.view.buffer===actual.buffer&&Array.from(actual.view).join()==="128,255"')! == 'true'
	assert agent.runtime.evaluate_host('typeof Worker==="undefined"&&typeof window==="undefined"')! == 'true'
}

fn test_worker_agent_rejects_bad_mime_missing_entries_and_response_sandbox_before_execution() {
	for failure in ['missing', 'mime', 'sandbox-scripts', 'sandbox-origin'] {
		mut state := &WorkerAgentTestNetwork{}
		if failure != 'missing' { state.sources['https://worker-agent.test/entry.js'] = 'postMessage("must not execute");' }
		if failure == 'mime' { state.mime = 'text/plain' }
		if failure.starts_with('sandbox') {
			state.headers << http.Header{name: 'Content-Security-Policy', value: if failure == 'sandbox-scripts' { 'sandbox allow-same-origin' } else { 'sandbox allow-scripts' }}
		}
		mut agent := worker_agent_test_create(state)!
		if _ := agent.load_entry() { assert false, failure }
		assert agent.state() == .failed
		assert !agent.environment.settings.execution_ready()
		assert agent.environment.settings.environment().discarded
		assert agent.environment.global_scope.is_closing()
		assert agent.runtime.closed && agent.fetcher.closed
		assert agent.take_outgoing().len == 0
		agent.close()
	}
}

fn test_worker_agent_distinguishes_parse_failure_from_a_reported_runtime_exception() {
	for source in ['postMessage("unreachable");const = ;', 'onmessage=event=>postMessage(event.data);throw new Error("entry failed");'] {
		state := &WorkerAgentTestNetwork{sources: {'https://worker-agent.test/entry.js': source}}
		mut agent := worker_agent_test_create(state)!
		defer { agent.close() }
		if source.contains('const =') {
			if _ := agent.load_entry() { assert false }
			assert agent.state() == .failed && !agent.environment.settings.execution_ready()
			assert agent.take_outgoing().len == 0
		} else {
			observed := &WorkerAgentTestErrors{}
			agent.environment.global_scope.this_impl().add_event_listener_without_options('error',
				dom.IDLEventListener.create(&dom.CallbackType{
					handle_event: fn [observed] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
						event := unsafe { &dom.ErrorEvent(base_event) }
						mut errors := unsafe { observed }
						errors.messages << event.message()
						mut mutable_event := unsafe { base_event }
						mutable_event.prevent_default()
						return dom.js_undefined()
					}
				}))
			agent.load_entry()!
			assert agent.state() == .ready && !agent.runtime.closed
			assert observed.messages.len == 1
			assert observed.messages[0].contains('entry failed')
			assert agent.runtime.evaluate_host('typeof onmessage==="function"')! == 'true'
		}
		if _ := agent.load_entry() { assert false }
	}
}

fn test_worker_agent_runs_fetch_timer_and_microtasks_on_its_worker_loop_and_cancels_on_close() {
	state := &WorkerAgentTestNetwork{sources: {
		'https://worker-agent.test/entry.js': r'globalThis.order=[];queueMicrotask(()=>order.push("microtask"));setTimeout(()=>order.push("timer"),0);fetch("./tile.bin").then(response=>response.text()).then(text=>{order.push(text);globalThis.finished=true});globalThis.interval=setInterval(()=>{},1);'
		'https://worker-agent.test/tile.bin': 'tile bytes'
	}}
	mut agent := worker_agent_test_create(state)!
	agent.load_entry()!
	deadline := time.sys_mono_now() + 5 * time.second
	for agent.runtime.evaluate_host('globalThis.finished===true&&order.includes("timer")')! != 'true' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
		agent.process()
	}
	assert agent.runtime.evaluate_host('finished&&order[0]==="microtask"&&order.includes("timer")&&order.includes("tile bytes")&&typeof fetch==="function"&&typeof TextDecoder==="function"&&typeof TextEncoder==="function"&&typeof Blob==="function"&&typeof URL==="function"&&typeof URLSearchParams==="function"&&typeof TransformStream==="function"&&typeof MessageChannel==="function"&&typeof crypto.getRandomValues==="function"')! == 'true'
	assert state.requests.len == 2
	agent.close()
	assert agent.state() == .closed && agent.runtime.closed && agent.fetcher.closed
	assert agent.runtime.protected_values_.len == 0
	assert voidptr(agent.runtime) !in timer_host_bindings_
	assert voidptr(agent.runtime) !in fetch_bindings_
	assert voidptr(agent.runtime) !in worker_global_bindings_
	agent.queue_message([u8(255)])!
	agent.process()
	agent.close()
}

fn test_worker_agent_retains_startup_and_received_frames_across_caller_and_delivery_scratch() {
	mut caller := platform.begin_thread_scratch('worker agent caller')
	persistent := platform.enter_persistent()
	state := &WorkerAgentTestNetwork{sources: {'https://worker-agent.test/entry.js': 'onmessage=event=>postMessage({text:event.data.text,url:location.href,name});'}}
	platform.leave_persistent(persistent)
	mut agent := worker_agent_test_create(state)!
	agent.load_entry()!
	mut sender := Runtime.create()
	transfer := ArrayBufferTransferBridge.create(sender)!
	value := sender.evaluate_host_value('({text:"Санкт-Петербург 😀"})')!
	agent.queue_message(encode_worker_message(transfer.serialize(value, [])!)!)!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker agent delivery')
	agent.process()
	frames := agent.take_outgoing()
	delivery.finish()
	assert frames.len == 1
	message := transfer.deserialize(decode_worker_message(frames[0])!)!
	sender.define_value_host_function('__retainedAgentMessage', fn [message] (_ voidptr, _ []voidptr) !voidptr { return message })!
	assert sender.evaluate_host('const value=__retainedAgentMessage();value.text==="Санкт-Петербург 😀"&&value.url==="https://worker-agent.test/entry.js"&&value.name==="map content"')! == 'true'
	agent.close()
	sender.close()
}
