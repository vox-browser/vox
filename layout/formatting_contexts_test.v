module layout

import html
import platform
import svg

fn layout_node_with_id(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := layout_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn used_for_id(result DocumentLayoutResult, id string) &UsedValues {
	node := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
	styled := node.as_node_with_style() or { panic('#${id} has no style') }
	return result.used_values_for(styled) or { panic('#${id} has no used values') }
}

fn test_flex_formatting_context_grows_and_aligns_items() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:300px; height:100px; gap:10px; align-items:center }
		#one, #two { flex:1 1 0px; height:20px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() == 145
	assert two.content_width().to_double() == 145
	assert one.offset.x().to_double() == 0
	assert two.offset.x().to_double() == 155
	assert one.offset.y().to_double() == 40
	assert two.offset.y().to_double() == 40
}

fn test_multiline_flex_align_content_distributes_cross_axis_space() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap; align-content:center; width:100px; height:100px }
		#one, #two { flex:none; width:60px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.y().to_double() == 40
	assert two.offset.y().to_double() == 50
}

fn test_flex_auto_placement_uses_bucketed_order_modified_document_order() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:400px }
		#flex > div { flex:none; width:100px; height:10px }
		#last { order:2 } #first, #also-first { order:-1 }
	</style><div id="flex"><div id="last"></div><div id="first"></div><div id="middle"></div><div id="also-first"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'first').offset.x().to_double() == 0
	assert used_for_id(result, 'also-first').offset.x().to_double() == 100
	assert used_for_id(result, 'middle').offset.x().to_double() == 200
	assert used_for_id(result, 'last').offset.x().to_double() == 300
}

fn test_flex_percentage_gaps_resolve_against_their_axis_inner_size() {
	row_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap; align-content:flex-start;
			width:200px; height:100px; row-gap:10% }
		#one, #two { flex:none; width:120px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	row_result := run_document_layout(row_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(row_result, 'one').offset.y().to_double() == 0
	assert used_for_id(row_result, 'two').offset.y().to_double() == 20

	column_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:200px; height:100px; row-gap:10% }
		#one, #two { flex:none; width:20px; height:20px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	column_result := run_document_layout(column_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(column_result, 'one').offset.y().to_double() == 0
	assert used_for_id(column_result, 'two').offset.y().to_double() == 30
}

fn test_automatic_flex_cross_size_uses_used_inner_size_for_percentage_gap() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap; align-content:flex-start; width:100px; row-gap:10% }
		#one, #two { flex:none; width:60px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.y().to_double() == 0
	// The parent formatting context has assigned a 20px used inner height before
	// FlexFormattingContext::cross_gap() is called, so the gap is 2px.
	assert used_for_id(result, 'two').offset.y().to_double() == 12
}

fn test_wrap_reverse_swaps_align_content_cross_start_and_end() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap-reverse; align-content:flex-start; width:100px; height:100px }
		#one, #two { flex:none; width:60px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert two.offset.y().to_double() == 80
	assert one.offset.y().to_double() == 90
}

fn test_row_flex_auto_margins_absorb_main_and_cross_axis_space() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:300px; height:100px; justify-content:center; align-items:flex-end }
		#one, #two { flex:none; width:50px; height:20px }
		#two { margin-left:auto; margin-top:auto; margin-bottom:auto }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.x().to_double() == 0
	assert one.offset.y().to_double() == 80
	assert two.offset.x().to_double() == 250
	assert two.offset.y().to_double() == 40
	assert two.margin_left.to_double() == 0
	assert two.margin_top.to_double() == 0
	assert two.margin_bottom.to_double() == 0
}

fn test_column_flex_auto_margins_absorb_main_and_cross_axis_space() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:200px; height:300px; justify-content:center; align-items:flex-end }
		#one, #two { flex:none; width:40px; height:50px }
		#two { margin-top:auto; margin-left:auto; margin-right:auto }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.x().to_double() == 160
	assert one.offset.y().to_double() == 0
	assert two.offset.x().to_double() == 80
	assert two.offset.y().to_double() == 250
	assert two.margin_top.to_double() == 0
	assert two.margin_left.to_double() == 0
	assert two.margin_right.to_double() == 0
}

fn test_row_reverse_places_flex_start_at_reversed_main_edge() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:row-reverse; width:300px }
		#one, #two { flex:none; width:50px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.x().to_double() == 250
	assert two.offset.x().to_double() == 200
}

fn test_row_flex_main_sizes_use_content_box_targets_for_border_box_items() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:200px }
		#one, #two { box-sizing:border-box; flex:none; width:100px; height:20px; padding:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() == 80
	assert one.border_box_width().to_double() == 100
	assert two.content_width().to_double() == 80
	assert two.offset.x().to_double() == 110
}

fn test_flex_main_axis_minimum_clamps_border_box_target() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:50px }
		#item { box-sizing:border-box; flex:0 1 200px; min-width:80px;
			height:20px; padding:10px }
	</style><div id="flex"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 60
	assert item.border_box_width().to_double() == 80
}

fn test_row_flex_automatic_minimum_size_is_content_based() {
	document := html.parse_document('<!doctype html><style>
		.flex { display:flex; width:50px }
		.item { flex:0 1 200px; white-space:nowrap }
		#zero { min-width:0 }
		#scroll { overflow:auto }
	</style>
	<div class="flex"><div id="auto">abcdefghijklmnopqrst</div></div>
	<div class="flex"><div id="zero">abcdefghijklmnopqrst</div></div>
	<div class="flex"><div id="scroll">abcdefghijklmnopqrst</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	automatic := used_for_id(result, 'auto')
	zero := used_for_id(result, 'zero')
	scroll := used_for_id(result, 'scroll')
	assert automatic.content_width().to_double() > 50
	assert zero.content_width().to_double() == 50
	assert scroll.content_width().to_double() == 50
}

fn test_flex_automatic_minimum_size_is_capped_by_preferred_and_maximum_sizes() {
	document := html.parse_document('<!doctype html><style>
		.flex { display:flex; width:20px }
		.item { flex:0 1 200px; width:40px; white-space:nowrap }
		#maximum { width:auto; max-width:30px }
	</style>
	<div class="flex"><div id="preferred" class="item">abcdefghijklmnopqrst</div></div>
	<div class="flex"><div id="maximum" class="item">abcdefghijklmnopqrst</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'preferred').content_width().to_double() == 40
	assert used_for_id(result, 'maximum').content_width().to_double() == 30
}

fn test_flex_length_resolution_redistributes_minimum_violations() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:100px }
		#one, #two { flex:0 1 80px; min-width:0; height:10px }
		#one { min-width:70px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 70
	assert used_for_id(result, 'two').content_width().to_double() == 30
}

fn test_flex_factors_below_one_leave_part_of_free_space_unfilled() {
	document := html.parse_document('<!doctype html><style>
		.flex { display:flex; width:100px }
		#shrink-flex { width:50px }
		#grow { flex:0.5 1 20px; min-width:0; height:10px }
		#shrink { flex:0 0.5 100px; min-width:0; height:10px }
	</style>
	<div class="flex"><div id="grow"></div></div>
	<div id="shrink-flex" class="flex"><div id="shrink"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'grow').content_width().to_double() == 60
	assert used_for_id(result, 'shrink').content_width().to_double() == 75
}

fn test_definite_single_line_flex_skips_automatic_minimum_intrinsic_layout() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:200px }
		#item { flex:none; width:100px }
	</style><div id="flex"><div id="item">content that would otherwise be measured</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	flex_node := layout_node_with_id(result.root, 'flex') or { panic('missing #flex') }
	item_node := layout_node_with_id(result.root, 'item') or { panic('missing #item') }
	flex_styled := flex_node.as_node_with_style() or { panic('#flex has no style') }
	item_styled := item_node.as_node_with_style() or { panic('#item has no style') }
	flex_state := result.state.try_get(flex_styled) or { panic('#flex has no used values') }
	item_state := result.state.try_get(item_styled) or { panic('#item has no used values') }
	assert should_skip_automatic_minimum_size_clamp(result.state, flex_node, flex_state, .normal, [
		item_node,
	], [CSSPixels.new(100)], true, CSSPixels.new(200))
	mut item_box := item_node.as_box() or { panic('#item is not a box') }
	item_box.reset_cached_intrinsic_sizes()
	mut measurement_state := result.state
	assert flex_used_main_minimum(mut measurement_state, item_node, item_state, true, CSSPixels.new(200), true).raw_value() == 0
	assert item_box.cached_intrinsic_sizes_ == none
	assert used_for_id(result, 'item').content_width().to_double() == 100
}

fn test_definite_item_basis_skips_redundant_automatic_minimum_intrinsic_layout() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap; width:80px }
		#item, #scroll, #ratio, #replaced { flex:none; width:100px }
		#scroll { overflow:auto }
		#ratio { aspect-ratio:2/1 }
	</style><div id="flex">
		<div id="item">content that would otherwise be measured</div>
		<div id="scroll"></div><div id="ratio"></div><img id="replaced">
	</div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	flex_node := layout_node_with_id(result.root, 'flex') or { panic('missing #flex') }
	item_node := layout_node_with_id(result.root, 'item') or { panic('missing #item') }
	flex_styled := flex_node.as_node_with_style() or { panic('#flex has no style') }
	item_styled := item_node.as_node_with_style() or { panic('#item has no style') }
	flex_state := result.state.try_get(flex_styled) or { panic('#flex has no used values') }
	item_state := result.state.try_get(item_styled) or { panic('#item has no used values') }
	// Wrapping disables the whole-container optimization, so only the C++
	// per-item proof can skip this automatic minimum.
	assert !should_skip_automatic_minimum_size_clamp(result.state, flex_node, flex_state, .normal, [
		item_node,
	], [CSSPixels.new(100)], true, CSSPixels.new(80))
	assert can_skip_automatic_minimum_size_for_item(item_node, item_state, flex_state, CSSPixels.new(100), true, CSSPixels.new(80))
	for id in ['scroll', 'ratio', 'replaced'] {
		excluded_node := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
		excluded_styled := excluded_node.as_node_with_style() or { panic('#${id} has no style') }
		excluded_state := result.state.try_get(excluded_styled) or {
			panic('#${id} has no used values')
		}
		assert !can_skip_automatic_minimum_size_for_item(excluded_node, excluded_state, flex_state, CSSPixels.new(100), true, CSSPixels.new(80))
	}
	mut item_box := item_node.as_box() or { panic('#item is not a box') }
	item_box.reset_cached_intrinsic_sizes()
	mut measurement_state := result.state
	assert flex_used_main_minimum(mut measurement_state, item_node, item_state, true, CSSPixels.new(80), true).raw_value() == 0
	assert item_box.cached_intrinsic_sizes_ == none
	assert used_for_id(result, 'item').content_width().to_double() == 100
}

