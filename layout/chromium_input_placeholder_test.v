module layout

import dom
import html

fn test_input_placeholder_line_height_inside_a_padded_clamped_control() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for materialize_shadow in [false, true] {
			mut document := html.parse_document('<!doctype html><style>
			body { margin:0 }
			.wrapper { display:inline-flex; align-items:center; width:280px }
			.context { display:block; width:100%; height:100%; overflow:hidden }
			input { box-sizing:border-box; margin:0; border:0; padding:16px 0;
				font:500 14px/48px Arial; width:100%; min-height:48px; max-height:48px }
			input::placeholder { line-height:80px !important }
		</style><span class="wrapper"><span class="context"><input id="search" placeholder="Search for and select places"></span></span>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			element := document.get_element_by_id('search') or { panic('missing input element') }
			if materialize_shadow {
				_ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			}
			result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
			bridge := element.as_node().layout_node() or { panic('missing input layout') }
			input := unsafe { &Node(bridge.layout_handle) }
			assert input.is_text_input_box()
			outer := input.first_child() or { panic('missing shadow container') }
			placeholder := outer.children()[1]
			input_style := input.as_node_with_style()?
			input_used := result.used_values_for(input_style)?
			outer_style := outer.as_node_with_style()?
			outer_used := result.used_values_for(outer_style)?
			placeholder_style := placeholder.as_node_with_style()?
			placeholder_used := result.used_values_for(placeholder_style)?
			assert input_used.content_height().to_double() == 16
			assert input_used.border_box_height().to_double() == 48
			assert outer_used.content_height() == input_used.content_height()
			if policy == .chromium {
				assert placeholder.computed_values().line_height().to_double() == 16
				assert placeholder_used.content_height().to_double() == 16
				assert placeholder_used.offset.y().to_double() == 0
			} else {
				assert placeholder.computed_values().line_height().to_double() == 48
				assert placeholder_used.content_height().to_double() == 48
				assert placeholder_used.offset.y().to_double() == -16
			}
		}
	}
}
