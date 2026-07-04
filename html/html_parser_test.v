module html

import dom

// Runtime tests for the tree-construction parser: parse HTML source into a DOM tree and check the
// resulting structure with a compact serializer (element(children...), "text", <!--comment-->).

fn parse(input string) &dom.Document {
	doc := dom.Document.create(dom.url_about_blank())
	mut parser := HTMLParser.create(doc, input)
	parser.run()
	return doc
}

// element -> local_name(child,child,...); text -> "data"; comment -> <!--data-->; doctype -> <!name>
fn tree_repr(node &dom.Node) string {
	if el := node.as_element() {
		mut out := el.local_name()
		kids := node.children_as_vector()
		if kids.len > 0 {
			mut parts := []string{}
			for k in kids {
				parts << tree_repr(k)
			}
			out += '(' + parts.join(',') + ')'
		}
		return out
	}
	if node.is_text() {
		return '"' + node_as_text(node).data() + '"'
	}
	if node.is_comment() {
		return '<!--comment-->'
	}
	return node.node_name()
}

fn html_element(doc &dom.Document) &dom.Node {
	el := doc.document_element() or { panic('no document element') }
	return el.as_node()
}

fn nth_child(node &dom.Node, index int) &dom.Node {
	kids := node.children_as_vector()
	return kids[index]
}

fn test_basic_document() {
	doc := parse('<!DOCTYPE html><html><head><title>Hi</title></head><body><p>Hello</p></body></html>')
	// The document has a doctype then the html element.
	mut doc_node := unsafe { &dom.Node(doc) }
	kids := doc_node.children_as_vector()
	assert kids.len == 2
	assert kids[0].node_name() == 'html' // doctype name
	assert tree_repr(html_element(doc)) == 'html(head(title("Hi")),body(p("Hello")))'
}

fn test_implicit_head_and_body() {
	// No <html>/<head>/<body> tags: the parser must synthesize them.
	doc := parse('<title>T</title><p>Hello</p>')
	assert tree_repr(html_element(doc)) == 'html(head(title("T")),body(p("Hello")))'
}

fn test_paragraph_auto_close() {
	// A <p> is implicitly closed by a following block-level <p>.
	doc := parse('<body><p>one<p>two</body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(p("one"),p("two"))'
}

fn test_formatting_element() {
	doc := parse('<body><p>Hello <b>world</b>!</p></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(p("Hello ",b("world"),"!"))'
}

fn test_adoption_agency_misnesting() {
	// The classic misnested-tags case; the adoption agency algorithm (no-furthest-block path)
	// plus reconstruct-the-active-formatting-elements must produce this tree.
	doc := parse('<!DOCTYPE html><body><b>1<i>2</b>3</i></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(b("1",i("2")),i("3"))'
}

fn test_attributes() {
	doc := parse('<body><div id="a" class="b c" data-x="1"></div></body>')
	body := nth_child(html_element(doc), 1)
	div := nth_child(body, 0).as_element() or { panic('no div') }
	assert div.local_name() == 'div'
	assert (div.get_attribute('id') or { '' }) == 'a'
	assert (div.get_attribute('class') or { '' }) == 'b c'
	assert (div.get_attribute('data-x') or { '' }) == '1'
}

fn test_uppercase_tag_name_in_html_document() {
	doc := parse('<body><section></section></body>')
	body := nth_child(html_element(doc), 1)
	section := nth_child(body, 0).as_element() or { panic('no section') }
	// Internal comparisons use local_name (lowercase); the public tag_name is uppercased in an HTML
	// document.
	assert section.local_name() == 'section'
	assert section.tag_name() == 'SECTION'
}

fn test_comment_in_body() {
	doc := parse('<body><!--hi--><p>x</p></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(<!--comment-->,p("x"))'
}

fn test_nested_lists() {
	doc := parse('<body><ul><li>a<li>b</ul></body>')
	body := nth_child(html_element(doc), 1)
	// Each <li> is implicitly closed by the next; both are children of the <ul>.
	assert tree_repr(body) == 'body(ul(li("a"),li("b")))'
}

fn test_text_before_html_is_moved_into_body() {
	// Leading non-whitespace text triggers body creation and ends up inside the body.
	doc := parse('Hello<p>world</p>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body("Hello",p("world"))'
}

fn test_table_implicit_tbody() {
	// A bare <tr> inside <table> gets an implicit <tbody> wrapper.
	doc := parse('<body><table><tr><td>a</td></tr></table></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(table(tbody(tr(td("a")))))'
}

fn test_table_cells_auto_close() {
	// <td>/<tr> auto-close each other.
	doc := parse('<body><table><tbody><tr><td>x<td>y</tr></tbody></table></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(table(tbody(tr(td("x"),td("y")))))'
}

fn test_table_thead_and_tbody() {
	doc := parse('<table><thead><tr><th>H</th></tr></thead><tbody><tr><td>D</td></tr></tbody></table>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(table(thead(tr(th("H"))),tbody(tr(td("D")))))'
}

fn test_table_caption() {
	doc := parse('<table><caption>C</caption><tr><td>x</td></tr></table>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(table(caption("C"),tbody(tr(td("x")))))'
}

fn test_table_colgroup() {
	doc := parse('<table><colgroup><col></colgroup><tr><td>x</td></tr></table>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(table(colgroup(col),tbody(tr(td("x")))))'
}

fn test_table_foster_parenting() {
	// Non-whitespace text directly inside <table> is foster-parented out, before the table.
	doc := parse('<table>foo<tr><td>x</td></tr></table>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body("foo",table(tbody(tr(td("x")))))'
}

fn test_void_elements_in_body() {
	// <br>/<img> are void: they must not swallow following siblings.
	doc := parse('<body><p>a<br><img>b</p></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(p("a",br,img,"b"))'
}