fn test_per_item_skipped_minimum_is_restored_for_flex_violations() {
	row_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap; width:80px }
		#item { flex:0.1 1 auto; width:100px; white-space:nowrap }
	</style><div id="flex"><div id="item">content wider than the specified width</div></div>')
	row_result := run_document_layout(row_document, 800, 600) or { panic('layout failed') }
	// The per-item proof skips the hypothetical minimum, but the unfrozen
	// violation pass must restore the specified-size-capped 100px minimum.
	assert used_for_id(row_result, 'item').content_width().to_double() == 100

	column_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-flow:column wrap; width:100px; height:80px }
		#item { flex:0.1 1 auto; height:100px }
		#child { height:120px }
	</style><div id="flex"><div id="item"><div id="child"></div></div></div>')
	column_result := run_document_layout(column_document, 800, 600) or {
		panic('column layout failed')
	}
	assert used_for_id(column_result, 'item').content_height().to_double() == 100
}

fn test_skipped_hypothetical_minimum_is_restored_for_flex_violations() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:200px }
		#item { flex:0.1 1 20px; width:100px; white-space:nowrap }
	</style><div id="flex"><div id="item">content wider than the specified width</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// The initial hypothetical-size pass can skip the automatic minimum, but
	// resolve_flexible_lengths_for_line() must still apply its real 100px cap
	// when fixing the unfrozen item's minimum violation.
	assert used_for_id(result, 'item').content_width().to_double() == 100
}

fn test_flex_wrap_collects_lines_using_outer_hypothetical_sizes() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap; align-content:flex-start; width:100px }
		#one, #two { flex:0 1 10px; min-width:70px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.y().to_double() == 0
	assert used_for_id(result, 'two').offset.y().to_double() == 10
}

fn test_column_flex_automatic_minimum_size_is_content_based() {
	document := html.parse_document('<!doctype html><style>
		.flex { display:flex; flex-direction:column; width:40px; height:50px }
		.item { flex:0 1 200px }
		.child { height:80px }
		#zero { min-height:0 }
		#scroll { overflow:auto }
	</style>
	<div class="flex"><div id="auto-column" class="item"><div class="child"></div></div></div>
	<div class="flex"><div id="zero" class="item"><div class="child"></div></div></div>
	<div class="flex"><div id="scroll" class="item"><div class="child"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'auto-column').content_height().to_double() == 80
	assert used_for_id(result, 'zero').content_height().to_double() == 50
	assert used_for_id(result, 'scroll').content_height().to_double() == 50
}

fn test_nested_flex_with_parent_resolved_size_skips_intrinsic_relayout() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:100px; height:50px }
		#item { flex:0 0 content }
	</style><div id="flex"><div id="item"><span>expensive intrinsic content</span></div></div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	flex_node := layout_node_with_id(result.root, 'flex') or { panic('missing #flex') }
	item_node := layout_node_with_id(result.root, 'item') or { panic('missing #item') }
	flex_styled := flex_node.as_node_with_style() or { panic('#flex has no style') }
	mut measurement_state := result.state
	mut flex_state := measurement_state.get_mutable(flex_styled)
	mut item_box := item_node.as_box() or { panic('#item is not a box') }
	item_box.reset_cached_intrinsic_sizes()
	assert item_box.cached_intrinsic_sizes_ == none
	result_ := run_flex_formatting_context_with_mode(mut measurement_state, flex_node, mut flex_state, .intrinsic_sizing, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(100)), AvailableSize.make_definite(CSSPixels.new(50))))
	assert result_.automatic_content_width.to_double() == 100
	assert result_.automatic_content_height.to_double() == 50
	assert item_box.cached_intrinsic_sizes_ == none
}

fn test_nested_grid_with_parent_resolved_size_skips_intrinsic_relayout() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; height:50px; grid-template-columns:auto }
	</style><div id="grid"><div id="item"><span>expensive intrinsic content</span></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid_node := layout_node_with_id(result.root, 'grid') or { panic('missing #grid') }
	item_node := layout_node_with_id(result.root, 'item') or { panic('missing #item') }
	grid_styled := grid_node.as_node_with_style() or { panic('#grid has no style') }
	mut measurement_state := result.state
	mut grid_state := measurement_state.get_mutable(grid_styled)
	mut item_box := item_node.as_box() or { panic('#item is not a box') }
	item_box.reset_cached_intrinsic_sizes()
	assert item_box.cached_intrinsic_sizes_ == none
	result_ := run_grid_formatting_context(mut measurement_state, grid_node, mut grid_state, .intrinsic_sizing, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(100)), AvailableSize.make_definite(CSSPixels.new(50))))
	assert result_.automatic_content_width.to_double() == 100
	assert result_.automatic_content_height.to_double() == 50
	assert item_box.cached_intrinsic_sizes_ == none
}

fn test_flex_automatic_minimum_uses_transferred_aspect_ratio_suggestion() {
	document := html.parse_document('<!doctype html><style>
		.flex { display:flex; width:20px }
		.item { flex:0 1 200px; height:40px; aspect-ratio:2/1 }
		#maximum { max-width:60px }
	</style>
	<div class="flex"><div id="ratio" class="item"></div></div>
	<div class="flex"><div id="maximum" class="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'ratio').content_width().to_double() == 80
	assert used_for_id(result, 'maximum').content_width().to_double() == 60
}

fn test_flex_basis_intrinsic_sizing_keywords_choose_their_matching_contribution() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:500px }
		.item { flex-grow:0; flex-shrink:0; width:0; min-width:0; white-space:normal }
		#minimum { flex-basis:min-content }
		#maximum { flex-basis:max-content }
		#fit { flex-basis:fit-content }
		#auto { flex-basis:auto }
	</style><div id="flex">
		<div id="minimum" class="item">foo bar baz</div>
		<div id="maximum" class="item">foo bar baz</div>
		<div id="fit" class="item">foo bar baz</div>
		<div id="auto" class="item">foo bar baz</div>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	minimum := used_for_id(result, 'minimum').content_width().to_double()
	maximum := used_for_id(result, 'maximum').content_width().to_double()
	assert minimum > 0
	assert maximum > minimum
	assert used_for_id(result, 'fit').content_width().to_double() == maximum
	assert used_for_id(result, 'auto').content_width().to_double() == 0
}

fn test_column_flex_intrinsic_cross_size_resolves_percentage_minimum_in_second_pass() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column }
		#item { min-width:200% }
		#content { width:50px; height:10px }
	</style><div id="flex"><div id="item"><div id="content"></div></div></div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	flex_node := layout_node_with_id(result.root, 'flex') or { panic('missing #flex') }
	item_node := layout_node_with_id(result.root, 'item') or { panic('missing #item') }
	mut flex_box := flex_node.as_box() or { panic('#flex is not a box') }
	mut item_box := item_node.as_box() or { panic('#item is not a box') }
	flex_box.reset_cached_intrinsic_sizes()
	item_box.reset_cached_intrinsic_sizes()
	mut measurement_state := result.state
	// Pass one ignores the cyclic percentage and gets 50px from the content.
	// Pass two resolves min-width:200% against that result, producing 100px.
	assert calculate_min_content_width(mut measurement_state, flex_box).to_double() == 100
	assert calculate_max_content_width(mut measurement_state, flex_box).to_double() == 100
}

fn test_wrapped_column_flex_max_content_cross_size_sums_flex_lines() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-flow:column wrap; height:50px; column-gap:10px }
		.item { flex:none; width:40px; height:40px }
	</style><div id="flex"><div class="item"></div><div class="item"></div></div>')
	mut result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	flex_node := layout_node_with_id(result.root, 'flex') or { panic('missing #flex') }
	mut flex_box := flex_node.as_box() or { panic('#flex is not a box') }
	flex_box.reset_cached_intrinsic_sizes()
	mut measurement_state := result.state
	// Multi-line column min-content sizing uses the largest item contribution,
	// while max-content layout forms two 40px columns with the 10px gap.
	assert calculate_min_content_width(mut measurement_state, flex_box).to_double() == 40
	assert calculate_max_content_width(mut measurement_state, flex_box).to_double() == 90
}

fn test_flex_content_basis_uses_definite_cross_size_and_aspect_ratio() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:200px }
		#item { flex:0 0 content; min-width:0; height:40px; aspect-ratio:2/1 }
	</style><div id="flex"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'item').content_width().to_double() == 80
}

fn test_column_flex_base_size_is_adjusted_through_natural_aspect_ratio() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:200px; height:300px; align-items:flex-start }
		#item { flex:0 0 100px; max-width:100px }
	</style><div id="flex"><canvas id="item"></canvas></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// The 2:1 canvas starts with a 100px flex basis. Its 100px cross maximum
	// transfers back through the ratio, reducing that main-axis base to 50px.
	assert used_for_id(result, 'item').content_width().to_double() == 100
	assert used_for_id(result, 'item').content_height().to_double() == 50
}

fn test_row_flex_baseline_alignment_uses_each_items_last_line_baseline() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; align-items:baseline; width:200px; height:100px }
		#one, #two { flex:none; width:50px }
		#one { font-size:40px; line-height:40px }
		#two { font-size:20px; line-height:20px }
	</style><div id="flex"><div id="one">A</div><div id="two">B</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one_node := layout_node_with_id(result.root, 'one') or { panic('missing #one') }
	two_node := layout_node_with_id(result.root, 'two') or { panic('missing #two') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	one_baseline := one.offset.y().plus(layout_box_baseline(result.state, one_node))
	two_baseline := two.offset.y().plus(layout_box_baseline(result.state, two_node))
	assert one_baseline.raw_value() == two_baseline.raw_value()
	assert one.offset.y().to_double() == 0
	assert two.offset.y().to_double() > 0
}

