module main

import browserjs
import dom
import html
import platform
import time

fn test_fragment_event_attributes_check_the_context_policy_and_retarget_after_shadow_insertion() {
	mut document := parse_browser_navigation_document('<!doctype html><meta http-equiv="Content-Security-Policy" content="script-src \'nonce-abc\'"><body><div id="host"></div>',dom.URL{value:'https://shadow-csp.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_script_sources(document,document.url.serialize(),[browserjs.ScriptSource{url:document.url.serialize(),code:r'globalThis.violations=[];document.addEventListener("securitypolicyviolation",e=>violations.push(e.target===host));const shadow=host.attachShadow({mode:"closed"});shadow.innerHTML="<a onclick=void(0)>link</a>";const link=shadow.firstChild;link.addEventListener("securitypolicyviolation",e=>violations.push(e.target===link));link.click();'}],runtime,mut messages)
	assert messages == []string{},messages.join('\n')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	deadline := time.now().add(time.second)
	for time.now()<deadline && runtime.evaluate_host('violations.length')! != '2' { loop.process();platform.pump_native_events(0.005) }
	assert runtime.evaluate_host('violations.length===2&&violations.every(Boolean)')! == 'true',runtime.evaluate_host('JSON.stringify(violations)')!
}
