module storageapi

import url as liburl

fn storage_test_origin(address string) liburl.Origin {
	parsed := liburl.parse(address) or { panic('invalid actual test origin URL') }
	return parsed.origin()
}

fn session_environment(origin string) StorageEnvironment {
	return StorageEnvironment{
		origin: storage_test_origin(origin)
		creation_url: liburl.parse(origin) or { panic('invalid actual creation URL') }
	}
}

fn test_storage_key_origin_and_failure_rules() {
	environment := session_environment('https://example.test')
	key := obtain_a_storage_key(environment) or { panic('expected storage key') }
	assert key.to_string() == 'https://example.test'
	assert key.equals(StorageKey{
		origin: storage_test_origin('https://example.test')
	})
	assert obtain_a_storage_key(StorageEnvironment{
		origin: liburl.Origin.create_opaque(.standard)
	}) == none
	file_key := obtain_a_storage_key(StorageEnvironment{
		origin: liburl.Origin.create_opaque(.file)
	}) or { panic('file origins should be storage-capable') }
	assert file_key.to_string() == 'file://'
	assert !file_key.origin.is_opaque()
	assert obtain_a_storage_key(StorageEnvironment{
		origin: storage_test_origin('https://example.test')
		storage_disabled: true
	}) != none
}

fn test_legacy_storage_key_byte_codec_preserves_legacy_flags() {
	key := LegacyStorageKeyRecord{
		origin: LegacyStorageOrigin{
			serialized: 'opaque-file:example'
			opaque: true
			opaque_file: true
		}
	}
	encoded := encode_legacy_storage_key(key)
	assert encoded[..4] == [u8(19), 0, 0, 0]
	assert encoded[4..encoded.len - 2] == 'opaque-file:example'.bytes()
	assert encoded[encoded.len - 2..] == [u8(1), 1]
	decoded := decode_legacy_storage_key(encoded) or { panic(err) }
	assert decoded.origin == key.origin
	if _ := decode_legacy_storage_key(encoded[..5]) {
		assert false
	}
	mut invalid_boolean := encode_legacy_storage_key(key)
	invalid_boolean[invalid_boolean.len - 1] = 2
	if _ := decode_legacy_storage_key(invalid_boolean) {
		assert false
	}
}

fn test_session_storage_shed_bucket_and_bottle_map() {
	mut shed := &StorageShed{}
	environment := session_environment('https://example.test')
	mut bottle := shed.obtain_a_storage_bottle_map(environment, .session_storage, none) or {
		panic('expected bottle')
	}
	assert bottle.size() == 0
	assert bottle.set('a', 'one').old_value == none
	assert bottle.set('a', 'two').old_value? == 'one'
	assert bottle.get('a')? == 'two'
	assert bottle.keys() == ['a']
	bottle.remove('a')
	assert bottle.get('a') == none
	bottle.set('b', 'three')
	bottle.clear()
	assert bottle.size() == 0
	// Re-obtaining the shelf uses the same origin-keyed object.
	again := shed.obtain_a_storage_bottle_map(environment, .session_storage, none) or {
		panic('expected bottle')
	}
	assert again == bottle
}

fn test_session_bottle_enforces_endpoint_quota() {
	key := StorageKey{
		origin: storage_test_origin('https://example.test')
	}
	mut bottle := StorageBottle.create(.session, .session_storage, key, u64(5), none)
	assert bottle.set('a', '1234').error == .none
	assert bottle.set('b', 'x').error == .quota_exceeded
	assert bottle.get('b') == none
	assert bottle.set('a', '1').error == .none
}

fn test_session_bottle_preserves_order_across_updates_removal_and_quota_failure() {
	key := StorageKey{
		origin: storage_test_origin('https://example.test')
	}
	mut bottle := StorageBottle.create(.session, .session_storage, key, u64(8), none)
	assert bottle.set('b', '1').error == .none
	assert bottle.set('a', '2').error == .none
	assert bottle.keys() == ['b', 'a']
	assert bottle.set('b', '3').old_value? == '1'
	assert bottle.keys() == ['b', 'a']
	bottle.remove('b')
	assert bottle.set('b', '4').error == .none
	assert bottle.keys() == ['a', 'b']
	assert bottle.set('too-long', 'x').error == .quota_exceeded
	assert bottle.keys() == ['a', 'b']
	bottle.clear()
	assert bottle.keys().len == 0
}

fn test_navigator_storage_is_same_object() {
	navigator := NavigatorStorage.create()
	assert navigator.storage() == navigator.storage()
}

struct ExactStorageHostState {
mut:
	map_ map[string]string
}

__global exact_storage_host_state = &ExactStorageHostState{}
__global exact_storage_task_ran = false

