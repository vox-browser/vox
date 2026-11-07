module html

import dom

fn quirks_mode_for_doctype(public_identifier string, system_identifier string, missing_system bool) dom.QuirksMode {
	document := dom.Document.create(dom.url_about_blank())
	parser := HTMLParser.create(document, '')
	mut token := HTMLToken.new(.doctype)
	token.doctype.name = 'html'
	token.doctype.missing_name = false
	token.doctype.public_identifier = public_identifier
	token.doctype.missing_public_identifier = false
	token.doctype.system_identifier = system_identifier
	token.doctype.missing_system_identifier = missing_system
	return parser.which_quirks_mode(token)
}

fn test_doctype_quirks_mode_classification() {
	assert quirks_mode_for_doctype('HTML', '', true) == .yes
	assert quirks_mode_for_doctype('-//W3C//DTD HTML 3.2 Final//EN', '', true) == .yes
	assert quirks_mode_for_doctype('-//W3C//DTD HTML 4.01 Transitional//EN', '', true) == .yes
	assert quirks_mode_for_doctype('-//W3C//DTD XHTML 1.0 Transitional//EN', '', true) == .limited
	assert quirks_mode_for_doctype('-//W3C//DTD HTML 4.01 Frameset//EN', 'example.dtd', false) == .limited
	assert quirks_mode_for_doctype('-//W3C//DTD HTML 4.01//EN', '', true) == .no
	assert quirks_mode_for_doctype('-//W3C//DTD HTML 4.01//EN', 'HTTP://WWW.IBM.COM/data/dtd/v11/ibmxhtml1-transitional.dtd', false) == .yes
}

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

