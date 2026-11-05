module domurl

import platform

fn test_url_input_cache_preserves_raw_keys_base_presence_and_parser_results() {
	mut parser := URLInputParser{}
	defer { parser.clear() }
	bases := [?string(none), ?string(''), ?string('invalid'), ?string('https://user:pass@[2001:db8::1]:8443/a/b?x#y'),
		?string('\x00\t https://example.test/a\n '), ?string('https://測試/'), ?string('file:///C:/a/b'),
		?string('about:blank')]
	for _ in 0 .. 3 {
		for base in bases {
			for input in ['../next?q=a b#f', '//other.test/a', '?next', '#part', '',
				'https://absolute.test/', 'data:text/plain,hello', 'blob:https://example.test/id',
				'http://[bad]/', 'http://example.test:65536/', 'https://host.test/?#',
				'https://user:pass@faß.de/測試/😀?日本語#é', '\t https://example.test/a\n '] {
				expected := parse_api_url(input, base)
				actual := parser.parse(input, base)
				if reference := expected {
					record := actual or { panic('memoized parse failed') }
					assert record.serialize(false) == reference.serialize(false)
					assert record.has_an_opaque_path == reference.has_an_opaque_path
					assert record.query == reference.query
					assert record.fragment == reference.fragment
					assert record.blob_url_entry() == none
				} else {
					assert actual == none
				}
			}
		}
	}
	assert parser.parse('https://absolute.test/', 'invalid') == none
	assert parser.parse('https://absolute.test/', none)?.serialize(false) == 'https://absolute.test/'
}

fn test_url_input_cache_results_and_keys_survive_producer_and_cache_retirement() {
	mut parser := URLInputParser{}
	mut producer := platform.new_arena('URL input producer')
	entry := producer.enter()
	input := '../item?q=one#fragment'.clone()
	base := 'https://user:pass@[2001:db8::1]:8443/root/page'.clone()
	_ = parser.parse(input, base)?
	_ = parser.parse(input, base)?
	producer.leave(entry)
	producer.release()
	mut first := parser.parse('../item?q=one#fragment',
		'https://user:pass@[2001:db8::1]:8443/root/page')?
	second := parser.parse('../item?q=one#fragment',
		'https://user:pass@[2001:db8::1]:8443/root/page')?
	first.paths[0] = 'changed'
	first.username = 'changed'
	assert second.serialize(false) == 'https://user:pass@[2001:db8::1]:8443/item?q=one#fragment'
	parser.clear()
	assert second.serialize(false) == 'https://user:pass@[2001:db8::1]:8443/item?q=one#fragment'
	assert first.serialize(false) == 'https://changed:pass@[2001:db8::1]:8443/changed?q=one#fragment'
	assert parser.parse('https://fresh.test/', none)?.serialize(false) == 'https://fresh.test/'
	parser.clear()
}

fn test_url_input_cache_hash_collisions_retain_exact_pair_identity_and_recent_way() {
	mut parser := URLInputParser{}
	defer { parser.clear() }
	first := 'https://collision.test/0'
	set := url_input_cache_set(first, none)
	mut inputs := [first]
	for i in 1 .. 65536 {
		input := 'https://collision.test/${i}'
		if url_input_cache_set(input, none) == set { inputs << input }
		if inputs.len == 4 { break }
	}
	assert inputs.len == 4
	for _ in 0 .. 2 {
		for input in inputs[..2] {
			assert parser.parse(input, none)?.serialize(false) == input
		}
	}
	if !retain_url_input_parse {
		assert parser.slots_[set * 2].input == inputs[0]
		assert parser.slots_[set * 2 + 1].input == inputs[1]
	}
	assert parser.parse(inputs[0], none)?.serialize(false) == inputs[0]
	assert parser.parse(inputs[2], none)?.serialize(false) == inputs[2]
	assert parser.parse(inputs[2], none)?.serialize(false) == inputs[2]
	if !retain_url_input_parse {
		assert parser.slots_[set * 2].input == inputs[0]
		assert parser.slots_[set * 2 + 1].input == inputs[2]
	}
	for _ in 0 .. 8 {
		for input in inputs {
			assert parser.parse(input, none)?.serialize(false) == input
		}
	}
}

