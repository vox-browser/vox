module url

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
	fn C.GC_gcollect()
}

@[noinline]
fn empty_blob_entry_fresh_url() URL {
	return URL{}
}

@[noinline]
fn empty_blob_entry_explicit_none_reference() URL {
	return URL{blob_url_entry_: none}
}

fn test_empty_url_does_not_construct_an_absent_blob_entry_payload() {
	for _ in 0 .. 8 {
		assert empty_blob_entry_fresh_url().blob_url_entry() == none
	}
	mut before := usize(0)
	$if gcboehm ? {
		C.GC_gcollect()
		before = C.GC_get_total_bytes()
	}
	mut empty := 0
	for _ in 0 .. 512 {
		record := empty_blob_entry_fresh_url()
		if record.blob_url_entry() == none && record.host == none && record.paths.len == 0 {
			empty++
		}
	}
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	mut reference_before := usize(0)
	$if gcboehm ? { reference_before = C.GC_get_total_bytes() }
	mut reference_empty := 0
	for _ in 0 .. 512 {
		record := empty_blob_entry_explicit_none_reference()
		if record.blob_url_entry() == none && record.host == none && record.paths.len == 0 {
			reference_empty++
		}
	}
	mut reference_allocated := usize(0)
	$if gcboehm ? { reference_allocated = C.GC_get_total_bytes() - reference_before }
	assert empty == 512
	assert reference_empty == 512
	// Both paths own the same required URL records. Exclude the extra Blob
	// and environment-origin owners of the implicit absent payload.
	assert allocated <= reference_allocated + 512 * 16, 'empty URL allocations: ${allocated}, explicit-none reference: ${reference_allocated}'
}

fn test_present_blob_entry_survives_copy_collection_and_original_clear() {
	mut original := parse('blob:https://url-path.example/id')?
	owner := Origin.create_opaque(.standard)
	mut bytes := [u8(0), 128, 255]
	original.set_blob_url_entry(BlobURLEntry{
		object: BlobURLBlob{type_: 'application/octet-stream', data: bytes}
		environment: BlobURLEnvironment{origin: owner}
	})
	mut snapshot := original.copy()
	bytes[0] = 42
	original.set_blob_url_entry(none)
	$if gcboehm ? { C.GC_gcollect() }
	assert original.blob_url_entry() == none
	assert snapshot.origin().is_same_origin(owner)
	mut first := snapshot.blob_url_entry()?.object
	if mut first is BlobURLBlob {
		assert first.type_ == 'application/octet-stream'
		assert first.data == [u8(0), 128, 255]
		first.data[1] = 21
	} else {
		assert false
	}
	retained := snapshot.blob_url_entry()?.object
	if retained is BlobURLBlob {
		assert retained.data == [u8(0), 128, 255]
	} else {
		assert false
	}
	snapshot.set_blob_url_entry(none)
	assert snapshot.blob_url_entry() == none
	assert snapshot.origin().serialize() == 'https://url-path.example'
	assert empty_blob_entry_fresh_url().blob_url_entry() == none
}

fn test_present_media_source_entry_preserves_its_environment_through_record_copies() {
	mut original := parse('blob:https://url-path.example/id')?
	owner := Origin.tuple('https', Host.from_string('entry-owner.example'), u16(9443), none)
	original.set_blob_url_entry(BlobURLEntry{
		object: BlobURLMediaSource{}
		environment: BlobURLEnvironment{origin: owner}
	})
	value_copy := original
	mut owned_copy := original.copy()
	original.set_blob_url_entry(none)
	$if gcboehm ? { C.GC_gcollect() }
	assert value_copy.blob_url_entry()?.object is BlobURLMediaSource
	assert owned_copy.blob_url_entry()?.object is BlobURLMediaSource
	assert value_copy.origin().serialize() == 'https://entry-owner.example:9443'
	assert owned_copy.origin().is_same_origin(owner)
	owned_copy.set_blob_url_entry(none)
	assert owned_copy.blob_url_entry() == none
	assert value_copy.blob_url_entry()?.environment.origin.is_same_origin(owner)
}
