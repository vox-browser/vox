module layout

import math

pub struct LayoutNodeState {
pub mut:
	id string
	kind string
	dom_id string
	label bool
	children_allowed bool = true
	width f64
	height f64
	intrinsic_width f64
	intrinsic_height f64
	alt_text string
	bitmap_id ?string
	default_bitmap_id ?string
	paintable_ids []string
	background_values []string
	computed map[string]string
	continuation_id string
	inserted bool
}

pub fn LayoutNodeState.create(id string, kind string) LayoutNodeState { return LayoutNodeState{id: id, kind: kind, dom_id: id} }
pub fn (node LayoutNodeState) dom_node() string { return node.dom_id }
pub fn (node LayoutNodeState) can_have_children() bool { return node.children_allowed && node.kind !in ['break', 'text', 'image', 'canvas', 'checkbox', 'radio'] }
pub fn (node LayoutNodeState) is_label() bool { return node.label }
pub fn (node LayoutNodeState) is_node_with_style() bool { return node.kind != 'text' && node.kind != 'break' }
pub fn (node LayoutNodeState) is_node_with_style_and_box_model_metrics() bool { return node.is_node_with_style() && node.kind != 'svg-text' }
pub fn (node LayoutNodeState) is_box() bool { return node.kind != 'text' }
pub fn (node LayoutNodeState) is_block_container() bool { return node.kind in ['block', 'fieldset', 'table-cell', 'viewport'] }
pub fn (node LayoutNodeState) is_inline_node() bool { return node.kind == 'inline' }
pub fn (node LayoutNodeState) is_break_node() bool { return node.kind == 'break' }
pub fn (node LayoutNodeState) is_text_node() bool { return node.kind == 'text' }
pub fn (node LayoutNodeState) is_replaced_box() bool { return node.kind in ['image', 'canvas', 'audio', 'video', 'navigable'] }
pub fn (node LayoutNodeState) is_fieldset_box() bool { return node.kind == 'fieldset' }
pub fn (node LayoutNodeState) is_legend_box() bool { return node.kind == 'legend' }
pub fn (node LayoutNodeState) is_list_item_box() bool { return node.kind == 'list-item' }
pub fn (node LayoutNodeState) is_list_item_marker_box() bool { return node.kind == 'list-marker' }
pub fn (node LayoutNodeState) is_table_wrapper() bool { return node.kind == 'table-wrapper' }
pub fn (node LayoutNodeState) is_viewport() bool { return node.kind == 'viewport' }
pub fn (node LayoutNodeState) is_svg_box() bool { return node.kind.starts_with('svg') }
pub fn (node LayoutNodeState) is_svg_graphics_box() bool { return node.kind in ['svg-graphics', 'svg-geometry', 'svg-image', 'svg-text'] }
pub fn (node LayoutNodeState) is_svg_geometry_box() bool { return node.kind == 'svg-geometry' }
pub fn (node LayoutNodeState) is_svg_clip_box() bool { return node.kind == 'svg-clip' }
pub fn (node LayoutNodeState) is_svg_mask_box() bool { return node.kind == 'svg-mask' }
pub fn (node LayoutNodeState) is_svg_pattern_box() bool { return node.kind == 'svg-pattern' }
pub fn (node LayoutNodeState) is_svg_foreign_object_box() bool { return node.kind == 'svg-foreign-object' }
pub fn (node LayoutNodeState) is_svg_svg_box() bool { return node.kind == 'svg-root' }
pub fn (node LayoutNodeState) is_textarea_box() bool { return node.kind == 'textarea' }
pub fn (node LayoutNodeState) is_scroll_container() bool { return node.kind.contains('scroll') }
pub fn (node LayoutNodeState) is_body() bool { return node.kind == 'body' }
pub fn (node LayoutNodeState) has_auto_content_box_size() bool { return node.width <= 0 || node.height <= 0 }
pub fn (node LayoutNodeState) has_css_transform() bool { return 'transform' in node.computed }
pub fn (mut node LayoutNodeState) inserted_into() { node.inserted = true }

