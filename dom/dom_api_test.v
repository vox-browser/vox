module dom

// Runtime tests porting concrete, non-JS-dependent DOM behaviors from upstream's JavaScript Text
// tests (Tests/LibWeb/Text/input/DOM/*) into V assertions. These complement dom_smoke_test.v.
// (Each _test.v is compiled separately, so this file has its own helpers.)

const html_ns = 'http://www.w3.org/1999/xhtml'
const svg_ns = 'http://www.w3.org/2000/svg'
const xlink_ns = 'http://www.w3.org/1999/xlink'

fn mk(doc &Document, tag string) &Element {
	return doc.create_element(tag) or { panic('create_element(${tag}): ${err}') }
}

fn append(mut parent Node, child &Node) {
	parent.append_child(child) or { panic('${err}') }
}

// getElementsByClassName-multiple / -empty-string:
// all specified class names must be present (whitespace-separated, order-independent).
fn test_get_elements_by_class_name() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	specs := ['te st', 'st te', 'te te st', 'te te', 'test']
	for i, cls in specs {
		mut d := mk(doc, 'div')
		d.set_attribute_value('class', cls)
		d.set_attribute_value('id', '${i}')
		append(mut rn, d.as_node())
	}
	// 'te st' -> elements having BOTH te and st: indices 0,1,2.
	both := root.get_elements_by_class_name('te st')
	assert both.length() == 3
	assert (both.item(0) or { panic('') }).get_attribute('id') or { '' } == '0'
	assert root.get_elements_by_class_name('te').length() == 4 // 0,1,2,3
	assert root.get_elements_by_class_name('st').length() == 3 // 0,1,2
	assert root.get_elements_by_class_name('test').length() == 1 // 4
	assert root.get_elements_by_class_name('nope').length() == 0
	// Empty / whitespace-only class strings match nothing.
	assert root.get_elements_by_class_name('').length() == 0
	assert root.get_elements_by_class_name('   ').length() == 0
}

// getElementById-multiple: with duplicate ids, returns the first in tree order.
// getElementById-empty-string: returns null.
fn test_get_element_by_id_multiple_and_empty() {
	doc := Document.create(url_about_blank())
	mut doc_node := unsafe { &Node(doc) }
	mut root := mk(doc, 'html')
	append(mut doc_node, root.as_node())
	mut rn := root.as_node()

	mut first := mk(doc, 'div')
	first.set_attribute_value('id', 'dup')
	first.set_attribute_value('data-n', '1')
	mut second := mk(doc, 'div')
	second.set_attribute_value('id', 'dup')
	second.set_attribute_value('data-n', '2')
	append(mut rn, first.as_node())
	append(mut rn, second.as_node())

	found := doc.get_element_by_id('dup') or { panic('no dup') }
	assert (found.get_attribute('data-n') or { '' }) == '1'
	assert doc.get_element_by_id('') == none
	assert doc.get_element_by_id('missing') == none
}

// Node.normalize: merges contiguous text nodes and drops empty ones.
fn test_normalize() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	append(mut rn, doc.create_text_node('Hello').as_node())
	append(mut rn, doc.create_text_node('').as_node())
	append(mut rn, doc.create_text_node(' world').as_node())
	append(mut rn, mk(doc, 'span').as_node())
	append(mut rn, doc.create_text_node('!').as_node())
	assert rn.child_count() == 5

	rn.normalize() or { panic('${err}') }
	// 'Hello'+''+' world' -> 'Hello world' (empty removed); span; '!'.
	assert rn.child_count() == 3
	first := rn.first_child() or { panic('') }
	assert first.is_text()
	assert (unsafe { &Text(first) }).data() == 'Hello world'
}

