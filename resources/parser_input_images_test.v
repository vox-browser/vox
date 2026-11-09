module main

import adblock
import dom
import encoding.base64
import html
import layout

fn parser_input_image_host() &BrowserParserScriptHost {
	address := dom.URL{value: 'https://parser-input-image.example/page'}
	document := create_browser_navigation_document_input_with_source('UTF-8', address,
		none, none, none, 1_000_000, true, none)
	mut owner := unsafe { &dom.Document(document) }
	owner.set_viewport_rect(dom.Rect{width: 800, height: 600})
	images := new_browser_image_request_loader(document, {})
	mut scripts := new_browser_script_request_loader(document, {})
	scripts.fetch = fn (_ string, _ string, _ chan PreloadedResource) {}
	return install_browser_parser_script_host(document, .javascriptcore, images, scripts, {}, none, none)
}

fn close_parser_input_image_host(host &BrowserParserScriptHost) {
	mut scripts := host.scripts
	scripts.cancel()
	mut images := host.images
	images.cancel()
	if host.runtime != unsafe { nil } { host.runtime.close() }
	mut document := unsafe { &dom.Document(host.document) }
	document.finalize()
}

fn parser_input_image_source() string {
	return 'data:image/svg+xml;base64,' + base64.encode('<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="100" height="100" fill="green"/></svg>'.bytes())
}

fn test_parser_suffix_image_input_is_ready_for_later_scripts_and_load() {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	mut host := parser_input_image_host()
	defer { close_parser_input_image_host(host) }
	source := parser_input_image_source()
	parse_prepared_browser_navigation_document(PreparedBrowserNavigationDocument{
		document: host.document
		markup: '<!doctype html><script>globalThis.earlyImageAbsent=document.querySelector("input")===null;</script><form><input id=image type=image src="${source}"></form><script>globalThis.imageSizeAtScript=[document.querySelector("input").width,document.querySelector("input").height];window.addEventListener("load",()=>{globalThis.imageSizeAtLoad=[document.querySelector("input").width,document.querySelector("input").height];});</script>'
	})
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 128 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	element := host.document.get_element_by_id('image') or { panic('missing image input') }
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	assert model.is_image_available()
	assert host.runtime.evaluate_host('earlyImageAbsent')! == 'true'
	assert host.runtime.evaluate_host('imageSizeAtScript.join(",")')! == '200,200'
	assert host.runtime.evaluate_host('imageSizeAtLoad.join(",")')! == '200,200'
	assert host.document.readiness() == .complete
	assert !host.document.anything_is_delaying_the_load_event()
	assert host.runtime.evaluate_host(r'(()=>{
const form=document.querySelector("form"),input=form.querySelector("input");
form.addEventListener("submit",event=>event.preventDefault());
const rect=input.getBoundingClientRect();
input.dispatchEvent(new MouseEvent("click",{clientX:Math.round((rect.left+rect.right)/7),clientY:Math.round((rect.top+rect.bottom)/4)}));
const data=new FormData(form,input);return data.get("x")+","+data.get("y");})()')! == '23,46'
}

fn test_failed_parser_script_still_loads_suffix_image_input_without_a_runtime() {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	mut host := parser_input_image_host()
	defer { close_parser_input_image_host(host) }
	source := parser_input_image_source()
	parse_prepared_browser_navigation_document(PreparedBrowserNavigationDocument{
		document: host.document
		markup: '<!doctype html><script src=failed.js></script><input id=suffix type=image src="${source}">'
	})
	assert host.document.get_element_by_id('suffix') == none
	host.scripts.results <- PreloadedResource{
		url: 'https://parser-input-image.example/failed.js'
		source_url: host.document.url.serialize()
		request_type: 'script'
		error: 'failed before runtime creation'
	}
	host.scripts.poll(host.runtime, mut host.messages)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 128 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	assert host.runtime == unsafe { nil }
	element := host.document.get_element_by_id('suffix') or { panic('missing suffix input') }
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	assert model.is_image_available()
	assert model.intrinsic_width()? == 200 && model.intrinsic_height()? == 200
	assert model.event_count('load') == 1
	assert host.document.readiness() == .complete
	assert !host.document.anything_is_delaying_the_load_event()
	_ = layout.run_document_layout(host.document, 800, 600)?
	assert element.get_bounding_client_rect().width == 200
	install_parser_document_resources(host.document, host.images, none)
	assert model.event_count('load') == 1
}
