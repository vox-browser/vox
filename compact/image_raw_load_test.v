module main

import browserjs
import dom

fn test_parsed_image_load_handler_runs_on_its_native_target() {
	mut document := parse_browser_navigation_document('<!doctype html><body><img id="picture" onload="globalThis.imageLoaded=(globalThis.imageLoaded||0)+1">',dom.URL{value:'https://image-load.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[r'globalThis.imageLoaded=0;picture.dispatchEvent(new Event("load"));console.log(imageLoaded);'],runtime,mut messages)
	assert messages == ['1'],messages.join('\n')
}
