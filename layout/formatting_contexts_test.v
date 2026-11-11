module layout

import css
import dom
import html
import platform
import svg
import math

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

fn layout_nodes_with_class(root &Node, class_name string, mut matches []&Node) {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('class').split(' ').contains(class_name) {
				matches << root
			}
		}
	}
	for child in root.children() {
		layout_nodes_with_class(child, class_name, mut matches)
	}
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

fn test_flex_intrinsic_height_accounts_for_line_clamping_and_nested_baselines() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; font:20px/20px monospace }
		.row { display:flex; width:100px }
		.card { width:100px }
		.title { display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:1; overflow:hidden }
		select { width:100px; height:40px; padding:0; border:0; font:inherit }
	</style>
	<div class="row"><div class="card" id="combined"><div class="title" id="combined-title">first second third fourth</div><div><select><option>Tea</option></select></div></div></div>
	<div class="row"><div class="card" id="title-only"><div class="title">first second third fourth</div></div></div>
	<div class="row"><div class="card" id="select-only"><div><select><option>Tea</option></select></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'combined').content_height().to_double() == 60
	assert used_for_id(result, 'combined-title').content_height().to_double() == 20
	assert used_for_id(result, 'title-only').content_height().to_double() == 20
	assert used_for_id(result, 'select-only').content_height().to_double() == 40
}

fn test_button_content_percentages_resolve_against_the_button() {
	document := html.parse_document('<!doctype html><style>
		.column { display:flex; flex-direction:column; align-items:start }
		button { width:60px; aspect-ratio:4/5; border:0; padding:0 }
		canvas { display:block; width:100%; height:100% }
		#fixed { aspect-ratio:auto; height:75px }
		#padded { aspect-ratio:auto; width:80px; height:100px; border:5px solid; padding:5px }
		#wide { width:80px }
		#auto { aspect-ratio:auto }
		#half canvas { height:50% }
	</style><div class="column">
		<button id="ratio"><canvas id="ratio-content" width="100" height="100"></canvas></button>
		<button id="fixed"><canvas id="fixed-content" width="100" height="100"></canvas></button>
		<button id="padded"><canvas id="padded-content" width="100" height="100"></canvas></button>
		<button id="wide"><canvas id="wide-content" width="100" height="100"></canvas></button>
		<button id="half"><canvas id="half-content" width="100" height="100"></canvas></button>
		<button id="auto"><canvas id="auto-content" width="100" height="100"></canvas></button>
		<button id="nested"><div><canvas id="nested-content" width="100" height="100"></canvas></div></button>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'ratio').content_height().to_double() == 75
	assert used_for_id(result, 'ratio-content').content_height().to_double() == 75
	assert used_for_id(result, 'fixed-content').content_height().to_double() == 75
	assert used_for_id(result, 'padded').border_box_height().to_double() == 100
	assert used_for_id(result, 'padded-content').content_height().to_double() == 80
	assert used_for_id(result, 'wide').content_height().to_double() == 100
	assert used_for_id(result, 'wide-content').content_height().to_double() == 100
	assert used_for_id(result, 'half-content').content_height().to_double() == 37.5
	assert used_for_id(result, 'auto').content_height().to_double() == 60
	assert used_for_id(result, 'auto-content').content_height().to_double() == 60
	assert used_for_id(result, 'nested-content').content_height().to_double() == 60
}

fn test_button_content_height_uses_clamped_border_box_height() {
	document := html.parse_document('<!doctype html><style>
		button { box-sizing:border-box; min-height:50px; padding:5px; border:5px solid; font:10px/10px SerenitySans }
		.flex { display:flex; align-items:flex-start }
		.block button { display:block }
		.intrinsic button { height:fit-content }
		.abs button { position:absolute; top:250px }
		.indefinite button { min-height:auto; height:fit-content }
		.indefinite .pct { height:100% }
	</style>
	<span><button id="inline">x</button></span>
	<div class="block"><button id="block">x</button></div>
	<div class="flex"><button id="flex">x</button></div>
	<div class="intrinsic"><button id="intrinsic">x</button></div>
	<div class="abs"><button id="absolute">x</button></div>
	<div class="indefinite"><button id="indefinite"><div class="pct" id="percentage"></div><div>x</div></button></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['inline', 'block', 'flex', 'intrinsic', 'absolute'] {
		button := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
		button_used := used_for_id(result, id)
		assert button_used.content_height().to_double() == 30
		assert button_used.has_definite_height()
		wrapper := button.first_child() or { panic('#${id} has no flex wrapper') }
		wrapper_used := result.used_values_for(wrapper.as_node_with_style() or {
			panic('#${id} flex wrapper has no style')
		}) or { panic('#${id} flex wrapper has no used values') }
		assert wrapper_used.content_height().to_double() == 30
		content := wrapper.first_child() or { panic('#${id} has no content box') }
		content_used := result.used_values_for(content.as_node_with_style() or {
			panic('#${id} content box has no style')
		}) or { panic('#${id} content box has no used values') }
		assert content_used.content_height().to_double() == 10
		assert content_used.offset.y().to_double() == 10
	}
	indefinite_used := used_for_id(result, 'indefinite')
	assert indefinite_used.content_height().to_double() == 10
	assert !indefinite_used.has_definite_height()
	assert used_for_id(result, 'percentage').content_height().to_double() == 0
}

fn test_button_layout_establishes_a_block_formatting_context() {
	// Button-type inputs keep a block flow display, unlike <button> and text
	// inputs, whose computed styles are adjusted to flow-root.
	document := html.parse_document('<!doctype html><style>
		input { display:block }
	</style><input id="submit" type="submit"><input id="reset" type="reset"><input id="button" type="button"><input id="text">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['submit', 'reset', 'button'] {
		node := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
		assert node.display().is_block_outside()
		assert node.display().is_flow_inside()
		assert creates_block_formatting_context(node.as_node_with_style() or {
			panic('#${id} has no style')
		})
	}
	text := layout_node_with_id(result.root, 'text') or { panic('missing #text') }
	assert !creates_block_formatting_context(text.as_node_with_style() or {
		panic('#text has no style')
	})
}

fn test_empty_button_content_is_skipped_by_flex_layout() {
	document := html.parse_document('<!doctype html><style>body { margin:0 }</style><button id="button"></button>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	button := layout_node_with_id(result.root, 'button') or { panic('missing button') }
	flex_wrapper := button.first_child() or { panic('missing button flex wrapper') }
	content := flex_wrapper.first_child() or { panic('missing button content wrapper') }
	content_styled := content.as_node_with_style() or { panic('button content has no style') }
	assert result.state.try_get(content_styled) == none
}

fn test_inline_grid_whitespace_runs_do_not_acquire_used_values() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:inline-grid }
	</style><div id="grid">
		<div></div>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := layout_node_with_id(result.root, 'grid') or { panic('missing grid') }
	assert grid.children().len == 3
	for whitespace in [grid.children()[0], grid.children()[2]] {
		whitespace_styled := whitespace.as_node_with_style() or {
			panic('anonymous whitespace run has no style')
		}
		assert result.state.try_get(whitespace_styled) == none
	}
}

fn test_fractional_calculated_flex_basis_does_not_wrap_the_third_item() {
	for width in [100, 101, 102, 100] {
		document := html.parse_document('<!doctype html><style>
			#container { display:flex; flex-wrap:wrap; column-gap:16px; width:${width}px }
			.item { flex:0 0 calc((100% - 32px) / 3); height:10px }
		</style><div id="container"><div class="item" id="one"></div><div class="item" id="two"></div><div class="item" id="three"></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		assert used_for_id(result, 'one').offset.y() == used_for_id(result, 'three').offset.y()
	}
}

fn test_large_percentage_width_retains_precision_before_saturation() {
	document := html.parse_document('<!doctype html><style>
		#parent { width:4753650px; height:20px }
		#child { width:100%; height:10px }
	</style><div id="parent"><div id="child"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'parent').content_width().to_double() == 4_753_650
	assert used_for_id(result, 'child').content_width().to_double() == 4_753_650
}

fn test_inline_math_uses_completed_run_height_without_enclosing_margin() {
	document := html.parse_document('<!doctype html><style>
		body * { border:1px solid black }
		math a { display:block; width:100px; height:100px }
	</style><math id="math"><a id="child">Hello</a></math>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	math_used := used_for_id(result, 'math')
	child_used := used_for_id(result, 'child')
	assert child_used.border_box_height().to_double() == 102
	assert math_used.content_height() == child_used.border_box_height()
}

fn test_auto_width_text_input_stretches_in_nested_column_flex() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer, #inner { display:flex; flex-direction:column; width:300px }
		#inner { width:auto }
	</style><div id="outer"><div id="inner"><input id="input" type="text" size="5"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'inner').border_box_width().to_double() == 300
	assert used_for_id(result, 'input').border_box_width().to_double() == 300
}

fn test_text_input_padding_belongs_to_the_host_box() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { font:16px/20px monospace }
		#custom { padding:7px 11px }
	</style><input id="default"><input id="custom">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	default_node := layout_node_with_id(result.root, 'default') or { panic('missing default input') }
	custom_node := layout_node_with_id(result.root, 'custom') or { panic('missing custom input') }
	default_used := used_for_id(result, 'default')
	custom_used := used_for_id(result, 'custom')

	assert default_used.padding_top.to_double() == 1
	assert default_used.padding_right.to_double() == 2
	assert default_used.padding_bottom.to_double() == 1
	assert default_used.padding_left.to_double() == 2
	assert custom_used.padding_top.to_double() == 7
	assert custom_used.padding_right.to_double() == 11
	assert custom_used.padding_bottom.to_double() == 7
	assert custom_used.padding_left.to_double() == 11

	for node in [default_node, custom_node] {
		box := node.as_box() or { panic('text input is not a box') }
		auto_height := box.auto_content_box_size().height or { panic('text input has no auto height') }
		assert auto_height == node.computed_values().line_height()
		internal := node.first_child() or { panic('text input has no internal flex box') }
		internal_nws := internal.as_node_with_style() or { panic('internal flex box has no style') }
		internal_used := result.used_values_for(internal_nws) or {
			panic('internal flex box has no used values')
		}
		assert internal_used.padding_top.to_double() == 0
		assert internal_used.padding_right.to_double() == 0
		assert internal_used.padding_bottom.to_double() == 0
		assert internal_used.padding_left.to_double() == 0
	}
}

fn test_visible_input_placeholder_overlays_the_full_width_editor() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { width:200px }
	</style><input id="text" placeholder="hint"><input id="number" type="number" placeholder="number">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	text := layout_node_with_id(result.root, 'text') or { panic('missing text input') }
	text_outer := text.first_child() or { panic('missing text outer box') }
	text_inner := text_outer.children()[0]
	text_placeholder := text_outer.children()[1]
	assert text_inner.computed_values().white_space_collapse() == .preserve
	assert text_inner.computed_values().text_wrap_mode() == .nowrap
	text_inner_used := result.used_values_for(text_inner.as_node_with_style() or {
		panic('text editor has no style')
	}) or { panic('text editor has no used values') }
	text_placeholder_used := result.used_values_for(text_placeholder.as_node_with_style() or {
		panic('text placeholder has no style')
	}) or { panic('text placeholder has no used values') }
	assert text_inner_used.content_width().to_double() == 200
	assert text_placeholder_used.content_width() == text_inner_used.content_width()
	assert text_placeholder_used.margin_left.to_double() == -200
	assert text_placeholder.computed_values().pointer_events() == .none_
	assert text_placeholder.computed_values().user_select() == .none_

	number := layout_node_with_id(result.root, 'number') or { panic('missing number input') }
	number_outer := number.first_child() or { panic('missing number outer box') }
	text_container := number_outer.children()[0]
	number_inner := text_container.children()[0]
	number_placeholder := text_container.children()[1]
	number_inner_used := result.used_values_for(number_inner.as_node_with_style() or {
		panic('number editor has no style')
	}) or { panic('number editor has no used values') }
	number_placeholder_used := result.used_values_for(number_placeholder.as_node_with_style() or {
		panic('number placeholder has no style')
	}) or { panic('number placeholder has no used values') }
	assert number_inner_used.content_width().to_double() > 0
	assert number_placeholder_used.content_width() == number_inner_used.content_width()
	assert number_placeholder_used.margin_left == number_inner_used.content_width().negated()
}

fn test_live_input_placeholder_overlays_after_attribute_mutation() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { width:200px }
	</style><input id="input">')
	// The compact browser lays parser-created controls out once before it replays
	// script mutations. Reproduce that lifecycle before materializing the input's
	// live UA shadow tree.
	_ = run_document_layout(document, 800, 600) or { panic('initial layout failed') }
	root := unsafe { &dom.Node(document) }
	mut element := css.query_selector(root, '#input') or { panic('missing input') }
	element.set_attribute_value('placeholder', 'hint')
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	model.form_associated_element_attribute_changed('placeholder', none, 'hint', none)

	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	input := layout_node_with_id(result.root, 'input') or { panic('missing input layout node') }
	outer := input.first_child() or { panic('missing input outer box') }
	inner := outer.children()[0]
	placeholder := outer.children()[1]
	inner_used := result.used_values_for(inner.as_node_with_style() or {
		panic('text editor has no style')
	}) or { panic('text editor has no used values') }
	placeholder_used := result.used_values_for(placeholder.as_node_with_style() or {
		panic('placeholder has no style')
	}) or { panic('placeholder has no used values') }
	assert inner_used.content_width().to_double() == 200
	assert placeholder_used.content_width() == inner_used.content_width()
	assert placeholder_used.margin_left == inner_used.content_width().negated()
}

fn test_number_input_stepper_icons_keep_computed_path_geometry() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { width:200px }
	</style><input id="number" type="number" value="1">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	number := layout_node_with_id(result.root, 'number') or { panic('missing number input') }
	outer := number.first_child() or { panic('missing number input outer box') }
	assert outer.children().len == 3
	for button in outer.children()[1..] {
		flex_wrapper := button.first_child() or { panic('missing button flex wrapper') }
		content_wrapper := flex_wrapper.first_child() or { panic('missing button content wrapper') }
		svg_box := content_wrapper.first_child() or { panic('missing stepper svg') }
		path_box := svg_box.first_child() or { panic('missing stepper path') }
		assert path_box.is_svg_geometry_box()
		path_used := result.used_values_for(path_box.as_node_with_style() or {
			panic('stepper path has no style')
		}) or { panic('stepper path has no used values') }
		assert path_used.content_width().to_double() == 12
		assert path_used.content_height().to_double() > 7
	}
}

fn test_native_input_min_max_height_clamps_are_definite_for_shadow_content() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { box-sizing:border-box; width:200px; border:1px solid; padding:1px 10px; font:16px/20px monospace }
		#minimum { min-height:44px }
		#maximum { max-height:18px }
	</style><input id="minimum" placeholder="minimum"><input id="maximum" placeholder="maximum">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	minimum := layout_node_with_id(result.root, 'minimum') or { panic('missing minimum input') }
	maximum := layout_node_with_id(result.root, 'maximum') or { panic('missing maximum input') }
	minimum_outer := minimum.first_child() or { panic('missing minimum internal box') }
	maximum_outer := maximum.first_child() or { panic('missing maximum internal box') }
	minimum_outer_used := result.used_values_for(minimum_outer.as_node_with_style() or {
		panic('minimum internal box has no style')
	}) or { panic('minimum internal box has no used values') }
	maximum_outer_used := result.used_values_for(maximum_outer.as_node_with_style() or {
		panic('maximum internal box has no style')
	}) or { panic('maximum internal box has no used values') }
	assert minimum_outer_used.content_height().to_double() == 40
	assert maximum_outer_used.content_height().to_double() == 14
	assert minimum_outer_used.has_definite_height()
	assert maximum_outer_used.has_definite_height()
	minimum_editor := minimum_outer.children()[0]
	maximum_editor := maximum_outer.children()[0]
	minimum_editor_used := result.used_values_for(minimum_editor.as_node_with_style() or {
		panic('minimum editor has no style')
	}) or { panic('minimum editor has no used values') }
	maximum_editor_used := result.used_values_for(maximum_editor.as_node_with_style() or {
		panic('maximum editor has no style')
	}) or { panic('maximum editor has no used values') }
	assert minimum_editor_used.offset.y().to_double() == 10
	assert maximum_editor_used.offset.y().to_double() == -3
}

fn test_visible_textarea_placeholder_overlays_the_full_width_editor() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		textarea { width:240px }
	</style><textarea id="textarea" placeholder="hint"></textarea>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	textarea := layout_node_with_id(result.root, 'textarea') or { panic('missing textarea') }
	outer := textarea.first_child() or { panic('missing textarea outer box') }
	assert outer.display().is_flex_inside()
	inner := outer.children()[0]
	placeholder := outer.children()[1]
	inner_used := result.used_values_for(inner.as_node_with_style() or {
		panic('textarea editor has no style')
	}) or { panic('textarea editor has no used values') }
	placeholder_used := result.used_values_for(placeholder.as_node_with_style() or {
		panic('textarea placeholder has no style')
	}) or { panic('textarea placeholder has no used values') }
	assert inner_used.content_width().to_double() == 240
	assert placeholder_used.content_width() == inner_used.content_width()
	assert placeholder_used.margin_left == inner_used.content_width().negated()
	assert placeholder.computed_values().pointer_events() == .none_
	assert placeholder.computed_values().user_select() == .none_
}

fn test_text_input_auto_height_uses_selected_font_metrics() {
	document := html.parse_document('<!doctype html><style>
		input { font-size:5px }
	</style><input id="input">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	input := layout_node_with_id(result.root, 'input') or { panic('missing input') }
	box := input.as_box() or { panic('input is not a box') }
	assert input.computed_values().line_height().to_double() == 5
	assert box.auto_content_box_size().height or { panic('missing auto height') } ==
		input.computed_values().line_height()
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

fn test_flex_min_height_stretches_lines_before_centering_items() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0; padding:0 }
		#flex { display:flex; flex-wrap:wrap; align-items:center; width:100px; min-height:400px }
		#one, #two { flex:none; width:40px; height:100px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'flex').content_height().to_double() == 400
	assert used_for_id(result, 'one').offset.y().to_double() == 150
	assert used_for_id(result, 'two').offset.y().to_double() == 150
}

fn test_wrap_reverse_stretch_places_flex_lines_from_the_far_cross_edge() {
	for direction in ['row', 'row-reverse'] {
		document := html.parse_document('<!doctype html><style>
			* { margin:0; padding:0 }
			#flex { display:flex; flex-direction:${direction}; flex-wrap:wrap-reverse;
				align-content:stretch; width:180px; height:160px }
			#one, #two, #three { flex:none; width:300px }
			#one { height:20px } #two { height:30px } #three { height:40px }
		</style><div id="flex"><div id="one"></div><div id="two"></div><div id="three"></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		// The 70px remainder is divided into three truncated 23.328125px shares.
		// align_all_flex_lines() starts at the 160px far edge and subtracts each
		// line, so the truncation residue does not shift the first placed item.
		assert used_for_id(result, 'one').offset.y().to_double() == 140
		assert used_for_id(result, 'two').offset.y().to_double() == 86.671875
		assert used_for_id(result, 'three').offset.y().to_double() == 23.34375
	}
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

fn test_reverse_direction_sorts_order_keys_descending() {
	// generate_anonymous_flex_items() sorts the distinct `order` keys descending for a
	// reverse direction instead of reversing the item list, because a reverse line is
	// already laid out from the far edge. Sorting ascending put the groups the wrong way
	// round: the lowest order ended up at the far edge rather than the highest.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:row-reverse; width:240px }
		#flex > div { flex:none; height:10px }
		#second { width:70px; order:1 } #first { width:50px; order:2 }
	</style><div id="flex"><div id="first"></div><div id="second"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// order:2 is the highest key, so it takes the reversed main-start edge on the right.
	assert used_for_id(result, 'first').offset.x().to_double() == 190
	assert used_for_id(result, 'second').offset.x().to_double() == 120
}

fn test_rtl_row_counts_as_the_reverse_direction_for_order_keys() {
	// is_direction_reverse() swaps which of `row`/`row-reverse` is reversed under
	// `direction: rtl`, so a plain rtl row sorts its order keys descending too.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; direction:rtl; width:240px }
		#flex > div { flex:none; height:10px }
		#second { width:70px; order:1 } #first { width:50px; order:2 }
	</style><div id="flex"><div id="first"></div><div id="second"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'first').offset.x().to_double() == 190
	assert used_for_id(result, 'second').offset.x().to_double() == 120
}

fn test_single_line_column_flex_swaps_cross_edges_for_wrap_reverse() {
	// "When flex-wrap is wrap-reverse, the cross-start and cross-end directions are
	// swapped." A column container's cross axis is the inline one, so its items align to the
	// right edge. The single-line column path derived that flag from `direction` alone, so a
	// wrap-reverse column left every item at the cross-start edge.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:wrap-reverse; width:240px }
		#one { width:50px; height:20px } #two { width:70px; height:30px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 190
	assert used_for_id(result, 'two').offset.x().to_double() == 170
	// The main axis is untouched: the items still stack downwards in document order.
	assert used_for_id(result, 'one').offset.y().to_double() == 0
	assert used_for_id(result, 'two').offset.y().to_double() == 20
}

fn test_rtl_and_wrap_reverse_cancel_each_other_on_the_column_cross_axis() {
	// A column's cross axis is the inline axis. RTL reverses it once and wrap-reverse reverses
	// it again, leaving normal items at the physical left edge.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:wrap-reverse; direction:rtl; width:240px }
		#one { width:50px; height:20px } #two { width:70px; height:30px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').offset.x().to_double() == 0
}

fn test_indefinite_column_flex_uses_the_intrinsic_main_size_algorithm() {
	// calculate_intrinsic_main_size_of_flex_container(): the container is the smallest size
	// at which every item reaches its max-content contribution, given the items' relative
	// flexibility. Two `flex-basis: 0` items with 20px and 30px of content and grow factors
	// 1 and 2 need a 60px container - the chosen flex fraction is 20, so the second item is
	// twice the first. Summing the outer hypothetical sizes gave 50px and left both items at
	// their zero flex base size.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:240px }
		#one { flex:1 1 0; height:20px } #two { flex:2 1 0; height:30px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'flex').content_height().to_double() == 60
	assert used_for_id(result, 'one').content_height().to_double() == 20
	assert used_for_id(result, 'two').content_height().to_double() == 40
	assert used_for_id(result, 'two').offset.y().to_double() == 20
}

