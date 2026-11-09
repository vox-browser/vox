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

fn test_check_name_preserves_xml_rules_and_locates_prefix() {
	for name, colon in {
		'root':      -1
		'_node-1.2': -1
		'p:node':    1
		'xml:lang':  3
		'文:名':     3
	} {
		assert check_name_colon(name)! == colon
		check_name(name)!
	}
	for name in ['', ':root', 'root:', 'a:b:c', '1root', 'a?', 'a=b', 'a b', 'xmlns:p:q'] {
		if _ := check_name_colon(name) {
			assert false, name
		}
	}
}

fn parsed_test_root(source string) !vxml.XMLNode {
	document := parse(source, resolve_test_entity)!
	for child in document.children {
		if child is vxml.XMLNode {
			return resolved_test_node(document, child)!
		}
	}
	return error('missing root')
}

// Exercise the public payload-resolution boundary used by the DOM adapter.
// Processing instructions and doctypes keep their marker because vlib's tree
// has no matching node variant; callers inspect them through special_node.
fn resolved_test_node(document Document, node vxml.XMLNode) !vxml.XMLNode {
	mut attributes := map[string]string{}
	for name, value in node.attributes { attributes[name] = document.attribute_value(value)! }
	mut children := []vxml.XMLNodeContents{cap: node.children.len}
	for child in node.children {
		match child {
			vxml.XMLNode { children << resolved_test_node(document, child)! }
			vxml.XMLComment {
				if special := document.special_node(child) {
					if special.is_text {
						children << special.data
					} else if special.is_cdata {
						children << vxml.XMLCData{ text: special.data }
					} else if special.is_comment {
						children << vxml.XMLComment{ text: special.data }
					} else {
						children << child
					}
				} else {
					children << child
				}
			}
			else { children << child }
		}
	}
	return vxml.XMLNode{ name: node.name, attributes: attributes, children: children }
}

