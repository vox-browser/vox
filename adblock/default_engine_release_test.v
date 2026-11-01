module adblock

import time

#include "@DIR/default_engine_release_test.h"

fn C.vox_adblock_test_exchange_error(&char) &char

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_default_engine_release_restores_complete_filters_and_keeps_owned_results() {
	previous_enabled := is_enabled()
	set_enabled(true)
	defer {
		_ = release_unused_engine()
		set_enabled(previous_enabled)
	}
	_ = release_unused_engine()
	assert !release_unused_engine()
	assert C.vox_adblock_get_context() == unsafe { nil }
	requests := [
		Request{url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js', source_url: 'https://www.theverge.com/', request_type: 'script'},
		Request{url: 'https://cs45.pikabu.ru/v2/event/j/3/ad_request', source_url: 'https://pikabu.ru/', request_type: 'xmlhttprequest', method: 'POST'},
		Request{url: 'https://pikabu.ru/ajax/stories', source_url: 'https://pikabu.ru/', request_type: 'xmlhttprequest'},
		Request{url: 'https://www.wikipedia.org/', source_url: 'https://www.wikipedia.org/', request_type: 'main_frame'},
	]
	expected := requests.map(check(it))
	assert expected.all(it.error == '')
	assert expected[0].blocked
	assert expected[1].blocked
	assert !expected[2].blocked
	assert !expected[3].blocked
	headers := [ResponseHeader{name: 'LLaSalBBubRRl', value: '1'}]
	header_decision := check_response(requests[2], headers)
	assert header_decision.error == ''
	assert header_decision.blocked
	assert header_decision.rule.contains('responseheader=llasalbbubrrl')
	filters := document_filters('https://www.theverge.com/', ['.ad-banner'])!
	assert filters.css.contains('div[data-concert]')
	assert filters.css.contains('.duet--layout--rail')
	assert filters.filters.any(it.contains('abort-current-script'))
	assert filters.filters.any(it.contains('csg_uid'))
	assert filters.scriptlets.contains('const scriptletGlobals =')
	retained_css := filters.css.clone()
	retained_scriptlets := filters.scriptlets.clone()
	retained_rules := filters.filters.clone()
	for _ in 0 .. 2 {
		// Cached decisions need not recreate the idle engine. Exercise releasing
		// an actually live context independently of those retained results.
		_ = evaluate_engine('1')!
		assert release_unused_engine()
		assert !release_unused_engine()
		assert C.vox_adblock_get_context() == unsafe { nil }
		$if gcboehm ? { C.GC_gcollect() }
		assert filters.css == retained_css
		assert filters.scriptlets == retained_scriptlets
		assert filters.filters == retained_rules
		for index, request in requests {
			assert check(request) == expected[index]
		}
		assert check_response(requests[2], headers) == header_decision
		assert document_filters('https://www.theverge.com/', ['.ad-banner'])! == filters
	}
}

fn test_default_engine_release_leaves_custom_engine_and_its_state_independent() {
	previous_enabled := is_enabled()
	set_enabled(true)
	defer {
		_ = release_unused_engine()
		set_enabled(previous_enabled)
	}
	mut custom := new_engine('||release-custom.example^$script\nrelease-custom.example##.private-ad')!
	defer { custom.close() }
	request := Request{url: 'https://release-custom.example/ad.js', source_url: 'https://content.example/', request_type: 'script'}
	assert custom.check(request).blocked
	assert evaluate_custom_engine(custom.context, 'globalThis.releaseFixtureCount=17; releaseFixtureCount')! == '17'
	default_before := check(request)
	assert default_before.error == ''
	assert !default_before.blocked
	for expected_count in 18 .. 21 {
		_ = evaluate_engine('1')!
		assert release_unused_engine()
		assert custom.context != unsafe { nil }
		assert custom.check(request).blocked
		assert evaluate_custom_engine(custom.context, '++releaseFixtureCount')! == '${expected_count}'
		assert check(request) == default_before
	}
}

fn test_default_engine_release_preserves_disabled_and_initialization_error_state() {
	previous_enabled := is_enabled()
	_ = release_unused_engine()
	C.vox_adblock_lock()
	previous_error := C.vox_adblock_test_exchange_error(c'default initialization fixture')
	C.vox_adblock_unlock()
	defer {
		C.vox_adblock_lock()
		_ = C.vox_adblock_test_exchange_error(previous_error)
		C.vox_adblock_unlock()
		set_enabled(previous_enabled)
	}
	set_enabled(false)
	assert !release_unused_engine()
	assert !is_enabled()
	assert check(Request{url: 'https://doubleclick.net/ads.js'}) == Decision{}
	assert document_filters('https://www.theverge.com/', [])! == DocumentFilters{}
	assert C.vox_adblock_get_context() == unsafe { nil }
	set_enabled(true)
	assert !release_unused_engine()
	message := evaluate_engine('1') or { err.msg() }
	assert message == 'default initialization fixture'
	assert unsafe { cstring_to_vstring(C.vox_adblock_get_error()) } == message
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn release_default_engine_after_notification(started chan bool, completed chan bool) {
	started <- true
	completed <- release_unused_engine()
}

fn test_default_engine_release_waits_for_existing_evaluation_lock() {
	_ = evaluate_engine('42')!
	mut started := chan bool{cap: 1}
	mut completed := chan bool{cap: 1}
	C.vox_adblock_lock()
	context := C.vox_adblock_get_context()
	worker := spawn release_default_engine_after_notification(started, completed)
	_ = <-started
	mut completed_while_locked := false
	select {
		_ := <-completed { completed_while_locked = true }
		20 * time.millisecond {}
	}
	context_stayed_live := C.vox_adblock_get_context() == context
	C.vox_adblock_unlock()
	assert !completed_while_locked
	assert context_stayed_live
	assert <-completed
	worker.wait()
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn evaluate_default_engine_during_release() []string {
	mut values := []string{}
	for _ in 0 .. 4 {
		values << evaluate_engine('"Unicode λ 🌍:"+(6*7)') or { 'ERROR: ${err.msg()}' }
	}
	return values
}

fn release_default_engine_during_evaluation() {
	for _ in 0 .. 4 { _ = release_unused_engine() }
}

fn test_default_engine_release_serializes_concurrent_owned_result_conversion() {
	first := spawn evaluate_default_engine_during_release()
	second := spawn evaluate_default_engine_during_release()
	releaser := spawn release_default_engine_during_evaluation()
	first_values := first.wait()
	second_values := second.wait()
	releaser.wait()
	_ = release_unused_engine()
	$if gcboehm ? { C.GC_gcollect() }
	assert first_values == ['Unicode λ 🌍:42'].repeat(4)
	assert second_values == first_values
	assert C.vox_adblock_get_context() == unsafe { nil }
}
