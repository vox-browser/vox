module layout

import css
import dom

fn initial_constraint_node(document &dom.Document, declarations string) &NodeWithStyle {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:20px/24px SerenitySans;${declarations}')
	computed := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	return unsafe { &NodeWithStyle(BlockContainer.new(document, none, computed)) }
}

// Preserve the previous eager evaluation as an oracle for the initialization
// boundary. Independent expectations below also check the important branches.
fn initial_constraint_eager(node &NodeWithStyle, containing ?&UsedValues, mut values UsedValues) {
	values.node_ = node
	values.containing_block_used_values_ = containing
	computed := node.computed_values()
	min_width := resolve_definite_size(node, computed, computed.size_value(.min_width), containing, true, values)
	max_width := resolve_definite_size(node, computed, computed.size_value(.max_width), containing, true, values)
	min_height := resolve_definite_size(node, computed, computed.size_value(.min_height), containing, false, values)
	max_height := resolve_definite_size(node, computed, computed.size_value(.max_height), containing, false, values)
	if width := resolve_definite_size(node, computed, computed.size_value(.width), containing, true, values) {
		values.content_width_ = clamp_to_max_dimension_value(width)
		values.has_definite_width_ = true
		if minimum := min_width {
			if values.content_width_.raw_value() < minimum.raw_value() { values.content_width_ = clamp_to_max_dimension_value(minimum) }
		}
		if maximum := max_width {
			if values.content_width_.raw_value() > maximum.raw_value() { values.content_width_ = clamp_to_max_dimension_value(maximum) }
		}
	}
	if height := resolve_definite_size(node, computed, computed.size_value(.height), containing, false, values) {
		values.content_height_ = clamp_to_max_dimension_value(height)
		values.has_definite_height_ = true
		if minimum := min_height {
			if values.content_height_.raw_value() < minimum.raw_value() { values.content_height_ = clamp_to_max_dimension_value(minimum) }
		}
		if maximum := max_height {
			if values.content_height_.raw_value() > maximum.raw_value() { values.content_height_ = clamp_to_max_dimension_value(maximum) }
		}
	}
}

fn test_initial_size_constraints_keep_eager_results_across_axis_and_edge_states() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for declarations in [
		'width:auto;height:auto',
		'width:100px;height:auto',
		'width:auto;height:80px',
		'width:50%;height:50%',
		'width:min-content;height:max-content',
		'width:calc(2em + 10%);height:4em',
		'width:100px;height:80px;box-sizing:border-box;padding:1em;border:3px solid',
		'width:100px;height:80px;min-width:120px;max-width:90px;min-height:100px;max-height:60px',
	] {
		node := initial_constraint_node(document, 'min-width:30%;max-width:120px;min-height:16px;max-height:120px;${declarations}')
		parent := initial_constraint_node(document, '')
		mut parent_node := unsafe { &Node(parent) }
		parent_node.append_child(unsafe { &Node(node) })
		for mode in 0 .. 5 {
			mut basis := &UsedValues{}
			basis.set_content_width(CSSPixels.nearest_value_for(240.125))
			basis.set_content_height(CSSPixels.nearest_value_for(120.25))
			basis.set_has_definite_width(mode % 2 == 0)
			basis.set_has_definite_height(mode >= 2)
			containing := if mode == 4 { ?&UsedValues(none) } else { ?&UsedValues(basis) }
			for edges in [0, 3] {
				mut eager := UsedValues{margin_left:CSSPixels.new(edges), padding_right:CSSPixels.new(edges), border_left:CSSPixels.new(edges)}
				mut actual := eager
				initial_constraint_eager(node, containing, mut eager)
				actual.set_node(node, containing)
				assert actual.content_width() == eager.content_width()
				assert actual.content_height() == eager.content_height()
				assert actual.has_definite_width() == eager.has_definite_width()
				assert actual.has_definite_height() == eager.has_definite_height()
				assert voidptr(actual.node()) == voidptr(node)
				assert actual.containing_block_used_values() == containing
			}
		}
	}
}

fn test_initial_size_constraints_leave_unresolved_axes_for_later_layout() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut basis := &UsedValues{}
	basis.set_content_width(CSSPixels.new(240))
	basis.set_content_height(CSSPixels.new(120))
	basis.set_has_definite_height(true)
	for declarations, expected in {
		'width:auto;height:auto': [120, 0, 1, 0]
		'width:auto;height:80px': [120, 80, 1, 1]
		'width:100px;height:auto': [100, 0, 1, 0]
		'width:auto;height:auto;float:left': [0, 0, 0, 0]
		'width:auto;height:auto;position:absolute': [0, 0, 0, 0]
		'width:min-content;height:max-content': [0, 0, 0, 0]
	} {
		node := initial_constraint_node(document, 'min-width:80px;max-width:120px;min-height:16px;max-height:120px;${declarations}')
		parent := initial_constraint_node(document, '')
		mut parent_node := unsafe { &Node(parent) }
		parent_node.append_child(unsafe { &Node(node) })
		mut values := UsedValues{}
		values.set_node(node, basis)
		assert values.content_width() == CSSPixels.new(expected[0])
		assert values.content_height() == CSSPixels.new(expected[1])
		assert values.has_definite_width() == (expected[2] == 1)
		assert values.has_definite_height() == (expected[3] == 1)
	}
}