pub fn (mut node LayoutNodeState) create_paintable() string { id := if node.paintable_ids.len == 0 { '${node.id}:paintable' } else { '${node.id}:paintable:${node.paintable_ids.len}' }; node.paintable_ids << id; return id }
pub fn (mut node LayoutNodeState) create_paintable_for_line_with_index(index int) string { id := '${node.id}:line:${index}'; node.paintable_ids << id; return id }
pub fn (mut node LayoutNodeState) add_paintable(id string) { if id !in node.paintable_ids { node.paintable_ids << id } }
pub fn (mut node LayoutNodeState) clear_paintables() { node.paintable_ids.clear() }
pub fn (node LayoutNodeState) first_paintable() ?string { return if node.paintable_ids.len > 0 { node.paintable_ids[0] } else { none } }
pub fn (node LayoutNodeState) paintables() []string { return node.paintable_ids.clone() }
pub fn (node LayoutNodeState) paintable_box() ?string { return node.first_paintable() }
pub fn (node LayoutNodeState) paintable_with_lines() ?string { return node.first_paintable() }

pub fn (node LayoutNodeState) compute_auto_content_box_size() (f64, f64) { return if node.intrinsic_width > 0 { node.intrinsic_width } else { node.width }, if node.intrinsic_height > 0 { node.intrinsic_height } else { node.height } }
pub fn (mut node LayoutNodeState) did_set_content_size(width f64, height f64) { node.width = width; node.height = height }
pub fn (node LayoutNodeState) natural_size() (f64, f64) { return node.compute_auto_content_box_size() }
pub fn (node LayoutNodeState) intrinsic_size() (f64, f64) { return node.compute_auto_content_box_size() }
pub fn (node LayoutNodeState) image_provider() string { return node.id }
pub fn (node LayoutNodeState) current_image_bitmap() ?string { return node.bitmap_id }
pub fn (node LayoutNodeState) default_image_bitmap() ?string { return node.default_bitmap_id }
pub fn (node LayoutNodeState) default_image_bitmap_sized(width f64, height f64) ?string { return if width > 0 && height > 0 { node.default_bitmap_id } else { none } }
pub fn (mut node LayoutNodeState) did_update_alt_text(text string) { node.alt_text = text }
pub fn (node LayoutNodeState) image_provider_visit_edges() []string { return [node.id, node.bitmap_id or { '' }, node.default_bitmap_id or { '' }].filter(it.len > 0) }

pub fn (node LayoutNodeState) background_layers() []string { return node.background_values.clone() }
pub fn (node LayoutNodeState) list_style_image() ?string { return node.computed['list-style-image'] }
pub fn (node LayoutNodeState) mutable_computed_values() map[string]string { return node.computed.clone() }
pub fn (mut node LayoutNodeState) propagate_non_inherit_values(values map[string]string) { for key, value in values { node.computed[key] = value } }
pub fn (mut node LayoutNodeState) reset_table_box_computed_values_used_by_wrapper_to_init_values() { for key in ['margin-left', 'margin-right', 'position', 'float'] { node.computed.delete(key) } }
pub fn (mut node LayoutNodeState) transfer_table_box_computed_values_to_wrapper_computed_values(values map[string]string) { for key, value in values { node.computed[key] = value } }
pub fn (node LayoutNodeState) create_anonymous_wrapper() LayoutNodeState { return LayoutNodeState{id: '${node.id}:anonymous', kind: 'anonymous-wrapper', computed: node.computed.clone()} }
pub fn (mut node LayoutNodeState) set_continuation_of_node(id string) { node.continuation_id = id }
pub fn (node LayoutNodeState) grapheme_segmenter() string { return 'unicode-grapheme' }
pub fn (node LayoutNodeState) line_segmenter() string { return 'unicode-line' }

pub struct LayoutTreeBuilder {
pub mut:
	parent_stack []string
	nodes []string
	steps []string
}

