module main

import browserjs
import dom
import html

fn test_native_window_open_uses_the_source_document_navigation_policy() {
	mut document := parse_browser_navigation_document('<!doctype html><meta http-equiv="Content-Security-Policy" content="script-src \'nonce-abc\'"><body>',dom.URL{value:'https://popup-policy.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_script_sources(document,document.url.serialize(),[browserjs.ScriptSource{url:document.url.serialize(),code:r'globalThis.violations=[];document.addEventListener("securitypolicyviolation",e=>violations.push(e));globalThis.popup=open("javascript:throw new Error(1)","policy-popup");console.log(typeof open,popup!==null);'}],runtime,mut messages)
	assert messages == ['function true'],messages.join('\n')
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	for _ in 0..10 { loop.process() }
	assert runtime.evaluate_host('violations.length===1&&violations[0].blockedURI==="inline"&&violations[0].effectiveDirective==="script-src-elem"')! == 'true',runtime.evaluate_host('JSON.stringify(violations.map(e=>[e.blockedURI,e.effectiveDirective]))')!
}
