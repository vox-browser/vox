// Copyright (c) 2022-2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WorkerGlobalScope, DedicatedWorkerGlobalScope,
// SharedWorkerGlobalScope, Worker, SharedWorker, WorkerAgentParent,
// WorkletGlobalScope, ShadowRealmGlobalScope, and WorkerDebugConsoleClient.
@[has_globals]
module html

import css
import dom
import fetch
import page

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

pub struct WorkerRunTarget {
pub:
	worker        ?&Worker
	shared_worker ?&SharedWorker
}

pub type WorkerScriptFetchHook = fn(dom.URL, &ScriptingRealm) !&ClassicScript

pub type WorkerGlobalOwner = SerializedDocument | SerializedWorkerGlobalScope

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
	web_interfaces_initialized_  bool
	fonts_                       ?&css.FontFaceSet
	policy_container_            ?&PolicyContainer
	page_                        ?&page.Page
	owner_set_                   []WorkerGlobalOwner
}

pub fn WorkerGlobalScope.create(url dom.URL, worker_type WorkerType, name string, realm &ScriptingRealm) &WorkerGlobalScope {
	return &WorkerGlobalScope{
		realm: realm
		event_loop: EventLoop.create(.worker)
		url_: url
		worker_type: worker_type
		name_: name
		location_: WorkerLocation.create(url)
		navigator_: WorkerNavigator.create()
	}
}

pub fn (scope &WorkerGlobalScope) url() dom.URL {
	return scope.url_
}

pub fn (scope &WorkerGlobalScope) this_impl() &dom.EventTarget {
	return unsafe { &dom.EventTarget(scope) }
}

pub fn (scope &WorkerGlobalScope) self() &WorkerGlobalScope {
	return scope
}

pub fn (scope &WorkerGlobalScope) extract_an_origin() ?dom.Origin {
	origin := scope.url_.origin()
	return if origin.serialize() == 'opaque' { none } else { origin }
}

pub fn (mut scope WorkerGlobalScope) set_url(url dom.URL) {
	scope.url_ = url
}

pub fn (scope &WorkerGlobalScope) name() string {
	return scope.name_
}

pub fn (mut scope WorkerGlobalScope) set_name(name string) {
	scope.name_ = name
}

pub fn (scope &WorkerGlobalScope) type_() WorkerType {
	return scope.worker_type
}

pub fn (mut scope WorkerGlobalScope) set_type(type_ WorkerType) {
	scope.worker_type = type_
}

pub fn (scope &WorkerGlobalScope) is_closing() bool {
	return scope.closing_
}

pub fn (scope &WorkerGlobalScope) location() &WorkerLocation {
	return scope.location_
}

pub fn (mut scope WorkerGlobalScope) set_location(location &WorkerLocation) {
	scope.location_ = location
}

pub fn (scope &WorkerGlobalScope) navigator() &WorkerNavigator {
	return scope.navigator_
}

pub fn (mut scope WorkerGlobalScope) fonts() &css.FontFaceSet {
	if fonts := scope.fonts_ {
		return fonts
	}
	fonts := css.FontFaceSet.create()
	scope.fonts_ = fonts
	return fonts
}

pub fn (mut scope WorkerGlobalScope) policy_container() &PolicyContainer {
	if container := scope.policy_container_ {
		return container
	}
	container := &PolicyContainer{}
	scope.policy_container_ = container
	return container
}

pub fn (mut scope WorkerGlobalScope) initialize_policy_container(response &fetch.Response, environment &EnvironmentSettingsObject) {
	if fetch.is_local_url(scope.url_) && scope.url_.scheme() != 'blob' {
		// The native implementation has the same owner-set cloning FIXME.
		return
	}
	scope.policy_container_ = create_a_policy_container_from_a_fetch_response(response, environment)
}

pub enum CSPInitializationResult {
	allowed
	blocked
}

