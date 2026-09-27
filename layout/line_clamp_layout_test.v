module layout

import css
import dom
import html

struct LineClampTestResult {
	lines           []LineBox
	height          CSSPixels
	has_clamp_point bool
}

fn line_clamp_test_style(document &dom.Document, declarations string) &css.ComputedProperties {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', declarations)
	return css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
}

fn run_line_clamp_test(document &dom.Document, declarations string,
	available_height AvailableSize) LineClampTestResult {
	style := line_clamp_test_style(document, declarations)
	break_style := line_clamp_test_style(document, 'display:inline; font:20px/24px monospace')
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	for index, text in ['first', 'second', 'hidden'] {
		dom_text := document.create_text_node(text)
		text_node := TextNode.new(document, dom_text.as_node(), text)
		container.append_child(unsafe { &Node(text_node) })
		if index < 2 {
			mut break_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic('${err}') }
			break_node := BreakNode.new(document, break_element.as_node(), break_style)
			container.append_child(unsafe { &Node(break_node) })
		}
	}
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(240))
	result := run_inline_formatting_context(mut state, container, mut used, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(240)), available_height))
	return LineClampTestResult{
		lines: used.line_boxes.clone()
		height: result.automatic_content_height
		has_clamp_point: used.has_line_clamp_point()
	}
}

fn test_standard_line_clamp_adds_the_selected_block_ellipsis() {
	document := dom.Document.create(dom.url_about_blank())
	automatic := run_line_clamp_test(document, 'display:block; line-clamp:2; font:20px/24px monospace', AvailableSize.make_indefinite())
	assert automatic.has_clamp_point
	assert automatic.lines.len == 2
	assert automatic.height.to_double() == 48
	assert automatic.lines.last().fragments_.last().is_block_ellipsis()
	assert automatic.lines.last().fragments_.last().text()? == '…'
	assert automatic.lines.last().fragments_.last().length_in_code_units() == 1
	assert automatic.lines.last().fragments_.last().start() == 6
	assert layout_nodes_same(automatic.lines.last().fragments_[0].layout_node(), automatic.lines.last().fragments_.last().layout_node())

	without := run_line_clamp_test(document, 'display:block; line-clamp:2 no-ellipsis; font:20px/24px monospace', AvailableSize.make_indefinite())
	assert without.lines.len == 2
	assert !without.lines.last().fragments_.last().is_block_ellipsis()

	custom := run_line_clamp_test(document, 'display:block; line-clamp:2 "++"; font:20px/24px monospace', AvailableSize.make_indefinite())
	assert custom.lines.len == 2
	assert custom.lines.last().fragments_.last().is_block_ellipsis()
	assert custom.lines.last().fragments_.last().text()? == '++'

	unspaced_words := run_line_clamp_test(document, 'display:block; line-clamp:2 "x x"; font:20px/24px monospace', AvailableSize.make_indefinite())
	spaced_words := run_line_clamp_test(document, 'display:block; line-clamp:2 "x x"; font:20px/24px monospace; word-spacing:6px', AvailableSize.make_indefinite())
	unspaced_ellipsis := unspaced_words.lines.last().fragments_.last()
	spaced_ellipsis := spaced_words.lines.last().fragments_.last()
	assert spaced_ellipsis.inline_length().to_double() == unspaced_ellipsis.inline_length().to_double() + 6
}

fn test_line_clamp_auto_uses_the_definite_block_size() {
	document := dom.Document.create(dom.url_about_blank())
	result := run_line_clamp_test(document, 'display:block; line-clamp:auto; font:20px/24px monospace', AvailableSize.make_definite(CSSPixels.new(48)))
	assert result.has_clamp_point
	assert result.lines.len == 2
	assert result.lines.last().fragments_.last().text()? == '…'
}

fn test_webkit_line_clamp_only_activates_for_a_vertical_legacy_box() {
	document := dom.Document.create(dom.url_about_blank())
	vertical := run_line_clamp_test(document, 'display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:2; font:20px/24px monospace', AvailableSize.make_indefinite())
	assert vertical.lines.len == 2
	assert vertical.has_clamp_point

	horizontal := run_line_clamp_test(document, 'display:-webkit-box; -webkit-box-orient:horizontal; -webkit-line-clamp:2; font:20px/24px monospace', AvailableSize.make_indefinite())
	assert horizontal.lines.len == 3
	assert !horizontal.has_clamp_point
}

fn test_continue_collapse_and_discard_establish_independent_formatting_contexts() {
	document := dom.Document.create(dom.url_about_blank())
	for value in ['collapse', 'discard'] {
		style := line_clamp_test_style(document, 'display:block; continue:${value}')
		box := BlockContainer.new(document, none, style)
		styled := unsafe { &Node(box) }.as_node_with_style() or { panic('style') }
		assert creates_block_formatting_context(styled), value
	}
}

