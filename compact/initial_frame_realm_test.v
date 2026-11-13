module main

import browserjs
import dom
import page
import time

fn test_initial_content_window_exposes_one_actual_realm_and_its_native_functions() {
	$if !darwin {
		return
	}
	owner := page.Page.create(1)!
	address := dom.URL{ value: 'https://initial-window.test/' }
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><body><iframe id="frame"></iframe>', address, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		if mut host := browser_child_document_hosts_[voidptr(document)] { host.close() }
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
 const frame=document.getElementById("frame"),first=frame.contentWindow;
 const childFunction=first.Function,childEval=childFunction("return eval")();
 globalThis.initialRealmChecks=[first===frame.contentWindow,first===first.window,
  first===first.document.defaultView,first===childFunction("return this")(),
  first.eval===childEval,first.eval("1+1")===2,
  String(first.eval)===String(childEval)];
 '], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
	assert runtime.evaluate_host('initialRealmChecks.every(Boolean)')! == 'true'
}