fn test_indefinite_column_flex_intrinsic_main_size_counts_gaps_and_edges() {
	// Step 5 adds the gaps, and each item is summed at its outer size so main-axis margins,
	// borders, and padding do not overflow the container.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; width:240px; row-gap:10px }
		#one { flex:1 1 0; height:20px; margin-bottom:5px }
		#two { flex:1 1 0; height:20px; border-top:3px solid }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// Contributions are 25 and 23 outer; the greatest desired flex fraction is 20, so both
	// items resolve to 20 of content plus their own edges, plus the 10px gap.
	assert used_for_id(result, 'flex').content_height().to_double() == 58
	assert used_for_id(result, 'one').content_height().to_double() == 20
	assert used_for_id(result, 'two').content_height().to_double() == 20
}

fn test_wrapping_container_sizes_its_only_line_to_its_items() {
	// calculate_cross_size_of_each_flex_line() gives the line the container's inner cross
	// size only when the container is single-line, and is_single_line() means
	// `flex-wrap: nowrap` - not "collection happened to produce one line". A wrapping
	// container whose items all fit on one line still sizes that line to its items, which is
	// what leaves cross-axis free space for align-content to distribute.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:wrap; align-content:flex-end;
		        width:180px; height:160px }
		#flex > div { width:300px }
		#one { height:20px } #two { height:30px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// The single line is 300 wide against a 180 container, so flex-end starts it at -120.
	assert used_for_id(result, 'one').offset.x().to_double() == -120
	assert used_for_id(result, 'two').offset.x().to_double() == -120
}

fn test_nowrap_container_still_stretches_its_line_to_the_definite_cross_size() {
	// The nowrap half of the same rule: a single-line container with a definite cross size
	// hands that size to its only line, so there is no free space and align-content is inert.
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; flex-direction:column; flex-wrap:nowrap; align-content:flex-end;
		        width:180px; height:160px }
		#flex > div { width:300px }
		#one { height:20px } #two { height:30px }
	</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').offset.x().to_double() == 0
}

fn test_negative_align_content_free_space_falls_back_to_center() {
	// align_all_flex_lines(): for space-around and space-evenly, "if the leftover free-space
	// is negative this value is identical to center". Distributing the clamped, non-negative
	// free space instead pinned overflowing lines to the cross-start edge.
	for align in ['space-around', 'space-evenly'] {
		document := html.parse_document('<!doctype html><style>
			#flex { display:flex; flex-direction:column; flex-wrap:wrap; align-content:${align};
			        width:180px; height:160px }
			#flex > div { width:300px }
			#one { height:20px } #two { height:30px }
		</style><div id="flex"><div id="one"></div><div id="two"></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		// One 300-wide line against a 180 container overflows by 120, so it is centred.
		assert used_for_id(result, 'one').offset.x().to_double() == -60
		assert used_for_id(result, 'two').offset.x().to_double() == -60
	}
}

fn test_only_normal_alignment_follows_a_wrap_reversed_cross_axis() {
	// align_all_flex_items_along_the_cross_axis() consults flex-wrap for the `normal` case
	// alone. Every explicit keyword names a fixed edge of the line, so `flex-start` stays at
	// cross-start and `flex-end` at cross-end however the container wraps - and the inline
	// `direction` does not enter into the item's own offset at all.
	document := html.parse_document('<!doctype html><style>
		.f { display:flex; flex-direction:row; flex-wrap:wrap-reverse; width:240px; height:120px }
		.f > div { width:70px; height:30px }
	</style>
		<div class="f"><div id="start" style="align-self:flex-start"></div></div>
		<div class="f"><div id="end" style="align-self:flex-end"></div></div>
		<div class="f"><div id="stretch" style="align-self:stretch"></div></div>
		<div class="f"><div id="normal" style="align-self:normal"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// Each container is 120 tall and each item 30, so within the line cross-start is at 0 and
	// cross-end at 90.
	assert used_for_id(result, 'start').offset.y().to_double() == 0
	assert used_for_id(result, 'end').offset.y().to_double() == 90
	assert used_for_id(result, 'stretch').offset.y().to_double() == 0
	// Only this one follows the swapped cross-start edge at the bottom of its line.
	assert used_for_id(result, 'normal').offset.y().to_double() == 90
}

fn test_column_cross_alignment_ignores_the_inline_direction() {
	// A column container's cross axis is the inline one, but the item's own offset still
	// names a fixed edge: rtl does not turn flex-start into the right edge.
	document := html.parse_document('<!doctype html><style>
		.f { display:flex; flex-direction:column; flex-wrap:wrap; direction:rtl; width:240px }
		.f > div { width:70px; height:30px }
	</style>
		<div class="f"><div id="start" style="align-self:flex-start"></div></div>
		<div class="f"><div id="end" style="align-self:flex-end"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'start').offset.x().to_double() == 0
	assert used_for_id(result, 'end').offset.x().to_double() == 170
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

fn test_nested_flex_with_parent_resolved_size_still_runs_intrinsic_relayout() {
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
	_ = run_flex_formatting_context_with_mode(mut measurement_state, flex_node, mut flex_state, .intrinsic_sizing, AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(100)), AvailableSize.make_definite(CSSPixels.new(50))))
	// Even with both dimensions resolved by the parent, descendants may supply
	// the baseline of an inline flex box. The intrinsic run therefore cannot be
	// skipped; measuring this content populates the item's intrinsic cache.
	assert item_box.cached_intrinsic_sizes_ != none
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

fn test_auto_height_row_flex_ignores_unresolved_percentage_min_height_for_ratio_transfer() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#flex { display:flex }
		#ratio { aspect-ratio:2/1; min-height:50% }
		#fixed { width:40px; height:60px }
	</style><div id="flex"><div id="ratio"></div><div id="fixed"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	ratio := used_for_id(result, 'ratio')
	assert ratio.content_width().to_double() == 0
	assert ratio.content_height().to_double() == 60
}

fn test_intrinsic_column_flex_width_does_not_create_a_cyclic_percentage_minimum_basis() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex }
		.column { display:flex; flex-direction:column; padding:4px 20px }
		.label { width:100px; height:20px }
		.indicator { min-width:calc(100% + 40px); height:4px }
		.percentage-only { min-width:150% }
	</style>
	<div class="row"><div class="column"><div class="indicator"></div><div class="label"></div></div></div>
	<div class="row"><div class="column"><div class="indicator percentage-only"></div><div class="label"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut columns := []&Node{}
	layout_nodes_with_class(result.root, 'column', mut columns)
	assert columns.len == 2
	for node in columns {
		styled := node.as_node_with_style() or { panic('matched node has no style') }
		used := result.used_values_for(styled) or { panic('matched node has no used values') }
		assert used.content_width().to_double() == 100
	}
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

fn test_svg_partial_intrinsic_height_sets_its_max_content_width() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } .row { display:flex } .logo { display:flex; flex-direction:column; align-items:center }
	</style><div class="row"><div id="logo" class="logo"><svg id="image" height="24" viewBox="0 0 262 33"><rect width="262" height="33"></rect></svg></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	logo := used_for_id(result, 'logo')
	image := used_for_id(result, 'image')
	assert logo.content_width().to_double() == 190.53125
	assert image.content_width().to_double() == 190.53125
	assert image.content_height().to_double() == 24
}

fn test_ratio_only_svg_cyclic_percentage_uses_replaced_max_content_fallback() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; justify-content:space-between }
		p { margin:16px 0 }
	</style><div id="grid"><p id="paragraph"><svg id="image" width="100%" viewBox="0 0 99 99"><circle cx="50" cy="50" r="50"></circle></svg></p></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'grid').content_height().to_double() == 332
	assert used_for_id(result, 'paragraph').content_width().to_double() == 300
	assert used_for_id(result, 'image').content_width().to_double() == 300
	assert used_for_id(result, 'image').content_height().to_double() == 300
}

fn test_ratio_only_replaced_max_content_transfers_constraints() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.grid { display:grid; grid-template-columns:max-content; width:max-content }
		img { max-height:32px }
		#conflicting { min-height:100px }
		#capped { min-height:100px; max-width:150px }
		#cyclic { min-width:calc(10px + 50%); max-height:2px }
		#border { aspect-ratio:2/1; box-sizing:border-box; border:10px solid; min-height:120px; max-height:none }
	</style>
	<div id="conflicting-grid" class="grid"><img id="conflicting" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 2 1\'%3E%3C/svg%3E"></div>
	<div id="capped-grid" class="grid"><img id="capped" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 2 1\'%3E%3C/svg%3E"></div>
	<div id="cyclic-grid" class="grid"><img id="cyclic" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 2 1\'%3E%3C/svg%3E"></div>
	<div id="border-grid" class="grid"><img id="border" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\'%3E%3C/svg%3E"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'conflicting-grid').content_width().to_double() == 200
	assert used_for_id(result, 'conflicting').content_height().to_double() == 100
	assert used_for_id(result, 'capped-grid').content_width().to_double() == 150
	assert used_for_id(result, 'capped').content_width().to_double() == 150
	assert used_for_id(result, 'cyclic-grid').content_width().to_double() == 10
	assert used_for_id(result, 'cyclic').content_width().to_double() == 15
	assert used_for_id(result, 'border-grid').content_width().to_double() == 240
	assert used_for_id(result, 'border-grid').content_height().to_double() == 120
	assert used_for_id(result, 'border').content_width().to_double() == 220
	assert used_for_id(result, 'border').content_height().to_double() == 100
}

fn test_column_flex_intrinsic_cross_size_keeps_cyclic_percentage_minimum_indefinite() {
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
	// The second pass must keep using the initially indefinite percentage basis,
	// not the 784px width left in the source state by normal layout and not the
	// first pass's 50px intrinsic result.
	assert calculate_min_content_width(mut measurement_state, flex_box).to_double() == 50
	assert calculate_max_content_width(mut measurement_state, flex_box).to_double() == 50
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

fn test_abspos_max_content_width_sums_adjacent_floats() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 }
		#root { position:relative; width:500px }
		#menu { position:absolute; left:0; top:0 }
		#menu > div { float:left; height:10px }
		#one { width:40px } #two { width:50px } #three { width:60px }
	</style><div id="root"><div id="menu"><div id="one">a</div><div id="two">b</div><div id="three">c</div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	// An auto-width abspos box shrink-wraps to its max-content width. Adjacent
	// floats share that max-content row, so their outer widths add up.
	assert used_for_id(result, 'menu').content_width().to_double() == 150
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').offset.x().to_double() == 40
	assert used_for_id(result, 'three').offset.x().to_double() == 90
}

fn test_font_relative_width_uses_selected_face_metrics() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 }
		#target { float:left; width:6.1ex; font-family:Verdana, Arial, sans-serif;
			font-size:small; font-weight:bold }
	</style><div id="target"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	target := layout_node_with_id(result.root, 'target') or { panic('missing #target') }
	font_metrics := target.first_available_font().pixel_metrics()
	x_height := CSSPixels.nearest_value_for(f64(font_metrics.x_height))

	// Font-relative lengths are absolutized during the computed-value pass.
	// Their metric must come from the selected face, just as text shaping does.
	assert used_for_id(result, 'target').content_width() == x_height.times_float(6.1)
}

fn test_flex_content_basis_uses_definite_cross_size_and_aspect_ratio() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex; width:200px }
		#item { flex:0 0 content; min-width:0; height:40px; aspect-ratio:2/1 }
	</style><div id="flex"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'item').content_width().to_double() == 80
}

fn test_anchor_size_flex_basis_is_unresolvable_in_flex_formatting_context() {
	document := html.parse_document('<!doctype html><style>
		#flex { display:flex }
		#basis { flex-basis:anchor-size(--a width, 10px) }
		#width { flex-basis:auto; width:anchor-size(--a width, 10px) }
	</style><div id="flex"><div id="basis"></div><div id="width"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'basis').content_width().to_double() == 0
	assert used_for_id(result, 'width').content_width().to_double() == 0
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
	one_baseline := one.offset.y().plus(layout_box_baseline(result.state, one_node, .first))
	two_baseline := two.offset.y().plus(layout_box_baseline(result.state, two_node, .first))
	assert one_baseline.raw_value() == two_baseline.raw_value()
	assert one.offset.y().to_double() == 0
	assert two.offset.y().to_double() > 0
}

fn test_inline_flex_baseline_uses_its_wrapped_childs_first_line() {
	document := html.parse_document('<!doctype html><style>
		#icon { display:inline-flex; width:18px; height:18px; margin-left:4px }
		#label { width:64px }
	</style><p>foo <a>bar<span id="icon"><span id="label">baz baz baz baz</span></span></a> qux</p>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	icon_node := layout_node_with_id(result.root, 'icon') or { panic('missing #icon') }
	label_node := layout_node_with_id(result.root, 'label') or { panic('missing #label') }
	icon := used_for_id(result, 'icon')
	label := used_for_id(result, 'label')
	assert icon_node.display().is_inline_outside()
	assert icon_node.display().is_flex_inside()
	assert label.line_boxes.len > 1
	first_line := label.line_boxes.first()
	first_line_top := first_line.bottom().minus(first_line.block_length())
	expected := icon.margin_box_top().plus(label.offset.y().minus(label.margin_box_top())).plus(label.margin_box_top()).plus(first_line_top).plus(first_line.baseline())
	assert layout_box_baseline(result.state, icon_node, .last).raw_value() == expected.raw_value()
	assert layout_box_baseline(result.state, icon_node, .last).raw_value() != icon.margin_box_top().plus(label.offset.y().minus(label.margin_box_top())).plus(layout_box_baseline(result.state,
		label_node, .last)).raw_value()
}

fn test_intrinsic_inline_flex_resolves_auto_height_before_alignment_and_caches_baseline() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; font:16px/20px monospace }
		.flex { display:inline-flex; vertical-align:top; min-height:80px }
		#column { flex-direction:column; justify-content:center }
		#wrapped { width:20px; flex-wrap:wrap; align-content:center }
		.item { display:block; width:10px; height:20px }
	</style><div><span id="column" class="flex"><span id="column-a" class="item">A</span><span class="item">B</span></span><span id="wrapped" class="flex"><span id="wrapped-a" class="item">A</span><span class="item">B</span><span class="item">C</span></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	column := used_for_id(result, 'column')
	wrapped := used_for_id(result, 'wrapped')
	assert used_for_id(result, 'column-a').offset.y().minus(column.offset.y()).to_double() == 20
	assert used_for_id(result, 'wrapped-a').offset.y().minus(wrapped.offset.y()).to_double() == 20
	column_node := layout_node_with_id(result.root, 'column') or { panic('missing column') }
	wrapped_node := layout_node_with_id(result.root, 'wrapped') or { panic('missing wrapped') }
	assert layout_box_baseline(result.state, column_node, .first).raw_value() < column.margin_box_height().raw_value()
	assert layout_box_baseline(result.state, wrapped_node, .first).raw_value() < wrapped.margin_box_height().raw_value()
}

fn test_overflow_clip_inline_block_keeps_its_content_baseline() {
	document := html.parse_document('<!doctype html><style>
		span { display:inline-block; height:40px; font:20px/20px monospace }
		#clip { overflow:clip }
		#hidden { overflow:hidden }
	</style><span id="visible">text</span><span id="clip">text</span><span id="hidden">text</span>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	visible := layout_node_with_id(result.root, 'visible') or { panic('missing #visible') }
	clip := layout_node_with_id(result.root, 'clip') or { panic('missing #clip') }
	hidden := layout_node_with_id(result.root, 'hidden') or { panic('missing #hidden') }

	visible_baseline := layout_box_baseline(result.state, visible, .last)
	clip_baseline := layout_box_baseline(result.state, clip, .last)
	hidden_baseline := layout_box_baseline(result.state, hidden, .last)
	visible_first_baseline := layout_box_baseline(result.state, visible, .first)
	hidden_first_baseline := layout_box_baseline(result.state, hidden, .first)
	assert clip_baseline == visible_baseline
	assert hidden_baseline != visible_baseline
	assert hidden_baseline == used_for_id(result, 'hidden').margin_box_height()
	assert hidden_first_baseline == visible_first_baseline
}

fn test_inline_table_exports_its_first_row_baseline() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } #line { font-size:0 }
		#marker { display:inline-block; width:20px; height:20px }
		#table { display:inline-table; border-spacing:0 }
		tr { display:table-row } td { padding:0; font-size:20px; line-height:20px }
	</style><div id="line"><span id="marker"></span><table id="table"><tr id="first"><td>X</td></tr><tr id="last"><td>X</td></tr></table></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table_node := layout_node_with_id(result.root, 'table') or { panic('missing table') }
	wrapper := table_node.parent() or { panic('missing table wrapper') }
	assert wrapper.is_table_wrapper()
	table_styled := table_node.as_node_with_style() or { panic('table has no style') }
	wrapper_styled := wrapper.as_node_with_style() or { panic('wrapper has no style') }
	table := result.state.try_get(table_styled) or { panic('table has no used values') }
	wrapper_values := result.state.try_get(wrapper_styled) or { panic('wrapper has no used values') }
	first := used_for_id(result, 'first')
	last := used_for_id(result, 'last')
	first_baseline := first.derived_first_baseline() or { panic('missing first row baseline') }
	last_baseline := last.derived_last_baseline() or { panic('missing last row baseline') }
	wrapper_baseline := layout_box_baseline(result.state, wrapper, .last)
	assert wrapper_baseline.raw_value() == table.offset.y().plus(first.offset.y()).plus(first_baseline).raw_value()
	assert wrapper_baseline.raw_value() != last.offset.y().plus(last_baseline).raw_value()
	assert used_for_id(result, 'marker').offset.y().plus(CSSPixels.new(20)).raw_value() ==
		wrapper_values.offset.y().plus(wrapper_baseline).raw_value()
}

fn test_table_row_baseline_ignores_middle_aligned_cells() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } table { border-spacing:0 }
		td { padding:0; font-size:20px; line-height:20px }
		#middle { height:40px; vertical-align:middle }
		#baseline { vertical-align:baseline }
	</style><table><tr id="row"><td id="middle">X</td><td id="baseline">X</td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	row := used_for_id(result, 'row')
	baseline := used_for_id(result, 'baseline')
	row_baseline := row.derived_first_baseline() or { panic('missing row baseline') }
	baseline_node := layout_node_with_id(result.root, 'baseline') or { panic('missing cell') }
	assert row_baseline.raw_value() == table_cell_baseline(result.state, baseline_node,
		baseline, false).raw_value()
	assert baseline.padding_bottom.to_double() == 20
}

