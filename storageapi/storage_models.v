// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of StorageKey, StorageBottle, StorageShelf, StorageShed,
// StorageManager, and NavigatorStorage.
module storageapi

import url as liburl

// Captured-value adapter for the Source HTML Environment overload. Genuine
// owners supply their actual current settings origin or creation URL record.
pub struct StorageEnvironment {
pub:
	origin             liburl.Origin
	creation_url       liburl.URL
	is_settings_object bool = true
	storage_disabled   bool
}

pub struct StorageKey {
pub:
	origin liburl.Origin
}

pub fn (key StorageKey) to_string() string {
	return key.origin.serialize()
}

pub fn (key StorageKey) equals(other StorageKey) bool {
	return key.origin.is_same_origin(other.origin)
}

// StorageKey.cpp:39–42: Source's overload for an actual URL Origin value.
pub fn obtain_a_storage_key_for_origin(origin liburl.Origin) StorageKey {
	return StorageKey{ origin: origin }
}

pub fn obtain_a_storage_key_for_non_storage_purposes(environment StorageEnvironment) StorageKey {
	return StorageKey{
		origin: if environment.is_settings_object {
			environment.origin
		} else {
			environment.creation_url.origin()
		}
	}
}

pub fn obtain_a_storage_key(environment StorageEnvironment) ?StorageKey {
	mut key := obtain_a_storage_key_for_non_storage_purposes(environment)
	// file: URLs have opaque origins, but current Ladybird deliberately gives
	// them one shared storage origin for compatibility with other browsers.
	if key.origin.is_opaque_file_origin() {
		key = StorageKey{
			origin: liburl.Origin.tuple('file', liburl.Host.from_string(''), none, none)
		}
	}
	if key.origin.is_opaque() {
		return none
	}
	// Source FIXME: user-disabled storage has no implemented effect here.
	return key
}

pub enum StorageOperationError {
	none
	quota_exceeded
}

pub struct StorageSetResult {
pub:
	old_value ?string
	error     StorageOperationError
}

pub type StorageKeysHook = fn (endpoint StorageEndpointType, storage_key string) []string

pub type StorageGetHook = fn (endpoint StorageEndpointType, storage_key string, key string) ?string

pub type StorageSetHook = fn (endpoint StorageEndpointType, storage_key string, key string, value string) StorageSetResult

pub type StorageClearHook = fn (endpoint StorageEndpointType, storage_key string)

pub type StorageRemoveHook = fn (endpoint StorageEndpointType, storage_key string, key string)

pub type StorageUsageHook = fn (storage_key string) u64

// PageClient-facing operations used by both local and session bottles. Current
// Ladybird keeps both storage sheds in the browser process.
pub struct StorageHost {
pub:
	keys   StorageKeysHook @[required]
	get    StorageGetHook @[required]
	set    StorageSetHook @[required]
	clear  StorageClearHook @[required]
	remove StorageRemoveHook @[required]
	usage  ?StorageUsageHook
}

@[heap]
pub struct StorageBottle {
pub:
	type_       StorageType
	endpoint    StorageEndpointType
	storage_key ?StorageKey
mut:
	quota_     ?u64
	map_       map[string]string
	key_order_ []string
	host       ?&StorageHost
}

pub fn StorageBottle.create(type_ StorageType, endpoint StorageEndpointType, key StorageKey, quota ?u64, host ?&StorageHost) &StorageBottle {
	return &StorageBottle{
		type_: type_
		endpoint: endpoint
		storage_key: key
		quota_: quota
		host: host
	}
}

pub fn (bottle &StorageBottle) proxy() &StorageBottle {
	return bottle
}

pub fn (bottle &StorageBottle) quota() ?u64 {
	return bottle.quota_
}

fn (bottle &StorageBottle) host_storage_key() string {
	key := bottle.storage_key or { panic('Host-backed StorageBottle has no actual StorageKey') }
	return key.to_string()
}

pub fn (bottle &StorageBottle) size() int {
	if host := bottle.host {
		return host.keys(bottle.endpoint, bottle.host_storage_key()).len
	}
	return bottle.map_.len
}

pub fn (bottle &StorageBottle) keys() []string {
	if host := bottle.host {
		return host.keys(bottle.endpoint, bottle.host_storage_key())
	}
	return bottle.key_order_.clone()
}

pub fn (bottle &StorageBottle) get(key string) ?string {
	if host := bottle.host {
		return host.get(bottle.endpoint, bottle.host_storage_key(), key)
	}
	return bottle.map_[key] or { none }
}

