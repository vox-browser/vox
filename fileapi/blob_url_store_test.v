module fileapi

fn blob_url_environment(id string, origin string, storage_key string) BlobURLEnvironment {
	return BlobURLEnvironment{
		id:          id
		origin:      origin
		storage_key: storage_key
	}
}

fn test_blob_url_store_add_resolve_partition_and_remove() {
	blob := Blob.create('payload'.bytes(), 'text/plain')
	mut store := BlobURLStore.create()
	owner := blob_url_environment('owner', 'https://example.com', 'partition-a')
	url := store.add_entry(BlobURLObject.from_blob(blob), owner)!
	assert url.starts_with('blob:https://example.com/')
	assert store.length() == 1
	entry := store.resolve('${url}#fragment') or { panic('missing blob URL') }
	assert entry.object.kind == .blob
	assert voidptr(entry.object.blob or { panic('missing blob') }) == voidptr(blob)
	assert obtain_a_blob_object(entry, owner, false) != none
	other_partition := blob_url_environment('other', 'https://example.com', 'partition-b')
	assert obtain_a_blob_object(entry, other_partition, false) == none
	assert obtain_a_blob_object(entry, none, true) != none
	store.remove_entry('${url}#ignored')
	assert store.resolve(url) == none
}

fn test_blob_url_store_opaque_origin_and_environment_cleanup() {
	mut store := BlobURLStore.create()
	environment := blob_url_environment('document-a', 'null', 'partition')
	first := store.add_entry(BlobURLObject.from_blob(Blob.construct(none, none)), environment)!
	second := store.add_entry(BlobURLObject.from_media_source('media-1'), environment)!
	assert first.starts_with('blob:ladybird/')
	assert first != second
	assert store.length() == 2
	store.run_unloading_cleanup_steps('different-document')
	assert store.length() == 2
	store.run_unloading_cleanup_steps('document-a')
	assert store.length() == 0
}

fn test_process_wide_blob_url_store_entry_points() {
	blob := Blob.create('global'.bytes(), 'text/plain')
	environment := blob_url_environment('global-test', 'https://example.test', 'global-partition')
	value := add_entry_to_blob_url_store(BlobURLObject.from_blob(blob), environment)!
	entry := resolve_a_blob_url('${value}#fragment') or { panic('entry was not resolved') }
	assert entry.object.blob or { panic('blob was not stored') } == blob
	remove_entry_from_blob_url_store(value)
	assert resolve_a_blob_url(value) == none
}
