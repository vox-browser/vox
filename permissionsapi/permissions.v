// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PermissionsAPI/{PermissionStatus,PermissionStore,Permissions}.
// The JS promise and environment-settings lookups enter through the explicit
// PermissionEnvironment boundary; the permission algorithms and store remain
// source-shaped and synchronous just as they are before upstream queues tasks.
@[has_globals]
module permissionsapi

import dom

pub enum PermissionState {
	prompt
	granted
	denied
}

pub struct PermissionDescriptor {
pub:
	name string
}

pub struct PermissionEnvironment {
pub:
	fully_active     bool = true
	secure_context   bool = true
	top_level_origin dom.Origin
	origin           dom.Origin
	test_mode        bool
}

pub struct PermissionStoreEntry {
pub:
	descriptor     PermissionDescriptor
	permission_key dom.Origin
	state          PermissionState
}

@[heap]
pub struct PermissionStore {
mut:
	entries []PermissionStoreEntry
}

__global permissions_api_store = &PermissionStore{}

pub fn PermissionStore.the() &PermissionStore {
	return permissions_api_store
}

pub fn permission_key_is_equal_to(_ PermissionDescriptor, key1 dom.Origin, key2 dom.Origin) bool {
	return permission_key_comparison_algorithm(key1, key2)
}

// https://w3c.github.io/permissions/#dfn-permission-key-comparison-algorithm
pub fn permission_key_comparison_algorithm(key1 dom.Origin, key2 dom.Origin) bool {
	return key1.is_same_origin(key2)
}

// https://w3c.github.io/permissions/#dfn-permission-key-generation-algorithm
pub fn permission_key_generation_algorithm(origin dom.Origin, _ dom.Origin) dom.Origin {
	return origin
}

// https://w3c.github.io/permissions/#dfn-get-a-permission-store-entry
pub fn (store &PermissionStore) get_permission_store_entry(descriptor PermissionDescriptor, key dom.Origin) ?PermissionStoreEntry {
	for entry in store.entries {
		if entry.descriptor.name == descriptor.name
			&& permission_key_is_equal_to(descriptor, entry.permission_key, key) {
			return entry
		}
	}
	return none
}

// https://w3c.github.io/permissions/#dfn-set-a-permission-store-entry
pub fn (mut store PermissionStore) set_permission_store_entry(descriptor PermissionDescriptor, key dom.Origin, state PermissionState) {
	new_entry := PermissionStoreEntry{
		descriptor: descriptor
		permission_key: key
		state: state
	}
	for index, entry in store.entries {
		if entry.descriptor.name == descriptor.name
			&& permission_key_is_equal_to(descriptor, entry.permission_key, key) {
			store.entries[index] = new_entry
			return
		}
	}
	store.entries << new_entry
}

// https://w3c.github.io/permissions/#dfn-remove-a-permission-store-entry
pub fn (mut store PermissionStore) remove_permission_store_entry(descriptor PermissionDescriptor, key dom.Origin) {
	store.entries = store.entries.filter(!(it.descriptor.name == descriptor.name
		&& permission_key_is_equal_to(descriptor, it.permission_key, key)))
}

pub fn (mut store PermissionStore) clear() {
	store.entries.clear()
}

pub fn is_permission_supported(name string) bool {
	return name == 'geolocation'
}

fn permission_key_for(environment PermissionEnvironment) dom.Origin {
	return permission_key_generation_algorithm(environment.top_level_origin, environment.origin)
}

// https://w3c.github.io/permissions/#dfn-permission-state
pub fn permission_state(descriptor PermissionDescriptor, environment PermissionEnvironment) PermissionState {
	if !environment.secure_context {
		return .denied
	}
	key := permission_key_for(environment)
	if entry := PermissionStore.the().get_permission_store_entry(descriptor, key) {
		return entry.state
	}
	return .prompt
}

// https://w3c.github.io/permissions/#dfn-request-permission-to-use
pub fn request_permission(descriptor PermissionDescriptor, environment PermissionEnvironment) PermissionState {
	mut current_state := permission_state(descriptor, environment)
	if current_state != .prompt {
		return current_state
	}
	current_state = if descriptor.name == 'geolocation' || environment.test_mode {
		PermissionState.granted
	} else {
		PermissionState.denied
	}
	mut store := PermissionStore.the()
	store.set_permission_store_entry(descriptor, permission_key_for(environment), current_state)
	return current_state
}

pub fn get_current_permission_state(name string, environment PermissionEnvironment) PermissionState {
	return permission_state(PermissionDescriptor{ name: name }, environment)
}

@[heap]
pub struct PermissionStatus {
	dom.EventTarget
pub:
	name_  string
	query_ PermissionDescriptor
mut:
	state_         PermissionState = .prompt
	environment    PermissionEnvironment
	change_pending bool
}

pub fn PermissionStatus.create(environment PermissionEnvironment, descriptor PermissionDescriptor) &PermissionStatus {
	assert is_permission_supported(descriptor.name)
	return &PermissionStatus{
		name_: descriptor.name
		query_: descriptor
		environment: environment
	}
}

pub fn (status &PermissionStatus) state() PermissionState {
	return status.state_
}

pub fn (mut status PermissionStatus) set_state(state PermissionState) {
	status.state_ = state
}

pub fn (status &PermissionStatus) name() string {
	return status.name_
}

pub fn (status &PermissionStatus) query() PermissionDescriptor {
	return status.query_
}

// https://w3c.github.io/permissions/#dfn-permissionstatus-update-steps
pub fn (mut status PermissionStatus) update_steps() {
	if !status.environment.fully_active {
		return
	}
	permission_query_algorithm(status.query_, mut status)
	status.change_pending = true
}

pub fn (mut status PermissionStatus) run_next_task() bool {
	if !status.change_pending {
		return false
	}
	status.change_pending = false
	event := dom.Event.create('change', dom.EventInit{})
	status.EventTarget.dispatch_event(event)
	return true
}

pub fn (status &PermissionStatus) set_onchange(event_handler ?&dom.CallbackType) {
	status.EventTarget.set_event_handler_attribute('change', event_handler)
}

pub fn (status &PermissionStatus) onchange() ?&dom.CallbackType {
	return status.EventTarget.event_handler_attribute('change')
}

@[heap]
pub struct Permissions {}

pub fn Permissions.create() &Permissions {
	return &Permissions{}
}

// This is the translated parallel portion of Permissions.query(). The binding
// layer owns conversion to/from a WebIDL promise and queues its resolution.
pub fn (permissions &Permissions) query(permission_desc PermissionDescriptor, environment PermissionEnvironment) !&PermissionStatus {
	_ = permissions
	if !environment.fully_active {
		return error('InvalidStateError: The document is not fully active.')
	}
	if !is_permission_supported(permission_desc.name) {
		return error('TypeError: ${permission_desc.name} is not a supported PermissionName')
	}
	mut status := PermissionStatus.create(environment, permission_desc)
	permission_query_algorithm(permission_desc, mut status)
	return status
}

// https://w3c.github.io/permissions/#dfn-permission-query-algorithm
pub fn permission_query_algorithm(permission_desc PermissionDescriptor, mut status PermissionStatus) {
	status.set_state(permission_state(permission_desc, status.environment))
}
