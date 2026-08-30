@[has_globals]
module loader

import dom

fn test_ascii_string_matcher_builds_compact_sorted_trie_and_finds_substrings() {
	matcher := AsciiStringMatcher.create(['tracker', 'ads.example', 'banner']) or { panic(err) }
	assert matcher.contains('https://ads.example/script.js')
	assert matcher.contains('/assets/tracker-v2.js')
	assert matcher.contains('a-banner-image')
	assert !matcher.contains('https://example.test/app.js')
	assert !matcher.contains('TRACKER')
}

fn test_ascii_string_matcher_inherits_suffix_outputs_and_retries_root() {
	matcher := AsciiStringMatcher.create(['he', 'she', 'his', 'hers']) or { panic(err) }
	assert matcher.contains('ushers')
	assert matcher.contains('ahish')
	assert !matcher.contains('xyz')
}

fn test_ascii_string_matcher_rejects_non_ascii_patterns() {
	if _ := AsciiStringMatcher.create(['трекер']) {
		assert false
	} else {
		assert err.msg().contains('ASCII')
	}
}

fn test_content_filter_honors_enabled_and_data_url_exemptions() {
	mut filter := ContentFilter.create()
	filter.set_patterns(['blocked.test']) or { panic(err) }
	assert filter.is_filtered(dom.URL{'https://blocked.test/ad.js'})
	assert !filter.is_filtered(dom.URL{'https://allowed.test/ad.js'})
	assert !filter.is_filtered(dom.URL{'data:text/plain,blocked.test'})
	filter.set_filtering_enabled(false)
	assert !filter.filtering_enabled()
	assert !filter.is_filtered(dom.URL{'https://blocked.test/ad.js'})
}

fn test_resetting_patterns_replaces_existing_matcher() {
	mut filter := ContentFilter.create()
	filter.set_patterns(['old']) or { panic(err) }
	assert filter.contains('old')
	filter.set_patterns(['new']) or { panic(err) }
	assert !filter.contains('old')
	assert filter.contains('new')
}
