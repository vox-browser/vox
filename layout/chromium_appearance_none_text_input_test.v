module layout

import html

fn test_chromium_unthemed_text_controls_keep_intrinsic_sizing_and_clamped_placeholder_geometry() {
	for type_ in ['text', 'search', 'tel', 'url', 'email', 'password', 'number', 'unknown'] {
		mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { appearance:none; box-sizing:border-box; border:0; padding:16px 0;
			font:500 14px/48px Arial; width:280px; min-height:48px; max-height:48px }
		</style><input id="search" type="${type_}" placeholder="Search for and select places">')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout') }
		element := document.get_element_by_id('search')?
		bridge := element.as_node().layout_node()?
		input := unsafe { &Node(bridge.layout_handle) }
		assert input.is_text_input_box(), type_
		input_style := input.as_node_with_style()?
		used := result.used_values_for(input_style)?
		assert used.has_definite_height(), type_
		assert used.content_height().to_double() == 16, type_
		outer := input.first_child()?
		outer_style := outer.as_node_with_style()?
		outer_used := result.used_values_for(outer_style)?
		assert outer_used.content_height().to_double() == 16, type_
		// Number controls place the editor and placeholder in another flex item.
		text_container := if type_ == 'number' { outer.first_child()? } else { outer }
		placeholder := text_container.children()[1]
		placeholder_style := placeholder.as_node_with_style()?
		placeholder_used := result.used_values_for(placeholder_style)?
		mut placeholder_y := placeholder_used.offset.y().to_double()
		if type_ == 'number' {
			text_style := text_container.as_node_with_style()?
			text_used := result.used_values_for(text_style)?
			placeholder_y += text_used.offset.y().to_double()
		}
		assert placeholder_y == 0, type_
	}
}

fn test_libweb_unthemed_input_keeps_the_generic_display_box() {
	mut document := html.parse_document('<!doctype html><input id="input" style="appearance:none">')
	defer { document.finalize() }
	_ = run_document_layout(document, 800, 600)?
	element := document.get_element_by_id('input')?
	bridge := element.as_node().layout_node()?
	assert !unsafe { &Node(bridge.layout_handle) }.is_text_input_box()
}

// Brave 156: GitHub's "Go to file" input (20px line, 28px content box from flex
// stretch) puts the editor at 4px and the placeholder's 17px line at 5px, so
// both share the editor's baseline rather than centering independently (5.5px).
fn test_chromium_text_control_placeholder_shares_the_editor_baseline() {
	$if !macos {
		return
	}
	for case_ in [['', '4', '5'], ['height:30px;', '4', '5'], ['height:32px;', '5', '6']] {
		mut document := html.parse_document('<!doctype html><style>
		body{margin:0}#w{display:flex;min-height:32px;font:14px/20px system-ui;border:1px solid #ccc;width:204px;box-sizing:border-box}
		input{appearance:none;font-family:inherit;font-size:inherit;line-height:inherit;border:0;width:100%;padding:1px 0;outline:0;box-sizing:border-box;${case_[0]}}
		</style><span id="w"><input id="in" placeholder="Go to file"></span>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 400, 300) or { panic('layout') }
		element := document.get_element_by_id('in') or { panic('element') }
		bridge := element.as_node().layout_node() or { panic('bridge') }
		input := unsafe { &Node(bridge.layout_handle) }
		container := input.first_child() or { panic('container') }
		editor := container.children()[0]
		placeholder := container.children()[1]
		editor_used := result.used_values_for(editor.as_node_with_style() or { panic('editor style') }) or { panic('editor used') }
		placeholder_used := result.used_values_for(placeholder.as_node_with_style() or { panic('placeholder style') }) or { panic('placeholder used') }
		assert editor_used.offset.y().to_double() == case_[1].f64(), case_[0]
		assert placeholder_used.offset.y().to_double() == case_[2].f64(), case_[0]
	}
}
