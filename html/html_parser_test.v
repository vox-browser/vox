module html

import dom

// Runtime tests for the tree-construction parser: parse HTML source into a DOM tree and check the
// resulting structure with a compact serializer (element(children...), "text", <!--comment-->).

fn parse(input string) &dom.Document {
	// Exercise the public top-level entry point.
	return parse_document(input)
}

// element -> local_name(child,child,...); text -> "data"; comment -> <!--data-->; doctype -> <!name>
fn tree_repr(node &dom.Node) string {
	if el := node.as_element() {
		mut out := el.local_name()
		ns := el.namespace_uri() or { '' }
		if ns == ns_svg {
			out = 'svg:' + out
		} else if ns == ns_mathml {
			out = 'math:' + out
		}
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

fn children_repr(node &dom.Node) string {
	mut parts := []string{}
	for k in node.children_as_vector() {
		parts << tree_repr(k)
	}
	return parts.join(',')
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

fn test_inline_svg() {
	doc := parse('<body><svg><rect></rect><circle></circle></svg></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(svg:svg(svg:rect,svg:circle))'
}

fn test_svg_tag_name_casing() {
	// The tokenizer lowercases <clipPath>; adjust_svg_tag_names restores the camelCase local name.
	doc := parse('<body><svg><clipPath></clipPath></svg></body>')
	body := nth_child(html_element(doc), 1)
	svg := nth_child(body, 0)
	child := nth_child(svg, 0).as_element() or { panic('no svg child') }
	assert child.local_name() == 'clipPath'
	assert tree_repr(body) == 'body(svg:svg(svg:clipPath))'
}

fn test_svg_attribute_casing() {
	doc := parse('<body><svg viewBox="0 0 1 1"></svg></body>')
	body := nth_child(html_element(doc), 1)
	svg := nth_child(body, 0).as_element() or { panic('no svg') }
	// 'viewbox' (lowercased by the tokenizer) is restored to 'viewBox'.
	assert (svg.get_attribute('viewBox') or { '' }) == '0 0 1 1'
}

fn test_mathml() {
	// <mi> is a MathML text integration point, so its text child is parsed with HTML rules.
	doc := parse('<body><math><mi>x</mi></math></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(math:math(math:mi("x")))'
}

fn test_svg_html_integration_point() {
	// <foreignObject> is an HTML integration point: its <div> child is an HTML-namespace element.
	doc := parse('<body><svg><foreignObject><div>hi</div></foreignObject></svg></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(svg:svg(svg:foreignObject(div("hi"))))'
}

fn test_foreign_content_breakout() {
	// A <p> start tag inside SVG breaks out of foreign content back to HTML.
	doc := parse('<body><svg><rect></rect><p>out</p></svg></body>')
	body := nth_child(html_element(doc), 1)
	// The <p> pops back out of the <svg> and becomes an HTML sibling of it in the body.
	assert tree_repr(body) == 'body(svg:svg(svg:rect),p("out"))'
}

fn test_select_options() {
	doc := parse('<body><select><option>a</option><option>b</option></select></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(select(option("a"),option("b")))'
}

fn test_select_option_auto_close() {
	// An <option> is implicitly closed by the next <option> and by </select>.
	doc := parse('<body><select><option>a<option>b</select></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(select(option("a"),option("b")))'
}

fn test_select_optgroup() {
	doc := parse('<body><select><optgroup><option>a</option></optgroup></select></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(select(optgroup(option("a"))))'
}

fn test_button() {
	doc := parse('<body><button>click</button></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(button("click"))'
}

fn test_textarea_rcdata_and_newline_skip() {
	// <textarea> is RCDATA (so '<b>' is literal text) and a leading newline is dropped.
	doc := parse('<body><textarea>\nhi<b>there</textarea></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(textarea("hi<b>there"))'
}

fn test_xmp_raw_text() {
	// <xmp> is a raw-text element: markup inside is literal text.
	doc := parse('<body><xmp><b>raw</b></xmp></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(xmp("<b>raw</b>"))'
}

fn test_template_contents() {
	doc := parse('<body><template><div>x</div><span>y</span></template></body>')
	body := nth_child(html_element(doc), 1)
	template := nth_child(body, 0).as_element() or { panic('no template') }
	assert template.local_name() == 'template'
	// The template element itself has no children in the tree; they live in its content fragment.
	assert template.as_node().children_as_vector().len == 0
	tmpl := unsafe { &dom.HTMLTemplateElement(template) }
	assert children_repr(tmpl.content().as_node()) == 'div("x"),span("y")'
}

fn test_content_after_template() {
	// After </template>, parsing resumes in the body.
	doc := parse('<body><template>t</template><p>after</p></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(template,p("after"))'
	template := nth_child(body, 0).as_element() or { panic('no template') }
	tmpl := unsafe { &dom.HTMLTemplateElement(template) }
	assert children_repr(tmpl.content().as_node()) == '"t"'
}

fn context_element(tag string) &dom.Element {
	doc := dom.Document.create(dom.url_about_blank())
	return doc.create_element_ns(ns_html, tag) or { panic('context ${tag}: ${err}') }
}

fn repr_nodes(nodes []&dom.Node) string {
	mut parts := []string{}
	for n in nodes {
		parts << tree_repr(n)
	}
	return parts.join(',')
}

fn test_fragment_div_context() {
	// The <div>-context fragment (like div.innerHTML = ...) parses with the "in body" rules.
	nodes := parse_html_fragment(context_element('div'), '<p>hello</p><b>x</b>')
	assert nodes.len == 2
	assert repr_nodes(nodes) == 'p("hello"),b("x")'
}

fn test_fragment_table_context() {
	// A <table>-context fragment parses with the "in table" rules: a bare <tr> gets an implicit
	// <tbody> and there is no <table> wrapper in the result.
	nodes := parse_html_fragment(context_element('table'), '<tr><td>x</td></tr>')
	assert repr_nodes(nodes) == 'tbody(tr(td("x")))'
}

fn test_fragment_tbody_context() {
	nodes := parse_html_fragment(context_element('tbody'), '<tr><td>a</td></tr><tr><td>b</td></tr>')
	assert repr_nodes(nodes) == 'tr(td("a")),tr(td("b"))'
}

fn test_fragment_textarea_context_is_rcdata() {
	// A <textarea>-context fragment tokenizes as RCDATA, so markup is literal text.
	nodes := parse_html_fragment(context_element('textarea'), 'a<b>c')
	assert repr_nodes(nodes) == '"a<b>c"'
}

fn test_parse_document_end_to_end() {
	// The one-call entry point produces a full html document.
	doc := parse_document('<!DOCTYPE html><title>T</title><p>hi</p>')
	assert doc.document_type() == .html
	html_el := doc.document_element() or { panic('no document element') }
	assert html_el.local_name() == 'html'
	// Structure: doctype + html(head(title), body(p)).
	assert tree_repr(html_el.as_node()) == 'html(head(title("T")),body(p("hi")))'
	mut doc_node := unsafe { &dom.Node(doc) }
	assert doc_node.children_as_vector()[0].node_name() == 'html' // the doctype
}

fn test_set_inner_html_replaces_children() {
	// div.innerHTML = ... : the div's existing children are replaced by the parsed fragment.
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(ns_html, 'div') or { panic('div') }
	mut div_node := div.as_node()
	div_node.append_child(doc.create_text_node('old').as_node()) or {}
	assert children_repr(div_node) == '"old"'

	set_inner_html(div, '<span>a</span><span>b</span>')
	assert children_repr(div_node) == 'span("a"),span("b")'
}
