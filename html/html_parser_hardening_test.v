module html

// Hardening suite of tricky html5lib-style tree-construction cases (adoption agency furthest-block
// paths, foster parenting + reconstruction, implied end tags, raw text, foreign content). Each
// expected tree is the WHATWG-correct result. These exercise paths the basic parser tests do not.

import dom

// element -> local_name(child,...); text -> "data". (Each _test.v is compiled separately, so this
// cannot share tree_repr with html_parser_test.v.)
fn hardening_repr(node &dom.Node) string {
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
				parts << hardening_repr(k)
			}
			out += '(' + parts.join(',') + ')'
		}
		return out
	}
	if node.is_text() {
		return '"' + node_as_text(node).data() + '"'
	}
	return node.node_name()
}

fn body_repr(markup string) string {
	doc := parse_document(markup)
	html_el := doc.document_element() or { return '?' }
	kids := html_el.as_node().children_as_vector()
	// Serialize the <body> (second child of <html>, after <head>).
	if kids.len < 2 {
		return hardening_repr(html_el.as_node())
	}
	return hardening_repr(kids[1])
}

fn test_adoption_agency_furthest_block_a_in_p() {
	// The <p> is the furthest block for the outer <a>; the adoption agency clones <a> into it.
	assert body_repr('<a><p>X<a>Y</a>Z</p></a>') == 'body(a,p(a("X"),a("Y"),"Z"))'
}

fn test_adoption_agency_b_across_p() {
	assert body_repr('<b>1<p>2</b>3</p>') == 'body(b("1"),p(b("2"),"3"))'
}

fn test_adoption_agency_a_button() {
	assert body_repr('<a href="a">1<button>2</a>3</button>') == 'body(a("1"),button(a("2"),"3"))'
}

fn test_adoption_agency_nested_formatting() {
	assert body_repr('<p>1<b>2<i>3</b>4</i>5</p>') == 'body(p("1",b("2",i("3")),i("4"),"5"))'
}

fn test_adoption_agency_double() {
	assert body_repr('<i>a<b>b</i>c</b>d') == 'body(i("a",b("b")),b("c"),"d")'
}

fn test_formatting_reconstruct_after_block_close() {
	assert body_repr('<p><b>1</p>2') == 'body(p(b("1")),b("2"))'
}

fn test_block_in_formatting() {
	assert body_repr('<b><p>bold</p></b>') == 'body(b(p("bold")))'
}

fn test_misnested_b_i() {
	assert body_repr('<b><i></b></i>x') == 'body(b(i),"x")'
}

fn test_stray_end_p_creates_empty_p() {
	assert body_repr('<p>a</p></p>b') == 'body(p("a"),p,"b")'
}

fn test_div_closes_open_p() {
	assert body_repr('<div><p>a</div>b') == 'body(div(p("a")),"b")'
}

fn test_headings_close_each_other() {
	assert body_repr('<h1>a<h2>b</h1>c') == 'body(h1("a"),h2("b"),"c")'
}

fn test_nested_lists() {
	assert body_repr('<ul><li>1<ul><li>2</ul></li></ul>') == 'body(ul(li("1",ul(li("2")))))'
}

fn test_dd_dt_auto_close() {
	assert body_repr('<dd>a<dt>b<dd>c') == 'body(dd("a"),dt("b"),dd("c"))'
}

fn test_plaintext_consumes_rest_as_text() {
	assert body_repr('<plaintext><b>not a tag</b>') == 'body(plaintext("<b>not a tag</b>"))'
}

fn test_table_foster_misnested_formatting() {
	assert body_repr('<table><b><tr><td>aaa</td></tr>bbb</table>ccc') == 'body(b,b("bbb"),table(tbody(tr(td("aaa")))),b("ccc"))'
}

fn test_table_foster_text_merges() {
	assert body_repr('<b>1<table>2<td>3</td></table>4</b>') == 'body(b("12",table(tbody(tr(td("3")))),"4"))'
}

fn test_implicit_table_wrappers() {
	assert body_repr('<div><table><td>x</table></div>') == 'body(div(table(tbody(tr(td("x"))))))'
}

fn test_character_references_in_text() {
	assert body_repr('a&amp;b &lt; c') == 'body("a&b < c")'
}
