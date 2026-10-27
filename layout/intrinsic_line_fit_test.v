module layout

import css
import dom
import platform

fn intrinsic_line_fit_test_style(document &dom.Document) &css.ComputedProperties {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'display:block;font:20px Arial;line-height:24px;overflow-wrap:anywhere')
	computer := css.css_style_computer_for(document)
	return computer.compute_style(dom.AbstractElement.new(element, none))
}

fn test_intrinsic_soft_wrap_decisions_match_fully_measured_signed_advances() {
	for constraint in [AvailableSize.make_min_content(), AvailableSize.make_max_content(),
		AvailableSize.make_indefinite(), AvailableSize.make_definite(CSSPixels.new(25)),
		AvailableSize.make_definite(CSSPixels.new(1000))] {
		for populated in [false, true] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			style := intrinsic_line_fit_test_style(document)
			mut container := BlockContainer.new(document, none, style)
			container.set_children_are_inline(true)
			text := 'AV To Wa Y'
			text_node := TextNode.new(document, document.create_text_node(text).as_node(), text)
			container.append_child(unsafe { &Node(text_node) })
			assign_layout_indexes(unsafe { &Node(container) })
			mut state := LayoutState.new()
			styled := unsafe { &Node(container) }.as_node_with_style() or { panic('missing style') }
			mut values := state.get_mutable(styled)
			values.set_content_width(CSSPixels.new(1000))
			mut builder := LineBuilder.new(mut state, container, values, constraint, .ltr, .horizontal_tb)
			font := &platform.Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
			prefix := platform.shape_text(0, 0, 'AV ', font, .ltr)
			if populated {
				builder.append_text_chunk(text_node, 0, 3, CSSPixels.new(0), CSSPixels.new(0),
					CSSPixels.new(0), CSSPixels.new(0), shaped_inline_width(prefix, 0), CSSPixels.new(24), prefix)
			}
			run := platform.shape_text(0, 0, 'To', font, .ltr)
			following_run := platform.shape_text(0, 0, ' Wa', font, .ltr)
			following := [InlineLevelItem{
				type_:          .text
				node:           unsafe { &Node(text_node) }
				glyph_run:      following_run
				offset_in_node: 5
				length_in_node: 3
				width:          shaped_inline_width(following_run, 0)
			}]
			for width in [shaped_inline_width(run, 0), CSSPixels.new(-100), CSSPixels.new(0)] {
				item := InlineLevelItem{
					type_:          .text
					node:           unsafe { &Node(text_node) }
					glyph_run:      run
					offset_in_node: 3
					length_in_node: 2
					width:          width
				}
				measured := builder.projected_text_sequence_width(item, following)
				fit := builder.projected_text_sequence_width_for_line_break(item, following)
				assert builder.should_break(fit) == builder.should_break(measured)
				if constraint.is_definite() {
					assert fit == measured
				}
				assert values.line_boxes.len == 1
				assert values.line_boxes[0].fragments_.len == if populated { 1 } else { 0 }
			}
		}
	}
}

fn test_intrinsic_overflow_splitting_keeps_the_measured_width() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	style := intrinsic_line_fit_test_style(document)
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	text_node := TextNode.new(document, document.create_text_node('AAAA').as_node(), 'AAAA')
	container.append_child(unsafe { &Node(text_node) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	styled := unsafe { &Node(container) }.as_node_with_style() or { panic('missing style') }
	mut values := state.get_mutable(styled)
	values.set_content_width(CSSPixels.new(1000))
	mut builder := LineBuilder.new(mut state, container, values, AvailableSize.make_min_content(), .ltr, .horizontal_tb)
	font := &platform.Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	run := platform.shape_text(0, 0, 'AAAA', font, .ltr)
	mut item := InlineLevelItem{
		type_:          .text
		node:           unsafe { &Node(text_node) }
		glyph_run:      run
		length_in_node: 4
		width:          shaped_inline_width(run, 0)
	}
	assert builder.projected_text_sequence_width(item, []).raw_value() > 0
	assert builder.projected_text_sequence_width_for_line_break(item, []).raw_value() == 0
	break_overflowing_text_item(mut builder, mut item)
	builder.append_text_item(item, CSSPixels.new(24))
	assert values.line_boxes.len == 4
	for line in values.line_boxes {
		assert line.fragments_.len == 1
		assert line.fragments_[0].length_in_code_units_ == 1
		assert line.fragments_[0].inline_length_.raw_value() > 0
	}
}
