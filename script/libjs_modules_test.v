module main

import adblock
import browserjs
import html
import libjs
import page

fn testsuite_begin() { adblock.set_enabled(false) }

fn test_libjs_inline_modules_execute_in_separate_native_document_environments() {
	mut app := &BrowserApp{
		page_model:page.Page.create(1)!
		js_engine:.libjs
		script_policy:.enabled
		layout_tree_only:true
		viewport_width:800
		viewport_height:600
	}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:'https://github.com/vlang/v'
		content_type:'text/html'
		markup:'<!doctype html><body><p id=result>pending</p><script id=classic>globalThis.classicScript=document.currentScript.id;globalThis.documentHead=document.head.nodeName;</script><script type=module>var hidden=1;export const value=42;document.getElementById("result").textContent=value+":"+(this===undefined)+":"+(document.currentScript===null);</script><script type=module>const value=2;document.getElementById("result").textContent+=":"+value;</script>'
	},false)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 32 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	app.poll_javascript_tasks()
	assert app.js_messages == []string{}, app.js_messages.str()
	text := app.document.get_element_by_id('result')?.as_node().text_content()?
	assert text == '42:true:true:2', text
	assert app.js_runtime.evaluate('classicScript+":"+documentHead')! == 'classic:HEAD'
	assert app.js_runtime.evaluate('typeof value+":"+typeof hidden')! == 'undefined:undefined'
	assert !app.js_runtime.native_context_initialized()
	assert app.js_runtime.libjs_vm().execution_context_stack().len == 0
	assert app.js_runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_libjs_module_urls_are_evaluated_once_and_errors_leave_classics_runnable() {
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	source := browserjs.ScriptSource{
		source_type:libjs.SourceType.module
		url:'https://github.com/module.js'
		code:'globalThis.moduleRuns=(globalThis.moduleRuns||0)+1;export const value=42;'
	}
	prepared := browserjs.prepare_script(source)!
	assert runtime.evaluate_prepared(prepared)! == 'undefined'
	assert runtime.evaluate_prepared(prepared)! == 'undefined'
	assert runtime.evaluate('moduleRuns')! == '1'
	failed := browserjs.prepare_script(browserjs.ScriptSource{source_type:.module,url:'https://github.com/bad.js',code:'throw 7;'})!
	runtime.evaluate_prepared(failed) or {
		assert err.msg().contains('7')
		assert runtime.evaluate('6*7')! == '42'
		return
	}
	assert false,'Module exceptions must stay observable'
}
