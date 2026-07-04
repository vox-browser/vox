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
