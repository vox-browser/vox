module main

import platform

fn test_document_reference_results_survive_query_workspace_reuse() {
	base := 'https://resource.test/dir/page.html?old=1'
	cases := [
		[' ../img/logo.svg#mark ', 'https://resource.test/img/logo.svg#mark'],
		['?new=2', 'https://resource.test/dir/page.html?new=2'],
		['#part', 'https://resource.test/dir/page.html?old=1#part'],
		['//other.test/a/../b', 'https://other.test/b'],
		['https://EXAMPLE.test', 'https://example.test/'],
		['data:image/svg+xml,%3Csvg%3E', 'data:image/svg+xml,%3Csvg%3E'],
		['', base],
		[' \t\r\n', base],
	]
	mut results := []string{}
	for sample in cases { results << resolve_document_reference(sample[0], base) }
	for _ in 0 .. 32 {
		assert resolve_document_reference('other/path?q=1', base) == 'https://resource.test/dir/other/path?q=1'
	}
	for index, sample in cases { assert results[index] == sample[1] }
	// The fallback for an unparseable base stays identical to resolve_url().
	assert resolve_document_reference('asset.png', 'http://[') == resolve_url('asset.png', '')
}

fn test_document_reference_queries_retain_only_serialized_url_storage() {
	path := 'long-path-'.repeat(400)
	reference := '  ../${path}#mark  '
	expected := 'https://resource.test/${path}#mark'
	mut storage := platform.new_arena('serialized resource URLs')
	entry := storage.enter()
	before := storage.usage().used
	mut results := []string{cap:128}
	for _ in 0 .. 128 {
		results << resolve_document_reference(reference, 'https://resource.test/dir/page.html')
	}
	growth := storage.usage().used - before
	storage.leave(entry)
	$if prealloc { assert growth < 128 * (expected.len + 192), '${growth} retained URL bytes' }
	for result in results { assert result == expected }
	storage.release()
}