// Element.toggleAttribute: toggles presence, honors the force argument, returns the new state.
fn test_toggle_attribute() {
	doc := Document.create(url_about_blank())
	mut e := mk(doc, 'div')
	assert !e.has_attribute('hidden')
	assert e.toggle_attribute('hidden', none) or { panic('') } == true
	assert e.has_attribute('hidden')
	assert e.toggle_attribute('hidden', none) or { panic('') } == false
	assert !e.has_attribute('hidden')
	// force = true adds (or keeps) it.
	assert e.toggle_attribute('hidden', ?bool(true)) or { panic('') } == true
	assert e.toggle_attribute('hidden', ?bool(true)) or { panic('') } == true
	assert e.has_attribute('hidden')
	// force = false removes it.
	assert e.toggle_attribute('hidden', ?bool(false)) or { panic('') } == false
	assert !e.has_attribute('hidden')
	// Empty attribute name is an InvalidCharacterError.
	if _ := e.toggle_attribute('', none) {
		assert false, 'empty name should throw'
	}
}

// createElement rejects invalid names (createElement-with-emoji, setAttribute-name-validation).
fn test_invalid_element_name_throws() {
	doc := Document.create(url_about_blank())
	if _ := doc.create_element('has space') {
		assert false, 'space in name should throw'
	}
	if _ := doc.create_element('1leadingdigit') {
		assert false, 'leading digit should throw'
	}
	// An emoji IS a valid name character (XML NameStartChar includes U+10000-U+EFFFF), so this
	// must NOT throw (matches upstream createElement-with-emoji-in-tag-name).
	assert (mk(doc, '🧐')).local_name() == '🧐'
	assert (mk(doc, 'my-element')).local_name() == 'my-element'
}

// CharacterData.replaceData: remove `count` units at `offset` and insert `data`.
fn test_character_data_replace_data() {
	doc := Document.create(url_about_blank())
	mut text := doc.create_text_node('Hello world')
	text.replace_data(0, 5, 'Goodbye') or { panic('${err}') }
	assert text.data() == 'Goodbye world'
	text.replace_data(0, 0, 'Say: ') or { panic('${err}') } // pure insertion
	assert text.data() == 'Say: Goodbye world'
}

// Element.removeAttributeNode.
fn test_remove_attribute_node() {
	doc := Document.create(url_about_blank())
	mut e := mk(doc, 'a')
	e.set_attribute_value('href', 'x')
	attr := e.get_attribute_node('href') or { panic('no attr') }
	e.remove_attribute_node(attr) or { panic('${err}') }
	assert !e.has_attribute('href')
}

// Namespaced attributes: setAttributeNS + getAttributeNodeNS.
fn test_attribute_ns() {
	doc := Document.create(url_about_blank())
	mut e := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	e.set_attribute_ns_for_bindings(xlink_ns, 'xlink:href', 'u') or { panic('${err}') }
	attr := e.get_attribute_node_ns(xlink_ns, 'href') or { panic('no ns attr') }
	assert attr.value() == 'u'
	assert attr.name() == 'xlink:href'
}

// createElementNS preserves the given case (Document-createElementNS-uppercase).
fn test_create_element_ns_case_preserved() {
	doc := Document.create(url_about_blank())
	svg := doc.create_element_ns(svg_ns, 'clipPath') or { panic('${err}') }
	assert svg.local_name() == 'clipPath'
	assert (svg.namespace_uri() or { '' }) == svg_ns
}

// DOMImplementation.createHTMLDocument builds html > head > title, body.
fn test_create_html_document() {
	mut doc := Document.create(url_about_blank())
	mut implementation := doc.implementation()
	new_doc := implementation.create_html_document('My Title') or { panic('${err}') }
	html_el := new_doc.document_element() or { panic('no document element') }
	assert html_el.local_name() == 'html'
	// html has a head (with the title) and a body.
	children := html_el.as_node().children_as_vector()
	assert children.len == 2
	assert (children[0].as_element() or { panic('') }).local_name() == 'head'
	assert (children[1].as_element() or { panic('') }).local_name() == 'body'
}

