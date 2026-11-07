module main

import dom
import html

fn test_static_browser_images_decode_without_a_javascript_runtime() {
	markup := '<!doctype html><img id="picture" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=">'
	mut document := parse_loaded_browser_navigation_document(LoadedPage{url: 'about:blank', markup: markup}, dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	assert html.html_image_element_is_image_available(image)
	assert html.html_image_element_natural_width(image) == 1
	assert html.html_image_element_natural_height(image) == 1
	assert !document.is_scripting_enabled_by_embedder()
	// Installing again reuses the completed request instead of dispatching a
	// duplicate load event or replacing its decoded pixels.
	model := html.html_image_element_model_for_dom_element(image)
	before := model.current_request()
	events := model.event_count('load')
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	assert model.current_request() == before
	assert model.event_count('load') == events
}

fn test_static_browser_image_errors_keep_the_alt_text_representation() {
	mut document := parse_loaded_browser_navigation_document(LoadedPage{url: 'about:blank', markup: '<!doctype html><img id="picture" src="data:image/png,invalid" alt="unavailable">'}, dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	install_static_browser_image_fetch_hooks(document, map[string]bool{})
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	assert !html.html_image_element_is_image_available(image)
	assert html.html_image_element_natural_width(image) == 0
	assert html.html_image_element_model_for_dom_element(image).event_count('error') == 1
}

fn test_static_browser_image_preloads_keep_hidden_requests_deferred_until_completion() {
	address := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
	mut document := parse_loaded_browser_navigation_document(LoadedPage{url: 'about:blank', markup: '<!doctype html><img id="picture" style="display:none" src="${address}">'}, dom.url_about_blank(), none, none, none, false)
	defer { document.finalize() }
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	install_static_browser_image_fetch_hooks(document, {address: true})
	assert !html.html_image_element_is_image_available(image)
	complete_static_browser_image_requests(document, {address: true})
	assert html.html_image_element_is_image_available(image)
	assert html.html_image_element_natural_width(image) == 1
}
