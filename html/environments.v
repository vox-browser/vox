// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/Environments.{h,cpp},
// WindowEnvironmentSettingsObject.{h,cpp}, and
// WorkerEnvironmentSettingsObject.{h,cpp}. LibJS execution-context identity is
// represented by ScriptingRealm; browser-owned service-worker records use the
// stable lightweight wrappers below.
@[has_globals]
module html

import dom
import domurl
import contentsecuritypolicy as csp
import mixedcontentcore
import securecontexts
import url as liburl
import fetch
import math
import storageapi
import time

__global (
	html_next_environment_id               = u64(1)
	html_scripting_execution_context_stack = []&ScriptingRealm{}
)

pub enum RunScriptDecision {
	run
	do_not_run
}

pub enum EnvironmentGlobalKind {
	window
	worker
	snapshot
}

@[heap]
pub struct Environment {
pub mut:
	id                      string
	creation_url            dom.URL
	top_level_creation_url  ?dom.URL
	top_level_origin        ?dom.Origin
	target_browsing_context ?&BrowsingContextModel
	execution_ready         bool
	discarded               bool
	settings_handle         voidptr
}

pub fn Environment.create(id string, creation_url dom.URL, top_level_creation_url ?dom.URL, top_level_origin ?dom.Origin, target ?&BrowsingContextModel) &Environment {
	return &Environment{
		id: id
		creation_url: creation_url
		top_level_creation_url: top_level_creation_url
		top_level_origin: top_level_origin
		target_browsing_context: target
	}
}

pub fn (mut environment Environment) discard_environment() {
	environment.discarded = true
}

pub struct ServiceWorkerRecordModel {
pub:
	id    string
	state string
}

pub struct ServiceWorkerObjectModel {
pub:
	record_id string
	state     string
}

@[heap]
pub struct ServiceWorkerRegistrationRecordModel {
pub:
	storage_key string
	scope_url   dom.URL
	installing  ?&ServiceWorkerRecordModel
	waiting     ?&ServiceWorkerRecordModel
	active      ?&ServiceWorkerRecordModel
}

@[heap]
pub struct ServiceWorkerRegistrationObjectModel {
	// Keep the registration's identity alive while its cached wrapper exists.
	registration_ &ServiceWorkerRegistrationRecordModel
pub:
	storage_key string
	scope_url   dom.URL
pub mut:
	installing ?&ServiceWorkerObjectModel
	waiting    ?&ServiceWorkerObjectModel
	active     ?&ServiceWorkerObjectModel
}

pub struct FetchGroup {
pub mut:
	controllers []voidptr
}

@[heap]
pub struct EnvironmentSettingsObject {
mut:
	realm_                               &ScriptingRealm
	environment_                         &Environment
	module_map_                          &ModuleMap
	responsible_event_loop_              &EventLoop
	global_kind_                         EnvironmentGlobalKind
	window_                              ?&WindowModel
	worker_                              ?&WorkerGlobalScope
	policy_container_                    PolicyContainer
	time_origin_                         f64
	origin_                              dom.Origin
	outside_has_cross_site_ancestor_     bool
	worker_owner_secure_context_         bool
	global_object_                       &dom.EventTarget = unsafe { nil }
	universal_global_scope_              &UniversalGlobalScopeMixin = unsafe { nil }
	storage_manager_                     &storageapi.StorageManager = unsafe { nil }
	resolved_module_set_                 []ResolvedModuleRecord
	service_worker_registration_objects_ map[u64]&ServiceWorkerRegistrationObjectModel
	service_worker_objects_              map[string]&ServiceWorkerObjectModel
	worker_agents_starting_              []&WorkerAgentParent
	fetch_group_                         FetchGroup
	script_fetch_hook_                   ?PerformTheFetchHook
	script_compile_hook_                 ?ScriptCompileHook
	script_function_compile_hook_        ?ScriptFunctionCompileHook
	script_bytecode_cache_compile_hook_  ?ScriptBytecodeCacheCompileHook
	script_bytecode_materialize_hook_    ?ScriptBytecodeCacheMaterializeHook
	script_bytecode_cache_store_hook_    ?ScriptBytecodeCacheStoreHook
}

fn create_environment_settings(realm &ScriptingRealm, environment &Environment, kind EnvironmentGlobalKind, event_loop &EventLoop) &EnvironmentSettingsObject {
	dom.set_url_finish_parsing_hook(domurl.finish_parsing_record)
	settings := &EnvironmentSettingsObject{
		realm_: realm
		environment_: environment
		module_map_: ModuleMap.create()
		responsible_event_loop_: event_loop
		global_kind_: kind
		policy_container_: PolicyContainer{}
	}
	mut mutable_realm := unsafe { &ScriptingRealm(realm) }
	mutable_realm.settings_handle = voidptr(settings)
	mutable_realm.module_map_ = settings.module_map_
	mut mutable_environment := unsafe { &Environment(environment) }
	mutable_environment.settings_handle = voidptr(settings)
	mut responsible_event_loop := unsafe { &EventLoop(event_loop) }
	responsible_event_loop.register_environment_settings_object(settings)
	return settings
}