fn test_relative_insets_resolve_against_the_containing_block_without_changing_flow_offsets() {
	document := html.parse_document('<!doctype html><style>
		#parent { width:200px }
		#first { position:relative; left:10%; right:70px; top:50%; width:20px; height:10px }
		#second { position:relative; right:30px; width:20px; height:10px }
	</style><div id="parent"><div id="first"></div><div id="second"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	assert first.inset_left.to_double() == 20
	assert first.inset_right.to_double() == -20
	// The containing block has automatic height, so a percentage block inset behaves as auto.
	assert first.inset_top.to_double() == 0
	assert first.offset.x().to_double() == 0
	assert first.offset.y().to_double() == 0
	assert second.inset_left.to_double() == -30
	assert second.inset_right.to_double() == 30
	assert second.offset.x().to_double() == 0
	assert second.offset.y().to_double() == 10
}

fn test_multicol_used_column_count_and_width_follow_the_upstream_pseudo_algorithm() {
	document := html.parse_document('<!doctype html><style>
		.box { font-size:20px }
		#count { column-count:3 }
		#width { column-width:100px; column-gap:20px }
		#both { column-count:5; column-width:100px; column-gap:20px }
		#ordinary { column-count:auto; column-width:auto }
	</style><div id="count" class="box"></div><div id="width" class="box"></div>
	<div id="both" class="box"></div><div id="ordinary" class="box"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	count := layout_node_with_id(result.root, 'count') or { panic('missing #count') }
	width := layout_node_with_id(result.root, 'width') or { panic('missing #width') }
	both := layout_node_with_id(result.root, 'both') or { panic('missing #both') }
	ordinary := layout_node_with_id(result.root, 'ordinary') or { panic('missing #ordinary') }
	assert determine_used_multicol_column_count(count, css_px(300)) or { 0 } == 3
	assert determine_used_multicol_column_width(count, css_px(300), 3).to_double() == 86.671875
	assert determine_used_multicol_column_count(width, css_px(350)) or { 0 } == 3
	assert determine_used_multicol_column_width(width, css_px(350), 3).to_double() == 103.328125
	assert determine_used_multicol_column_count(both, css_px(350)) or { 0 } == 3
	assert determine_used_multicol_column_count(ordinary, css_px(350)) == none
}

fn test_column_flex_main_size_uses_content_box_target_for_border_box_item() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:100px; height:100px }
		#item { box-sizing:border-box; flex:none; width:20px; height:80px; padding:10px }
	</style><div id="flex"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_height().to_double() == 60
	assert item.border_box_height().to_double() == 80
}

fn test_column_flex_stretched_cross_size_respects_border_box_max_width() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:100px; height:100px }
		#item { box-sizing:border-box; max-width:60px; height:20px; padding:10px }
	</style><div id="flex"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 40
	assert item.border_box_width().to_double() == 60
	assert item.offset.x().to_double() == 10
}

fn test_row_reverse_flex_end_and_space_between_use_reversed_physical_offsets() {
	end_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:row-reverse; justify-content:flex-end; width:300px }
		#one, #two { flex:none; width:50px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	end_result := run_document_layout(end_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(end_result, 'one').offset.x().to_double() == 50
	assert used_for_id(end_result, 'two').offset.x().to_double() == 0

	between_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:row-reverse; justify-content:space-between; width:300px }
		#one, #two { flex:none; width:50px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	between_result := run_document_layout(between_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(between_result, 'one').offset.x().to_double() == 250
	assert used_for_id(between_result, 'two').offset.x().to_double() == 0
}

fn test_column_reverse_places_flex_start_at_reversed_main_edge() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column-reverse; width:100px; height:300px }
		#one, #two { flex:none; width:10px; height:50px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.y().to_double() == 250
	assert two.offset.y().to_double() == 200
}

fn test_row_reverse_justify_start_remains_physical_inline_start() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:row-reverse; justify-content:start; width:300px }
		#one, #two { flex:none; width:50px; height:10px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 50
	assert used_for_id(result, 'two').offset.x().to_double() == 0
}

fn test_rtl_column_flex_cross_start_is_right_edge() {
	start_document := html.parse_document('<!doctype html><style>
		#flex { direction:rtl; display:flex; flex-direction:column; align-items:flex-start;
			width:100px; height:100px }
		#item { width:20px; height:20px }
	</style><div id="flex"><div id="item"></div></div>')
	start_result := run_document_layout(start_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(start_result, 'item').offset.x().to_double() == 80

	end_document := html.parse_document('<!doctype html><style>
		#flex { direction:rtl; display:flex; flex-direction:column; align-items:flex-end;
			width:100px; height:100px }
		#item { width:20px; height:20px }
	</style><div id="flex"><div id="item"></div></div>')
	end_result := run_document_layout(end_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(end_result, 'item').offset.x().to_double() == 0
}

fn test_wrapping_column_flex_forms_columns_and_stretches_line_cross_sizes() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:wrap; width:200px; height:100px }
		#one, #two { flex:none; width:20px; height:60px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.x().to_double() == 0
	assert one.offset.y().to_double() == 0
	assert two.offset.x().to_double() == 100
	assert two.offset.y().to_double() == 0
}

fn test_wrapping_column_flex_applies_column_gap_and_align_content() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:wrap; align-content:flex-start;
			column-gap:10px; width:200px; height:100px }
		#one, #two { flex:none; width:20px; height:60px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').offset.x().to_double() == 30
}

fn test_rtl_and_wrap_reverse_flip_wrapping_column_flex_cross_axis() {
	rtl_document := html.parse_document('<!doctype html><style>
		#flex { direction:rtl; display:flex; flex-direction:column; flex-wrap:wrap;
			width:200px; height:100px }
		#one, #two { flex:none; width:20px; height:60px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	rtl_result := run_document_layout(rtl_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(rtl_result, 'one').offset.x().to_double() == 180
	assert used_for_id(rtl_result, 'two').offset.x().to_double() == 80

	reverse_document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:wrap-reverse;
			width:200px; height:100px }
		#one, #two { flex:none; width:20px; height:60px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	reverse_result := run_document_layout(reverse_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(reverse_result, 'one').offset.x().to_double() == 180
	assert used_for_id(reverse_result, 'two').offset.x().to_double() == 80
}

fn test_wrapping_column_reverse_places_each_line_from_bottom_main_edge() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column-reverse; flex-wrap:wrap;
			width:200px; height:100px }
		#one, #two { flex:none; width:20px; height:60px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.y().to_double() == 40
	assert used_for_id(result, 'two').offset.y().to_double() == 40
}

fn test_wrap_reverse_flips_item_cross_start_within_flex_line() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-wrap:wrap-reverse; align-content:flex-start;
			align-items:flex-start; width:100px; height:100px }
		#large, #small { flex:none; width:40px }
		#large { height:30px } #small { height:10px }
		#next { flex:none; width:80px; height:10px }
	</style><div id="flex"><div id="large"></div><div id="small"></div><div id="next"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	large := used_for_id(result, 'large')
	small := used_for_id(result, 'small')
	assert small.offset.y().to_double() == large.offset.y().to_double() + 20
}

fn test_intrinsic_width_keywords_relayout_content_under_constraints() {
	document := html.parse_document('<!doctype html><style>
		#maximum { width:max-content; font-size:16px }
		#minimum { width:min-content; font-size:16px }
		#flex { display:flex; width:max-content }
		#fixed { width:100px; height:10px; flex:none }
	</style><div id="maximum">short longer</div><div id="minimum">short longer</div><div id="flex"><div id="fixed"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	maximum := used_for_id(result, 'maximum')
	minimum := used_for_id(result, 'minimum')
	flex := used_for_id(result, 'flex')
	assert maximum.content_width().to_double() > minimum.content_width().to_double()
	assert minimum.content_width().to_double() > 0
	assert flex.content_width().to_double() == 100
}

fn test_intrinsic_min_and_max_width_constraints_clamp_used_width() {
	document := html.parse_document('<!doctype html><style>
		#maximum { width:400px; max-width:max-content }
		#minimum { width:1px; min-width:min-content }
	</style><div id="maximum">short longer</div><div id="minimum">short longer</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	maximum := used_for_id(result, 'maximum')
	minimum := used_for_id(result, 'minimum')
	assert maximum.content_width().to_double() < 400
	assert maximum.content_width().to_double() > 0
	assert minimum.content_width().to_double() > 1
}

fn test_grid_formatting_context_sizes_fr_tracks_and_gap() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:1fr 2fr; gap:10px }
		#one, #two { height:20px }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() > 96.6 && one.content_width().to_double() < 96.7
	assert two.content_width().to_double() > 193.3 && two.content_width().to_double() < 193.4
	assert two.offset.x().to_double() > 106.6 && two.offset.x().to_double() < 106.7
	assert two.offset.y().to_double() == 0
}

fn test_grid_max_content_flexible_track_accounts_for_spanning_item() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:max-content; grid-template-columns:50px 1fr }
		#item { grid-column:1 / 3; width:200px; height:10px }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	item := used_for_id(result, 'item')
	assert grid.content_width().to_double() == 200
	assert item.content_width().to_double() == 200
}

fn test_grid_spanning_item_minimum_grows_flexible_track_before_expansion() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; grid-template-columns:50px 1fr }
		#span { grid-column:1 / 3; width:200px; height:10px }
		#flex { grid-column:2; height:10px }
	</style><div id="grid"><div id="span"></div><div id="flex"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	span := used_for_id(result, 'span')
	flex := used_for_id(result, 'flex')
	assert grid.content_width().to_double() == 100
	assert span.content_width().to_double() == 200
	assert flex.offset.x().to_double() == 50
	assert flex.content_width().to_double() == 150
}

fn test_grid_spanning_intrinsic_distribution_freezes_at_growth_limits() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:max-content;
			grid-template-columns:minmax(auto, 50px) minmax(auto, 200px) }
		#span { grid-column:1 / 3; width:300px; height:10px }
		#first { grid-column:1; height:10px }
		#second { grid-column:2; height:10px }
	</style><div id="grid"><div id="span"></div><div id="first"></div><div id="second"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	assert grid.content_width().to_double() == 300
	assert first.content_width().to_double() == 75
	assert second.offset.x().to_double() == 75
	assert second.content_width().to_double() == 225
}

fn test_grid_fixed_minimum_does_not_become_an_intrinsic_base_size() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; grid-template-columns:minmax(50px, max-content) }
		#wide { width:200px; height:10px }
		#probe { height:10px }
	</style><div id="grid"><div id="wide"></div><div id="probe"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	wide := used_for_id(result, 'wide')
	probe := used_for_id(result, 'probe')
	assert grid.content_width().to_double() == 100
	assert wide.content_width().to_double() == 200
	assert probe.content_width().to_double() == 100
}