// Range.toString + Range.deleteContents over a text node (Range-to-string, Range-deleteContents).
fn test_range_to_string_and_delete_contents() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	mut text := doc.create_text_node('Hello world')
	append(mut rn, text.as_node())

	mut range := doc.create_range()
	range.set_start(text.as_node(), 0) or { panic('${err}') }
	range.set_end(text.as_node(), 5) or { panic('${err}') }
	assert range.to_string() == 'Hello'
	range.delete_contents() or { panic('${err}') }
	assert text.data() == ' world'
}

// ChildNode.before / after: insert nodes (and strings, converted to text) around this node
// (ChildNode-before-previous-sibling, ChildNode-after-next-sibling).
fn test_child_node_before_after() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	b := mk(doc, 'b')
	append(mut rn, b.as_node())

	mut bn := b.as_node()
	a := mk(doc, 'a')
	bn.before([node_or_string_from_node(a.as_node()), node_or_string_from_string('x')]) or {
		panic('${err}')
	}
	c := mk(doc, 'c')
	bn.after([node_or_string_from_node(c.as_node())]) or { panic('${err}') }

	mut names := []string{}
	for child in rn.children {
		names << child.node_name()
	}
	assert names == ['a', '#text', 'b', 'c']
}

// ChildNode.replaceWith.
fn test_child_node_replace_with() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	old := mk(doc, 'old')
	append(mut rn, old.as_node())

	x := mk(doc, 'x')
	y := mk(doc, 'y')
	mut on := old.as_node()
	on.replace_with([node_or_string_from_node(x.as_node()), node_or_string_from_node(y.as_node())]) or {
		panic('${err}')
	}

	mut names := []string{}
	for child in rn.children {
		names << child.node_name()
	}
	assert names == ['x', 'y']
	assert old.as_node().parent() == none
}

// NonDocumentTypeChildNode.previousElementSibling / nextElementSibling: skip non-element siblings.
fn test_element_siblings() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	append(mut rn, doc.create_text_node('t1').as_node())
	a := mk(doc, 'a')
	append(mut rn, a.as_node())
	append(mut rn, doc.create_text_node('t2').as_node())
	b := mk(doc, 'b')
	append(mut rn, b.as_node())

	assert (a.as_node().next_element_sibling() or { panic('') }).local_name() == 'b'
	assert (b.as_node().previous_element_sibling() or { panic('') }).local_name() == 'a'
	assert a.as_node().previous_element_sibling() == none // only a text node precedes it
	assert b.as_node().next_element_sibling() == none
}

// Node.contains: true iff other is an inclusive descendant (null -> false).
fn test_contains() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut rn := root.as_node()
	child := mk(doc, 'span')
	append(mut rn, child.as_node())
	grandchild := mk(doc, 'a')
	mut cn := child.as_node()
	append(mut cn, grandchild.as_node())
	other := mk(doc, 'p') // not in the tree

	assert rn.contains(rn) // inclusive: a node contains itself
	assert rn.contains(child.as_node())
	assert rn.contains(grandchild.as_node()) // deep descendant
	assert !rn.contains(other.as_node())
	assert !child.as_node().contains(rn) // a child does not contain its parent
	assert !rn.contains(none) // null -> false
}

// Node.lookupNamespaceURI / isDefaultNamespace (Node-lookupNamespaceURI, Node-isDefaultNamespace).
fn test_namespace_lookups() {
	doc := Document.create(url_about_blank())
	html_el := doc.create_element_ns(html_ns, 'div') or { panic('${err}') }
	svg_el := doc.create_element_ns(svg_ns, 'rect') or { panic('${err}') }

	// lookupNamespaceURI(null) returns the element's own namespace.
	assert (html_el.as_node().lookup_namespace_uri(none) or { '' }) == html_ns
	assert (svg_el.as_node().lookup_namespace_uri(none) or { '' }) == svg_ns
	// The xml prefix is always bound.
	assert (html_el.as_node().lookup_namespace_uri('xml') or { '' }) == 'http://www.w3.org/XML/1998/namespace'

	// isDefaultNamespace.
	assert html_el.as_node().is_default_namespace(html_ns)
	assert !html_el.as_node().is_default_namespace(svg_ns)

	// A non-namespaced element's default namespace is null.
	plain := mk(doc, 'div') // Document.create -> namespace none
	assert plain.as_node().is_default_namespace(none)
	assert !plain.as_node().is_default_namespace(html_ns)
}