pub fn (settings &EnvironmentSettingsObject) environment() &Environment {
	return settings.environment_
}

// All environment settings objects are created with a realm execution
// context. ScriptingRealm is the compact port's execution-context record.
pub fn (settings &EnvironmentSettingsObject) realm_execution_context() &ScriptingRealm {
	return settings.realm_
}

// https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object%27s-realm
pub fn (settings &EnvironmentSettingsObject) realm() &ScriptingRealm {
	return settings.realm_execution_context()
}

// https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global
pub fn (settings &EnvironmentSettingsObject) global_object() &dom.EventTarget {
	assert settings.global_object_ != unsafe { nil }
	return settings.global_object_
}

pub fn (settings &EnvironmentSettingsObject) universal_global_scope() &UniversalGlobalScopeMixin {
	assert settings.universal_global_scope_ != unsafe { nil }
	return settings.universal_global_scope_
}

pub fn (settings &EnvironmentSettingsObject) report_an_exception(exception dom.JSValue, omit_error bool) {
	if window := settings.window_ {
		mut scope := unsafe { &WindowOrWorkerGlobalScopeMixin(window.window_or_worker_global_scope()) }
		scope.report_an_exception(exception, omit_error)
		return
	}
	if worker := settings.worker_ {
		mut scope := unsafe { &WindowOrWorkerGlobalScopeMixin(worker.window_or_worker_global_scope()) }
		scope.report_an_exception(exception, omit_error)
	}
}

pub fn (settings &EnvironmentSettingsObject) module_map() &ModuleMap {
	return settings.module_map_
}

pub fn (settings &EnvironmentSettingsObject) responsible_event_loop() &EventLoop {
	return settings.responsible_event_loop_
}

pub fn (settings &EnvironmentSettingsObject) fetch_group() &FetchGroup {
	return &settings.fetch_group_
}

pub fn (mut settings EnvironmentSettingsObject) keep_worker_agent_alive_while_starting(agent &WorkerAgentParent) {
	if agent !in settings.worker_agents_starting_ {
		settings.worker_agents_starting_ << agent
	}
}

pub fn (mut settings EnvironmentSettingsObject) release_worker_agent_from_startup_keep_alive(agent &WorkerAgentParent) {
	settings.worker_agents_starting_ = settings.worker_agents_starting_.filter(voidptr(it) != voidptr(agent))
}

pub fn (settings &EnvironmentSettingsObject) worker_startup_keep_alive_count() int {
	return settings.worker_agents_starting_.len
}

// Platform fetching remains a host boundary in the V translation. Script
// fetching algorithms use this hook when they are not passed an override.
pub fn (mut settings EnvironmentSettingsObject) set_script_fetch_hook(hook ?PerformTheFetchHook) {
	settings.script_fetch_hook_ = hook
}

pub fn (settings &EnvironmentSettingsObject) script_fetch_hook() ?PerformTheFetchHook {
	return settings.script_fetch_hook_
}

// Runtime-neutral host boundary for parsing and top-level code generation.
pub fn (mut settings EnvironmentSettingsObject) set_script_compile_hook(hook ?ScriptCompileHook) {
	settings.script_compile_hook_ = hook
}

pub fn (settings &EnvironmentSettingsObject) script_compile_hook() ?ScriptCompileHook {
	return settings.script_compile_hook_
}

pub fn (mut settings EnvironmentSettingsObject) set_script_function_compile_hook(hook ?ScriptFunctionCompileHook) {
	settings.script_function_compile_hook_ = hook
}

pub fn (settings &EnvironmentSettingsObject) script_function_compile_hook() ?ScriptFunctionCompileHook {
	return settings.script_function_compile_hook_
}

pub fn (mut settings EnvironmentSettingsObject) set_script_bytecode_cache_compile_hook(hook ?ScriptBytecodeCacheCompileHook) {
	settings.script_bytecode_cache_compile_hook_ = hook
}

pub fn (settings &EnvironmentSettingsObject) script_bytecode_cache_compile_hook() ?ScriptBytecodeCacheCompileHook {
	return settings.script_bytecode_cache_compile_hook_
}

pub fn (mut settings EnvironmentSettingsObject) set_script_bytecode_cache_materialize_hook(hook ?ScriptBytecodeCacheMaterializeHook) {
	settings.script_bytecode_materialize_hook_ = hook
}

pub fn (settings &EnvironmentSettingsObject) script_bytecode_cache_materialize_hook() ?ScriptBytecodeCacheMaterializeHook {
	return settings.script_bytecode_materialize_hook_
}

