// Copyright (c) 2024, Tim Ledbetter and Jamie Mansfield.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/ServiceWorkerContainer.{h,cpp,idl}.
@[has_globals]
module serviceworker

import dom

pub struct RegistrationOptions {
pub:
	scope            ?string
	type_            WorkerType
	update_via_cache ServiceWorkerUpdateViaCache = .imports
}

pub struct ServiceWorkerClient {
pub:
	base_url     string
	creation_url string
	origin       string
	storage_key  ?string
}

@[heap]
pub struct ServiceWorkerContainer {
pub:
	agent &ServiceWorkerAgent
mut:
	client_               &ServiceWorkerClient
	handlers              map[string]bool
	registration_objects_ map[u64]&ServiceWorkerRegistration
	live_                 bool = true
}

pub fn ServiceWorkerContainer.create(client &ServiceWorkerClient, agent &ServiceWorkerAgent) &ServiceWorkerContainer {
	return &ServiceWorkerContainer{
		client_: client
		agent:   agent
	}
}

@[heap]
struct ServiceWorkerContainerReadyPromiseCacheEntry {
	container_pointer voidptr
mut:
	ready_promises map[u64]&WorkerPromise
	live_          bool = true
}

__global service_worker_container_ready_promise_cache_entries = []&ServiceWorkerContainerReadyPromiseCacheEntry{}

fn service_worker_container_ready_promise_caches() []&ServiceWorkerContainerReadyPromiseCacheEntry {
	return service_worker_container_ready_promise_cache_entries.clone()
}

fn prune_service_worker_container_ready_promise_caches() {
	mut retained := []&ServiceWorkerContainerReadyPromiseCacheEntry{}
	for entry in service_worker_container_ready_promise_cache_entries {
		if entry.live_ {
			retained << entry
		}
	}
	service_worker_container_ready_promise_cache_entries = retained.clone()
}

fn ready_promise_cache_for(container &ServiceWorkerContainer) &ServiceWorkerContainerReadyPromiseCacheEntry {
	prune_service_worker_container_ready_promise_caches()
	for entry in service_worker_container_ready_promise_cache_entries {
		if entry.container_pointer == voidptr(container) {
			return entry
		}
	}
	entry := &ServiceWorkerContainerReadyPromiseCacheEntry{
		container_pointer: voidptr(container)
	}
	service_worker_container_ready_promise_cache_entries << entry
	return entry
}

fn resolve_service_worker_registration_promise(mut promise WorkerPromise, registration &Registration, registration_object &ServiceWorkerRegistration) {
	promise.state = .fulfilled
	promise.registration = registration
	promise.registration_object = registration_object
}

fn resolve_service_worker_registration_list_promise(mut promise WorkerPromise, registrations []&Registration, registration_objects []&ServiceWorkerRegistration) {
	promise.state = .fulfilled
	promise.registrations = registrations.clone()
	promise.registration_objects = registration_objects.clone()
}

pub fn (container &ServiceWorkerContainer) service_worker_client() &ServiceWorkerClient {
	return container.client_
}

fn (mut container ServiceWorkerContainer) registration_object_for(registration &Registration) &ServiceWorkerRegistration {
	key := u64(voidptr(registration))
	if object := container.registration_objects_[key] {
		return object
	}
	object := ServiceWorkerRegistration.create(registration)
	container.registration_objects_[key] = object
	return object
}

// The GC bridge marks the weak cache entry dead when the container is swept.
pub fn (mut container ServiceWorkerContainer) mark_destroyed() {
	container.live_ = false
	for mut entry in service_worker_container_ready_promise_cache_entries {
		if entry.container_pointer == voidptr(&container) {
			entry.live_ = false
		}
	}
	prune_service_worker_container_ready_promise_caches()
}

fn parse_url(value string, base string) ?string {
	base_url := dom.dom_url_parse(base, dom.url_about_blank(), 'UTF-8') or { return none }
	mut parsed := dom.dom_url_parse(value, base_url, 'UTF-8') or { return none }
	parsed.set_fragment(none)
	return parsed.serialize()
}

fn valid_service_worker_url(url string) bool {
	parsed := dom.dom_url_parse(url, dom.url_about_blank(), 'UTF-8') or { return false }
	if parsed.scheme() !in ['http', 'https'] {
		return false
	}
	path := parsed.serialize_path().to_lower()
	return !path.contains('%2f') && !path.contains('%5c')
}

fn has_forbidden_path_escape(input string) bool {
	path_part := input.all_before('?').all_before('#').to_lower()
	return path_part.contains('%2f') || path_part.contains('%5c')
}

fn rejected(message string) &WorkerPromise {
	return &WorkerPromise{
		state: .rejected
		error: message
	}
}

pub fn (mut container ServiceWorkerContainer) register_(script_url string, options RegistrationOptions) &WorkerPromise {
	return container.start_register(script_url, options)
}

