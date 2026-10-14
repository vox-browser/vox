module layout

import css
import dom

fn paint_offset_chain(count int) ([]&NodeWithStyle, []&UsedValues, &LayoutState) {
	document := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut nodes := []&NodeWithStyle{}
	mut values := []&UsedValues{}
	mut state := LayoutState.new()
	for index in 0 .. count {
		mut node := NodeWithStyle.new(document, none, style)
		node.set_layout_index(u32(index))
		mut used := state.get_mutable(node)
		used.set_content_offset(css.CSSPixelPoint.from_values(1.25, -2.5))
		if index > 0 {
			used.set_containing_block_used_values(values[index - 1])
		}
		nodes << node
		values << used
	}
	return nodes, values, state
}

fn test_paint_offsets_follow_deep_containing_block_chains_and_live_geometry() {
	nodes, values, state := paint_offset_chain(257)
	root := unsafe { &Node(nodes.last()) }
	assert paint_cumulative_offset(root, state, values.last()) == css.CSSPixelPoint.from_values(321.25,
		-642.5)
	mut middle := values[128]
	middle.set_content_offset(css.CSSPixelPoint.from_values(10.25, 17.5))
	assert paint_cumulative_offset(root, state, values.last()) == css.CSSPixelPoint.from_values(330.25,
		-622.5)
}

fn test_paint_offsets_count_each_distinct_record_once_in_cyclic_chains() {
	for count in [1, 2, 3, 17, 65, 257] {
		nodes, values, state := paint_offset_chain(count)
		mut first := values[0]
		first.set_containing_block_used_values(values.last())
		assert paint_cumulative_offset(unsafe { &Node(nodes.last()) }, state, values.last()) == css.CSSPixelPoint.from_values(f64(count) * 1.25,
			f64(count) * -2.5)
		// A tail enters the cycle away from its start.
		first.set_containing_block_used_values(values[count / 2])
		assert paint_cumulative_offset(unsafe { &Node(nodes.last()) }, state, values.last()) == css.CSSPixelPoint.from_values(f64(count) * 1.25,
			f64(count) * -2.5)
	}
}

fn test_paint_offsets_include_live_relative_insets() {
	nodes, values, state := paint_offset_chain(3)
	mut relative_style := css.ComputedProperties.new()
	relative_style.set_property_without_modifying_flags(.position, &dom.StyleValue{
		css_text: 'relative'
	})
	mut middle_node := nodes[1]
	middle_node.apply_style(relative_style)
	mut middle := values[1]
	middle.inset_left = CSSPixels.new(7)
	middle.inset_top = CSSPixels.new(-11)
	assert paint_cumulative_offset(unsafe { &Node(nodes.last()) }, state, values.last()) == css.CSSPixelPoint.from_values(10.75,
		-18.5)
}
