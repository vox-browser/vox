// Copyright (c) 2024-2025, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/StorageAPI/StorageEndpoint.cpp and
// StorageType.h — the StorageType and StorageEndpointType enums, the StorageEndpoint record, and the set
// of registered storage endpoints. The storage bottles/buckets/shelves/sheds that use these endpoints
// are GC- and Page-coupled and are out of scope.
// https://storage.spec.whatwg.org/#storage-endpoint
module storageapi

// https://storage.spec.whatwg.org/#storage-type — a storage type is "local" or "session".
pub enum StorageType {
	local
	session
}

// A storage endpoint's identifier (a storage identifier). `count` is the sentinel one-past-the-last
// value, matching the C++ enum.
pub enum StorageEndpointType {
	caches                       // 0
	indexed_db                   // 1
	local_storage                // 2
	service_worker_registrations // 3
	session_storage              // 4
	count                        // 5
}

// The recommended per-bottle quota for local and session storage: 5 MiB (5 * MiB, MiB = 1024 * 1024).
pub const local_storage_quota = u64(5) * 1024 * 1024
pub const session_storage_quota = u64(5) * 1024 * 1024

// https://storage.spec.whatwg.org/#storage-endpoint
pub struct StorageEndpoint {
pub:
	identifier StorageEndpointType
	type_      StorageType
	// null (none) or a recommended quota in bytes for each corresponding storage bottle.
	quota ?u64
}

// https://storage.spec.whatwg.org/#registered-storage-endpoints
pub fn registered_endpoints() []StorageEndpoint {
	return [
		StorageEndpoint{
			identifier: .caches
			type_:      .local
		},
		StorageEndpoint{
			identifier: .indexed_db
			type_:      .local
		},
		StorageEndpoint{
			identifier: .local_storage
			type_:      .local
			quota:      local_storage_quota
		},
		StorageEndpoint{
			identifier: .service_worker_registrations
			type_:      .local
		},
		StorageEndpoint{
			identifier: .session_storage
			type_:      .session
			quota:      session_storage_quota
		},
	]
}