pub fn (mut container ServiceWorkerContainer) start_register(script_url string, options RegistrationOptions) &WorkerPromise {
	if has_forbidden_path_escape(script_url) {
		return rejected("TypeError: scriptURL path must not contain '%2f' or '%5c'")
	}
	parsed_script := parse_url(script_url, container.client_.base_url) or {
		return rejected('TypeError: scriptURL is not a valid URL')
	}
	if !valid_service_worker_url(parsed_script) {
		return rejected("TypeError: scriptURL must be HTTP(S) and its path must not contain '%2f' or '%5c'")
	}
	parsed_scope := if scope := options.scope {
		if has_forbidden_path_escape(scope) {
			return rejected("TypeError: scopeURL path must not contain '%2f' or '%5c'")
		}
		parse_url(scope, container.client_.base_url) or {
			return rejected('TypeError: scopeURL is not a valid URL')
		}
	} else {
		parse_url('./', parsed_script) or {
			return rejected('TypeError: default scopeURL is not a valid URL')
		}
	}
	if !valid_service_worker_url(parsed_scope) {
		return rejected("TypeError: scopeURL must be HTTP(S) and its path must not contain '%2f' or '%5c'")
	}
	storage_key := container.client_.storage_key or {
		return rejected('TypeError: Failed to obtain a storage key')
	}

	mut job := Job.create(.register, storage_key, parsed_scope, parsed_script,
		container.client_.creation_url)
	job.worker_type = options.type_
	job.update_via_cache = options.update_via_cache
	mut agent := container.agent
	agent.schedule_job(job)
	return job.promise
}

pub fn (mut container ServiceWorkerContainer) get_registration(client_url string) &WorkerPromise {
	storage_key := container.client_.storage_key or {
		return rejected('TypeError: Failed to obtain a storage key')
	}

	parsed := parse_url(client_url, container.client_.base_url) or {
		return rejected('TypeError: clientURL is not a valid URL')
	}
	if !same_origin(parsed, container.client_.origin) {
		return rejected("SecurityError: clientURL is not the same origin as the client's origin")
	}
	registration := container.agent.store.match_client(storage_key, parsed) or {
		return &WorkerPromise{
			state: .fulfilled
		}
	}
	object := container.registration_object_for(registration)
	mut promise := &WorkerPromise{}
	resolve_service_worker_registration_promise(mut promise, registration, object)
	return promise
}

pub fn (mut container ServiceWorkerContainer) ready() &WorkerPromise {
	return container.ready_for_world(0)
}

pub fn (mut container ServiceWorkerContainer) ready_for_world(wrapper_world_id u64) &WorkerPromise {
	mut cache := ready_promise_cache_for(container)
	if existing := cache.ready_promises[wrapper_world_id] {
		return existing
	}
	promise := &WorkerPromise{}
	cache.ready_promises[wrapper_world_id] = promise
	container.start_ready_promise_steps(promise)
	return promise
}

pub fn (mut container ServiceWorkerContainer) start_ready_promise_steps(ready_promise &WorkerPromise) {
	if ready_promise.state != .pending {
		return
	}
	storage_key := container.client_.storage_key or { return }
	registration := container.agent.store.match_client(storage_key, container.client_.creation_url) or {
		return
	}
	if registration.active_worker() == none {
		return
	}
	object := container.registration_object_for(registration)
	mut promise := unsafe { ready_promise }
	resolve_service_worker_registration_promise(mut promise, registration, object)
}

// The C++ parallel algorithm leaves ready pending until an active matching
// worker exists. Hosts call this when registration/activation state changes.
pub fn (mut container ServiceWorkerContainer) poll_ready() {
	mut cache := ready_promise_cache_for(container)
	for _, promise in cache.ready_promises {
		container.start_ready_promise_steps(promise)
	}
}

pub fn (mut container ServiceWorkerContainer) get_registrations() &WorkerPromise {
	storage_key := container.client_.storage_key or {
		return rejected('TypeError: Failed to obtain a storage key')
	}
	registrations := container.agent.store.for_storage_key(storage_key)
	mut objects := []&ServiceWorkerRegistration{cap: registrations.len}
	for registration in registrations {
		objects << container.registration_object_for(registration)
	}
	mut promise := &WorkerPromise{}
	resolve_service_worker_registration_list_promise(mut promise, registrations, objects)
	return promise
}

pub fn (container &ServiceWorkerContainer) controller() ?&ServiceWorker {
	// [FIXME] in upstream IDL/C++; no controller association is implemented.
	return none
}

pub fn (mut container ServiceWorkerContainer) set_event_handler(name string, present bool) {
	if name in ['controllerchange', 'message', 'messageerror'] {
		container.handlers[name] = present
	}
}

pub fn (container &ServiceWorkerContainer) has_event_handler(name string) bool {
	return container.handlers[name] or { false }
}
