// SPDX-License-Identifier: BSD-2-Clause
module main

import adblock
import browserjs
import html
import page

fn testsuite_begin() { adblock.set_enabled(false) }

fn test_execution_audit_distinguishes_configuration_from_an_uninitialized_runtime() {
	mut document := html.parse_document('<!doctype html><title>Unscripted</title>')
	defer { document.finalize() }
	app := BrowserApp{ document: document, js_engine: .libjs }
	audit := app.collect_capture_audit(CaptureAuditConfig{})!
	assert audit.configured_javascript_engine == 'libjs'
	assert audit.javascript_runtime == none
	assert app.js_runtime == unsafe { nil }
}

fn test_execution_audit_records_completed_libjs_modules_without_running_them_again() {
	mut app := &BrowserApp{ page_model: page.Page.create(1)!, js_engine: .libjs, script_policy: .enabled, layout_tree_only: true, viewport_width: 800, viewport_height: 600 }
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{ url: 'https://github.com/vlang/audit', content_type: 'text/html', markup: '<!doctype html><body><p id=result>pending</p><script type=module>let sum=0;for(const [a,b] of [[20,22]]){sum+=a+b};globalThis.moduleRuns=(globalThis.moduleRuns||0)+1;document.getElementById("result").textContent=sum;</script>' }, false)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 32 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	app.poll_javascript_tasks()
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == '42'
	first := app.collect_capture_audit(CaptureAuditConfig{})!.javascript_runtime or { panic('Missing script runtime audit') }
	assert first.engine == 'libjs' && !first.native_context_initialized && !first.closed
	assert first.libjs_execution_generation > 0 && first.modules.len == 1
	assert first.modules[0].status == 'evaluated' && first.modules[0].promise_state == 'fulfilled'
	second := app.js_runtime.execution_audit()
	assert second.libjs_execution_generation == first.libjs_execution_generation
	assert app.js_runtime.evaluate('moduleRuns')! == '1'
}

fn test_execution_audit_exposes_rejection_and_keeps_native_engine_identity() {
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	before := runtime.execution_audit()
	assert before.modules.len == 0 && before.libjs_execution_generation == 0 && !before.native_context_initialized
	prepared := browserjs.prepare_script(browserjs.ScriptSource{ source_type: .module, url: 'https://github.com/failed.mjs', code: 'throw 7;' })!
	runtime.evaluate_prepared(prepared) or {
		audit := runtime.execution_audit()
		assert audit.modules.len == 1 && audit.modules[0].promise_state == 'rejected'
		assert !audit.native_context_initialized && audit.engine == 'libjs'
		mut native := browserjs.Runtime.create()
		defer { native.close() }
		assert native.execution_audit().engine == 'javascriptcore'
		assert native.execution_audit().native_context_initialized
		return
	}
	assert false, 'Module rejection must remain visible'
}
