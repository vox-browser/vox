// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of StorageKey, StorageBottle, StorageShelf, StorageShed,
// StorageManager, and NavigatorStorage.
module storageapi

pub struct StorageOrigin {
pub:
	serialized string
	opaque     bool
}

pub struct StorageEnvironment {
pub:
	origin             StorageOrigin
	creation_origin    StorageOrigin
	is_settings_object bool = true
	storage_disabled   bool
}

pub struct StorageKey {
pub:
	origin StorageOrigin
}

pub fn (key StorageKey) to_string() string {
	return key.origin.serialized
}

pub fn (key StorageKey) equals(other StorageKey) bool {
	return !key.origin.opaque && !other.origin.opaque
		&& key.origin.serialized == other.origin.serialized
}

pub fn obtain_a_storage_key_for_non_storage_purposes(environment StorageEnvironment) StorageKey {
	return StorageKey{
		origin: if environment.is_settings_object {
			environment.origin
		} else {
			environment.creation_origin
		}
	}
}

pub fn obtain_a_storage_key(environment StorageEnvironment) ?StorageKey {
	key := obtain_a_storage_key_for_non_storage_purposes(environment)
	if key.origin.opaque || environment.storage_disabled {
		return none
	}
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

// PageClient-facing operations used by a local storage bottle. Session
// bottles remain entirely within the translated storage shed.
pub struct StorageHost {
pub:
	keys   StorageKeysHook   @[required]
	get    StorageGetHook    @[required]
	set    StorageSetHook    @[required]
	clear  StorageClearHook  @[required]
	remove StorageRemoveHook @[required]
}

@[heap]
pub struct StorageBottle {
pub:
	type_       StorageType
	endpoint    StorageEndpointType
	storage_key StorageKey
mut:
	quota_     ?u64
	map_       map[string]string
	key_order_ []string
	host       ?&StorageHost
}

pub fn StorageBottle.create(type_ StorageType, endpoint StorageEndpointType, key StorageKey, quota ?u64, host ?&StorageHost) &StorageBottle {
	return &StorageBottle{
		type_:       type_
		endpoint:    endpoint
		storage_key: key
		quota_:      quota
		host:        host
	}
}

pub fn (bottle &StorageBottle) proxy() &StorageBottle {
	return bottle
}

pub fn (bottle &StorageBottle) quota() ?u64 {
	return bottle.quota_
}

pub fn (bottle &StorageBottle) size() int {
	if bottle.type_ == .local {
		if host := bottle.host {
			return host.keys(bottle.endpoint, bottle.storage_key.to_string()).len
		}
	}
	return bottle.map_.len
}

pub fn (bottle &StorageBottle) keys() []string {
	if bottle.type_ == .local {
		if host := bottle.host {
			return host.keys(bottle.endpoint, bottle.storage_key.to_string())
		}
	}
	return bottle.key_order_.clone()
}

pub fn (bottle &StorageBottle) get(key string) ?string {
	if bottle.type_ == .local {
		if host := bottle.host {
			return host.get(bottle.endpoint, bottle.storage_key.to_string(), key)
		}
	}
	return bottle.map_[key] or { none }
}

pub fn (mut bottle StorageBottle) set(key string, value string) StorageSetResult {
	if bottle.type_ == .local {
		if host := bottle.host {
			return host.set(bottle.endpoint, bottle.storage_key.to_string(), key, value)
		}
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
		bottle_: StorageBottle.create(.session, .session_storage, StorageKey{
			origin: StorageOrigin{}
		}, quota, none)
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
	if bottle.type_ == .local {
		if host := bottle.host {
			host.clear(bottle.endpoint, bottle.storage_key.to_string())
			return
		}
	}
	bottle.map_.clear()
	bottle.key_order_.clear()
}

pub fn (mut bottle StorageBottle) remove(key string) {
	if bottle.type_ == .local {
		if host := bottle.host {
			host.remove(bottle.endpoint, bottle.storage_key.to_string(), key)
			return
		}
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
			bucket.bottles[int(endpoint.identifier)] = StorageBottle.create(type_,
				endpoint.identifier, key, endpoint.quota, host)
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
mut:
	buckets map[string]&StorageBucket
}

pub fn StorageShelf.create(type_ StorageType, key StorageKey, host ?&StorageHost) &StorageShelf {
	return &StorageShelf{
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

pub fn obtain_a_session_storage_bottle_map(mut shed StorageShed, environment StorageEnvironment, identifier StorageEndpointType, host ?&StorageHost) ?&StorageBottle {
	return shed.obtain_a_storage_bottle_map(environment, identifier, host)
}

@[heap]
pub struct StorageManager {}

pub fn StorageManager.create() &StorageManager {
	return &StorageManager{}
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
