// Copyright (c) 2022-2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WorkerGlobalScope, DedicatedWorkerGlobalScope,
// SharedWorkerGlobalScope, Worker, SharedWorker, WorkerAgentParent,
// WorkletGlobalScope, ShadowRealmGlobalScope, and WorkerDebugConsoleClient.
@[has_globals]
module html

import dom

pub enum WorkerType {
	classic
	module_
}

pub enum WorkerCredentials {
	omit
	same_origin
	include
}

pub struct WorkerOptions {
pub:
	type_       WorkerType
	credentials WorkerCredentials = .same_origin
	name        string
}

pub type WorkerScriptFetchHook = fn (dom.URL, &ScriptingRealm) !&ClassicScript

@[heap]
pub struct WorkerGlobalScope {
	dom.EventTarget
pub:
	realm      &ScriptingRealm
	event_loop &EventLoop
pub mut:
	url_                         dom.URL
	worker_type                  WorkerType
	name_                        string
	closing_                     bool
	location_                    &WorkerLocation
	navigator_                   &WorkerNavigator
	internal_port_               ?&MessagePort
	policy_container_initialized bool
}

pub fn WorkerGlobalScope.create(url dom.URL, worker_type WorkerType, name string, realm &ScriptingRealm) &WorkerGlobalScope {
	return &WorkerGlobalScope{
		realm:       realm
		event_loop:  EventLoop.create(.worker)
		url_:        url
		worker_type: worker_type
		name_:       name
		location_:   WorkerLocation.create(url)
		navigator_:  WorkerNavigator.create()
	}
}

pub fn (scope &WorkerGlobalScope) url() dom.URL {
	return scope.url_
}

pub fn (scope &WorkerGlobalScope) name() string {
	return scope.name_
}

pub fn (scope &WorkerGlobalScope) is_closing() bool {
	return scope.closing_
}

pub fn (scope &WorkerGlobalScope) location() &WorkerLocation {
	return scope.location_
}

pub fn (scope &WorkerGlobalScope) navigator() &WorkerNavigator {
	return scope.navigator_
}

pub fn (mut scope WorkerGlobalScope) set_internal_port(port &MessagePort) {
	scope.internal_port_ = port
	mut mutable_port := unsafe { &MessagePort(port) }
	mutable_port.set_worker_event_target(unsafe { &dom.EventTarget(&scope) })
}

fn worker_should_remove_task(task &Task) bool {
	return task.source != .posted_message
}

pub fn (mut scope WorkerGlobalScope) close_a_worker() {
	mut queue := scope.event_loop.task_queue()
	queue.remove_tasks_matching(worker_should_remove_task)
	scope.closing_ = true
}

pub fn (mut scope WorkerGlobalScope) import_scripts(urls []string, fetch_script WorkerScriptFetchHook) ! {
	if scope.worker_type == .module_ {
		return error('TypeError: importScripts is unavailable in module workers')
	}
	mut records := []dom.URL{cap: urls.len}
	for input in urls {
		records << (dom.dom_url_parse(input, scope.url_, 'UTF-8') or {
			return error('SyntaxError: invalid worker script URL')
		})
	}
	for record in records {
		mut script := fetch_script(record, scope.realm)!
		script.run(.yes)!
	}
}

pub fn (scope &WorkerGlobalScope) set_onerror(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }.set_event_handler_attribute('error', callback)
}

pub fn (scope &WorkerGlobalScope) onerror() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(scope) }.event_handler_attribute('error')
}

@[heap]
pub struct DedicatedWorkerGlobalScope {
	WorkerGlobalScope
}

pub fn DedicatedWorkerGlobalScope.create(url dom.URL, options WorkerOptions, realm &ScriptingRealm) &DedicatedWorkerGlobalScope {
	return &DedicatedWorkerGlobalScope{
		WorkerGlobalScope: *WorkerGlobalScope.create(url, options.type_, options.name, realm)
	}
}

pub fn (mut scope DedicatedWorkerGlobalScope) close() {
	scope.close_a_worker()
}