fn test_form_end_tag_clears_the_form_element_pointer() {
	doc := parse('<body><form id="first"><input></form><form id="second"><button>go</button></form></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(form(input),form(button("go")))'
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

fn test_frameset_document() {
	doc := parse('<html><head></head><frameset><frame src="a"><frameset><frame src="b"></frameset></frameset></html>')
	assert tree_repr(html_element(doc)) == 'html(head,frameset(frame,frameset(frame)))'
}

fn test_frameset_ignores_non_frameset_content() {
	doc := parse('<frameset><div>ignored</div><frame></frameset>tail')
	assert tree_repr(html_element(doc)) == 'html(head,frameset(frame))'
}

fn test_in_body_legacy_and_void_element_rules() {
	doc := parse('<body><p>a</br>b<image src="x"><param>c<source>d<track>e</p></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(p("a",br,"b",img,param,"c",source,"d",track,"e"))'
}

fn test_ruby_implied_end_tags() {
	doc := parse('<body><ruby><rt>first<rt>second</ruby></body>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body(ruby(rt("first"),rt("second")))'
}

fn test_hidden_input_preserves_frameset_ok() {
	doc := parse('<html><head></head><input type="hidden"><frameset><frame></frameset></html>')
	assert tree_repr(html_element(doc)) == 'html(head,frameset(frame))'
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
	before := parser_non_append_insertions()
	doc := parse('<table>foo<tr><td>x</td></tr></table>')
	body := nth_child(html_element(doc), 1)
	assert tree_repr(body) == 'body("foo",table(tbody(tr(td("x")))))'
	assert parser_non_append_insertions() > before
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
	assert tmpl.content().host()?.as_node().is_same_node(template.as_node())
	assert tmpl.content().as_node().as_shadow_root() == none
	assert tmpl.content().as_node().document().created_for_appropriate_template_contents()

	cloned_node := template.as_node().clone_node(none, true, none) or { panic('${err}') }
	cloned_element := cloned_node.as_element() or { panic('template clone is not an element') }
	cloned_template := unsafe { &dom.HTMLTemplateElement(cloned_element) }
	assert cloned_element.as_node().children_as_vector().len == 0
	assert children_repr(cloned_template.content().as_node()) == 'div("x"),span("y")'
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
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_document_type(.html)
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

fn test_fragment_scripting_modes_set_script_parser_state_during_parsing() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	context := document.create_element_ns(ns_html, 'div') or { panic(err) }
	inert_nodes := parse_html_fragment_with_options(context, '<script>inert()</script>', .no, .inert)
	inert_element := inert_nodes[0].as_element() or { panic('missing inert script') }
	inert_script := unsafe { &dom.HTMLScriptElement(inert_element) }
	inert_model := html_script_element_model_for_dom_element(inert_script)
	assert inert_model.has_already_started()
	assert inert_model.is_parser_inserted()

	fragment_nodes := parse_html_fragment_with_options(context, '<script>active()</script>', .no, .fragment)
	fragment_element := fragment_nodes[0].as_element() or { panic('missing fragment script') }
	fragment_script := unsafe { &dom.HTMLScriptElement(fragment_element) }
	fragment_model := html_script_element_model_for_dom_element(fragment_script)
	assert !fragment_model.has_already_started()
	assert !fragment_model.is_parser_inserted()
}

fn test_fragment_scripting_mode_is_disabled_by_the_context_document() {
	mut enabled_document := dom.Document.create(dom.url_about_blank())
	enabled_document.set_document_type(.html)
	enabled_document.set_browsing_context(&dom.BrowsingContext{
		active_document_: enabled_document
	})
	enabled_context := enabled_document.create_element_ns(ns_html, 'div') or { panic(err) }
	enabled_nodes := parse_html_fragment_with_options(enabled_context, '<noscript><b>fallback</b></noscript>', .no, .inert)
	assert repr_nodes(enabled_nodes) == 'noscript("<b>fallback</b>")'

	mut disabled_document := dom.Document.create(dom.url_about_blank())
	disabled_document.set_document_type(.html)
	disabled_context := disabled_document.create_element_ns(ns_html, 'div') or { panic(err) }
	disabled_nodes := parse_html_fragment_with_options(disabled_context, '<noscript><b>fallback</b></noscript>', .no, .fragment)
	assert repr_nodes(disabled_nodes) == 'noscript(b("fallback"))'
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

fn test_standard_document_parse_entry_point_uses_html_parser() {
	mut doc := dom.Document.create(dom.url_about_blank())
	install_document_fragment_parsing_hook(doc)
	doc.parse_html_from_a_string('<!DOCTYPE html><title>DOM parser</title><main>x</main>')
	html_el := doc.document_element() or { panic('no document element') }
	assert tree_repr(html_el.as_node()) == 'html(head(title("DOM parser")),body(main("x")))'
}

fn test_dom_xml_fragment_entry_point_uses_xml_parser() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	install_document_fragment_parsing_hook(document)
	mut context := document.create_element_ns('urn:default', 'context')!
	context.set_attribute_ns_for_bindings('http://www.w3.org/2000/xmlns/', 'xmlns:q', 'urn:child')!
	fragment := context.parse_fragment('<q:item>ok</q:item>')!
	item := fragment.as_node().first_child()?.as_element() or { panic('missing XML item') }
	assert item.local_name() == 'item'
	assert item.namespace_uri()? == 'urn:child'
	assert item.as_node().text_content()? == 'ok'
	if _ := context.parse_fragment('<a></b>') {
		assert false
	} else {
		assert err.str().contains('SyntaxError')
	}
}

fn test_parser_creation_with_uncertain_encoding_decodes_sniffed_bytes() {
	mut bytes := '<meta charset="windows-1252"><p>'.bytes()
	bytes << u8(0x80)
	bytes << '</p>'.bytes()
	doc := dom.Document.create(dom.url_about_blank())
	mut parser := HTMLParser.create_with_uncertain_encoding(doc, bytes, none) or { panic('${err}') }
	parser.run()
	assert doc.get_encoding()? == 'windows-1252'
	assert doc.body()?.as_node().descendant_text_content() == '€'
}

fn test_run_until_completion_processes_eof_and_finishes_the_document() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parser := HTMLParser.create(doc, '<title>Complete</title><main>done</main>')
	parser.run_until_completion()
	assert parser.stopped()
	assert doc.ready_state() == 'complete'
	assert doc.title() == 'Complete'
	assert doc.body()?.as_node().descendant_text_content() == 'done'
}

fn test_option_pop_updates_selectedcontent_after_buffered_text_flush() {
	mut doc := parse('<select><button><selectedcontent></selectedcontent></button><option selected><b>Chosen</b></option></select>')
	selectedcontent := doc.get_elements_by_tag_name('selectedcontent').item(0) or {
		panic('missing selectedcontent')
	}
	assert selectedcontent.as_node().descendant_text_content() == 'Chosen'
}

fn test_document_open_write_writeln_and_close_use_live_html_parser() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_document_type(.html)
	install_document_fragment_parsing_hook(doc)
	doc.open_document() or { panic('${err}') }
	doc.write_strings(['<title>Written</title><main>one']) or { panic('${err}') }
	doc.writeln_strings([' + two</main>']) or { panic('${err}') }

	// Each write runs only as far as the tokenizer insertion point. Closing the
	// stream inserts explicit EOF and finishes tree construction.
	doc.close() or { panic('${err}') }
	html_el := doc.document_element() or { panic('no document element') }
	assert tree_repr(html_el.as_node()) == 'html(head(title("Written")),body(main("one + two"),"\n"))'
}

fn test_document_close_only_closes_script_created_parsers() {
	mut network_document := dom.Document.create(dom.url_about_blank())
	mut network_parser := HTMLParser.create_with_open_input_stream(network_document)
	assert !network_parser.is_script_created()
	assert !network_parser.tokenizer.is_input_stream_closed()
	network_document.close() or { panic(err) }
	assert !network_parser.tokenizer.is_input_stream_closed()
	assert !network_parser.tokenizer.is_eof_inserted()

	mut script_document := dom.Document.create(dom.url_about_blank())
	mut script_parser := HTMLParser.create_for_scripting(script_document)
	assert script_parser.is_script_created()
	assert !script_parser.tokenizer.is_input_stream_closed()
	script_document.close() or { panic(err) }
	assert script_parser.tokenizer.is_input_stream_closed()
	assert script_parser.tokenizer.is_eof_inserted()
}

fn test_declarative_shadow_roots_respect_parser_permission() {
	disallowed_document := dom.Document.create(dom.url_about_blank())
	parse_html_from_a_string(disallowed_document, '<div id="host"><template shadowrootmode="open"><span>shadow</span></template></div>')
	disallowed_host := disallowed_document.get_element_by_id('host') or { panic('missing host') }
	assert disallowed_host.shadow_root() == none
	assert disallowed_host.as_node().first_child()?.as_element()?.local_name() == 'template'

	allowed_document := parse_document('<div id="host"><template shadowrootmode="open"><span>shadow</span></template></div>')
	allowed_host := allowed_document.get_element_by_id('host') or { panic('missing host') }
	shadow := allowed_host.shadow_root() or { panic('missing declarative shadow root') }
	assert shadow.declarative()
	assert shadow.as_node().as_shadow_root()? == shadow
	assert shadow.as_node().descendant_text_content() == 'shadow'
	assert allowed_host.as_node().first_child() == none
}

fn test_set_inner_html_replaces_children() {
	// div.innerHTML = ... : the div's existing children are replaced by the parsed fragment.
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_document_type(.html)
	mut div := doc.create_element_ns(ns_html, 'div') or { panic('div') }
	mut div_node := div.as_node()
	div_node.append_child(doc.create_text_node('old').as_node()) or {}
	assert children_repr(div_node) == '"old"'

	set_inner_html(div, '<span>a</span><span>b</span>')
	assert children_repr(div_node) == 'span("a"),span("b")'

	// The same translated parser is installed behind the standard DOM API.
	div.set_inner_html('<em>through DOM</em>') or { panic('${err}') }
	assert children_repr(div_node) == 'em("through DOM")'
	assert (div.inner_html() or { panic('${err}') }) == '<em>through DOM</em>'
	assert (div.outer_html() or { panic('${err}') }) == '<div><em>through DOM</em></div>'
}

fn test_shadow_root_inner_html_invalidates_only_its_layout_subtree() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	install_document_fragment_parsing_hook(document)
	mut host := document.create_element_ns(ns_html, 'div') or { panic('host') }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic('${err}') }
	mut shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or {
		panic('${err}')
	}

	// Discard invalidation caused by connecting the host and attaching the root.
	mut host_node := host.as_node()
	mut shadow_node := dom.shadow_root_as_node(shadow_root)
	document.set_needs_full_layout_tree_update(false)
	document_node.set_needs_layout_tree_update(false, .style_change)
	document_node.set_child_needs_layout_tree_update(false)
	host_node.set_needs_layout_tree_update(false, .style_change)
	host_node.set_child_needs_layout_tree_update(false)
	shadow_node.set_needs_layout_tree_update(false, .style_change)
	shadow_node.set_child_needs_layout_tree_update(false)

	shadow_root.set_inner_html('<span>updated</span>')!

	assert !document.needs_full_layout_tree_update()
	assert shadow_node.needs_layout_tree_update_()
	assert host_node.needs_layout_tree_update_()
	assert dom.set_needs_layout_tree_update_reason_to_string(.shadow_root_set_inner_html) == 'ShadowRootSetInnerHTML'
}

