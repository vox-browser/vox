module main

import browserjs
import dom

fn test_allowed_inline_media_and_window_handlers_compile_while_author_eval_remains_disabled() {
	mut document := parse_browser_navigation_document('<!doctype html><meta http-equiv="Content-Security-Policy" content="script-src &apos;unsafe-inline&apos;"><body onload="globalThis.windowHandler=true"><audio id="audio" onloadeddata="globalThis.mediaHandler=true"></audio>',dom.URL{value:'https://handler-policy.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[r'
 document.getElementById("audio").dispatchEvent(new Event("loadeddata"));
 window.dispatchEvent(new Event("load"));
 if(globalThis.mediaHandler!==true||globalThis.windowHandler!==true)throw Error("allowed raw handlers did not compile");
 let blocked=false;try{eval("globalThis.evalRan=true")}catch(error){blocked=error instanceof EvalError}
 if(!blocked||globalThis.evalRan)throw Error("host compilation changed author eval policy");
 '],runtime,mut messages)
	assert messages == []string{},messages.str()
}