fn test_grid_spanning_item_increases_intrinsic_growth_limits() {
	mut tracks := [GridTrack{
		max_content_max: true
	}, GridTrack{
		max_content_max: true
	}]
	distribute_grid_item_contribution_across_intrinsic_track_growth_limits(mut tracks, 0, 2, CSSPixels.new(0), CSSPixels.new(300), .intrinsic_maximum)
	assert tracks[0].has_growth_limit
	assert tracks[0].growth_limit.to_double() == 150
	assert tracks[1].growth_limit.to_double() == 150

	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:max-content;
			grid-template-columns:minmax(0px, max-content) minmax(0px, max-content) }
		#span { grid-column:1 / 3; width:300px; height:10px }
	</style><div id="grid"><div id="span"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	span := used_for_id(result, 'span')
	assert grid.content_width().to_double() == 300
	assert span.content_width().to_double() == 300
}

fn test_grid_maximum_width_retries_track_maximization() {
	mut tracks := [GridTrack{
		has_growth_limit: true
		growth_limit: CSSPixels.new(100)
	}, GridTrack{
		has_growth_limit: true
		growth_limit: CSSPixels.new(100)
	}]
	maximize_grid_tracks(mut tracks, AvailableSize.make_max_content(), CSSPixels.new(0), CSSPixels.new(100))
	assert tracks[0].base_size.to_double() == 50
	assert tracks[1].base_size.to_double() == 50

	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:max-content; max-width:100px;
			grid-template-columns:minmax(0px, max-content) minmax(0px, max-content) }
		#one, #two { width:100px; height:10px }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert grid.content_width().to_double() == 100
	assert one.content_width().to_double() == 100
	assert two.offset.x().to_double() == 50
}

fn test_grid_definite_available_height_limits_row_maximization() {
	mut rows := [GridTrack{
		has_growth_limit: true
		growth_limit: CSSPixels.new(200)
	}]
	maximize_grid_tracks(mut rows, AvailableSize.make_definite(CSSPixels.new(100)), CSSPixels.new(0), none)
	assert rows[0].base_size.to_double() == 100

	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; align-content:start;
			grid-template-rows:minmax(0px, max-content) }
		#item, #probe { grid-row:1; grid-column:1 }
		#item { height:200px }
	</style><div id="grid"><div id="item"></div><div id="probe"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid_node := layout_node_with_id(result.root, 'grid') or { panic('missing #grid') }
	grid_styled := grid_node.as_node_with_style() or { panic('#grid has no style') }
	mut relayout_state := result.state
	mut grid_state := relayout_state.get_mutable(grid_styled)
	assert !grid_state.has_definite_height()
	run_grid_formatting_context(mut relayout_state, grid_node, mut grid_state, .normal, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(100)), AvailableSize.make_definite(CSSPixels.new(100))))
	probe_node := layout_node_with_id(result.root, 'probe') or { panic('missing #probe') }
	probe_styled := probe_node.as_node_with_style() or { panic('#probe has no style') }
	assert relayout_state.get(probe_styled).content_height().to_double() == 100
}

fn test_grid_indefinite_flexible_row_accounts_for_spanning_item() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; grid-template-rows:50px 1fr }
		#item { grid-row:1 / 3; height:200px }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	item := used_for_id(result, 'item')
	assert grid.content_height().to_double() == 200
	assert item.content_height().to_double() == 200
}

fn test_grid_multispan_flexible_row_uses_zero_automatic_minimum() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; height:100px; align-content:start;
			grid-template-rows:50px 1fr }
		#span { grid-row:1 / 3 }
		#content { height:200px }
		#probe { grid-row:2 }
	</style><div id="grid"><div id="span"><div id="content"></div></div><div id="probe"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	span := used_for_id(result, 'span')
	probe := used_for_id(result, 'probe')
	assert span.content_height().to_double() == 100
	assert probe.offset.y().to_double() == 50
	assert probe.content_height().to_double() == 50
}

fn test_grid_intrinsic_flexible_row_uses_limited_min_content_contribution() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:100px; height:min-content; max-height:50px;
			grid-template-rows:minmax(0px, 1fr) }
		#item { min-height:0 }
		#content { height:100px }
	</style><div id="grid"><div id="item"><div id="content"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	item := used_for_id(result, 'item')
	assert grid.content_height().to_double() == 50
	assert item.content_height().to_double() == 50
}

fn test_grid_percentage_gaps_resolve_against_their_axis_available_size() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:200px; height:100px; align-content:start;
			grid-template-columns:100px; grid-template-rows:20px 20px; row-gap:10% }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.y().to_double() == 0
	assert used_for_id(result, 'two').offset.y().to_double() == 30
}

fn test_grid_auto_placement_expands_repeat_and_accommodates_largest_span() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:repeat(3, 1fr) }
		#feature, #card { height:40px }
		#feature { grid-column:span 2 }
	</style><div id="grid"><div id="feature"></div><div id="card"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	feature := used_for_id(result, 'feature')
	card := used_for_id(result, 'card')
	assert feature.content_width().to_double() == 200
	assert card.content_width().to_double() == 100
	assert feature.offset.x().to_double() == 0
	assert card.offset.x().to_double() == 200
	assert card.offset.y().to_double() == feature.offset.y().to_double()
}

fn test_grid_auto_placement_uses_order_modified_document_order() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:400px; grid-template-columns:repeat(4, 1fr) }
		#last { order:2 } #first, #also-first { order:-1 }
	</style><div id="grid"><div id="last"></div><div id="first"></div><div id="middle"></div><div id="also-first"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'first').offset.x().to_double() == 0
	assert used_for_id(result, 'also-first').offset.x().to_double() == 100
	assert used_for_id(result, 'middle').offset.x().to_double() == 200
	assert used_for_id(result, 'last').offset.x().to_double() == 300
}

fn test_grid_occupation_uses_distinct_packed_signed_coordinates() {
	mut occupied := map[u64]bool{}
	placement := GridItemPlacement{
		row: -2
		column: -3
		row_span: 2
		column_span: 2
	}
	occupy_grid_area(mut occupied, placement)
	assert !grid_area_is_free(occupied, -2, -3, 2, 2)
	assert grid_area_is_free(occupied, -3, -2, 1, 1)
	assert grid_cell_key(-1, 0) != grid_cell_key(0, -1)
	assert occupied.len == 4
}

fn test_grid_dense_auto_placement_backfills_earlier_holes() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:repeat(3, 1fr); grid-auto-flow:dense }
		.wide { grid-column:span 2 } .wide, #backfill { height:10px }
	</style><div id="grid"><div class="wide" id="one"></div><div class="wide" id="two"></div><div id="backfill"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	backfill := used_for_id(result, 'backfill')
	assert one.offset.x().to_double() == 0
	assert two.offset.x().to_double() == 0
	assert two.offset.y().to_double() > one.offset.y().to_double()
	assert backfill.offset.x().to_double() == 200
	assert backfill.offset.y().to_double() == one.offset.y().to_double()
}

fn test_grid_position_can_be_derived_from_definite_end_line() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:repeat(3, 1fr) }
		#item { grid-column:auto / 4 }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 100
	assert item.offset.x().to_double() == 200
}

fn test_grid_auto_fill_repeats_definite_tracks_to_fill_available_width() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:250px; column-gap:10px; grid-template-columns:repeat(auto-fill, 100px) }
		#one, #two { height:10px }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() == 100
	assert two.content_width().to_double() == 100
	assert one.offset.x().to_double() == 0
	assert two.offset.x().to_double() == 110
	assert two.offset.y().to_double() == one.offset.y().to_double()
}

fn test_grid_auto_fit_collapses_empty_flexible_repeated_tracks() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:repeat(auto-fit, minmax(100px, 1fr)) }
	</style><div id="grid"><div id="only"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	only := used_for_id(result, 'only')
	assert only.content_width().to_double() == 300
	assert only.offset.x().to_double() == 0
}

fn test_grid_implicit_tracks_use_grid_auto_column_and_row_sizes() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:100px; grid-template-rows:20px; grid-auto-columns:50px; grid-auto-rows:30px }
		#implicit { grid-column:2; grid-row:2 }
	</style><div id="grid"><div id="implicit"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'implicit')
	assert item.content_width().to_double() == 50
	assert item.content_height().to_double() == 30
	assert item.offset.x().to_double() == 100
	assert item.offset.y().to_double() == 20
}

fn test_grid_spanning_items_grow_intrinsic_columns_and_rows() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:200px; grid-template-columns:auto auto; grid-template-rows:auto auto }
		#spanning { width:200px; height:60px; grid-column:span 2; grid-row:span 2 }
		#after { grid-column:1; grid-row:4 }
	</style><div id="grid"><div id="spanning"></div><div id="after"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	spanning := used_for_id(result, 'spanning')
	after := used_for_id(result, 'after')
	assert spanning.content_width().to_double() == 200
	assert spanning.content_height().to_double() == 60
	// The empty non-spanning item gives the first auto track a zero growth
	// limit. C++ freezes that track and places the spanning contribution in the
	// still-unbounded second track.
	assert after.content_width().to_double() == 0
	assert after.offset.y().to_double() == 60
}

fn test_grid_default_content_alignment_stretches_auto_tracks() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:auto auto }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() == 150
	assert two.content_width().to_double() == 150
	assert two.offset.x().to_double() == 150
}

fn test_grid_item_with_definite_width_does_not_stretch_to_area() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:1fr }
		#item { width:100px }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 100
	assert item.offset.x().to_double() == 0
}

fn test_grid_content_alignment_positions_fixed_tracks_in_definite_container() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; height:100px; grid-template-columns:100px; grid-template-rows:20px; justify-content:center; align-content:center }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 100
	assert item.content_height().to_double() == 20
	assert item.offset.x().to_double() == 100
	assert item.offset.y().to_double() == 40
}

fn test_grid_space_between_adds_free_space_between_tracks() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:50px 50px; justify-content:space-between }
		#one, #two { height:10px }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').offset.x().to_double() == 250
}