fn test_line_clamp_counts_descendant_in_flow_line_boxes_across_block_children() {
	document := dom.Document.create(dom.url_about_blank())
	root_style := line_clamp_test_style(document, 'display:block; line-clamp:2 "!"; font:20px/24px monospace')
	mut root := BlockContainer.new(document, none, root_style)
	root.set_children_are_inline(false)
	mut children := []&BlockContainer{}
	for text in ['first', 'second', 'hidden'] {
		child_style := line_clamp_test_style(document, 'display:block; block-ellipsis:"!"; font:20px/24px monospace')
		mut child := BlockContainer.new(document, none, child_style)
		child.set_children_are_inline(true)
		dom_text := document.create_text_node(text)
		text_node := TextNode.new(document, dom_text.as_node(), text)
		child.append_child(unsafe { &Node(text_node) })
		root.append_child(unsafe { &Node(child) })
		children << child
	}
	assign_layout_indexes(unsafe { &Node(root) })
	mut state := LayoutState.new()
	root_styled := unsafe { &Node(root) }.as_node_with_style() or { panic('root style') }
	layout_block_flow(mut state, root_styled, 240, none)
	root_used := state.get(root_styled)
	assert root_used.has_line_clamp_point()
	assert root_used.content_height().to_double() == 48
	second_styled := unsafe { &Node(children[1]) }.as_node_with_style() or {
		panic('second style')
	}
	second_used := state.get(second_styled)
	assert second_used.line_boxes.len == 1
	assert second_used.line_boxes[0].fragments_.last().is_block_ellipsis()
	assert second_used.line_boxes[0].fragments_.last().text()? == '!'
	hidden_styled := unsafe { &Node(children[2]) }.as_node_with_style() or {
		panic('hidden style')
	}
	assert state.get(hidden_styled).is_invisible_for_line_clamp()
}

fn test_line_clamp_does_not_create_a_clamp_point_without_future_content() {
	document := dom.Document.create(dom.url_about_blank())
	result := run_line_clamp_test(document, 'display:block; line-clamp:3; font:20px/24px monospace', AvailableSize.make_indefinite())
	assert result.lines.len == 3
	assert !result.has_clamp_point
	assert !result.lines.last().fragments_.last().is_block_ellipsis()
}

fn test_block_ellipsis_uses_the_same_paint_run_as_literal_text() {
	style := '<style>html,body{margin:0}div{width:12ch;font:20px/24px monospace}</style>'
	clamped_document := html.parse_document('${style}<div style="line-clamp:2">first<br>second<br>hidden</div>')
	clamped_root := layout_document_typed_in_viewport(clamped_document, 300, 200)
	clamped_commands := clamped_root.paint_commands().filter(it.kind == 'draw_text'
		&& it.text.contains('…'))
	assert clamped_commands.len == 1
	assert clamped_commands[0].text == 'second…'

	literal_document := html.parse_document('${style}<div>first<br>second…</div>')
	literal_root := layout_document_typed_in_viewport(literal_document, 300, 200)
	literal_commands := literal_root.paint_commands().filter(it.kind == 'draw_text'
		&& it.text.contains('…'))
	assert literal_commands.len == 1
	assert literal_commands[0].text == clamped_commands[0].text
	if clamped_run := clamped_commands[0].glyph_run {
		literal_run := literal_commands[0].glyph_run or {
			panic('literal ellipsis did not retain the clamped glyph-run representation')
		}
		assert clamped_run.glyph_indices() == literal_run.glyph_indices()
		assert clamped_run.glyph_positions() == literal_run.glyph_positions()
	} else {
		assert literal_commands[0].glyph_run == none
	}

	custom_document := html.parse_document('${style}<div style="line-clamp:2 &quot;++&quot;">first<br>second<br>hidden</div>')
	custom_root := layout_document_typed_in_viewport(custom_document, 300, 200)
	custom_commands := custom_root.paint_commands().filter(it.kind == 'draw_text'
		&& it.text.contains('++'))
	assert custom_commands.len == 1
	custom_run := custom_commands[0].glyph_run or { panic('missing custom ellipsis run') }

	literal_custom_document := html.parse_document('${style}<div>first<br>second++</div>')
	literal_custom_root := layout_document_typed_in_viewport(literal_custom_document, 300, 200)
	literal_custom_commands := literal_custom_root.paint_commands().filter(it.kind == 'draw_text'
		&& it.text.contains('++'))
	assert literal_custom_commands.len == 1
	literal_custom_run := literal_custom_commands[0].glyph_run or {
		panic('missing literal custom ellipsis run')
	}
	assert custom_commands[0].text == literal_custom_commands[0].text
	assert custom_run.glyph_indices() == literal_custom_run.glyph_indices()
	assert custom_run.glyph_positions() == literal_custom_run.glyph_positions()
}

fn test_block_ellipsis_reuses_a_matching_last_resort_face() {
	typeface := &css.PlatformTypeface{
		family_name: 'Authored alias'
		source_path: 'pixel_tests/sites/uclibc-ng/uclibc-ng.org/fonts/glyphicons-halflings-regular.ttf'
	}
	last_resort_typeface := &css.PlatformTypeface{
		family_name: 'Last resort alias'
		source_path: typeface.source_path
	}
	mut cascade := css.FontCascadeList.create()
	cascade.add(css.PlatformFont{
		typeface: typeface
		point_size: 20
	}, []css.UnicodeRange{})
	cascade.set_last_resort_font(css.PlatformFont{
		typeface: last_resort_typeface
		point_size: 20
	})

	selected := block_ellipsis_font_for_code_point(cascade, 0x2026)
	assert !selected.contains_glyph(0x2026)
	assert selected.family == 'Authored alias'
}
