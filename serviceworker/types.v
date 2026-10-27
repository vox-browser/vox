// Copyright (c) 2024-2026, Ladybird contributors.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorkerRecord, ServiceWorker, ServiceWorkerRegistration,
// EventNames and their IDL enums/event attributes.
module serviceworker

pub const event_activate = 'activate'
pub const event_fetch = 'fetch'
pub const event_install = 'install'
pub const event_message = 'message'
pub const event_messageerror = 'messageerror'

pub enum WorkerType {
	classic
	module_
}

pub enum ServiceWorkerState {
	parsed
	installing
	installed
	activating
	activated
	redundant
}

pub enum ServiceWorkerUpdateViaCache {
	imports
	all
	none
}

@[heap]
pub struct ServiceWorkerRecord {
pub mut:
	state                    ServiceWorkerState
	script_url               string
	worker_type              WorkerType
	classic_scripts_imported bool
	script_body              []u8
}

@[heap]
pub struct ServiceWorker {
mut:
	record_  ?&ServiceWorkerRecord
	state_   ServiceWorkerState
	handlers map[string]bool
}

pub fn ServiceWorker.create(record ?&ServiceWorkerRecord) &ServiceWorker {
	return &ServiceWorker{
		record_: record
	}
}

pub fn (worker &ServiceWorker) script_url() string {
	record := worker.record_ or { return '' }
	return record.script_url
}

pub fn (worker &ServiceWorker) service_worker_state() ServiceWorkerState {
	return worker.state_
}

pub fn (mut worker ServiceWorker) set_service_worker_state(state ServiceWorkerState) {
	worker.state_ = state
}

pub fn (mut worker ServiceWorker) set_event_handler(name string, present bool) {
	if name !in ['statechange', 'error'] {
		return
	}
	worker.handlers[name] = present
}

pub fn (worker &ServiceWorker) has_event_handler(name string) bool {
	return worker.handlers[name] or { false }
}

@[heap]
pub struct ServiceWorkerRegistration {
mut:
	registration_ &Registration
	installing_   ?&ServiceWorker
	waiting_      ?&ServiceWorker
	active_       ?&ServiceWorker
}

pub fn ServiceWorkerRegistration.create(registration &Registration) &ServiceWorkerRegistration {
	return &ServiceWorkerRegistration{
		registration_: registration
		installing_:   worker_object(registration.installing_worker())
		waiting_:      worker_object(registration.waiting_worker())
		active_:       worker_object(registration.active_worker())
	}
}

fn worker_object(record ?&ServiceWorkerRecord) ?&ServiceWorker {
	value := record or { return none }
	mut object := ServiceWorker.create(value)
	object.set_service_worker_state(value.state)
	return object
}

pub fn (object &ServiceWorkerRegistration) installing() ?&ServiceWorker {
	return object.installing_
}

pub fn ServiceWorkerRegistration.installing_offset() uint {
	return uint(__offsetof(ServiceWorkerRegistration, installing_))
}

pub fn (object &ServiceWorkerRegistration) waiting() ?&ServiceWorker {
	return object.waiting_
}

pub fn ServiceWorkerRegistration.waiting_offset() uint {
	return uint(__offsetof(ServiceWorkerRegistration, waiting_))
}

pub fn (object &ServiceWorkerRegistration) active() ?&ServiceWorker {
	return object.active_
}

pub fn ServiceWorkerRegistration.active_offset() uint {
	return uint(__offsetof(ServiceWorkerRegistration, active_))
}

pub fn (object &ServiceWorkerRegistration) registration() &Registration {
	return object.registration_
}

pub fn (mut object ServiceWorkerRegistration) set_installing(worker ?&ServiceWorker) {
	object.installing_ = worker
}

pub fn (mut object ServiceWorkerRegistration) set_waiting(worker ?&ServiceWorker) {
	object.waiting_ = worker
}

pub fn (mut object ServiceWorkerRegistration) set_active(worker ?&ServiceWorker) {
	object.active_ = worker
}

pub fn (object &ServiceWorkerRegistration) scope() string {
	return object.registration_.scope_url()
}

pub fn (object &ServiceWorkerRegistration) update_via_cache() ServiceWorkerUpdateViaCache {
	return object.registration_.update_via_cache()
}
