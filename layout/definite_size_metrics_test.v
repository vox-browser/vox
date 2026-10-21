module layout

import css
import dom

fn definite_metrics_node(declarations string) &NodeWithStyle {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:20px/24px SerenitySans;${declarations}')
	computed := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	return unsafe { &NodeWithStyle(BlockContainer.new(document, none, computed)) }
}

fn definite_metrics_resolve(node &NodeWithStyle, size css.Size, containing ?&UsedValues, width bool) ?CSSPixels {
	return resolve_definite_size(node, node.computed_values(), size, containing, width, &UsedValues{})
}

fn test_definite_size_initialization_keeps_absolute_units_and_min_max_clamps() {
	for width in ['96px', '72pt', '1in', '2.54cm', '25.4mm', '6pc', '101.6q'] {
		node := definite_metrics_node('width:${width};min-width:80px;max-width:120px;height:48px;min-height:16px;max-height:32px')
		mut document := node.document()
		defer { document.finalize() }
		mut state := LayoutState.new()
		values := state.get_mutable(node)
		assert values.content_width() == CSSPixels.new(96)
		assert values.content_height() == CSSPixels.new(32)
		assert values.has_definite_width() && values.has_definite_height()
	}
}

fn test_definite_sizes_keep_actual_payload_and_fractional_percentage_results() {
	node := definite_metrics_node('width:calc(2em + 10%)')
	mut document := node.document()
	defer { document.finalize() }
	mut containing := &UsedValues{}
	containing.set_content_width(CSSPixels.nearest_value_for(128.125))
	containing.set_content_height(CSSPixels.nearest_value_for(128.125))
	containing.set_has_definite_height(true)
	calculated := node.computed_values().size_value(.width).length_percentage_ or { panic('missing calculation') }
	payloads := [css.LengthPercentage.from_length(css.Length.make_px(12.5)),
		css.LengthPercentage.from_percentage(css.Percentage.new(12.5)),
		css.LengthPercentage.from_length(css.Length.new(2, .em)), calculated]
	context := layout_length_resolution_context(node)
	for tag in [css.SizeType.length, .percentage, .calculated] {
		assert definite_metrics_resolve(node, css.Size.new(tag, none), containing, true)? == CSSPixels.new(0)
		for payload in payloads {
			size := css.Size.new(tag, payload)
			expected := size.to_px(context, containing.content_width())
			assert definite_metrics_resolve(node, size, containing, true)? == expected
			assert definite_metrics_resolve(node, size, containing, false)? == expected
		}
	}
	for raw in [1, 63, 65, 641] {
		containing.content_width_ = CSSPixels.from_raw(raw)
		for percentage in [0.0, 12.5, 50.0, 100.0] {
			size := css.Size.make_percentage(css.Percentage.new(percentage))
			assert definite_metrics_resolve(node, size, containing, true)?.raw_value() == i64(f64(raw) * percentage / 100)
		}
	}
	assert definite_metrics_resolve(node, css.Size.make_length(css.Length.new(2, .em)), containing, true)? == CSSPixels.new(40)
}

fn test_border_box_definite_sizes_keep_axis_padding_contexts_and_percentage_basis() {
	mut containing := &UsedValues{}
	containing.set_content_width(CSSPixels.new(240))
	containing.set_content_height(CSSPixels.new(120))
	containing.set_has_definite_height(true)
	for declarations, expected in {
		'padding:2px;border:3px solid': [90, 70]
		'padding-left:10%;padding-right:10%;padding-top:5%;padding-bottom:2px;border:3px solid': [46, 60]
		'padding-left:1em;padding-right:2px;padding-top:1em;padding-bottom:2px;border:3px solid': [72, 52]
		'padding-left:calc(1em + 2px);padding-right:2px;padding-top:calc(1em + 2px);padding-bottom:2px;border:3px solid': [70, 50]
	} {
		node := definite_metrics_node('box-sizing:border-box;${declarations}')
		mut document := node.document()
		defer { document.finalize() }
		assert definite_metrics_resolve(node, css.Size.make_px(CSSPixels.new(100)), containing, true)? == CSSPixels.new(expected[0])
		assert definite_metrics_resolve(node, css.Size.make_px(CSSPixels.new(80)), containing, false)? == CSSPixels.new(expected[1])
	}
}

fn test_relative_definite_sizes_keep_live_viewport_and_indefinite_percentage_rules() {
	node := definite_metrics_node('')
	mut document := node.document()
	defer { document.finalize() }
	for viewport_width in [400, 800] {
		document.set_viewport_rect(dom.Rect{width: f64(viewport_width), height: 600})
		assert definite_metrics_resolve(node, css.Size.make_length(css.Length.new(20, .vw)), none, true)? == CSSPixels.new(viewport_width / 5)
		assert definite_metrics_resolve(node, css.Size.make_length(css.Length.new(2, .em)), none, false)? == CSSPixels.new(40)
	}
	mut containing := &UsedValues{}
	containing.set_content_width(CSSPixels.new(200))
	percentage := css.Size.make_percentage(css.Percentage.new(50))
	assert definite_metrics_resolve(node, percentage, containing, true)? == CSSPixels.new(100)
	assert definite_metrics_resolve(node, percentage, containing, false) == none
	containing.set_content_height(CSSPixels.new(120))
	containing.set_has_definite_height(true)
	assert definite_metrics_resolve(node, percentage, containing, false)? == CSSPixels.new(60)
	for size in [css.Size.make_auto(), css.Size.make_none(), css.Size.make_min_content(), css.Size.make_max_content()] {
		assert definite_metrics_resolve(node, size, none, true) == none
	}
}
