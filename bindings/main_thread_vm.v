// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/MainThreadVM.{h,cpp}. LibJS execution is supplied by
// typed callbacks, while HTML host-hook ordering, realm bookkeeping, promise
// jobs, module resolution, mutation microtasks, and custom-element reactions
// run against the translated HTML and DOM runtimes.
@[has_globals]
module bindings

import dom
import html

struct AgentSelection {
	agent        &html.Agent
	window_agent ?&html.SimilarOriginWindowAgent
}

fn create_agent(type_ html.AgentType) !AgentSelection {
	return match type_ {
		.similar_origin_window {
			window_agent := html.relevant_similar_origin_window_agent()
			AgentSelection{
				agent:        unsafe { &html.Agent(window_agent) }
				window_agent: window_agent
			}
		}
		.dedicated_worker, .shared_worker {
			worker := html.WorkerAgent.create(.yes)
			AgentSelection{
				agent: unsafe { &html.Agent(worker) }
			}
		}
		.service_worker {
			worker := html.WorkerAgent.create(.no)
			AgentSelection{
				agent: unsafe { &html.Agent(worker) }
			}
		}
		.worklet {
			return error('Worklet agents are not initialized by MainThreadVM upstream')
		}
	}
}

pub enum PrivateElementTargetKind {
	ordinary
	window_proxy
	location
}

pub enum PromiseRejectionOperation {
	reject
	handle
}

pub type JobCallbackBehavior = fn (dom.JSValue, []dom.JSValue) !dom.JSValue

pub type PromiseJob = fn () !dom.JSValue

pub type FinalizationRegistryCleanupJob = fn () !

pub type CreateGlobalObject = fn (&html.ScriptingRealm) voidptr

@[heap]
pub struct WebExecutionContext {
pub:
	realm         &html.ScriptingRealm
	active_script ?&html.Script
}

@[heap]
pub struct WebEngineCustomJobCallbackData {
pub:
	incumbent_settings    &html.EnvironmentSettingsObject
	active_script_context ?&WebExecutionContext
}

@[heap]
pub struct JobCallback {
pub:
	callback    JobCallbackBehavior @[required]
	custom_data &WebEngineCustomJobCallbackData
}

@[heap]
pub struct MainThreadVM {
pub:
	agent_type   html.AgentType
	agent        &html.Agent
	window_agent ?&html.SimilarOriginWindowAgent
pub mut:
	active_script_                  ?&html.Script
	execution_context_stack_        []&WebExecutionContext
	unimplemented_property_accesses []string
	unrecognized_date_strings       []string
}

__global (
	bindings_main_thread_vm_value                    &MainThreadVM
	bindings_main_thread_similar_origin_window_agent &html.SimilarOriginWindowAgent
	bindings_main_thread_principal_realm             &html.ScriptingRealm
)

fn main_thread_vm_ptr() ?&MainThreadVM {
	if bindings_main_thread_vm_value == unsafe { nil } {
		return none
	}
	return bindings_main_thread_vm_value
}

fn main_thread_similar_origin_window_agent_ptr() ?&html.SimilarOriginWindowAgent {
	if bindings_main_thread_similar_origin_window_agent == unsafe { nil } {
		return none
	}
	return bindings_main_thread_similar_origin_window_agent
}

pub fn initialize_main_thread_vm(type_ html.AgentType) !&MainThreadVM {
	if main_thread_vm_ptr() != none {
		return error('MainThreadVM is already initialized')
	}
	selection := create_agent(type_)!
	bindings_main_thread_vm_value = &MainThreadVM{
		agent_type:   type_
		agent:        selection.agent
		window_agent: selection.window_agent
	}
	if window_agent := selection.window_agent {
		bindings_main_thread_similar_origin_window_agent = window_agent
	}
	return bindings_main_thread_vm_value
}

pub fn main_thread_vm() &MainThreadVM {
	return main_thread_vm_ptr() or { panic('MainThreadVM is not initialized') }
}

