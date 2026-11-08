module main

import browserjs
import dom
import page
import time

fn test_native_load_listeners_and_their_promise_jobs_observe_complete_readiness_once() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><p>readiness</p>', dom.URL{value: 'https://readiness.test/'}, none,
		none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') })!
	assert document.ready_state() == 'interactive'
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.readinessEvents=[];
document.addEventListener("DOMContentLoaded",()=>readinessEvents.push("DOMContentLoaded:"+document.readyState));
document.addEventListener("readystatechange",()=>readinessEvents.push("readystatechange:"+document.readyState));
addEventListener("load",()=>{readinessEvents.push("load:"+document.readyState);Promise.resolve().then(()=>readinessEvents.push("promise:"+document.readyState));});
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('readinessEvents.join(",")')! == 'DOMContentLoaded:interactive,readystatechange:complete,load:complete,promise:complete'
	runtime.dispatch_document_readiness_event('load')!
	runtime.dispatch_document_readiness_event('DOMContentLoaded')!
	assert runtime.evaluate_host('readinessEvents.length')! == '4'
	assert document.ready_state() == 'complete'
}