fn test_url_input_cache_warm_hits_do_not_grow_cache_and_oversized_inputs_bypass_it() {
	mut parser := URLInputParser{}
	defer { parser.clear() }
	_ = parser.parse('child', 'https://example.test/root/')?
	if !retain_url_input_parse {
		assert parser.storage_ == unsafe { nil }
	}
	_ = parser.parse('child', 'https://example.test/root/')?
	before := if parser.storage_ == unsafe { nil } { i64(0) } else { parser.storage_.usage().used }
	for _ in 0 .. 128 {
		assert parser.parse('child', 'https://example.test/root/')?.serialize(false) == 'https://example.test/root/child'
	}
	if !retain_url_input_parse {
		assert parser.storage_.usage().used == before
	}
	for length in [url_input_cache_max_bytes, url_input_cache_max_bytes + 1, 8192] {
		input := 'https://example.test/' + 'a'.repeat(length)
		assert parser.parse(input, none)?.serialize(false) == input
		base := 'https://example.test/' + 'b'.repeat(length)
		assert parser.parse('#end', base)?.serialize(false) == base + '#end'
	}
	if !retain_url_input_parse {
		assert parser.storage_.usage().used == before
	}
}

fn test_url_input_cache_admission_filter_is_only_a_storage_hint() {
	mut parser := URLInputParser{}
	defer { parser.clear() }
	for bit in [0, 63, 64, 32767] {
		parser.seen_ = [512]u64{}
		key := u64(bit) | (u64(bit) << 32)
		assert !parser.admit(key)
		assert parser.admit(key)
	}
	for i in 0 .. parser.seen_.len { parser.seen_[i] = ~u64(0) }
	assert parser.parse('https://first.test/', none)?.serialize(false) == 'https://first.test/'
	assert parser.parse('https://second.test/', none)?.serialize(false) == 'https://second.test/'
	parser.admission_misses_ = 4096
	assert !parser.admit(u64(12345))
	assert parser.admission_misses_ == 1
	prefix := 'https://boundary.test/'
	edge := prefix + 'x'.repeat(url_input_cache_max_bytes - prefix.len)
	assert edge.len == url_input_cache_max_bytes
	for _ in 0 .. 3 {
		assert parser.parse(edge, none)?.serialize(false) == edge
		assert parser.parse('#fragment', edge)?.serialize(false) == edge + '#fragment'
	}
}

fn test_url_input_cache_bounds_replaced_storage_and_keeps_escaped_results() {
	mut parser := URLInputParser{}
	defer { parser.clear() }
	_ = parser.parse('https://survivor.test/a/b?query#fragment', none)?
	_ = parser.parse('https://survivor.test/a/b?query#fragment', none)?
	survivor := parser.parse('https://survivor.test/a/b?query#fragment', none)?
	mut retired := false
	mut rounds := 64
	mut suffix_bytes := 32
	$if prealloc {
		rounds = 4096
		suffix_bytes = 1024
	}
	for i in 0 .. rounds {
		input := 'https://bounded.test/${i}/' + 'x'.repeat(suffix_bytes)
		assert parser.parse(input, none)?.serialize(false) == input
		assert parser.parse(input, none)?.serialize(false) == input
		if !retain_url_input_parse {
			assert parser.storage_.usage().used < url_input_cache_storage_bytes + 64 * 1024
			retired = retired || parser.storage_.reset_count() > 0
		}
	}
	$if prealloc {
		if !retain_url_input_parse {
			assert retired
		}
	}
	parser.clear()
	assert survivor.serialize(false) == 'https://survivor.test/a/b?query#fragment'
}