fn test_grid_negative_and_reversed_line_numbers_resolve_against_explicit_grid() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:100px 100px 100px; grid-template-rows:20px 20px }
		#last { grid-column:-2 / -1; grid-row:1 }
		#reverse { grid-column:4 / 2; grid-row:2 }
	</style><div id="grid"><div id="last"></div><div id="reverse"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	last := used_for_id(result, 'last')
	reverse := used_for_id(result, 'reverse')
	assert last.offset.x().to_double() == 200
	assert last.content_width().to_double() == 100
	assert reverse.offset.x().to_double() == 100
	assert reverse.content_width().to_double() == 200
}

fn test_grid_negative_lines_before_explicit_grid_prepend_implicit_tracks() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:350px; grid-template-columns:100px 100px 100px; grid-auto-columns:50px }
		#before { grid-column:-5 / -4; grid-row:1 }
		#first { grid-column:1 / 2; grid-row:1 }
	</style><div id="grid"><div id="before"></div><div id="first"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	before := used_for_id(result, 'before')
	first := used_for_id(result, 'first')
	assert before.offset.x().to_double() == 0
	assert before.content_width().to_double() == 50
	assert first.offset.x().to_double() == 50
	assert first.content_width().to_double() == 100
}

fn test_grid_start_span_can_create_multiple_implicit_tracks_before_explicit_grid() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:340px; grid-template-columns:100px 100px 100px;
			grid-auto-columns:20px }
		#before { grid-column:span 2 / 1; height:10px }
		#first { grid-column:1 / 2; height:10px }
	</style><div id="grid"><div id="before"></div><div id="first"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	before := used_for_id(result, 'before')
	first := used_for_id(result, 'first')
	assert before.offset.x().to_double() == 0
	assert before.content_width().to_double() == 40
	assert first.offset.x().to_double() == 40
}

fn test_grid_named_lines_resolve_authored_start_and_end_names() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:[left] 100px [middle] 100px [right] 100px [end] }
		#item { grid-column:middle / end }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.offset.x().to_double() == 100
	assert item.content_width().to_double() == 200
}

fn test_grid_template_area_names_create_implicit_start_and_end_lines() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:200px; grid-template-columns:100px 100px; grid-template-rows:20px 30px; grid-template-areas:"head head" "side main" }
		#main { grid-area:main }
	</style><div id="grid"><div id="main"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'main')
	assert item.offset.x().to_double() == 100
	assert item.offset.y().to_double() == 20
	assert item.content_width().to_double() == 100
	assert item.content_height().to_double() == 30
}

fn test_grid_items_inherit_container_alignment_and_allow_self_overrides() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:200px; height:100px; grid-template-columns:200px; grid-template-rows:100px; justify-items:center; align-items:end }
		.item { width:40px; height:20px; grid-column:1; grid-row:1 }
		#override { justify-self:end; align-self:center }
	</style><div id="grid"><div id="inherited" class="item"></div><div id="override" class="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	inherited := used_for_id(result, 'inherited')
	override := used_for_id(result, 'override')
	assert inherited.offset.x().to_double() == 80
	assert inherited.offset.y().to_double() == 80
	assert override.offset.x().to_double() == 160
	assert override.offset.y().to_double() == 40
}

fn test_grid_auto_margins_absorb_free_space_before_self_alignment() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:200px; grid-template-columns:200px; justify-items:end }
		#item { width:40px; height:10px; margin-left:auto; margin-right:auto }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.offset.x().to_double() == 80
	assert item.margin_left.to_double() == 80
	assert item.margin_right.to_double() == 80
}

fn test_grid_normal_alignment_does_not_stretch_replaced_items() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; height:100px; grid-template-columns:300px; grid-template-rows:100px }
	</style><div id="grid"><canvas id="item" width="80" height="20"></canvas></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 80
	assert item.content_height().to_double() == 20
	assert item.offset.x().to_double() == 0
	assert item.offset.y().to_double() == 0
}

fn test_rtl_grid_places_logical_first_column_at_right_and_aligns_from_inline_start() {
	document := html.parse_document('<!doctype html><style>
		#grid { direction:rtl; display:grid; width:300px; grid-template-columns:100px 200px }
		#first { grid-column:1; width:20px; height:10px; justify-self:start }
		#second { grid-column:2; width:20px; height:10px; justify-self:end }
	</style><div id="grid"><div id="first"></div><div id="second"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	assert first.offset.x().to_double() == 280
	assert second.offset.x().to_double() == 0
}

fn test_rtl_grid_content_start_and_end_are_logical_while_left_is_physical() {
	start_document := html.parse_document('<!doctype html><style>
		#grid { direction:rtl; display:grid; justify-content:start; width:300px;
			grid-template-columns:100px }
		#item { width:100px; height:10px }
	</style><div id="grid"><div id="item"></div></div>')
	start_result := run_document_layout(start_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(start_result, 'item').offset.x().to_double() == 200

	end_document := html.parse_document('<!doctype html><style>
		#grid { direction:rtl; display:grid; justify-content:end; width:300px;
			grid-template-columns:100px }
		#item { width:100px; height:10px }
	</style><div id="grid"><div id="item"></div></div>')
	end_result := run_document_layout(end_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(end_result, 'item').offset.x().to_double() == 0

	left_document := html.parse_document('<!doctype html><style>
		#grid { direction:rtl; display:grid; justify-content:left; width:300px;
			grid-template-columns:100px }
		#item { width:100px; height:10px }
	</style><div id="grid"><div id="item"></div></div>')
	left_result := run_document_layout(left_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(left_result, 'item').offset.x().to_double() == 0
}

fn test_rtl_absolutely_positioned_grid_child_uses_physical_grid_area_rect() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; direction:rtl; display:grid; width:300px; height:100px;
			grid-template-columns:100px 200px }
		#absolute { position:absolute; grid-column:1; left:0; top:0; width:20px; height:10px }
	</style><div id="grid"><div id="absolute"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 200
}

fn test_grid_item_percentages_and_border_box_resolve_against_grid_area() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; height:100px; grid-template-columns:100px 200px;
			grid-template-rows:100px }
		#item { grid-column:2; box-sizing:border-box; width:50%; height:50%; padding:10px }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 80
	assert item.content_height().to_double() == 30
	assert item.border_box_width().to_double() == 100
	assert item.border_box_height().to_double() == 50
	assert item.offset.x().to_double() == 110
	assert item.offset.y().to_double() == 10
}

fn test_grid_forced_item_sizes_apply_min_max_with_border_box_sizing() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:200px; height:100px; grid-template-columns:100px 100px;
			grid-template-rows:100px }
		#minimum { box-sizing:border-box; width:20px; min-width:80px; height:20px;
			min-height:60px; padding:10px }
		#maximum { box-sizing:border-box; width:90px; max-width:60px; height:90px;
			max-height:50px; padding:10px }
	</style><div id="grid"><div id="minimum"></div><div id="maximum"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	minimum := used_for_id(result, 'minimum')
	maximum := used_for_id(result, 'maximum')
	assert minimum.content_width().to_double() == 60
	assert minimum.content_height().to_double() == 40
	assert minimum.border_box_width().to_double() == 80
	assert minimum.border_box_height().to_double() == 60
	assert maximum.content_width().to_double() == 40
	assert maximum.content_height().to_double() == 30
	assert maximum.border_box_width().to_double() == 60
	assert maximum.border_box_height().to_double() == 50
}

fn test_absolutely_positioned_grid_child_uses_its_grid_area_as_containing_block() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; display:grid; width:300px; height:100px;
			grid-template-columns:100px 200px; grid-template-rows:40px 60px }
		#item { position:absolute; grid-column:2; grid-row:2;
			left:0; top:0; width:20px; height:10px }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 20
	assert item.content_height().to_double() == 10
	assert item.offset.x().to_double() == 100
	assert item.offset.y().to_double() == 40
}

fn test_absolutely_positioned_grid_child_auto_insets_apply_self_alignment_in_grid_area() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; display:grid; width:300px; height:100px;
			grid-template-columns:100px 200px; grid-template-rows:40px 60px }
		#item { position:absolute; grid-column:2; grid-row:2; width:20px; height:10px;
			justify-self:center; align-self:end }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.offset.x().to_double() == 190
	assert item.offset.y().to_double() == 90
}

fn test_absolutely_positioned_grid_child_percentages_resolve_against_grid_area() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; display:grid; width:300px; height:100px;
			grid-template-columns:100px 200px; grid-template-rows:40px 60px }
		#item { position:absolute; grid-column:2; grid-row:2;
			left:10%; top:10%; width:50%; height:50% }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := used_for_id(result, 'item')
	assert item.content_width().to_double() == 100
	assert item.content_height().to_double() == 30
	assert item.offset.x().to_double() == 120
	assert item.offset.y().to_double() == 46
}

fn test_absolute_descendant_of_grid_item_uses_ancestor_grid_area() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; display:grid; width:300px; height:100px;
			grid-template-columns:100px 200px; grid-template-rows:100px }
		#grid-item { grid-column:2 }
		#absolute { position:absolute; left:0; top:0; width:20px; height:10px }
	</style><div id="grid"><div id="grid-item"><div id="absolute"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 100
	assert absolute.offset.y().to_double() == 0
}

fn test_positioned_grid_item_remains_nearer_abspos_containing_block() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; display:grid; width:300px; height:100px;
			grid-template-columns:100px 200px; grid-template-rows:100px }
		#grid-item { position:relative; grid-column:2 }
		#absolute { position:absolute; left:0; top:0; width:20px; height:10px }
	</style><div id="grid"><div id="grid-item"><div id="absolute"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid_item := used_for_id(result, 'grid-item')
	absolute := used_for_id(result, 'absolute')
	assert grid_item.offset.x().to_double() == 100
	assert absolute.offset.x().to_double() == 0
	assert absolute.offset.y().to_double() == 0
}

fn test_abspos_grid_line_at_end_uses_padding_edge_track_and_auto_axis_uses_padding_box() {
	document := html.parse_document('<!doctype html><style>
		#grid { position:relative; display:grid; width:150px; height:150px; padding:10px;
			grid-template-columns:50px 100px; grid-template-rows:50px 100px }
		#absolute { position:absolute; grid-column:3; left:0; top:0;
			width:100%; height:100% }
	</style><div id="grid"><div id="absolute"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.content_width().to_double() == 10
	assert absolute.content_height().to_double() == 170
	assert absolute.offset.x().to_double() == 150
	assert absolute.offset.y().to_double() == -10
}

