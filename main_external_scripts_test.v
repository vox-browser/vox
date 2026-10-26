module main

import browserjs
import dom
import html
import os
import time
import x.json2

fn dynamic_script_fixture(code string) (&dom.Document, &browserjs.Runtime, &BrowserScriptRequestLoader, []string) {
	mut document := html.parse_document_with_url('<!doctype html><html><head><script id="bootstrap"></script></head><body></body></html>', dom.URL{ value: 'https://dynamic-script.example/' })
	mut runtime := browserjs.Runtime.create()
	mut loader := &BrowserScriptRequestLoader{
		document: document
		// Tests deliver responses explicitly, including out-of-order completions.
		fetch:    fn (_ string, _ string, _ chan PreloadedResource) {}
	}
	mut messages := []string{}
	_ := script_sources(document, document.url.serialize(), {}, mut messages)
	run_document_script_sources_with_resource_loaders(document, document.url.serialize(), [browserjs.ScriptSource{ code: code }], runtime,
		browser_fetch_image_request, none, loader, mut messages)
	return document, runtime, loader, messages
}

fn dynamic_script_response(loader &BrowserScriptRequestLoader, name string, code string, failure string) {
	loader.results <- PreloadedResource{
		url:          'https://dynamic-script.example/${name}'
		source_url:   loader.document.url.serialize()
		request_type: 'script'
		body:         code
		error:        failure
	}
}

fn test_dynamic_external_scripts_execute_per_element_and_fire_trusted_load_after_exceptions() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];globalThis.checks=[];
for(const id of ["first","second"]){const s=document.createElement("script");s.id=id;s.src="bundle.js";
s.onload=function(e){checks.push(this===s&&e.target===s&&e.currentTarget===s&&e.isTrusted&&!e.bubbles&&!e.cancelable&&document.currentScript===null);order.push("load-"+id);this.id="renamed-"+id;this.remove();};
s.onerror=()=>checks.push(false);document.head.appendChild(s);}
document.addEventListener("DOMContentLoaded",()=>order.push("ready"));window.addEventListener("load",()=>order.push("window-load"));
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert messages == []
	assert loader.requests.len == 2
	assert loader.active_fetches == 1
	assert document.anything_is_delaying_the_load_event()
	dynamic_script_response(loader, 'bundle.js', 'order.push(document.currentScript.id);throw new Error("dynamic-script-test-exception");', '')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["ready","first","load-first","second","load-second"]'
	assert runtime.evaluate_host('checks.length===2&&checks.every(Boolean)')! == 'true'
	assert !document.anything_is_delaying_the_load_event()
	assert loader.requests.len == 0
	assert runtime.evaluate_host('document.currentScript===null')! == 'true'
}

fn test_dynamic_async_false_waits_for_earlier_ordered_scripts_but_not_async_scripts() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];globalThis.checks=[];
for(const id of ["one","two","three"]){const s=document.createElement("script");s.id=id;s.src=id+".js";
checks.push(s.async===true);if(id!=="three"){s.async=false;checks.push(s.async===false&&!s.hasAttribute("async"));}
s.onload=()=>order.push("load-"+id);document.head.appendChild(s);}
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert messages == []
	assert loader.requests.len == 3
	assert loader.requests[0].ordered && loader.requests[1].ordered && !loader.requests[2].ordered
	dynamic_script_response(loader, 'two.js', 'order.push("two");', '')
	dynamic_script_response(loader, 'three.js', 'order.push("three");', '')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["three","load-three"]'
	assert document.anything_is_delaying_the_load_event()
	dynamic_script_response(loader, 'one.js', 'order.push("one");', '')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["three","load-three","one","load-one","two","load-two"]'
	assert runtime.evaluate_host('checks.length===5&&checks.every(Boolean)')! == 'true'
	assert !document.anything_is_delaying_the_load_event()
}

