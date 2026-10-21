module layout

import html

fn all_frozen_find(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := all_frozen_find(child, id) {
			return found
		}
	}
	return none
}

fn all_frozen_used(result DocumentLayoutResult, id string) &UsedValues {
	node := all_frozen_find(result.root, id) or { panic('missing #${id}') }
	styled := node.as_node_with_style() or { panic('missing style') }
	return result.used_values_for(styled) or { panic('missing used values') }
}

fn test_all_frozen_empty_line_keeps_an_empty_owned_result() {
	mut state := LayoutState.new()
	line := FlexLine{}
	for row_axis in [true, false] {
		for width in [0, 100] {
			result := resolve_flexible_lengths(mut state, line, CSSPixels.new(width),
				[]CSSPixels{}, CSSPixels.new(7), none, row_axis)
			assert result.len == 0
			assert line.bases.len == 0
		}
	}
}

fn test_all_frozen_zero_factors_and_constraint_freezing_keep_hypotheticals() {
	document := html.parse_document('<!doctype html><style>
		body{margin:0}.row{display:flex;width:200px}.item{flex:none;width:40px;height:30px}
		#small{width:50px}.column{display:flex;flex-direction:column;height:200px;width:50px}
		#capped{flex:1 1 100px;max-width:40px;min-width:0;height:10px}
		#minimum{flex:1 1 20px;min-width:70px;height:10px}
	</style><div class="row"><div id="grow-a" class="item"></div><div id="grow-b" class="item"></div></div>
	<div class="row" id="small"><div id="shrink-a" class="item"></div><div id="shrink-b" class="item"></div></div>
	<div class="column"><div id="column-a" class="item"></div><div id="column-b" class="item"></div></div>
	<div class="row"><div id="capped"></div></div>
	<div class="row" style="width:50px"><div id="minimum"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['grow-a', 'grow-b', 'shrink-a', 'shrink-b'] {
		assert all_frozen_used(result, id).content_width().to_double() == 40
	}
	assert all_frozen_used(result, 'shrink-b').offset.x().to_double() == 40
	for id in ['column-a', 'column-b'] {
		assert all_frozen_used(result, id).content_height().to_double() == 30
	}
	assert all_frozen_used(result, 'column-b').offset.y().to_double() == 30
	assert all_frozen_used(result, 'capped').content_width().to_double() == 40
	assert all_frozen_used(result, 'minimum').content_width().to_double() == 70
}

fn test_all_frozen_targets_own_storage_and_leave_source_arrays_unchanged() {
	document := html.parse_document('<!doctype html><style>
		#flex{display:flex;width:200px}.item{flex:none;width:40px;height:10px}
	</style><div id="flex"><div id="one" class="item"></div><div id="two" class="item"></div></div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := all_frozen_find(result.root, 'one') or { panic('missing one') }
	two := all_frozen_find(result.root, 'two') or { panic('missing two') }
	line := FlexLine{
		items: [one, two]
		bases: [CSSPixels.new(10), CSSPixels.new(20)]
		hypotheticals: [CSSPixels.new(40), CSSPixels.new(30)]
		minimums: [CSSPixels.new(0), CSSPixels.new(0)]
		maximums: [CSSPixels.new(999), CSSPixels.new(999)]
		deferred_minimums: [true, true]
	}
	mut state := result.state
	for width in [20, 200] {
		mut targets := resolve_flexible_lengths(mut state, line, CSSPixels.new(width),
			[CSSPixels.new(0), CSSPixels.new(0)], CSSPixels.new(3), none, true)
		assert targets == line.hypotheticals
		assert targets.data != line.bases.data
		assert targets.data != line.hypotheticals.data
		targets[0] = CSSPixels.new(99)
		assert line.bases[0] == CSSPixels.new(10)
		assert line.hypotheticals[0] == CSSPixels.new(40)
		assert line.minimums[0] == CSSPixels.new(0)
		assert line.deferred_minimums == [true, true]
	}
}
