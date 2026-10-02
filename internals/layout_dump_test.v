module internals

import dom
import gamepad
import layout

fn test_dump_layout_tree_uses_retained_layout_for_requested_subtree() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.populate_with_html_head_and_body()!
	body := document.body()?
	mut target := document.create_element('div')!
	target.set_attribute_value('id', 'target')
	mut body_node := unsafe { &dom.Node(body) }
	body_node.append_child(target.as_node())!
	mut target_node := target.as_node()
	target_node.append_child(document.create_text_node('content').as_node())!
	layout.run_document_layout(document, 320, 200) or { panic('layout failed') }
	api := Internals.create(&PlatformState{}, gamepad.NavigatorGamepadPartial.new())
	output := api.dump_layout_tree(target_node)
	assert output.starts_with('BlockContainer <div#target>')
	assert output.contains('TextNode <#text>')
	assert !output.contains('Viewport')
	assert !output.contains('host boundary')
}

fn test_dump_layout_tree_absent_node_and_node_without_generated_box() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.populate_with_html_head_and_body()!
	mut hidden := document.create_element('div')!
	hidden.set_attribute_value('style', 'display:none')
	mut body := document.body()?.as_node()
	body.append_child(hidden.as_node())!
	layout.run_document_layout(document, 320, 200) or { panic('layout failed') }
	api := Internals.create(&PlatformState{}, gamepad.NavigatorGamepadPartial.new())
	assert api.dump_layout_tree(none) == '(no layout node)'
	assert api.dump_layout_tree(hidden.as_node()) == '(no layout node)'
}