pub fn LayoutTreeBuilder.create() LayoutTreeBuilder { return LayoutTreeBuilder{} }
pub fn (mut builder LayoutTreeBuilder) build(root string) []string { builder.nodes = [root]; builder.steps << 'build'; return builder.nodes.clone() }
pub fn (mut builder LayoutTreeBuilder) push_parent(id string) { builder.parent_stack << id }
pub fn (mut builder LayoutTreeBuilder) pop_parent() ?string { return if builder.parent_stack.len > 0 { builder.parent_stack.pop() } else { none } }
pub fn (mut builder LayoutTreeBuilder) create_pseudo_element_if_needed(id string, needed bool) ?string { if !needed { return none }; pseudo := '${id}::pseudo'; builder.nodes << pseudo; return pseudo }
pub fn (mut builder LayoutTreeBuilder) fixup_tables() { builder.steps << 'fixup-tables' }
pub fn (mut builder LayoutTreeBuilder) generate_missing_child_wrappers() { builder.steps << 'missing-child-wrappers' }
pub fn (mut builder LayoutTreeBuilder) generate_missing_parents() { builder.steps << 'missing-parents' }
pub fn (mut builder LayoutTreeBuilder) missing_cells_fixup() { builder.steps << 'missing-cells' }
pub fn (mut builder LayoutTreeBuilder) remove_irrelevant_boxes() { builder.nodes = builder.nodes.filter(it.len > 0) }
pub fn (mut builder LayoutTreeBuilder) restructure_block_node_in_inline_parent() { builder.steps << 'restructure-block-in-inline' }
pub fn (mut builder LayoutTreeBuilder) wrap_in_button_layout_tree_if_needed(needed bool) { if needed { builder.steps << 'button-wrapper' } }
pub fn (mut builder LayoutTreeBuilder) insert_node_into_inline_or_block_ancestor(id string) { if id !in builder.nodes { builder.nodes << id } }
pub fn (mut builder LayoutTreeBuilder) update_layout_tree() { builder.steps << 'update' }
pub fn (mut builder LayoutTreeBuilder) update_layout_tree_before_children() { builder.steps << 'before-children' }
pub fn (mut builder LayoutTreeBuilder) update_layout_tree_after_children() { builder.steps << 'after-children' }
pub fn (builder LayoutTreeBuilder) for_each_in_tree_with_inside_display() []string { return builder.nodes.clone() }
pub fn (builder LayoutTreeBuilder) for_each_in_tree_with_internal_display() []string { return builder.nodes.clone() }

pub struct UsedValuesFacade {
pub mut:
	floating []string
	grid_columns []f64
	grid_rows []f64
	collapsed_borders [4]f64
	override_borders [4]f64
	table_row int = -1
	table_column int = -1
	materialized bool
}

pub fn (mut values UsedValuesFacade) add_floating_descendant(id string) { if id !in values.floating { values.floating << id } }
pub fn (values UsedValuesFacade) floating_descendants() []string { return values.floating.clone() }
pub fn (values UsedValuesFacade) border_top_collapsed() f64 { return values.collapsed_borders[0] }
pub fn (values UsedValuesFacade) border_right_collapsed() f64 { return values.collapsed_borders[1] }
pub fn (values UsedValuesFacade) border_bottom_collapsed() f64 { return values.collapsed_borders[2] }
pub fn (values UsedValuesFacade) border_left_collapsed() f64 { return values.collapsed_borders[3] }
pub fn (mut values UsedValuesFacade) set_grid_template_columns(columns []f64) { values.grid_columns = columns.clone() }
pub fn (values UsedValuesFacade) grid_template_columns() []f64 { return values.grid_columns.clone() }
pub fn (mut values UsedValuesFacade) set_grid_template_rows(rows []f64) { values.grid_rows = rows.clone() }
pub fn (values UsedValuesFacade) grid_template_rows() []f64 { return values.grid_rows.clone() }
pub fn (mut values UsedValuesFacade) set_override_borders_data(borders [4]f64) { values.override_borders = borders }
pub fn (values UsedValuesFacade) override_borders_data() [4]f64 { return values.override_borders }
pub fn (mut values UsedValuesFacade) set_table_cell_coordinates(row int, column int) { values.table_row = row; values.table_column = column }
pub fn (values UsedValuesFacade) table_cell_coordinates() (int, int) { return values.table_row, values.table_column }
pub fn (mut values UsedValuesFacade) materialize_from_paintable() { values.materialized = true }

pub struct LayoutStateFacade {
pub mut:
	populated bool
	committed bool
	relative_positions_resolved bool
}
pub fn (mut state LayoutStateFacade) populate_from_paintable() { state.populated = true }
pub fn (mut state LayoutStateFacade) resolve_relative_positions() { state.relative_positions_resolved = true }
pub fn (mut state LayoutStateFacade) commit() bool { state.committed = state.populated; return state.committed }

pub struct LayoutMarginState {
pub mut:
	callbacks map[string]bool
}
pub fn (mut state LayoutMarginState) register_block_container_y_position_update_callback(id string) { state.callbacks[id] = true }
pub fn (mut state LayoutMarginState) unregister_block_container_y_position_update_callback(id string) { state.callbacks.delete(id) }

pub struct LayoutFloatSideState {
pub mut:
	values []f64
}
pub fn (mut state LayoutFloatSideState) clear() { state.values.clear() }

pub struct LayoutLineBuilderState {
pub mut:
	block_offset f64
}
pub fn (state LayoutLineBuilderState) current_block_offset() f64 { return state.block_offset }

pub fn (iterator TextNodeChunkIterator) font_for_space() string { return 'space-font' }
