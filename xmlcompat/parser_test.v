module xmlcompat

import encoding.xml as vxml

fn resolve_test_entity(name string) ?string {
	return match name {
		'AElig' { 'Æ' }
		'NotEqualTilde' { '≂̸' }
		'nbsp' { '\u00a0' }
		else { none }
	}
}

fn parsed_test_root(source string) !vxml.XMLNode {
	document := parse(source, resolve_test_entity)!
	for child in document.children {
		if child is vxml.XMLNode {
			return child
		}
	}
	return error('missing root')
}

fn parsed_test_special(document Document, child vxml.XMLNodeContents) SpecialNode {
	comment := child as vxml.XMLComment
	assert comment.text.starts_with(document.marker)
	index := comment.text[document.marker.len..].int()
	assert index >= 0 && index < document.special_nodes.len
	return document.special_nodes[index]
}

fn test_parse_preserves_mixed_content_and_whitespace_only_nodes() {
	root := parsed_test_root('<root> before <item/> between <blank> \t\r\n </blank> after </root>')!
	assert root.children.len == 5
	assert (root.children[0] as string) == ' before '
	assert (root.children[1] as vxml.XMLNode).name == 'item'
	assert (root.children[2] as string) == ' between '
	blank := root.children[3] as vxml.XMLNode
	assert blank.children.len == 1
	assert (blank.children[0] as string) == ' \t\r\n '
	assert (root.children[4] as string) == ' after '
}

fn test_parse_accepts_quoted_delimiters_and_xml_spacing() {
	root := parsed_test_root('<root left = "a > b" right\t=\n"c &gt; d" quote="&quot;&apos;"><item></item \t></root >')!
	assert root.attributes['left'] == 'a > b'
	assert root.attributes['right'] == 'c > d'
	assert root.attributes['quote'] == '"\''
	assert (root.children[0] as vxml.XMLNode).name == 'item'
}

fn test_parse_decodes_unicode_and_entities_once() {
	root := parsed_test_root('<root value="&amp;amp; &AElig; &NotEqualTilde;">Привет 文 😀 &amp;amp; &AElig; &NotEqualTilde; &#65; &#x1F600; &nbsp;</root>')!
	assert root.attributes['value'] == '&amp; Æ ≂̸'
	assert (root.children[0] as string) == 'Привет 文 😀 &amp; Æ ≂̸ A 😀 \u00a0'
}

fn test_parse_preserves_comments_cdata_and_processing_instruction_order() {
	document := parse('<?before document?><root>A<!--&amp;--><![CDATA[ <raw>&amp; ]]><?inside &amp;?>B</root><?after document?>',
		resolve_test_entity)!
	assert document.children.len == 3
	before := parsed_test_special(document, document.children[0])
	assert before.target == 'before'
	assert before.data == 'document'
	root := document.children[1] as vxml.XMLNode
	assert root.children.len == 5
	assert (root.children[0] as string) == 'A'
	assert (root.children[1] as vxml.XMLComment).text == '&amp;'
	assert (root.children[2] as vxml.XMLCData).text == ' <raw>&amp; '
	inside := parsed_test_special(document, root.children[3])
	assert inside.target == 'inside'
	assert inside.data == '&amp;'
	assert (root.children[4] as string) == 'B'
	after := parsed_test_special(document, document.children[2])
	assert after.target == 'after'
	assert after.data == 'document'
}

fn test_parse_preserves_doctype_identifiers_without_loading_dtd_entities() {
	document := parse('<?xml version="1.0"?><!--before--><!DOCTYPE root PUBLIC "-//TEST//DTD Root//EN" "root.dtd" [<!ENTITY ignored "value">]><root/><!--after-->',
		resolve_test_entity)!
	assert document.children.len == 4
	assert (document.children[0] as vxml.XMLComment).text == 'before'
	doctype := parsed_test_special(document, document.children[1]).doctype?
	assert doctype.name == 'root'
	assert doctype.external_id == 'PUBLIC "-//TEST//DTD Root//EN" "root.dtd"'
	assert (document.children[2] as vxml.XMLNode).name == 'root'
	assert (document.children[3] as vxml.XMLComment).text == 'after'
	if _ := parse('<!DOCTYPE root [<!ENTITY ignored "value">]><root>&ignored;</root>',
		resolve_test_entity) {
		assert false, 'DTD entity declarations must remain inert'
	}
}

fn test_parse_rejects_malformed_documents_and_trailing_input() {
	for source in [
		'',
		'<root/><second/>',
		'leading<root/>',
		'<root/>trailing',
		'<root><child></root>',
		'<root a="1" a="2"/>',
		'<root>&unknown;</root>',
		'<root>&#0;</root>',
		'<root>&#xD800;</root>',
		'<root value="a < b"/>',
		'<root/><?xml version="1.0"?>',
		'<root><!--a--b--></root>',
		'<![CDATA[outside]]><root/>',
		'< root/>',
		'<root/ >',
		'</vox-xml-document><root/>',
		'<vox-xml-document><root/>',
	] {
		if _ := parse(source, resolve_test_entity) {
			assert false, source
		}
	}
}

fn test_parse_keeps_marker_like_comments_and_wrapper_named_elements() {
	document := parse('<!--vox-xml-special:not-an-index--><vox-xml-document><!--vox-xml-special:0--><?inside data?><item/></vox-xml-document>',
		resolve_test_entity)!
	assert document.children.len == 2
	before := parsed_test_special(document, document.children[0])
	assert before.is_comment
	assert before.data == 'vox-xml-special:not-an-index'
	root := document.children[1] as vxml.XMLNode
	assert root.name == 'vox-xml-document'
	assert root.children.len == 3
	comment := parsed_test_special(document, root.children[0])
	assert comment.is_comment
	assert comment.data == 'vox-xml-special:0'
	instruction := parsed_test_special(document, root.children[1])
	assert !instruction.is_comment
	assert instruction.target == 'inside'
	assert instruction.data == 'data'
	assert (root.children[2] as vxml.XMLNode).name == 'item'
}

fn test_parse_many_small_elements_without_losing_text_or_attributes() {
	root := parsed_test_root('<root>' + '<item value="&amp;amp;"> x </item>'.repeat(1000) +
		'</root>')!
	assert root.children.len == 1000
	for child in root.children {
		item := child as vxml.XMLNode
		assert item.name == 'item'
		assert item.attributes['value'] == '&amp;'
		assert item.children.len == 1
		assert (item.children[0] as string) == ' x '
	}
}
