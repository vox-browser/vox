module main

import adblock
import browserjs
import dom
import fetch
import http
import time
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

fn test_libjs_external_module_dispatches_its_load_event_after_native_dom_changes() {
	address := 'https://github.com/vlang/ready.js'
	mut app := &BrowserApp{
		page_model:page.Page.create(1)!
		js_engine:.libjs
		script_policy:.enabled
		layout_tree_only:true
		viewport_width:800
		viewport_height:600
		navigation_preloaded_resources:{
			address:PreloadedResource{
				url:address
				body:'export const value=42;document.getElementById("result").textContent=value+"";'
				request_type:'script'
				status_code:200
				response_headers:[adblock.ResponseHeader{name:'Content-Type',value:'text/javascript'}]
			}
		}
	}
	defer { app.dispose_browser_tab() }
	app.install_loaded_page(LoadedPage{
		url:'https://github.com/vlang/v'
		content_type:'text/html'
		markup:'<!doctype html><body><p id=result>pending</p><script id=module type=module src="./ready.js"></script><script>globalThis.moduleLoads=0;document.getElementById("module").addEventListener("load",function(){moduleLoads++;document.getElementById("result").textContent+=" loaded";});</script>'
	},false)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 32 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	app.poll_javascript_tasks()
	text := app.document.get_element_by_id('result')?.as_node().text_content()?
	assert text == '42 loaded', text
	assert app.js_runtime.evaluate('moduleLoads')! == '1'
	assert app.js_messages == []string{},app.js_messages.str()
	assert !app.js_runtime.native_context_initialized()
}

@[heap]
struct LibJSGraphRequests {
mut:
    urls []string
}

fn libjs_graph_transport(sources map[string]string,seen &LibJSGraphRequests) &fetch.FetchHost {
    return &fetch.FetchHost{perform:fn [sources,seen] (request &fetch.Request) !&fetch.Response {
        mut state := unsafe { &LibJSGraphRequests(seen) }
        key := request.current_url().serialize()
        state.urls << key
        assert request.mode==.cors
        assert request.credentials_mode==.same_origin
        mut response := fetch.Response.create()
        response.url_list=request.url_list.clone()
        response.header_list.append(http.Header{name:'Content-Type',value:if key.ends_with('.txt') { 'text/plain' } else { 'text/javascript' }})
        if source := sources[key] { response.set_body_bytes(source.bytes()) }
        else { response.status=404;response.set_body_bytes([]) }
        return response
    }}
}

fn libjs_graph_wait(settings &html.EnvironmentSettingsObject,runtime &browserjs.Runtime) {
    deadline := time.sys_mono_now()+5*time.second
    mut loop := settings.responsible_event_loop()
    loop.spin_until(fn [runtime,deadline] () bool { return !runtime.has_pending_module_scripts() || time.sys_mono_now()>=deadline })
    assert !runtime.has_pending_module_scripts(),'Module graph did not settle'
}

fn test_libjs_browser_fetches_import_map_graphs_once_and_mutates_the_native_document() {
    address := dom.URL{value:'https://libjs-graph.test/page'}
    mut document := html.create_navigation_document(address,address.origin(),none)!
    document.set_document_type(.html)
    mut runtime := browserjs.Runtime.create_with_engine(.libjs)
    defer { runtime.close();document.finalize() }
    root := document.create_element('html')!
    body := document.create_element('body')!
    mut result := document.create_element('p')!
    result.set_attribute_value('id','result')
    mut script := document.create_element('script')!
    script.set_attribute_value('id','entry')
    script.set_attribute_value('src','/main.js')
    document.as_node().append_child(root.as_node())!
    root.as_node().append_child(body.as_node())!
    body.as_node().append_child(result.as_node())!
    body.as_node().append_child(script.as_node())!
    settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
    runtime.bind_scripting_environment(settings)!
    runtime.install_libjs_document(document)!
    mut scope := settings.universal_global_scope()
    map_ := html.parse_import_map_string('{"imports":{"counter":"./lib/counter.js"}}',address)!
    scope.set_import_map(&map_)
    seen := &LibJSGraphRequests{}
    mut host := browserjs.ModuleHost.create(settings,libjs_graph_transport({
        'https://libjs-graph.test/lib/counter.js':'globalThis.depRuns=(globalThis.depRuns||0)+1;export let n=40;export function inc(){n++}'
        'https://libjs-graph.test/bridge.js':'export {n,inc} from "counter";'
    },seen))
    host.install(mut runtime)!
    runtime.evaluate('globalThis.moduleLoads=0;document.getElementById("entry").addEventListener("load",function(){moduleLoads++;document.getElementById("result").textContent+=" loaded";});')!
    assert runtime.run_document_scripts_collect_errors([browserjs.ScriptSource{
        url:'https://libjs-graph.test/main.js'
        source_type:.module
        element:script
        external_element:script
        code:'import {n,inc} from "./bridge.js";import * as ns from "counter";inc();document.getElementById("result").textContent=(n+1)+":"+ns.n+":"+(document.currentScript===null);'
    }])==[]string{}
    libjs_graph_wait(settings,runtime)
    text := result.as_node().text_content()?
    assert text=='42:41:true loaded','text=${text}; errors=${host.errors()}; requests=${seen.urls}; messages=${runtime.take_libjs_messages()}'
    assert runtime.evaluate('moduleLoads+":"+depRuns')! == '1:1'
    assert seen.urls.len==2,seen.urls.str()
    assert host.errors()==[]string{},host.errors().str()
    assert runtime.libjs_vm().execution_context_stack().len==0
    assert runtime.libjs_vm().interpreter_stack().depth()==0
    assert !runtime.native_context_initialized()
}

fn test_libjs_browser_module_fetch_errors_release_delays_and_keep_later_classics_runnable() {
    for bad in ['missing.js','wrong.txt','syntax.js'] {
        address := dom.URL{value:'https://libjs-errors.test/page'}
        mut document := html.create_navigation_document(address,address.origin(),none)!
    document.set_document_type(.html)
        mut runtime := browserjs.Runtime.create_with_engine(.libjs)
        defer { runtime.close();document.finalize() }
        settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
        runtime.bind_scripting_environment(settings)!
        seen := &LibJSGraphRequests{}
        mut host := browserjs.ModuleHost.create(settings,libjs_graph_transport({
            'https://libjs-errors.test/wrong.txt':'export const n=42;'
            'https://libjs-errors.test/syntax.js':'export const =;'
        },seen))
        host.install(mut runtime)!
        assert runtime.run_document_scripts_collect_errors([browserjs.ScriptSource{url:'https://libjs-errors.test/main.js',source_type:.module,code:'import "./${bad}";globalThis.shouldNotRun=true;'}])==[]string{}
        libjs_graph_wait(settings,runtime)
        assert host.errors().len==1,host.errors().str()
        assert runtime.take_libjs_messages().len==1
        assert runtime.evaluate('typeof shouldNotRun+":"+(6*7)')! == 'undefined:42'
        assert !document.anything_is_delaying_the_load_event()
        assert !runtime.native_context_initialized()
    }
}
