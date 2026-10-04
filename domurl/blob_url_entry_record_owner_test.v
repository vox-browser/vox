module domurl

import url as liburl

fn test_source_domurl_origin_consumes_actual_embedded_entry_record() {
	mut record := liburl.parse('blob:https://fallback-is-not-owner.test:8443/id')?
	owner := liburl.Origin.create_opaque(.file)
	record.set_blob_url_entry(liburl.BlobURLEntry{
		object:      liburl.BlobURLBlob{ type_: 'text/plain', data: 'actual URL snapshot'.bytes() }
		environment: liburl.BlobURLEnvironment{ origin: owner }
	})
	mut actual := DOMURL.initialize_a_url(record)
	assert actual.href() == 'blob:https://fallback-is-not-owner.test:8443/id'
	assert actual.origin() == 'null'
	assert actual.extract_an_origin().is_same_origin(Origin.create(owner))
	actual.set_hash('changed')
	actual.set_search('?new-query')
	assert actual.href() == 'blob:https://fallback-is-not-owner.test:8443/id?new-query#changed'
	assert actual.extract_an_origin().is_same_origin(Origin.create(owner))
	assert actual.record.blob_url_entry()?.environment.origin.is_same_origin(owner)
	actual.set_href('blob:https://replacement-path.test:9443/new-id')!
	assert actual.record.blob_url_entry() == none
	assert actual.origin() == 'https://replacement-path.test:9443'
	assert !actual.extract_an_origin().is_same_origin(Origin.create(owner))
}