// Node.nodeName for the stable non-element node types (Node-nodeName).
fn test_node_name_variants() {
	doc := Document.create(url_about_blank())
	assert doc.create_text_node('x').as_node().node_name() == '#text'
	assert doc.create_comment('x').as_node().node_name() == '#comment'
	mut doc_node := unsafe { &Node(doc) }
	assert doc_node.node_name() == '#document'
	frag := new_document_fragment(doc)
	assert frag.as_node().node_name() == '#document-fragment'
}

fn test_url_resolution_and_fragment_mutation() {
	base := URL{'https://example.com/a/b/index.html?old=1#before'}
	resolved := dom_url_parse('../image.png?size=2#preview', base, 'UTF-8') or {
		panic('relative URL did not parse')
	}
	assert resolved.serialize() == 'https://example.com/a/image.png?size=2#preview'
	assert resolved.fragment() or { '' } == 'preview'

	mut changed := resolved
	changed.set_fragment('final')
	assert changed.serialize() == 'https://example.com/a/image.png?size=2#final'
	changed.set_fragment(none)
	assert changed.serialize() == 'https://example.com/a/image.png?size=2'
	assert dom_url_parse('http://[', base, 'UTF-8') == none
}

fn test_url_origin_preserves_tuple_and_opaque_identity() {
	first := URL{ value: 'https://a.example.co.uk/path' }.origin()
	second := URL{ value: 'https://b.example.co.uk/other' }.origin()
	assert first.serialize() == 'https://a.example.co.uk'
	assert !first.is_same_origin(second)
	assert first.is_same_site(second)
	opaque_a := origin_create_opaque()
	opaque_a_copy := opaque_a
	opaque_b := origin_create_opaque()
	assert opaque_a.serialize() == 'null'
	assert opaque_a.is_same_origin(opaque_a_copy)
	assert !opaque_a.is_same_origin(opaque_b)
	assert origin_from_ipc(opaque_a.serialize_for_ipc()).is_same_origin(opaque_a)
	assert URL{ value: 'file:///tmp/a' }.origin().is_opaque_file_origin()
}

fn test_meta_color_scheme_discovery() {
	mut doc := Document.create(url_about_blank())
	mut html := doc.create_element_ns(html_ns, 'html') or { panic('${err}') }
	mut head := doc.create_element_ns(html_ns, 'head') or { panic('${err}') }
	mut invalid_meta := doc.create_element_ns(html_ns, 'meta') or { panic('${err}') }
	invalid_meta.set_attribute_value('name', 'COLOR-SCHEME')
	invalid_meta.set_attribute_value('content', 'normal dark')
	mut valid_meta := doc.create_element_ns(html_ns, 'meta') or { panic('${err}') }
	valid_meta.set_attribute_value('name', 'color-scheme')
	valid_meta.set_attribute_value('content', 'only DARK light')

	mut doc_node := unsafe { &Node(doc) }
	append(mut doc_node, html.as_node())
	mut html_node := html.as_node()
	append(mut html_node, head.as_node())
	mut head_node := head.as_node()
	append(mut head_node, invalid_meta.as_node())
	append(mut head_node, valid_meta.as_node())

	doc.obtain_supported_color_schemes()
	schemes := doc.supported_color_schemes() or { panic('no supported color schemes') }
	assert schemes == ['dark', 'light']
}

