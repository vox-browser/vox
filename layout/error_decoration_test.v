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
		commands := box.paint_commands().filter(it.kind == 'draw_svg_path')
		assert commands.len == 1
		assert commands[0].stroke_color == expected_color
		assert commands[0].stroke_width == 1
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
	rules := css.parse_css_stylesheet_contents_with_parser('.spelling-error { text-decoration: spelling-error; }', map[string]bool{})
	box := layout_block(element, 0, 0, 800, rules)
	assert box.lines[0].fragments[0].decoration == 'spelling-error'
	commands := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	assert commands[0].stroke_color == 'rgb(255 0 0)'
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
	commands := box.paint_commands().filter(it.kind == 'draw_svg_path'
		&& it.stroke_color == 'rgb(255 0 0)')
	assert commands.len == 1
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
	sprite.set_attribute_value('style', 'width: 100px; height: 50px; background-image: url("sprite.png"); background-repeat: round space; background-size: 30px auto; background-position: 25% 50%; background-blend-mode: multiply')
	mut body_node := body.as_node()
	body_node.append_child(sprite.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(body.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }

	box := layout_document_typed_in_viewport(document, 800, 600)
	all_commands := box.paint_commands()
	commands := all_commands.filter(it.kind == 'draw_background_image')
	assert commands.len == 1
	assert commands[0].image_url.ends_with('sprite.png')
	assert commands[0].image_repeat_x == 'round'
	assert commands[0].image_repeat_y == 'space'
	assert commands[0].image_size == '30px auto'
	assert commands[0].image_position_x == '25%'
	assert commands[0].image_position_y == '50%'
	retained_layer := commands[0].image_computed_layer or {
		panic('typed background layer was flattened to renderer strings')
	}
	assert retained_layer.repeat_x == .round
	assert retained_layer.repeat_y == .space
	assert retained_layer.blend_mode == .multiply
	assert commands[0].background_blend_mode == .multiply
	assert !retained_layer.size_x.is_auto()
	assert retained_layer.size_y.is_auto()
	assert retained_layer.position_x.to_px(commands[0].image_resolution_context, css.CSSPixels.nearest_value_for(100)).to_double() == 25
	assert retained_layer.position_y.to_px(commands[0].image_resolution_context, css.CSSPixels.nearest_value_for(100)).to_double() == 50
	mut group_begin := -1
	mut image_index := -1
	mut group_end := -1
	for index, command in all_commands {
		match command.kind {
			'begin_background_blend_group' {
				group_begin = index
			}
			'draw_background_image' {
				image_index = index
			}
			'end_background_blend_group' {
				group_end = index
			}
			else {}
		}
	}
	assert group_begin >= 0
	assert group_begin < image_index
	assert image_index < group_end
	svg := box.render_svg(800, 600)
	assert svg.contains('<g style="isolation:isolate">')
	assert svg.contains('style="mix-blend-mode:multiply"')

	mut computed := css.ComputedProperties.new()
	computed.set_property_without_modifying_flags(.background_image, &dom.StyleValue{
		css_text: 'url("sprite.png")'
		base_url: 'https://example.test/assets/site.css'
	})
	layers := computed_background_image_layers(sprite, computed, css.ColorResolutionContext{
		current_color: css.Color{0, 0, 0, 255}
	})
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
	commands := box.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	assert commands[0].image_url.starts_with('data:image/png')
	assert commands[0].image_size == 'contain'
	assert commands[0].image_position_x == '25%'
	assert commands[0].image_position_y == '75%'
	paintable := commands[0].image_paintable or { panic('missing retained ImagePaintable') }
	assert paintable.object_fit == .contain
	assert paintable.object_position.offset_x.to_px(paintable.resolution_context, css.CSSPixels.new(100)).to_double() == 25
	assert paintable.object_position.offset_y.to_px(paintable.resolution_context, css.CSSPixels.new(100)).to_double() == 75
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
	assert box.paint_commands().any(it.kind == 'fill_rounded_rect'
		&& it.color == 'rgb(255 255 255)' && it.width > 0 && it.height > 0)
}
