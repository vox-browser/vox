module main

import browserjs
import css
import dom
import html

// A blocking script can suspend the parser before the shell's first resource
// scan. Attach clients to newly parsed owners before scripts and readiness,
// including when a failed script never created a JavaScript runtime.
fn install_parser_document_resources(document &dom.Document, images &BrowserImageRequestLoader,
	media_loader ?browserjs.MediaElementCreatedHook) {
	if document.has_been_destroyed() || images.cancelled
		|| voidptr(images.document) != voidptr(document) { return }
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	install_browser_input_image_fetch_hooks(document)
	for element in css.query_selector_all(document.as_node(), 'img') {
		if !element.is_html_element() { continue }
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		// Preserve existing ImageHost hooks and requests from earlier stages.
		if model.has_fetch_hook() { continue }
		model.set_model_async_fetch_hook(images.static_callback())
		if element.has_attribute('src') || element.has_attribute('srcset') {
			model.update_the_image_data(false, false)
		}
	}
	install_object_image_fetch_hooks(document)
	install_video_poster_fetch_hooks(document)
	if callback := media_loader {
		for element in css.query_selector_all(document.as_node(), 'audio,video') {
			if element.is_html_element() { callback(element) }
		}
	}
}
