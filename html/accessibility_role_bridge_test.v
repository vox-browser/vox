module html

import aria
import dom

fn role_bridge_element(document &dom.Document, id string) &dom.Element {
	return document.get_element_by_id(id) or { panic('missing #${id}') }
}

fn attach_accessibility_test_layout(element &dom.Element, rendered_text string) {
	mut element_node := unsafe { &dom.Node(element.as_node()) }
	element_node.set_layout_node(&dom.LayoutNode{})
	mut text_node := unsafe { &dom.Node(element.as_node().first_child() or { panic('missing text') }) }
	text_node.set_layout_node(&dom.LayoutNode{
		is_text_node_: true
		rendered_text_: rendered_text
		display_: dom.CSSDisplay_{
			is_inline_outside_: true
			is_flow_inside_: true
		}
	})
}

fn test_accessible_name_uses_aria_mixin_role_resolution() {
	document := parse_document('<!doctype html><button id="button">Button text</button><div id="tree" role="tree"><span id="item" role="command treeitem">Item text</span></div><span id="orphan" role="treeitem">Orphan text</span>')
	button := role_bridge_element(document, 'button')
	item := role_bridge_element(document, 'item')
	orphan := role_bridge_element(document, 'orphan')
	attach_accessibility_test_layout(button, 'Button text')
	attach_accessibility_test_layout(item, 'Item text')
	attach_accessibility_test_layout(orphan, 'Orphan text')

	assert html_element_role_or_default(button)? == aria.Role.button
	assert html_element_role_or_default(item)? == aria.Role.treeitem
	assert html_element_role_or_default(orphan)? == aria.Role.generic
	assert document.element_allows_accessible_name_from_content(button, false)?
	assert !(document.element_allows_accessible_name_from_content(item, false)?)
	assert document.element_allows_accessible_name_from_content(item, true)?
	assert button.as_node().accessible_name(document, .no)! == 'Button text'
	assert item.as_node().accessible_name(document, .yes)! == 'Item text'
	assert orphan.as_node().accessible_name(document, .no)! == ''
}

fn test_specialized_html_default_roles_feed_the_aria_mixin() {
	document := parse_document('<!doctype html><a id="plain">plain</a><a id="link" href="/">link</a><input id="search" type="search"><select id="many" multiple></select>')
	plain := role_bridge_element(document, 'plain')
	link := role_bridge_element(document, 'link')
	search := role_bridge_element(document, 'search')
	many := role_bridge_element(document, 'many')

	assert html_element_role_or_default(plain)? == aria.Role.generic
	assert html_element_role_or_default(link)? == aria.Role.link
	assert html_element_role_or_default(search)? == aria.Role.searchbox
	assert html_element_role_or_default(many)? == aria.Role.listbox
}

fn test_accessible_name_embedded_control_step_uses_html_control_values() {
	document := parse_document('<!doctype html><label for="target">Amount <input id="target"><input type="text" value="42"></label>')
	target := role_bridge_element(document, 'target')
	assert target.as_node().accessible_name(document, .yes)! == 'Amount 42'
}

fn test_named_svg_groups_resolve_default_roles_through_the_shared_svg_model() {
 document := parse_document('<!doctype html><svg><g id="named" style="display:contents"><title>Group label</title><path/></g><g id="plain"/><g id="labelled" aria-label="Group"/><g id="override" role="img"><title>Override</title></g><a id="link" href="/"/></svg>')
 defer { document.finalize() }
 assert html_element_role_or_default(role_bridge_element(document,'named'))? == .group
 assert html_element_role_or_default(role_bridge_element(document,'plain'))? == .generic
 assert html_element_role_or_default(role_bridge_element(document,'labelled'))? == .group
 assert html_element_role_or_default(role_bridge_element(document,'override'))? == .image
 assert html_element_role_or_default(role_bridge_element(document,'link'))? == .link
}