pub fn main_thread_similar_origin_window_agent() &html.SimilarOriginWindowAgent {
	return main_thread_similar_origin_window_agent_ptr() or {
		panic('main thread does not have a similar-origin window agent')
	}
}

pub fn reset_main_thread_vm_for_testing() {
	bindings_main_thread_vm_value = unsafe { nil }
	bindings_main_thread_similar_origin_window_agent = unsafe { nil }
	bindings_main_thread_principal_realm = unsafe { nil }
}

pub fn (mut vm MainThreadVM) set_active_script(script ?&html.Script) {
	vm.active_script_ = script
}

// https://html.spec.whatwg.org/multipage/webappapis.html#active-script
pub fn active_script() ?&html.Script {
	if main_thread_vm_ptr() == none {
		return none
	}
	return bindings_main_thread_vm_value.active_script_
}

pub fn (mut vm MainThreadVM) note_unimplemented_property_access(class_name string, property_name string) {
	vm.unimplemented_property_accesses << '${class_name}.${property_name}'
}

// https://html.spec.whatwg.org/multipage/webappapis.html#the-hostensurecanaddprivateelement-implementation
pub fn (_ &MainThreadVM) host_ensure_can_add_private_element(target PrivateElementTargetKind) ! {
	if target in [.window_proxy, .location] {
		return error('TypeError: Cannot add private elements to window or location object')
	}
}

// The host receives the translated CSP engine's decision from the active global-object embedding.
pub fn (_ &MainThreadVM) host_ensure_can_compile_strings(csp_allows_compilation bool) ! {
	if !csp_allows_compilation {
		return error('EvalError: string compilation was blocked by Content Security Policy')
	}
}

pub struct TrustedScript {
pub:
	data string
}

pub fn (_ &MainThreadVM) host_get_code_for_eval(argument ?TrustedScript) ?string {
	trusted_script := argument or { return none }
	return trusted_script.data
}

// https://html.spec.whatwg.org/multipage/webappapis.html#the-hostpromiserejectiontracker-implementation
pub fn (_ &MainThreadVM) host_promise_rejection_tracker(mut scope html.UniversalGlobalScopeMixin, promise &dom.Promise, operation PromiseRejectionOperation) {
	match operation {
		.reject {
			scope.push_onto_about_to_be_notified_rejected_promises_list(promise)
		}
		.handle {
			if scope.remove_from_about_to_be_notified_rejected_promises_list(promise) {
				return
			}
			if !scope.remove_from_outstanding_rejected_promises_weak_set(promise) {
				return
			}
			scope_pointer := &scope
			html.queue_a_microtask(none, fn [scope_pointer, promise] () {
				event := dom.PromiseRejectionEvent.create('rejectionhandled', dom.PromiseRejectionEventInit{
					promise: dom.js_object(voidptr(promise))
					reason:  promise.result()
				})
				scope_pointer.event_target.dispatch_event(unsafe { &dom.Event(event) })
			})
		}
	}
}

// https://html.spec.whatwg.org/multipage/webappapis.html#hostmakejobcallback
pub fn (vm &MainThreadVM) host_make_job_callback(callback JobCallbackBehavior, incumbent_settings &html.EnvironmentSettingsObject) &JobCallback {
	mut active_context := ?&WebExecutionContext(none)
	if script := vm.active_script_ {
		active_context = &WebExecutionContext{
			realm:         script.realm
			active_script: script
		}
	}
	return &JobCallback{
		callback: callback
		custom_data: &WebEngineCustomJobCallbackData{
			incumbent_settings: incumbent_settings
			active_script_context: active_context
		}
	}
}

