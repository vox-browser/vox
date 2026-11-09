module main

import browserjs
import dom
import page
import time
import platform

fn test_same_origin_window_proxy_preserves_error_constructor_identity() {
	owner := page.Page.create(1)!
	address := dom.URL{value:'https://window-constructor.test/'}
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><iframe id="frame"></iframe>',address,none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,address.serialize(),[r'
 const win=document.getElementById("frame").contentWindow;
 globalThis.timerDelivered=false;win.deliver=()=>{timerDelivered=true;};
 if(Object.prototype.hasOwnProperty.call(win.setTimeout,"prototype"))throw Error("timer operation is constructable");
 win.setTimeout("deliver()",0);
 const meta=win.document.createElement("meta");meta.httpEquiv="Content-Security-Policy";meta.content="script-src \u0027self\u0027";win.document.head.append(meta);
 let caught=false;
 try{win.eval("1")}catch(error){caught=true;if(error.constructor!==win.EvalError||!(error instanceof win.EvalError))throw Error("child error constructor identity");}
 if(!caught)throw Error("child eval policy");
 '],runtime,mut messages)
	assert messages == []string{},messages.str()
	for _ in 0..20 { platform.pump_native_events(0.005) }
	assert runtime.evaluate_host('timerDelivered')! == 'true'
}
