module domurl

import platform

fn test_url_base_cache_matches_uncached_parser_and_invalid_base_validation() {
	mut parser := URLBaseParser{}
	defer { parser.clear() }
	for base in ['https://user:pass@example.test:8443/a/b?x#y', 'https://測試/',
		'file:///C:/a/b', 'about:blank', 'blob:https://example.test/id',
		'\x00\t https://example.test/a\n ', '', 'not a base', 'https://[bad]/'] {
		for input in ['../next?q=a b#f', '//other.test/a', '?next', '#part', '',
			'https://absolute.test/', 'data:text/plain,hello', 'http://[bad]/'] {
			for _ in 0 .. 2 {
				expected := parse_api_url(input, base)
				actual := parser.parse(input, base)
				if reference := expected {
					record := actual or { panic('cached parse failed') }
					assert record.serialize(false) == reference.serialize(false)
					assert record.has_an_opaque_path == reference.has_an_opaque_path
					assert record.blob_url_entry() == none
				} else { assert actual == none }
			}
		}
	}
	assert parser.parse('https://absolute.test/', 'bad base') == none
	assert parser.parse('https://absolute.test/', none)?.serialize(false) == 'https://absolute.test/'
}

fn test_url_base_cache_keys_raw_strings_and_bypasses_oversized_bases() {
	mut parser := URLBaseParser{}
	defer { parser.clear() }
	assert parser.parse('child', 'https://a.test/root/')?.serialize(false) == 'https://a.test/root/child'
	assert parser.parse('child', 'https://b.test/root/')?.serialize(false) == 'https://b.test/root/child'
	assert parser.parse('child', 'https://a.test/root/\t')?.serialize(false) == 'https://a.test/root/child'
	long_base := 'https://long.test/' + 'x'.repeat(url_base_cache_max_bytes)
	assert parser.parse('#f', long_base)?.serialize(false) == long_base + '#f'
	assert parser.parse('child', 'https://a.test/root/\t')?.serialize(false) == 'https://a.test/root/child'
	if !retain_url_base_parse { assert parser.input_? == 'https://a.test/root/\t' }
	parser.clear()
	assert parser.parse('next', 'https://fresh.test/')?.serialize(false) == 'https://fresh.test/next'
}

fn test_url_base_cache_does_not_share_mutable_paths_with_results() {
	mut parser := URLBaseParser{}
	defer { parser.clear() }
	mut first := parser.parse('#first', 'https://user:pass@example.test/a/b?q')?
	first.paths[0] = 'mutated'
	assert parser.parse('#next', 'https://user:pass@example.test/a/b?q')?.serialize(false) ==
		'https://user:pass@example.test/a/b?q#next'
}

fn test_url_base_cache_survives_producer_retirement_eviction_and_clear() {
	mut parser := URLBaseParser{}
	mut producer := platform.new_arena('URL cache producer')
	entry := producer.enter()
	_ = parser.parse('first', 'https://user:pass@example.test:8443/root/?query#fragment')?
	producer.leave(entry)
	producer.release()
	owned := parser.parse('second', 'https://user:pass@example.test:8443/root/?query#fragment')?
	_ = parser.parse('eviction', 'https://other.test/')?
	parser.clear()
	assert owned.serialize(false) == 'https://user:pass@example.test:8443/root/second'
}

fn test_url_base_cache_warm_lookups_do_not_grow_cache_arena() {
	mut parser := URLBaseParser{}
	defer { parser.clear() }
	_ = parser.parse('warm', 'https://example.test/a/b')?
	if retain_url_base_parse { return }
	before := parser.storage_.usage().used
	for _ in 0 .. 128 { assert parser.parse('#same', 'https://example.test/a/b')?.serialize(false) == 'https://example.test/a/b#same' }
	assert parser.storage_.usage().used == before
}
