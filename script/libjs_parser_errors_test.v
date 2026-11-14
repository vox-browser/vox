module main

import adblock
import browserjs
import html
import page

fn testsuite_begin() {
	adblock.set_enabled(false)
}

fn test_libjs_parser_failures_remain_observable_and_later_scripts_run() {
	mut app := &BrowserApp{
		page_model: page.Page.create(1)!
		js_engine: .libjs
		script_policy: .enabled
		layout_tree_only: true
		viewport_width: 800
		viewport_height: 600
	}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url: 'https://github.com/vlang/v'
		content_type: 'text/html'
		markup: '<!doctype html><body><p id=result>pending</p><script>console.log("before failure");</script><script>class Untranslated {}</script><script>document.getElementById("result").textContent="later script ran";</script>'
	}, false)
	assert app.js_runtime != unsafe { nil }
	assert app.js_runtime.engine == browserjs.Engine.libjs
	assert !app.js_runtime.native_context_initialized()
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'later script ran'
	assert app.js_messages.filter(it.contains('class')).len == 1
	assert app.js_messages.contains('before failure')
	assert app.js_messages.any(it.contains('https://github.com/vlang/v') && it.contains('LibJS'))
	assert app.js_runtime.libjs_vm().execution_context_stack().len == 0
	assert app.js_runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_libjs_parser_reports_unsupported_dependency_linking_instead_of_a_clean_shell() {
	mut app := &BrowserApp{
		page_model: page.Page.create(1)!
		js_engine: .libjs
		script_policy: .enabled
		layout_tree_only: true
		viewport_width: 800
		viewport_height: 600
	}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url: 'https://github.com/vlang/v'
		content_type: 'text/html'
		markup: '<!doctype html><body><script type=module>import "./dependency.js";export const value=42;</script>'
	}, false)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 32 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	app.poll_javascript_tasks()
	assert app.js_messages.any(it.contains('module dependency linking') && it.contains('LibJS'))
	assert !app.js_runtime.native_context_initialized()
}

fn test_libjs_browser_accepts_deeper_scripts_with_guarded_frontend_limits() {
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	source := '('.repeat(64)+'42'+')'.repeat(64)
	assert browserjs.prepare_script(browserjs.ScriptSource{code:source})!.frontend.reached_recursion_limit
	assert runtime.evaluate(source)! == '42'
	runtime.evaluate('('.repeat(5000)+'0'+')'.repeat(5000)) or {
		assert err.msg().contains('recursion limit')
		assert runtime.evaluate('6*7')! == '42'
		assert !runtime.native_context_initialized()
		return
	}
	assert false, 'Hostile nesting must remain bounded'
}
