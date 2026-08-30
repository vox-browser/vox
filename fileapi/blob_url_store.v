// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FileAPI/BlobURLStore.{h,cpp}. The browser owns the process-wide
// store and current settings object; this typed store makes both dependencies
// explicit and implements the URL generation, partition check, lookup, removal,
// and environment cleanup algorithms.
module fileapi

import crypto.rand

__global file_api_blob_url_store &BlobURLStore

pub enum BlobURLObjectKind {
	blob
	media_source
}

pub struct BlobURLObject {
pub:
	kind            BlobURLObjectKind
	blob            ?&Blob
	media_source_id string
}

pub fn BlobURLObject.from_blob(blob &Blob) BlobURLObject {
	return BlobURLObject{
		kind: .blob
		blob: blob
	}
}

// MediaSource is owned by the MediaSourceExtensions module. Its stable host
// identity is sufficient for the File API store algorithms.
pub fn BlobURLObject.from_media_source(id string) BlobURLObject {
	return BlobURLObject{
		kind:            .media_source
		media_source_id: id
	}
}

pub struct BlobURLEnvironment {
pub:
	id          string
	origin      string
	storage_key string
}

pub struct BlobURLEntry {
pub:
	object      BlobURLObject
	environment BlobURLEnvironment
}

pub struct BlobURLStore {
mut:
	entries map[string]BlobURLEntry
}

pub fn BlobURLStore.create() &BlobURLStore {
	return &BlobURLStore{}
}

pub fn blob_url_store() &BlobURLStore {
	if file_api_blob_url_store == unsafe { nil } {
		file_api_blob_url_store = BlobURLStore.create()
	}
	return file_api_blob_url_store
}

fn generate_random_uuid() !string {
	mut bytes := rand.bytes(16)!
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	hex := bytes.hex()
	return '${hex[..8]}-${hex[8..12]}-${hex[12..16]}-${hex[16..20]}-${hex[20..]}'
}

// https://w3c.github.io/FileAPI/#unicodeBlobURL
pub fn generate_new_blob_url(origin string) !string {
	serialized_origin := if origin == '' || origin == 'null' { 'ladybird' } else { origin }
	return 'blob:${serialized_origin}/${generate_random_uuid()!}'
}

// https://w3c.github.io/FileAPI/#add-an-entry
pub fn (mut store BlobURLStore) add_entry(object BlobURLObject, environment BlobURLEnvironment) !string {
	url := generate_new_blob_url(environment.origin)!
	store.entries[url] = BlobURLEntry{
		object:      object
		environment: environment
	}
	return url
}

pub fn add_entry_to_blob_url_store(object BlobURLObject, environment BlobURLEnvironment) !string {
	mut store := blob_url_store()
	return store.add_entry(object, environment)
}

// https://www.w3.org/TR/FileAPI/#check-for-same-partition-blob-url-usage
pub fn check_for_same_partition_blob_url_usage(entry BlobURLEntry, environment BlobURLEnvironment) bool {
	return entry.environment.storage_key == environment.storage_key
}

// https://www.w3.org/TR/FileAPI/#blob-url-obtain-object
pub fn obtain_a_blob_object(entry BlobURLEntry, environment ?BlobURLEnvironment, navigation bool) ?BlobURLObject {
	if !navigation {
		requested_environment := environment or { return none }
		if !check_for_same_partition_blob_url_usage(entry, requested_environment) {
			return none
		}
	}
	return entry.object
}

// https://w3c.github.io/FileAPI/#removeTheEntry
pub fn (mut store BlobURLStore) remove_entry(url string) {
	store.entries.delete(blob_url_without_fragment(url))
}

pub fn remove_entry_from_blob_url_store(url string) {
	mut store := blob_url_store()
	store.remove_entry(url)
}

// https://w3c.github.io/FileAPI/#lifeTime
pub fn (mut store BlobURLStore) run_unloading_cleanup_steps(environment_id string) {
	mut urls_to_remove := []string{}
	for url, entry in store.entries {
		if entry.environment.id == environment_id {
			urls_to_remove << url
		}
	}
	for url in urls_to_remove {
		store.entries.delete(url)
	}
}

fn blob_url_without_fragment(url string) string {
	index := url.index_u8(`#`)
	return if index < 0 { url } else { url[..index] }
}

// https://w3c.github.io/FileAPI/#blob-url-resolve
pub fn (store &BlobURLStore) resolve(url string) ?BlobURLEntry {
	if !url.starts_with('blob:') {
		return none
	}
	return store.entries[blob_url_without_fragment(url)] or { none }
}

pub fn resolve_a_blob_url(url string) ?BlobURLEntry {
	return blob_url_store().resolve(url)
}

pub fn (store &BlobURLStore) length() int {
	return store.entries.len
}
