// Copyright (c) 2024, Tim Ledbetter and Jamie Mansfield.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/ServiceWorkerContainer.{h,cpp,idl}.
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
	client &ServiceWorkerClient
	agent  &ServiceWorkerAgent
mut:
	ready_promise_ ?&WorkerPromise
	handlers       map[string]bool
}

pub fn ServiceWorkerContainer.create(client &ServiceWorkerClient, agent &ServiceWorkerAgent) &ServiceWorkerContainer {
	return &ServiceWorkerContainer{
		client: client
		agent:  agent
	}
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
	parsed_script := parse_url(script_url, container.client.base_url) or {
		return rejected('TypeError: scriptURL is not a valid URL')
	}
	if !valid_service_worker_url(parsed_script) {
		return rejected("TypeError: scriptURL must be HTTP(S) and its path must not contain '%2f' or '%5c'")
	}
	parsed_scope := if scope := options.scope {
		if has_forbidden_path_escape(scope) {
			return rejected("TypeError: scopeURL path must not contain '%2f' or '%5c'")
		}
		parse_url(scope, container.client.base_url) or {
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
	storage_key := container.client.storage_key or {
		return rejected('TypeError: Failed to obtain a storage key')
	}

	mut job := Job.create(.register, storage_key, parsed_scope, parsed_script,
		container.client.creation_url)
	job.worker_type = options.type_
	job.update_via_cache = options.update_via_cache
	mut agent := container.agent
	agent.schedule_job(job)
	return job.promise
}

pub fn (container &ServiceWorkerContainer) get_registration(client_url string) &WorkerPromise {
	storage_key := container.client.storage_key or {
		return rejected('TypeError: Failed to obtain a storage key')
	}

	parsed := parse_url(client_url, container.client.base_url) or {
		return rejected('TypeError: clientURL is not a valid URL')
	}
	if !same_origin(parsed, container.client.origin) {
		return rejected("SecurityError: clientURL is not the same origin as the client's origin")
	}
	registration := container.agent.store.match_client(storage_key, parsed)
	return &WorkerPromise{
		state:        .fulfilled
		registration: registration
	}
}

pub fn (mut container ServiceWorkerContainer) ready() &WorkerPromise {
	if existing := container.ready_promise_ {
		return existing
	}
	promise := &WorkerPromise{}
	container.ready_promise_ = promise
	container.poll_ready()
	return promise
}

// The C++ parallel algorithm leaves ready pending until an active matching
// worker exists. Hosts call this when registration/activation state changes.
pub fn (mut container ServiceWorkerContainer) poll_ready() {
	mut promise := container.ready_promise_ or { return }
	if promise.state != .pending {
		return
	}
	storage_key := container.client.storage_key or { return }
	registration := container.agent.store.match_client(storage_key, container.client.creation_url) or {
		return
	}
	if registration.active_worker() == none {
		return
	}
	promise.state = .fulfilled
	promise.registration = registration
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