fn test_dynamic_failed_scripts_fire_error_once_and_reinsertion_does_not_retry() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];globalThis.failed=document.createElement("script");failed.src="missing.js";
failed.onload=()=>order.push("wrong-load");failed.onerror=e=>order.push(e.isTrusted&&e.target===failed?"error":"wrong-error");document.head.appendChild(failed);
for(const [type,nomodule] of [["application/json",false],["module",false],["",true]]){const s=document.createElement("script");s.type=type;s.src="ignored.js";if(nomodule)s.setAttribute("nomodule","");document.head.appendChild(s);}
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert messages == []
	assert loader.requests.len == 1
	dynamic_script_response(loader, 'missing.js', '', 'Test fetch failure')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["error"]'
	assert messages.any(it.contains('Test fetch failure'))
	runtime.evaluate_host('failed.remove();failed.src="changed.js";document.head.appendChild(failed);__ladybirdFlushPendingScriptMutations();')!
	loader.discover()
	assert loader.requests.len == 0
	assert !document.anything_is_delaying_the_load_event()
}

fn test_async_scripts_preserve_fetch_completion_order_between_polls() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];
for(const id of ["one","two"]){const s=document.createElement("script");s.src=id+".js";s.onload=()=>order.push("load-"+id);document.head.appendChild(s);}
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	dynamic_script_response(loader, 'two.js', 'order.push("two");', '')
	dynamic_script_response(loader, 'one.js', 'order.push("one");', '')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["two","load-two","one","load-one"]'
	assert !document.anything_is_delaying_the_load_event()
}

fn test_dynamic_prepared_scripts_run_after_removal_but_not_after_adoption() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];
for(const id of ["removed","adopted"]){const s=document.createElement("script");s.id=id;s.src=id+".js";s.onload=()=>order.push("load-"+id);document.head.appendChild(s);}
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert loader.requests.len == 2
	mut removed := document.get_element_by_id('removed')?.as_node()
	removed.remove(false)
	mut other := dom.Document.create(dom.URL{ value: 'https://other-script.example/' })
	defer { other.finalize() }
	adopted := document.get_element_by_id('adopted')?.as_node()
	other.adopt_node(adopted)
	dynamic_script_response(loader, 'removed.js', 'order.push(document.currentScript.id);', '')
	dynamic_script_response(loader, 'adopted.js', 'order.push("wrong-adopted");', '')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["removed","load-removed"]'
	assert !document.anything_is_delaying_the_load_event()
}

fn test_dynamic_loader_cancellation_releases_document_load_delays() {
	mut document, mut runtime, mut loader, messages := dynamic_script_fixture(r'
const s=document.createElement("script");s.src="pending.js";document.head.appendChild(s);
')
	defer {
		runtime.close()
		document.finalize()
	}
	assert messages == []
	assert document.anything_is_delaying_the_load_event()
	loader.cancel()
	assert !document.anything_is_delaying_the_load_event()
	assert loader.requests.len == 0
	loader.discover()
	assert loader.requests.len == 0
}

fn test_connected_scripts_prepare_after_late_src_or_type_attribute_changes() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];
globalThis.lateSource=document.createElement("script");document.head.appendChild(lateSource);
globalThis.lateType=document.createElement("script");lateType.type="application/json";lateType.src="typed.js";document.head.appendChild(lateType);
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert messages == []
	assert loader.requests.len == 0
	version := document.dom_tree_version()
	runtime.evaluate_host('lateSource.src="source.js";lateType.type="text/javascript";__ladybirdFlushPendingScriptMutations();')!
	assert document.dom_tree_version() == version
	loader.discover()
	assert loader.requests.len == 2
	dynamic_script_response(loader, 'source.js', 'order.push("source");', '')
	dynamic_script_response(loader, 'typed.js', 'order.push("typed");', '')
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["source","typed"]'
	assert !document.anything_is_delaying_the_load_event()
}

fn test_cloning_an_executed_script_preserves_its_started_state() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.checks=[];const initial=document.getElementById("bootstrap");initial.src="must-not-repeat.js";
const wrapper=document.createElement("div");wrapper.appendChild(initial);document.body.appendChild(wrapper);
const copy=wrapper.cloneNode(true);document.body.appendChild(copy);
const s=document.createElement("script"),d=Object.getOwnPropertyDescriptor(s,"async");
s.async=true;checks.push(s.async&&s.hasAttribute("async"));s.async=0;checks.push(!s.async&&!s.hasAttribute("async"));
for(const receiver of [{},null,document.body,new Proxy(s,{})]){try{d.get.call(receiver);checks.push(false);}catch(e){checks.push(e instanceof TypeError);}}
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert messages == []
	loader.discover()
	assert loader.requests.len == 0
	assert runtime.evaluate_host('checks.length===6&&checks.every(Boolean)')! == 'true'
}

