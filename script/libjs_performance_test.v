module main

import adblock
import browserjs
import dom
import html
import page

fn testsuite_begin() { adblock.set_enabled(false) }

fn test_libjs_performance_marks_retain_real_native_entries_and_wrapper_identity() {
	address := dom.URL{ value: 'https://performance.test/page' }
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_performance_binding()!
	runtime.install_performance_binding()!
	actual := runtime.evaluate('var mark=performance.mark("js-parse-end:fixture",{startTime:42});mark.name+":"+mark.entryType+":"+mark.startTime+":"+mark.duration+":"+(mark.detail===null)+":"+(performance.getEntriesByName(mark.name,"mark")[0]===mark)')!
	assert actual == 'js-parse-end:fixture:mark:42:0:true:true', actual
	mut scope := settings.window_or_worker_global_scope()!
	native := scope.performance()
	entries := native.get_entries_by_name('js-parse-end:fixture', none)
	assert entries.len == 1
	assert entries[0].start_time == 42 && entries[0].duration == 0
	assert runtime.evaluate('performance.now()>=0&&performance.timeOrigin>0')! == 'true'
	assert runtime.evaluate('mark.toJSON().name===mark.name&&mark.toJSON().startTime===42')! == 'true'
	assert runtime.evaluate('var rejected=0;try{performance.mark.call({},"bad")}catch(e){rejected++}try{performance.mark("negative",{startTime:-1})}catch(e){rejected++}try{performance.mark("nonfinite",{startTime:1/0})}catch(e){rejected++}try{performance.mark("detail",{detail:{}})}catch(e){rejected++}rejected')! == '4'
	assert native.get_entries_by_type('mark').len == 1
	assert runtime.evaluate('performance.clearMarks(mark.name);performance.getEntriesByType("mark").length+":"+mark.startTime')! == '0:42'
	assert native.get_entries_by_type('mark').len == 0
	assert !runtime.native_context_initialized()
	assert runtime.libjs_vm().execution_context_stack().len == 0
}

fn test_libjs_parser_bundles_record_native_performance_marks_before_dom_mutation() {
	mut app := &BrowserApp{
		page_model:       page.Page.create(1)!
		js_engine:        .libjs
		script_policy:    .enabled
		layout_tree_only: true
		viewport_width:   800
		viewport_height:  600
	}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:          'https://github.com/vlang/v'
		content_type: 'text/html'
		markup:       '<!doctype html><body><p id=result>pending</p><script>performance.mark("js-parse-end:fixture.js");document.getElementById("result").textContent=performance.getEntriesByType("mark")[0].name;</script>'
	}, false)
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'js-parse-end:fixture.js'
	assert app.js_messages == []string{}, app.js_messages.str()
	settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	mut scope := settings.window_or_worker_global_scope()!
	assert scope.performance().get_entries_by_name('js-parse-end:fixture.js', none).len == 1
	assert !app.js_runtime.native_context_initialized()
}