fn test_table_row_grows_to_contain_shifted_baseline_aligned_cell() {
	document := html.parse_document('<!doctype html><style>
		table { border-spacing:0; font-size:0 } td { padding:0; vertical-align:baseline }
		.inline { display:inline-block; width:20px; height:20px }
		.block { height:100px }
	</style><table><tr id="row"><td><div style="width:20px;height:50px"></div></td><td id="shifted"><span class="inline"></span><div class="block"></div></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	row := used_for_id(result, 'row')
	shifted := used_for_id(result, 'shifted')
	assert row.content_height().to_double() > 149
	assert shifted.padding_top.to_double() > 29
	assert shifted.padding_bottom.to_double() >= 0
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
	assert count.computed_values().establishes_multi_column_container()
	assert width.computed_values().establishes_multi_column_container()
	assert both.computed_values().establishes_multi_column_container()
	assert !ordinary.computed_values().establishes_multi_column_container()
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

fn test_rtl_column_flex_item_alignment_names_a_fixed_edge() {
	// align_all_flex_items_along_the_cross_axis() places `flex-start` at the line's
	// cross-start edge and `flex-end` at its cross-end edge without consulting the inline
	// direction, so an rtl column does not mirror them.
	start_document := html.parse_document('<!doctype html><style>
		#flex { direction:rtl; display:flex; flex-direction:column; align-items:flex-start;
			width:100px; height:100px }
		#item { width:20px; height:20px }
	</style><div id="flex"><div id="item"></div></div>')
	start_result := run_document_layout(start_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(start_result, 'item').offset.x().to_double() == 0

	end_document := html.parse_document('<!doctype html><style>
		#flex { direction:rtl; display:flex; flex-direction:column; align-items:flex-end;
			width:100px; height:100px }
		#item { width:20px; height:20px }
	</style><div id="flex"><div id="item"></div></div>')
	end_result := run_document_layout(end_document, 800, 600) or { panic('layout failed') }
	assert used_for_id(end_result, 'item').offset.x().to_double() == 80
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

fn test_reversed_cross_axis_reverses_wrapping_column_flex_line_order() {
	// A horizontal-tb column flex container's cross axis is its inline axis, so RTL reverses
	// line placement even without wrap-reverse.
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

fn test_explicit_flex_start_is_not_flipped_within_a_wrap_reversed_line() {
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
	// `align-items: flex-start` names the line's cross-start edge whichever way the container
	// wraps, so both items sit at the top of their line rather than the small one dropping.
	assert small.offset.y().to_double() == large.offset.y().to_double()
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

fn test_huge_font_size_min_content_measurement_is_clamped_before_shaping() {
	document := html.parse_document('<!doctype html><div id="target" style="font-size:100000000px;width:min-content">AAAA</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'target').content_width().to_double() > 0
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

fn test_grid_intrinsic_measurement_does_not_apply_items_own_percentage_min_max_width() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; grid-template-columns:min-content max-content 1fr;
			grid-template-areas:"one two three" }
		.item { min-width:25%; max-width:50% }
	</style><div id="grid"><div id="minimum" class="item" style="grid-area:one">min-content</div><div id="maximum" class="item" style="grid-area:two">max-content</div><div class="item" style="grid-area:three">1fr</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	minimum := used_for_id(result, 'minimum')
	maximum := used_for_id(result, 'maximum')
	// The unit-test font plugin has different glyph metrics from the native
	// corpus runner, so assert the behavior rather than its platform width.
	assert minimum.content_width().to_double() < 40
	assert minimum.content_width().to_double() < maximum.content_width().to_double()
	assert minimum.content_height().to_double() > 20
}

fn test_min_content_width_does_not_collapse_at_zero_minimum_descendant() {
	document := html.parse_document('<!doctype html><style>
		#bubble { width:min-content }
		#inner { min-width:0 }
		#child { width:300px; height:20px }
	</style><div id="bubble"><div id="inner"><div id="child"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'bubble').content_width().to_double() == 300
	assert used_for_id(result, 'inner').content_width().to_double() == 300
	assert used_for_id(result, 'child').content_width().to_double() == 300
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

fn test_grid_formatting_context_sizes_calculated_fr_tracks() {
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; width:300px; grid-template-columns:calc(1fr) calc(2 * 1fr) }
		#one, #two, #three { height:20px }
	</style><div id="grid"><div id="one"></div><div id="two"></div><div id="three"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	one := used_for_id(result, 'one')
	two := used_for_id(result, 'two')
	three := used_for_id(result, 'three')
	assert one.content_width().to_double() == 100
	assert two.content_width().to_double() == 200
	assert two.offset.x().to_double() == 100
	assert three.offset.x().to_double() == 0
	assert three.offset.y().to_double() == 20
}

fn test_fr_track_sizing_truncates_like_a_css_pixel_fraction() {
	// expand_flexible_tracks() keeps the hypothetical fr size as an exact CSSPixelFraction
	// and only lands on a pixel value where it is multiplied by a track's flex factor, and
	// that fixed-point division truncates. 290px of leftover space over three flex units is
	// 96.6666..., which truncates to 96.65625 (6186/64) rather than rounding to 96.671875.
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; grid-template-columns:1fr 2fr; gap:10px; width:300px }
		#one { height:20px } #two { height:40px }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 96.65625
	assert used_for_id(result, 'two').offset.x().to_double() == 106.65625
}

fn test_auto_fit_collapse_looks_only_at_the_first_cell_of_a_track() {
	// collapse_auto_fit_tracks_if_needed() asks the occupation grid whether the track's first
	// cell is taken - is_occupied(track_index, 0) for a column - instead of scanning the whole
	// track. The only item in column 1 sits at row 2 here, so column 1 is still collapsed to
	// 0px and column 2 slides left into its place.
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; grid-template-columns:repeat(auto-fit, 60px); width:300px }
		#one { grid-row:2 } #two { grid-column:2 }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_width().to_double() == 0
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').content_width().to_double() == 60
	assert used_for_id(result, 'two').offset.x().to_double() == 0
}

fn test_auto_fit_collapse_keeps_a_track_whose_first_cell_is_taken() {
	// The other half of the same rule: an item in row 1 does keep its column alive, so the
	// second column starts after it rather than at the container edge.
	document := html.parse_document('<!doctype html><style>
		#grid { display:grid; grid-template-columns:repeat(auto-fit, 60px); width:300px }
		#one { grid-column:1 } #two { grid-column:2 }
	</style><div id="grid"><div id="one"></div><div id="two"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').offset.x().to_double() == 0
	assert used_for_id(result, 'two').offset.x().to_double() == 60
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

fn test_flexible_grid_tracks_honor_intrinsic_minimum_phases() {
	document := html.parse_document('<!doctype html><style>
		.grid { display:grid; width:50px; font:10px/1 monospace }
		.item { min-width:0 }
		.item span { display:inline-block; width:60px; height:10px }
		#minimum { grid-template-columns:minmax(min-content, 1fr) }
		#maximum { grid-template-columns:minmax(max-content, 1fr) }
		#spanning { grid-template-columns:minmax(max-content, 1fr) minmax(max-content, 2fr) }
		#zero { width:max-content; grid-template-columns:minmax(auto, 0fr) }
		#zero-item { overflow:auto }
		#span { grid-column:span 2 }
		#second { grid-column:2 }
	</style>
	<div class="grid" id="minimum"><div class="item" id="minimum-item"><span></span><wbr><span></span></div></div>
	<div class="grid" id="maximum"><div class="item" id="maximum-item"><span></span><wbr><span></span></div></div>
	<div class="grid" id="spanning"><div class="item" id="span"><span></span><wbr><span></span></div><div id="second"></div></div>
	<div class="grid" id="zero"><div class="item" id="zero-item"><span></span></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'minimum-item').content_width().to_double() == 60
	assert used_for_id(result, 'maximum-item').content_width().to_double() == 120
	assert used_for_id(result, 'span').content_width().to_double() == 120
	assert used_for_id(result, 'second').offset.x().to_double() == 40
	assert used_for_id(result, 'second').content_width().to_double() == 80
	assert used_for_id(result, 'zero-item').content_width().to_double() == 0
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

fn test_grid_explicit_item_minimum_contribution_includes_box_edges() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { float:left; display:grid; grid-template-columns:auto }
		#item { min-width:100px; min-height:10px; border:1px solid }
	</style><div id="grid"><div id="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	item := used_for_id(result, 'item')
	assert grid.content_width().to_double() == 102
	assert item.content_width().to_double() == 100
	assert item.border_box_width().to_double() == 102
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
	assert item.content_height().to_double() == 100
}

fn test_grid_percentage_height_items_contribute_auto_sizes_to_rows() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; grid-template-rows:max-content; row-gap:20px;
			align-items:start; width:120px; height:300px }
		#label { height:10px } .item { height:100% } .content { height:30px }
	</style><div id="grid"><div id="label"></div><div id="first" class="item"><div class="content"></div></div><div id="second" class="item"><div class="content"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'label').content_height().to_double() == 10
	assert used_for_id(result, 'first').offset.y().to_double() == 30
	assert used_for_id(result, 'first').content_height().to_double() == 125
	assert used_for_id(result, 'second').offset.y().to_double() == 175
	assert used_for_id(result, 'second').content_height().to_double() == 125
}

fn test_grid_limited_contribution_is_clamped_by_fit_content_row() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.outer { display:grid; grid-template-columns:1fr minmax(auto, 200px) 1fr }
		.inner { display:grid; gap:10px; grid-column:2;
			grid-template-columns:repeat(2, 1fr);
			grid-template-rows:min-content 1fr fit-content(0) }
		.span { grid-column:1; grid-row:1 / 3; min-height:100px }
		.top { grid-column:2; grid-row:1; min-height:70px }
		.middle { grid-column:2; grid-row:2; min-height:20px }
		.feed { grid-column:1 / 3; grid-row:3; min-height:50px; overflow:hidden }
		.feed > div { height:300px }
	</style><div id="outer" class="outer"><div id="inner" class="inner"><div class="span"></div><div class="top"></div><div class="middle"></div><div id="feed" class="feed"><div></div></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	outer := used_for_id(result, 'outer')
	inner := used_for_id(result, 'inner')
	feed := used_for_id(result, 'feed')
	assert outer.content_height().to_double() == 160
	assert inner.content_height().to_double() == 160
	assert feed.offset.y().to_double() == 110
	assert feed.content_height().to_double() == 50
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

fn test_fixed_table_auto_columns_ignore_cell_padding_and_later_rows() {
	document := html.parse_document('<!doctype html><style>
		table { width:400px; border-spacing:0; table-layout:fixed }
		td { height:10px; padding:0; border:0 } #padded { padding:0 60px } #late { width:75% }
	</style><table><tr><td id="padded"></td><td id="plain"></td></tr><tr><td id="late"></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	padded := used_for_id(result, 'padded')
	plain := used_for_id(result, 'plain')
	late := used_for_id(result, 'late')
	assert padded.border_box_width().to_double() == 200
	assert padded.content_width().to_double() == 80
	assert plain.border_box_width().to_double() == 200
	assert plain.offset.x().to_double() == 200
	assert late.border_box_width().to_double() == 200
}

fn test_fixed_table_percentage_cell_adds_content_box_offsets() {
	document := html.parse_document('<!doctype html><style>
		table { width:600px; border-spacing:0; table-layout:fixed }
		td { height:10px; padding:0; border:0 } #percentage { width:25%; padding:0 10px }
	</style><table><tr><td id="percentage"></td><td id="auto"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	percentage := used_for_id(result, 'percentage')
	auto := used_for_id(result, 'auto')
	assert percentage.content_width().to_double() == 150
	assert percentage.border_box_width().to_double() == 170
	assert auto.border_box_width().to_double() == 430
	assert auto.offset.x().to_double() == 170
}

fn test_fixed_table_cells_shrink_padding_to_stay_within_columns() {
	document := html.parse_document('<!doctype html><style>
		table { width:100px; border-spacing:0; table-layout:fixed }
		td { height:10px; padding:50px 25px; border:0 }
		#middle { width:50% }
	</style><table><tr><td id="left"></td><td id="middle"></td><td id="right"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	left := used_for_id(result, 'left')
	middle := used_for_id(result, 'middle')
	right := used_for_id(result, 'right')
	assert left.border_box_width().to_double() == 0
	assert left.padding_left.to_double() == 0
	assert left.padding_right.to_double() == 0
	assert middle.content_width().to_double() == 50
	assert middle.border_box_width().to_double() == 100
	assert middle.padding_left.to_double() == 25
	assert middle.padding_right.to_double() == 25
	assert right.border_box_width().to_double() == 0
}

fn test_fixed_table_cells_shrink_borders_after_padding() {
	document := html.parse_document('<!doctype html><style>
		table { width:15px; border-spacing:0; table-layout:fixed }
		td { height:10px; padding:0 2px; border:10px solid }
	</style><table><tr><td id="cell"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	cell := used_for_id(result, 'cell')
	assert cell.content_width().to_double() == 0
	assert cell.padding_left.to_double() == 0
	assert cell.padding_right.to_double() == 0
	assert cell.border_left.to_double() == 10
	assert cell.border_right.to_double() == 5
	assert cell.border_box_width().to_double() == 15
}

fn test_collapsed_table_odd_borders_split_between_table_and_cells() {
	document := html.parse_document('<!doctype html><style>
		table { width:100px; border-collapse:collapse; table-layout:fixed; border:1px solid }
		td { height:10px; padding:0; border:1px solid }
	</style><table id="table"><tr><td id="cell"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	cell := used_for_id(result, 'cell')
	assert table.use_collapsing_borders_model()
	assert table.is_collapsed_borders_table_box()
	assert table.border_left_collapsed().to_double() == 1
	assert table.border_right_collapsed().to_double() == 0
	assert table.content_width().to_double() == 99
	assert table.border_box_width().to_double() == 100
	assert cell.use_collapsing_borders_model()
	assert !cell.is_collapsed_borders_table_box()
	assert cell.border_left_collapsed().to_double() == 0
	assert cell.border_right_collapsed().to_double() == 1
	assert cell.content_width().to_double() == 98
	assert cell.border_box_width().to_double() == 99
}

fn test_percentage_collapsed_table_resolves_border_box_from_split_outer_borders() {
	document := html.parse_document('<!doctype html><style>
		body { margin:8px }
		table { width:100%; border-collapse:collapse }
		td { border:1px solid }
	</style><table id="table"><tr><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table_node := layout_node_with_id(result.root, 'table') or { panic('missing table') }
	wrapper_node := table_node.parent() or { panic('table has no wrapper') }
	wrapper_styled := wrapper_node.as_node_with_style() or { panic('wrapper has no style') }
	wrapper := result.used_values_for(wrapper_styled) or { panic('wrapper has no used values') }
	table := used_for_id(result, 'table')
	assert wrapper.content_width().to_double() == 784
	assert table.content_width().to_double() == 783
	assert table.border_box_width().to_double() == 784
}

fn test_inline_block_intrinsic_width_includes_anonymous_collapsed_table_outer_border() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		table { border-collapse:collapse; border-spacing:20px 10px; border:1px solid }
		td { padding:10px 20px; border:1px solid }
		.horizontal > * { display:inline-block }
	</style><div class="horizontal"><table id="outer">
		<tbody><tr><td>A</td><td>B</td><td>1</td></tr></tbody>
	</table></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	outer_node := layout_node_with_id(result.root, 'outer') or { panic('missing outer') }
	outer := used_for_id(result, 'outer')
	inner_wrapper := outer_node.children().filter(it.is_table_wrapper())[0]
	inner_styled := inner_wrapper.as_node_with_style() or { panic('inner wrapper has no style') }
	inner := result.used_values_for(inner_styled) or { panic('inner wrapper has no used values') }
	assert outer.content_width() == inner.content_width()
	inner_table := inner_wrapper.children().filter(it.display().is_table_inside())[0]
	inner_table_styled := inner_table.as_node_with_style() or { panic('inner table has no style') }
	inner_table_used := result.used_values_for(inner_table_styled) or {
		panic('inner table has no used values')
	}
	assert inner.derived_first_baseline() or { panic('inner wrapper has no baseline') } ==
		inner_table_used.offset.y().plus(inner_table_used.derived_first_baseline() or {
			panic('inner table has no baseline')
		})
}

fn test_collapsed_table_uses_winning_outer_grid_borders() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 }
		table { border-collapse:collapse }
		td { width:20px; height:10px; padding:0; border:5px solid }
	</style><table id="table"><tr><td id="cell"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	cell := used_for_id(result, 'cell')
	assert table.border_left.to_double() == 5
	assert table.border_right.to_double() == 5
	assert table.border_top.to_double() == 5
	assert table.border_bottom.to_double() == 5
	// The table owns the inside half of its outer grid border. Odd widths put
	// the remainder on the start edges.
	assert table.border_box_left().to_double() == 3
	assert table.border_box_right().to_double() == 2
	assert table.border_box_top().to_double() == 3
	assert table.border_box_bottom().to_double() == 2
	assert table.offset.x().to_double() == 3
	assert table.offset.y().to_double() == 3
	assert cell.border_left.to_double() == 5
	assert cell.border_right.to_double() == 5
}

fn test_missing_collapsed_table_cells_take_no_border_share() {
	document := html.parse_document('<!doctype html><style>
		table { border-collapse:collapse }
		td { border:10px solid; padding:0; width:20px; height:20px }
		#spacer { height:4px }
	</style><table id="table"><tr id="first"><td></td><td></td></tr><tr id="empty"></tr><tr id="spacer"></tr><tr id="last"><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	empty_node := layout_node_with_id(result.root, 'empty') or { panic('missing empty row') }
	missing_cell := empty_node.first_child() or { panic('missing generated cell') }
	assert missing_cell.is_missing_table_cell()
	missing_styled := missing_cell.as_node_with_style() or { panic('missing cell has no style') }
	missing := result.used_values_for(missing_styled) or { panic('missing cell has no used values') }
	assert missing.use_collapsing_borders_model()
	assert missing.border_left.to_double() == 0
	assert missing.border_right.to_double() == 0
	assert missing.border_top.to_double() == 0
	assert missing.border_bottom.to_double() == 0
	assert used_for_id(result, 'first').content_height().to_double() == 30
	assert used_for_id(result, 'empty').content_height().to_double() == 0
	assert used_for_id(result, 'spacer').content_height().to_double() == 4
	assert used_for_id(result, 'last').content_height().to_double() == 30
	assert used_for_id(result, 'table').content_height().to_double() == 64
}

fn test_table_cell_height_uses_content_box_except_for_border_box_and_quirks() {
	standards := html.parse_document('<!doctype html><style>
		table { border-spacing:0 } td { height:20px; padding:3px; border:2px solid }
		#border-box { box-sizing:border-box }
	</style><table><tr id="content-row"><td></td></tr></table><table><tr id="border-row"><td id="border-box"></td></tr></table>')
	standards_result := run_document_layout(standards, 800, 600) or { panic('layout failed') }
	assert used_for_id(standards_result, 'content-row').content_height().to_double() == 30
	assert used_for_id(standards_result, 'border-row').content_height().to_double() == 20

	quirks := html.parse_document('<style>
		table { border-spacing:0 } td { height:20px; padding:3px; border:2px solid }
	</style><table><tr id="quirks-row"><td></td></tr></table>')
	quirks_result := run_document_layout(quirks, 800, 600) or { panic('layout failed') }
	assert used_for_id(quirks_result, 'quirks-row').content_height().to_double() == 20
}

fn test_collapsed_table_ignores_authored_padding() {
	document := html.parse_document('<!doctype html><style>
		table { padding:10px; border:2px solid; border-spacing:0 }
		#collapsed { border-collapse:collapse }
		td { width:20px; height:10px; padding:0 }
	</style><table id="collapsed"><tr><td></td></tr></table><table id="separate"><tr><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	collapsed := used_for_id(result, 'collapsed')
	assert collapsed.padding_left.to_double() == 0
	assert collapsed.padding_right.to_double() == 0
	assert collapsed.padding_top.to_double() == 0
	assert collapsed.padding_bottom.to_double() == 0
	assert collapsed.border_box_left().to_double() == 1
	assert collapsed.border_box_top().to_double() == 1
	separate := used_for_id(result, 'separate')
	assert separate.padding_left.to_double() == 10
	assert separate.padding_right.to_double() == 10
	assert separate.padding_top.to_double() == 10
	assert separate.padding_bottom.to_double() == 10
}

fn test_table_lays_out_first_header_first_and_first_footer_last() {
	document := html.parse_document('<!doctype html><style>
		#table { display:table; border-spacing:0 }
		.group { display:table-row-group }
		.header { display:table-header-group }
		.footer { display:table-footer-group }
		.row { display:table-row; height:10px }
		.cell { display:table-cell }
	</style><div id="table">
		<div class="footer"><div class="row" id="footer"><div class="cell"></div></div></div>
		<div class="header"><div class="row" id="header"><div class="cell"></div></div></div>
		<div class="group"><div class="row" id="body"><div class="cell"></div></div></div>
		<div class="header"><div class="row" id="second-header"><div class="cell"></div></div></div>
		<div class="footer"><div class="row" id="second-footer"><div class="cell"></div></div></div>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'header').offset.y().to_double() == 0
	assert used_for_id(result, 'body').offset.y().to_double() == 10
	assert used_for_id(result, 'second-header').offset.y().to_double() == 20
	assert used_for_id(result, 'second-footer').offset.y().to_double() == 30
	assert used_for_id(result, 'footer').offset.y().to_double() == 40
}

fn test_table_row_groups_span_their_rows_across_loose_rows() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } #table { display:table; border-spacing:0 }
		.row { display:table-row } .group { display:table-row-group }
		.cell { display:table-cell; width:50px; height:20px }
	</style><div id="table">
		<div class="row"><div class="cell"></div></div>
		<div class="group" id="first-group"><div class="row"><div class="cell"></div></div></div>
		<div class="row"><div class="cell"></div></div>
		<div class="group" id="second-group"><div class="row"><div class="cell"></div></div><div class="row"><div class="cell"></div></div></div>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first-group')
	second := used_for_id(result, 'second-group')
	assert first.offset.y().to_double() == 20
	assert first.content_height().to_double() == 20
	assert second.offset.y().to_double() == 60
	assert second.content_height().to_double() == 40
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
	assert used_for_id(result, 'top-table').margin_bottom.to_double() == 0
	assert used_for_id(result, 'bottom-cell').offset.y().to_double() == 10
	assert used_for_id(result, 'bottom-caption').offset.y().to_double() == 20
	assert used_for_id(result, 'bottom-table').content_height().to_double() == 20
	assert used_for_id(result, 'bottom-table').margin_bottom.to_double() == 0
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

fn test_table_rowspan_zero_matches_upstream_unimplemented_downward_growth() {
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
	assert two.offset.x().to_double() == 0
	assert three.offset.x().to_double() == 0
	assert span.offset.y().to_double() == 45
	assert one.offset.y().to_double() == 45
	assert two.offset.y().to_double() == 105
	assert three.offset.y().to_double() == 135
	assert body.offset.x().to_double() == 0
	assert body.offset.y().to_double() == 0
	assert body.content_width().to_double() == 200
	assert body.content_height().to_double() == 150
}

fn test_percentage_table_cell_height_is_applied_during_second_layout_pass() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; height:100px; border-spacing:0 } td { padding:0 }
		#sized { height:60%; vertical-align:top } #row { height:80px }
	</style><table><tr id="row"><td id="sized"><div style="height:10px"></div></td><td></td></tr><tr><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	sized := used_for_id(result, 'sized')
	assert sized.content_height().to_double() == 60
	assert sized.padding_top.to_double() == 0
	assert sized.padding_bottom.to_double() == 20
}

fn test_percentage_table_cell_alignment_retains_signed_row_difference() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; height:100px; border-spacing:0 } td { padding:0 }
		#fixed-row { height:80px } #sized { height:60%; vertical-align:top }
	</style><table><tr><td id="sized"><div style="height:10px"></div></td><td></td></tr><tr id="fixed-row"><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	sized := used_for_id(result, 'sized')
	assert sized.content_height().to_double() == 60
	assert sized.padding_bottom.to_double() == -17.140625
}

fn test_collapsed_table_row_has_zero_height_and_does_not_advance_row_cursor() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 } table { width:150px; border-spacing:3px 5px }
		td { padding:2px; border:1px solid }
	</style><table id="table"><tbody id="group"><tr id="first" style="height:20px"><td>a</td></tr>
		<tr id="collapsed" style="visibility:collapse;height:70px"><td id="collapsed-cell" style="height:50px">b</td></tr>
		<tr id="last" style="height:30px"><td>c</td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	group := used_for_id(result, 'group')
	first := used_for_id(result, 'first')
	collapsed := used_for_id(result, 'collapsed')
	last := used_for_id(result, 'last')
	collapsed_cell := used_for_id(result, 'collapsed-cell')
	assert table.content_height().to_double() == 68
	assert group.content_height().to_double() == 58
	assert first.content_height().to_double() == 23
	assert first.offset.y().to_double() == 5
	assert collapsed.content_height().to_double() == 0
	assert collapsed.offset.y().to_double() == 33
	assert last.content_height().to_double() == 30
	assert last.offset.y().to_double() == 33
	// Collapsed cells are still laid out. Positioning applies the signed
	// alignment difference against their zero-height row.
	assert collapsed_cell.content_height().to_double() == 17
	assert collapsed_cell.padding_top.to_double() == -9.5
	assert collapsed_cell.padding_bottom.to_double() == -9.5
}

fn test_collapsed_table_column_has_zero_width_and_no_border_spacing() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 }
		table { width:340px; border-spacing:10px; table-layout:fixed }
		col { width:100px } td { height:10px; padding:0; border:0 }
	</style><table id="table"><col><col id="collapsed" style="visibility:collapse"><col>
		<tr id="row"><td id="first"></td><td id="middle"></td><td id="last"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	collapsed_column := used_for_id(result, 'collapsed')
	row := used_for_id(result, 'row')
	first := used_for_id(result, 'first')
	middle := used_for_id(result, 'middle')
	last := used_for_id(result, 'last')
	assert table.content_width().to_double() == 230
	assert collapsed_column.content_width().to_double() == 0
	assert row.content_width().to_double() == 210
	assert first.content_width().to_double() == 100
	assert first.offset.x().to_double() == 10
	assert middle.content_width().to_double() == 0
	assert middle.hidden_by_collapsed_columns()
	assert middle.offset.x().to_double() == 120
	assert last.content_width().to_double() == 100
	assert !last.hidden_by_collapsed_columns()
	assert last.offset.x().to_double() == 120
}

fn test_collapsed_table_column_hides_only_cells_wholly_inside_it_from_paint() {
	document := html.parse_document('<!doctype html><style>
		table { border-spacing:4px } td { padding:0; width:50px; height:50px }
		.collapsed { visibility:collapse }
	</style><table><col><col class="collapsed"><col><tr>
		<td id="visible"></td><td id="hidden"><div id="hidden-child"></div></td>
		<td id="spanning" colspan="2"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'hidden').hidden_by_collapsed_columns()
	assert !used_for_id(result, 'visible').hidden_by_collapsed_columns()
	assert !used_for_id(result, 'spanning').hidden_by_collapsed_columns()
	hidden := document.get_element_by_id('hidden') or { panic('missing hidden cell') }
	hidden_child := document.get_element_by_id('hidden-child') or { panic('missing hidden child') }
	visible := document.get_element_by_id('visible') or { panic('missing visible cell') }
	spanning := document.get_element_by_id('spanning') or { panic('missing spanning cell') }
	assert result.paint_tree.find_box(i64(hidden.as_node().unique_id())) == none
	assert result.paint_tree.find_box(i64(hidden_child.as_node().unique_id())) == none
	assert result.paint_tree.find_box(i64(visible.as_node().unique_id())) != none
	assert result.paint_tree.find_box(i64(spanning.as_node().unique_id())) != none
}

fn test_block_container_vertical_align_does_not_shift_its_own_text() {
	font_face := $if macos {
		'@font-face { font-family:Ahem; src:url("file:///System/Library/Fonts/Supplemental/Arial.ttf") }'
	} $else {
		''
	}
	document := html.parse_document('<!doctype html><style>${font_face}
		table, div { font:1.25em/1 Ahem }
		table { table-layout:fixed; width:420px; border-spacing:4px }
		td { padding:1px 0 }
	</style><table><tr id="row"><td id="cell">col</td></tr></table><div id="after">ref</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	cell := used_for_id(result, 'cell')
	after := used_for_id(result, 'after')
	assert cell.line_boxes.len == 1
	assert cell.line_boxes[0].height().to_double() == after.line_boxes[0].height().to_double()
	assert cell.content_height().to_double() == after.content_height().to_double()
	assert used_for_id(result, 'row').content_height().to_double() == cell.content_height().to_double() + 2
}

fn test_collapsed_table_column_group_collapses_its_columns() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 }
		table { width:340px; border-spacing:10px; table-layout:fixed }
		col { width:100px } td { height:10px; padding:0; border:0 }
	</style><table id="table"><col><colgroup id="group" style="visibility:collapse"><col></colgroup><col>
		<tr><td></td><td id="middle"></td><td id="last"></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'table').content_width().to_double() == 230
	assert used_for_id(result, 'group').content_width().to_double() == 0
	assert used_for_id(result, 'middle').content_width().to_double() == 0
	assert used_for_id(result, 'last').offset.x().to_double() == 120
}