fn parsed_test_special(document Document, child vxml.XMLNodeContents) SpecialNode {
	comment := child as vxml.XMLComment
	return document.special_node(comment) or { panic('missing special node') }
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

struct TestEntityCalls {
mut:
	counts map[string]int
}

fn test_parse_caches_html_entities_across_declaration_attributes_and_text() {
	mut calls := &TestEntityCalls{}
	resolver := fn [mut calls] (name string) ?string {
		calls.counts[name]++
		return match name {
			'period' { '.' }
			'Literal' { '&amp; <文>' }
			else { resolve_test_entity(name) }
		}
	}
	source := '<?xml version="&#X31;&period;0"?><root a="&AElig; &NotEqualTilde; &Literal;">&AElig;|&NotEqualTilde;|&Literal;|&period;|&#X1F600;|&amp;#X41;<item a="&AElig;"/></root>'
	for iteration in 0 .. 2 {
		document := parse(source, resolver)!
		root := resolved_test_node(document, document.children[0] as vxml.XMLNode)!
		assert root.attributes['a'] == 'Æ ≂̸ &amp; <文>'
		assert (root.children[0] as string) == 'Æ|≂̸|&amp; <文>|.|😀|&#X41;'
		assert (root.children[1] as vxml.XMLNode).attributes['a'] == 'Æ'
		assert calls.counts.len == 4
		for name in ['period', 'Literal', 'AElig', 'NotEqualTilde'] {
			// A fresh parse gets its own cache; repeated names within it are
			// resolved only once, including names first used by the prolog.
			assert calls.counts[name] == iteration + 1, name
		}
	}
}

fn test_reference_defaults_and_uppercase_hex_keep_the_html_cache_empty() {
	mut references := XMLReferenceContext{ resolve_entity: resolve_test_entity }
	plain := 'plain 文 payload'
	assert decode_references(plain, mut references)!.str == plain.str
	assert decode_references('&amp;amp; &#X41; &#x1F600; &lt;', mut references)! == '&amp; A 😀 <'
	assert references.entities.len == 0
	assert expand_html_references('&amp;amp; &#X41;', mut references)! == '&amp;amp; &#x41;'
	assert references.entities.len == 0
}

fn test_parse_validates_custom_entity_replacement_characters_with_vlib() {
	for replacement in ['\x00', '\ufffe'] {
		resolver := fn [replacement] (name string) ?string {
			return if name == 'Invalid' { replacement } else { none }
		}
		if _ := parse('<root>&Invalid;</root>', resolver) {
			assert false, 'invalid replacement must not bypass character validation'
		}
	}
}

fn test_parse_preserves_comments_cdata_and_processing_instruction_order() {
	document := parse('<?before document?><root>A<!--&amp;--><![CDATA[ <raw>&amp; ]]><?inside &amp;?>B</root><?after document?>',
		resolve_test_entity)!
	assert document.children.len == 3
	before := parsed_test_special(document, document.children[0])
	assert before.target == 'before'
	assert before.data == 'document'
	root := resolved_test_node(document, document.children[1] as vxml.XMLNode)!
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
		'<root>&AElig;&unknown;</root>',
		'<root>&#0;</root>',
		'<root>&#xD800;</root>',
		'<root>&#X110000;</root>',
		'<root>&#X;</root>',
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
	document := parse('<!--!not-an-index--><vox-xml-document><!--!0--><?inside data?><item/></vox-xml-document>',
		resolve_test_entity)!
	assert document.children.len == 2
	before := parsed_test_special(document, document.children[0])
	assert before.is_comment
	assert before.data == '!not-an-index'
	root := document.children[1] as vxml.XMLNode
	assert root.name == 'vox-xml-document'
	assert root.children.len == 3
	comment := parsed_test_special(document, root.children[0])
	assert comment.is_comment
	assert comment.data == '!0'
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

fn test_parse_resolves_literal_attribute_markers_only_once() {
	root := parsed_test_root('<root literal="@0" numeric="&#64;0" escaped="&amp;#64;0"><!--!0-->!0<![CDATA[!0]]></root>')!
	assert root.attributes['literal'] == '@0'
	assert root.attributes['numeric'] == '@0'
	assert root.attributes['escaped'] == '&#64;0'
	assert root.children.len == 3
	assert (root.children[0] as vxml.XMLComment).text == '!0'
	assert (root.children[1] as string) == '!0'
	assert (root.children[2] as vxml.XMLCData).text == '!0'
}

fn test_parse_preserves_large_attribute_text_comment_and_cdata_payloads() {
	path := 'M 0 0 L 1 1 '.repeat(6000)
	text := ' leading\tpayload &amp; 文\n'.repeat(4000)
	comment := ' comment &amp; payload '.repeat(4000)
	cdata := ' <raw>&amp; ] '.repeat(6000)
	root := parsed_test_root('<root path="${path}">${text}<!--${comment}--><![CDATA[${cdata}]]></root>')!
	assert root.attributes['path'] == path
	assert root.children.len == 3
	assert (root.children[0] as string) == text.replace('&amp;', '&')
	assert (root.children[1] as vxml.XMLComment).text == comment
	assert (root.children[2] as vxml.XMLCData).text == cdata
}

fn test_normalized_source_stays_bounded_for_large_spaced_payloads() {
	path := 'M 0 0 L 1 1 '.repeat(6000)
	text := ' a b c d '.repeat(8192)
	assert path.len >= 65536
	assert text.len >= 65536
	prepared := xml_prepare_source('<root path="${path}">${text}</root>', resolve_test_entity)!
	// Each payload is represented once outside vlib's lexical stream. This
	// bounds the allocation regression from encoding every whitespace byte.
	assert prepared.source.len <= 1024
	assert prepared.attribute_values.len == 1
	assert prepared.attribute_values[0] == path
	assert prepared.special_nodes.len == 1
	assert prepared.special_nodes[0].is_text
	assert prepared.special_nodes[0].data == text
}
