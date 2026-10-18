module adblock

import os
import time

// A repeated check of one request, or of one response and its headers, reuses
// the retained decision instead of evaluating the engine again. Every check is
// still logged.
fn test_repeated_default_checks_reuse_the_decision_and_log_every_check() {
	log_path := os.join_path(os.temp_dir(), 'vox-filter-memo-${os.getpid()}-${time.sys_mono_now()}.jsonl')
	previous := os.getenv('VOX_ADBLOCK_LOG')
	os.setenv('VOX_ADBLOCK_LOG', log_path, true)
	defer {
		os.setenv('VOX_ADBLOCK_LOG', previous, true)
		os.rm(log_path) or {}
	}
	request := Request{
		url:          'https://securepubads.g.doubleclick.net/tag/js/gpt.js?memo'
		source_url:   'https://www.theverge.com/'
		request_type: 'script'
	}
	source := 'voxAdblockCheck(${encode_transport_json(request)})'
	first := check(request)
	first_result := retained_filter_decision(source) or { '' }
	assert first.error == '', first.error
	assert first.blocked
	assert retained_filter_decision(source) != none
	// A different retained result shows that the next check reads it.
	retain_filter_decision(source, '{"blocked":false,"exception":true,"rule":"retained","redirect_url":"","error":""}')
	second := check(request)
	assert !second.blocked && second.exception && second.rule == 'retained'
	headers := [ResponseHeader{
		name:  'content-type'
		value: 'text/javascript'
	}]
	response_source := 'voxAdblockCheckResponse(${encode_transport_json(request)},${encode_transport_json(headers)})'
	assert check_response(request, headers).error == ''
	assert retained_filter_decision(response_source) != none
	assert os.read_lines(log_path)!.len == 3
	retain_filter_decision(source, first_result)
}

// The retained decisions are bounded.
fn test_filter_decision_memo_starts_over_at_its_limit() {
	mut index := 0
	for retained_filter_decision_count() < filter_decision_memo_limit {
		retain_filter_decision('filler-${index}', '{}')
		index++
	}
	request := Request{
		url:          'https://bounded.example.test/script-${time.sys_mono_now()}.js'
		source_url:   'https://bounded.example.test/'
		request_type: 'script'
	}
	assert check(request).error == ''
	assert retained_filter_decision_count() == 1
}
