module layout

import css
import dom

fn image_observer_node() (&NodeWithStyle, &dom.Paintable) {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut owner := NodeWithStyle.new(document, element.as_node(), css.ComputedProperties.new())
	mut dom_node := element.as_node()
	paintable := &dom.Paintable{layout_handle: voidptr(owner)}
	dom_node.set_layout_node(&dom.LayoutNode{
		layout_handle: voidptr(owner)
		dom_node_: dom_node
		paintables_: [paintable]
	})
	return owner, paintable
}

fn test_image_observers_cover_background_mask_cursor_border_and_list_sources_in_source_order() {
	mut owner, mut paintable := image_observer_node()
	mut properties := css.ComputedProperties.new()
	properties.set_property_without_modifying_flags(.background_image, &dom.StyleValue{css_text: 'url("background.png")'})
	properties.set_property_without_modifying_flags(.mask_image, &dom.StyleValue{css_text: 'url("mask.png")'})
	properties.set_property_without_modifying_flags(.cursor, &dom.StyleValue{css_text: 'url("cursor.png") 1 2, url("cursor2.png"), pointer'})
	properties.set_property_without_modifying_flags(.border_image_source, &dom.StyleValue{css_text: 'url("border.png")'})
	properties.set_property_without_modifying_flags(.list_style_image, &dom.StyleValue{css_text: 'url("list.png")'})
	owner.apply_style(properties)
	assert owner.image_observers_.len == 6
	mut urls := []string{}
	for observer in owner.image_observers_ {
		urls << observer.image.url_.url()
		paintable.needs_repaint = false
		observer.image.notify_clients()
		assert paintable.needs_repaint
	}
	assert urls[0].ends_with('background.png')
	assert urls[1].ends_with('mask.png')
	assert urls[2].ends_with('cursor.png')
	assert urls[3].ends_with('cursor2.png')
	assert urls[4].ends_with('border.png')
	assert urls[5].ends_with('list.png')
}

fn test_replacing_observer_slots_preserves_shared_image_registration_and_releases_old_identity() {
	mut owner, mut paintable := image_observer_node()
	mut properties := css.ComputedProperties.new()
	typed_image := css.parse_css_type(css.ParsingParams{document: owner.document()}, 'url("https://example.test/shared.png")', .image) or { panic('missing typed image') }
	properties.set_property_without_modifying_flags(.background_image, typed_image)
	owner.apply_style(properties)
	old := owner.image_observers_[0]
	image := old.image
	owner.rebuild_image_observers()
	replacement := owner.image_observers_[0]
	assert voidptr(old) != voidptr(replacement)
	// Releasing the old slot again cannot remove its successor's client.
	image.unregister_client(voidptr(old))
	paintable.needs_repaint = false
	image.notify_clients()
	assert paintable.needs_repaint
	owner.clear_image_observers()
	paintable.needs_repaint = false
	image.notify_clients()
	assert !paintable.needs_repaint
	assert owner.image_observers_.len == 0
}

fn test_removed_cursor_and_border_images_stop_notifying_and_layout_detach_releases_clients() {
	mut owner, mut paintable := image_observer_node()
	mut properties := css.ComputedProperties.new()
	properties.set_property_without_modifying_flags(.cursor, &dom.StyleValue{css_text: 'url("cursor.png"), auto'})
	properties.set_property_without_modifying_flags(.border_image_source, &dom.StyleValue{css_text: 'url("border.png")'})
	owner.apply_style(properties)
	old_cursor := owner.image_observers_[0].image
	old_border := owner.image_observers_[1].image
	owner.apply_style(css.ComputedProperties.new())
	paintable.needs_repaint = false
	old_cursor.notify_clients()
	old_border.notify_clients()
	assert !paintable.needs_repaint
	owner.apply_style(properties)
	assert owner.image_observers_.len == 2
	live_cursor := owner.image_observers_[0].image
	live_border := owner.image_observers_[1].image
	_ = attach_layout_nodes(unsafe { &Node(owner) })
	mut dom_node := owner.dom_node() or { panic('missing DOM owner') }
	dom_node.detach_layout_node()
	assert owner.image_observers_.len == 0
	paintable.needs_repaint = false
	live_cursor.notify_clients()
	live_border.notify_clients()
	assert !paintable.needs_repaint
}
