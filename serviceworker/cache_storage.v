// Copyright (c) 2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ServiceWorker/CacheStorage.{h,cpp,idl}. These rejection
// surfaces intentionally match the current upstream implementation.
module serviceworker

pub struct CacheStorageResult {
pub:
	state WorkerPromiseState
	error string
	value ?bool
}

pub struct CacheStorage {}

pub fn (storage &CacheStorage) open(cache_name string) CacheStorageResult {
	_ = storage
	_ = cache_name
	return CacheStorageResult{
		state: .rejected
		error: 'NotSupportedError: CacheStorage.open() is not yet implemented'
	}
}

pub fn (storage &CacheStorage) has(cache_name string) CacheStorageResult {
	_ = storage
	_ = cache_name
	// C++ rejects the promise with the JS boolean false (it does not resolve).
	return CacheStorageResult{
		state: .rejected
		value: false
	}
}