pub fn (mut scope WorkerGlobalScope) run_csp_initialization() CSPInitializationResult {
	container := scope.policy_container()
	mut result := CSPInitializationResult.allowed
	for policy in container.csp_list {
		if policy.disposition != .enforce {
			continue
		}
		for directive in policy.directives {
			if ascii_lowercase_string(directive.name) != 'sandbox' {
				continue
			}
			flags := parse_a_sandboxing_directive(SandboxingDirective(directive.value))
			if flags.contains(.sandboxed_scripts) || flags.contains(.sandboxed_origin) {
				result = .blocked
			}
		}
	}
	return result
}

pub fn (mut scope WorkerGlobalScope) initialize_web_interfaces_impl() {
	scope.web_interfaces_initialized_ = true
}

pub fn (mut scope WorkerGlobalScope) initialize_web_interfaces() {
	scope.initialize_web_interfaces_impl()
}

pub fn (scope &WorkerGlobalScope) page() ?&page.Page {
	return scope.page_
}

pub fn (mut scope WorkerGlobalScope) set_page(page_ &page.Page) {
	scope.page_ = page_
}

pub fn (scope &WorkerGlobalScope) owner_set() []WorkerGlobalOwner {
	return scope.owner_set_.clone()
}

pub fn (scope &WorkerGlobalScope) is_universal_global_scope_mixin() bool {
	_ = scope
	return true
}

pub fn (scope &WorkerGlobalScope) web_interfaces_initialized() bool {
	return scope.web_interfaces_initialized_
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
	unsafe { &dom.EventTarget(scope) }
	.set_event_handler_attribute('error', callback)
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

pub fn (mut scope DedicatedWorkerGlobalScope) initialize_web_interfaces_impl() {
	scope.WorkerGlobalScope.initialize_web_interfaces_impl()
}

pub fn (scope &DedicatedWorkerGlobalScope) post_message(message dom.JSValue, options StructuredSerializeOptions) ! {
	port := scope.internal_port_ or {
		return error('InvalidStateError: worker has no internal port')
	}

	port.post_message(message, options)!
}

pub fn (scope &DedicatedWorkerGlobalScope) set_onmessage(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }
	.set_event_handler_attribute('message', callback)
	if port := scope.internal_port_ {
		mut mutable_port := unsafe { &MessagePort(port) }
		mutable_port.start()
	}
}

pub fn (scope &DedicatedWorkerGlobalScope) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(scope) }.event_handler_attribute('message')
}

pub fn (scope &DedicatedWorkerGlobalScope) set_onmessageerror(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }
	.set_event_handler_attribute('messageerror', callback)
}

@[heap]
pub struct SharedWorkerGlobalScope {
	WorkerGlobalScope
pub:
	storage_key    string
	secure_context bool
pub mut:
	constructor_origin_ ?dom.Origin
	constructor_url_    dom.URL
	credentials_        fetch.CredentialsMode = .same_origin
}

__global html_shared_worker_global_scopes = []&SharedWorkerGlobalScope{}

pub fn all_shared_worker_global_scopes() []&SharedWorkerGlobalScope {
	return html_shared_worker_global_scopes.clone()
}

pub fn SharedWorkerGlobalScope.create(url dom.URL, options WorkerOptions, storage_key string, secure_context bool, realm &ScriptingRealm) &SharedWorkerGlobalScope {
	scope := &SharedWorkerGlobalScope{
		WorkerGlobalScope: *WorkerGlobalScope.create(url, options.type_, options.name, realm)
		storage_key: storage_key
		secure_context: secure_context
		constructor_origin_: url.origin()
		constructor_url_: url
		credentials_: match options.credentials {
			.omit { fetch.CredentialsMode.omit }
			.same_origin { fetch.CredentialsMode.same_origin }
			.include { fetch.CredentialsMode.include }
		}
	}
	html_shared_worker_global_scopes << scope
	return scope
}

pub fn (mut scope SharedWorkerGlobalScope) set_constructor_origin(origin dom.Origin) {
	scope.constructor_origin_ = origin
}

pub fn (scope &SharedWorkerGlobalScope) constructor_origin() dom.Origin {
	return scope.constructor_origin_ or { scope.url().origin() }
}