fn test_table_formatting_context_builds_columns_and_rows() {
	document := html.parse_document('<!doctype html><style>
		table { width:300px; border-spacing:0 }
		td { height:20px; padding:0 }
	</style><table><tbody><tr><td id="one"></td><td id="two"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() == 150
	assert two.content_width().to_double() == 150
	assert one.offset.x().to_double() == 0
	assert two.offset.x().to_double() == 150
	assert one.offset.y().to_double() == 10
	assert two.offset.y().to_double() == 10
	assert one.padding_top.to_double() == 10
	assert one.padding_bottom.to_double() == 10
}

fn test_rtl_table_places_logical_first_column_at_right() {
	document := html.parse_document('<!doctype html><style>
		table { direction:rtl; width:300px; border-spacing:0; table-layout:fixed }
		td { padding:0; height:10px } #one { width:100px }
	</style><table><tbody><tr><td id="one"></td><td id="two"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.content_width().to_double() == 100
	assert two.content_width().to_double() == 200
	assert one.offset.x().to_double() == 200
	assert two.offset.x().to_double() == 0
}

fn test_rtl_table_cell_spanning_logical_columns_uses_mirrored_range() {
	document := html.parse_document('<!doctype html><style>
		table { direction:rtl; width:340px; border-spacing:10px; table-layout:fixed }
		col { width:100px } td { padding:0; height:10px }
	</style><table><col><col><col><tbody><tr><td id="span" colspan="2"></td><td id="last"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	span := used_for_id(result, 'span')
	last := used_for_id(result, 'last')
	assert span.content_width().to_double() == 210
	assert span.offset.x().to_double() == 120
	assert last.content_width().to_double() == 100
	assert last.offset.x().to_double() == 10
}

fn test_fixed_table_cell_border_box_width_is_not_counted_twice() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; border-spacing:0; table-layout:fixed }
		td { padding:0; height:10px }
		#first { box-sizing:border-box; width:100px; padding:10px }
	</style><table><tbody><tr><td id="first"></td><td id="second"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	assert first.content_width().to_double() == 80
	assert first.border_box_width().to_double() == 100
	assert second.content_width().to_double() == 100
	assert second.offset.x().to_double() == 100
}

fn test_table_auto_layout_uses_definite_cell_width_contributions() {
	document := html.parse_document('<!doctype html><style>
		table { width:160px; border-spacing:0 }
		td { padding:0 } #wide { width:120px } #narrow { width:40px }
	</style><table><tbody><tr><td id="wide"></td><td id="narrow"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	wide := used_for_id(result, 'wide')
	narrow := used_for_id(result, 'narrow')
	assert wide.content_width().to_double() == 120
	assert narrow.content_width().to_double() == 40
	assert narrow.offset.x().to_double() == 120
}

fn test_table_min_content_measure_does_not_use_the_cells_preferred_width() {
	document := html.parse_document('<!doctype html><style>
		table { width:min-content; border-spacing:0 } td { width:300px; padding:0 }
	</style><table id="table"><tr><td>x</td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// TableFormattingContext::compute_cell_measures() defines outer min-content
	// from max(min-width, min-content), without the preferred width.
	assert used_for_id(result, 'table').content_width().to_double() < 50
}

fn test_constrained_table_column_uses_cell_min_content_for_its_max_measure() {
	document := html.parse_document('<!doctype html><style>
		table { width:max-content; border-spacing:0 } col { width:100px } td { padding:0 }
	</style><table id="table"><col><tr><td>a a a a a a a a a a a a a a a a a a a a</td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// A cell originating in a constrained column contributes its min-content
	// width to the column's outer max-content measure.
	assert used_for_id(result, 'table').content_width().to_double() == 100
}

fn test_table_cell_margins_do_not_participate_in_grid_measurement_or_positioning() {
	document := html.parse_document('<!doctype html><style>
		table { width:100px; border-spacing:0 } td { margin:40px; padding:0 }
	</style><table><tr><td id="cell"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	cell := used_for_id(result, 'cell')
	assert cell.content_width().to_double() == 100
	assert cell.offset.x().to_double() == 0
}

fn test_table_spanning_cell_distributes_its_minimum_width_over_columns() {
	document := html.parse_document('<!doctype html><style>
		table { width:160px; border-spacing:0 } td { padding:0 }
		#span { width:160px }
	</style><table><tbody><tr><td id="span" colspan="2"></td></tr><tr><td id="left"></td><td id="right"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	span := used_for_id(result, 'span')
	left := used_for_id(result, 'left')
	right := used_for_id(result, 'right')
	assert span.content_width().to_double() == 160
	assert left.content_width().to_double() == 80
	assert right.content_width().to_double() == 80
	assert right.offset.x().to_double() == 80
}

fn test_table_captions_are_laid_out_above_and_below_the_grid() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; border-spacing:0 } caption { height:20px } td { height:20px; padding:0 }
	</style><table id="top-table"><caption id="top-caption">top</caption><tr><td id="top-cell"></td></tr></table>
	<table id="bottom-table"><caption id="bottom-caption" style="caption-side:bottom">bottom</caption><tr><td id="bottom-cell"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'top-caption').offset.y().to_double() == 0
	assert used_for_id(result, 'top-cell').offset.y().to_double() == 10
	assert used_for_id(result, 'top-table').content_height().to_double() == 20
	assert used_for_id(result, 'top-table').margin_bottom.to_double() == 20
	assert used_for_id(result, 'bottom-cell').offset.y().to_double() == 10
	assert used_for_id(result, 'bottom-caption').offset.y().to_double() == 20
	assert used_for_id(result, 'bottom-table').content_height().to_double() == 20
	assert used_for_id(result, 'bottom-table').margin_bottom.to_double() == 20
}

fn test_table_cell_vertical_alignment_distributes_extra_row_height_to_padding() {
	document := html.parse_document('<!doctype html><style>
		table { width:300px; border-spacing:0 } td { width:100px; padding:0 }
		#tall { height:60px; vertical-align:top } #middle { height:20px; vertical-align:middle } #bottom { height:20px; vertical-align:bottom }
	</style><table><tr><td id="tall"></td><td id="middle"></td><td id="bottom"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	middle := used_for_id(result, 'middle')
	bottom := used_for_id(result, 'bottom')
	assert middle.offset.y().to_double() == 30
	assert middle.padding_top.to_double() == 30
	assert middle.padding_bottom.to_double() == 30
	assert bottom.offset.y().to_double() == 60
	assert bottom.padding_top.to_double() == 60
}

fn test_table_rowspan_zero_grows_cell_through_remaining_rows() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; border-spacing:0 } td { width:100px; height:30px; padding:0 }
		#span { height:90px }
	</style><table><tbody id="body"><tr><td id="span" rowspan="0"></td><td id="one"></td></tr><tr><td id="two"></td></tr><tr><td id="three"></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	body := used_for_id(result, 'body')
	span := used_for_id(result, 'span')
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	three := used_for_id(result, 'three')
	assert span.offset.x().to_double() == 0
	assert span.content_height().to_double() == 0
	assert span.padding_top.to_double() == 45
	assert span.padding_bottom.to_double() == 45
	assert one.offset.x().to_double() == 100
	assert two.offset.x().to_double() == 100
	assert three.offset.x().to_double() == 100
	assert span.offset.y().to_double() == 45
	assert one.offset.y().to_double() == 15
	assert two.offset.y().to_double() == 45
	assert three.offset.y().to_double() == 75
	assert body.offset.x().to_double() == 0
	assert body.offset.y().to_double() == 0
	assert body.content_width().to_double() == 200
	assert body.content_height().to_double() == 90
}

fn test_fixed_table_layout_uses_first_row_widths_and_shares_unassigned_space() {
	document := html.parse_document('<!doctype html><style>
		table { width:600px; table-layout:fixed; border-spacing:0 } td { padding:0 }
		#last { width:300px }
	</style><table><tr><td id="one"></td><td id="two"></td><td id="three"></td><td id="last"></td></tr><tr><td></td><td></td><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 100
	assert used_for_id(result, 'two').content_width().to_double() == 100
	assert used_for_id(result, 'three').content_width().to_double() == 100
	assert used_for_id(result, 'last').content_width().to_double() == 300
	assert used_for_id(result, 'last').offset.x().to_double() == 300
}

fn test_fixed_table_equal_distribution_truncates_css_pixel_fractions() {
	mut widths := [CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(299)]
	assert distribute_table_excess_width_equally(mut widths, [true, true, true, false], CSSPixels.new(299))
	// CSSPixels(299) / 3 is a CSSPixelFraction in LibWeb. Its conversion back
	// to CSSPixels truncates 19136 raw units / 3 to 6378.
	assert widths[0].raw_value() == 6378
	assert widths[1].raw_value() == 6378
	assert widths[2].raw_value() == 6378
	assert widths[3] == CSSPixels.new(299)
}

fn test_table_wrapper_and_percentage_table_share_final_width_before_centering() {
	document := html.parse_document('<!doctype html><style>
		body { margin:8px } table { width:50%; border-spacing:0 }
	</style><center><table id="table"><tr><td></td></tr></table></center>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table_node := layout_node_with_id(result.root, 'table') or { panic('missing table') }
	table := used_for_id(result, 'table')
	wrapper_node := table_node.parent() or { panic('table has no wrapper') }
	wrapper_styled := wrapper_node.as_node_with_style() or { panic('wrapper has no style') }
	wrapper := result.used_values_for(wrapper_styled) or { panic('wrapper has no used values') }
	assert wrapper.content_width().to_double() == 392
	assert table.content_width().to_double() == 392
	assert wrapper.offset.x().to_double() == 196
	assert table.offset.x().to_double() == 0
}

fn test_empty_table_row_is_retained_when_the_grid_has_no_columns() {
	document := html.parse_document('<!doctype html><style>
		table { height:100px; padding:10px; border:1px solid; }
	</style><table><tr id="row"></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	row := used_for_id(result, 'row')
	assert row.content_width().to_double() == 0
	assert row.content_height().to_double() == 0
	assert row.offset.x().to_double() == 2
	assert row.offset.y().to_double() == 2
}

fn test_empty_table_row_group_uses_current_group_cursor() {
	document := html.parse_document('<!doctype html><style>
		table { width:100px; border-spacing:5px 7px }
		tr { height:10px } td { padding:0 }
	</style><table><tbody id="first"><tr><td></td></tr><tr><td></td></tr></tbody>
		<tbody id="empty"></tbody><tbody id="last"><tr><td></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first')
	empty := used_for_id(result, 'empty')
	last := used_for_id(result, 'last')
	assert first.offset.y().to_double() == 7
	assert first.content_height().to_double() == 27
	assert empty.offset.y().to_double() == 41
	assert empty.content_width().to_double() == 0
	assert empty.content_height().to_double() == 0
	assert last.offset.y().to_double() == 41
	assert last.content_height().to_double() == 10
}

fn test_fixed_table_layout_distributes_excess_proportionally_when_all_columns_are_sized() {
	document := html.parse_document('<!doctype html><style>
		table { width:600px; table-layout:fixed; border-spacing:0 } td { padding:0 }
		#one { width:50px } #two { width:50px } #three { width:100px } #four { width:300px }
	</style><table><tr><td id="one"></td><td id="two"></td><td id="three"></td><td id="four"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 60
	assert used_for_id(result, 'two').content_width().to_double() == 60
	assert used_for_id(result, 'three').content_width().to_double() == 120
	assert used_for_id(result, 'four').content_width().to_double() == 360
	assert used_for_id(result, 'four').offset.x().to_double() == 240
}

fn test_specified_table_row_height_establishes_row_minimum() {
	document := html.parse_document('<!doctype html><style>
		table { width:100px; border-spacing:0 } tr { height:50px } td { padding:0; vertical-align:top }
	</style><table><tr id="row"><td id="cell"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	row := used_for_id(result, 'row')
	cell := used_for_id(result, 'cell')
	assert row.content_height().to_double() == 50
	assert cell.padding_bottom.to_double() == 50
	assert cell.margin_box_height().to_double() == 50
}

fn test_table_column_elements_constrain_fixed_layout_column_widths() {
	document := html.parse_document('<!doctype html><style>
		table { width:300px; table-layout:fixed; border-spacing:0 } td { padding:0 }
	</style><table><colgroup><col style="width:50px"><col style="width:100px"><col></colgroup><tr><td id="one"></td><td id="two"></td><td id="three"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 50
	assert used_for_id(result, 'two').content_width().to_double() == 100
	assert used_for_id(result, 'three').content_width().to_double() == 150
	assert used_for_id(result, 'two').offset.x().to_double() == 50
	assert used_for_id(result, 'three').offset.x().to_double() == 150
}

fn test_table_column_constraints_receive_priority_in_auto_layout_excess_distribution() {
	document := html.parse_document('<!doctype html><style>
		table { width:300px; border-spacing:0 } td { padding:0 }
	</style><table><colgroup><col style="width:50px"><col style="width:100px"><col></colgroup><tr><td id="one"></td><td id="two"></td><td id="three"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 50
	assert used_for_id(result, 'two').content_width().to_double() == 100
	assert used_for_id(result, 'three').content_width().to_double() == 150
}

fn test_absolute_positioning_solves_inset_equations() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:300px; height:200px }
		#fill { position:absolute; left:10px; right:20px; top:15px; bottom:25px }
		#right { position:absolute; width:100px; height:30px; right:10px; top:5px }
	</style><div id="container"><div id="fill"></div><div id="right"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	fill := used_for_id(result, 'fill')
	right := used_for_id(result, 'right')
	assert fill.content_width().to_double() == 270
	assert fill.content_height().to_double() == 160
	assert fill.offset.x().to_double() == 10
	assert fill.offset.y().to_double() == 15
	assert right.content_width().to_double() == 100
	assert right.offset.x().to_double() == 190
	assert right.offset.y().to_double() == 5
}

fn test_absolute_positioning_resolves_border_box_sizes_to_content_box() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:300px; height:200px }
		#absolute { position:absolute; box-sizing:border-box; left:0; top:0;
			width:100px; height:80px; padding:10px; border:5px solid }
	</style><div id="container"><div id="absolute"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.content_width().to_double() == 70
	assert absolute.content_height().to_double() == 50
	assert absolute.border_box_width().to_double() == 100
	assert absolute.border_box_height().to_double() == 80
	assert absolute.offset.x().to_double() == 15
	assert absolute.offset.y().to_double() == 15
}

fn test_absolute_inset_size_and_min_max_constraints_respect_box_sizing() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:300px; height:200px }
		#fill { position:absolute; box-sizing:border-box; left:10px; right:20px;
			top:0; height:20px; padding:10px; border:5px solid }
		#minimum { position:absolute; box-sizing:border-box; left:0; top:40px;
			width:50px; min-width:100px; height:10px; padding:10px }
		#maximum { position:absolute; box-sizing:border-box; left:0; top:80px;
			width:200px; max-width:120px; height:10px; padding:10px }
		#overlap { position:absolute; left:200px; right:200px; top:120px; height:10px }
	</style><div id="container"><div id="fill"></div><div id="minimum"></div>
		<div id="maximum"></div><div id="overlap"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	fill := used_for_id(result, 'fill')
	minimum := used_for_id(result, 'minimum')
	maximum := used_for_id(result, 'maximum')
	overlap := used_for_id(result, 'overlap')
	assert fill.content_width().to_double() == 240
	assert fill.border_box_width().to_double() == 270
	assert minimum.content_width().to_double() == 80
	assert minimum.border_box_width().to_double() == 100
	assert maximum.content_width().to_double() == 100
	assert maximum.border_box_width().to_double() == 120
	assert overlap.content_width().to_double() == 0
}

