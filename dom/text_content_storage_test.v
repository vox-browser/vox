module dom

import platform

fn test_only_text_child_reuses_immutable_data_and_survives_replacement() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut script := document.create_element('script')!
	mut script_node := script.as_node()
	mut text := document.create_text_node('const message = "é中😀";'.repeat(1024))
	script_node.append_child(text.as_node())!
	original := text.data()
	content := script_node.child_text_content()
	assert content == original
	assert voidptr(content.str) == voidptr(original.str)
	text.set_data('replacement')
	assert content == original
	assert script_node.child_text_content() == 'replacement'
	script_node.append_child(document.create_text_node(' tail').as_node())!
	assert script_node.child_text_content() == 'replacement tail'
}

fn test_only_cdata_child_shares_data_but_non_text_children_are_ignored() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.xml)
	mut fragment := document.create_document_fragment()
	cdata := document.create_cdata_section('é中😀')!
	fragment.append_child(cdata.as_node())!
	content := fragment.child_text_content()
	assert content == cdata.data()
	assert voidptr(content.str) == voidptr(cdata.data().str)
	assert cdata.as_node().child_text_content() == ''
	mut parent := document.create_element('root')!
	mut parent_node := parent.as_node()
	parent_node.append_child(document.create_comment('ignored').as_node())!
	assert parent_node.child_text_content() == ''
}

fn test_text_content_collectors_preserve_tree_order_unicode_and_shadow_boundaries() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut root := document.create_element('div')!
	mut root_node := root.as_node()
	mut child := document.create_element('span')!
	mut child_node := child.as_node()
	root_node.append_child(document.create_text_node('first\x00中').as_node())!
	root_node.append_child(document.create_comment('ignored').as_node())!
	child_node.append_child(document.create_text_node('😀nested').as_node())!
	root_node.append_child(child.as_node())!
	root_node.append_child(document.create_text_node('tail').as_node())!
	mut shadow := child.attach_shadow(ShadowRootInit{mode:.open})!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(document.create_text_node('shadow only').as_node())!
	assert root.as_node().child_text_content() == 'first\x00中tail'
	assert root.as_node().descendant_text_content() == 'first\x00中😀nestedtail'
	assert root.as_node().text_content()? == 'first\x00中😀nestedtail'
	assert shadow.as_node().descendant_text_content() == 'shadow only'
	assert root.as_node().children[0].descendant_text_content() == ''
	assert root.as_node().children[1].child_text_content() == ''
}

fn test_descendant_text_content_keeps_cdata_and_omits_processing_instructions() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.xml)
	mut fragment := document.create_document_fragment()
	fragment.append_child(document.create_text_node('text').as_node())!
	cdata := document.create_cdata_section('中😀')!
	fragment.append_child(cdata.as_node())!
	instruction := document.create_processing_instruction('target', 'ignored')!
	fragment.append_child(instruction.as_node())!
	assert fragment.as_node().child_text_content() == 'text中😀'
	assert fragment.as_node().descendant_text_content() == 'text中😀'
}

fn test_collected_text_owns_one_exact_payload_after_source_changes() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('div')!
	mut root_node := root.as_node()
	piece := 'é中😀'.repeat(64)
	for _ in 0 .. 64 { root_node.append_child(document.create_text_node(piece).as_node())! }
	expected := piece.repeat(64)
	for recursive in [false, true] {
		before := platform.thread_arena_usage().used
		text := if recursive { root.as_node().descendant_text_content() } else { root.as_node().child_text_content() }
		$if prealloc { assert platform.thread_arena_usage().used - before < expected.len + 4096 }
		assert text == expected
		assert unsafe { text.str[text.len] } == 0
		mut first := root.as_node().children[0].character_data()?
		first.set_data('changed')
		assert text == expected
		first.set_data(piece)
	}
}