fn exact_storage_task() {
	exact_storage_task_ran = true
}

fn exact_storage_keys(_ StorageEndpointType, _ string) []string {
	return exact_storage_host_state.map_.keys()
}

fn exact_storage_get(_ StorageEndpointType, _ string, key string) ?string {
	return exact_storage_host_state.map_[key] or { none }
}

fn exact_storage_set(_ StorageEndpointType, _ string, key string, value string) StorageSetResult {
	old := exact_storage_host_state.map_[key] or { '' }
	had_old := key in exact_storage_host_state.map_
	exact_storage_host_state.map_[key] = value
	return StorageSetResult{
		old_value: if had_old { old } else { none }
	}
}

fn exact_storage_clear(_ StorageEndpointType, _ string) {
	exact_storage_host_state.map_.clear()
}

fn exact_storage_remove(_ StorageEndpointType, _ string, key string) {
	exact_storage_host_state.map_.delete(key)
}

fn exact_storage_usage(_ string) u64 {
	mut usage := u64(0)
	for key, value in exact_storage_host_state.map_ {
		usage += u64(key.len + value.len)
	}
	return usage
}

fn test_exact_storage_bottle_bucket_shelf_and_shed_entry_points() {
	key := StorageKey{
		origin: storage_test_origin('https://exact.test')
	}
	base := StorageBottle.create(.session, .session_storage, key, u64(10), none)
	assert voidptr(base.proxy()) == voidptr(base)
	assert base.quota()? == 10

	mut session := SessionStorageBottle.create(u64(8))
	assert session.size() == 0
	assert session.set('a', '1').error == .none
	assert session.keys() == ['a']
	assert session.get('a')? == '1'
	session.remove('a')
	assert session.size() == 0
	session.set('b', '2')
	session.clear()
	assert session.keys().len == 0

	exact_storage_host_state.map_.clear()
	host := &StorageHost{
		keys: exact_storage_keys
		get: exact_storage_get
		set: exact_storage_set
		clear: exact_storage_clear
		remove: exact_storage_remove
		usage: exact_storage_usage
	}
	mut local := LocalStorageBottle.create(key, local_storage_quota, host)
	assert local.set('a', 'one').old_value == none
	assert local.size() == 1
	assert local.keys() == ['a']
	assert local.get('a')? == 'one'
	local.remove('a')
	assert local.size() == 0
	local.set('b', 'two')
	local.clear()
	assert local.size() == 0

	bucket := StorageBucket.create(.session, key, none)
	assert int(StorageEndpointType.session_storage) in bucket.bottle_map()
	shelf := StorageShelf.create(.session, key, none)
	assert 'default' in shelf.bucket_map()
	environment := session_environment('https://exact.test')
	assert obtain_a_session_storage_bottle_map(environment, .session_storage, none) != none
}

fn test_current_storage_bottles_proxy_both_local_and_session_data_to_the_host() {
	exact_storage_host_state.map_.clear()
	host := &StorageHost{
		keys: exact_storage_keys
		get: exact_storage_get
		set: exact_storage_set
		clear: exact_storage_clear
		remove: exact_storage_remove
		usage: exact_storage_usage
	}
	environment := session_environment('https://current.test')
	mut local := obtain_a_local_storage_bottle_map(environment, .local_storage, host) or {
		panic('missing local bottle')
	}
	assert local.set('local', 'one').error == .none
	assert local.get('local')? == 'one'

	mut session := obtain_a_session_storage_bottle_map(environment, .session_storage, host) or {
		panic('missing session bottle')
	}
	assert session.set('session', 'two').error == .none
	assert session.get('session')? == 'two'
	assert session.keys().len == 2
	assert obtain_a_storage_bottle_map(.local, environment, .session_storage, host) == none
}

fn test_storage_manager_estimate_uses_host_usage_and_registered_local_quota() {
	exact_storage_host_state.map_ = {
		'a': '1234'
	}
	host := &StorageHost{
		keys: exact_storage_keys
		get: exact_storage_get
		set: exact_storage_set
		clear: exact_storage_clear
		remove: exact_storage_remove
		usage: exact_storage_usage
	}
	manager := StorageManager.create_for_environment(session_environment('https://estimate.test'), host)
	exact_storage_task_ran = false
	manager.queue_a_storage_task(exact_storage_task)
	assert exact_storage_task_ran
	estimate := manager.estimate()!
	assert estimate.usage? == 5
	assert estimate.quota? == local_storage_quota

	unconfigured := StorageManager.create()
	if _ := unconfigured.estimate() {
		assert false
	} else {
		assert err.msg().contains('Failed to obtain local storage shelf')
	}
}
