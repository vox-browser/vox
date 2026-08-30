module storageapi

fn session_environment(origin string) StorageEnvironment {
	return StorageEnvironment{
		origin:          StorageOrigin{
			serialized: origin
		}
		creation_origin: StorageOrigin{
			serialized: origin
		}
	}
}

fn test_storage_key_origin_and_failure_rules() {
	environment := session_environment('https://example.test')
	key := obtain_a_storage_key(environment) or { panic('expected storage key') }
	assert key.to_string() == 'https://example.test'
	assert key.equals(StorageKey{
		origin: StorageOrigin{
			serialized: 'https://example.test'
		}
	})
	assert obtain_a_storage_key(StorageEnvironment{
		origin: StorageOrigin{
			serialized: 'null'
			opaque:     true
		}
	}) == none
	assert obtain_a_storage_key(StorageEnvironment{
		origin:           StorageOrigin{
			serialized: 'https://example.test'
		}
		storage_disabled: true
	}) == none
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
		origin: StorageOrigin{
			serialized: 'https://example.test'
		}
	}
	mut bottle := StorageBottle.create(.session, .session_storage, key, u64(5), none)
	assert bottle.set('a', '1234').error == .none
	assert bottle.set('b', 'x').error == .quota_exceeded
	assert bottle.get('b') == none
	assert bottle.set('a', '1').error == .none
}

fn test_session_bottle_preserves_order_across_updates_removal_and_quota_failure() {
	key := StorageKey{
		origin: StorageOrigin{
			serialized: 'https://example.test'
		}
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

fn test_exact_storage_bottle_bucket_shelf_and_shed_entry_points() {
	key := StorageKey{
		origin: StorageOrigin{
			serialized: 'https://exact.test'
		}
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
		keys:   exact_storage_keys
		get:    exact_storage_get
		set:    exact_storage_set
		clear:  exact_storage_clear
		remove: exact_storage_remove
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
	mut shed := StorageShed.create()
	environment := session_environment('https://exact.test')
	first := obtain_a_session_storage_bottle_map(mut shed, environment, .session_storage,
		none) or { panic('missing session bottle') }
	second := obtain_a_session_storage_bottle_map(mut shed, environment, .session_storage,
		none) or { panic('missing repeated session bottle') }
	assert voidptr(first) == voidptr(second)
}
