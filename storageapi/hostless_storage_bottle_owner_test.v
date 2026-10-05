module storageapi

import url as liburl

__global source_host_bottle_observed_key = ''

fn source_host_bottle_keys(_ StorageEndpointType, key string) []string {
	source_host_bottle_observed_key = key
	return ['actual-key']
}

fn source_host_bottle_get(_ StorageEndpointType, _ string, _ string) ?string {
	return none
}

fn source_host_bottle_set(_ StorageEndpointType, _ string, _ string, _ string) StorageSetResult {
	return StorageSetResult{}
}

fn source_host_bottle_clear(_ StorageEndpointType, _ string) {}

fn source_host_bottle_remove(_ StorageEndpointType, _ string, _ string) {}

fn test_hostless_session_adapter_preserves_quota_map_without_fabricating_a_typed_key() {
	mut adapter := SessionStorageBottle.create(u64(5))
	assert adapter.bottle_.storage_key == none
	assert adapter.bottle_.host == none
	assert adapter.bottle_.quota()? == 5
	assert adapter.set('a', '1234').error == .none
	assert adapter.set('b', 'x').error == .quota_exceeded
	assert adapter.get('a')? == '1234'
	assert adapter.keys() == ['a']
	adapter.remove('a')
	assert adapter.size() == 0
	adapter.set('x', 'y')
	adapter.clear()
	assert adapter.keys().len == 0
	assert adapter.bottle_.storage_key == none
}

fn test_host_backed_constructor_retains_actual_key_and_uses_its_source_serialization() {
	origin := liburl.parse('https://actual-host-key.test:8443/page')?.origin()
	key := obtain_a_storage_key_for_origin(origin)
	host := &StorageHost{
		keys:   source_host_bottle_keys
		get:    source_host_bottle_get
		set:    source_host_bottle_set
		clear:  source_host_bottle_clear
		remove: source_host_bottle_remove
	}
	actual := LocalStorageBottle.create(key, none, host)
	assert actual.bottle_.storage_key?.origin.is_same_origin(origin)
	assert actual.keys() == ['actual-key']
	assert source_host_bottle_observed_key == 'https://actual-host-key.test:8443'
}