pub fn (mut scope SharedWorkerGlobalScope) set_constructor_url(url dom.URL) {
	scope.constructor_url_ = url
}

pub fn (scope &SharedWorkerGlobalScope) constructor_url() dom.URL {
	return scope.constructor_url_
}

pub fn (scope &SharedWorkerGlobalScope) credentials() fetch.CredentialsMode {
	return scope.credentials_
}

pub fn (mut scope SharedWorkerGlobalScope) set_credentials(credentials fetch.CredentialsMode) {
	scope.credentials_ = credentials
}

pub fn (mut scope SharedWorkerGlobalScope) close() {
	scope.close_a_worker()
	html_shared_worker_global_scopes = html_shared_worker_global_scopes.filter(voidptr(it) != voidptr(&scope))
}

pub fn (mut scope SharedWorkerGlobalScope) initialize_web_interfaces_impl() {
	scope.WorkerGlobalScope.initialize_web_interfaces_impl()
}

pub fn (scope &SharedWorkerGlobalScope) set_onconnect(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(scope) }
	.set_event_handler_attribute('connect', callback)
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
	agent_        ?&WorkerAgentParent
	terminated_   bool
}

pub fn Worker.construct_impl(script_url string, outside_settings &EnvironmentSettingsObject, options WorkerOptions) !&Worker {
	mut worker := Worker.create(script_url, outside_settings.api_base_url(), options, outside_settings.realm())!
	port := worker.outside_message_port() or {
		return error('InvalidStateError: worker has no outside message port')
	}
	run_a_worker(WorkerRunTarget{ worker: worker }, worker.script_url, outside_settings, port, options)!
	return worker
}

pub fn Worker.create(script_url string, base_url dom.URL, options WorkerOptions, realm &ScriptingRealm) !&Worker {
	url := dom.dom_url_parse(script_url, base_url, 'UTF-8') or {
		return error('SyntaxError: Worker constructed with invalid URL')
	}
	channel := MessageChannel.construct_impl()!
	mut worker := &Worker{
		script_url: url
		options: options
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
	if worker.terminated_ {
		return
	}
	worker.terminated_ = true
	if mut port := worker.outside_port_ { port.close() }
	if mut scope := worker.scope_ { scope.close() }
}

pub fn (worker &Worker) post_message(message dom.JSValue, options StructuredSerializeOptions) ! {
	if worker.terminated_ {
		return
	}
	port := worker.outside_port_ or { return }
	port.post_message(message, options)!
}

pub fn (worker &Worker) outside_message_port() ?&MessagePort {
	return worker.outside_port_
}

pub fn (mut worker Worker) set_agent(agent &WorkerAgentParent) {
	worker.agent_ = agent
}

pub fn (worker &Worker) this_event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(worker) }
}

pub fn (worker &Worker) scope() ?&DedicatedWorkerGlobalScope {
	return worker.scope_
}

pub fn (worker &Worker) set_onmessage(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(worker) }
	.set_event_handler_attribute('message', callback)
}

pub fn (worker &Worker) onmessage() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(worker) }.event_handler_attribute('message')
}

pub fn (worker &Worker) set_onmessageerror(callback ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(worker) }
	.set_event_handler_attribute('messageerror', callback)
}

pub fn (worker &Worker) set_onerror(callback ?&dom.CallbackType) {
	set_abstract_worker_onerror(unsafe { &dom.EventTarget(worker) }, callback)
}

// https://html.spec.whatwg.org/multipage/workers.html#run-a-worker
pub fn run_a_worker(target WorkerRunTarget, url dom.URL, outside_settings &EnvironmentSettingsObject, port &MessagePort, options WorkerOptions) ! {
	_ = outside_settings
	if worker := target.worker {
		mut agent := WorkerAgentParent.create(url, options, port, worker.this_event_target())
		agent.initialize()!
		mut mutable_worker := unsafe { &Worker(worker) }
		mutable_worker.set_agent(agent)
		return
	}
	if worker := target.shared_worker {
		mut agent := WorkerAgentParent.create(url, options, port, worker.this_event_target())
		agent.initialize()!
		mut mutable_worker := unsafe { &SharedWorker(worker) }
		mutable_worker.set_agent(agent)
		return
	}
	return error('InvalidStateError: run a worker requires a Worker or SharedWorker')
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
	agent_ ?&WorkerAgentParent
}