fn test_focus_updates_active_element_and_invalidates_style() {
	mut doc := Document.create(url_about_blank())
	mut html := doc.create_element_ns(html_ns, 'html') or { panic('${err}') }
	mut body := doc.create_element_ns(html_ns, 'body') or { panic('${err}') }
	input := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	mut doc_node := unsafe { &Node(doc) }
	append(mut doc_node, html.as_node())
	mut html_node := html.as_node()
	append(mut html_node, body.as_node())
	mut body_node := body.as_node()
	append(mut body_node, input.as_node())

	doc.set_focused_area(input.as_node())
	assert (doc.focused_area() or { panic('no focused area') }).is_same_node(input.as_node())
	assert (doc.active_element() or { panic('no active element') }) == input
	assert input.needs_style_update()

	doc.set_focused_area(none)
	assert doc.focused_area() == none
}

fn test_hovered_node_identity_handles_null_transitions() {
	mut doc := Document.create(url_about_blank())
	first := mk(doc, 'div')
	second := mk(doc, 'div')

	doc.set_hovered_node(first.as_node())
	assert (doc.get_hovered_node() or { panic('no hovered node') }).is_same_node(first.as_node())
	doc.set_hovered_node(second.as_node())
	assert (doc.get_hovered_node() or { panic('no hovered node') }).is_same_node(second.as_node())
	doc.set_hovered_node(none)
	assert doc.get_hovered_node() == none
}

fn test_attribute_changes_invalidate_descendant_style() {
	doc := Document.create(url_about_blank())
	mut parent := mk(doc, 'div')
	child := mk(doc, 'span')
	mut parent_node := parent.as_node()
	append(mut parent_node, child.as_node())
	parent_node.set_entire_subtree_needs_style_update(false)

	parent.set_attribute_value('class', 'theme')
	assert parent_node.entire_subtree_needs_style_update()
}

fn test_style_invalidator_applies_descendant_and_sibling_plans() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'root')
	mut first := mk(doc, 'first')
	mut matching_descendant := mk(doc, 'span')
	matching_descendant.set_attribute_value('class', 'affected')
	mut following := mk(doc, 'following')

	mut root_node := root.as_node()
	append(mut root_node, first.as_node())
	mut first_node := first.as_node()
	append(mut first_node, matching_descendant.as_node())
	append(mut root_node, doc.create_text_node('separator').as_node())
	append(mut root_node, following.as_node())
	root_node.set_needs_style_update(false)
	first_node.set_needs_style_update(false)
	mut descendant_node := matching_descendant.as_node()
	descendant_node.set_needs_style_update(false)
	mut following_node := following.as_node()
	following_node.set_needs_style_update(false)

	descendant_payload := InvalidationPlan{
		invalidate_self: true
	}
	sibling_payload := InvalidationPlan{
		invalidate_self: true
	}
	plan := InvalidationPlan{
		descendant_rules: [
			DescendantInvalidationRule{
				match_set: StyleInvalidationSet{
					properties: [
						InvalidationProperty{
							type_: .class
							name:  'affected'
						},
					]
				}
				payload:   descendant_payload
			},
		]
		sibling_rules:    [
			SiblingInvalidationRule{
				match_any: true
				reach:     .subsequent
				payload:   sibling_payload
			},
		]
	}

	mut invalidator := StyleInvalidator{}
	assert !invalidator.enqueue_invalidation_plan(first.as_node(), .element_attribute_change, plan)
	invalidator.invalidate(mut root_node)
	assert matching_descendant.needs_style_update()
	assert following.needs_style_update()
	assert invalidator.pending_invalidations.len == 0
	assert invalidator.active_descendant_invalidations.len == 0
}

fn test_style_invalidator_whole_subtree_plan_short_circuits() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'div')
	mut root_node := root.as_node()
	root_node.set_entire_subtree_needs_style_update(false)
	mut invalidator := StyleInvalidator{}
	assert invalidator.enqueue_invalidation_plan(root.as_node(), .element_attribute_change, InvalidationPlan{
		invalidate_whole_subtree: true
	})
	assert root_node.entire_subtree_needs_style_update()
}

