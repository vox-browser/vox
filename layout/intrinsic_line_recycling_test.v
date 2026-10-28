module layout

import css
import dom

fn recycled_intrinsic_container(document &dom.Document, text string, extra string) &BlockContainer {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:20px/24px Arial;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	container.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(text).as_node(), text)) })
	assign_layout_indexes(unsafe { &Node(container) })
	return container
}

fn test_disposable_intrinsic_lines_recycle_without_losing_earlier_widths() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for text in ['WIDEST_EARLY ' + 'AV To word  '.repeat(32),
			'AV To word  '.repeat(32) + ' WIDEST_LATE',
			'one\n\nlongest-middle-word\n' + 'a\tb\n '.repeat(32)] {
			for extra in ['', 'white-space:pre-wrap;text-indent:73px hanging each-line',
				'text-indent:73px;letter-spacing:-1.25px;word-spacing:2px'] {
				mut document := dom.Document.create(dom.url_about_blank())
				defer { document.finalize() }
				document.set_font_rendering_policy(policy)
				container := recycled_intrinsic_container(document, text, extra)
				for width in [AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
					space := AvailableSpace.new(width, AvailableSize.make_indefinite())
					mut reference_state := LayoutState.new()
					mut reference := reference_state.get_mutable(unsafe { &NodeWithStyle(container) })
					reference.set_indefinite_content_width()
					oracle := run_inline_formatting_context(mut reference_state, container, mut reference,
						.intrinsic_sizing, space)
					mut state := LayoutState.new()
					mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
					used.set_indefinite_content_width()
					measured := measure_disposable_inline_width(mut state, container, mut used, space)
					assert measured == oracle.automatic_content_width
					assert used.line_boxes.len <= 2
					if width.is_min_content() {
						assert reference.line_boxes.len > 10
					}
					// A later published layout must reconstruct all lines and glyph geometry.
					published := run_inline_formatting_context(mut state, container, mut used,
						.intrinsic_sizing, space)
					assert published.automatic_content_width == oracle.automatic_content_width
					assert published.automatic_content_height == oracle.automatic_content_height
					assert used.line_boxes.len == reference.line_boxes.len
					for index in 0 .. used.line_boxes.len {
						assert used.line_boxes[index].width() == reference.line_boxes[index].width()
						assert used.line_boxes[index].baseline() == reference.line_boxes[index].baseline()
					}
				}
			}
		}
	}
}
