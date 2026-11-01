module main

import dom
import html

// -1 leaves synthetic/non-HTML image callers on their existing decode path.
// Reading the live element also preserves changes to the decoding attribute
// without attaching a DOM owner graph to retained painting snapshots.
fn chromium_image_decoding_hint(document &dom.Document, image_element_id i64) int {
	if document == unsafe { nil } || image_element_id == 0 { return -1 }
	node := dom.Node.from_unique_id(dom.UniqueNodeID(image_element_id)) or { return -1 }
	if !node.is_html_image_element() || voidptr(node.document()) != voidptr(document) { return -1 }
	element := node.as_element() or { return -1 }
	if element.get_attribute_value('decoding').to_lower() != 'async' { return 0 }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(node) })
	if model.current_request().state() != .completely_available { return 0 }
	if data := model.decoded_image_data() {
		if data.is_animated() { return 0 }
	}
	return 1
}