fn test_hidden_state_uses_layout_visibility_and_aria_ancestors() {
	doc := Document.create(url_about_blank())
	mut parent := mk(doc, 'div')
	mut child := mk(doc, 'span')
	mut parent_node := parent.as_node()
	append(mut parent_node, child.as_node())

	// Elements without a layout node are not rendered.
	assert child.is_hidden()
	mut child_node := child.as_node()
	child_node.set_layout_node(&LayoutNode{})
	child.set_computed_properties(none, &CSSComputedProperties_{})
	assert !child.is_hidden()

	child.set_computed_properties(none, &CSSComputedProperties_{
		visibility_: .collapse
	})
	assert child.is_hidden()
	child.set_computed_properties(none, &CSSComputedProperties_{})
	parent.set_attribute_value('aria-hidden', 'true')
	assert child.is_hidden()
	assert child.has_hidden_ancestor()
}

fn test_element_state_pseudo_classes() {
	doc := Document.create(URL{'https://example.com/path#current'})
	mut checkbox := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	checkbox.set_attribute_value('type', 'checkbox')
	assert checkbox.matches_unchecked_pseudo_class()
	checkbox.set_attribute_value('checked', '')
	assert checkbox.matches_checked_pseudo_class()
	assert !checkbox.matches_unchecked_pseudo_class()
	assert !mk(doc, 'div').matches_unchecked_pseudo_class()

	mut option := doc.create_element_ns(html_ns, 'option') or { panic('${err}') }
	assert option.matches_unchecked_pseudo_class()
	option.set_attribute_value('selected', '')
	assert option.matches_checked_pseudo_class()

	mut input := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	input.set_attribute_value('placeholder', 'Name')
	assert input.matches_placeholder_shown_pseudo_class()
	input.set_attribute_value('value', 'Alice')
	assert !input.matches_placeholder_shown_pseudo_class()

	mut local := doc.create_element_ns(html_ns, 'a') or { panic('${err}') }
	local.set_attribute_value('href', '/path')
	assert local.matches_local_link_pseudo_class()
	local.set_attribute_value('href', '/path#other')
	assert !local.matches_local_link_pseudo_class()
}

fn test_registrable_domain_suffix_validation() {
	assert is_a_registrable_domain_suffix_of_or_is_equal_to('www.example.com', 'www.example.com')
	assert is_a_registrable_domain_suffix_of_or_is_equal_to('example.com', 'www.example.com')
	assert !is_a_registrable_domain_suffix_of_or_is_equal_to('com', 'www.example.com')
	assert !is_a_registrable_domain_suffix_of_or_is_equal_to('co.uk', 'www.example.co.uk')
	assert is_a_registrable_domain_suffix_of_or_is_equal_to('example.co.uk', 'www.example.co.uk')
	assert !is_a_registrable_domain_suffix_of_or_is_equal_to('ample.com', 'example.com')
	assert !is_a_registrable_domain_suffix_of_or_is_equal_to('127.0.0.1', 'sub.127.0.0.1')
	assert is_a_registrable_domain_suffix_of_or_is_equal_to('127.0.0.1', '127.0.0.1')
}

fn test_xml_serialization_namespaces_and_node_types() {
	doc := Document.create(url_about_blank())
	mut root := doc.create_element_ns('urn:test', 'p:root') or { panic('${err}') }
	root.set_attribute_ns_for_bindings(xlink_ns, 'xlink:href', 'a&b') or { panic('${err}') }
	mut root_node := root.as_node()
	append(mut root_node, doc.create_text_node('x < y & z').as_node())
	append(mut root_node, doc.create_comment('ok').as_node())
	processing_instruction := doc.create_processing_instruction('work', 'data') or {
		panic('${err}')
	}
	append(mut root_node, processing_instruction.as_node())
	cdata := doc.create_cdata_section('<raw>') or { panic('${err}') }
	append(mut root_node, cdata.as_node())

	assert root.outer_html() or { panic('${err}') } == '<p:root xmlns:p="urn:test" xmlns:xlink="${xlink_ns}" xlink:href="a&amp;b">x &lt; y &amp; z<!--ok--><?work data?><![CDATA[<raw>]]></p:root>'
}

