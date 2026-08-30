// Copyright (c) 2024-2025, Shannon Booth <shannon@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/ServiceWorkerGlobalScope.{h,cpp,idl}.
module serviceworker

@[heap]
pub struct CookieStore {
pub:
	page_client_id u64
}

@[heap]
pub struct ServiceWorkerGlobalScope {
pub:
	page_client_id u64
mut:
	handlers      map[string]bool
	cookie_store_ ?&CookieStore
}

pub fn ServiceWorkerGlobalScope.create(page_client_id u64) &ServiceWorkerGlobalScope {
	return &ServiceWorkerGlobalScope{
		page_client_id: page_client_id
	}
}

pub fn (mut scope ServiceWorkerGlobalScope) set_event_handler(name string, present bool) {
	if name in [event_install, event_activate, event_fetch, event_message, event_messageerror] {
		scope.handlers[name] = present
	}
}

pub fn (scope &ServiceWorkerGlobalScope) has_event_handler(name string) bool {
	return scope.handlers[name] or { false }
}

pub fn (mut scope ServiceWorkerGlobalScope) set_oninstall(value bool) { scope.set_event_handler(event_install, value) }
pub fn (scope &ServiceWorkerGlobalScope) oninstall() bool { return scope.has_event_handler(event_install) }
pub fn (mut scope ServiceWorkerGlobalScope) set_onactivate(value bool) { scope.set_event_handler(event_activate, value) }
pub fn (scope &ServiceWorkerGlobalScope) onactivate() bool { return scope.has_event_handler(event_activate) }
pub fn (mut scope ServiceWorkerGlobalScope) set_onfetch(value bool) { scope.set_event_handler(event_fetch, value) }
pub fn (scope &ServiceWorkerGlobalScope) onfetch() bool { return scope.has_event_handler(event_fetch) }
pub fn (mut scope ServiceWorkerGlobalScope) set_onmessage(value bool) { scope.set_event_handler(event_message, value) }
pub fn (scope &ServiceWorkerGlobalScope) onmessage() bool { return scope.has_event_handler(event_message) }
pub fn (mut scope ServiceWorkerGlobalScope) set_onmessageerror(value bool) { scope.set_event_handler(event_messageerror, value) }
pub fn (scope &ServiceWorkerGlobalScope) onmessageerror() bool { return scope.has_event_handler(event_messageerror) }

pub fn (mut scope ServiceWorkerGlobalScope) cookie_store() &CookieStore {
	if existing := scope.cookie_store_ {
		return existing
	}
	value := &CookieStore{
		page_client_id: scope.page_client_id
	}
	scope.cookie_store_ = value
	return value
}
