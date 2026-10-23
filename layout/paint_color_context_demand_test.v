module layout

import html
import http
import loader
import painting

fn test_box_paint_keeps_full_color_and_calculation_context_for_gradients_and_filters() {
	for style in [
		'background:linear-gradient(currentColor,CanvasText);filter:drop-shadow(1px 2px 0 AccentColor)',
		'background:radial-gradient(circle at 1em 2em,currentColor,Canvas);backdrop-filter:drop-shadow(2px 1px 0 currentColor)',
		'background:conic-gradient(from 30deg,currentColor,CanvasText)',
	] {
		mut document := html.parse_document('<!doctype html><div id="target" style="color-scheme:dark;color:rgb(40,50,60);font-size:23px;width:80px;height:40px;' + style + '"></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 200, 100)
		element := document.get_element_by_id('target')?
		node := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
		state := document_layout_result(document)?.state
		styled := node.as_node_with_style() or { panic('missing styled target') }
		used := state.try_get(styled) or { panic('missing used target') }
		assert used.border_box_width().to_double() == 80
		assert used.border_box_height().to_double() == 40
		computed := node.computed_values()
		box := uncached_block_box_from_typed_layout_shallow(node, state, [6]f64{})
		full := color_resolution_context_for_typed_node(node, computed.color())
		position := paint_cumulative_offset(node, state, used)
		bounds := painting.Rect{
			x:      position.x().to_double() - used.padding_left.to_double() - used.border_left.to_double()
			y:      position.y().to_double() - used.padding_top.to_double() - used.border_top.to_double()
			width:  used.border_box_width().to_double()
			height: used.border_box_height().to_double()
		}
		actual_gradient := box.decorations().background_gradient or { panic('missing painted gradient') }
		expected_gradient := computed_background_gradient(computed, bounds.width, bounds.height, full) or { panic('missing reference gradient') }
		actual_gradient_value := *actual_gradient
		assert actual_gradient_value.str() == expected_gradient.str()
		if style.contains('filter:') {
			assert box.filters().filter.has_filters() || box.filters().backdrop_filter.has_filters()
		}
		assert box.filters().filter.str() == resolved_css_filter_for_element(computed, full, element, bounds).str()
		assert box.filters().backdrop_filter.str() == resolve_css_filter(computed.backdrop_filter(), computed, full, element, bounds).str()
	}
}

fn test_url_background_svg_keeps_its_color_scheme_and_intrinsic_size_without_gradient_calculations() {
	if !loader.is_initialized() { loader.initialize() }
	mut resources := loader.ResourceLoader.the()
	resources.register_network_response('https://paint-context.test/icon', loader.NetworkResponse{
		data:    '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="blue"/></svg>'.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
	mut document := html.parse_document('<!doctype html><div id="target" style="color-scheme:dark;width:40px;height:30px;background:url(https://paint-context.test/icon)"></div>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 200, 100)
	commands := root.paint_commands().filter(it.kind == 'draw_background_image')
	assert commands.len == 1
	assert commands[0].image().image_intrinsic_width == 20
	assert commands[0].image().image_intrinsic_height == 10
	assert commands[0].image().background_svg_document?.preferred_color_scheme() == 'dark'
}