fn test_collapsed_table_row_group_spans_its_positioned_rows() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 } table { width:150px; height:160px; border-spacing:3px 5px }
		td { padding:2px; border:1px solid }
	</style><table id="table"><tbody id="collapsed-group" style="visibility:collapse">
		<tr id="collapsed-one"><td></td></tr><tr id="collapsed-two"><td></td></tr></tbody>
		<tbody id="visible-group"><tr id="visible"><td></td></tr></tbody></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	collapsed_group := used_for_id(result, 'collapsed-group')
	visible_group := used_for_id(result, 'visible-group')
	assert used_for_id(result, 'collapsed-one').content_height().to_double() == 0
	assert used_for_id(result, 'collapsed-two').content_height().to_double() == 0
	assert collapsed_group.offset.y().to_double() == 5
	// Both collapsed rows occupy the same grid line, so their group is empty at
	// that line instead of acquiring synthetic spacing between them.
	assert collapsed_group.content_height().to_double() == 0
	assert visible_group.offset.y().to_double() == 5
	assert used_for_id(result, 'visible').offset.y().to_double() == 5
	// The specified height includes the spacing around the only visible row.
	assert used_for_id(result, 'visible').content_height().to_double() == 150
	assert table.content_height().to_double() == 160
}

fn test_table_auto_row_height_distribution_truncates_fractional_increment() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 } table { width:120px; height:137px; border-spacing:0; table-layout:fixed }
		td { padding:2px; border:1px solid } td div { height:7px }
	</style><table id="table"><tr id="one"><td><div></div></td></tr>
		<tr id="two"><td><div></div></td></tr><tr id="three"><td><div></div></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'one').content_height().to_double() == 45.65625
	assert used_for_id(result, 'two').content_height().to_double() == 45.65625
	assert used_for_id(result, 'three').content_height().to_double() == 45.65625
	// Three truncated shares total 1/32px less than the table's minimum.
	assert used_for_id(result, 'table').content_height().to_double() == 137
}

fn test_percentage_height_rowspan_cell_is_relaid_out_in_second_pass() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 } table { width:120px; height:100px; border-spacing:0; table-layout:fixed }
		tr { height:50px } td { padding:0 } #span { height:60%; vertical-align:top }
	</style><table><tr><td id="span" rowspan="2"><div style="height:7px"></div></td><td></td></tr>
		<tr><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	span := used_for_id(result, 'span')
	assert span.content_height().to_double() == 60
	assert span.padding_bottom.to_double() == 40
}

fn test_table_rowspan_height_uses_intrinsic_row_measure_contributions() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 } table { width:180px; table-layout:fixed; border-spacing:0 }
		td { padding:2px; border:1px solid }
	</style><table id="table"><tr id="first"><td id="span" rowspan="2"><div style="height:100px"></div></td>
		<td><div style="height:11px"></div></td></tr><tr id="second"><td><div style="height:23px"></div></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	span := used_for_id(result, 'span')
	// compute_table_measures<Row>() distributes the spanning contribution in
	// proportion to the previous max-content row measures. The former equal
	// shortfall split produced 47px and 59px here.
	assert first.content_height().to_double() == 39.5
	assert second.content_height().to_double() == 66.5
	assert second.offset.y().to_double() == 39.5
	assert span.content_height().to_double() == 100
	assert used_for_id(result, 'table').content_height().to_double() == 106
}

fn test_table_cell_min_height_affects_row_measure_but_not_cell_content_height() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin:0 } table { width:120px; table-layout:fixed; border-spacing:0 }
		td { padding:2px; border:1px solid } #span { min-height:29px }
	</style><table><tr><td id="span" rowspan="2"><div style="height:7px"></div></td><td><div style="height:11px"></div></td></tr>
		<tr><td><div style="height:23px"></div></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	span := used_for_id(result, 'span')
	// LibWeb applies min-height to intrinsic row measures. It does not clamp
	// the automatic content height written back by the cell's first layout pass.
	assert span.content_height().to_double() == 7
}

fn test_table_caption_flows_inside_the_wrapper_with_its_outer_edges() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; border-spacing:0 } caption { height:10px; margin:3px 7px; padding:5px } td { height:20px; padding:0 }
	</style><table><caption id="caption"><div></div></caption><tr><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	caption := used_for_id(result, 'caption')
	assert caption.offset.x().to_double() == 12
	assert caption.offset.y().to_double() == 8
}

fn test_table_caption_uses_its_content_width_to_lay_out_descendants() {
	document := html.parse_document('<!doctype html><style>
		table { width:200px; border-spacing:0 } caption { width:50%; height:10px; padding:5px } td { height:20px; padding:0 }
	</style><table><caption id="caption"><div id="inside"></div></caption><tr><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	caption := used_for_id(result, 'caption')
	inside := used_for_id(result, 'inside')
	assert caption.content_width().to_double() == 100
	assert caption.offset.x().to_double() == 5
	assert inside.content_width().to_double() == 100
	assert inside.offset.x().to_double() == 0
}

fn test_table_wrapper_flow_includes_bottom_captions_and_stretches_the_grid() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0; padding:0 } table { border-spacing:0 } .flex { display:flex } .table { display:table }
		.cell { display:table-cell } .sizer { width:20px; height:100px }
		caption { height:20px } td { height:30px }
	</style><table id="bottom"><caption style="caption-side:bottom"></caption><tr><td></td></tr></table>
	<div class="flex"><div id="stretched" class="table"><div style="display:table-caption;height:20px"></div><div class="cell"></div></div><div class="sizer"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	bottom_node := layout_node_with_id(result.root, 'bottom') or { panic('missing bottom table') }
	bottom_wrapper := bottom_node.parent() or { panic('missing bottom table wrapper') }
	bottom_wrapper_state := result.used_values_for(bottom_wrapper.as_node_with_style() or {
		panic('bottom wrapper has no style')
	}) or { panic('bottom wrapper has no used values') }
	assert bottom_wrapper_state.content_height().to_double() == 50

	stretched_node := layout_node_with_id(result.root, 'stretched') or {
		panic('missing stretched table')
	}
	stretched_wrapper := stretched_node.parent() or { panic('missing stretched wrapper') }
	stretched_wrapper_state := result.used_values_for(stretched_wrapper.as_node_with_style() or {
		panic('stretched wrapper has no style')
	}) or { panic('stretched wrapper has no used values') }
	assert stretched_wrapper_state.content_height().to_double() == 100
	assert used_for_id(result, 'stretched').content_height().to_double() == 80
}

fn test_table_caption_capmin_includes_outer_edges_and_definite_width() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		table { border-spacing:0 }
		caption { width:120px; margin:0 3px; border:2px solid; padding:0 5px }
	</style><table id="table"><caption id="caption"></caption></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	caption := used_for_id(result, 'caption')
	assert caption.content_width().to_double() == 120
	assert caption.margin_box_width().to_double() == 140
	assert table.content_width().to_double() == 140
}

fn test_table_caption_capmin_resolves_intrinsic_and_border_box_widths() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } table { border-spacing:0 } td { padding:0; width:100px }
		caption { font:20px/1 monospace }
	</style>
	<table id="fit"><caption style="width:fit-content">AAAA BBBB CCCC</caption><tr><td>x</td></tr></table>
	<table id="max"><caption style="width:max-content">AAAA BBBB CCCC</caption><tr><td>x</td></tr></table>
	<table id="border"><caption id="border-caption" style="width:200px;box-sizing:border-box;padding:0 20px">AAAA</caption><tr><td>x</td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'fit').content_width().to_double() == 100
	assert used_for_id(result, 'max').content_width().to_double() > 100
	assert used_for_id(result, 'border').content_width().to_double() == 200
	assert used_for_id(result, 'border-caption').content_width().to_double() == 160
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

fn test_spanning_table_measure_zero_baseline_truncates_fraction() {
	mut minimums := []CSSPixels{len: 3, init: CSSPixels.new(0)}
	mut maximums := []CSSPixels{len: 3, init: CSSPixels.new(0)}
	placements := [TableCellPlacement{
		column_span: 3
	}]
	measures := [TableCellIntrinsicWidthMeasures{
		outer_min_width: CSSPixels.new(10)
		outer_max_width: CSSPixels.new(10)
	}]
	compute_spanning_table_column_measures(mut minimums, mut maximums, placements, measures, CSSPixels.new(0), 3, false)
	// CSSPixels(10) / 3 is a CSSPixelFraction. Converting it for each
	// contribution truncates raw 640 / 3 to raw 213.
	for index in 0 .. 3 {
		assert minimums[index].raw_value() == 213
		assert maximums[index].raw_value() == 213
	}
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

fn test_legacy_center_does_not_shift_an_oversized_table_before_the_containing_block() {
	document := html.parse_document('<!doctype html><style>
		body { margin:8px } table { min-width:796px; border-spacing:0 }
	</style><center><table id="table"><tr><td></td></tr></table></center>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table_node := layout_node_with_id(result.root, 'table') or { panic('missing table') }
	wrapper_node := table_node.parent() or { panic('table has no wrapper') }
	wrapper_styled := wrapper_node.as_node_with_style() or { panic('wrapper has no style') }
	wrapper := result.used_values_for(wrapper_styled) or { panic('missing wrapper values') }
	assert wrapper.content_width().to_double() == 796
	assert wrapper.offset.x().to_double() == 0
}

fn test_empty_table_row_is_retained_when_the_grid_has_no_columns() {
	document := html.parse_document('<!doctype html><style>
		table { height:100px; padding:10px; border:1px solid; }
	</style><table><tr id="row"></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	row := used_for_id(result, 'row')
	assert row.content_width().to_double() == 0
	// A row without cells still receives the specified table height, less the
	// table's padding, borders and the spacing around the row.
	assert row.content_height().to_double() == 74
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

fn test_table_column_boxes_cover_their_grid_tracks() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } table { width:100px; table-layout:fixed; border-spacing:2px 3px }
		td { height:20px; padding:0 } #first { width:30px }
	</style><table><colgroup id="group"><col id="first"><col id="second"></colgroup><tr><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	group := used_for_id(result, 'group')
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	assert group.offset.x().to_double() == 2
	assert group.offset.y().to_double() == 3
	assert group.content_width().to_double() == 96
	assert group.content_height().to_double() == 20
	assert first.offset.x().to_double() == 0
	assert first.offset.y().to_double() == 0
	assert first.content_width().to_double() == 30
	assert first.content_height().to_double() == 20
	assert second.offset.x().to_double() == 32
	assert second.content_width().to_double() == 64
	assert second.content_height().to_double() == 20
}

fn test_table_column_percentage_resolves_against_table_width() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } table { width:400px; border-spacing:0 } td { padding:0; height:10px }
		#group-first { width:25% }
	</style><table><colgroup id="percentage-group"><col id="group-first"><col id="group-second"></colgroup><tr><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'percentage-group').content_width().to_double() == 400
	assert used_for_id(result, 'group-first').content_width().to_double() == 100
	assert used_for_id(result, 'group-second').content_width().to_double() == 300
}

fn test_empty_column_group_does_not_create_a_grid_track() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } table { border-spacing:4px 2px } td { width:30px; height:10px; padding:0 }
	</style><table id="table"><colgroup><col><col></colgroup><col span="2"><colgroup id="empty"></colgroup><tr><td></td><td></td><td></td><td></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	table := used_for_id(result, 'table')
	empty := used_for_id(result, 'empty')
	assert table.content_width().to_double() == 140
	assert empty.offset.x().to_double() == 140
	assert empty.offset.y().to_double() == 2
	assert empty.content_width().to_double() == 0
	assert empty.content_height().to_double() == 10
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

fn test_css_anchor_positioning_resolves_names_sides_and_fallbacks() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { position:relative; width:300px; height:200px }
		#a1 { anchor-name:--a1; position:absolute; left:100px; top:50px; width:80px; height:40px }
		#a2 { anchor-name:--a2; position:absolute; left:220px; top:120px; width:50px; height:30px }
		#bordered-anchor { anchor-name:--bordered; position:absolute; left:20px; top:10px; width:40px; height:20px; padding:5px; border:3px solid }
		.target { position:absolute; width:10px; height:10px; position-anchor:--a1 }
		#default { left:anchor(right); top:anchor(bottom) }
		#explicit { left:anchor(--a2 left); top:anchor(--a2 top) }
		#bordered { left:anchor(--bordered right); top:anchor(--bordered bottom) }
		#wrong-axis { left:anchor(top, 17px); top:anchor(left, 19px) }
		#chain { left:anchor(--missing center, anchor(--a1 center)); top:anchor(--missing center, anchor(--also-missing center, 33px)) }
	</style><div id="container"><div id="a1"></div><div id="a2"></div><div id="bordered-anchor"></div>
		<div id="default" class="target"></div><div id="explicit" class="target"></div>
		<div id="bordered" class="target"></div><div id="wrong-axis" class="target"></div>
		<div id="chain" class="target"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	default_target := used_for_id(result, 'default')
	explicit := used_for_id(result, 'explicit')
	bordered := used_for_id(result, 'bordered')
	wrong_axis := used_for_id(result, 'wrong-axis')
	chain := used_for_id(result, 'chain')
	assert default_target.offset.x().to_double() == 180
	assert default_target.offset.y().to_double() == 90
	assert explicit.offset.x().to_double() == 220
	assert explicit.offset.y().to_double() == 120
	assert bordered.offset.x().to_double() == 76
	assert bordered.offset.y().to_double() == 46
	assert wrong_axis.offset.x().to_double() == 17
	assert wrong_axis.offset.y().to_double() == 19
	assert chain.offset.x().to_double() == 140
	assert chain.offset.y().to_double() == 33
}

fn test_css_anchor_positioning_resolves_anchor_functions_in_calculations() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { position:relative; width:400px; height:200px }
		#a1 { anchor-name:--a1; position:absolute; left:40px; top:30px; width:80px; height:50px }
		#a2 { anchor-name:--a2; position:absolute; left:180px; top:100px; width:40px; height:20px }
		.target { position:absolute; width:10px; height:10px }
		#sum { position-anchor:--a1; left:calc(anchor(right) + 10px); top:calc(anchor(bottom) + 5px) }
		#compare { left:max(anchor(--a1 left), anchor(--a2 left)); top:min(anchor(--a1 bottom), anchor(--a2 top)) }
		#fallback { left:calc(anchor(--missing right, anchor(--a1 center)) + 3px); top:calc(anchor(--missing bottom, 17px) + 2px) }
		#calc-fallback { left:anchor(--missing right, calc(anchor(--a2 left) + 7px)); top:anchor(--missing bottom, calc(anchor(--a1 bottom) + 6px)) }
	</style><div id="container"><div id="a1"></div><div id="a2"></div>
		<div id="sum" class="target"></div><div id="compare" class="target"></div>
		<div id="fallback" class="target"></div><div id="calc-fallback" class="target"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	sum := used_for_id(result, 'sum')
	compare := used_for_id(result, 'compare')
	fallback := used_for_id(result, 'fallback')
	calc_fallback := used_for_id(result, 'calc-fallback')
	assert sum.offset.x().to_double() == 130
	assert sum.offset.y().to_double() == 85
	assert compare.offset.x().to_double() == 180
	assert compare.offset.y().to_double() == 80
	assert fallback.offset.x().to_double() == 83
	assert fallback.offset.y().to_double() == 19
	assert calc_fallback.offset.x().to_double() == 187
	assert calc_fallback.offset.y().to_double() == 86
}

fn test_span_all_position_area_unites_the_containing_block_and_centers_on_anchor() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		#fixed-anchor { position:absolute; left:300px; top:100px; width:100px; height:50px; anchor-name:--fixed }
		#fixed-target { position:fixed; position-anchor:--fixed; position-area:span-all; top:calc(anchor(bottom) + 10px); width:200px; height:40px }
		#padded { position:absolute; left:50px; top:250px; width:300px; height:160px; padding:40px }
		#padded-anchor { position:absolute; left:100px; top:40px; width:80px; height:40px; anchor-name:--padded }
		#padded-target { position:absolute; position-anchor:--padded; position-area:span-all; width:160px; height:30px }
		#overhang { position:absolute; left:500px; top:300px; width:200px; height:150px }
		#overhang-anchor { position:absolute; left:-100px; top:-60px; width:40px; height:20px; anchor-name:--overhang }
		#overhang-target { position:absolute; position-anchor:--overhang; position-area:span-all; left:10px; top:calc(anchor(bottom) + 10px); width:50%; height:50% }
		#grid { position:absolute; display:grid; left:50px; top:480px; width:300px; height:100px; grid-template-columns:200px 100px; grid-template-rows:100px }
		#grid-anchor { position:absolute; left:50px; top:20px; width:40px; height:20px; anchor-name:--grid }
		#grid-target { position:absolute; grid-column:1 / 2; grid-row:1 / 2; position-anchor:--grid; position-area:span-all; justify-self:end; align-self:start; width:60px; height:20px }
	</style><div id="fixed-anchor"></div><div id="fixed-target"></div>
	<div id="padded"><div id="padded-anchor"></div><div id="padded-target"></div></div>
	<div id="overhang"><div id="overhang-anchor"></div><div id="overhang-target"></div></div>
	<div id="grid"><div id="grid-anchor"></div><div id="grid-target"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	fixed := used_for_id(result, 'fixed-target')
	padded := used_for_id(result, 'padded-target')
	overhang := used_for_id(result, 'overhang-target')
	grid := used_for_id(result, 'grid-target')
	assert fixed.cumulative_offset().x().to_double() == 250
	assert fixed.cumulative_offset().y().to_double() == 160
	assert padded.cumulative_offset().x().to_double() == 110
	assert padded.cumulative_offset().y().to_double() == 295
	assert overhang.cumulative_offset().x().to_double() == 410
	assert overhang.cumulative_offset().y().to_double() == 270
	assert overhang.content_width().to_double() == 150
	assert overhang.content_height().to_double() == 105
	assert grid.cumulative_offset().x().to_double() == 190
	assert grid.cumulative_offset().y().to_double() == 480
}

fn test_css_anchor_positioning_skips_ineligible_later_named_elements() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { position:relative; width:300px; height:200px }
		#eligible { anchor-name:--shared; position:absolute; left:40px; top:20px; width:30px; height:10px }
		#ineligible { anchor-name:--shared; display:none }
		#target { position:absolute; position-anchor:--shared; left:anchor(right, 7px); top:anchor(bottom, 9px); width:10px; height:10px }
	</style><div id="container"><div id="eligible"></div><div id="ineligible"></div><div id="target"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	target := used_for_id(result, 'target')
	assert target.offset.x().to_double() == 70
	assert target.offset.y().to_double() == 30
}

fn test_css_anchor_positioning_resolves_logical_inside_and_percentage_sides() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { position:relative; direction:rtl; width:300px; height:200px }
		#anchor { anchor-name:--a; position:absolute; left:100px; top:50px; width:80px; height:40px }
		.target { position:absolute; position-anchor:--a; direction:ltr; width:10px; height:10px }
		#start { left:anchor(start); top:anchor(end) }
		#self-start { left:anchor(self-start); top:anchor(self-start) }
		#inside-end { right:anchor(inside); bottom:anchor(inside) }
		#outside { left:anchor(outside); top:anchor(outside) }
		#percentage { left:anchor(25%); top:anchor(25%) }
	</style><div id="container"><div id="anchor"></div><div id="start" class="target"></div>
		<div id="self-start" class="target"></div><div id="inside-end" class="target"></div>
		<div id="outside" class="target"></div><div id="percentage" class="target"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	start := used_for_id(result, 'start')
	self_start := used_for_id(result, 'self-start')
	inside_end := used_for_id(result, 'inside-end')
	outside := used_for_id(result, 'outside')
	percentage := used_for_id(result, 'percentage')
	assert start.offset.x().to_double() == 180
	assert start.offset.y().to_double() == 90
	assert self_start.offset.x().to_double() == 100
	assert self_start.offset.y().to_double() == 50
	assert inside_end.offset.x().to_double() == 170
	assert inside_end.offset.y().to_double() == 80
	assert outside.offset.x().to_double() == 180
	assert outside.offset.y().to_double() == 90
	assert percentage.offset.x().to_double() == 160
	assert percentage.offset.y().to_double() == 60
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