fn test_xml_serialization_rejects_malformed_comment() {
	doc := Document.create(url_about_blank())
	mut root := mk(doc, 'root')
	mut root_node := root.as_node()
	append(mut root_node, doc.create_comment('bad--comment').as_node())
	if _ := root.outer_html() {
		assert false, 'malformed XML comment unexpectedly serialized'
	} else {
		assert err.str().contains('well-formed XML')
	}
}

fn test_top_layer_and_fullscreen_state_machine() {
	mut doc := Document.create(url_about_blank())
	mut first := mk(doc, 'div')
	mut second := mk(doc, 'div')

	doc.fullscreen_element_within_doc(mut first)
	assert first.in_top_layer()
	assert first.rendered_in_top_layer()
	assert (doc.fullscreen_element() or { panic('no fullscreen element') }) == first

	doc.fullscreen_element_within_doc(mut second)
	assert (doc.fullscreen_element() or { panic('no fullscreen element') }) == second
	doc.request_an_element_to_be_remove_from_the_top_layer(second)
	assert !second.in_top_layer()
	assert !second.rendered_in_top_layer()

	// Re-adding cancels the pending removal and moves the element to the top.
	doc.add_an_element_to_the_top_layer(second)
	assert second.in_top_layer()
	doc.process_top_layer_removals()
	assert second.in_top_layer()

	doc.remove_an_element_from_the_top_layer_immediately(second)
	assert !second.in_top_layer()
	assert (doc.fullscreen_element() or { panic('first should remain fullscreen') }) == first
}

fn test_generic_event_target_dispatch_does_not_probe_node_storage() {
	target := EventTarget.construct_impl() or { panic(err) }
	assert target.data.kind == .generic
	event := Event.new('generic-target-event')
	assert target.dispatch_event_binding(event) or { panic(err) }
	assert (event.target() or { panic('dispatch did not set the event target') }) == target

	first_document := Document.create(url_about_blank())
	second_document := Document.create(url_about_blank())
	first_node := unsafe { &Node(first_document) }
	second_node := unsafe { &Node(second_document) }
	assert first_node.data.kind == .node
	assert second_node.data.kind == .node
	assert first_node.unique_id_.value() != 0
	assert first_node.unique_id_ != second_node.unique_id_
}

fn test_document_environment_variables_match_upstream_host_defaults() {
	document := Document.create(url_about_blank())
	assert (document.environment_variable_value(.preferred_text_scale) or { '' }) == '1'
	for variable in [
		EnvironmentVariable.safe_area_inset_top,
		.safe_area_inset_right,
		.safe_area_inset_bottom,
		.safe_area_inset_left,
		.safe_area_max_inset_top,
		.safe_area_max_inset_right,
		.safe_area_max_inset_bottom,
		.safe_area_max_inset_left,
	] {
		assert (document.environment_variable_value(variable) or { '' }) == '0px'
	}
	assert document.environment_variable_value(.viewport_segment_width) == none
}

