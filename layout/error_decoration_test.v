module layout

import css
import dom

fn test_error_decoration_shorthands_reach_the_paint_pipeline() {
	document := dom.Document.create(dom.url_about_blank())
	for decoration, expected_color in {
		'spelling-error': 'rgb(255 0 0)'
		'grammar-error':  'rgb(0 100 0)'
	} {
		mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or {
			panic(err)
		}
		element.set_attribute_value('style', 'text-decoration: ${decoration}')
		mut node := element.as_node()
		node.append_child(document.create_text_node('mistake').as_node()) or { panic(err) }
		box := layout_block(element, 0, 0, 800, []&css.CSSRule{})
		assert box.lines.len == 1
		assert box.lines[0].fragments[0].decoration == decoration
		commands := box.paint_commands().filter(it.kind == 'fill_polygon')
		assert commands.len > 1
		assert commands.all(it.color == expected_color)
	}
}

fn test_error_decoration_shorthands_reach_layout_from_author_rules() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or {
		panic(err)
	}
	element.set_attribute_value('class', 'spelling-error')
	mut node := element.as_node()
	node.append_child(document.create_text_node('mistake').as_node()) or { panic(err) }
	rules := css.parse_css_stylesheet_contents_with_parser('.spelling-error { text-decoration: spelling-error; }',
		map[string]bool{})
	box := layout_block(element, 0, 0, 800, rules)
	assert box.lines[0].fragments[0].decoration == 'spelling-error'
	commands := box.paint_commands().filter(it.kind == 'fill_polygon')
	assert commands.len > 1
	assert commands.all(it.color == 'rgb(255 0 0)')
}

fn test_typed_document_paint_preserves_error_decoration_lines() {
	document := dom.Document.create(dom.url_about_blank())
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut head := document.create_element_ns('http://www.w3.org/1999/xhtml', 'head') or {
		panic(err)
	}
	mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or {
		panic(err)
	}
	mut body := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic(err)
	}
	mut spelling := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or {
		panic(err)
	}
	spelling.set_attribute_value('class', 'spelling-error')
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node('.spelling-error { text-decoration: spelling-error; }').as_node()) or {
		panic(err)
	}
	mut spelling_node := spelling.as_node()
	spelling_node.append_child(document.create_text_node('mistake').as_node()) or { panic(err) }
	mut head_node := head.as_node()
	head_node.append_child(style.as_node()) or { panic(err) }
	mut body_node := body.as_node()
	body_node.append_child(spelling.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(head.as_node()) or { panic(err) }
	html_node.append_child(body.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }

	box := layout_document_typed_in_viewport(document, 800, 600)
	commands := box.paint_commands().filter(it.kind == 'fill_polygon'
		&& it.color == 'rgb(255 0 0)')
	assert commands.len > 1
}
