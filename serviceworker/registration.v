// Copyright (c) 2024, Andrew Kaster <andrew@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/Registration.{h,cpp}.
module serviceworker

fn without_fragment(url string) string {
	index := url.index_u8(`#`)
	return if index < 0 { url } else { url[..index] }
}

fn registration_key(storage_key string, scope string) string {
	return '${storage_key}\x00${without_fragment(scope)}'
}

@[heap]
pub struct Registration {
mut:
	storage_key_            string
	scope_url_              string
	installing_worker_      ?&ServiceWorkerRecord
	waiting_worker_         ?&ServiceWorkerRecord
	active_worker_          ?&ServiceWorkerRecord
	last_update_check_time_ ?f64
	update_via_cache_       ServiceWorkerUpdateViaCache = .imports
}

pub fn (registration &Registration) storage_key() string {
	return registration.storage_key_
}

pub fn (registration &Registration) scope_url() string {
	return registration.scope_url_
}

pub fn (registration &Registration) update_via_cache() ServiceWorkerUpdateViaCache {
	return registration.update_via_cache_
}

pub fn (mut registration Registration) set_update_via_cache(value ServiceWorkerUpdateViaCache) {
	registration.update_via_cache_ = value
}

pub fn (mut registration Registration) set_last_update_check_time(value f64) {
	registration.last_update_check_time_ = value
}

pub fn (registration &Registration) is_stale(now f64) bool {
	last := registration.last_update_check_time_ or { return false }
	return now - last > 86400
}

pub fn (registration &Registration) is_unregistered(store &RegistrationStore) bool {
	return store.is_unregistered(registration)
}

pub fn Registration.get(store &RegistrationStore, storage_key string, scope ?string) ?&Registration {
	return store.get(storage_key, scope)
}

pub fn Registration.set(mut store RegistrationStore, storage_key string, scope string, update_via_cache ServiceWorkerUpdateViaCache) &Registration {
	return store.set(storage_key, scope, update_via_cache)
}

pub fn Registration.match_(store &RegistrationStore, storage_key string, client_url string) ?&Registration {
	return store.match_client(storage_key, client_url)
}

pub fn Registration.remove(mut store RegistrationStore, storage_key string, scope string) {
	store.remove(storage_key, scope)
}

pub fn (registration &Registration) newest_worker() ?&ServiceWorkerRecord {
	if installing := registration.installing_worker_ {
		return installing
	}
	if waiting := registration.waiting_worker_ {
		return waiting
	}
	return registration.active_worker_
}

pub fn (registration &Registration) installing_worker() ?&ServiceWorkerRecord {
	return registration.installing_worker_
}

pub fn (registration &Registration) waiting_worker() ?&ServiceWorkerRecord {
	return registration.waiting_worker_
}

pub fn (registration &Registration) active_worker() ?&ServiceWorkerRecord {
	return registration.active_worker_
}

pub fn (mut registration Registration) set_installing_worker(worker ?&ServiceWorkerRecord) {
	registration.installing_worker_ = worker
}

pub fn (mut registration Registration) set_waiting_worker(worker ?&ServiceWorkerRecord) {
	registration.waiting_worker_ = worker
}

pub fn (mut registration Registration) set_active_worker(worker ?&ServiceWorkerRecord) {
	registration.active_worker_ = worker
}

@[heap]
pub struct RegistrationStore {
mut:
	registrations_ map[string]&Registration
}

pub fn RegistrationStore.create() &RegistrationStore {
	return &RegistrationStore{}
}

pub fn (store &RegistrationStore) len() int {
	return store.registrations_.len
}

pub fn (store &RegistrationStore) get(storage_key string, scope ?string) ?&Registration {
	scope_string := if value := scope { value } else { '' }
	return store.registrations_[registration_key(storage_key, scope_string)] or { none }
}

pub fn (mut store RegistrationStore) set(storage_key string, scope string, update_via_cache ServiceWorkerUpdateViaCache) &Registration {
	registration := &Registration{
		storage_key_: storage_key
		// Registration.cpp excludes the fragment from the map key, but retains
		// the original URL record on the newly created registration.
		scope_url_:        scope
		update_via_cache_: update_via_cache
	}
	store.registrations_[registration_key(storage_key, scope)] = registration
	return registration
}

pub fn (store &RegistrationStore) match_client(storage_key string, client_url string) ?&Registration {
	mut longest := ''
	prefix := '${storage_key}\x00'
	for key, _ in store.registrations_ {
		if !key.starts_with(prefix) {
			continue
		}
		scope := key[prefix.len..]
		if client_url.starts_with(scope) && scope.len > longest.len {
			longest = scope
		}
	}
	if longest == '' {
		return none
	}
	return store.get(storage_key, longest)
}

pub fn (mut store RegistrationStore) remove(storage_key string, scope string) {
	store.registrations_.delete(registration_key(storage_key, scope))
}

pub fn (store &RegistrationStore) is_unregistered(registration &Registration) bool {
	stored := store.get(registration.storage_key_, registration.scope_url_) or { return true }
	return voidptr(stored) != voidptr(registration)
}