pub fn (mut bottle StorageBottle) set(key string, value string) StorageSetResult {
	if host := bottle.host {
		return host.set(bottle.endpoint, bottle.host_storage_key(), key, value)
	}
	old_value := bottle.map_[key] or { '' }
	had_old_value := key in bottle.map_
	if quota := bottle.quota_ {
		mut current_size := u64(0)
		for existing_key, existing_value in bottle.map_ {
			if existing_key != key {
				current_size += u64(existing_key.len + existing_value.len)
			}
		}
		if current_size + u64(key.len + value.len) > quota {
			return StorageSetResult{
				error: .quota_exceeded
			}
		}
	}
	bottle.map_[key] = value
	if !had_old_value {
		bottle.key_order_ << key
	}
	return StorageSetResult{
		old_value: if had_old_value { old_value } else { none }
	}
}

@[heap]
pub struct LocalStorageBottle {
mut:
	bottle_ &StorageBottle
}

pub fn LocalStorageBottle.create(key StorageKey, quota ?u64, host &StorageHost) &LocalStorageBottle {
	return &LocalStorageBottle{
		bottle_: StorageBottle.create(.local, .local_storage, key, quota, host)
	}
}

pub fn (bottle &LocalStorageBottle) size() int {
	return bottle.bottle_.size()
}

pub fn (bottle &LocalStorageBottle) keys() []string {
	return bottle.bottle_.keys()
}

pub fn (bottle &LocalStorageBottle) get(key string) ?string {
	return bottle.bottle_.get(key)
}

pub fn (mut bottle LocalStorageBottle) set(key string, value string) StorageSetResult {
	return bottle.bottle_.set(key, value)
}

pub fn (mut bottle LocalStorageBottle) clear() {
	bottle.bottle_.clear()
}

pub fn (mut bottle LocalStorageBottle) remove(key string) {
	bottle.bottle_.remove(key)
}

@[heap]
pub struct SessionStorageBottle {
mut:
	bottle_ &StorageBottle
}

pub fn SessionStorageBottle.create(quota ?u64) &SessionStorageBottle {
	return &SessionStorageBottle{
		// This quota-only constructor is the existing isolated in-memory
		// adapter; it has no Source Page or StorageKey constructor owner.
		bottle_: &StorageBottle{
			type_: .session
			endpoint: .session_storage
			quota_: quota
		}
	}
}

pub fn (bottle &SessionStorageBottle) size() int {
	return bottle.bottle_.size()
}

pub fn (bottle &SessionStorageBottle) keys() []string {
	return bottle.bottle_.keys()
}

pub fn (bottle &SessionStorageBottle) get(key string) ?string {
	return bottle.bottle_.get(key)
}

pub fn (mut bottle SessionStorageBottle) set(key string, value string) StorageSetResult {
	return bottle.bottle_.set(key, value)
}

pub fn (mut bottle SessionStorageBottle) clear() {
	bottle.bottle_.clear()
}

pub fn (mut bottle SessionStorageBottle) remove(key string) {
	bottle.bottle_.remove(key)
}

pub fn (mut bottle StorageBottle) clear() {
	if host := bottle.host {
		host.clear(bottle.endpoint, bottle.host_storage_key())
		return
	}
	bottle.map_.clear()
	bottle.key_order_.clear()
}

pub fn (mut bottle StorageBottle) remove(key string) {
	if host := bottle.host {
		host.remove(bottle.endpoint, bottle.host_storage_key(), key)
		return
	}
	if key in bottle.map_ {
		bottle.map_.delete(key)
		index := bottle.key_order_.index(key)
		if index >= 0 {
			bottle.key_order_.delete(index)
		}
	}
}

@[heap]
pub struct StorageBucket {
mut:
	bottles map[int]&StorageBottle
}

pub fn StorageBucket.create(type_ StorageType, key StorageKey, host ?&StorageHost) &StorageBucket {
	mut bucket := &StorageBucket{}
	for endpoint in registered_endpoints() {
		if endpoint.type_ == type_ {
			bucket.bottles[int(endpoint.identifier)] = StorageBottle.create(type_, endpoint.identifier, key, endpoint.quota, host)
		}
	}
	return bucket
}

pub fn (bucket &StorageBucket) bottle(endpoint StorageEndpointType) ?&StorageBottle {
	return bucket.bottles[int(endpoint)] or { none }
}

pub fn (bucket &StorageBucket) bottle_map() map[int]&StorageBottle {
	return bucket.bottles.clone()
}

@[heap]
pub struct StorageShelf {
pub:
	type_       StorageType
	storage_key StorageKey
mut:
	buckets map[string]&StorageBucket
	host    ?&StorageHost
}

