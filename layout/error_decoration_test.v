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

fn test_typed_document_paint_preserves_computed_background_image_layers() {
	document := dom.Document.create(dom.url_about_blank())
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut body := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic(err)
	}
	mut sprite := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	sprite.set_attribute_value('style', 'width: 32px; height: 32px; background-image: url("sprite.png"); background-repeat: no-repeat; background-position: -4px -8px')
	mut body_node := body.as_node()
	body_node.append_child(sprite.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(body.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }

	box := layout_document_typed_in_viewport(document, 800, 600)
	commands := box.paint_commands().filter(it.kind == 'draw_background_image')
	assert commands.len == 1
	assert commands[0].image_url.ends_with('sprite.png')
	assert commands[0].image_repeat_x == 'no-repeat'
	assert commands[0].image_repeat_y == 'no-repeat'
	assert commands[0].image_position_x == '-4px'
	assert commands[0].image_position_y == '-8px'

	mut computed := css.ComputedProperties.new()
	computed.set_property_without_modifying_flags(.background_image, &dom.StyleValue{
		css_text: 'url("sprite.png")'
		base_url: 'https://example.test/assets/site.css'
	})
	layers := computed_background_image_layers(sprite, computed)
	assert layers.len == 1
	assert layers[0].url == 'https://example.test/assets/sprite.png'
}

fn test_typed_document_paints_replaced_image_content() {
	document := dom.Document.create(dom.url_about_blank())
	mut html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic(err)
	}
	mut body := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic(err)
	}
	mut image := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img') or {
		panic(err)
	}
	image.set_attribute_value('src', 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAF/gL+X9HkWQAAAABJRU5ErkJggg==')
	image.set_attribute_value('style', 'width: 12px; height: 8px; object-fit: contain; object-position: 25% 75%')
	mut body_node := body.as_node()
	body_node.append_child(image.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(body.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }

	box := layout_document_typed_in_viewport(document, 800, 600)
	commands := box.paint_commands().filter(it.kind == 'draw_background_image')
	assert commands.len == 1
	assert commands[0].image_url.starts_with('data:image/png')
	assert commands[0].image_size == 'contain'
	assert commands[0].image_position_x == '25%'
	assert commands[0].image_position_y == '75%'
}

fn test_typed_document_paints_inline_backgrounds_and_native_checkboxes() {
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
	mut badge := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut checkbox := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic(err)
	}
	badge.set_attribute_value('class', 'badge')
	mut badge_node := badge.as_node()
	badge_node.append_child(document.create_text_node('join').as_node()) or { panic(err) }
	checkbox.set_attribute_value('type', 'checkbox')
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node('.badge { background-image: url("sprite.png"); background-position: -3px -4px; background-repeat: no-repeat; }').as_node()) or {
		panic(err)
	}
	mut head_node := head.as_node()
	head_node.append_child(style.as_node()) or { panic(err) }
	mut body_node := body.as_node()
	body_node.append_child(badge.as_node()) or { panic(err) }
	body_node.append_child(checkbox.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(head.as_node()) or { panic(err) }
	html_node.append_child(body.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }

	box := layout_document_typed_in_viewport(document, 800, 600)
	images := box.paint_commands().filter(it.kind == 'draw_background_image')
	assert images.len == 1
	assert images[0].image_url.ends_with('sprite.png')
	assert images[0].image_position_x == '-3px'
	assert images[0].image_position_y == '-4px'
	assert box.paint_commands().any(it.kind == 'fill_rect' && it.color == 'rgb(255 255 255)' && it.width > 0 && it.height > 0)
}
