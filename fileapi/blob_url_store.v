// Copyright (c) 2023-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/BlobURLStore.{h,cpp}: live objects and actual settings references.
// HTML implements the settings contract to avoid the FileAPI/HTML import cycle.
module fileapi

import crypto.rand
import platform
import storageapi
import url as liburl

__global file_api_blob_url_store &BlobURLStore

pub enum BlobURLObjectKind {
	blob
	media_source
}

pub type BlobURLMediaSourceAttachHook = fn (voidptr, voidptr) !

pub struct BlobURLObject {
pub:
	kind                BlobURLObjectKind
	blob                ?&Blob
	media_source_id     string
	media_source_handle voidptr
	media_source_attach ?BlobURLMediaSourceAttachHook
}

pub fn BlobURLObject.from_blob(blob &Blob) BlobURLObject {
	return BlobURLObject{
		kind: .blob
		blob: blob
	}
}

// MediaSource is owned by the MediaSourceExtensions module. Its stable host
// identity and attachment callback preserve the object without introducing a
// FileAPI/HTML/MediaSourceExtensions import cycle.
pub fn BlobURLObject.from_media_source(id string) BlobURLObject {
	return BlobURLObject{
		kind:            .media_source
		media_source_id: id
	}
}

pub fn BlobURLObject.from_media_source_object(id string, handle voidptr, attach BlobURLMediaSourceAttachHook) BlobURLObject {
	return BlobURLObject{
		kind: .media_source
		media_source_id: id
		media_source_handle: handle
		media_source_attach: attach
	}
}

// Retains the actual EnvironmentSettingsObject, not an origin snapshot or a
// textual environment ID. HTML's implementation reads its current origin.
pub interface BlobURLSettingsObject {
	blob_url_settings_origin() liburl.Origin
	blob_url_settings_identity() voidptr
}

pub struct BlobURLEntry {
pub:
	object      BlobURLObject
	environment BlobURLSettingsObject
}

pub struct BlobURLStore {
mut:
	entries map[string]BlobURLEntry
}

pub fn BlobURLStore.create() &BlobURLStore {
	return &BlobURLStore{}
}

pub fn blob_url_store() &BlobURLStore {
	// The first lookup can happen while an evicted document is being retired.
	// Process-wide store records must outlive every document payload arena.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
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

pub fn generate_new_blob_url(settings BlobURLSettingsObject) !string {
	origin := settings.blob_url_settings_origin().serialize()
	serialized_origin := if origin == 'null' { 'ladybird' } else { origin }
	return 'blob:${serialized_origin}/${generate_random_uuid()!}'
}

pub fn (mut store BlobURLStore) add_entry(object BlobURLObject, settings BlobURLSettingsObject) !string {
	// Map growth and generated URL keys also belong to process storage.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }

	// Source's GC::Ref variants cannot contain a missing platform object.
	// ID-only MediaSource descriptors belong to the standalone adapter.
	if object.kind == .blob {
		if object.blob == none { panic('Blob URL store requires a live Blob') }
	} else if object.media_source_handle == unsafe { nil } || object.media_source_attach == none {
		panic('Blob URL store requires a live MediaSource')
	}
	url := generate_new_blob_url(settings)!
	store.entries[url] = BlobURLEntry{
		object: object
		environment: settings
	}
	return url
}

// HTML supplies its actual current settings object at the cyclic boundary.
pub fn add_entry_to_blob_url_store(object BlobURLObject, settings BlobURLSettingsObject) !string {
	mut store := blob_url_store()
	return store.add_entry(object, settings)
}

pub struct TopLevelNavigation {}

pub struct TopLevelSelfFetch {}

// The requesting owner may be an actual settings object or base Environment.
// HTML performs Source's as_if<EnvironmentSettingsObject> selection, reading
// the current settings origin or the current creation URL's origin.
pub interface BlobURLUsageEnvironment {
	blob_url_partition_origin() liburl.Origin
}

// V sum types cannot contain an interface directly. This arm retains the
// actual owner interface rather than capturing its origin in a substitute.
pub struct BlobURLRequestEnvironment {
pub:
	environment BlobURLUsageEnvironment @[required]
}

pub type BlobURLObtainEnvironment = BlobURLRequestEnvironment | TopLevelNavigation | TopLevelSelfFetch

pub fn check_for_same_partition_blob_url_usage(entry liburl.BlobURLEntry, environment BlobURLUsageEnvironment) bool {
	blob_key := storageapi.obtain_a_storage_key_for_origin(entry.environment.origin)
	environment_key := storageapi.obtain_a_storage_key_for_origin(environment.blob_url_partition_origin())
	return blob_key.equals(environment_key)
}

pub fn obtain_a_blob_object(entry liburl.BlobURLEntry, environment BlobURLObtainEnvironment) ?liburl.BlobURLObject {
	if environment is BlobURLRequestEnvironment {
		if !check_for_same_partition_blob_url_usage(entry, environment.environment) { return none }
	}
	// Source returns the variant by value; its ByteBuffer copy is independent.
	object := entry.object
	if object is liburl.BlobURLBlob {
		return liburl.BlobURLBlob{ type_: object.type_, data: object.data.clone() }
	}
	return liburl.BlobURLMediaSource{}
}

// DOMURL.cpp::finish_parsing copies the live object's bytes/type and reads
// its creator settings' current origin. Each URL owns this separate value.
pub fn (entry BlobURLEntry) snapshot() liburl.BlobURLEntry {
	mut object := liburl.BlobURLObject(liburl.BlobURLMediaSource{})
	if entry.object.kind == .blob {
		blob := entry.object.blob or { panic('Source Blob URL entry requires its live Blob') }
		object = liburl.BlobURLObject(liburl.BlobURLBlob{
			type_: blob.type_utf16().str()
			data: blob.raw_bytes()
		})
	}
	return liburl.BlobURLEntry{
		object: object
		environment: liburl.BlobURLEnvironment{ origin: entry.environment.blob_url_settings_origin() }
	}
}

// Removal serializes with the fragment; resolve deliberately excludes it.
pub fn (mut store BlobURLStore) remove_entry(url liburl.URL) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }

	store.entries.delete(url.serialize(false))
}

pub fn remove_entry_from_blob_url_store(url liburl.URL) {
	mut store := blob_url_store()
	store.remove_entry(url)
}

pub fn (mut store BlobURLStore) run_unloading_cleanup_steps(settings BlobURLSettingsObject) {
	identity := settings.blob_url_settings_identity()
	mut urls_to_remove := []string{}
	for url, entry in store.entries {
		if entry.environment.blob_url_settings_identity() == identity {
			urls_to_remove << url
		}
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	for url in urls_to_remove {
		store.entries.delete(url)
	}
}

pub fn (store &BlobURLStore) resolve(url liburl.URL) ?BlobURLEntry {
	if url.scheme != 'blob' { panic('Source VERIFY: Blob URL resolution requires the blob scheme') }
	return store.entries[url.serialize(true)] or { none }
}

pub fn resolve_a_blob_url(url liburl.URL) ?BlobURLEntry {
	return blob_url_store().resolve(url)
}

pub fn (store &BlobURLStore) length() int {
	return store.entries.len
}
