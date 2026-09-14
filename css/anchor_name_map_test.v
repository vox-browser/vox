module css

import dom

fn recompute_anchor_name_style(style_computer &StyleComputer, element &dom.Element) {
	mut abstract_element := dom.AbstractElement.new(element, none)
	style_computer.recompute_style(mut abstract_element)
}

fn reject_anchor_name_element(target voidptr, element &dom.Element) bool {
	return voidptr(element) != target
}

fn test_anchor_name_map_falls_back_to_an_earlier_matching_element() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	root.append_child(first)
	root.append_child(second)
	mut names := dom.AnchorNameMap{}
	assert !names.has_registered_names()
	names.register_name('--target', first)
	names.register_name('--target', second)
	assert names.has_registered_names()
	assert names.last_element_by_name_matching('--target', dom.AnchorNameMapFilter{
		target: voidptr(second)
		callback: reject_anchor_name_element
	})? == first
}

fn test_anchor_name_registry_tracks_tree_order_restyle_removal_and_shadow_scopes() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.populate_with_html_head_and_body()!
	body := document.body() or { panic('missing body') }
	mut body_node := body.as_node()

	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	first.set_attribute_value('style', 'anchor-name: --target, --shared')
	body_node.append_child(first.as_node())!
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	second.set_attribute_value('style', 'anchor-name: --target')
	body_node.append_child(second.as_node())!
	assert !document.any_anchor_names_are_registered()

	style_computer := StyleComputer.new(document)
	recompute_anchor_name_style(style_computer, first)
	recompute_anchor_name_style(style_computer, second)
	assert document.any_anchor_names_are_registered()
	assert document.element_by_anchor_name('--target', body_node)? == second

	mut second_node := second.as_node()
	second_node.remove(false)
	assert document.element_by_anchor_name('--target', body_node)? == first
	first.set_attribute_value('style', 'anchor-name: --renamed, --shared')
	recompute_anchor_name_style(style_computer, first)
	assert document.element_by_anchor_name('--target', body_node) == none
	assert document.element_by_anchor_name('--renamed', body_node)? == first

	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section')!
	body_node.append_child(host.as_node())!
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut shadow_root_node := unsafe { &dom.Node(shadow_root) }
	mut shadow_anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	shadow_anchor.set_attribute_value('style', 'anchor-name: --shared')
	shadow_root_node.append_child(shadow_anchor.as_node())!
	recompute_anchor_name_style(style_computer, shadow_anchor)
	assert document.element_by_anchor_name('--shared', shadow_anchor.as_node())? == shadow_anchor
	assert document.element_by_anchor_name('--shared', body_node)? == first

	mut shadow_anchor_node := shadow_anchor.as_node()
	shadow_anchor_node.remove(false)
	assert document.element_by_anchor_name('--shared', host.as_node())? == first
}
