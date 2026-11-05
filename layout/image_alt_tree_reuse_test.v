module layout

import dom
import html

fn test_alt_text_shadow_changes_preserve_clean_siblings_and_publish_current_text() {
	mut document := html.parse_document('<!doctype html><body><img id="image" alt=""><section id="stable">' + '<p>Stable branch <b>content</b></p>'.repeat(16) + '</section>')
	defer { document.finalize() }
	mut element := document.get_element_by_id('image')?
	image := unsafe { &dom.HTMLImageElement(element) }
	_ = html.html_image_element_model_for_dom_element(image)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	for alt in ['First fallback', 'Changed fallback', ''] {
		before := stable.as_node().unsafe_layout_node()?.real_layout_handle()
		old := element.get_attribute('alt')
		element.set_attribute_value('alt', alt)
		html.html_image_element_form_associated_element_attribute_changed(image, 'alt', old, alt, none)
		document.update_layout(.debugging)
		after := stable.as_node().unsafe_layout_node()?.real_layout_handle()
		assert after == before
		list := document.record_display_list() or { panic('missing image fallback paint') }
		commands := display_list_commands(list)
		assert commands.any(it.kind == 'draw_text' && it.text == alt) == (alt != '')
		assert commands.filter(it.kind == 'draw_text' && it.text.contains('Stable branch')).len == 16
		if alt != '' {
			assert element.shadow_root() != none
		} else {
			assert element.shadow_root() == none
		}
		expected := list.dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		full := document.record_display_list() or { panic('missing full paint') }
		assert full.dump() == expected
	}
}