fn (mut vm MainThreadVM) finish_job_callback(callback &JobCallback, pushed_context bool) {
	if pushed_context && vm.execution_context_stack_.len > 0 {
		vm.execution_context_stack_.delete_last()
	}
	mut realm := unsafe { &html.ScriptingRealm(callback.custom_data.incumbent_settings.realm()) }
	html.clean_up_after_running_callback(mut realm)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#hostcalljobcallback
pub fn (mut vm MainThreadVM) host_call_job_callback(callback &JobCallback, this_value dom.JSValue, arguments []dom.JSValue) !dom.JSValue {
	mut realm := unsafe { &html.ScriptingRealm(callback.custom_data.incumbent_settings.realm()) }
	html.prepare_to_run_callback(mut realm)
	mut pushed_context := false
	if context := callback.custom_data.active_script_context {
		vm.execution_context_stack_ << context
		pushed_context = true
	}
	result := callback.callback(this_value, arguments) or {
		vm.finish_job_callback(callback, pushed_context)
		return err
	}
	vm.finish_job_callback(callback, pushed_context)
	return result
}

// https://html.spec.whatwg.org/multipage/webappapis.html#hostenqueuefinalizationregistrycleanupjob
pub fn (_ &MainThreadVM) host_enqueue_finalization_registry_cleanup_job(cleanup FinalizationRegistryCleanupJob, realm &html.ScriptingRealm, document ?&dom.Document) {
	html.queue_a_task(.javascript_engine, html.main_thread_event_loop(), document, fn [cleanup, realm] () {
		mut mutable_realm := unsafe { &html.ScriptingRealm(realm) }
		html.prepare_to_run_script(mut mutable_realm)
		cleanup() or {
			html.clean_up_after_running_script(mut mutable_realm)
			html.report_exception(dom.js_string(err.msg()), mut mutable_realm)
			return
		}
		html.clean_up_after_running_script(mut mutable_realm)
	})
}

// https://html.spec.whatwg.org/multipage/webappapis.html#hostenqueuepromisejob
pub fn (_ &MainThreadVM) host_enqueue_promise_job(job PromiseJob, realm ?&html.ScriptingRealm, document ?&dom.Document) {
	html.queue_a_microtask(document, fn [job, realm] () {
		if realm_pointer := realm {
			mut mutable_realm := unsafe { &html.ScriptingRealm(realm_pointer) }
			html.prepare_to_run_script(mut mutable_realm)
			html.prepare_to_run_callback(mut mutable_realm)
			_ = job() or {
				html.clean_up_after_running_callback(mut mutable_realm)
				html.clean_up_after_running_script(mut mutable_realm)
				html.report_exception(dom.js_string(err.msg()), mut mutable_realm)
				return
			}
			html.clean_up_after_running_callback(mut mutable_realm)
			html.clean_up_after_running_script(mut mutable_realm)
			return
		}
		_ = job() or { return }
	})
}

pub fn (_ &MainThreadVM) host_promise_job_queue_is_empty() bool {
	return html.main_thread_event_loop().microtask_queue_empty()
}

pub struct ImportMetaProperties {
pub:
	url        string
	base_url   dom.URL
	import_map html.ImportMap
}

pub fn (properties &ImportMetaProperties) resolve(specifier string) !string {
	url := html.resolve_module_specifier(&properties.import_map, properties.base_url, specifier)!
	return url.serialize()
}

// https://html.spec.whatwg.org/multipage/webappapis.html#hostgetimportmetaproperties
pub fn (_ &MainThreadVM) host_get_import_meta_properties(module_script &html.Script, import_map &html.ImportMap) !ImportMetaProperties {
	base_url := module_script.base_url or {
		return error('TypeError: module script has no base URL')
	}

	return ImportMetaProperties{
		url:        base_url.serialize()
		base_url:   base_url
		import_map: html.ImportMap{
			imports:   html.ModuleSpecifierMap{
				entries: import_map.imports.entries.clone()
			}
			scopes:    import_map.scopes.clone()
			integrity: import_map.integrity.clone()
		}
	}
}

pub fn (_ &MainThreadVM) host_get_supported_import_attributes() []string {
	return ['type']
}

pub enum ModuleGlobalKind {
	window
	worker
	worklet
	service_worker
}

pub struct ModuleRequest {
pub:
	specifier  string
	attributes map[string]string
}

pub struct ResolvedModuleLoad {
pub:
	url         dom.URL
	module_type string
}

// Validation and resolution portion of HostLoadImportedModule. Fetching and
// LibJS FinishLoadingImportedModule remain host callbacks in the V runtime.
pub fn (_ &MainThreadVM) host_load_imported_module(request ModuleRequest, import_map &html.ImportMap, base_url dom.URL, global_kind ModuleGlobalKind, load_state_present bool) !ResolvedModuleLoad {
	if !load_state_present && global_kind in [.worklet, .service_worker] {
		return error('TypeError: Dynamic import is not available for Worklets or ServiceWorkers')
	}
	for attribute, _ in request.attributes {
		if attribute != 'type' {
			return error('SyntaxError: module request attributes may only contain type')
		}
	}
	url := html.resolve_module_specifier(import_map, base_url, request.specifier)!
	module_type := request.attributes['type'] or { 'javascript' }
	if !html.module_type_allowed(module_type) {
		return error("TypeError: Module type '${module_type}' is not supported")
	}
	return ResolvedModuleLoad{
		url:         url
		module_type: module_type
	}
}

pub fn (mut vm MainThreadVM) host_unrecognized_date_string(date string) {
	vm.unrecognized_date_strings << date
}

pub struct HostArrayBuffer {
pub:
	shared          bool
	max_byte_length int
pub mut:
	data []u8
}

pub fn (mut buffer HostArrayBuffer) host_resize_array_buffer(new_byte_length int) ! {
	if buffer.shared {
		return error('TypeError: shared ArrayBuffer requires the grow hook')
	}
	if new_byte_length > buffer.max_byte_length {
		return error('RangeError: requested ArrayBuffer length exceeds its maximum')
	}
	buffer.data = if new_byte_length <= buffer.data.len {
		buffer.data[..new_byte_length].clone()
	} else {
		mut grown := buffer.data.clone()
		grown << []u8{len: new_byte_length - buffer.data.len}
		grown
	}
}

pub fn (mut buffer HostArrayBuffer) host_grow_shared_array_buffer(new_byte_length int) ! {
	if !buffer.shared {
		return error('TypeError: non-shared ArrayBuffer requires the resize hook')
	}
	if new_byte_length < buffer.data.len || new_byte_length > buffer.max_byte_length {
		return error('RangeError: invalid SharedArrayBuffer growth length')
	}
	buffer.data << []u8{len: new_byte_length - buffer.data.len}
}

// https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
pub fn queue_mutation_observer_microtask(document &dom.Document) {
	mut agent := html.relevant_similar_origin_window_agent()
	if agent.mutation_observer_microtask_queued {
		return
	}
	agent.mutation_observer_microtask_queued = true
	html.queue_a_microtask(document, fn [agent, document] () {
		mut mutable_agent := unsafe { &html.SimilarOriginWindowAgent(agent) }
		mutable_agent.mutation_observer_microtask_queued = false
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.notify_mutation_observers()
	})
}

pub struct WebRealmExecutionContext {
pub:
	realm         &html.ScriptingRealm
	global_object voidptr
	global_this   voidptr
}

// https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-new-javascript-realm
pub fn create_a_new_javascript_realm(create_global_object CreateGlobalObject, create_global_this_value CreateGlobalObject) &WebRealmExecutionContext {
	mut realm := &html.ScriptingRealm{}
	global_object := create_global_object(realm)
	realm.global_object_handle = global_object
	return &WebRealmExecutionContext{
		realm: realm
		global_object: global_object
		global_this: create_global_this_value(realm)
	}
}

// Test and tooling callers may use these helpers before the browser process
// has installed its normal main-thread VM.
fn ensure_main_thread_vm_initialized() &MainThreadVM {
	if vm := main_thread_vm_ptr() {
		return vm
	}
	return initialize_main_thread_vm(.similar_origin_window) or { panic(err) }
}

fn create_window_backed_realm() (&WebRealmExecutionContext, &Wrappable, &PlatformObject) {
	mut realm := &html.ScriptingRealm{}
	mut implementation := Wrappable.create('Window', ['EventTarget'])
	wrapper := create_global_object_wrapper(realm, mut implementation)
	realm.global_object_handle = voidptr(wrapper)
	context := &WebRealmExecutionContext{
		realm: realm
		global_object: voidptr(wrapper)
		global_this: voidptr(wrapper)
	}
	return context, implementation, wrapper
}

// Creates a principal realm backed by a Page and window environment settings object.
pub fn create_a_principal_javascript_realm() &html.ScriptingRealm {
	mut vm := ensure_main_thread_vm_initialized()
	context, _, _ := create_window_backed_realm()
	mut realm := unsafe { &html.ScriptingRealm(context.realm) }
	page := &dom.Page{}
	mut document := dom.Document.create(dom.URL{ value: 'about:blank' })
	document.set_page(page)
	window := html.WindowModel.create_top_level(document, none, '') or { panic(err) }
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin()).settings
	intrinsics := Intrinsics.create(realm)
	create_principal_host_defined(settings, intrinsics, page)
	cache_global_object_wrapper(realm)
	vm.execution_context_stack_ << &WebExecutionContext{
		realm: realm
	}
	return realm
}

