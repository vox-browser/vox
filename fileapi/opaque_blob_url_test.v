module fileapi

import url as liburl

@[heap]
struct OpaqueBlobURLSettings {
	origin liburl.Origin
}

fn (settings &OpaqueBlobURLSettings) blob_url_settings_origin() liburl.Origin { return settings.origin }
fn (settings &OpaqueBlobURLSettings) blob_url_settings_identity() voidptr { return voidptr(settings) }
fn (settings &OpaqueBlobURLSettings) blob_url_partition_origin() liburl.Origin { return settings.origin }

fn test_blob_urls_serialize_opaque_origins_as_null_and_keep_unique_identifiers() {
	settings := &OpaqueBlobURLSettings{origin: liburl.Origin.create_opaque(.standard)}
	first := generate_new_blob_url(settings)!
	second := generate_new_blob_url(settings)!
	assert first.starts_with('blob:null/')
	assert second.starts_with('blob:null/')
	assert first != second
	assert first.all_after('blob:null/').len == 36
	assert liburl.parse(first)?.serialize(false) == first
	tuple := &OpaqueBlobURLSettings{origin: liburl.parse('https://blob-origin.example:8443/')?.origin()}
	assert generate_new_blob_url(tuple)!.starts_with('blob:https://blob-origin.example:8443/')
}

fn test_null_blob_url_serialization_preserves_opaque_partition_and_owner_identity() {
	origin := liburl.Origin.create_opaque(.standard)
	creator := &OpaqueBlobURLSettings{origin: origin}
	same := &OpaqueBlobURLSettings{origin: origin}
	other := &OpaqueBlobURLSettings{origin: liburl.Origin.create_opaque(.standard)}
	mut store := BlobURLStore.create()
	blob := Blob.create('opaque payload'.bytes(), 'text/plain')
	value := store.add_entry(BlobURLObject.from_blob(blob), creator)!
	other_value := store.add_entry(BlobURLObject.from_blob(blob), other)!
	assert value.starts_with('blob:null/') && other_value.starts_with('blob:null/')
	entry := store.resolve(liburl.parse(value)?)?
	snapshot := entry.snapshot()
	assert snapshot.environment.origin.is_same_origin(origin)
	assert snapshot.environment.origin.serialize() == 'null'
	assert check_for_same_partition_blob_url_usage(snapshot, same)
	assert !check_for_same_partition_blob_url_usage(snapshot, other)
	store.run_unloading_cleanup_steps(same)
	assert store.length() == 2
	store.run_unloading_cleanup_steps(creator)
	assert store.resolve(liburl.parse(value)?) == none
	assert store.resolve(liburl.parse(other_value)?) != none
	store.run_unloading_cleanup_steps(other)
	assert store.length() == 0
}