fn test_block_abspos_static_position_includes_pending_collapsed_margin() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:100px }
		#flow { height:20px; margin-bottom:30px }
		#absolute { position:absolute; width:10px; height:10px }
	</style><div id="container"><div id="flow"></div><div id="absolute"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 0
	assert absolute.offset.y().to_double() == 50
}

// The static position marker is recorded at the line's inline length and
// block start, not at the preceding atomic inline's baseline-aligned offset.
fn test_inline_abspos_auto_insets_follow_the_line_marker() {
	document := html.parse_document('<!doctype html><style>
		#container { position:relative; width:100px }
		#atomic { display:inline-block; width:20px; height:10px }
		#absolute { position:absolute; width:10px; height:10px }
	</style><div id="container"><span id="atomic"></span><span id="absolute"></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.offset.x().to_double() == 20
	assert absolute.offset.y().to_double() == 0
}

fn test_baseline_aligned_inline_block_keeps_the_containing_strut_descent() {
	document := html.parse_document('<!doctype html><style>
		#container { width:100px; font:16px/16px SerenitySans }
		#atomic { display:inline-block; width:10px; height:30px }
	</style><div id="container"><span id="atomic"></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container := used_for_id(result, 'container')
	container_node := layout_node_with_id(result.root, 'container') or { panic('missing container') }
	computed := container_node.computed_values()
	metrics := layout_font_metrics_for_node(container_node)
	baseline := font_baseline_for_line_height(metrics, computed.line_height())
	expected_height := CSSPixels.new(30).plus(computed.line_height().minus(baseline))
	assert container.content_height().raw_value() == expected_height.raw_value()
}

fn test_line_box_baseline_comes_from_final_unshifted_text_fragment() {
	document := html.parse_document('<!doctype html><style>
		.ib { display:inline-block }
		.label { display:inline-block; border:1px solid; font-size:20px }
		button { display:inline-block; border:1px solid; font-size:40px }
	</style><div id="outer" class="ib"><div class="label">A</div> <button>B</button></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	outer := used_for_id(result, 'outer')
	assert outer.line_boxes.len == 1
	line := outer.line_boxes[0]
	text_fragment := line.fragments().filter(it.layout_node().is_text_node())[0]
	assert line.baseline() == text_fragment.block_offset().plus(text_fragment.baseline())
}

fn test_atomic_inline_applies_calculated_vertical_align_offset() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0; padding:0; font:16px SerenitySans }
		body { line-height:5rem }
		#icon { display:inline-block; width:16px; height:16px;
			vertical-align:calc(0.5px + 0.3465em - 0.5rem) }
	</style><body id="body">Get in touch<span id="icon"></span></body>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	body := used_for_id(result, 'body')
	assert body.content_height().to_double() == 80
	assert body.line_boxes.len == 1
	fragments := body.line_boxes[0].fragments()
	assert fragments.len == 2
	assert fragments[1].is_atomic_inline()
	assert fragments[1].block_offset().to_double() == 30
}

fn test_inline_display_native_inputs_are_atomic_inlines() {
	document := html.parse_document('<!doctype html><style>
		input { display:inline }
	</style><div id="container"><span id="plain">a</span><input id="submit" type="submit" value="PASS"><input id="reset" type="reset"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	plain := layout_node_with_id(result.root, 'plain') or { panic('missing #plain') }
	assert !plain.is_replaced_element()
	assert !plain.is_atomic_inline()
	// Button-type inputs keep their inline flow display; text-like inputs are
	// already adjusted to inline-block by their computed style.
	submit := layout_node_with_id(result.root, 'submit') or { panic('missing #submit') }
	reset := layout_node_with_id(result.root, 'reset') or { panic('missing #reset') }
	for input in [submit, reset] {
		assert input.display().is_inline_outside()
		assert input.display().is_flow_inside()
		assert !input.is_replaced_box()
		assert input.is_replaced_element()
		assert input.is_atomic_inline()
	}
	// The line places each control as one atomic fragment instead of
	// descending into its internal shadow content.
	container := used_for_id(result, 'container')
	assert container.line_boxes.len == 1
	mut fragment_nodes := []voidptr{}
	for fragment in container.line_boxes[0].fragments() {
		fragment_nodes << voidptr(fragment.layout_node())
	}
	assert voidptr(submit) in fragment_nodes
	assert voidptr(reset) in fragment_nodes
}

fn test_text_bottom_atomic_inline_fits_the_parent_content_area() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		#container { display:block; font:14px/20px sans-serif; padding:5px; border:1px solid }
		#icon { vertical-align:text-bottom }
	</style><a id="container"><svg id="icon" width="16" height="16"></svg> Labels</a>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container := used_for_id(result, 'container')
	assert container.content_height().to_double() == 20
	assert container.line_boxes.len == 1
	fragments := container.line_boxes[0].fragments()
	assert fragments.len == 2
	assert fragments[0].is_atomic_inline()
	assert fragments[0].block_offset().to_double() == 1
	assert container.line_boxes[0].height().to_double() == 20
}

fn test_text_top_and_bottom_use_parent_inline_font_metrics() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.line { font:20px/40px SerenitySans }
		.box { display:inline-block; width:20px; height:10px }
		.top { vertical-align:text-top }
		.bottom { vertical-align:text-bottom }
		.parent { font-size:40px }
	</style>
	<div class="line" id="direct">A<span class="box top"></span><span class="box bottom"></span></div>
	<div class="line" id="nested">A<span class="parent">B<span class="box top"></span><span class="box bottom"></span></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['direct', 'nested'] {
		line := used_for_id(result, id).line_boxes[0]
		fragments := line.fragments()
		text_index := if id == 'direct' { 0 } else { 1 }
		top_index := text_index + 1
		bottom_index := text_index + 2
		assert fragments[top_index].block_offset() == fragments[text_index].block_offset()
		assert fragments[bottom_index].block_offset().plus(fragments[bottom_index].block_length()) ==
			fragments[text_index].block_offset().plus(fragments[text_index].block_length())
	}
}

fn test_top_and_bottom_align_complete_inline_subtrees_to_line_edges() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.line { font:20px/20px SerenitySans }
		#top-subtree { vertical-align:top }
		#top-child, #tall, #bottom { display:inline-block; width:20px }
		#top-child { height:40px }
		#tall { height:60px }
		#bottom { height:25px; vertical-align:bottom }
	</style>
	<div class="line" id="top-line">A<span id="top-subtree">B<span id="top-child"></span>C</span>D</div>
	<div class="line" id="bottom-line"><span id="tall"></span><span id="bottom"></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	top_line := used_for_id(result, 'top-line').line_boxes[0]
	assert top_line.fragments()[2].block_offset().to_double() == 0
	bottom_line := used_for_id(result, 'bottom-line').line_boxes[0]
	bottom_fragment := bottom_line.fragments()[1]
	assert bottom_fragment.block_offset().plus(bottom_fragment.block_length()) == bottom_line.block_length()
}

fn test_normal_heading_line_height_uses_selected_font_typo_metrics() {
	document := html.parse_document('<!doctype html><style>h3 { font-family: SerenitySans }</style><h3 id="heading">heading</h3>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	heading := layout_node_with_id(result.root, 'heading') or { panic('missing heading') }
	assert heading.computed_values().font_size().to_double() == 18.71875
	font := heading.first_available_font()
	metrics := font.pixel_metrics()
	assert font.point_size == f32(18.71875)
	// The platform wrapper exposes the selected face under its logical fallback family,
	// while retaining the concrete SerenitySans resource and metrics.
	assert font.family == 'Default'
	assert (font.font_path() or { '' }).ends_with('/3rd/ladybird/Base/res/fonts/SerenitySans-Regular.ttf')
	assert metrics.ascent == f32(14.971344)
	assert metrics.descent == f32(3.747406)
	// normal rounds the two values independently, just like SkFont-backed LibGfx.
	assert heading.computed_values().line_height().to_double() == 19
}

fn test_abspos_static_position_is_converted_to_actual_containing_block_space() {
	document :=
		html.parse_document('<!doctype html>foo <div id="absolute" style="position:absolute">bar</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	absolute := used_for_id(result, 'absolute')
	assert absolute.cumulative_offset().x().to_double() == 8
	assert absolute.cumulative_offset().y().to_double() == 25
}

// Final line alignment moves an atomic inline. An abspos descendant whose
// actual containing block is outside that inline must convert its static
// position through the atomic inline's final, not provisional, offset.
fn test_abspos_static_position_uses_final_atomic_inline_offset() {
	document := html.parse_document('<!doctype html><style>
		body { display:inline; position:relative }
		main { display:inline-block }
		#absolute { position:absolute }
	</style><body><main id="atomic"><div id="absolute">hello</div></main>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	atomic_box := used_for_id(result, 'atomic')
	absolute := used_for_id(result, 'absolute')
	assert atomic_box.cumulative_offset().y().raw_value() > 0
	assert absolute.cumulative_offset().y().raw_value() == atomic_box.cumulative_offset().y().raw_value()
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

fn test_ratio_only_content_replacement_uses_definite_width_for_max_content_size() {
	document := html.parse_document('<!doctype html><style>
		#host { display:flex; width:200px; height:48px }
		#host::before {
			content:url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 40 40\'%3E%3C/svg%3E");
			width:32px; height:fit-content; min-width:fit-content; max-height:32px
		}
	</style><div id="host"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	host := layout_node_with_id(result.root, 'host') or { panic('missing host') }
	image := host.first_child() or { panic('missing generated image') }
	assert image.is_image_box()
	image_style := image.as_node_with_style() or { panic('generated image has no style') }
	mut state := result.state
	used := state.get(image_style)
	assert used.content_width().to_double() == 32
	assert used.content_height().to_double() == 32
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
	assert !box.has_definite_height()
}

fn test_intrinsic_height_keywords_stay_indefinite_for_percentage_children() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.case { height:fit-content }
		.percent { height:100% }
		#fixed-min { position:fixed; top:100px; left:0; width:40px; min-height:48px }
		#fixed-insets { position:fixed; top:200px; bottom:0 }
	</style>
	<div id="normal" class="case"><div id="normal-percent" class="percent">A</div><div>B</div></div>
	<div id="fixed-min" class="case"><div id="fixed-min-percent" class="percent">A</div><div>B</div></div>
	<div id="fixed-insets" class="case"><div id="fixed-insets-percent" class="percent">A</div>B</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'normal').content_height().to_double() == 34
	assert used_for_id(result, 'normal-percent').content_height().to_double() == 17
	assert used_for_id(result, 'fixed-min').content_height().to_double() == 48
	assert used_for_id(result, 'fixed-min-percent').content_height().to_double() == 17
	assert used_for_id(result, 'fixed-insets').content_height().to_double() == 34
	assert used_for_id(result, 'fixed-insets-percent').content_height().to_double() == 17
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

fn test_svg_formatting_context_keeps_geometry_in_viewport_user_units() {
	document :=
		html.parse_document('<!doctype html><style>body { margin:0 }</style><svg id="svg" width="200" height="100" viewBox="0 0 100 50"><g id="group" transform="translate(10 5)"><rect id="shape" x="20" y="10" width="30" height="15"/></g></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	svg_state := used_for_id(result, 'svg')
	assert svg_state.content_width().to_double() == 200
	assert svg_state.content_height().to_double() == 100
	shape := used_for_id(result, 'shape')
	assert shape.offset.x().to_double() == 20
	assert shape.offset.y().to_double() == 10
	assert shape.content_width().to_double() == 30
	assert shape.content_height().to_double() == 15
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

fn test_svg_text_shapes_each_code_point_with_its_computed_font_cascade() {
	$if macos {
		document := html.parse_document('<!doctype html><style>
			@font-face { font-family:Fixture; src:url("file:///System/Library/Fonts/Supplemental/Arial.ttf"); unicode-range:U+41 }
			#label { font-family:Fixture, serif; font-size:40px }
		</style><svg width="240" height="100"><text id="label" x="20" y="60">AB</text></svg>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		label_node := layout_node_with_id(result.root, 'label') or { panic('missing SVG text') }
		shaped := svg_shape_text(label_node, 'AB')
		assert shaped.runs.len == 2
		assert shaped.runs[0].font().source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		assert shaped.runs[0].glyphs().map(it.code_point) == [u32(`A`)]
		assert shaped.runs[1].glyphs().map(it.code_point) == [u32(`B`)]
		assert !shaped.runs[0].font().has_same_identity(shaped.runs[1].font())
		assert shaped.runs[1].glyphs()[0].position.x == shaped.runs[0].width()
	}
}

fn test_svg_tspans_advance_from_shaped_run_width_instead_of_ink_bounds() {
	document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="300" height="120"><text x="20" y="36" font-size="28"><tspan id="first" dx="20">foo</tspan><tspan id="second" dx="20">bar</tspan></text></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first_node := layout_node_with_id(result.root, 'first') or { panic('missing first tspan') }
	second_node := layout_node_with_id(result.root, 'second') or { panic('missing second tspan') }
	first_shape := svg_shape_text(first_node, 'foo')
	second_shape := svg_shape_text(second_node, 'bar')
	second_local_path := svg_glyph_runs_outline_path(second_shape.runs, 0, 0)
	second_local_bounds := svg_path_bounds(second_local_path) or { panic('missing local bounds') }
	expected_second_x := CSSPixels.nearest_value_for(40 + first_shape.width + 20 +
		second_local_bounds.x)
	assert used_for_id(result, 'second').offset.x() == expected_second_x
	assert used_for_id(result, 'first').content_width().to_double() < first_shape.width
}

fn test_svg_text_path_places_rotated_glyph_outlines_on_first_contour() {
	font := &platform.Font{
		family: 'sans-serif'
		point_size: 20
	}
	horizontal := svg_place_text_along_path(svg.parse_path_data('M 10 40 L 150 40'), 'OO', font, 0)
	horizontal_bounds := svg_path_bounds(horizontal) or { panic('missing horizontal text path') }
	assert horizontal.instructions.any(it.type_ == .quadratic_bezier_curve)
	assert horizontal_bounds.width > horizontal_bounds.height

	vertical := svg_place_text_along_path(svg.parse_path_data('M 30 10 L 30 150'), 'OO', font, 0)
	vertical_bounds := svg_path_bounds(vertical) or { panic('missing vertical text path') }
	assert vertical_bounds.height > vertical_bounds.width

	// SkPathMeasure measures its first contour only. A later long contour must
	// not rescue a glyph whose midpoint does not fit on the first one.
	short_first := svg_place_text_along_path(svg.parse_path_data('M 0 0 L 1 0 M 20 20 L 200 20'), 'O', font, 0)
	assert short_first.instructions.len == 0
}

fn test_svg_text_path_start_offset_resolves_against_first_contour_length() {
	shape := svg.parse_path_data('M 50 50 L 250 50')
	document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="300" height="100"><defs><path id="guide" d="M 50 50 L 250 50"/></defs><text><textPath id="label" href="#guide" startOffset="50%" font-size="20">O</textPath></text></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	label_node := layout_node_with_id(result.root, 'label') or { panic('missing textPath') }
	shaped := svg_shape_text(label_node, 'O')
	without_offset := svg_place_glyph_runs_along_path(shape, shaped.runs, 0)
	with_offset := svg_place_glyph_runs_along_path(shape, shaped.runs, 100)
	without_bounds := svg_path_bounds(without_offset) or { panic('missing text path') }
	with_bounds := svg_path_bounds(with_offset) or { panic('missing offset text path') }
	assert math.abs((with_bounds.x - without_bounds.x) - 100) < 0.01
	label := used_for_id(result, 'label')
	laid_out := svg_path_bounds(label.computed_svg_path() or { panic('textPath has no path') }) or {
		panic('textPath has no bounds')
	}
	assert math.abs(laid_out.x - with_bounds.x) < 0.01
}

fn test_svg_text_path_text_anchor_adjusts_the_start_offset() {
	start_document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="320" height="120"><defs><path id="guide" d="M 20 60 L 300 60"/></defs><text><textPath id="label" href="#guide" startOffset="50%" font-size="20">OO</textPath></text></svg>')
	middle_document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="320" height="120"><defs><path id="guide" d="M 20 60 L 300 60"/></defs><text text-anchor="middle"><textPath id="label" href="#guide" startOffset="50%" font-size="20">OO</textPath></text></svg>')
	end_document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="320" height="120"><defs><path id="guide" d="M 20 60 L 300 60"/></defs><text><textPath id="label" href="#guide" startOffset="50%" text-anchor="end" font-size="20">OO</textPath></text></svg>')
	start_result := run_document_layout(start_document, 800, 600) or { panic('start layout failed') }
	middle_result := run_document_layout(middle_document, 800, 600) or {
		panic('middle layout failed')
	}
	end_result := run_document_layout(end_document, 800, 600) or { panic('end layout failed') }
	start_bounds := svg_path_bounds(used_for_id(start_result, 'label').computed_svg_path() or {
		panic('start textPath has no path')
	}) or { panic('start textPath has no bounds') }
	middle_bounds := svg_path_bounds(used_for_id(middle_result, 'label').computed_svg_path() or {
		panic('middle textPath has no path')
	}) or { panic('middle textPath has no bounds') }
	end_bounds := svg_path_bounds(used_for_id(end_result, 'label').computed_svg_path() or {
		panic('end textPath has no path')
	}) or { panic('end textPath has no bounds') }
	start_label := layout_node_with_id(start_result.root, 'label') or { panic('missing textPath') }
	run_width := svg_shape_text(start_label, 'OO').width
	assert math.abs((start_bounds.x - middle_bounds.x) - run_width / 2) < 0.01
	assert math.abs((start_bounds.x - end_bounds.x) - run_width) < 0.01
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
	assert foreign.offset.x().to_double() == 5
	assert foreign.offset.y().to_double() == 6
	assert foreign.content_width().to_double() == 40
	assert foreign.content_height().to_double() == 20
	html_child := used_for_id(result, 'html-child')
	assert html_child.content_width().to_double() == 40
	assert html_child.content_height().to_double() == 8
}

fn test_svg_foreign_object_geometry_is_not_a_definite_percentage_height_basis() {
	document := html.parse_document('<!doctype html><style>body { margin:0 }</style><svg width="400" height="200" viewBox="0 0 100 100"><foreignObject id="foreign" x="10%" y="10%" width="50%" height="50%"><div id="child" style="height:100%"></div></foreignObject></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	foreign := used_for_id(result, 'foreign')
	assert foreign.content_width().to_double() == 50
	assert foreign.content_height().to_double() == 50
	assert !foreign.has_definite_height()
	assert used_for_id(result, 'child').content_height().to_double() == 0
}

fn test_svg_resource_attached_to_foreign_object_keeps_its_own_coordinate_space() {
	document := html.parse_document('<!doctype html><svg id="root" width="100" height="100"><defs><mask id="mask"><rect width="20" height="20"/></mask></defs><foreignObject id="foreign" x="10" y="20" width="40" height="40" mask="url(#mask)"><div></div></foreignObject></svg>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mask := used_for_id(result, 'mask')
	assert mask.offset.x().to_double() == 0
	assert mask.offset.y().to_double() == 0
	assert mask.cumulative_offset().x().to_double() == 8
	assert mask.cumulative_offset().y().to_double() == 8
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
	assert circle.offset.x().to_double() == 30
	assert circle.offset.y().to_double() == 10
	assert circle.content_width().to_double() == 20
	assert circle.content_height().to_double() == 20
	nested := used_for_id(result, 'nested')
	assert nested.offset.x().to_double() == 10
	assert nested.offset.y().to_double() == 5
	assert nested.content_width().to_double() == 60
	assert nested.content_height().to_double() == 30
	foreign := used_for_id(result, 'foreign')
	assert foreign.offset.x().to_double() == 7
	assert foreign.offset.y().to_double() == 8
	assert foreign.content_width().to_double() == 25
	assert foreign.content_height().to_double() == 12
}

fn test_svg_path_d_uses_the_css_cascade_and_presentation_attribute_syntax() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#styled { d:path("M 5 6 L 45 6") }
		#none { d:none }
	</style><svg width="100" height="50">
		<path id="styled" d="M 0 0 L 10 0"/>
		<path id="attribute" d="M 1 2 L 11 12"/>
		<path id="none" d="M 0 0 L 10 0"/>
	</svg>')
	result := run_document_layout(document, 100, 50) or { panic('layout failed') }
	styled := used_for_id(result, 'styled').computed_svg_path() or { panic('styled path missing') }
	assert styled.serialize() == 'M 5 6 L 45 6'
	attribute := used_for_id(result, 'attribute').computed_svg_path() or {
		panic('attribute path missing')
	}
	assert attribute.serialize() == 'M 1 2 L 11 12'
	none_path := used_for_id(result, 'none').computed_svg_path() or { svg.Path{} }
	assert none_path.instructions.len == 0
}

fn test_svg_rect_uses_computed_geometry_and_used_corner_radii() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#styled { x:5px; y:6px; width:40px; height:20px; rx:25% }
		#paired { x:10px; y:10px; width:80px; height:20px; rx:25%; ry:25% }
		#hidden { width:auto; height:20px }
	</style><svg width="200" height="100">
		<rect id="styled" x="1" y="2" width="3" height="4"/>
		<rect id="paired"/>
		<rect id="hidden" width="30"/>
	</svg>')
	result := run_document_layout(document, 200, 100) or { panic('layout failed') }
	styled := used_for_id(result, 'styled')
	assert styled.offset.x().to_double() == 5
	assert styled.offset.y().to_double() == 6
	assert styled.content_width().to_double() == 40
	assert styled.content_height().to_double() == 20
	styled_path := styled.computed_svg_path() or { panic('styled rect path missing') }
	assert styled_path.instructions[0].data == [15.0, 6.0]
	assert styled_path.instructions[2].data[..2] == [10.0, 10.0]
	paired_path := used_for_id(result, 'paired').computed_svg_path() or {
		panic('paired rect path missing')
	}
	assert paired_path.instructions[0].data == [30.0, 10.0]
	assert paired_path.instructions[2].data[..2] == [20.0, 5.0]
	assert (used_for_id(result, 'hidden').computed_svg_path() or { svg.Path{} }).instructions.len == 0
}

fn test_svg_ellipse_uses_computed_geometry_and_auto_radii() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#styled { cx:25%; cy:50%; rx:auto; ry:10% }
		#paired { cx:100px; cy:50px; rx:25%; ry:25% }
	</style><svg width="200" height="100">
		<ellipse id="styled" cx="1" cy="2" rx="3" ry="4"/>
		<ellipse id="paired"/>
	</svg>')
	result := run_document_layout(document, 200, 100) or { panic('layout failed') }
	styled := used_for_id(result, 'styled')
	assert styled.offset.x().to_double() == 40
	assert styled.offset.y().to_double() == 40
	assert styled.content_width().to_double() == 20
	assert styled.content_height().to_double() == 20
	styled_path := styled.computed_svg_path() or { panic('styled ellipse path missing') }
	assert styled_path.instructions[0].data == [60.0, 50.0]
	assert styled_path.instructions[1].data[..2] == [10.0, 10.0]
	paired := used_for_id(result, 'paired')
	assert paired.offset.x().to_double() == 50
	assert paired.offset.y().to_double() == 25
	assert paired.content_width().to_double() == 100
	assert paired.content_height().to_double() == 50
}

fn test_svg_image_uses_computed_geometry_and_default_sizing() {
	viewbox_image := 'data:image/svg+xml,%3Csvg%20viewBox%3D%220%200%20200%20100%22%3E%3C%2Fsvg%3E'
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#styled { x:20px; y:15px; width:80px; height:40px }
	</style><svg width="400" height="200">
		<image id="styled" x="1" y="2" width="3" height="4" href="https://example.test/image.png"/>
		<image id="default" y="50" href="${viewbox_image}"/>
	</svg>')
	result := run_document_layout(document, 400, 200) or { panic('layout failed') }
	styled := used_for_id(result, 'styled')
	assert styled.offset.x().to_double() == 20
	assert styled.offset.y().to_double() == 15
	assert styled.content_width().to_double() == 80
	assert styled.content_height().to_double() == 40
	default_image := used_for_id(result, 'default')
	assert default_image.offset.x().to_double() == 0
	assert default_image.offset.y().to_double() == 50
	assert default_image.content_width().to_double() == 300
	assert default_image.content_height().to_double() == 150
}

fn test_svg_use_translation_uses_computed_x_and_y() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#copy { x:25%; y:10% }
	</style><svg width="200" height="100">
		<defs><rect id="source" width="10" height="10"/></defs>
		<use id="copy" href="#source" x="1" y="2" transform="scale(2)"/>
	</svg>')
	result := run_document_layout(document, 200, 100) or { panic('layout failed') }
	transform := used_for_id(result, 'copy').svg_transform()
	assert transform.a == 2
	assert transform.d == 2
	assert transform.e == 100
	assert transform.f == 20
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

fn test_clearance_moves_past_every_stacked_float() {
	document := html.parse_document('<!doctype html><style>
		#container { width:200px }
		#first { float:left; width:200px; height:80px }
		#second { float:left; width:200px; height:40px }
		#cleared { clear:left; height:10px }
	</style><div id="container"><div id="first"></div><div id="second"></div><div id="cleared"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	first := used_for_id(result, 'first')
	second := used_for_id(result, 'second')
	cleared := used_for_id(result, 'cleared')
	assert first.offset.y().to_double() == 0
	assert second.offset.y().to_double() == 80
	assert cleared.offset.y().to_double() == 120
}

fn test_float_is_lowered_past_an_opposite_side_blocker() {
	document := html.parse_document('<!doctype html><style>
		#container { width:100px }
		#left { float:left; width:60px; height:40px }
		#right { float:right; width:60px; height:20px }
	</style><div id="container"><div id="left"></div><div id="right"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	left := used_for_id(result, 'left')
	right := used_for_id(result, 'right')
	assert left.offset.x().to_double() == 0
	assert left.offset.y().to_double() == 0
	assert right.offset.x().to_double() == 40
	assert right.offset.y().to_double() == 40
}

fn test_intrinsic_width_ignores_a_float_that_does_not_overlap_the_widest_line() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { float:left }
		#inner { float:left; width:100px; height:20px }
		#late { display:inline-block; width:130px; height:20px }
	</style><div id="outer"><div id="inner"></div>x<br><span id="late"></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	outer := used_for_id(result, 'outer')
	inner := used_for_id(result, 'inner')
	late := used_for_id(result, 'late')
	assert inner.content_width().to_double() == 100
	assert late.content_width().to_double() == 130
	assert outer.content_width().to_double() == 130
}

fn test_auto_width_float_is_clamped_by_max_width() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { width:300px }
		#float { float:right; max-width:100px; white-space:nowrap }
	</style><div id="container"><div id="float">content wider than the maximum</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	floating := used_for_id(result, 'float')
	assert floating.content_width().to_double() == 100
	assert floating.offset.x().to_double() == 200
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

fn test_overflow_wrap_anywhere_splits_long_run_around_float() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { width:200px; font:20px/20px monospace; overflow-wrap:anywhere }
		#float { float:left; width:100px; height:60px }
	</style><div id="container"><span id="float"></span>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container_node := layout_node_with_id(result.root, 'container') or { panic('no container') }
	container := result.used_values_for(container_node.as_node_with_style() or {
		panic('container has no style')
	}) or { panic('container has no used values') }
	mut text := ''
	mut saw_intruded_line := false
	mut saw_full_width_line := false
	for line in container.line_boxes {
		for fragment in line.fragments() {
			part := fragment.text() or { continue }
			text += part
			if fragment.inline_offset().to_double() >= 100 {
				saw_intruded_line = true
			}
			if fragment.inline_offset().to_double() == 0 {
				saw_full_width_line = true
			}
		}
	}
	assert text == 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
	assert saw_intruded_line
	assert saw_full_width_line
}

fn test_inline_line_uses_float_band_that_starts_midway_through_its_height() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#container { width:300px; font:16px/60px SerenitySans }
		#spacer { height:50px }
		#float { float:left; width:120px; height:20px }
		#probe { margin:-10px 0 0 }
	</style><div id="container"><div id="spacer"></div><div id="float"></div><p id="probe">line spans the float</p></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	probe_node := layout_node_with_id(result.root, 'probe') or { panic('missing probe') }
	probe := result.used_values_for(probe_node.as_node_with_style() or {
		panic('probe has no style')
	}) or { panic('probe has no used values') }
	assert probe.line_boxes.len == 1
	assert probe.line_boxes[0].fragments().len == 1
	assert probe.line_boxes[0].fragments()[0].inline_offset().to_double() == 120
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
	assert text_y or { panic('missing text fragment') } == 42
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

fn test_container_type_establishes_an_independent_formatting_context() {
	for container_type in ['size', 'inline-size'] {
		document := html.parse_document('<!doctype html><div id="container" style="container-type:${container_type}"></div>')
		root := build_layout_tree(document) or { panic('layout tree was not created') }
		container := layout_node_with_id(root, 'container') or { panic('container box is missing') }
		styled_container := container.as_node_with_style() or {
			panic('container box has no computed style')
		}
		assert creates_block_formatting_context(styled_container), container_type
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		used_container := used_for_id(result, 'container')
		// Establishing an independent formatting context does not give an
		// ordinary block a replaced-element intrinsic inline size. Its auto
		// width still fills the containing block.
		assert used_container.content_width().to_double() == 784, container_type
	}
}

fn test_auto_height_flex_items_make_their_used_cross_size_definite_for_descendants() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0; padding:0 }
		html { position:relative; width:400px; height:200px }
		body { display:flex; position:absolute; inset:0 auto auto 0; width:100% }
		#outer { width:100%; height:50% }
		#inner { width:100%; height:50% }
		#content { width:50px; height:30px }
	</style><div id="outer"><div id="inner"><div id="content"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'outer').content_height().to_double() == 30
	assert used_for_id(result, 'inner').content_height().to_double() == 15
	assert used_for_id(result, 'content').content_height().to_double() == 30
}

// FormattingContext::box_is_sized_as_replaced_element(): a non-replaced box with
// a preferred aspect ratio and a definite block size resolves its automatic
// inline size through the ratio instead of stretching to the containing block.
fn test_aspect_ratio_box_with_definite_height_transfers_through_the_ratio() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:2/1; height:30px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	assert box.content_width().to_double() == 60
	assert box.content_height().to_double() == 30
}

// The same selection applies to floats and to absolutely positioned boxes,
// which upstream routes through compute_width_for_block_level_replaced_element_in_normal_flow()
// and compute_width_for_absolutely_positioned_replaced_element() respectively.
fn test_aspect_ratio_transfer_applies_to_floats_and_absolute_positioning() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px; height:120px; position:relative }
		#floated { float:left; aspect-ratio:2/1; height:30px }
		#positioned { position:absolute; aspect-ratio:2/1; height:30px }
	</style><div id="outer"><div id="floated"></div><div id="positioned"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	floated := used_for_id(result, 'floated')
	assert floated.content_width().to_double() == 60
	assert floated.content_height().to_double() == 30
	positioned := used_for_id(result, 'positioned')
	assert positioned.content_width().to_double() == 60
	assert positioned.content_height().to_double() == 30
}

