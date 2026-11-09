module main

import dom
import html

// Native attribute writes must refresh the image request as well as the DOM.
// Keep srcset on the same selection and invalidation path as src, including
// writes through a retained Attr or a null-namespace attribute setter.
fn compact_image_attribute_changed(element &dom.Element, name string, old_value ?string, value ?string, namespace ?string) {
	if namespace != none || !element.is_html_element() || element.local_name() != 'img'
		|| name !in ['src', 'srcset'] {
		return
	}
	image := unsafe { &dom.HTMLImageElement(element) }
	html.html_image_element_form_associated_element_attribute_changed(image, name, old_value,
		value, none)
	mut node := element.as_node()
	node.set_needs_layout_update(.html_image_element_update_the_image_data)
	node.set_needs_repaint(.paint_commands)
}