fn test_html_fragment_serialization_node_kinds_and_raw_text() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_document_type(.html)
	mut div := doc.create_element_ns(ns_html, 'div') or { panic('div') }
	div.set_attribute_value('title', 'a&"b')
	mut div_node := div.as_node()
	div_node.append_child(doc.create_comment('marker').as_node()) or {}
	mut script := doc.create_element_ns(ns_html, 'script') or { panic('script') }
	mut script_node := script.as_node()
	script_node.append_child(doc.create_text_node('if (a < b && c > d) {}').as_node()) or {}
	div_node.append_child(script.as_node()) or {}

	assert (div.outer_html() or { panic('${err}') }) == '<div title="a&amp;&quot;b"><!--marker--><script>if (a < b && c > d) {}</script></div>'
}

fn test_cdata_sections_are_text_only_in_foreign_content() {
	document := parse_document('<svg><![CDATA[foo]]></svg><math><![CDATA[a<b]]></math><div><![CDATA[x]]></div>')
	body := document.body() or { panic('missing body') }
	children := body.as_node().children
	svg_text := children[0].first_child() or { panic('missing svg child') }
	assert svg_text.is_text()
	assert svg_text.text_content() or { '' } == 'foo'
	math_text := children[1].first_child() or { panic('missing math child') }
	assert math_text.is_text()
	assert math_text.text_content() or { '' } == 'a<b'
	comment := children[2].first_child() or { panic('missing div child') }
	assert comment.is_comment()
}

fn test_cdata_sections_are_not_allowed_in_integration_points() {
	document := parse_document('<svg><foreignObject>x<![CDATA[y]]></foreignObject><desc>x<![CDATA[y]]></desc></svg><math><mi>x<![CDATA[y]]></mi></math>')
	body := document.body() or { panic('missing body') }
	svg := body.as_node().children[0]
	for container in [svg.children[0], svg.children[1], body.as_node().children[1].children[0]] {
		assert container.children.len == 2
		assert container.children[1].is_comment()
	}
}

