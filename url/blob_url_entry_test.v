module url

fn test_source_blob_entry_origin_retains_actual_opaque_environment_and_blob_value() {
	mut actual := parse('blob:https://path-is-not-owner.test:8443/id')?
	assert actual.blob_url_entry() == none
	assert actual.origin().serialize() == 'https://path-is-not-owner.test:8443'
	origin := Origin.create_opaque(.file)
	mut bytes := [u8(0), 128, 255]
	actual.set_blob_url_entry(BlobURLEntry{
		object:      BlobURLBlob{ type_: 'application/octet-stream', data: bytes }
		environment: BlobURLEnvironment{ origin: origin }
	})
	bytes[0] = 42
	assert actual.origin().is_same_origin(origin)
	assert actual.origin().is_opaque_file_origin()
	assert actual.origin().opaque_data()?.nonce == origin.opaque_data()?.nonce
	entry := actual.blob_url_entry()?
	assert entry.environment.origin.is_same_origin(origin)
	mut object := entry.object
	if mut object is BlobURLBlob {
		assert object.type_ == 'application/octet-stream'
		assert object.data == [u8(0), 128, 255]
		object.data[1] = 21
	} else {
		assert false
	}
	retained_object := actual.blob_url_entry()?.object
	if retained_object is BlobURLBlob {
		assert retained_object.data == [u8(0), 128, 255]
	} else {
		assert false
	}
	actual.set_blob_url_entry(none)
	assert actual.blob_url_entry() == none
	assert actual.origin().serialize() == 'https://path-is-not-owner.test:8443'
}

fn test_source_media_source_entry_retains_exact_tuple_environment_origin() {
	mut actual := parse('blob:data:text/plain,path-is-not-owner')?
	owner := Origin.tuple('https', Host.from_string('actual-entry-owner.test'), u16(9443),
		'actual-domain.test')
	actual.set_blob_url_entry(BlobURLEntry{
		object:      BlobURLMediaSource{}
		environment: BlobURLEnvironment{ origin: owner }
	})
	assert actual.blob_url_entry()?.object is BlobURLMediaSource
	assert actual.origin().is_same_origin(owner)
	assert actual.origin().serialize() == 'https://actual-entry-owner.test:9443'
	value := actual.origin()
	if value is OriginTuple {
		assert value.domain? == 'actual-domain.test'
		assert value.port? == 9443
	} else {
		assert false
	}
}

fn test_source_url_component_copies_preserve_blob_entry_value_and_independent_owner_slot() {
	mut original := parse('blob:https://different-path.test/id?old#old')?
	owner := Origin.create_opaque(.standard)
	original.set_blob_url_entry(BlobURLEntry{
		object:      BlobURLBlob{ type_: 'text/plain', data: 'owned snapshot'.bytes() }
		environment: BlobURLEnvironment{ origin: owner }
	})
	mut fragment := original.with_fragment('changed')
	mut query := original.with_query('updated')
	assert fragment.fragment? == 'changed' && query.query? == 'updated'
	assert fragment.origin().is_same_origin(owner) && query.origin().is_same_origin(owner)
	assert fragment.blob_url_entry()?.environment.origin.is_same_origin(owner)
	assert query.blob_url_entry()?.environment.origin.is_same_origin(owner)
	fragment.set_blob_url_entry(none)
	query.set_blob_url_entry(none)
	assert original.origin().is_same_origin(owner)
	assert original.blob_url_entry()?.environment.origin.is_same_origin(owner)
	assert fragment.origin().serialize() == 'https://different-path.test'
	assert query.origin().serialize() == 'https://different-path.test'
}

fn test_source_entry_is_used_only_for_blob_scheme_and_absence_keeps_fresh_opaque_fallback() {
	mut secure := parse('https://ordinary-entry-control.test:8443/page')?
	owner := Origin.create_opaque(.standard)
	secure.set_blob_url_entry(BlobURLEntry{
		object:      BlobURLMediaSource{}
		environment: BlobURLEnvironment{ origin: owner }
	})
	assert secure.blob_url_entry() != none
	assert secure.origin().serialize() == 'https://ordinary-entry-control.test:8443'
	assert !secure.origin().is_same_origin(owner)
	missing := parse('blob:data:text/plain,opaque-fallback')?
	assert missing.blob_url_entry() == none
	assert missing.origin().is_opaque()
	assert !missing.origin().is_same_origin(missing.origin())
}
