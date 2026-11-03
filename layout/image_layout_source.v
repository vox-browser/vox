module layout

import dom
import html
import os

const retain_image_attribute_source_parse = os.getenv('VOX_RETAIN_IMAGE_ATTRIBUTE_SOURCE_PARSE') != ''
const image_layout_source_diagnostics = os.getenv('VOX_IMAGE_LAYOUT_SOURCE_DIAGNOSTICS') != ''

__global image_layout_source_reported_document dom.UniqueNodeID

// A decoded request already owns the selected URL. Parsing srcset first only
// computes a fallback which the constructor and relayout immediately replace.
// Read the live request each time; pending/failed requests keep attribute-based
// selection and a replacement request is observed without a retained cache.
fn image_source_for_layout(element &dom.Element) string {
	fallback := if retain_image_attribute_source_parse { image_source_selected_from_attributes(element) } else { '' }
	if element.as_node().is_html_image_element() {
		image := unsafe { &dom.HTMLImageElement(element) }
		if html.html_image_element_is_image_available(image) {
			source := html.html_image_element_current_src(image)
			if source != '' {
				if !retain_image_attribute_source_parse && image_layout_source_diagnostics {
					document := element.document()
					identity := document.as_node().unique_id()
					if image_layout_source_reported_document != identity {
						image_layout_source_reported_document = identity
						eprintln('Vox image source: used live available request before attribute parsing; document=${document.url.serialize()}')
					}
				}
				return source
			}
		}
	} else if element.is_html_element() && element.local_name() == 'object' {
		model := html.html_object_element_model_for_dom_element(unsafe { &dom.HTMLObjectElement(element) })
		if model.is_image_available() { return model.data() }
	}
	return if retain_image_attribute_source_parse { fallback } else { image_source_selected_from_attributes(element) }
}
