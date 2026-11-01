module layout

import css
import dom

struct RetainedBlockValues {
	node       &NodeWithStyle
	containing ?&NodeWithStyle
	values     UsedValues
}

fn append_retained_block_snapshot(mut snapshots []RetainedBlockValues,
	node &NodeWithStyle, values &UsedValues) {
	snapshots << RetainedBlockValues{
		node: node
		containing: retained_block_containing_node(values)
		values: *values
	}
	mut snapshot := unsafe { &snapshots[snapshots.len - 1].values }
	snapshot.containing_block_used_values_ = none
	snapshot.line_boxes = copy_retained_inline_lines(snapshot.line_boxes)
	snapshot.line_boxes_are_shared_ = false
	if rare := snapshot.rare_ { snapshot.rare_ = rare.clone() }
}

@[heap]
struct RetainedBlockLayout {
	inputs            []RetainedInlineInput
	values            []RetainedBlockValues
	space             AvailableSpace
	width             CSSPixels
	height            CSSPixels
	definite_width    bool
	definite_height   bool
	width_constraint  SizeConstraint
	height_constraint SizeConstraint
	font_generation   u64
	font_policy       dom.FontRenderingPolicy
	style_environment u64
	lines             []LineBox
	inline_end        ?StaticPositionRect
	grid_container_rare ?&UsedValuesRareData
	result            FormattingContextResult
mut:
	paint_lines_ map[u64]&RetainedBlockPaintLines
	paint_boxes_ map[u64]&RetainedBlockPaintBox
	visual_lines_ map[u64][]dom.VisualLine
}

// Independent ordinary flow cannot exchange floats or collapsed margins with
// its parent. Its unchanged descendants keep local geometry when the whole
// context moves. Specialized layout and position-dependent side effects still
// run through the complete algorithm.
fn collect_retained_block_inputs(node &Node, mut inputs []RetainedInlineInput,
	mut rejected map[u64]bool) bool {
	key := u64(voidptr(node))
	if !disable_retained_block_rejection_cache && rejected[key] {
		report_retained_block_rejection()
		return false
	}
	mut accepted := false
	defer { if !accepted { remember_rejected_block_input(mut rejected, key) } }
	computed := node.computed_values()
	image := if node.is_replaced_box() { retained_block_image_input(node) } else { none }
	if node.is_generated_for_pseudo_element() || node.is_generated_text_node()
		|| node.is_in_ua_internal_shadow_tree() || node.is_svg_box()
		|| (node.is_replaced_box() && image == none)
		|| node.is_floating() || !retained_layout_position_is_unshifted(node) || node.is_list_item_box()
		|| node.is_list_item_marker_box() || node.is_fieldset_box()
		|| node.has_layout_containment() || node.has_paint_containment()
		|| computed.writing_mode() != .horizontal_tb || computed.has_animated_properties()
		|| computed.mutation_revision() == 0 || computed.content_visibility() != .visible
		|| computed.establishes_multi_column_container()
		|| computed.continue_value() in [.collapse, .discard]
		|| (!node.is_text_node() && !node.display().is_flow_inside()
			&& !node.display().is_flow_root_inside() && !retained_context_allows_flex(node)
			&& !retained_context_allows_grid(node)) {
		return false
	}
	container_type := computed.container_type()
	if container_type.is_size_container || container_type.is_inline_size_container { return false }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	mut text := ''
	if value := node.as_text_node() {
		if value.first_letter_ != none || value.source_range_length_ != none
			|| value.is_empty_editable_ || value.produces_line_box_fragment_when_empty_ {
			return false
		}
		text = value.text_for_rendering()
	}
	line_height := computed.line_height()
	inputs << RetainedInlineInput{
		node: node
		style: computed
		style_revision: computed.mutation_revision()
		child_count: node.child_count()
		parent_id: if inputs.len == 0 { u64(0) } else if parent := node.parent() { u64(voidptr(parent)) } else { 0 }
		sibling_index: node.index_in_parent_
		text: text
		font_list: computed.cached_computed_font_list()
		font_generation: computed.cached_computed_font_list_generation_
		line_height: line_height
		root_font_size: computed.root_font_size_px_
		root_line_height: computed.root_line_height_px_
		image: image
	}
	for child in node.children() {
		if !collect_retained_block_inputs(child, mut inputs, mut rejected) { return false }
	}
	accepted = true
	return true
}

