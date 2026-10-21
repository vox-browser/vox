module layout

import css
import dom

fn context_free_size_node(declarations string) &Node {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:20px/24px SerenitySans;${declarations}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	return unsafe { &Node(BlockContainer.new(document, none, style)) }
}

fn context_free_size_check(node &Node, size css.Size, basis CSSPixels) CSSPixels {
	expected := size.to_px(layout_length_resolution_context(node), basis)
	actual := resolve_layout_size(node, size, basis) or { panic('numeric size was rejected') }
	assert actual == expected
	return actual
}

fn test_context_free_sizes_keep_absolute_units_and_fractional_percentage_rounding() {
	node := context_free_size_node('')
	units := [css.LengthUnit.px, .pt, .in_, .cm, .mm, .pc, .q]
	values := [96.0, 72.0, 1.0, 2.54, 25.4, 6.0, 101.6]
	for i, unit in units {
		for sign in [-1.0, 0.0, 1.0] {
			size := css.Size.make_length(css.Length.new(values[i] * sign, unit))
			assert context_free_size_check(node, size, CSSPixels.new(300)) == CSSPixels.new(int(96 * sign))
		}
	}
	for raw in [-641, -1, 0, 1, 641] {
		for percentage in [-50.0, 0.0, 50.0, 100.0, 200.0] {
			size := css.Size.make_percentage(css.Percentage.new(percentage))
			actual := context_free_size_check(node, size, CSSPixels.from_raw(raw))
			assert actual.raw_value() == i64(f64(raw) * percentage / 100)
		}
	}
	for value in [-1e100, -0.0078125, 0.0078125, 1e100] {
		context_free_size_check(node, css.Size.make_length(css.Length.make_px(value)), CSSPixels.new(0))
	}
}

fn test_context_dependent_sizes_keep_font_calculation_and_actual_payload_semantics() {
	node := context_free_size_node('')
	for text, expected in {'2em': 40.0, '0em': 0.0, 'calc(2em + 10%)': 72.0} {
		styled := context_free_size_node('width:${text}')
		size := styled.computed_values().size_value(.width)
		assert context_free_size_check(styled, size, CSSPixels.new(320)) == CSSPixels.nearest_value_for(expected)
	}
	// Public Size records can carry a numeric tag with no payload, or a
	// payload that differs from the tag. Resolution follows the actual owner.
	for tag in [css.SizeType.length, .percentage, .calculated] {
		assert context_free_size_check(node, css.Size.new(tag, none), CSSPixels.new(320)).raw_value() == 0
		for payload in [css.LengthPercentage.from_length(css.Length.make_px(12.5)),
			css.LengthPercentage.from_percentage(css.Percentage.new(12.5)),
			css.LengthPercentage.from_length(css.Length.new(2, .em))] {
			context_free_size_check(node, css.Size.new(tag, payload), CSSPixels.new(320))
		}
	}
	for tag in [css.SizeType.auto_, .min_content, .max_content, .fit_content, .none_] {
		assert resolve_layout_size(node, css.Size.new(tag, none), CSSPixels.new(320)) == none
		assert resolve_layout_size(node, css.Size.new(tag,
			css.LengthPercentage.from_length(css.Length.make_px(10))), CSSPixels.new(320)) == none
	}
}

fn test_context_free_sizes_keep_content_box_edge_subtraction_and_zero_clamp() {
	for sizing in ['content-box', 'border-box'] {
		node := context_free_size_node('box-sizing:${sizing}')
		mut used := &UsedValues{}
		used.padding_left = CSSPixels.new(3)
		used.padding_right = CSSPixels.new(7)
		used.border_left = CSSPixels.new(2)
		used.border_right = CSSPixels.new(4)
		used.padding_top = CSSPixels.new(5)
		used.padding_bottom = CSSPixels.new(6)
		used.border_top = CSSPixels.new(1)
		used.border_bottom = CSSPixels.new(2)
		for width in [false, true] {
			for value in [10.0, 50.0] {
				for size in [css.Size.make_length(css.Length.make_px(value)),
					css.Size.make_percentage(css.Percentage.new(value))] {
					resolved := resolve_layout_content_size(node, size, CSSPixels.new(100), used, width) or { panic('missing size') }
					edges := if sizing == 'content-box' { 0.0 } else if width { 16.0 } else { 14.0 }
					expected := if value < edges { 0.0 } else { value - edges }
					assert resolved == CSSPixels.nearest_value_for(expected)
				}
			}
		}
	}
}
