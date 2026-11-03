module adblock

import os
import platform

fn clear_css_test_memo() {
	document_filter_memo_mutex_.@lock()
	document_filter_memo_.clear()
	document_filter_memo_bytes_ = 0
	document_filter_memo_mutex_.unlock()
}

fn css_test_source(url string, tokens []string) string {
	return 'JSON.stringify(voxDocumentFilters(${encode_transport_json(url)}, ${encode_transport_json(tokens)}))'
}

fn test_document_css_matches_full_rules_and_reuses_css_after_engine_and_document_release() {
	clear_css_test_memo()
	previous := is_enabled()
	set_enabled(true)
	defer { set_enabled(previous) }
	url := 'https://www.theverge.com/'
	tokens := ['.ad-banner']
	expected := document_filters(url, tokens)!.css
	assert expected.contains('div[data-concert]')
	mut arena := platform.new_arena('CSS memo caller')
	entry := arena.enter()
	assert document_css(url, tokens)! == expected
	arena.leave(entry)
	arena.release()
	_ = release_unused_engine()
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert document_css(url, tokens)! == expected
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert document_filter_memo_.len == 1
	clear_css_test_memo()
}

fn test_document_css_memo_caches_empty_css_and_respects_shared_byte_budget() {
	clear_css_test_memo()
	retain_document_filters('empty', '{}')
	retain_document_filter_css('empty', '')
	assert retained_document_filter_css('empty')? == ''
	before := document_filter_memo_bytes_
	retain_document_filters('bounded', '{}')
	retain_document_filter_css('bounded', '.snow{content:"雪😀"}')
	assert document_filter_memo_bytes_ == before + 'bounded'.len + '{}'.len + '.snow{content:"雪😀"}'.len
	retain_document_filter_css('bounded', 'replacement must not allocate')
	assert retained_document_filter_css('bounded')? == '.snow{content:"雪😀"}'
	retain_document_filter_css('empty', 'x'.repeat(document_filter_memo_byte_limit))
	assert retained_document_filter_css('empty')? == ''
	retain_document_filters('no-room', '{}')
	retain_document_filter_css('no-room', 'x'.repeat(document_filter_memo_byte_limit))
	if _ := retained_document_filter_css('no-room') { assert false }
	assert document_filter_memo_bytes_ <= document_filter_memo_byte_limit
	// Eviction drops the CSS lookup alongside its encoded result.
	for i in 0 .. document_filter_memo_limit { retain_document_filters('new-${i}', '{}') }
	if _ := retained_document_filter_css('bounded') { assert false }
	clear_css_test_memo()
}

fn test_document_css_keys_enablement_and_memo_control_match_full_lookup() {
	clear_css_test_memo()
	previous := is_enabled()
	old_control := os.getenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO')
	set_enabled(true)
	defer {
		set_enabled(previous)
		os.setenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO', old_control, true)
	}
	for url in ['https://www.theverge.com/', 'https://www.bbc.com/'] {
		for tokens in [ []string{}, ['.ad-banner'] ] {
			assert document_css(url, tokens)! == document_filters(url, tokens)!.css
		}
	}
	assert document_filter_memo_.len == 4
	set_enabled(false)
	assert document_css('https://www.theverge.com/', ['.ad-banner'])! == ''
	set_enabled(true)
	assert document_css('file:///fixture.html', [])! == ''
	assert document_filter_memo_.len == 4
	expected := document_css('https://www.bbc.com/', [])!
	_ = release_unused_engine()
	os.setenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO', '1', true)
	assert document_css('https://www.bbc.com/', [])! == expected
	assert C.vox_adblock_get_context() != unsafe { nil } || default_worker_pid() > 0
	clear_css_test_memo()
}

fn test_document_css_does_not_memoize_failed_conversion() {
	clear_css_test_memo()
	_ = evaluate_engine('globalThis.cssOriginalFilters=voxDocumentFilters; globalThis.voxDocumentFilters=()=>42')!
	defer {
		_ = evaluate_engine('globalThis.voxDocumentFilters=cssOriginalFilters; delete globalThis.cssOriginalFilters') or { '' }
	}
	mut failed := false
	_ = document_css('https://www.bbc.com/css-memo-failure', []) or { failed = true; '' }
	assert failed
	assert document_filter_memo_.len == 0
}

fn css_refresh_retention_trial(url string, css_only bool) !i64 {
	mut arena := platform.new_arena('CSS refresh retention')
	entry := arena.enter()
	before := arena.usage().used
	for _ in 0 .. 32 {
		actual := if css_only { document_css(url, [])! } else { document_filters(url, [])!.css }
		assert actual == '.snow{content:"雪😀"}'
	}
	growth := arena.usage().used - before
	arena.leave(entry)
	arena.release()
	return growth
}

fn test_document_css_refresh_keeps_no_repeated_scriptlet_and_rule_copies() {
	clear_css_test_memo()
	url := 'https://css-memo.test/'
	source := css_test_source(url, [])
	encoded := encode_transport_json(DocumentFilters{
		css: '.snow{content:"雪😀"}'
		scriptlets: 'const text="λ😀";\n'.repeat(8192)
		filters: ['first rule', 'second rule']
	})
	retain_document_filters(source, encoded)
	assert document_css(url, [])! == '.snow{content:"雪😀"}'
	control := css_refresh_retention_trial(url, false)!
	candidate := css_refresh_retention_trial(url, true)!
	$if prealloc {
		assert candidate < 16 * 1024
		assert candidate * 100 < control
		println('CSS refresh retention: candidate=${candidate} control=${control} bytes')
	}
	clear_css_test_memo()
}