pub fn (scope &DedicatedWorkerGlobalScope) post_message(message dom.JSValue, options StructuredSerializeOptions) ! {
	port := scope.internal_port_ or {
		return error('InvalidStateError: worker has no internal port')
	}

	port.post_message(message, options)!
}

pub fn (scope &DedicatedWorkerGlobalScope) set_onmessage(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }.set_event_handler_attribute('message', callback)
	if port := scope.internal_port_ {
		mut mutable_port := unsafe { &MessagePort(port) }
		mutable_port.start()
	}
}

pub fn (scope &DedicatedWorkerGlobalScope) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(scope) }.event_handler_attribute('message')
}

pub fn (scope &DedicatedWorkerGlobalScope) set_onmessageerror(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }.set_event_handler_attribute('messageerror', callback)
}

@[heap]
pub struct SharedWorkerGlobalScope {
	WorkerGlobalScope
pub:
	storage_key    string
	secure_context bool
}

__global html_shared_worker_global_scopes = []&SharedWorkerGlobalScope{}

pub fn SharedWorkerGlobalScope.create(url dom.URL, options WorkerOptions, storage_key string, secure_context bool, realm &ScriptingRealm) &SharedWorkerGlobalScope {
	scope := &SharedWorkerGlobalScope{
		WorkerGlobalScope: *WorkerGlobalScope.create(url, options.type_, options.name, realm)
		storage_key:       storage_key
		secure_context:    secure_context
	}
	html_shared_worker_global_scopes << scope
	return scope
}

pub fn (mut scope SharedWorkerGlobalScope) close() {
	scope.close_a_worker()
}

pub fn (scope &SharedWorkerGlobalScope) set_onconnect(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }.set_event_handler_attribute('connect', callback)
}

pub fn (scope &SharedWorkerGlobalScope) onconnect() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(scope) }.event_handler_attribute('connect')
}

@[heap]
pub struct Worker {
	dom.EventTarget
pub:
	script_url dom.URL
	options    WorkerOptions
pub mut:
	outside_port_ ?&MessagePort
	scope_        ?&DedicatedWorkerGlobalScope
	terminated_   bool
}

pub fn Worker.create(script_url string, base_url dom.URL, options WorkerOptions, realm &ScriptingRealm) !&Worker {
	url := dom.dom_url_parse(script_url, base_url, 'UTF-8') or {
		return error('SyntaxError: Worker constructed with invalid URL')
	}
	channel := MessageChannel.construct_impl()!
	mut worker := &Worker{
		script_url:    url
		options:       options
		outside_port_: channel.port1()
	}
	mut scope := DedicatedWorkerGlobalScope.create(url, options, realm)
	scope.set_internal_port(channel.port2())
	worker.scope_ = scope
	mut outside_port := channel.port1()
	outside_port.set_worker_event_target(unsafe { &dom.EventTarget(worker) })
	outside_port.start()
	return worker
}

pub fn (mut worker Worker) terminate() {
	if worker.terminated_ { return }
	worker.terminated_ = true
	if mut port := worker.outside_port_ { port.close() }
	if mut scope := worker.scope_ { scope.close() }
}

pub fn (worker &Worker) post_message(message dom.JSValue, options StructuredSerializeOptions) ! {
	if worker.terminated_ { return }
	port := worker.outside_port_ or { return }
	port.post_message(message, options)!
}

pub fn (worker &Worker) outside_message_port() ?&MessagePort {
	return worker.outside_port_
}

pub fn (worker &Worker) scope() ?&DedicatedWorkerGlobalScope {
	return worker.scope_
}

pub fn (worker &Worker) set_onmessage(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(worker) }.set_event_handler_attribute('message', callback)
}

pub fn (worker &Worker) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(worker) }.event_handler_attribute('message')
}

pub fn (worker &Worker) set_onmessageerror(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(worker) }.set_event_handler_attribute('messageerror', callback)
}

pub fn (worker &Worker) set_onerror(callback ?&dom.CallbackType) {
	set_abstract_worker_onerror(unsafe { &dom.EventTarget(worker) }, callback)
}

@[heap]
pub struct SharedWorker {
	dom.EventTarget
pub:
	script_url dom.URL
	options    WorkerOptions
pub mut:
	port_  &MessagePort
	scope_ &SharedWorkerGlobalScope
}