// BlockFormattingContext::compute_width_for_block_level_replaced_element_in_normal_flow()
// converts the replaced content width through calculate_inner_width() a second
// time, so a block-level `box-sizing: border-box` replaced box loses its inline
// border and padding twice. The first conversion happens before the used inline
// padding is assigned, so it only subtracts the borders.
fn test_block_level_replaced_border_box_width_is_converted_twice() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:2/1; box-sizing:border-box; width:80px; padding:5px; border:3px solid }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	// 80 - 3 - 3 = 74 with the still-zero used padding, then 74 - 3 - 5 - 3 - 5 = 58.
	assert box.content_width().to_double() == 58
	// The ratio-derived height follows the converted inline size.
	assert box.content_height().to_double() == 29
}

// An inline-block is sized by the inline formatting context and never enters
// that block-level path, so its border-box width is converted only once.
fn test_inline_block_replaced_border_box_width_is_converted_once() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px; font-size:0 }
		#box { display:inline-block; aspect-ratio:2/1; box-sizing:border-box; width:80px; padding:5px; border:3px solid }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	assert box.content_width().to_double() == 64
	assert box.content_height().to_double() == 32
}

// A box whose inline and block sizes are both automatic is sized as a normal
// block, not as a replaced element, even with a preferred aspect ratio. Its
// stretch-fit width is measured before the used inline padding exists, so the
// padding does not shrink it.
fn test_aspect_ratio_box_with_two_automatic_axes_uses_the_stretch_fit_width() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:2/1; padding:5px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	assert box.content_width().to_double() == 200
	assert box.content_height().to_double() == 100
}

// FormattingContext::solve_replaced_size_constraint() compares min/max sizes in
// content-box space, just like the preferred size.
fn test_replaced_size_constraints_use_content_box_space() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:2/1; box-sizing:border-box; padding:5px; border:3px solid; min-width:20px; max-width:150px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	// The constraint table converts max-width to 144 with the padding not yet
	// assigned. The block path then subtracts all 16px of used edges.
	assert box.content_width().to_double() == 128
	assert box.content_height().to_double() == 64
}

// With one axis specified the source clamps each axis on its own through
// tentative_width_for_replaced_element(), so the constraint passes through the
// same box-sizing conversion as the preferred size - twice, on this path.
fn test_specified_axis_clamps_each_axis_through_the_box_sizing_conversion() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:1/3; box-sizing:border-box; height:30px; padding:5px; border:3px solid; min-width:20px; max-width:150px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	// min-width 20 becomes 14 with zero used padding, then 14 - 16 clamps to 0.
	assert box.content_width().to_double() == 0
	assert box.content_height().to_double() == 14
	// The margin equation still re-runs with the clamped 4px width.
	assert box.margin_right.to_double() == 180
}

// Steps 2 and 3 of FormattingContext::compute_width_for_replaced_element()
// compare and assign constraints in content-box space. They also re-run after
// the constraint-violation table.
fn test_replaced_constraints_compare_and_assign_converted_sizes() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:2/1; box-sizing:border-box; padding:5px; border:3px solid;
			min-width:120px; max-width:60px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	// min-width wins over max-width in content-box space (120-6=114), and the
	// block-level conversion subtracts the real edges once more.
	assert box.content_width().to_double() == 98
	assert box.content_height().to_double() == 49
}

fn test_replaced_form_control_block_constraints_rerun_intrinsic_sizing() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		input { font-size:5px; box-sizing:border-box }
		#max-width { border:5px solid; padding:0 10px; max-width:50px }
		#max-height { border:4px solid; padding:10px 0; max-height:32px }
		#min-height { border:3px solid; padding:8px 0; min-height:50px }
		#image { box-sizing:border-box; border:10px solid; padding:5px; max-width:80px }
	</style><input id="max-width"><input id="max-height"><input id="min-height"><canvas id="image"></canvas>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'max-width').content_width().to_double() == 20
	// The source block-size algorithm reruns tentative sizing after a min/max
	// violation. Since both original axes are auto, the input's intrinsic line
	// height wins again before the replacement constraint is inspected.
	assert used_for_id(result, 'max-height').content_height().to_double() == 5
	assert used_for_id(result, 'min-height').content_height().to_double() == 5
	assert used_for_id(result, 'image').content_width().to_double() == 50
	assert used_for_id(result, 'image').content_height().to_double() == 25
}

// compute_height_for_replaced_element() applies its own max-height and
// min-height steps before tentative_width_for_replaced_element() transfers the
// block size through the ratio.
fn test_block_size_is_clamped_before_it_transfers_through_the_ratio() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { aspect-ratio:2/1; height:30px; padding:5px; border:3px solid; max-height:25px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	assert box.content_width().to_double() == 50
	assert box.content_height().to_double() == 25
}

fn test_replaced_intrinsic_width_transfers_from_definite_height() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex }
		.column { display:flex; flex-direction:column }
		canvas { height:32px }
	</style><div class="row"><div id="column" class="column"><canvas id="image"></canvas></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	column := used_for_id(result, 'column')
	image := used_for_id(result, 'image')
	assert column.content_width().to_double() == 64
	assert column.content_height().to_double() == 32
	assert image.content_width().to_double() == 64
	assert image.content_height().to_double() == 32
}

// An unresolved percentage block size is treated as automatic. Only a box that
// box_is_sized_as_replaced_element() selects transfers it from the inline size;
// a box with two automatic axes takes its automatic content height instead.
fn test_unresolved_percentage_height_only_transfers_for_replaced_sizing() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#sized { aspect-ratio:2/1; width:80px; height:40% }
		#stretched { aspect-ratio:2/1; height:40% }
		#stretched > div { height:7px }
	</style><div id="outer"><div id="sized"></div><div id="stretched"><div></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	sized := used_for_id(result, 'sized')
	assert sized.content_width().to_double() == 80
	assert sized.content_height().to_double() == 40
	stretched := used_for_id(result, 'stretched')
	assert stretched.content_width().to_double() == 200
	assert stretched.content_height().to_double() == 7
}

// A floating box with a preferred aspect ratio takes the same block-level
// replaced path, so its border-box inline size is converted twice as well.
fn test_floating_border_box_ratio_transfer_converts_the_inline_size_twice() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px }
		#box { float:left; box-sizing:border-box; aspect-ratio:2/1; width:auto; height:30px; padding:5px }
	</style><div id="outer"><div id="box"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	box := used_for_id(result, 'box')
	// 30 - 10 = 20 of block size, transferred to 40, converted once more to 30.
	assert box.content_width().to_double() == 30
	assert box.content_height().to_double() == 20
}

// BlockFormattingContext::compute_width() gives a table wrapper the width its
// table box's own algorithm produces. An inline-table therefore honours an
// intrinsic sizing keyword on the table box, which the wrapper's own
// shrink-to-fit measure would have discarded.
fn test_inline_table_honours_intrinsic_sizing_keywords() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px; font-size:0 }
		.k { display:inline-block }
		.t { display:inline-table }
	</style><div id="outer">
		<div class="t" id="minimum" style="width:min-content"><i class="k" style="width:40px;height:10px"></i><i class="k" style="width:70px;height:10px"></i></div>
		<div class="t" id="fit" style="width:fit-content"><i class="k" style="width:40px;height:10px"></i><i class="k" style="width:70px;height:10px"></i></div>
		<div class="t" id="maximum" style="width:max-content"><i class="k" style="width:40px;height:10px"></i><i class="k" style="width:70px;height:10px"></i></div>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'minimum').content_width().to_double() == 70
	assert used_for_id(result, 'fit').content_width().to_double() == 110
	assert used_for_id(result, 'maximum').content_width().to_double() == 110
}

fn test_table_fit_content_distinguishes_zero_argument_from_keyword() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:500px }
		table { border-collapse:collapse; font:10px/10px monospace }
		td { padding:0 }
	</style><div id="outer">
		<table id="zero" style="width:fit-content(0)"><tr><td>XXXX XXXX</td></tr></table>
		<table id="zero-percent" style="width:fit-content(0%)"><tr><td>XXXX XXXX</td></tr></table>
		<table id="limited" style="width:fit-content(30px)"><tr><td>XXXX XXXX</td></tr></table>
		<table id="keyword" style="width:fit-content"><tr><td>XXXX XXXX</td></tr></table>
		<table id="max-zero" style="max-width:fit-content(0)"><tr><td>XXXX XXXX</td></tr></table>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	zero := used_for_id(result, 'zero').content_width()
	zero_percent := used_for_id(result, 'zero-percent').content_width()
	limited := used_for_id(result, 'limited').content_width()
	keyword := used_for_id(result, 'keyword').content_width()
	max_zero := used_for_id(result, 'max-zero')
	assert zero == zero_percent
	assert zero.raw_value() < limited.raw_value()
	assert limited.raw_value() < keyword.raw_value()
	assert max_zero.content_width() == zero
	assert max_zero.margin_right.raw_value() == 0
}

// The current Rust block formatting context ignores the left margin in an RTL
// containing block, assigning the remaining width to that side.
fn test_over_constrained_block_keeps_the_right_edge_in_rtl() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#outer { width:200px; direction:rtl }
		#fixed { width:30px; height:20px }
		#with_start_margin { width:30px; height:20px; margin-left:10px }
		#overflowing { width:250px; height:20px }
	</style><div id="outer"><div id="fixed"></div><div id="with_start_margin"></div><div id="overflowing"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	fixed := used_for_id(result, 'fixed')
	assert fixed.offset.x().to_double() == 170
	assert fixed.margin_left.to_double() == 170
	assert fixed.margin_right.to_double() == 0

	with_start_margin := used_for_id(result, 'with_start_margin')
	assert with_start_margin.offset.x().to_double() == 170
	assert with_start_margin.margin_left.to_double() == 170
	assert with_start_margin.margin_right.to_double() == 0

	// A negative remainder goes to the same side.
	overflowing := used_for_id(result, 'overflowing')
	assert overflowing.offset.x().to_double() == -50
	assert overflowing.margin_left.to_double() == -50
	assert overflowing.margin_right.to_double() == 0
}

// The <meter> UA-internal children are synthesized, so they carry no id: reach
// them positionally from the host box.
fn meter_track_used_values(result DocumentLayoutResult, id string) &UsedValues {
	host := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
	track := host.children()[0] or { panic('#${id} has no slider track') }
	styled := track.as_node_with_style() or { panic('#${id} track has no style') }
	return result.used_values_for(styled) or { panic('#${id} track has no used values') }
}

fn meter_fill_used_values(result DocumentLayoutResult, id string) &UsedValues {
	host := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
	track := host.children()[0] or { panic('#${id} has no slider track') }
	fill := track.children()[0] or { panic('#${id} has no slider fill') }
	styled := fill.as_node_with_style() or { panic('#${id} fill has no style') }
	return result.used_values_for(styled) or { panic('#${id} fill has no used values') }
}

// HTMLMeterElement::create_shadow_tree_if_needed() gives <meter> the same
// ::slider-track / ::slider-fill pair as <progress>, and
// update_meter_value_element() sets the fill's width to
// (value - min) / (max - min) * 100%.
fn test_meter_builds_its_slider_track_and_fill() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; font-size:0 }
		#outer { width:400px }
	</style><div id="outer">
		<meter id="half" value="0.5"></meter>
		<meter id="ranged" min="10" max="20" value="12"></meter>
		<meter id="clamped" value="3"></meter>
		<meter id="degenerate" min="5" max="5" value="5"></meter>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	// Default UA size is 300x12 with a 1px track border, so the track content
	// box is 298 wide and the fill takes its share of that.
	half := used_for_id(result, 'half')
	assert half.content_width().to_double() == 300
	assert half.content_height().to_double() == 12
	half_track := meter_track_used_values(result, 'half')
	assert half_track.content_width().to_double() == 298
	assert meter_fill_used_values(result, 'half').content_width().to_double() == 149

	// min/max shift and scale the position: (12 - 10) / (20 - 10) = 20%.
	assert meter_fill_used_values(result, 'ranged').content_width().to_double() == 59.59375

	// The actual value is clamped to the maximum, so the fill is full.
	assert meter_fill_used_values(result, 'clamped').content_width().to_double() == 298

	// A degenerate range would format as `nan%`; the fill keeps its auto width.
	assert meter_fill_used_values(result, 'degenerate').content_width().to_double() == 298
}

// compute_width_for_absolutely_positioned_non_replaced_element() and
// compute_height_for_absolutely_positioned_non_replaced_element() record the
// solved insets on the box's used values. getComputedStyle() reports those as
// the resolved value of top/right/bottom/left whenever the specified inset is a
// percentage, a calculation, or `auto`, so an `auto` side has to carry the
// distance the layout produced rather than zero.
fn test_absolutely_positioned_boxes_record_their_solved_insets() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.box { width:200px; height:100px; position:relative }
		#start { position:absolute; top:10px; left:5px }
		#end { position:absolute; bottom:10px; right:5px; width:20px; height:20px }
		#static_position { position:absolute; width:10px; height:10px }
	</style><div class="box"><div id="start"></div><div id="end"></div><div id="static_position"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	start := used_for_id(result, 'start')
	assert start.inset_left.to_double() == 5
	assert start.inset_top.to_double() == 10
	// The `auto` sides carry the distance to the containing block's padding edge.
	assert start.inset_right.to_double() == 195
	assert start.inset_bottom.to_double() == 90

	end_box := used_for_id(result, 'end')
	assert end_box.inset_left.to_double() == 175
	assert end_box.inset_top.to_double() == 70
	assert end_box.inset_right.to_double() == 5
	assert end_box.inset_bottom.to_double() == 10

	// With no insets at all the static position supplies them.
	static_position := used_for_id(result, 'static_position')
	assert static_position.inset_left.to_double() == 0
	assert static_position.inset_top.to_double() == 0
	assert static_position.inset_right.to_double() == 190
	assert static_position.inset_bottom.to_double() == 90
}

