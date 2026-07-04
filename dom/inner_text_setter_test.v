module dom

const its_html_ns = 'http://www.w3.org/1999/xhtml'

fn its_element(tag string) &Element {
	doc := Document.create(url_about_blank())
	return doc.create_element_ns(its_html_ns, tag) or { panic('${err}') }
}

// A compact description of an element's children: `text:<data>` for a Text node, `<br>` for a br
// element, and `<tag>` for any other element.
fn its_child_kinds(el &Element) []string {
	mut kinds := []string{}
	for child in el.as_node().children_as_vector() {
		if child.is_text() {
			kinds << 'text:' + unsafe { &Text(child) }.data()
		} else if element := child.as_element() {
			kinds << '<' + element.local_name() + '>'
		} else {
			kinds << '?'
		}
	}
	return kinds
}

// Plain text with no line breaks becomes a single Text node.
fn test_set_inner_text_plain() {
	mut el := its_element('div')
	el.set_inner_text('hello world')
	assert its_child_kinds(el) == ['text:hello world']
}

// A LF splits the text into Text nodes separated by a <br>.
fn test_set_inner_text_newline_makes_br() {
	mut el := its_element('div')
	el.set_inner_text('a\nb')
	assert its_child_kinds(el) == ['text:a', '<br>', 'text:b']
}

// A CRLF pair counts as a single line break (one <br>).
fn test_set_inner_text_crlf_is_one_break() {
	mut el := its_element('div')
	el.set_inner_text('x\r\ny')
	assert its_child_kinds(el) == ['text:x', '<br>', 'text:y']
}

// Consecutive line breaks each produce their own <br>, and a leading break makes a leading <br>.
fn test_set_inner_text_multiple_and_leading_breaks() {
	mut el := its_element('div')
	el.set_inner_text('\na\n\nb')
	assert its_child_kinds(el) == ['<br>', 'text:a', '<br>', '<br>', 'text:b']
}

// Setting innerText replaces any existing children.
fn test_set_inner_text_replaces_children() {
	mut el := its_element('div')
	mut node := unsafe { &Node(el) }
	old := its_element('span')
	node.append_child(old.as_node()) or { panic('${err}') }
	assert its_child_kinds(el) == ['<span>']

	el.set_inner_text('fresh')
	assert its_child_kinds(el) == ['text:fresh']
}
