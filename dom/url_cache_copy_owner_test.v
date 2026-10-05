// SPDX-License-Identifier: BSD-2-Clause
module dom

fn test_fresh_compatibility_url_record_does_not_share_paths_with_the_cache() {
	address := URL{value: 'https://fresh-cache-copy.test/original/item?query#fragment'}
	mut supplied := address.parsed()?
	supplied.paths[0] = 'changed'
	assert supplied.serialize(false) == 'https://fresh-cache-copy.test/changed/item?query#fragment'
	assert address.serialize() == address.value
	assert address.parsed()?.paths == ['original', 'item']
	assert URL{value: address.value}.serialize() == address.value
}

fn test_cached_document_url_record_mutation_does_not_change_its_base_or_other_owners() {
	address := URL{value: 'https://document-cache-copy.test/original/page.html'}
	document := Document.create(address)
	// Document creation has already parsed this serialized compatibility URL.
	mut supplied := document.url.parsed()?
	supplied.paths[0] = 'changed'
	assert supplied.serialize(false) == 'https://document-cache-copy.test/changed/page.html'
	assert document.url_string() == address.value
	assert document.base_url().serialize() == address.value
	assert document.encoding_parse_url('child.txt')?.serialize() == 'https://document-cache-copy.test/original/child.txt'
	assert Document.create(address).url_string() == address.value
}
