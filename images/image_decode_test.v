module main

import browserjs
import dom
import html

fn test_compact_image_decode_uses_real_created_element_request_and_asynchronous_owner_settlement() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 globalThis.nativeImage=new Image();nativeImage.src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
 globalThis.decodeResult="pending";globalThis.decodePromise=nativeImage.decode();decodePromise.then(value=>{decodeResult=value===undefined?"decoded":"wrong";target.classList.add("decoded")});
 '], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('decodePromise instanceof Promise&&nativeImage instanceof HTMLImageElement&&decodeResult==="pending"')! == 'true'
	mut native := &dom.Element(unsafe { nil })
	for _, element in runtime.canvas_elements_for_binding() {
		if element.local_name() == 'img' { native = element }
	}
	assert native != unsafe { nil }
	assert voidptr(native.document()) == voidptr(document)
	image := unsafe { &dom.HTMLImageElement(native) }
	assert html.html_image_element_is_image_available(image)
	assert html.html_image_element_natural_width(image) == 1
	mut loop := html.main_thread_event_loop()
	for loop.task_queue().has_runnable_tasks() { loop.process() }
	mut app := BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true }
	app.poll_javascript_tasks()
	assert runtime.evaluate_host('decodeResult==="decoded"')! == 'true'
	assert document.get_element_by_id('target')?.get_attribute_value('class') == 'decoded'
}

fn test_compact_image_decode_rejects_invalid_resource_with_actual_encoding_error() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><img id="target">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 globalThis.failure=null;target.src="data:image/png,invalid";target.decode().catch(value=>failure=value);
 '], runtime, mut messages)
	assert messages == []
	mut loop := html.main_thread_event_loop()
	for loop.task_queue().has_runnable_tasks() { loop.process() }
	assert runtime.evaluate_host('failure instanceof DOMException&&failure.name==="EncodingError"&&failure.message==="Current request state is broken"')! == 'true'
}
