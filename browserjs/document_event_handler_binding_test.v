module browserjs

import dom
import html
import json2

fn document_handler_fixture() !(&Runtime, &dom.Document) {
	url := dom.URL{ value: 'https://document-handlers.test/' }
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.evaluate_host('globalThis.document={}')!
	runtime.install_document_window_event_binding(document, runtime.evaluate_host_value('document')!)!
	return runtime, document
}

fn test_document_exposes_global_event_handlers_over_actual_slots() {
	$if !darwin {
		return
	}
	mut runtime, mut document := document_handler_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	for name in document_event_handler_names() {
		assert runtime.evaluate_host('(()=>{const t=typeof Document==="function"?Document.prototype:document;const d=Object.getOwnPropertyDescriptor(t,${json2.encode(name.attribute)});return !!d&&d.enumerable&&d.configurable&&document[${json2.encode(name.attribute)}]===null&&${json2.encode(name.attribute)} in document})()')! == 'true', name.attribute
	}
	// React's input-event feature test.
	assert runtime.evaluate_host('"oninput" in document&&"onreadystatechange" in document&&"onvisibilitychange" in document')! == 'true'
	for name in ['onhashchange', 'onmessage', 'onpopstate', 'onbeforeunload', 'onunload', 'onstorage'] {
		assert runtime.evaluate_host('${json2.encode(name)} in document')! == 'false', name
	}
	runtime.evaluate_host(r'globalThis.calls=[];const handler=function(event){calls.push([this===document,event.type]);return false};document.oninput=handler;globalThis.sameHandler=document.oninput===handler;')!
	assert runtime.evaluate_host('sameHandler')! == 'true'
	event := dom.Event.create('input', dom.EventInit{ cancelable: true })
	unsafe { &dom.EventTarget(document) }.dispatch_event(event)
	assert runtime.evaluate_host('JSON.stringify(calls)')! == '[[true,"input"]]'
	// Returning false from an ordinary event handler cancels the event.
	assert event.default_prevented()
	runtime.evaluate_host('document.oninput=null')!
	unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('input', dom.EventInit{}))
	assert runtime.evaluate_host('calls.length===1&&document.oninput===null')! == 'true'
	assert runtime.evaluate_host('(()=>{try{Object.getOwnPropertyDescriptor(typeof Document==="function"?Document.prototype:document,"oninput").get.call({});return false}catch(error){return error instanceof TypeError}})()')! == 'true'
}
