module layout

import css
import dom
import html
import platform

fn test_pretty_and_balance_do_not_wrap_fractionally_spaced_max_content_text() {
	font_path := platform.document_font_path(400) or { panic('fixture font') }
	for wrap in ['pretty', 'balance'] {
		for spacing in ['0.17px', '0.860448px', '-0.23px'] {
			for text in ['Shirin Ali', '\n  Shirin Ali\n ', 'Jim Newell', 'AV To Wa'] {
				mut document := html.parse_document('<!doctype html><style>@font-face{font-family:Fixture;src:url("file://${font_path}")}#label{display:inline-block;width:max-content;font:12.29px Fixture;letter-spacing:${spacing};text-transform:uppercase;text-wrap:${wrap}}</style><div id="label">${text}</div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(.chromium)
				_ = layout_document_typed_in_viewport(document, 800, 600)
				result := document_layout_result(document) or { panic('layout') }
				element := document.get_element_by_id('label') or { panic('label') }
				bridge := element.as_node().layout_node() or { panic('bridge') }
				node := unsafe { &Node(bridge.real_layout_handle()) }
				used := result.state.try_get(node.as_node_with_style() or { panic('style') }) or { panic('used') }
				assert used.line_boxes.len == 1, '${wrap} ${spacing} ${text.trim_space()}'
			}
		}
	}
}

fn wrap_copy_lines(text string, declaration string, width int, mode LayoutMode) ([]string, []f64) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	element.set_attribute_value('style', 'display:block;font:12px/16px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;${declaration}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node(text)
	container.append_child(unsafe { &Node(TextNode.new(document, dom_text.as_node(), text)) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(width))
	run_inline_formatting_context(mut state, container, mut used, mode,
		AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite()))
	assert used.content_width().to_double() == width
	mut lines := []string{}
	mut offsets := []f64{}
	for line in used.line_boxes {
		mut content := ''
		for fragment in line.fragments_ { content += fragment.text() or { '' } }
		lines << content.trim_space()
		offsets << if line.fragments_.len > 0 {
			line.fragments_[0].offset().x().to_double()
		} else {
			0.0
		}
	}
	return lines, offsets
}

fn test_balance_heading_uses_native_advances_and_keeps_alignment_width() {
	$if !macos {
		return
	}
	text := 'Get responses tailored to you'
	declaration := 'font:600 16px/24px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;text-wrap:balance'
	lines, _ := wrap_copy_lines(text, declaration, 220, .normal)
	assert lines == ['Get responses', 'tailored to you']
	break_word_lines, _ := wrap_copy_lines(text, '${declaration};overflow-wrap:break-word', 220, .normal)
	assert break_word_lines == lines
	centered, offsets := wrap_copy_lines(text, '${declaration};text-align:center', 220, .normal)
	assert centered == lines
	assert offsets[0] > 50 && offsets[0] < 60
	assert offsets[1] > 50 && offsets[1] < 60
	greedy, _ := wrap_copy_lines(text, 'font:600 16px/24px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;text-wrap:wrap', 220, .normal)
	assert greedy == ['Get responses tailored to', 'you']
}

fn test_pretty_moves_words_off_an_orphan_final_line() {
	$if !macos {
		return
	}
	text := 'Log in to get answers based on saved chats, plus create images and upload files.'
	lines, _ := wrap_copy_lines(text, 'text-wrap:pretty', 220, .normal)
	assert lines == ['Log in to get answers based on', 'saved chats, plus create images and',
		'upload files.']
	greedy, _ := wrap_copy_lines(text, 'text-wrap:wrap', 220, .normal)
	assert greedy == ['Log in to get answers based on saved', 'chats, plus create images and upload',
		'files.']
}

fn test_unsupported_and_intrinsic_wrapping_keeps_existing_breaker() {
	$if !macos {
		return
	}
	text := 'Get responses tailored to you'
	base := 'font:600 16px/24px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;'
	for extra in ['white-space:nowrap', 'white-space:pre', 'text-indent:10px', 'overflow-wrap:anywhere'] {
		optimized, _ := wrap_copy_lines(text, '${base}text-wrap:balance;${extra}', 220, .normal)
		ordinary, _ := wrap_copy_lines(text, '${base}text-wrap:wrap;${extra}', 220, .normal)
		assert optimized == ordinary
	}
	intrinsic, _ := wrap_copy_lines(text, '${base}text-wrap:balance', 220, .intrinsic_sizing)
	ordinary, _ := wrap_copy_lines(text, '${base}text-wrap:wrap', 220, .intrinsic_sizing)
	assert intrinsic == ordinary
}

fn test_overflow_word_breaking_still_handles_words_wider_than_the_available_line() {
	$if !macos { return }
	text := 'a verylongwordthatmustbreakatthenarrowline follows'
	base := 'overflow-wrap:break-word;'
	balanced, _ := wrap_copy_lines(text, base+'text-wrap:balance', 50, .normal)
	ordinary, _ := wrap_copy_lines(text, base+'text-wrap:wrap', 50, .normal)
	assert balanced == ordinary
}