pub fn StorageShelf.create(type_ StorageType, key StorageKey, host ?&StorageHost) &StorageShelf {
	return &StorageShelf{
		type_: type_
		storage_key: key
		host: host
		buckets: {
			'default': StorageBucket.create(type_, key, host)
		}
	}
}

pub fn (shelf &StorageShelf) default_bucket() &StorageBucket {
	return shelf.buckets['default'] or { panic('storage shelf is missing its default bucket') }
}

pub fn (shelf &StorageShelf) bucket_map() map[string]&StorageBucket {
	return shelf.buckets.clone()
}

pub fn (shelf &StorageShelf) storage_usage() u64 {
	host := shelf.host or { return 0 }
	usage := host.usage or { return 0 }
	return usage(shelf.storage_key.to_string())
}

pub fn (shelf &StorageShelf) storage_quota() u64 {
	// Bottle limits only cover local/session storage, not the shelf's other
	// storage endpoints. Keep this estimate independent of device free space.
	return u64(10) * 1024 * 1024 * 1024
}

pub fn obtain_a_local_storage_shelf(environment StorageEnvironment, host ?&StorageHost) ?&StorageShelf {
	key := obtain_a_storage_key(environment) or { return none }
	return StorageShelf.create(.local, key, host)
}

// Compatibility test double for callers that need an isolated in-memory shed;
// current obtain-a-bottle algorithms below construct browser-host proxies.
@[heap]
pub struct StorageShed {
mut:
	shelves map[string]&StorageShelf
}

pub fn StorageShed.create() &StorageShed {
	return &StorageShed{}
}

pub fn (mut shed StorageShed) obtain_a_storage_shelf(environment StorageEnvironment, type_ StorageType, host ?&StorageHost) ?&StorageShelf {
	key := obtain_a_storage_key(environment) or { return none }
	serialized := key.to_string()
	if serialized !in shed.shelves {
		shed.shelves[serialized] = StorageShelf.create(type_, key, host)
	}
	return shed.shelves[serialized] or { none }
}

pub fn (mut shed StorageShed) obtain_a_storage_bottle_map(environment StorageEnvironment, endpoint StorageEndpointType, host ?&StorageHost) ?&StorageBottle {
	shelf := shed.obtain_a_storage_shelf(environment, .session, host) or { return none }
	return shelf.default_bucket().bottle(endpoint)
}

pub fn obtain_a_storage_bottle_map(type_ StorageType, environment StorageEnvironment, identifier StorageEndpointType, host ?&StorageHost) ?&StorageBottle {
	key := obtain_a_storage_key(environment) or { return none }
	endpoint := registered_endpoints().filter(it.identifier == identifier && it.type_ == type_)
	if endpoint.len != 1 {
		return none
	}
	return StorageBottle.create(type_, identifier, key, endpoint[0].quota, host)
}

pub fn obtain_a_local_storage_bottle_map(environment StorageEnvironment, identifier StorageEndpointType, host ?&StorageHost) ?&StorageBottle {
	return obtain_a_storage_bottle_map(.local, environment, identifier, host)
}

pub fn obtain_a_session_storage_bottle_map(environment StorageEnvironment, identifier StorageEndpointType, host ?&StorageHost) ?&StorageBottle {
	return obtain_a_storage_bottle_map(.session, environment, identifier, host)
}

@[heap]
pub struct StorageManager {
mut:
	environment_ ?StorageEnvironment
	host_        ?&StorageHost
}

pub fn StorageManager.create() &StorageManager {
	return &StorageManager{}
}

pub fn StorageManager.create_for_environment(environment StorageEnvironment, host ?&StorageHost) &StorageManager {
	return &StorageManager{
		environment_: environment
		host_: host
	}
}

pub struct StorageEstimate {
pub:
	usage ?u64
	quota ?u64
}

pub fn (_ &StorageManager) queue_a_storage_task(steps fn ()) {
	steps()
}

pub fn (manager &StorageManager) estimate() !StorageEstimate {
	environment := manager.environment_ or {
		return error('TypeError: Failed to obtain local storage shelf.')
	}
	shelf := obtain_a_local_storage_shelf(environment, manager.host_) or {
		return error('TypeError: Failed to obtain local storage shelf.')
	}
	return StorageEstimate{
		usage: shelf.storage_usage()
		quota: shelf.storage_quota()
	}
}

@[heap]
pub struct NavigatorStorage {
mut:
	storage_manager_ &StorageManager = unsafe { nil }
}

pub fn NavigatorStorage.create() &NavigatorStorage {
	return &NavigatorStorage{
		storage_manager_: StorageManager.create()
	}
}

// [SameObject] storage getter.
pub fn (navigator &NavigatorStorage) storage() &StorageManager {
	return navigator.storage_manager_
}