pub type SharedWorkerOptionsValue = WorkerOptions | string

pub fn SharedWorker.construct_impl(script_url string, options_value SharedWorkerOptionsValue, outside_settings &EnvironmentSettingsObject) !&SharedWorker {
	options := match options_value {
		string {
			WorkerOptions{
				name: options_value
			}
		}
		WorkerOptions { options_value }
	}
	mut worker := SharedWorker.create(script_url, outside_settings.api_base_url(), options, outside_settings.origin().serialize(), outside_settings.is_secure_context(), outside_settings.realm())!
	run_a_worker(WorkerRunTarget{ shared_worker: worker }, worker.script_url, outside_settings, worker.port(), options)!
	return worker
}

pub fn SharedWorker.create(script_url string, base_url dom.URL, options WorkerOptions, storage_key string, secure_context bool, realm &ScriptingRealm) !&SharedWorker {
	url := dom.dom_url_parse(script_url, base_url, 'UTF-8') or {
		return error('SyntaxError: SharedWorker constructed with invalid URL')
	}
	mut matching_scope := ?&SharedWorkerGlobalScope(none)
	for scope in html_shared_worker_global_scopes {
		if !scope.is_closing() && scope.storage_key == storage_key && scope.url() == url && scope.name() == options.name {
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
		options: options
		port_: outside
		scope_: scope
	}
	mut event := MessageEvent.create('connect', MessageEventInit{
		data: dom.js_string('')
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

pub fn (mut worker SharedWorker) set_agent(agent &WorkerAgentParent) {
	worker.agent_ = agent
}

pub fn (worker &SharedWorker) this_event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(worker) }
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
	message_port                         ?&MessagePort
	started                              bool
	ipc_callbacks_configured_            bool
	worker_script_load_failure_callback_ ?fn()
}

pub fn WorkerAgentParent.create(url dom.URL, options WorkerOptions, outside_port &MessagePort, worker_event_target &dom.EventTarget) &WorkerAgentParent {
	return &WorkerAgentParent{
		url: url
		options: options
		outside_port: outside_port
		worker_event_target: worker_event_target
	}
}

pub fn (mut parent WorkerAgentParent) initialize() ! {
	mut port := MessagePort.create()
	port.entangle_with(parent.outside_port)
	parent.message_port = port
	mut outside := parent.outside_port
	outside.start()
	parent.setup_worker_ipc_callbacks()
	parent.started = true
}

pub fn (mut parent WorkerAgentParent) setup_worker_ipc_callbacks() {
	target := parent.worker_event_target
	parent.worker_script_load_failure_callback_ = fn [target] () {
		event := dom.Event.create('error', dom.EventInit{})
		target.dispatch_event(event)
	}
	parent.ipc_callbacks_configured_ = true
}

pub fn (parent &WorkerAgentParent) worker_script_load_failure() {
	if callback := parent.worker_script_load_failure_callback_ {
		callback()
		return
	}
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
pub mut:
	web_interfaces_initialized_ bool
}

pub fn ShadowRealmGlobalScope.create(realm &ScriptingRealm) &ShadowRealmGlobalScope {
	return &ShadowRealmGlobalScope{
		realm: realm
	}
}

pub fn (mut scope ShadowRealmGlobalScope) initialize_web_interfaces() {
	scope.web_interfaces_initialized_ = true
}

pub fn (scope &ShadowRealmGlobalScope) this_impl() &dom.EventTarget {
	return unsafe { &dom.EventTarget(scope) }
}

pub fn (scope &ShadowRealmGlobalScope) self() &ShadowRealmGlobalScope {
	return scope
}

pub fn (scope &ShadowRealmGlobalScope) is_universal_global_scope_mixin() bool {
	_ = scope
	return true
}
