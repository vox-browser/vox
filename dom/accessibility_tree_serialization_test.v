module dom

import strings

fn test_accessibility_serialization_preserves_order_escaping_and_whitespace_filtering() {
	document := Document.create(url_about_blank())
	mut root := AccessibilityTreeNode.create(document, document.as_node())
	text := document.create_text_node('quote "\ntext')
	whitespace := document.create_text_node(' \n\t')
	root.append_child(AccessibilityTreeNode.create(document, text.as_node()))
	root.append_child(AccessibilityTreeNode.create(document, whitespace.as_node()))
	root.append_child(AccessibilityTreeNode.create(document, none))
	mut output := strings.new_builder(256)
	root.serialize_tree_as_json(mut output, document)
	assert output.str() == '{"type":"node","id":${document.as_node().unique_id().value()},"children":[{"type":"text","name":"quote \\"\\ntext","role":"text leaf","id":${text.as_node().unique_id().value()}},{}]}'
}

fn test_accessibility_serialization_handles_deep_trees_without_recursive_calls() {
	document := Document.create(url_about_blank())
	text := document.create_text_node('x')
	root := AccessibilityTreeNode.create(document, text.as_node())
	mut parent := root
	for _ in 0 .. 10_000 {
		child := AccessibilityTreeNode.create(document, text.as_node())
		parent.append_child(child)
		parent = child
	}
	mut output := strings.new_builder(1_000_000)
	root.serialize_tree_as_json(mut output, document)
	serialized := output.str()
	assert serialized.count('"type":"text"') == 10_001
	assert serialized.count('"children":[') == 10_000
	assert serialized.ends_with(']}')
}
