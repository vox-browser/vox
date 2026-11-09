// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Standalone compatibility store: origin/partition strings and textual cleanup
// IDs retain the former adapter behavior. Source settings ownership and URL
// snapshots belong to BlobURLStore instead.
module fileapi

import platform

__global file_api_legacy_blob_url_store &LegacyBlobURLStore

pub struct LegacyBlobURLEnvironment {
pub:
	id          string
	origin      string
	storage_key string
}

pub struct LegacyBlobURLEntry {
pub:
	object      BlobURLObject
	environment LegacyBlobURLEnvironment
}

pub struct LegacyBlobURLStore {
mut:
	entries map[string]LegacyBlobURLEntry
}

pub fn LegacyBlobURLStore.create() &LegacyBlobURLStore {
	return &LegacyBlobURLStore{}
}

pub fn legacy_blob_url_store() &LegacyBlobURLStore {
	// The first lookup can happen while an evicted document is being retired.
	// Process-wide store records must outlive every document payload arena.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if file_api_legacy_blob_url_store == unsafe { nil } {
		file_api_legacy_blob_url_store = LegacyBlobURLStore.create()
	}
	return file_api_legacy_blob_url_store
}

// https://w3c.github.io/FileAPI/#unicodeBlobURL
pub fn generate_new_legacy_blob_url(origin string) !string {
	serialized_origin := if origin == '' || origin == 'null' { 'ladybird' } else { origin }
	return 'blob:${serialized_origin}/${generate_random_uuid()!}'
}

// https://w3c.github.io/FileAPI/#add-an-entry
pub fn (mut store LegacyBlobURLStore) add_entry(object BlobURLObject, environment LegacyBlobURLEnvironment) !string {
	// Map growth and generated URL keys also belong to process storage.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }

	url := generate_new_legacy_blob_url(environment.origin)!
	store.entries[url] = LegacyBlobURLEntry{
		object:      object
		environment: LegacyBlobURLEnvironment{
			id: environment.id.clone()
			origin: environment.origin.clone()
			storage_key: environment.storage_key.clone()
		}
	}
	return url
}

pub fn add_legacy_entry_to_blob_url_store(object BlobURLObject, environment LegacyBlobURLEnvironment) !string {
	mut store := legacy_blob_url_store()
	return store.add_entry(object, environment)
}

// https://www.w3.org/TR/FileAPI/#check-for-same-partition-blob-url-usage
pub fn check_for_same_partition_legacy_blob_url_usage(entry LegacyBlobURLEntry, environment LegacyBlobURLEnvironment) bool {
	return entry.environment.storage_key == environment.storage_key
}

pub type LegacyBlobURLObtainEnvironment = LegacyBlobURLEnvironment | TopLevelNavigation | TopLevelSelfFetch

// https://www.w3.org/TR/FileAPI/#blob-url-obtain-object
pub fn obtain_a_legacy_blob_object(entry LegacyBlobURLEntry, environment LegacyBlobURLObtainEnvironment) ?BlobURLObject {
	if environment is LegacyBlobURLEnvironment {
		requested_environment := environment as LegacyBlobURLEnvironment
		if !check_for_same_partition_legacy_blob_url_usage(entry, requested_environment) {
			return none
		}
	}
	return entry.object
}

// https://w3c.github.io/FileAPI/#removeTheEntry
pub fn (mut store LegacyBlobURLStore) remove_entry(url string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }

	store.entries.delete(blob_url_without_fragment(url))
}

pub fn remove_legacy_entry_from_blob_url_store(url string) {
	mut store := legacy_blob_url_store()
	store.remove_entry(url)
}

// https://w3c.github.io/FileAPI/#lifeTime
pub fn (mut store LegacyBlobURLStore) run_unloading_cleanup_steps(environment_id string) {
	mut urls_to_remove := []string{}
	for url, entry in store.entries {
		if entry.environment.id == environment_id {
			urls_to_remove << url
		}
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	for url in urls_to_remove {
		store.entries.delete(url)
	}
}

fn blob_url_without_fragment(url string) string {
	index := url.index_u8(`#`)
	return if index < 0 { url } else { url[..index] }
}

// https://w3c.github.io/FileAPI/#blob-url-resolve
pub fn (store &LegacyBlobURLStore) resolve(url string) ?LegacyBlobURLEntry {
	if !url.starts_with('blob:') {
		return none
	}
	return store.entries[blob_url_without_fragment(url)] or { none }
}

pub fn resolve_a_legacy_blob_url(url string) ?LegacyBlobURLEntry {
	return legacy_blob_url_store().resolve(url)
}

pub fn (store &LegacyBlobURLStore) length() int {
	return store.entries.len
}
