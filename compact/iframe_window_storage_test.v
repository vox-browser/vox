module main

import browserjs
import html
import platform

fn test_iframe_replay_retires_snapshot_text_and_keeps_dom_writes_owned() {
	mut document := html.parse_document('<!doctype html><body><input id="field"><iframe id="frame"></iframe></body>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://iframe-storage.test/', []string{}, runtime, mut messages)
	assert messages.len == 0
	runtime.evaluate_host('console.log("queued output".repeat(16384));field.setAttribute("data-owner","retained "+"λ😀".repeat(2048));0;')!
	flush_compact_iframe_runtime_state(document, runtime)!
	field := document.get_element_by_id('field')?
	expected := 'retained ' + 'λ😀'.repeat(2048)
	assert field.get_attribute('data-owner')? == expected
	mut storage := document.native_storage()
	mut retained_growth := i64(0)
	$if prealloc {
		mut entered := storage.enter()
		before := storage.arena.usage().used
		for _ in 0 .. 32 { flush_compact_iframe_runtime_state(document, runtime)! }
		retained_growth = storage.arena.usage().used - before
		entered.finish()
		assert retained_growth < 1024 * 1024, '${retained_growth} retained bytes for read-only iframe flushes'
	}
	churn := platform.begin_thread_scratch('iframe replay overwrite')
	_ = []u8{len: 1024 * 1024, init: u8(0xa5)}
	churn.finish()
	assert field.get_attribute('data-owner')? == expected
	assert runtime.evaluate_host('JSON.parse(__ladybirdFinalize()).logs[0].length')! == '${13 * 16384}'
}