fn run_retaining_independent_formatting_context(mut state LayoutState, box &Node,
	mut used UsedValues, mode LayoutMode, space AvailableSpace) FormattingContextResult {
	mut geometry_scratch := begin_nested_geometry_scratch(box.document(), mode)
	defer { geometry_scratch.finish() }
	styled := box.as_node_with_style() or {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	if mode != .normal || state.subtree_root != none || !space.width.is_definite()
		|| box.document().in_quirks_mode()
		|| box.is_viewport() || box.is_root_element()
		|| (box.as_block_container() == none && !retained_context_allows_flex(box)
			&& !retained_context_allows_grid(box))
		|| box.display().is_inline_outside()
		|| (!creates_block_formatting_context(styled) && !retained_context_allows_flex(box)
			&& !retained_context_allows_grid(box)) {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	key := u64(voidptr(box))
	font_generation := css.css_style_computer_for(box.document()).font_computer().environment_generation()
	if cached := state.previous_block_layouts_[key] {
		if cached.space == space && cached.width == used.content_width()
			&& cached.height == used.content_height()
			&& cached.definite_width == used.has_definite_width()
			&& cached.definite_height == used.has_definite_height()
			&& cached.width_constraint == used.width_constraint
			&& cached.height_constraint == used.height_constraint
			&& cached.font_policy == box.document().font_rendering_policy()
			&& cached.style_environment == box.document().style_environment_version()
			&& retained_inline_inputs_are_current(cached.inputs)
			&& (cached.font_generation == font_generation
				|| retained_layout_fonts_are_current(cached.inputs)) {
			report_retained_block_image_reuse(cached.inputs)
			report_retained_flex_layout(cached.inputs)
			report_retained_grid_layout(cached.inputs)
			report_relative_flow_layout_reuse(cached.inputs)
			if cached.font_generation != font_generation && retained_font_generation_diagnostics {
				eprintln('Vox retained block font generation: ${cached.font_generation} -> ${font_generation}, ${cached.inputs.len} inputs')
			}
			used.borrow_retained_line_boxes(cached.lines)
			if end := cached.inline_end { used.set_inline_end_static_position_rect(end) }
			// The root is omitted from descendant snapshots: its outer geometry
			// belongs to the caller. A grid also publishes its own track sizes,
			// line names and content baselines, which must survive this replay.
			if rare := cached.grid_container_rare {
				used.rare_ = rare.clone()
				used.rare_is_shared_ = false
			}
			for index in 0 .. cached.values.len {
				entry := unsafe { &cached.values[index] }
				mut containing_values := ?&UsedValues(none)
				if containing := entry.containing {
					containing_values = state.get(containing)
				}
				_ = state.restore_retained_values(entry.node, &entry.values, containing_values)
			}
			mut retained := retain_geometry_allocations()
			defer { retained.finish() }
			for input in cached.inputs {
				input_key := u64(voidptr(input.node))
				if inline_cache := state.previous_inline_layouts_[input_key] {
					state.inline_layouts_[input_key] = inline_cache
				}
				if block_cache := state.previous_block_layouts_[input_key] {
					state.block_layouts_[input_key] = block_cache
				}
			}
			state.block_layouts_[key] = cached
			return cached.result
		}
	}
	mut inputs := []RetainedInlineInput{}
	if !collect_retained_block_inputs(box, mut inputs, mut state.block_layout_rejections_) {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	width := used.content_width()
	height := used.content_height()
	definite_width := used.has_definite_width()
	definite_height := used.has_definite_height()
	width_constraint := used.width_constraint
	height_constraint := used.height_constraint
	result := layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	mut snapshots := []RetainedBlockValues{cap: inputs.len - 1}
	for input in inputs[1..] {
		child := input.node.as_node_with_style() or { continue }
		if values := state.try_get(child) {
			append_retained_block_snapshot(mut snapshots, child, values)
		}
	}
	state.block_layouts_[key] = &RetainedBlockLayout{
		inputs: inputs.clone()
		values: snapshots
		space: space
		width: width
		height: height
		definite_width: definite_width
		definite_height: definite_height
		width_constraint: width_constraint
		height_constraint: height_constraint
		font_generation: font_generation
		font_policy: box.document().font_rendering_policy()
		style_environment: box.document().style_environment_version()
		lines: copy_retained_inline_lines(used.line_boxes)
		inline_end: used.inline_end_static_position_rect()
		grid_container_rare: if box.display().is_grid_inside() {
			if rare := used.rare_ { ?&UsedValuesRareData(rare.clone()) } else { none }
		} else { none }
		result: result
	}
	return result
}

fn retained_block_containing_node(values &UsedValues) ?&NodeWithStyle {
	parent := values.containing_block_used_values_ or { return none }
	return parent.node_
}