fn test_split_inline_containing_blocks_include_block_descendants_and_valid_inline_triggers() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.frame { margin:100px; width:400px; padding:10px }
		.reset { margin:0; padding:0; border:0 }
		.abs { position:absolute; inset:0; display:block }
	</style>
	<div class="frame"><span style="display:inline; position:relative"><span
		id="relative" class="abs"></span><div class="reset" style="height:50px"></div></span></div>
	<div class="frame" style="position:relative; height:100px"><span
		style="display:inline; transform:scale(1)"><span id="transform" class="abs"></span><div
		class="reset" style="height:30px"></div></span></div>
	<div class="frame"><span style="display:inline; filter:blur(0)"><span
		id="filter" class="abs"></span><div class="reset" style="height:30px"></div></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	// The empty relative inline gets its dimensions from the split-out block child.
	relative := used_for_id(result, 'relative')
	assert relative.content_width().to_double() == 400
	assert relative.content_height().to_double() == 50

	// Transform does not apply to a non-atomic inline, so its abspos descendant
	// falls through to the frame's padding box.
	transformed := used_for_id(result, 'transform')
	assert transformed.content_width().to_double() == 420
	assert transformed.content_height().to_double() == 120

	// Filter does establish an inline containing block.
	filtered := used_for_id(result, 'filter')
	assert filtered.content_width().to_double() == 400
	assert filtered.content_height().to_double() == 30
}

fn test_inline_containing_block_lookup_crosses_shadow_roots() {
	document := html.parse_document('<!doctype html><style>
		positioned-inline { position:relative }
	</style><div style="height:100px"></div><positioned-inline id="host">inline containing block</positioned-inline>')
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut absolutely_positioned := document.create_element_ns('http://www.w3.org/1999/xhtml',
		'div') or { panic(err) }
	absolutely_positioned.set_attribute_value('id', 'absolutely-positioned')
	absolutely_positioned.set_attribute_value('style', 'position:absolute; inset:0')
	mut slot := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		panic(err)
	}
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(absolutely_positioned.as_node()) or { panic(err) }
	shadow_node.append_child(slot.as_node()) or { panic(err) }

	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	abspos_node := layout_node_with_id(result.root, 'absolutely-positioned') or {
		panic('missing absolutely positioned shadow child')
	}
	inline_containing_block := abspos_node.inline_containing_block_if_applicable() or {
		panic('shadow child did not find its inline containing block')
	}
	containing_dom_node := unsafe { &Node(inline_containing_block) }.dom_node() or {
		panic('inline containing block has no DOM node')
	}
	assert voidptr(containing_dom_node) == voidptr(host.as_node())
}

fn test_flex_fieldsets_apply_layout_to_the_anonymous_content_box() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		fieldset { display:flex; flex-wrap:wrap; gap:10px; width:200px; margin:0; padding:0; border:0 }
		legend { width:30px; height:20px; padding:0 }
		.item { display:flex; flex:none; width:80px; height:30px }
	</style>
	<fieldset id="with"><legend></legend><div id="with-one" class="item"></div><div id="with-two" class="item"></div><div id="with-three" class="item"></div></fieldset>
	<fieldset id="without"><div id="without-one" class="item"></div><div id="without-two" class="item"></div><div id="without-three" class="item"></div></fieldset>
	<fieldset id="column" style="flex-direction:column; align-items:flex-end"><legend></legend><div id="column-one" class="item"></div><div id="column-two" class="item"></div></fieldset>
	<fieldset id="inline" style="display:inline-flex; justify-content:flex-end"><legend></legend><div id="inline-one" class="item"></div><div id="inline-two" class="item"></div></fieldset>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	with_fieldset := layout_node_with_id(result.root, 'with') or { panic('missing fieldset') }
	assert with_fieldset.child_count() == 2
	with_wrapper := with_fieldset.children()[1]
	assert with_wrapper.is_anonymous()
	assert with_wrapper.display().is_flex_inside()
	assert used_for_id(result, 'with-one').offset.x().to_double() == 0
	assert used_for_id(result, 'with-two').offset.x().to_double() == 90
	assert used_for_id(result, 'with-three').offset.y().to_double() == 40

	without_fieldset := layout_node_with_id(result.root, 'without') or { panic('missing fieldset') }
	assert without_fieldset.child_count() == 1
	without_wrapper := without_fieldset.children()[0]
	assert without_wrapper.is_anonymous()
	assert without_wrapper.display().is_flex_inside()
	assert used_for_id(result, 'without-two').offset.x().to_double() == 90
	assert used_for_id(result, 'without-three').offset.y().to_double() == 40

	column_wrapper := (layout_node_with_id(result.root, 'column') or { panic('missing fieldset') }).children()[1]
	assert column_wrapper.display().is_flex_inside()
	assert used_for_id(result, 'column-one').offset.x().to_double() == 120
	assert used_for_id(result, 'column-two').offset.y().to_double() == 40

	inline_wrapper := (layout_node_with_id(result.root, 'inline') or { panic('missing fieldset') }).children()[1]
	assert inline_wrapper.display().is_flex_inside()
	assert used_for_id(result, 'inline-one').offset.x().to_double() == 30
	assert used_for_id(result, 'inline-two').offset.x().to_double() == 120
}

// "For grid-template-columns and grid-template-rows the resolved value is the
// used value", so the grid formatting context records the final track base sizes
// and the explicit line names between them.
fn test_grid_containers_record_their_used_track_sizes() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; width:300px; grid-template-columns: [a] 1fr [b] 2fr [c]; grid-template-rows: [r1] 20px [r2] }
	</style><div id="grid"><i></i><i></i></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := used_for_id(result, 'grid')
	assert grid.grid_template_columns().len == 2
	assert grid.grid_template_columns()[0].to_double() == 100
	assert grid.grid_template_columns()[1].to_double() == 200
	assert grid.grid_template_rows().len == 1
	assert grid.grid_template_rows()[0].to_double() == 20
	// Only the explicit names are kept; grid-template-areas' implicit
	// `<area>-start`/`-end` names are not part of the resolved value.
	assert grid.grid_column_line_names() == [['a'], ['b'], ['c']]
	assert grid.grid_row_line_names() == [['r1'], ['r2']]
}

// CSS Sizing 4 explicit intrinsic inner sizes replace the automatic size of a
// size-contained box. contain-intrinsic-width/height are physical axes, even
// when either the box or its containing block has a vertical writing mode.
fn test_size_containment_uses_explicit_intrinsic_inner_sizes() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		div { width:200px; line-height:16px }
		#size_only { contain:size }
		#strict_only { contain:strict }
		#shorthand { contain:size; contain-intrinsic-size:111px 222px }
		#longhand { contain:size; contain-intrinsic-height:222px }
		#auto_length { content-visibility:auto; contain-intrinsic-height:auto 32px; contain:strict }
		#none { contain:size; contain-intrinsic-height:none }
		#not_contained { contain-intrinsic-height:222px }
		.inline { display:inline-block; width:auto; contain:size; contain-intrinsic-size:111px 222px }
		#vertical_inline_block { writing-mode:vertical-rl }
	</style>
	<div id="size_only">x</div>
	<div id="strict_only">x</div>
	<div id="shorthand">x</div>
	<div id="longhand">x</div>
	<div id="auto_length">a file row</div>
	<div id="none">x</div>
	<div id="not_contained">x</div>
	<div id="horizontal_inline_block" class="inline">x</div>
	<div id="vertical_inline_block" class="inline">x</div>
	<div style="writing-mode:vertical-rl; width:auto; height:300px"><div id="in_vertical_inline_block" class="inline">x</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	assert used_for_id(result, 'size_only').content_height().to_double() == 0
	assert used_for_id(result, 'strict_only').content_height().to_double() == 0
	assert used_for_id(result, 'shorthand').content_height().to_double() == 222
	assert used_for_id(result, 'longhand').content_height().to_double() == 222
	assert used_for_id(result, 'auto_length').content_height().to_double() == 32
	assert used_for_id(result, 'none').content_height().to_double() == 0
	assert used_for_id(result, 'not_contained').content_height().to_double() == 16
	for id in ['horizontal_inline_block', 'vertical_inline_block', 'in_vertical_inline_block'] {
		used := used_for_id(result, id)
		assert used.content_width().to_double() == 111, id
		assert used.content_height().to_double() == 222, id
	}
}

// A display:table grid item is represented by its anonymous table wrapper.
// Grid placement and alignment therefore live on that wrapper, while its used
// inline size still comes from the principal table's width algorithm.
fn test_grid_table_wrappers_use_table_constraints_and_grid_item_properties() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.grid { display:grid; grid-template-columns:100px 100px; width:200px }
		.wide-grid { grid-template-columns:300px; width:300px }
		.table { display:table; height:20px }
		.cell { display:table-cell }
		.narrow { display:inline-block; width:20px; height:20px }
		.wide { display:inline-block; width:160px; height:20px }
		.segment { display:inline-block; width:80px; height:20px }
		#end { width:50px; justify-self:end }
		.maximum { max-width:60px }
		#minimum { max-width:min-content }
		#fit { max-width:fit-content(120px) }
		#late { width:50px; order:2 }
		#early { width:50px; order:1 }
	</style>
	<div class="grid"><div id="end" class="table"><i class="cell"><b class="narrow"></b></i></div></div>
	<div class="grid"><div id="narrow-max" class="table maximum"><i class="cell"><b class="narrow"></b></i></div></div>
	<div class="grid"><div id="wide-max" class="table maximum"><i class="cell"><b class="wide"></b></i></div></div>
	<div class="grid wide-grid"><div id="minimum" class="table"><i class="cell"><b class="segment"></b> <b class="segment"></b></i></div></div>
	<div class="grid wide-grid"><div id="fit" class="table"><i class="cell"><b class="segment"></b> <b class="segment"></b></i></div></div>
	<div class="grid"><div id="late" class="table"><i class="cell"><b class="narrow"></b></i></div><div id="early" class="table"><i class="cell"><b class="narrow"></b></i></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	end_node := layout_node_with_id(result.root, 'end') or { panic('missing #end') }
	end_wrapper := end_node.parent() or { panic('#end has no wrapper') }
	end_wrapper_style := end_wrapper.as_node_with_style() or { panic('#end wrapper has no style') }
	end_wrapper_used := result.used_values_for(end_wrapper_style) or { panic('#end wrapper has no used values') }
	assert end_wrapper.is_table_wrapper()
	assert end_wrapper_used.content_width().to_double() == 50
	assert end_wrapper_used.offset.x().to_double() == 50
	assert used_for_id(result, 'end').margin_right.to_double() == 0

	assert used_for_id(result, 'narrow-max').content_width().to_double() == 60
	assert used_for_id(result, 'wide-max').content_width().to_double() == 160
	assert used_for_id(result, 'minimum').content_width().to_double() == 80
	assert used_for_id(result, 'fit').content_width().to_double() == 120
	early_node := layout_node_with_id(result.root, 'early') or { panic('missing #early') }
	late_node := layout_node_with_id(result.root, 'late') or { panic('missing #late') }
	early_wrapper := (early_node.parent() or { panic('#early has no wrapper') }).as_node_with_style() or {
		panic('#early wrapper has no style')
	}
	late_wrapper := (late_node.parent() or { panic('#late has no wrapper') }).as_node_with_style() or {
		panic('#late wrapper has no style')
	}
	assert (result.used_values_for(early_wrapper) or { panic('#early wrapper has no values') }).offset.x().to_double() == 0
	assert (result.used_values_for(late_wrapper) or { panic('#late wrapper has no values') }).offset.x().to_double() == 100
}

// A baseline-aligned inline-block can raise the line baseline above the
// containing block's font strut. The strut's descent remains below that raised
// baseline, and the following wrapped line starts after the resulting line box.
fn test_wrapped_inline_blocks_preserve_strut_descent_between_lines() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#line { width:80px; font-size:16px; line-height:16px }
		#line span { display:inline-block; width:80px; height:20px }
	</style><div id="line"><span></span> <span></span> <span></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	line := used_for_id(result, 'line')
	assert line.line_boxes.len == 3
	assert line.line_boxes[0].height().to_double() > 20
	assert line.line_boxes[1].height().to_double() > 20
	assert line.line_boxes[2].height().to_double() > 20
	assert line.line_boxes[1].bottom().minus(line.line_boxes[1].height()).raw_value() >= line.line_boxes[0].bottom().raw_value()
	assert line.line_boxes[2].bottom().minus(line.line_boxes[2].height()).raw_value() >= line.line_boxes[1].bottom().raw_value()
}

// An originally-inline abspos pseudo-element remains in the list item's
// inline formatting context. The IFC publishes its exact inline-end insertion
// point after consecutive forced breaks for the static-position pass.
fn test_inline_end_static_position_survives_consecutive_forced_breaks() {
	document := html.parse_document('<!doctype html><style>
		body, ul { margin:0; padding:0 }
		ul { list-style:none; font-size:10px; line-height:20px }
		li { position:relative; width:100px }
		li::after { content:"X"; position:absolute }
	</style><ul><li id="item">XXX<br><br></li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := layout_node_with_id(result.root, 'item') or { panic('missing #item') }
	assert item.children_are_inline()
	mut positioned := ?&Node(none)
	for child in item.children() {
		assert !child.is_anonymous() || child.is_absolutely_positioned()
		if child.is_absolutely_positioned() {
			positioned = child
		}
	}
	item_style := item.as_node_with_style() or { panic('#item has no style') }
	item_used := result.used_values_for(item_style) or { panic('#item has no used values') }
	inline_end := item_used.inline_end_static_position_rect() or { panic('missing inline-end position') }
	assert inline_end.rect.x.to_double() == 0
	assert inline_end.rect.y.to_double() == 40
	positioned_node := positioned or { panic('missing abspos pseudo-element') }
	positioned_style := positioned_node.as_node_with_style() or { panic('abspos pseudo-element has no style') }
	positioned_used := result.used_values_for(positioned_style) or { panic('abspos pseudo-element has no used values') }
	assert positioned_used.static_position().x().to_double() == 0
	assert positioned_used.static_position().y().to_double() == 40
}

// A list item that establishes an independent formatting context lays out its
// own outside marker, including list items outside their parent's flow.
fn test_list_items_with_independent_formatting_contexts_lay_out_their_markers() {
	document := html.parse_document('<!doctype html><style>
		body, ul { margin:0 }
		ul { padding-left:100px; font:16px/24px SerenitySans }
		#floating { float:left }
		.flex { display:flex }
		#positioned { position:absolute; top:100px }
		#flow-root { display:flow-root list-item }
	</style><ul><li id="floating">a</li></ul><ul class="flex"><li id="flex-item">b</li></ul><ul><li id="positioned">c</li><li id="flow-root">d</li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['floating', 'flex-item', 'positioned', 'flow-root'] {
		item := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
		list_item := item.as_list_item_box() or { panic('#${id} is not a list item') }
		marker := list_item.marker() or { panic('#${id} has no marker') }
		marker_style := marker.as_node_with_style() or { panic('#${id} marker has no style') }
		marker_used := result.used_values_for(marker_style) or {
			panic('#${id} marker has no used values')
		}
		assert marker_used.content_width().to_double() > 0
		assert marker_used.content_height().to_double() == 24
		// The marker ends at or before the list item's inline-start content edge.
		assert marker_used.offset.x().plus(marker_used.content_width()).to_double() <= 0
		assert marker_used.offset.y().to_double() == 0
	}
}

fn list_item_marker_used_values(result DocumentLayoutResult, id string) &UsedValues {
	item := layout_node_with_id(result.root, id) or { panic('missing #${id}') }
	list_item := item.as_list_item_box() or { panic('#${id} is not a list item') }
	marker := list_item.marker() or { panic('#${id} has no marker') }
	marker_style := marker.as_node_with_style() or { panic('#${id} marker has no style') }
	return result.used_values_for(marker_style) or { panic('#${id} marker has no used values') }
}

fn test_outside_list_marker_aligns_with_the_list_item_first_baseline() {
	document := html.parse_document('<!doctype html><style>
		body, ul { margin:0 }
		ul { padding-left:100px; font:16px/24px SerenitySans }
		.big { font:32px/48px SerenitySans }
		.padded { padding-top:10px }
		#floating { float:left }
	</style><ul><li id="tall"><span class="big">X</span></li><li id="nested"><div class="padded">y</div></li><li id="empty"></li><li id="floating"><span class="big">X</span></li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['tall', 'floating'] {
		item_used := used_for_id(result, id)
		item_line := item_used.line_boxes[0]
		item_baseline := item_line.bottom().minus(item_line.block_length()).plus(item_line.baseline())
		marker_used := list_item_marker_used_values(result, id)
		marker_line := marker_used.line_boxes[0]
		marker_baseline := marker_line.bottom().minus(marker_line.block_length()).plus(marker_line.baseline())
		assert marker_used.offset.y().to_double() > 0
		assert marker_used.offset.y().plus(marker_baseline) == item_baseline
	}
	// A baseline inside a block child includes that child's offset.
	assert list_item_marker_used_values(result, 'nested').offset.y().to_double() == 10
	// Without a first baseline, the marker stays centered in its line height.
	assert list_item_marker_used_values(result, 'empty').offset.y().to_double() == 0
}

fn test_list_item_marker_line_height_floors_only_automatic_heights() {
	document := html.parse_document('<!doctype html><style>
		body, ul { margin:0 }
		ul { padding-left:100px; font:16px/24px SerenitySans }
		#fixed { height:5px }
		#clamped { max-height:5px }
		#floating { float:left }
	</style><ul><li id="fixed">a</li><li id="clamped">b</li><li id="empty"></li><li id="floating"></li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// Specified heights and max-height win over the marker floor.
	assert used_for_id(result, 'fixed').content_height().to_double() == 5
	assert used_for_id(result, 'clamped').content_height().to_double() == 5
	// Automatic heights, including a float's, are at least the marker's line height.
	assert used_for_id(result, 'empty').content_height().to_double() == 24
	assert used_for_id(result, 'floating').content_height().to_double() == 24
}

// A floated list item's shrink-to-fit probes must not leave its generated
// outside marker cached at zero width when nested inline fieldset content is
// measured before the marker's own formatting-context run.
fn test_floating_list_item_remeasures_marker_after_fieldset_intrinsic_probe() {
	document := html.parse_document('<!doctype html><style>
		li { float:right }
		fieldset, p { margin:0; padding:0 }
		fieldset, p, .actions, input { display:inline }
		p { position:relative }
	</style><ul><li id="item"><form><fieldset><p><span class="actions"><input type="submit" value="PASS"></span></p></fieldset></form></li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	marker := list_item_marker_used_values(result, 'item')
	assert marker.content_width().to_double() > 0
	assert marker.line_boxes.len == 1
	assert marker.offset.x().plus(marker.content_width()).to_double() <= 0
}

fn test_inline_abspos_static_position_accounts_for_float_intrusion() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#wrapper { position:relative; width:400px; height:200px }
		#float { float:left; width:100px; height:200px }
		#abspos { display:inline-block; position:absolute; width:50px; height:50px }
	</style><div id="wrapper">
		<div id="float"></div>
		<div id="abspos"></div>
	</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'abspos').static_position().x().to_double() == 100
	assert used_for_id(result, 'abspos').offset.x().to_double() == 100
	assert used_for_id(result, 'abspos').offset.y().to_double() == 0
}

fn test_range_input_keeps_intrinsic_inline_size_and_stretches_in_grid() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; grid-template-columns:auto 1fr; width:400px }
	</style><input id="inline-range" type="range"><div id="grid"><span>Label</span><input id="grid-range" type="range"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	inline_node := layout_node_with_id(result.root, 'inline-range') or { panic('missing inline range') }
	grid_node := layout_node_with_id(result.root, 'grid-range') or { panic('missing grid range') }
	assert inline_node.is_range_input_box()
	assert grid_node.is_range_input_box()
	inline_range := used_for_id(result, 'inline-range')
	grid_range := used_for_id(result, 'grid-range')
	assert inline_range.content_width().to_double() > 0
	assert inline_range.content_width().to_double() < 400
	assert inline_range.content_height().to_double() == 16
	assert grid_range.offset.x().plus(grid_range.content_width()).to_double() == 400
	assert grid_range.content_width().raw_value() > inline_range.content_width().raw_value()
}

fn test_unsupported_input_types_fall_back_to_text_input_layout() {
	document := html.parse_document('<!doctype html><style>body{margin:0}</style><input id="time" type="time"><input id="unknown" type="not-a-type">')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	time_node := layout_node_with_id(result.root, 'time') or { panic('missing time input') }
	unknown_node := layout_node_with_id(result.root, 'unknown') or { panic('missing unknown input') }
	assert time_node.is_text_input_box()
	assert unknown_node.is_text_input_box()
	assert time_node.has_children()
	assert unknown_node.has_children()
	assert used_for_id(result, 'time').content_width().raw_value() > 0
	assert used_for_id(result, 'time').content_width().raw_value() == used_for_id(result,
		'unknown').content_width().raw_value()
}

fn test_flex_item_baseline_ignores_vertical_align() {
	document := html.parse_document('<!doctype html><div id="line" style="font-size:26px">x<button style="display:inline-flex"><span id="item" style="display:inline-flex;vertical-align:top">3</span></button>y</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item := layout_node_with_id(result.root, 'item') or { panic('missing flex item') }
	assert item.is_flex_item()
	assert !item.vertical_align_applies()
	item_used := used_for_id(result, 'item')
	assert layout_box_baseline(result.state, item, .first).raw_value() > item_used.border_box_top().raw_value()
	assert used_for_id(result, 'line').content_height().to_double() < 40
}

fn test_zero_height_flex_and_grid_containers_stop_margin_collapse() {
	document := html.parse_document('<!doctype html><style>
		body{margin:0}.before,.after{height:40px}.flex,.grid{height:0;margin:35px 0 15px}.flex{display:flex}.grid{display:grid}
	</style><div class="before"></div><div><div class="flex"></div></div><div id="after-flex" class="after"></div><div id="before-grid" class="before"></div><div><div class="grid"></div></div><div id="after-grid" class="after"></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'after-flex').offset.y().to_double() == 90
	assert used_for_id(result, 'before-grid').offset.y().to_double() == 130
	assert used_for_id(result, 'after-grid').offset.y().to_double() == 220
}

fn test_subgrid_inherits_tracks_and_contributes_descendants_to_parent_sizing() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.inline-grid { display:inline-grid; vertical-align:top }
		.subgrid { display:grid; grid-template-columns:subgrid }
		#matching { grid-template-columns:auto auto }
		#matching-subgrid { grid-column:1 / span 2 }
		#matching-item { grid-column:2; width:200px; height:10px }
		#basic { grid-template-columns:auto }
		#basic-item { width:200px; height:10px }
		#edge { grid-template-columns:auto }
		#edge-subgrid { border-left:5px solid; border-right:7px solid; margin-left:10px; margin-right:13px; padding-left:15px; padding-right:20px }
		#edge-item { width:100px; height:10px }
		#auto-span { display:grid; grid-template-columns:40px 50px 60px }
		#auto-subgrid { grid-template-columns:subgrid [a] [b] [c] }
		#auto-item { grid-column:2; height:10px }
		#gap { display:grid; width:300px; grid-template-columns:100px 1fr; column-gap:50px }
		#gap-subgrid { grid-column:1 / span 2; column-gap:0 }
		#gap-left { grid-column:1; height:10px }
		#gap-right { grid-column:2; height:10px }
		#rows { display:grid; grid-template-columns:30px 30px; grid-template-rows:20px }
		#rows-subgrid { grid-column:1 / span 2; grid-row:1; grid-template-rows:subgrid }
		#row-first, #row-second { grid-column:1; height:10px }
	</style>
	<div id="matching" style="display:inline-grid;grid-template-columns:auto auto"><div id="matching-subgrid" style="display:grid;grid-column-start:1;grid-column-end:span 2;grid-template-columns:subgrid"><div id="matching-item" style="grid-column-start:2;width:200px;height:10px"></div></div></div>
	<div id="basic" style="display:inline-grid;grid-template-columns:auto"><div id="basic-subgrid" style="display:grid;grid-template-columns:subgrid"><div id="basic-item" style="width:200px;height:10px"></div></div></div>
	<div id="edge" style="display:inline-grid;grid-template-columns:auto"><div id="edge-subgrid" style="display:grid;grid-template-columns:subgrid;border-left:5px solid;border-right:7px solid;margin-left:10px;margin-right:13px;padding-left:15px;padding-right:20px"><div id="edge-item" style="width:100px;height:10px"></div></div></div>
	<div id="auto-span" style="display:grid;grid-template-columns:40px 50px 60px"><div id="auto-subgrid" style="display:grid;grid-template-columns:subgrid [a] [b] [c]"><div id="auto-item" style="grid-column-start:2;height:10px"></div></div></div>
	<div id="gap" style="display:grid;width:300px;grid-template-columns:100px 1fr;column-gap:50px"><div id="gap-subgrid" style="display:grid;grid-column-start:1;grid-column-end:span 2;grid-template-columns:subgrid;column-gap:0"><div id="gap-left" style="grid-column-start:1;height:10px"></div><div id="gap-right" style="grid-column-start:2;height:10px"></div></div></div>
	<div id="rows" style="display:grid;grid-template-columns:30px 30px;grid-template-rows:20px"><div id="rows-subgrid" style="display:grid;grid-column-start:1;grid-column-end:span 2;grid-row-start:1;grid-template-columns:subgrid;grid-template-rows:subgrid"><div id="row-first" style="grid-column-start:1;height:10px"></div><div id="row-second" style="grid-column-start:1;height:10px"></div></div></div>
	<div id="clamp" style="display:grid;grid-template-columns:100px"><div style="display:grid;grid-template-columns:subgrid"><div id="clamp-first" style="grid-column-start:2;width:10px;height:10px"></div><div id="clamp-second" style="grid-column-start:2;width:10px;height:10px"></div></div></div>
	<div id="no-parent" style="display:grid;grid-template-columns:subgrid [a] [b] [c] [d];grid-auto-columns:10px;width:100px"><i style="grid-row-start:1;width:10px;height:10px"></i><div id="no-parent-target" style="grid-column-start:a;grid-column-end:d;height:10px"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }

	matching := used_for_id(result, 'matching')
	assert matching.grid_template_columns().len == 2
	assert matching.grid_template_columns()[0].to_double() == 0
	assert matching.grid_template_columns()[1].to_double() == 200
	assert used_for_id(result, 'matching-item').content_width().to_double() == 200

	assert used_for_id(result, 'basic').content_width().to_double() == 200
	assert used_for_id(result, 'basic-subgrid').border_box_width().to_double() == 200
	assert used_for_id(result, 'basic-item').content_width().to_double() == 200

	assert used_for_id(result, 'edge').content_width().to_double() == 170
	assert used_for_id(result, 'edge-subgrid').border_box_width().to_double() == 147
	assert used_for_id(result, 'edge-item').content_width().to_double() == 100
	assert used_for_id(result, 'edge-item').offset.x().to_double() == 0

	assert used_for_id(result, 'auto-subgrid').content_width().to_double() == 90
	assert used_for_id(result, 'auto-subgrid').grid_columns_are_subgrid()
	assert used_for_id(result, 'auto-subgrid').grid_column_line_names() == [['a'], ['b'],
		['c']]
	assert used_for_id(result, 'auto-item').offset.x().to_double() == 40
	assert used_for_id(result, 'auto-item').content_width().to_double() == 50

	assert used_for_id(result, 'gap-left').offset.x().to_double() == 0
	assert used_for_id(result, 'gap-left').content_width().to_double() == 125
	assert used_for_id(result, 'gap-right').offset.x().to_double() == 125
	assert used_for_id(result, 'gap-right').content_width().to_double() == 175

	assert used_for_id(result, 'row-first').offset.y().to_double() == 0
	assert used_for_id(result, 'row-second').offset.y().to_double() == 0
	assert used_for_id(result, 'row-first').content_width().to_double() == 30
	assert used_for_id(result, 'row-second').content_width().to_double() == 30

	assert used_for_id(result, 'clamp-first').offset.x().to_double() == 0
	assert used_for_id(result, 'clamp-first').offset.y().to_double() == 0
	assert used_for_id(result, 'clamp-second').offset.x().to_double() == 0
	assert used_for_id(result, 'clamp-second').offset.y().to_double() == 10
	assert !used_for_id(result, 'no-parent').grid_columns_are_subgrid()
	assert used_for_id(result, 'no-parent-target').offset.x().to_double() == 10
	assert used_for_id(result, 'no-parent-target').content_width().to_double() == 10
}