// https://html.spec.whatwg.org/multipage/semantics-other.html#selector-required
// and #selector-optional and #selector-default. The `required` attribute only
// *applies* to some input types, so an input of another type is neither
// required nor optional.
fn test_form_state_pseudo_classes() {
	doc := Document.create(URL{'https://example.com/'})

	mut text_input := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	text_input.set_attribute_value('type', 'text')
	assert !text_input.matches_required_pseudo_class()
	assert text_input.matches_optional_pseudo_class()
	text_input.set_attribute_value('required', '')
	assert text_input.matches_required_pseudo_class()
	assert !text_input.matches_optional_pseudo_class()

	// `required` does not apply to a button, so it is neither.
	mut button_input := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	button_input.set_attribute_value('type', 'button')
	button_input.set_attribute_value('required', '')
	assert !button_input.matches_required_pseudo_class()
	assert !button_input.matches_optional_pseudo_class()

	// AD-HOC: a hidden input matches :optional, as Chromium and WebKit do.
	mut hidden_input := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	hidden_input.set_attribute_value('type', 'hidden')
	assert hidden_input.matches_optional_pseudo_class()

	for name in ['select', 'textarea'] {
		mut control := doc.create_element_ns(html_ns, name) or { panic('${err}') }
		assert control.matches_optional_pseudo_class()
		assert !control.matches_required_pseudo_class()
		control.set_attribute_value('required', '')
		assert control.matches_required_pseudo_class()
		assert !control.matches_optional_pseudo_class()
	}

	assert !mk(doc, 'div').matches_required_pseudo_class()
	assert !mk(doc, 'div').matches_optional_pseudo_class()

	// :default matches a checked checkbox/radio and a selected option.
	mut checkbox := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	checkbox.set_attribute_value('type', 'checkbox')
	assert !checkbox.matches_default_pseudo_class()
	checkbox.set_attribute_value('checked', '')
	assert checkbox.matches_default_pseudo_class()

	mut option := doc.create_element_ns(html_ns, 'option') or { panic('${err}') }
	assert !option.matches_default_pseudo_class()
	option.set_attribute_value('selected', '')
	assert option.matches_default_pseudo_class()

	// `checked` does not apply to a text input.
	mut checked_text := doc.create_element_ns(html_ns, 'input') or { panic('${err}') }
	checked_text.set_attribute_value('type', 'text')
	checked_text.set_attribute_value('checked', '')
	assert !checked_text.matches_default_pseudo_class()
}

// https://svgwg.org/svg2-draft/types.html#__svg__SVGElement__ownerSVGElement
// and #__svg__SVGElement__viewportElement.
fn test_svg_owner_and_viewport_element() {
	doc := Document.create(URL{'https://example.com/'})
	mut outer := doc.create_element_ns(svg_ns, 'svg') or { panic('${err}') }
	mut symbol := doc.create_element_ns(svg_ns, 'symbol') or { panic('${err}') }
	mut inner := doc.create_element_ns(svg_ns, 'svg') or { panic('${err}') }
	mut rect := doc.create_element_ns(svg_ns, 'rect') or { panic('${err}') }
	mut group := doc.create_element_ns(svg_ns, 'g') or { panic('${err}') }

	mut symbol_node := symbol.as_node()
	symbol_node.append_child(rect.as_node()) or { panic('append failed') }
	mut inner_node := inner.as_node()
	inner_node.append_child(symbol_node) or { panic('append failed') }
	mut group_node := group.as_node()
	group_node.append_child(inner_node) or { panic('append failed') }
	mut outer_node := outer.as_node()
	outer_node.append_child(group_node) or { panic('append failed') }

	// ownerSVGElement is the nearest ancestor `svg`, skipping the `symbol`.
	owner := rect.owner_svg_element() or { panic('rect has no owner svg') }
	assert owner.local_name() == 'svg'
	assert voidptr(owner) == voidptr(inner)
	// The outermost `svg` has none.
	assert outer.owner_svg_element() == none
	// The inner `svg`'s owner is the outer one.
	inner_owner := inner.owner_svg_element() or { panic('inner has no owner svg') }
	assert voidptr(inner_owner) == voidptr(outer)

	// viewportElement stops at the `symbol`, which establishes a viewport too.
	viewport := rect.viewport_element() or { panic('rect has no viewport element') }
	assert voidptr(viewport) == voidptr(symbol)
	// A group's nearest viewport is the enclosing `svg`.
	group_viewport := group.viewport_element() or { panic('group has no viewport element') }
	assert voidptr(group_viewport) == voidptr(outer)
	assert outer.viewport_element() == none

	// Neither applies to a non-SVG element.
	assert mk(doc, 'div').owner_svg_element() == none
	assert mk(doc, 'div').viewport_element() == none
}