pub fn (mut settings EnvironmentSettingsObject) set_script_bytecode_cache_store_hook(hook ?ScriptBytecodeCacheStoreHook) {
	settings.script_bytecode_cache_store_hook_ = hook
}

pub fn (settings &EnvironmentSettingsObject) script_bytecode_cache_store_hook() ?ScriptBytecodeCacheStoreHook {
	return settings.script_bytecode_cache_store_hook_
}

pub fn (settings &EnvironmentSettingsObject) responsible_document() ?&dom.Document {
	window := settings.window_ or { return none }
	return window.Window.associated_document()
}

pub fn (settings &EnvironmentSettingsObject) api_base_url() dom.URL {
	if window := settings.window_ {
		return window.associated_document().base_url()
	}
	if worker := settings.worker_ {
		return worker.url()
	}
	return settings.environment_.creation_url
}

pub fn (settings &EnvironmentSettingsObject) origin() dom.Origin {
	if window := settings.window_ {
		return window.associated_document().origin()
	}
	return settings.origin_
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_policy_container() fetch.RequestPolicyContainer {
	container := settings.policy_container()
	return fetch.RequestPolicyContainer{
		referrer_policy: container.referrer_policy.to_string()
		csp_list: fetch_csp_policy_list(container.csp_list)
		integrity_policy: fetch_integrity_policy(container.integrity_policy)
		report_only_integrity_policy: fetch_integrity_policy(container.report_only_integrity_policy)
	}
}

fn fetch_csp_policy_list(policies []SerializedCSPPolicy) &csp.PolicyList {
	mut converted := []csp.SerializedPolicy{}
	for policy in policies {
		mut directives := []csp.SerializedDirective{}
		for directive in policy.directives {
			directives << csp.SerializedDirective{ name: directive.name, value: directive.value.clone() }
		}
		// Policy::create_from_serialized_policy copies the real Origin record.
		// Serializing and reparsing loses opaque identity and tuple fields.
		origin := policy.self_origin.liburl_origin() or {
			if !policy.self_origin.is_opaque() {
				panic('invalid CSP origin')
			}
			// Preserve the explicit legacy adapter when it has no typed origin.
			liburl.Origin.opaque([16]u8{}, .standard)
		}
		converted << csp.SerializedPolicy{
			directives: directives
			disposition: if policy.disposition == .enforce { .enforce } else { .report }
			source: if policy.source == .header { .header } else { .meta }
			self_origin: origin
			pre_parsed_policy_string: policy.pre_parsed_policy_string
		}
	}
	return csp.PolicyList.create_from_serialized_policies(converted)
}

fn fetch_integrity_policy(policy IntegrityPolicy) csp.IntegrityPolicy {
	mut destinations := []csp.RequestDestination{}
	for destination in policy.blocked_destinations {
		destinations << match destination {
			.audio { csp.RequestDestination.audio }
			.audio_worklet { csp.RequestDestination.audio_worklet }
			.document { csp.RequestDestination.document }
			.embed { csp.RequestDestination.embed }
			.font { csp.RequestDestination.font }
			.frame { csp.RequestDestination.frame }
			.iframe { csp.RequestDestination.iframe }
			.image { csp.RequestDestination.image }
			.json { csp.RequestDestination.json }
			.manifest { csp.RequestDestination.manifest }
			.object { csp.RequestDestination.object }
			.paint_worklet { csp.RequestDestination.paint_worklet }
			.report { csp.RequestDestination.report }
			.script { csp.RequestDestination.script }
			.service_worker { csp.RequestDestination.service_worker }
			.shared_worker { csp.RequestDestination.shared_worker }
			.style { csp.RequestDestination.style }
			.track { csp.RequestDestination.track }
			.video { csp.RequestDestination.video }
			.web_identity { csp.RequestDestination.web_identity }
			.worker { csp.RequestDestination.worker }
			.xslt { csp.RequestDestination.xslt }
			.text { csp.RequestDestination.other }
		}
	}
	return csp.IntegrityPolicy{ sources: policy.sources.clone(), blocked_destinations: destinations }
}

// MixedContent/AbstractOperations.cpp: inspect the real client origin and its
// logical ancestor navigables, including remote-safe active origin replicas.
pub fn (settings &EnvironmentSettingsObject) fetch_request_client_mixed_security_context() mixedcontentcore.EnvironmentSettings {
	mut ancestors := []bool{}
	if document := settings.responsible_document() {
		for ancestor in document.ancestor_navigables() {
			if origin := ancestor.active_document_origin() {
				ancestors << (securecontexts.is_origin_potentially_trustworthy(origin) == .potentially_trustworthy)
			}
		}
	}
	top_level := if target := settings.environment_.target_browsing_context {
		target.is_top_level()
	} else { false }
	return mixedcontentcore.EnvironmentSettings{
		origin_potentially_trustworthy: securecontexts.is_origin_potentially_trustworthy(settings.origin()) == .potentially_trustworthy
		global_kind: if settings.global_kind_ == .window { .window } else { .worker }
		ancestor_origins_potentially_trustworthy: ancestors
		target_browsing_context_is_top_level: top_level
	}
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_csp_global() &csp.GlobalContext {
	global_url := if document := settings.responsible_document() { document.url } else { settings.environment_.creation_url }
	global_object := settings.global_object_
	is_window := settings.global_kind_ == .window
	loop := settings.responsible_event_loop_
	mut source_file := ?liburl.URL(none)
	mut line := u32(0)
	mut column := u32(0)
	if provider := settings.realm().current_source_location_ {
		if location := provider() {
			source_file = liburl.parse(location.url)
			line = location.line
			column = location.column
		}
	}
	return &csp.GlobalContext{
		url: liburl.parse(global_url.serialize()) or { panic('invalid CSP global URL') }
		source_file:source_file
		line_number:line
		column_number:column
		policy_list: fetch_csp_policy_list(settings.policy_container().csp_list)
		dispatch_violation_event: fn [global_object, is_window, loop] (event &csp.SecurityPolicyViolationEvent) {
			queue_a_task(.unspecified, loop, none, fn [global_object, is_window, event] () {
				// Violation.cpp:301–305 selects the actual global at execution,
				// then reads a Window's current associated Document.
				mut target := unsafe { global_object }
				if is_window {
					target = unsafe { nil }
					if global_object != unsafe { nil } {
						window := unsafe { &dom.Window(global_object) }
						if document := window.associated_document() {
							target = unsafe { &dom.EventTarget(document) }
							if element := event.policy_element {
								if element.as_node().is_connected() && voidptr(element.document()) == voidptr(document) {
									target = unsafe { &dom.EventTarget(element) }
									}
							}
						}
					}
				}
				if target != unsafe { nil } {
					target.dispatch_event(unsafe { &dom.Event(event) })
				}
			})
		}
	}
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_is_window() bool {
	return settings.global_kind_ == .window
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_is_top_level_window() bool {
	window := settings.window_ or { return false }
	navigable := window.Window.navigable() or { return false }
	return navigable.parent() == none
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_api_base_url() dom.URL {
	return settings.api_base_url()
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_origin() dom.Origin {
	return settings.origin()
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_document_url() ?dom.URL {
	document := settings.responsible_document() or { return none }
	return document.url
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_creation_url() dom.URL {
	return settings.environment_.creation_url
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_embedder_policy_credentialless() bool {
	return settings.policy_container().embedder_policy.value == .credentialless
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_top_level_origin() ?dom.Origin {
	return settings.environment_.top_level_origin
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_top_level_creation_url() ?dom.URL {
	return settings.environment_.top_level_creation_url
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_cross_origin_isolated_capability() bool {
	return settings.cross_origin_isolated_capability() == .yes
}

pub fn (environment &Environment) fetch_request_environment_top_level_origin() ?dom.Origin {
	return environment.top_level_origin
}

pub fn (environment &Environment) fetch_request_environment_blob_url_origin() liburl.Origin {
	return environment.blob_url_partition_origin()
}

pub fn (environment &Environment) fetch_request_environment_creation_url() dom.URL {
	return environment.creation_url
}

pub fn (environment &Environment) fetch_request_environment_top_level_creation_url() ?dom.URL {
	return environment.top_level_creation_url
}

pub fn (settings &EnvironmentSettingsObject) has_transient_activation() bool {
	window := settings.window_ or { return false }
	return window.has_transient_activation()
}

pub fn (settings &EnvironmentSettingsObject) has_cross_site_ancestor() bool {
	if window := settings.window_ {
		// WindowEnvironmentSettingsObject.cpp asks the logical parent Navigable
		// for its active settings/origin, including non-local parent ownership.
		navigable := window.Window.navigable() or { panic('Source cross-site ancestor requires a Window navigable') }
		parent := navigable.parent() or { return false }
		if parent.active_document_has_cross_site_ancestor() { return true }
		origin := parent.active_document_origin() or { panic('Source parent navigable requires an active origin') }
		return !origin.is_same_site(window.associated_document().origin())
	}
	if worker := settings.worker_ {
		return settings.outside_has_cross_site_ancestor_ || worker.url().scheme() == 'data'
	}
	return settings.outside_has_cross_site_ancestor_
}

pub fn (settings &EnvironmentSettingsObject) policy_container() &PolicyContainer {
	// WindowEnvironmentSettingsObject.cpp:134–138 and
	// WorkerEnvironmentSettingsObject.cpp:103–107 read the current actual owner.
	if window := settings.window_ {
		if document := window.Window.associated_document() {
			return document.policy_container()
		}
	}
	if worker := settings.worker_ {
		mut mutable_worker := unsafe { &WorkerGlobalScope(worker) }
		return mutable_worker.policy_container()
	}
	// Explicit standalone settings have no Window or Worker owner.
	return &settings.policy_container_
}

// Compatibility installation routes to the actual Source container owner.
// Source defines its setter on Document and assigns WorkerGlobalScope's field.
pub fn (mut settings EnvironmentSettingsObject) set_policy_container(container &dom.PolicyContainer) {
	defer { if callback := settings.realm().string_compilation_policy_changed_ { callback() } }
	if window := settings.window_ {
		if document := window.Window.associated_document() {
			mut owner := unsafe { &dom.Document(document) }
			owner.set_policy_container(container)
			return
		}
	}
	if worker := settings.worker_ {
		mut mutable_worker := unsafe { &WorkerGlobalScope(worker) }
		mutable_worker.policy_container_ = container
		return
	}
	settings.policy_container_ = container.clone()
}

pub fn (settings &EnvironmentSettingsObject) cross_origin_isolated_capability() CanUseCrossOriginIsolatedAPIs {
	// Ladybird's current Window and Worker implementations return No pending
	// agent-cluster isolation and Permissions Policy integration.
	return .no
}

pub fn (settings &EnvironmentSettingsObject) time_origin() f64 {
	if window := settings.window_ {
		return window.associated_document().load_timing_info.navigation_start_time
	}
	return settings.time_origin_
}

pub fn (settings &EnvironmentSettingsObject) parse_url(value string) ?dom.URL {
	return dom.dom_url_parse(value, settings.api_base_url(), 'UTF-8')
}

pub fn (settings &EnvironmentSettingsObject) encoding_parse_url(value string) ?dom.URL {
	encoding := if document := settings.responsible_document() {
		document.encoding_or_default()
	} else {
		'UTF-8'
	}
	return dom.dom_url_parse(value, settings.api_base_url(), encoding)
}

pub fn (settings &EnvironmentSettingsObject) encoding_parse_and_serialize_url(value string) ?string {
	url := settings.encoding_parse_url(value) or { return none }
	return url.serialize()
}

pub fn (mut settings EnvironmentSettingsObject) discard_environment() {
	settings.environment_.discard_environment()
}

pub fn (settings &EnvironmentSettingsObject) discarded() bool {
	return settings.environment_.discarded
}

pub fn (mut settings EnvironmentSettingsObject) set_discarded(discarded bool) {
	settings.environment_.discarded = discarded
}

pub fn (settings &EnvironmentSettingsObject) is_secure_context() bool {
	if settings.global_kind_ == .worker {
		return settings.worker_owner_secure_context_
	}
	url := settings.environment_.top_level_creation_url or { return false }
	return is_url_potentially_trustworthy(url)
}

pub fn is_url_potentially_trustworthy(url dom.URL) bool {
	if url.scheme() in ['https', 'wss', 'file'] {
		return true
	}
	if url.scheme() == 'about' && url.serialize() in ['about:blank', 'about:srcdoc'] {
		return true
	}
	host := url.serialized_host()
	if url.scheme() == 'http' && (host == 'localhost' || host.ends_with('.localhost') || host == '127.0.0.1' || host == '::1' || host == '[::1]') {
		return true
	}
	return false
}

pub fn (settings &EnvironmentSettingsObject) serialize() SerializedEnvironmentSettingsObject {
	secure_context := settings.is_secure_context()
	global := if window := settings.window_ {
		SerializedGlobal(SerializedWindow{
			associated_document: SerializedDocument{
				url: window.associated_document().url
				relevant_settings_object_is_secure_context: secure_context
			}
		})
	} else {
		SerializedGlobal(SerializedWorkerGlobalScope{
			relevant_settings_object_is_secure_context: secure_context
		})
	}
	return SerializedEnvironmentSettingsObject{
		id: settings.environment_.id
		creation_url: settings.environment_.creation_url
		top_level_creation_url: settings.environment_.top_level_creation_url
		top_level_origin: settings.environment_.top_level_origin
		api_base_url: settings.api_base_url()
		origin: settings.origin()
		has_cross_site_ancestor: settings.has_cross_site_ancestor()
		policy_container: settings.policy_container().serialize()
		cross_origin_isolated_capability: settings.cross_origin_isolated_capability()
		time_origin: settings.time_origin()
		global: global
	}
}

pub fn (mut settings EnvironmentSettingsObject) add_module_to_resolved_module_set(serialized_base_url string, normalized_specifier string, as_url ?dom.URL) {
	if settings.global_kind_ != .window {
		return
	}
	settings.resolved_module_set_ << ResolvedModuleRecord{
		serialized_base_url: serialized_base_url
		specifier: normalized_specifier
		specifier_is_null_or_url_like_that_is_special: as_url == none || as_url or { dom.URL{} }.scheme() in [
			'ftp',
			'file',
			'http',
			'https',
			'ws',
			'wss',
		]
	}
}

pub fn (settings &EnvironmentSettingsObject) resolved_module_set() []ResolvedModuleRecord {
	return settings.resolved_module_set_.clone()
}

pub fn (mut settings EnvironmentSettingsObject) get_service_worker_object(record &ServiceWorkerRecordModel) &ServiceWorkerObjectModel {
	if object := settings.service_worker_objects_[record.id] {
		return object
	}
	object := &ServiceWorkerObjectModel{
		record_id: record.id
		state: record.state
	}
	settings.service_worker_objects_[record.id] = object
	return object
}

pub fn (mut settings EnvironmentSettingsObject) get_service_worker_registration_object(registration &ServiceWorkerRegistrationRecordModel) &ServiceWorkerRegistrationObjectModel {
	key := u64(voidptr(registration))
	if object := settings.service_worker_registration_objects_[key] {
		return object
	}
	mut object := &ServiceWorkerRegistrationObjectModel{
		registration_: registration
		storage_key: registration.storage_key
		scope_url: registration.scope_url
	}
	if worker := registration.installing {
		object.installing = settings.get_service_worker_object(worker)
	}
	if worker := registration.waiting {
		object.waiting = settings.get_service_worker_object(worker)
	}
	if worker := registration.active {
		object.active = settings.get_service_worker_object(worker)
	}
	settings.service_worker_registration_objects_[key] = object
	return object
}

pub fn (settings &EnvironmentSettingsObject) current_wall_time() f64 {
	// V exposes milliseconds; cross-origin isolation is currently No in this
	// port, so coarsen to 100 microseconds as High Resolution Time requires.
	unsafe_time := f64(time.now().unix_milli())
	return math.floor(unsafe_time * 10.0) / 10.0
}

pub fn (mut settings EnvironmentSettingsObject) storage_manager() &storageapi.StorageManager {
	if settings.storage_manager_ == unsafe { nil } {
		settings.storage_manager_ = storageapi.StorageManager.create()
	}
	return settings.storage_manager_
}

pub fn module_type_allowed(module_type string) bool {
	return module_type in ['javascript-or-wasm', 'css', 'json', 'text']
}

pub fn settings_object_of_realm(realm &ScriptingRealm) ?&EnvironmentSettingsObject {
	if realm.settings_handle == unsafe { nil } {
		return none
	}
	return unsafe { &EnvironmentSettingsObject(realm.settings_handle) }
}

// In the compact runtime ScriptingRealm is both the Realm record and its realm
// execution context, preserving the identity required by the HTML algorithms.
pub fn execution_context_of_realm(realm &ScriptingRealm) &ScriptingRealm {
	return realm
}

fn top_most_script_having_execution_context() ?&ScriptingRealm {
	for index := html_scripting_execution_context_stack.len - 1; index >= 0; index-- {
		realm := html_scripting_execution_context_stack[index]
		if realm.script_execution_depth > 0 {
			return realm
		}
	}
	return none
}

pub fn module_map_of_realm(realm &ScriptingRealm) &ModuleMap {
	if module_map := realm.module_map_ {
		return module_map
	}
	if settings := settings_object_of_realm(principal_realm(realm)) {
		return settings.module_map()
	}
	panic('realm has no module map')
}

pub fn principal_realm(realm &ScriptingRealm) &ScriptingRealm {
	return realm.principal_realm_ or { realm }
}

pub fn principal_realm_settings_object(realm &ScriptingRealm) &EnvironmentSettingsObject {
	principal := principal_realm(realm)
	return settings_object_of_realm(principal) or { panic('principal realm has no settings object') }
}

pub fn incumbent_realm() &ScriptingRealm {
	if context := top_most_script_having_execution_context() {
		if context.skip_when_determining_incumbent_counter == 0 {
			return context
		}
	}
	event_loop := main_thread_event_loop()
	if !event_loop.is_backup_incumbent_realm_stack_empty() {
		return event_loop.top_of_backup_incumbent_realm_stack()
	}
	if html_scripting_execution_context_stack.len > 0 {
		return html_scripting_execution_context_stack.last()
	}
	panic('incumbent realm requested without a scripting execution context')
}

pub fn incumbent_settings_object() &EnvironmentSettingsObject {
	return principal_realm_settings_object(incumbent_realm())
}

pub fn incumbent_global_object() &dom.EventTarget {
	return incumbent_settings_object().global_object()
}

pub fn current_principal_realm() &ScriptingRealm {
	assert html_scripting_execution_context_stack.len > 0
	return principal_realm(html_scripting_execution_context_stack.last())
}

pub fn current_principal_settings_object() &EnvironmentSettingsObject {
	return principal_realm_settings_object(current_principal_realm())
}

pub fn current_principal_global_object() &dom.EventTarget {
	return current_principal_settings_object().global_object()
}

pub struct RealmBoundObject {
pub:
	realm &ScriptingRealm
}

pub fn relevant_realm(object &RealmBoundObject) &ScriptingRealm {
	return object.realm
}

pub fn relevant_principal_realm(object &RealmBoundObject) &ScriptingRealm {
	return principal_realm(relevant_realm(object))
}

pub fn relevant_settings_object(object &RealmBoundObject) &EnvironmentSettingsObject {
	return principal_realm_settings_object(relevant_realm(object))
}

pub fn relevant_principal_settings_object(object &RealmBoundObject) &EnvironmentSettingsObject {
	return principal_realm_settings_object(relevant_principal_realm(object))
}

pub fn relevant_global_object(object &RealmBoundObject) &dom.EventTarget {
	return relevant_settings_object(object).global_object()
}

pub fn relevant_principal_global_object(object &RealmBoundObject) &dom.EventTarget {
	return relevant_principal_settings_object(object).global_object()
}

pub fn entry_realm() &ScriptingRealm {
	assert html_scripting_execution_context_stack.len > 0
	return html_scripting_execution_context_stack.last()
}

pub fn entry_settings_object() &EnvironmentSettingsObject {
	return principal_realm_settings_object(entry_realm())
}

pub fn entry_global_object() &dom.EventTarget {
	return entry_settings_object().global_object()
}

pub fn is_non_secure_context(environment &Environment) bool {
	if environment.settings_handle != unsafe { nil } {
		settings := unsafe { &EnvironmentSettingsObject(environment.settings_handle) }
		return !settings.is_secure_context()
	}
	url := environment.top_level_creation_url or { return true }
	return !is_url_potentially_trustworthy(url)
}

pub fn can_run_script_for_settings(settings &EnvironmentSettingsObject) RunScriptDecision {
	if window := settings.window_ {
		document := window.associated_document()
		if document.has_page() && document.page().has_scripting_enabled_owner() {
			if !document.is_fully_active() { return .do_not_run }
		} else if !window.browsing_context().is_fully_active() {
			// The standalone Window constructor retains its explicit context
			// activity adapter. Actual Page-backed settings ask their Document.
			return .do_not_run
		}
	}
	if is_scripting_disabled_for_settings(settings) {
		return .do_not_run
	}
	if window := settings.window_ {
		document := window.associated_document()
		if (!document.has_page() || !document.page().has_scripting_enabled_owner())
			&& !settings.realm().can_run {
			return .do_not_run
		}
	}
	return .run
}

pub fn can_run_script(realm &ScriptingRealm) RunScriptDecision {
	settings := settings_object_of_realm(realm) or {
		return if realm.scripting_enabled && realm.can_run { .run } else { .do_not_run }
	}
	return can_run_script_for_settings(settings)
}

pub fn is_scripting_enabled(realm &ScriptingRealm) bool {
	if settings := settings_object_of_realm(realm) {
		return is_scripting_enabled_for_settings(settings)
	}
	return realm.scripting_enabled
}

pub fn is_scripting_disabled(realm &ScriptingRealm) bool {
	return !is_scripting_enabled(realm)
}

@[heap]
pub struct WindowEnvironmentSettingsObject {
pub:
	settings &EnvironmentSettingsObject
	window   &WindowModel
}

pub fn WindowEnvironmentSettingsObject.setup(window &WindowModel, creation_url dom.URL, mut realm ScriptingRealm, reserved_environment ?&Environment, top_level_creation_url dom.URL, top_level_origin dom.Origin) &WindowEnvironmentSettingsObject {
	mut mutable_window := unsafe { &WindowModel(window) }
	mutable_window.scripting_realm_ = &realm
	mut id := ''
	mut target := ?&BrowsingContextModel(none)
	if mut reserved := reserved_environment {
		id = reserved.id
		target = reserved.target_browsing_context
		reserved.id = ''
	} else {
		id = html_next_environment_id.str()
		html_next_environment_id++
	}
	environment := Environment.create(id, creation_url, top_level_creation_url, top_level_origin, target)
	mut settings := create_environment_settings(realm, environment, .window, main_thread_event_loop())
	settings.window_ = window
	if mutable_window.global_scope_ != unsafe { nil } {
		mutable_window.global_scope_.responsible_event_loop_ = settings.responsible_event_loop()
		mutable_window.global_scope_.error_reporting_target_ = unsafe { &dom.EventTarget(window) }
		mutable_window.global_scope_.error_reporting_realm_ = realm
	}
	settings.global_object_ = unsafe { &dom.EventTarget(window) }
	// Window settings precede Document construction in BrowsingContext.cpp
	// and Document::create_and_initialize. These algorithms read the associated
	// document only after that actual Window has acquired one.
	document := window.Window.associated_document()
	settings.universal_global_scope_ = UniversalGlobalScopeMixin.create(settings.global_object_, realm)
	if associated := document {
		settings.origin_ = associated.origin()
		settings.time_origin_ = associated.load_timing_info.navigation_start_time
	}
	object := &WindowEnvironmentSettingsObject{
		settings: settings
		window: window
	}
	mutable_window.environment_settings_ = object
	return object
}

pub fn (settings &EnvironmentSettingsObject) execution_ready() bool {
	return settings.environment_.execution_ready
}

pub fn (object &WindowEnvironmentSettingsObject) responsible_document() &dom.Document {
	return object.window.associated_document()
}

pub fn (object &WindowEnvironmentSettingsObject) api_base_url() dom.URL {
	return object.settings.api_base_url()
}

pub fn (object &WindowEnvironmentSettingsObject) origin() dom.Origin {
	return object.settings.origin()
}

pub fn (object &WindowEnvironmentSettingsObject) has_cross_site_ancestor() bool {
	return object.settings.has_cross_site_ancestor()
}

pub fn (object &WindowEnvironmentSettingsObject) policy_container() &PolicyContainer {
	return object.settings.policy_container()
}

pub fn (object &WindowEnvironmentSettingsObject) cross_origin_isolated_capability() CanUseCrossOriginIsolatedAPIs {
	return object.settings.cross_origin_isolated_capability()
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#script-settings-for-window-objects:concept-settings-object-time-origin
pub fn (object &WindowEnvironmentSettingsObject) time_origin() f64 {
	// Return window's associated Document's load timing info's navigation start time.
	return object.window.associated_document().load_timing_info.navigation_start_time
}

@[heap]
pub struct WorkerEnvironmentSettingsObject {
pub:
	settings     &EnvironmentSettingsObject
	global_scope &WorkerGlobalScope
}

pub fn WorkerEnvironmentSettingsObject.setup(global_scope &WorkerGlobalScope, mut realm ScriptingRealm, outside_settings SerializedEnvironmentSettingsObject, unsafe_worker_creation_time f64) &WorkerEnvironmentSettingsObject {
	origin := if global_scope.url().scheme() == 'data' {
		dom.origin_create_opaque()
	} else {
		outside_settings.origin
	}
	id := html_next_environment_id.str()
	html_next_environment_id++
	environment := Environment.create(id, global_scope.url(), none, outside_settings.top_level_origin, none)
	mut settings := create_environment_settings(realm, environment, .worker, global_scope.event_loop)
	settings.worker_ = global_scope
	mut worker_services := unsafe { &WindowOrWorkerGlobalScopeMixin(global_scope.window_or_worker_global_scope()) }
	worker_services.responsible_event_loop_ = settings.responsible_event_loop()
	worker_services.error_reporting_target_ = unsafe { &dom.EventTarget(global_scope) }
	worker_services.error_reporting_realm_ = realm
	settings.global_object_ = unsafe { &dom.EventTarget(global_scope) }
	settings.universal_global_scope_ = UniversalGlobalScopeMixin.create(settings.global_object_, realm)
	settings.origin_ = origin
	settings.outside_has_cross_site_ancestor_ = outside_settings.has_cross_site_ancestor
	settings.worker_owner_secure_context_ = serialized_global_is_secure_context(outside_settings.global)
	settings.time_origin_ = coarsen_worker_time(unsafe_worker_creation_time)
	return &WorkerEnvironmentSettingsObject{
		settings: settings
		global_scope: global_scope
	}
}

fn serialized_global_is_secure_context(global SerializedGlobal) bool {
	return match global {
		SerializedWindow { global.associated_document.relevant_settings_object_is_secure_context }
		SerializedWorkerGlobalScope { global.relevant_settings_object_is_secure_context }
	}
}

fn coarsen_worker_time(value f64) f64 {
	return math.floor(value * 10.0) / 10.0
}

pub fn (object &WorkerEnvironmentSettingsObject) api_base_url() dom.URL {
	return object.settings.api_base_url()
}

pub fn (object &WorkerEnvironmentSettingsObject) responsible_document() ?&dom.Document {
	_ = object
	return none
}

pub fn (object &WorkerEnvironmentSettingsObject) origin() dom.Origin {
	return object.settings.origin()
}

pub fn (object &WorkerEnvironmentSettingsObject) has_cross_site_ancestor() bool {
	return object.settings.has_cross_site_ancestor()
}

pub fn (object &WorkerEnvironmentSettingsObject) policy_container() &PolicyContainer {
	return object.settings.policy_container()
}

pub fn (object &WorkerEnvironmentSettingsObject) cross_origin_isolated_capability() CanUseCrossOriginIsolatedAPIs {
	return object.settings.cross_origin_isolated_capability()
}

pub fn (object &WorkerEnvironmentSettingsObject) time_origin() f64 {
	return object.settings.time_origin()
}