fn test_subgrid_inherits_clipped_parent_grid_area_line_names() {
	mut column_lines := [][]css.GridLineName{len: 5}
	mut row_lines := [][]css.GridLineName{len: 5}
	column_lines[1] << css.GridLineName{
		name: 'literal-start'
	}
	column_lines[0] << css.GridLineName{
		name: 'area-start'
		implicit: true
	}
	column_lines[3] << css.GridLineName{
		name: 'area-end'
		implicit: true
	}
	row_lines[0] << css.GridLineName{
		name: 'area-start'
		implicit: true
	}
	row_lines[3] << css.GridLineName{
		name: 'area-end'
		implicit: true
	}
	// This second area overlaps the subgrid's columns but only touches its row
	// end. It must not leak names into either inherited axis.
	column_lines[1] << css.GridLineName{
		name: 'outside-start'
		implicit: true
	}
	column_lines[2] << css.GridLineName{
		name: 'outside-end'
		implicit: true
	}
	row_lines[3] << css.GridLineName{
		name: 'outside-start'
		implicit: true
	}
	row_lines[4] << css.GridLineName{
		name: 'outside-end'
		implicit: true
	}
	placement := GridItemPlacement{
		column: 1
		row: 1
		column_span: 2
		row_span: 2
	}
	inherited_columns := inherited_subgrid_line_names(column_lines, row_lines, placement,
		true)
	inherited_rows := inherited_subgrid_line_names(column_lines, row_lines, placement, false)
	assert inherited_columns.len == 3
	assert inherited_rows.len == 3
	assert inherited_columns[0].any(it.name == 'literal-start' && !it.implicit)
	assert inherited_columns[0].any(it.name == 'area-start' && it.implicit)
	assert inherited_columns[2].any(it.name == 'area-end' && it.implicit)
	assert inherited_rows[0].any(it.name == 'area-start' && it.implicit)
	assert inherited_rows[2].any(it.name == 'area-end' && it.implicit)
	for lines in [inherited_columns, inherited_rows] {
		for names in lines {
			assert !names.any(it.name.starts_with('outside-'))
		}
	}

	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.parent { display:grid; grid-template-areas:"top top top" "rail notice notice" "rail list page"; grid-template-columns:[start] 50px [rail-end] 100px [list-end] 150px [end]; grid-template-rows:[top] 20px [top-end] 0 [notice-end] 40px [end] }
		.top { grid-area:top }
		.content { display:grid; grid-column:start / end; grid-row:top-end / end; grid-template-columns:subgrid; grid-template-rows:subgrid }
		.sidebar { display:grid; grid-column:start / list-end; grid-row:top-end / end; grid-template-columns:subgrid; grid-template-rows:subgrid }
		.rail { grid-area:rail }
		.list { grid-area:list }
		.page { grid-area:page }
	</style><div class="parent"><div class="top"></div><div class="content"><div class="sidebar"><div id="rail" class="rail"></div><div id="list" class="list"></div></div><div id="page" class="page"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'rail').offset.x().to_double() == 0
	assert used_for_id(result, 'rail').content_width().to_double() == 50
	assert used_for_id(result, 'list').offset.x().to_double() == 50
	assert used_for_id(result, 'list').content_width().to_double() == 100
	assert used_for_id(result, 'page').offset.x().to_double() == 150
	assert used_for_id(result, 'page').content_width().to_double() == 150
}

// Upstream block-and-inline/*interrupting-block*: an in-flow block inside an
// inline stays in the inline's IFC. The line builder force-breaks around it,
// the parent BFC lays it out in place, and inline content resumes below it.
fn test_interrupting_block_is_laid_out_between_inline_lines() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
	</style><div id="container">first line<br><span id="inline"><b id="abs" style="position:absolute">abs</b><div id="block">block</div>rest</span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container := layout_node_with_id(result.root, 'container') or { panic('missing #container') }
	assert container.children_are_inline()
	block_node := layout_node_with_id(result.root, 'block') or { panic('missing #block') }
	block_parent := block_node.parent() or { panic('#block has no parent') }
	inline_node := layout_node_with_id(result.root, 'inline') or { panic('missing #inline') }
	assert layout_nodes_same(block_parent, inline_node)
	block := used_for_id(result, 'block')
	assert block.offset.y().to_double() == 20
	assert block.content_width().to_double() == 800
	assert block.content_height().to_double() == 20
	// The leading abspos box resolves its static position before the block.
	assert used_for_id(result, 'abs').static_position().y().to_double() == 20
	container_used := used_for_id(result, 'container')
	assert container_used.content_height().to_double() == 60
	mut rest_line_top := -1.0
	for line_box in container_used.line_boxes {
		for fragment in line_box.fragments() {
			if text := fragment.text() {
				if text == 'rest' {
					rest_line_top = line_box.bottom().to_double() - line_box.height().to_double()
				}
			}
		}
	}
	assert rest_line_top == 40
}

fn test_trailing_interrupting_block_margin_extends_bfc_root_height() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
	</style><div id="root" style="display:flow-root"><span>a<div id="block" style="margin-bottom:50px">b</div></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'block').offset.y().to_double() == 20
	assert used_for_id(result, 'root').content_height().to_double() == 90
}

fn test_float_after_interrupting_block_consumes_its_bottom_margin() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
	</style><div id="container"><span><div id="block" style="margin-bottom:40px; height:10px">block</div><img id="float" style="float:left; width:20px; height:20px">text</span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'block').offset.y().to_double() == 0
	float_used := used_for_id(result, 'float')
	assert float_used.offset.x().to_double() == 0
	assert float_used.offset.y().to_double() == 50
	assert used_for_id(result, 'container').content_height().to_double() == 70
}

fn test_inline_start_padding_attaches_after_interrupting_block() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
	</style><div id="container"><span style="padding-left:50px"> <div id="block" style="height:10px">block</div>text</span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'block').offset.y().to_double() == 0
	container_used := used_for_id(result, 'container')
	assert container_used.content_height().to_double() == 30
	mut text_left := -1.0
	for line_box in container_used.line_boxes {
		for fragment in line_box.fragments() {
			if text := fragment.text() {
				if text == 'text' {
					text_left = fragment.offset().x().to_double()
				}
			}
		}
	}
	assert text_left == 50
}

fn test_line_before_interrupting_block_is_not_justified() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
	</style><div id="container" style="text-align:justify; width:200px">aa bb cc<span><div id="block" style="height:10px"></div></span>dd ee ff gg hh ii jj kk ll mm nn oo pp qq</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	container_used := used_for_id(result, 'container')
	assert container_used.line_boxes.len > 2
	first_line := container_used.line_boxes[0]
	assert first_line.has_forced_break()
	assert first_line.width().to_double() < 200
	assert used_for_id(result, 'block').offset.y().to_double() == 20
}

// A definite flex basis is an inner size: box-sizing applies, and a border-box
// width smaller than the item's padding and border clamps its content to zero
// in the container's intrinsic width as it does during flex layout.
fn test_intrinsic_flex_basis_honors_border_box_sizing() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#flex { display:inline-flex }
		#tiny { box-sizing:border-box; width:1px; padding:0 5px; border:2px solid; height:10px }
		#wide { width:100px; height:10px }
	</style><div id="flex"><div id="tiny"></div><div id="wide"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert used_for_id(result, 'tiny').content_width().to_double() == 0
	assert used_for_id(result, 'flex').content_width().to_double() == 114
}

// InlinePaintable geometry: an inline box's pieces span its atomic inline
// children's margin boxes, not only their content-box fragments.
fn test_inline_box_geometry_spans_atomic_inline_margin_boxes() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; font-size:10px; line-height:20px }
		#atomic { display:inline-block; width:50px; height:10px; padding:0 5px; border:2px solid; margin:0 3px }
	</style><div><span id="inline"><span id="atomic"></span></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	inline_node := layout_node_with_id(result.root, 'inline') or { panic('missing #inline') }
	geometry := inline_box_absolute_geometry(inline_node, result.state) or {
		panic('missing inline geometry')
	}
	assert geometry.content_rect.x.to_double() == 0
	assert geometry.content_rect.width.to_double() == 70
}

// Nested inline boxes contribute their margin boxes to their parent's piece,
// and a line that only hosts an interrupting block adds no extent.
fn test_inline_box_geometry_unites_pieces_across_lines() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; font-size:10px; line-height:20px }
		#inner { padding-left:7px }
	</style><div><span id="outer">a<span id="inner">b</span><div style="height:10px"></div>c</span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	outer := layout_node_with_id(result.root, 'outer') or { panic('missing #outer') }
	inner := layout_node_with_id(result.root, 'inner') or { panic('missing #inner') }
	outer_geometry := inline_box_absolute_geometry(outer, result.state) or {
		panic('missing outer geometry')
	}
	inner_geometry := inline_box_absolute_geometry(inner, result.state) or {
		panic('missing inner geometry')
	}
	assert inner_geometry.border_rect.x.plus(inner_geometry.border_rect.width).raw_value() <= outer_geometry.content_rect.x.plus(outer_geometry.content_rect.width).raw_value()
	assert outer_geometry.content_rect.y.to_double() < 20
	assert outer_geometry.content_rect.y.plus(outer_geometry.content_rect.height).to_double() > 30
}

// Static positions come from markers recorded at the box's flow position: an
// abspos box after an inline's text starts at that text's inline end.
fn test_abspos_static_position_uses_line_marker_after_inline_content() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
		#abs { position:absolute; width:5px; height:5px }
	</style><div style="position:relative"><span id="text">text</span><span><i id="abs"></i></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	text_node := layout_node_with_id(result.root, 'text') or { panic('missing #text') }
	text_geometry := inline_box_absolute_geometry(text_node, result.state) or {
		panic('missing text geometry')
	}
	static_position := used_for_id(result, 'abs').static_position()
	assert static_position.x().to_double() > 0
	assert static_position.x().raw_value() == text_geometry.content_rect.x.plus(text_geometry.content_rect.width).raw_value()
	assert static_position.y().to_double() == 0
}

// A block-level abspos box whose marker follows in-flow content on its line
// starts below that line.
fn test_block_level_abspos_static_position_follows_line_content() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0 }
		body { font-size:10px; line-height:20px }
		#abs { position:absolute; display:block; width:5px; height:5px }
	</style><div style="position:relative">text<div id="abs"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	static_position := used_for_id(result, 'abs').static_position()
	assert static_position.x().to_double() == 0
	assert static_position.y().to_double() == 20
}

// Upstream abspos-inline-containing-block-atomic-inline-border-box: an inline
// containing block that only holds an atomic inline spans that box's margin
// box inline and its content box in the block direction.
fn test_inline_containing_block_spans_atomic_inline_margin_box() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; font-size:20px; line-height:20px }
		#host { position:relative }
		#atomic { display:inline-block; vertical-align:top; width:0; height:0; padding:6px 10px; border:4px solid }
		#overlay { position:absolute; inset:0 }
	</style><div><span id="host"><span id="atomic"></span><span id="overlay"></span></span></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	overlay := used_for_id(result, 'overlay')
	// The top-aligned atomic's content box starts below its 4px border and
	// 6px padding; its content box height is zero.
	assert overlay.content_width().to_double() == 28
	assert overlay.content_height().to_double() == 0
	assert overlay.offset.x().to_double() == 0
	assert overlay.offset.y().to_double() == 10
}

// An inline containing block's pieces are already relative to the table cell
// that hosts its inline formatting context. Converting them to the abspos
// containing block must therefore stop at that same cell instead of adding the
// cell and table wrapper offsets again.
fn test_inline_containing_block_inside_table_cell_uses_cell_coordinates() {
	document := html.parse_document('<!doctype html><style>
		* { margin:0; padding:0 }
		#host { position:relative }
		#overlay { position:absolute; inset:0 }
	</style><table><tr><td id="cell" style="width:200px"><span id="host">cell text<span id="overlay"></span></span></td></tr></table>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	cell := used_for_id(result, 'cell')
	overlay := used_for_id(result, 'overlay')
	assert overlay.cumulative_offset().x().raw_value() == cell.cumulative_offset().x().raw_value()
	assert overlay.cumulative_offset().y().raw_value() == cell.cumulative_offset().y().raw_value()
}

// Upstream flex-container-with-auto-width-avoids-float-intrusions: the border
// box of a formatting context root never overlaps a float's margin box, even
// with an automatic width or a negative margin.
fn test_formatting_context_roots_clear_floats_they_would_overlap() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0; width:400px }
		.full { float:left; width:100%; height:100px }
		.partial { float:left; width:100px; height:100px }
		.small { display:flex; height:100px; margin-left:-5px }
		.large { display:flex; height:100px; margin-left:-350px }
		.section { display:flow-root }
	</style><div class="section"><div class="full"></div><div id="cleared" class="small"></div></div><div class="section"><div class="partial"></div><div id="flush" class="small"></div></div><div class="section"><div class="partial"></div><div id="pulled" class="large"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	cleared := used_for_id(result, 'cleared')
	assert cleared.offset.y().to_double() == 100
	assert cleared.offset.x().to_double() == -5
	assert cleared.content_width().to_double() == 405
	flush := used_for_id(result, 'flush')
	assert flush.offset.y().to_double() == 0
	assert flush.offset.x().to_double() == 100
	assert flush.content_width().to_double() == 300
	pulled := used_for_id(result, 'pulled')
	assert pulled.offset.y().to_double() == 100
	assert pulled.offset.x().to_double() == -350
	assert pulled.content_width().to_double() == 750
}

// Upstream auto-fit-and-auto-fill-with-zero-min-track-size: a zero repeated
// track size is floored to 1px when counting automatic repetitions, and the
// gutters around collapsed auto-fit tracks collapse with them.
fn test_grid_auto_repeat_floors_zero_tracks_and_collapses_gutters() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.grid { display:grid; gap:10px; width:530px }
		#fit { grid-template-columns:repeat(auto-fit, minmax(0, 1fr)) }
		#fill { grid-template-columns:repeat(auto-fill, minmax(0, 1fr)) }
		.item { height:40px }
	</style><div id="fit" class="grid"><div id="fit-a" class="item"></div><div id="fit-b" class="item"></div><div id="fit-c" class="item"></div></div><div id="fill" class="grid"><div id="fill-a" class="item"></div><div id="fill-b" class="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// auto-fit: 49 repetitions, 46 of them empty and collapsed with their gutters.
	assert used_for_id(result, 'fit').content_height().to_double() == 40
	assert used_for_id(result, 'fit-a').content_width().to_double() == 170
	assert used_for_id(result, 'fit-b').offset.x().to_double() == 180
	assert used_for_id(result, 'fit-c').offset.x().to_double() == 360
	// auto-fill keeps all 49 tracks: (530 - 48 * 10) / 49 each.
	fill_a := used_for_id(result, 'fill-a')
	fill_b := used_for_id(result, 'fill-b')
	assert fill_a.content_width().to_double() > 1 && fill_a.content_width().to_double() < 1.1
	assert fill_b.offset.y().raw_value() == fill_a.offset.y().raw_value()
}

// Upstream fixed-tracks-followed-by-repeat-auto-fill: the definite tracks
// outside the automatic repetition use up space before repetitions are counted.
fn test_grid_auto_repeat_count_subtracts_fixed_template_tracks() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; width:300px; column-gap:10px; grid-template-columns:100px repeat(auto-fill, 50px) }
	</style><div id="grid"><div id="a"></div><div id="b"></div><div id="c"></div><div id="d"></div><div id="e"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// (300 + 10 - 100 - 10) / (50 + 10) = 3 repetitions after the 100px track.
	assert used_for_id(result, 'd').offset.x().to_double() == 230
	// The fifth item wraps to the first column of the next row.
	assert used_for_id(result, 'e').offset.x().to_double() == 0
}

// Upstream auto-placement-cursor-after-spanning-item-overflows-implicit-rows:
// after an auto-placed item, the cursor keeps its row and only advances past
// the item's columns, so row-spanning items pack side by side.
fn test_grid_auto_placement_cursor_keeps_the_row_of_spanning_items() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		#grid { display:grid; grid-template-columns:repeat(2, 100px) }
		.item { grid-row:span 2; height:50px }
	</style><div id="grid"><div id="a" class="item"></div><div id="b" class="item"></div><div id="c" class="item"></div><div id="d" class="item"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	c := used_for_id(result, 'c')
	d := used_for_id(result, 'd')
	assert c.offset.x().to_double() == 0
	assert c.offset.y().to_double() == 50
	assert d.offset.x().to_double() == 100
	assert d.offset.y().to_double() == 50
	assert used_for_id(result, 'grid').content_height().to_double() == 100
}
