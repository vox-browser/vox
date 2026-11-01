module adblock

import os
import platform

fn clear_document_filter_test_memo() {
	document_filter_memo_mutex_.@lock()
	document_filter_memo_.clear()
	document_filter_memo_bytes_ = 0
	document_filter_memo_mutex_.unlock()
}

fn test_document_filter_memo_returns_owned_results_without_restoring_idle_engine() {
	clear_document_filter_test_memo()
	previous := is_enabled()
	set_enabled(true)
	defer { set_enabled(previous) }
	url := 'https://www.theverge.com/'
	tokens := ['.ad-banner']
	expected := document_filters(url, tokens)!
	assert expected.css.contains('div[data-concert]')
	assert expected.filters.len > 0
	_ = release_unused_engine()
	assert C.vox_adblock_get_context() == unsafe { nil }
	mut rules := document_filters(url, tokens)!.filters
	rules[0] = 'caller mutation'
	actual := document_filters(url, tokens)!
	assert actual == expected
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_document_filter_memo_keeps_url_and_tokens_in_the_key_and_respects_enablement() {
	clear_document_filter_test_memo()
	previous := is_enabled()
	set_enabled(true)
	defer { set_enabled(previous) }
	for url in ['https://www.theverge.com/', 'https://www.bbc.com/'] {
		for tokens in [ []string{}, ['.ad-banner'] ] {
			_ = document_filters(url, tokens)!
		}
	}
	assert document_filter_memo_.len == 4
	set_enabled(false)
	assert document_filters('https://www.theverge.com/', ['.ad-banner'])! == DocumentFilters{}
	set_enabled(true)
	assert document_filters('file:///fixture.html', ['.ad-banner'])! == DocumentFilters{}
	assert document_filter_memo_.len == 4
}

fn test_document_filter_memo_control_really_evaluates_the_engine() {
	clear_document_filter_test_memo()
	previous := os.getenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO')
	defer { os.setenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO', previous, true) }
	expected := document_filters('https://www.bbc.com/', [])!
	_ = release_unused_engine()
	os.setenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO', '1', true)
	assert document_filters('https://www.bbc.com/', [])! == expected
	assert C.vox_adblock_get_context() != unsafe { nil } || default_worker_pid() > 0
}

fn test_document_filter_memo_does_not_change_custom_engine_results() {
	_ = document_filters('https://www.bbc.com/', ['.memo-private-ad'])!
	mut custom := new_engine('bbc.com##.memo-private-ad')!
	defer { custom.close() }
	result := evaluate_custom_engine(custom.context,
		'JSON.stringify(voxDocumentFilters("https://www.bbc.com/", [".memo-private-ad"]))')!
	filters := decode_transport_json[DocumentFilters](result)!
	assert filters.css.contains('.memo-private-ad')
}

fn test_document_filter_memo_does_not_retain_failed_result_conversion() {
	clear_document_filter_test_memo()
	_ = evaluate_engine('globalThis.memoOriginalFilters=voxDocumentFilters; globalThis.voxDocumentFilters=()=>42')!
	defer {
		_ = evaluate_engine('globalThis.voxDocumentFilters=memoOriginalFilters; delete globalThis.memoOriginalFilters') or { '' }
	}
	mut failed := false
	_ = document_filters('https://www.bbc.com/memo-failure', []) or {
		failed = true
		DocumentFilters{}
	}
	assert failed
	assert document_filter_memo_.len == 0
}

fn test_document_filter_memo_bounds_entries_and_encoded_bytes() {
	clear_document_filter_test_memo()
	for i in 0 .. document_filter_memo_limit {
		retain_document_filters('entry-${i}', '{}')
	}
	assert document_filter_memo_.len == document_filter_memo_limit
	retain_document_filters('new entry', '{}')
	assert document_filter_memo_.len == 1
	retain_document_filters('oversized', 'x'.repeat(document_filter_memo_byte_limit))
	assert document_filter_memo_.len == 1
	retain_document_filters('large', 'x'.repeat(document_filter_memo_byte_limit - 10))
	assert document_filter_memo_.len == 1
	assert document_filter_memo_bytes_ <= document_filter_memo_byte_limit
	clear_document_filter_test_memo()
}

fn test_document_filter_memo_owns_document_arena_keys_and_values() {
	clear_document_filter_test_memo()
	mut arena := platform.new_arena('cosmetic memo source')
	entry := arena.enter()
	retain_document_filters('arena fixture'.clone(), 'owned result'.clone())
	arena.leave(entry)
	arena.release()
	assert retained_document_filters('arena fixture')? == 'owned result'
	clear_document_filter_test_memo()
}