fn test_block_abspos_auto_insets_use_normal_flow_static_position() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:100px }
		#flow { height:20px }
		#absolute { position:absolute; width:10px; height:10px }
	</style><div id="container"><div id="flow"></div><div id="absolute"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 0
	assert absolute.offset.y().to_double() == 20
}

fn test_inline_abspos_auto_insets_follow_previous_inline_fragment() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:100px }
		#atomic { display:inline-block; width:20px; height:10px }
		#absolute { position:absolute; width:10px; height:10px }
	</style><div id="container"><span id="atomic"></span><span id="absolute"></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 20
	assert absolute.offset.y().to_double() > 0
}

fn test_abspos_static_position_is_converted_to_actual_containing_block_space() {
	document :=
		html.parse_document('<!doctype html>foo <div id="absolute" style="position:absolute">bar</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.cumulative_offset().x().to_double() == 8
	assert absolute.cumulative_offset().y().to_double() == 26
}

fn test_flex_abspos_static_position_uses_main_and_cross_alignment() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; position:relative; width:100px; height:50px; justify-content:center; align-items:center }
		#absolute { position:absolute; width:10px; height:10px }
	</style><div id="flex"><div id="absolute"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 45
	assert absolute.offset.y().to_double() == 20
}

fn test_replaced_element_uses_intrinsic_dimensions() {
	document := html.parse_document('<!doctype html><canvas id="canvas"></canvas>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	canvas := used_for_id(result, 'canvas')
	assert canvas.content_width().to_double() == 300
	assert canvas.content_height().to_double() == 150
}

fn test_zero_canvas_dimensions_are_valid_intrinsic_dimensions() {
	document :=
		html.parse_document('<!doctype html><canvas id="canvas" width="0" height="0"></canvas>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	canvas := used_for_id(result, 'canvas')
	assert canvas.content_width().to_double() == 0
	assert canvas.content_height().to_double() == 0
}

fn test_css_aspect_ratio_overrides_and_auto_falls_back_to_replaced_natural_ratio() {
	overridden_document :=
		html.parse_document('<!doctype html><style>canvas { width:120px; height:auto; aspect-ratio:1/1 }</style><canvas id="canvas"></canvas>')
	overridden_result := run_document_layout(overridden_document, 800, 600) or {
		panic('layout failed')
	}
	overridden := used_for_id(overridden_result, 'canvas')
	assert overridden.content_width().to_double() == 120
	assert overridden.content_height().to_double() == 120

	auto_document :=
		html.parse_document('<!doctype html><style>canvas { width:120px; height:auto; aspect-ratio:auto 1/1 }</style><canvas id="canvas"></canvas>')
	auto_result := run_document_layout(auto_document, 800, 600) or { panic('layout failed') }
	auto_sized := used_for_id(auto_result, 'canvas')
	assert auto_sized.content_width().to_double() == 120
	assert auto_sized.content_height().to_double() == 60
}

fn test_non_replaced_auto_height_uses_preferred_aspect_ratio() {
	document :=
		html.parse_document('<!doctype html><style>#box { width:120px; aspect-ratio:2/1 }</style><div id="box"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	assert box.content_width().to_double() == 120
	assert box.content_height().to_double() == 60
	assert box.has_definite_height()
}

fn test_intrinsic_height_keyword_relays_out_block_children() {
	document := html.parse_document('<!doctype html><style>
		#box { width:100px; height:max-content }
		#child { height:30px }
	</style><div id="box"><div id="child"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	assert box.content_height().to_double() == 30
	assert box.has_definite_height()
}

fn test_intrinsic_min_and_max_height_constraints_clamp_used_height() {
	document := html.parse_document('<!doctype html><style>
		#maximum { width:100px; height:100px; max-height:max-content }
		#minimum { width:100px; height:1px; min-height:max-content }
		.child { height:30px }
	</style><div id="maximum"><div class="child"></div></div><div id="minimum"><div class="child"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'maximum').content_height().to_double() == 30
	assert used_for_id(result, 'minimum').content_height().to_double() == 30
}

fn test_svg_formatting_context_applies_viewbox_and_group_transforms_to_geometry() {
	document :=
		html.parse_document('<!doctype html><style>body { margin:0 }</style><svg id="svg" width="200" height="100" viewBox="0 0 100 50"><g id="group" transform="translate(10 5)"><rect id="shape" x="20" y="10" width="30" height="15"/></g></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	svg_state := used_for_id(result, 'svg')
	assert svg_state.content_width().to_double() == 200
	assert svg_state.content_height().to_double() == 100
	shape := used_for_id(result, 'shape')
	assert shape.offset.x().to_double() == 60
	assert shape.offset.y().to_double() == 30
	assert shape.content_width().to_double() == 60
	assert shape.content_height().to_double() == 30
	assert shape.computed_svg_path() or { panic('shape has no SVG path') }.serialize().starts_with('M 20')
	group := used_for_id(result, 'group')
	assert group.offset.x().to_double() == shape.offset.x().to_double()
	assert group.offset.y().to_double() == shape.offset.y().to_double()
	assert group.content_width().to_double() == shape.content_width().to_double()
	assert group.content_height().to_double() == shape.content_height().to_double()
}

fn test_svg_text_is_materialized_as_glyph_outline_path_like_cpp() {
	document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="200" height="100"><text id="label" x="20" y="40" font-size="20" fill="red" stroke="blue">O</text></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	label := used_for_id(result, 'label')
	path := label.computed_svg_path() or { panic('SVG text has no glyph outline path') }
	assert path.instructions.len > 6
	assert path.instructions[0].type_ == .move
	assert path.instructions.any(it.type_ == .quadratic_bezier_curve)
	assert path.instructions.any(it.type_ == .close_path)
	assert label.content_width().to_double() > 0
	assert label.content_height().to_double() > 0
}

fn test_svg_text_path_places_rotated_glyph_outlines_on_first_contour() {
	font := &platform.Font{
		family: 'sans-serif'
		point_size: 20
	}
	horizontal := svg_place_text_along_path(svg.parse_path_data('M 10 40 L 150 40'), 'OO', font)
	horizontal_bounds := svg_path_bounds(horizontal) or { panic('missing horizontal text path') }
	assert horizontal.instructions.any(it.type_ == .quadratic_bezier_curve)
	assert horizontal_bounds.width > horizontal_bounds.height

	vertical := svg_place_text_along_path(svg.parse_path_data('M 30 10 L 30 150'), 'OO', font)
	vertical_bounds := svg_path_bounds(vertical) or { panic('missing vertical text path') }
	assert vertical_bounds.height > vertical_bounds.width

	// SkPathMeasure measures its first contour only. A later long contour must
	// not rescue a glyph whose midpoint does not fit on the first one.
	short_first := svg_place_text_along_path(svg.parse_path_data('M 0 0 L 1 0 M 20 20 L 200 20'), 'O', font)
	assert short_first.instructions.len == 0
}

fn test_svg_text_path_dom_node_retains_only_the_placed_glyph_geometry() {
	document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="200" height="100"><defs><path id="guide" d="M 10 50 L 180 50"/></defs><text fill="red"><textPath id="label" href="#guide" font-size="24">OO</textPath></text></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	label := used_for_id(result, 'label')
	path := label.computed_svg_path() or { panic('textPath has no placed glyph path') }
	assert path.instructions.len > 12
	assert path.instructions.any(it.type_ == .quadratic_bezier_curve)
	assert label.content_width().to_double() > 20
	assert label.content_height().to_double() > 10
	// The referenced guide is not copied into the output path.
	assert path.serialize() != 'M 10 50 L 180 50'
}

fn test_svg_foreign_object_delegates_its_contents_to_block_layout() {
	document :=
		html.parse_document('<!doctype html><style>body { margin:0 } #html-child { height:8px }</style><svg width="200" height="100" viewBox="0 0 100 50"><foreignObject id="foreign" x="5" y="6" width="40" height="20"><div id="html-child"></div></foreignObject></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	foreign := used_for_id(result, 'foreign')
	assert foreign.offset.x().to_double() == 10
	assert foreign.offset.y().to_double() == 12
	assert foreign.content_width().to_double() == 80
	assert foreign.content_height().to_double() == 40
	html_child := used_for_id(result, 'html-child')
	assert html_child.content_width().to_double() == 80
	assert html_child.content_height().to_double() == 8
}

fn test_svg_computed_geometry_properties_override_presentation_attributes_where_upstream_uses_them() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#circle { cx:40px; cy:20px; r:10px }
		#nested { x:10px; y:5px; width:60px; height:30px }
		#foreign { x:7px; y:8px; width:25px; height:12px }
	</style><svg width="200" height="100" viewBox="0 0 100 50">
		<circle id="circle" cx="1" cy="2" r="3"/>
		<svg id="nested" x="1" y="2" width="3" height="4"></svg>
		<foreignObject id="foreign" x="1" y="2" width="3" height="4"></foreignObject>
	</svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	circle := used_for_id(result, 'circle')
	assert circle.computed_svg_path() or { panic('circle has no path') }.serialize().starts_with('M 50 20')
	assert circle.offset.x().to_double() == 60
	assert circle.offset.y().to_double() == 20
	assert circle.content_width().to_double() == 40
	assert circle.content_height().to_double() == 40
	nested := used_for_id(result, 'nested')
	assert nested.offset.x().to_double() == 20
	assert nested.offset.y().to_double() == 10
	assert nested.content_width().to_double() == 120
	assert nested.content_height().to_double() == 60
	foreign := used_for_id(result, 'foreign')
	assert foreign.offset.x().to_double() == 14
	assert foreign.offset.y().to_double() == 16
	assert foreign.content_width().to_double() == 50
	assert foreign.content_height().to_double() == 24
}

fn test_relative_positioning_does_not_move_following_flow_content() {
	document := html.parse_document('<!doctype html><style>
		#one { position:relative; top:20px; left:5px; height:10px }
		#two { height:10px }
	</style><div><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	assert one.offset.x().to_double() == 0
	assert one.offset.y().to_double() == 0
	assert one.inset_left.to_double() == 5
	assert one.inset_top.to_double() == 20
	assert two.offset.y().to_double() == 10
}

fn test_viewport_text_blocks_preserve_utf16_positions_and_find_in_page_boundaries() {
	document :=
		html.parse_document('<!doctype html><style>.hidden { visibility:hidden }</style><div>A<span>😀</span>C</div><div>D<span class="hidden">X</span><span inert>Y</span>E</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut viewport := result.root.as_viewport() or { panic('root is not a viewport') }
	blocks := viewport.text_blocks()
	assert blocks.len == 2
	assert blocks[0].text == 'A😀C'
	assert blocks[0].positions.len == 3
	assert blocks[0].positions[0].start_offset == 0
	assert blocks[0].positions[1].start_offset == 1
	assert blocks[0].positions[2].start_offset == 3
	assert blocks[1].text == 'DE'
	assert blocks[1].positions.len == 2
	assert blocks[1].positions[0].start_offset == 0
	assert blocks[1].positions[1].start_offset == 1
	viewport.invalidate_text_blocks_cache()
	assert viewport.text_blocks()[0].text == 'A😀C'
}

fn test_layout_node_stacking_context_rules_match_upstream() {
	document := html.parse_document('<!doctype html><style>
		#relative { position:relative }
		#positioned { position:relative; z-index:0 }
		#flex { display:flex }
		#flex-item { z-index:1 }
		#opaque { opacity:.5 }
		#future { will-change:opacity }
		#transformed { transform:translateX(1px) }
	</style><div id="plain"></div><div id="relative"></div><div id="positioned"></div><div id="flex"><div id="flex-item"></div></div><div id="opaque"></div><div id="future"></div><div id="transformed"></div><svg id="svg" style="opacity:.5"><g id="svg-group" style="opacity:.5"></g></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert result.root.establishes_stacking_context()
	assert result.root.first_child() or { panic('missing root element') }.establishes_stacking_context()
	assert !layout_node_with_id(result.root, 'plain') or { panic('missing plain') }.establishes_stacking_context()
	assert !layout_node_with_id(result.root, 'relative') or { panic('missing relative') }.establishes_stacking_context()
	for id in ['positioned', 'flex-item', 'opaque', 'future', 'transformed', 'svg'] {
		assert layout_node_with_id(result.root, id) or { panic('missing ${id}') }.establishes_stacking_context()
	}
	assert !layout_node_with_id(result.root, 'svg-group') or { panic('missing svg group') }.establishes_stacking_context()
}

fn test_floats_are_positioned_at_available_edges_and_clearance_moves_blocks_below_them() {
	document := html.parse_document('<!doctype html><style>
		#container { width:200px }
		#left { float:left; width:60px; height:40px }
		#right { float:right; width:50px; height:30px }
		#cleared { clear:both; height:10px }
	</style><div id="container"><div id="left"></div><div id="right"></div><div id="cleared"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	left := used_for_id(result, 'left')
	right := used_for_id(result, 'right')
	cleared := used_for_id(result, 'cleared')
	assert left.offset.x().to_double() == 0
	assert left.offset.y().to_double() == 0
	assert right.offset.x().to_double() == 150
	assert right.offset.y().to_double() == 0
	assert cleared.offset.y().to_double() == 40
}

fn test_inline_lines_wrap_through_float_intrusion_bands() {
	document := html.parse_document('<!doctype html><style>
		#container { width:100px }
		#float { float:left; width:40px; height:40px }
	</style><div id="container"><span id="float"></span>aaaa aaaa aaaa aaaa</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container_node := layout_node_with_id(result.root, 'container') or { panic('no container') }
	container_used := result.used_values_for(container_node.as_node_with_style() or {
		panic('container has no style')
	}) or { panic('container has no used values') }
	assert container_used.line_boxes.len >= 3
	first_fragment := container_used.line_boxes[0].fragments()[0]
	assert first_fragment.inline_offset().to_double() >= 40
	last_line := container_used.line_boxes.last()
	assert last_line.fragments().len > 0
	assert last_line.fragments()[0].inline_offset().to_double() == 0
}

fn test_line_break_skips_crossing_opposite_float_bands() {
	document := html.parse_document('<!doctype html><style>
		#container { width:100px; font:20px SerenitySans; line-height:24px }
		#left, #right { width:60px; height:20px }
		#left { float:left }
		#right { float:right }
	</style><div id="container"><span id="left"></span><span id="right"></span>aa aaaaaaaa</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container_node := layout_node_with_id(result.root, 'container') or { panic('no container') }
	container_used := result.used_values_for(container_node.as_node_with_style() or {
		panic('container has no style')
	}) or { panic('container has no used values') }
	mut text_y := ?f64(none)
	for line_box in container_used.line_boxes {
		for fragment in line_box.fragments() {
			if fragment.text() or { '' } == 'aaaaaaaa' {
				text_y = fragment.offset().y().to_double()
			}
		}
	}
	assert text_y or { panic('missing text fragment') } == 40
}

fn test_independent_formatting_context_avoids_preceding_float() {
	document := html.parse_document('<!doctype html><style>
		#container { width:200px }
		#float { float:left; width:80px; height:40px }
		#independent { overflow:hidden; height:20px }
	</style><div id="container"><div id="float"></div><div id="independent"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	independent := used_for_id(result, 'independent')
	assert independent.offset.x().to_double() == 80
	assert independent.offset.y().to_double() == 0
	assert independent.content_width().to_double() == 120
}