fn test_dynamic_classic_script_fetches_a_real_local_resource_on_the_background_path() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture('globalThis.order=[];')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	path := os.join_path(os.temp_dir(), 'vox-dynamic-script-${os.getpid()}-${time.sys_mono_now()}.js')
	defer { os.rm(path) or {} }
	os.write_file(path, 'order.push(document.currentScript.id);')!
	loader.fetch = fetch_script_in_background
	runtime.evaluate_host('const fetched=document.createElement("script");fetched.id="fetched";fetched.src=${json2.encode('file://' + path)};fetched.onload=()=>order.push("load");document.head.appendChild(fetched);__ladybirdFlushPendingScriptMutations();')!
	loader.discover()
	assert loader.active_fetches == 1
	deadline := time.sys_mono_now() + i64(5 * time.second)
	for loader.requests.len > 0 && time.sys_mono_now() < deadline {
		loader.poll(runtime, mut messages)
		time.sleep(time.millisecond)
	}
	assert loader.requests.len == 0
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["fetched","load"]'
	assert messages == []
}

fn test_window_load_waits_for_dynamic_scripts_inserted_by_completion_handlers() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];const first=document.createElement("script");first.src="first.js";
first.onload=()=>{order.push("first-load");const next=document.createElement("script");next.src="next.js";next.onload=()=>order.push("next-load");document.head.appendChild(next);};document.head.appendChild(first);
window.addEventListener("load",()=>order.push("window-load"));
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	mut images := new_browser_image_request_loader(document, {})
	images.finish_initialization(true)
	mut app := BrowserApp{ document: document, js_runtime: runtime, image_request_loader: images }
	assert images.load_event_pending
	dynamic_script_response(loader, 'first.js', 'order.push("first");', '')
	loader.poll(runtime, mut messages)
	runtime.evaluate_host('__ladybirdFlushPendingScriptMutations();')!
	loader.discover()
	app.poll_browser_image_requests()
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["first","first-load"]'
	dynamic_script_response(loader, 'next.js', 'order.push("next");', '')
	loader.poll(runtime, mut messages)
	app.poll_browser_image_requests()
	app.poll_browser_image_requests()
	assert runtime.evaluate_host('JSON.stringify(order)')! == '["first","first-load","next","next-load","window-load"]'
	assert !document.anything_is_delaying_the_load_event()
}

fn test_dynamic_fetch_concurrency_is_bounded_and_queued_requests_resume() {
	mut document, mut runtime, mut loader, mut messages := dynamic_script_fixture(r'
globalThis.order=[];
for(let i=0;i<11;i++){const s=document.createElement("script");s.src=i+".js";document.head.appendChild(s);}
')
	defer {
		loader.cancel()
		runtime.close()
		document.finalize()
	}
	assert messages == []
	assert loader.requests.len == 11
	assert loader.active_fetches == max_browser_script_fetches
	assert loader.queued.len == 3
	for i in 0 .. max_browser_script_fetches {
		dynamic_script_response(loader, '${i}.js', 'order.push(${i});', '')
	}
	loader.poll(runtime, mut messages)
	assert loader.active_fetches == 3
	assert loader.queued.len == 0
	assert loader.requests.len == 3
	for i in max_browser_script_fetches .. 11 {
		dynamic_script_response(loader, '${i}.js', 'order.push(${i});', '')
	}
	loader.poll(runtime, mut messages)
	assert runtime.evaluate_host('JSON.stringify(order)')! == '[0,1,2,3,4,5,6,7,8,9,10]'
	assert loader.active_fetches == 0
	assert loader.requests.len == 0
	assert !document.anything_is_delaying_the_load_event()
}

fn test_parser_current_script_is_the_actual_inline_or_external_classic_element() {
	mut document := html.parse_document_with_url(r'<!doctype html><script id="inline">
globalThis.checks=[document.currentScript===document.getElementById("inline")];
document.addEventListener("DOMContentLoaded",()=>checks.push(document.currentScript===null));
</script><script id="external" defer src="bundle.js"></script>', dom.URL{ value: 'https://dynamic-script.example/' })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {
		'https://dynamic-script.example/bundle.js': PreloadedResource{ body: 'checks.push(document.currentScript===document.getElementById("external"));' }
	}, mut messages)
	run_document_script_sources(document, document.url.serialize(), sources, runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('checks.length===3&&checks.every(Boolean)&&document.currentScript===null')! == 'true'
}
