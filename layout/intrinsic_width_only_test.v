module layout

import css
import dom

fn intrinsic_width_container(document &dom.Document, text string, extra string) &BlockContainer {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:20px/24px Arial;overflow-wrap:anywhere;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	container.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(text).as_node(), text)) })
	assign_layout_indexes(unsafe { &Node(container) })
	return container
}

fn test_disposable_width_matches_complete_intrinsic_layout() {
	for text in ['AVATAR ffi To Wa Y word  ', 'Кириллица слова 😀 á', 'אבג xyz العربية',
		'a\tb\nAV To', '', ' \t\n '] {
		for extra in ['', 'letter-spacing:-40px;word-spacing:1.25px', 'white-space:pre-wrap',
			'direction:rtl', 'writing-mode:vertical-rl', 'text-align:justify',
			'text-indent:13px', 'text-indent:13px hanging each-line', 'text-align:center'] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			container := intrinsic_width_container(document, text, extra)
			for width in [AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
				space := AvailableSpace.new(width, AvailableSize.make_indefinite())
				mut reference_state := LayoutState.new()
				mut reference := reference_state.get_mutable(unsafe { &NodeWithStyle(container) })
				reference.set_indefinite_content_width()
				oracle := run_inline_formatting_context(mut reference_state, container, mut reference, .intrinsic_sizing, space)
				mut state := LayoutState.new()
				mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
				used.set_indefinite_content_width()
				assert measure_disposable_inline_width(mut state, container, mut used, space) == oracle.automatic_content_width
				// The public entry point still finalizes complete geometry afterward.
				published := run_inline_formatting_context(mut state, container, mut used, .intrinsic_sizing, space)
				assert published.automatic_content_width == oracle.automatic_content_width
				assert published.automatic_content_height == oracle.automatic_content_height
				assert used.line_boxes.len == reference.line_boxes.len
				for i in 0 .. used.line_boxes.len {
					assert used.line_boxes[i].baseline() == reference.line_boxes[i].baseline()
					assert used.line_boxes[i].height() == reference.line_boxes[i].height()
				}
			}
		}
	}
}
