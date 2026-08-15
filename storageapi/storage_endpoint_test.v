module storageapi

fn test_quota_constants_are_5_mib() {
	assert local_storage_quota == u64(5242880) // 5 * 1024 * 1024
	assert session_storage_quota == u64(5242880)
}

fn test_storage_endpoint_type_enum_values() {
	assert int(StorageEndpointType.caches) == 0
	assert int(StorageEndpointType.indexed_db) == 1
	assert int(StorageEndpointType.local_storage) == 2
	assert int(StorageEndpointType.service_worker_registrations) == 3
	assert int(StorageEndpointType.session_storage) == 4
	// count is the sentinel one-past-the-last value.
	assert int(StorageEndpointType.count) == 5
}

fn test_registered_endpoints_identifiers_in_order() {
	endpoints := registered_endpoints()
	assert endpoints.len == 5
	assert endpoints[0].identifier == .caches
	assert endpoints[1].identifier == .indexed_db
	assert endpoints[2].identifier == .local_storage
	assert endpoints[3].identifier == .service_worker_registrations
	assert endpoints[4].identifier == .session_storage
}

fn test_registered_endpoints_types() {
	endpoints := registered_endpoints()
	// Only session storage is a session type; the rest are local.
	assert endpoints[0].type_ == .local
	assert endpoints[1].type_ == .local
	assert endpoints[2].type_ == .local
	assert endpoints[3].type_ == .local
	assert endpoints[4].type_ == .session
}

fn test_registered_endpoints_quotas() {
	endpoints := registered_endpoints()
	// Caches, IndexedDB and ServiceWorkerRegistrations have no recommended quota.
	assert endpoints[0].quota == none
	assert endpoints[1].quota == none
	assert endpoints[3].quota == none
	// Local and session storage each get a 5 MiB quota.
	local_quota := endpoints[2].quota or { panic('local storage should have a quota') }
	assert local_quota == local_storage_quota
	session_quota := endpoints[4].quota or { panic('session storage should have a quota') }
	assert session_quota == session_storage_quota
}
