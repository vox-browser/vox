module main

import css
import dom
import html

fn browser_input_image_fetch(model &html.HTMLInputElementModel, address dom.URL) !html.DecodedImageData {
	return browser_fetch_image_resource_for_document(address, model.to_html_element().document().url.serialize())
}

// Configure every input before scripts run: a text control can later become an
// image button. The callback resolves the current document after adoption.
fn install_browser_input_image_fetch_hooks(document &dom.Document) {
	for element in css.query_selector_all(document.as_node(), 'input') {
		configure_browser_input_image_fetch(element, true)
	}
}

fn configure_browser_input_image_fetch(element &dom.Element, start bool) {
	if !element.is_html_element() || element.local_name() != 'input' { return }
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	model.set_image_model_fetch_hook(browser_input_image_fetch)
	request_needs_fetching := if request := model.resource_request_ {
		request.needs_fetching()
	} else {
		true
	}
	if start && model.type_state_ == .image_button && request_needs_fetching {
		if source := element.get_attribute('src') {
			model.handle_src_attribute(source) or {}
		}
	}
}