pub fn SharedWorker.create(script_url string, base_url dom.URL, options WorkerOptions, storage_key string, secure_context bool, realm &ScriptingRealm) !&SharedWorker {
	url := dom.dom_url_parse(script_url, base_url, 'UTF-8') or {
		return error('SyntaxError: SharedWorker constructed with invalid URL')
	}
	mut matching_scope := ?&SharedWorkerGlobalScope(none)
	for scope in html_shared_worker_global_scopes {
		if !scope.is_closing() && scope.storage_key == storage_key && scope.url() == url
			&& scope.name() == options.name {
			if scope.secure_context != secure_context {
				return error('SecurityError: shared worker secure-context mismatch')
			}
			matching_scope = scope
			break
		}
	}
	scope := matching_scope or {
		SharedWorkerGlobalScope.create(url, options, storage_key, secure_context, realm)
	}

	channel := MessageChannel.construct_impl()!
	mut outside := channel.port1()
	mut inside := channel.port2()
	outside.start()
	inside.start()
	worker := &SharedWorker{
		script_url: url
		options:    options
		port_:      outside
		scope_:     scope
	}
	mut event := MessageEvent.create('connect', MessageEventInit{
		data:  dom.js_string('')
		ports: [inside]
	})
	event.set_is_trusted(true)
	target := unsafe { &dom.EventTarget(scope) }
	target.dispatch_event(unsafe { &dom.Event(event) })
	return worker
}

pub fn (worker &SharedWorker) port() &MessagePort {
	return worker.port_
}

pub fn (worker &SharedWorker) scope() &SharedWorkerGlobalScope {
	return worker.scope_
}

@[heap]
pub struct WorkerAgentParent {
pub:
	url                 dom.URL
	options             WorkerOptions
	outside_port        &MessagePort
	worker_event_target &dom.EventTarget
pub mut:
	message_port ?&MessagePort
	started      bool
}

pub fn WorkerAgentParent.create(url dom.URL, options WorkerOptions, outside_port &MessagePort, worker_event_target &dom.EventTarget) &WorkerAgentParent {
	return &WorkerAgentParent{
		url:                 url
		options:             options
		outside_port:        outside_port
		worker_event_target: worker_event_target
	}
}

pub fn (mut parent WorkerAgentParent) initialize() ! {
	mut port := MessagePort.create()
	port.entangle_with(parent.outside_port)
	parent.message_port = port
	mut outside := parent.outside_port
	outside.start()
	parent.started = true
}

pub fn (parent &WorkerAgentParent) worker_script_load_failure() {
	event := dom.Event.create('error', dom.EventInit{})
	parent.worker_event_target.dispatch_event(event)
}

pub enum WorkerConsoleLogLevel {
	log
	info
	warn
	error
	trace
	group
	group_collapsed
}

pub struct WorkerDebugConsoleClient {
pub mut:
	group_stack_depth int
	output            []string
}

pub fn (mut client WorkerDebugConsoleClient) clear() {
	client.output.clear()
	client.group_stack_depth = 0
}

pub fn (mut client WorkerDebugConsoleClient) end_group() {
	if client.group_stack_depth > 0 { client.group_stack_depth-- }
}

pub fn (mut client WorkerDebugConsoleClient) printer(level WorkerConsoleLogLevel, values []string) {
	indent := ' '.repeat(client.group_stack_depth * 2)
	text := values.join(' ')
	client.output << '${indent}${text}'
	if level in [.group, .group_collapsed] { client.group_stack_depth++ }
}

@[heap]
pub struct WorkletGlobalScope {
pub:
	realm &ScriptingRealm
}

pub fn WorkletGlobalScope.create(realm &ScriptingRealm) &WorkletGlobalScope {
	return &WorkletGlobalScope{
		realm: realm
	}
}

@[heap]
pub struct ShadowRealmGlobalScope {
	dom.EventTarget
pub:
	realm &ScriptingRealm
}

pub fn ShadowRealmGlobalScope.create(realm &ScriptingRealm) &ShadowRealmGlobalScope {
	return &ShadowRealmGlobalScope{
		realm: realm
	}
}