// Creates a bare Window-backed internal realm whose principal state resolves
// through one lazily-created principal realm.
pub fn create_a_simple_javascript_realm() &html.ScriptingRealm {
	mut vm := ensure_main_thread_vm_initialized()
	if bindings_main_thread_principal_realm == unsafe { nil } {
		depth := vm.execution_context_stack_.len
		bindings_main_thread_principal_realm = create_a_principal_javascript_realm()
		for vm.execution_context_stack_.len > depth {
			vm.execution_context_stack_.delete_last()
		}
	}
	context, _, _ := create_window_backed_realm()
	mut realm := unsafe { &html.ScriptingRealm(context.realm) }
	intrinsics := Intrinsics.create(realm)
	wrapper_world := WrapperWorld.create(.internal)
	host_defined := HostDefined.create(intrinsics, wrapper_world, bindings_main_thread_principal_realm, .no)
	install_host_defined(mut realm, host_defined)
	cache_global_object_wrapper(realm)
	vm.execution_context_stack_ << &WebExecutionContext{
		realm: realm
	}
	return realm
}

pub type InvokeCustomElementCallback = fn (&dom.Element, dom.CustomElementCallbackReaction) !

pub type ReportCustomElementReactionError = fn (string)

// https://html.spec.whatwg.org/multipage/custom-elements.html#invoke-custom-element-reactions
pub fn invoke_custom_element_reactions(mut element_queue []&dom.Element, callback ?InvokeCustomElementCallback, report_error ?ReportCustomElementReactionError) {
	for element_queue.len > 0 {
		element := element_queue[0]
		element_queue.delete(0)
		mut mutable_element := unsafe { &dom.Element(element) }
		for {
			reactions := mutable_element.take_custom_element_reactions()
			if reactions.len == 0 {
				break
			}
			for reaction in reactions {
				match reaction {
					dom.CustomElementUpgradeReaction {
						mutable_element.upgrade_element(reaction.custom_element_definition) or {
							if reporter := report_error {
								reporter(err.msg())
							}
						}
					}
					dom.CustomElementCallbackReaction {
						if invoker := callback {
							invoker(element, reaction) or {
								if reporter := report_error {
									reporter(err.msg())
								}
							}
						}
					}
				}
			}
		}
	}
}
