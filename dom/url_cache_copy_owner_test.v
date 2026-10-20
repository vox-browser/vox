// SPDX-License-Identifier: BSD-2-Clause
module dom

import platform

fn test_compatibility_url_cache_owns_strings_from_a_temporary_parse() {
	mut arena := platform.new_arena('temporary URL parser')
	entry := arena.enter()
	address := URL{value: 'https://User:secret@url-arena-owner.test:8443/a%20path/second?query#fragment'.clone()}
	assert address.serialize() == 'https://User:secret@url-arena-owner.test:8443/a%20path/second?query#fragment'
	arena.leave(entry)
	arena.reset()
	// Recreate the lookup key independently of the discarded input.
	cached := URL{value: 'https://User:secret@url-arena-owner.test:8443/a%20path/second?query#fragment'}
	assert cached.serialize() == 'https://User:secret@url-arena-owner.test:8443/a%20path/second?query#fragment'
	assert cached.serialized_host() == 'url-arena-owner.test'
	assert cached.username() == 'User' && cached.password() == 'secret'
	assert cached.with_pathname('/replacement').serialize() == 'https://User:secret@url-arena-owner.test:8443/replacement?query#fragment'
	assert cached.serialize() == 'https://User:secret@url-arena-owner.test:8443/a%20path/second?query#fragment'
	arena.release()
}

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
