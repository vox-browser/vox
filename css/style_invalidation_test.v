module css

import dom

fn test_style_invalidation_levels_imply_less_severe_work() {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	assert invalidation.is_none()

	invalidation.ensure_at_least(.repaint)
	assert invalidation.needs_repaint()
	assert !invalidation.needs_relayout()

	invalidation.ensure_at_least(.relayout)
	assert invalidation.needs_repaint()
	assert invalidation.needs_relayout()
	assert !invalidation.needs_layout_tree_rebuild()

	invalidation.ensure_at_least(.rebuild_layout_tree)
	assert invalidation.needs_layout_tree_rebuild()
	assert invalidation.layout_tree_rebuild_root() == .parent
}

fn test_style_invalidation_tracks_independent_work() {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	invalidation.set_needs_stacking_context_tree_rebuild()
	assert invalidation.needs_stacking_context_tree_rebuild()
	assert invalidation.needs_repaint()
	assert invalidation.invalidates_hit_test_display_list()

	mut overflow_only := RequiredInvalidationAfterStyleChange{}
	overflow_only.set_needs_scrollable_overflow_recalculation()
	assert overflow_only.needs_scrollable_overflow_recalculation()
	assert !overflow_only.needs_repaint()
	overflow_only.ensure_at_least(.relayout)
	assert !overflow_only.needs_scrollable_overflow_recalculation()

	mut visual_context := RequiredInvalidationAfterStyleChange{}
	visual_context.ensure_accumulated_visual_contexts_at_least(.update_values)
	assert visual_context.accumulated_visual_contexts() == .update_values
	assert !visual_context.invalidates_hit_test_display_list()
	visual_context.ensure_accumulated_visual_contexts_at_least(.rebuild)
	assert visual_context.invalidates_hit_test_display_list()
}

fn test_background_attachment_rebuilds_accumulated_visual_contexts() {
	assert property_rebuilds_accumulated_visual_contexts(.background_attachment)
	assert !property_rebuilds_accumulated_visual_contexts(.background_color)
}

// Ladybird 148b0c0ec65a6c34dece2ae76c85197187b44915.
fn test_overflow_changes_rebuild_accumulated_visual_contexts() {
	for property in [PropertyID.overflow_x, .overflow_y] {
		assert property_rebuilds_accumulated_visual_contexts(property)
		for values in [['visible', 'hidden'], ['hidden', 'visible'], ['clip', 'scroll']] {
			old_value := dom_style_value_from_value_logic(parse_css_value_logic(property, values[0]) or { panic('old value') })
			new_value := dom_style_value_from_value_logic(parse_css_value_logic(property, values[1]) or { panic('new value') })
			invalidation := compute_property_invalidation(property, old_value, new_value)
			// Vox currently rebuilds layout boxes for overflow changes. That
			// stronger invalidation also rebuilds their visual contexts and
			// intentionally does not retain a redundant context-only flag.
			assert invalidation.needs_layout_tree_rebuild()
				|| invalidation.accumulated_visual_contexts() == .rebuild
			assert invalidation.invalidates_hit_test_display_list()
		}
	}
}

fn test_hit_testing_property_metadata_matches_upstream() {
	for property_id in [
		PropertyID.border_bottom_left_radius,
		.border_bottom_right_radius,
		.border_top_left_radius,
		.border_top_right_radius,
		.fill,
		.fill_rule,
		.pointer_events,
		.resize,
		.visibility,
	] {
		assert property_affects_hit_testing(property_id)
		invalidation := compute_property_invalidation(property_id,
			&dom.StyleValue{ css_text: 'old' }, &dom.StyleValue{ css_text: 'new' })
		assert invalidation.affects_hit_testing
		assert invalidation.invalidates_hit_test_display_list()
	}
	assert !property_affects_hit_testing(.background_color)
}

fn test_container_properties_recompute_descendant_styles() {
	old_value := &dom.StyleValue{css_text: 'old'}
	new_value := &dom.StyleValue{css_text: 'new'}
	name_invalidation := compute_property_invalidation(.container_name, old_value, new_value)
	assert name_invalidation.recompute_descendant_styles

	old_type := &dom.StyleValue{css_text: 'normal'}
	new_type := &dom.StyleValue{css_text: 'size'}
	type_invalidation := compute_property_invalidation(.container_type, old_type, new_type)
	assert type_invalidation.recompute_descendant_styles
}

fn test_display_box_presence_changes_rebuild_the_layout_tree() {
	block := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.block))))
	none_display := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_))))
	box_presence := compute_property_invalidation(.display, block, none_display)
	assert box_presence.needs_layout_tree_rebuild()
	assert box_presence.layout_tree_rebuild_root() == .box_presence_change

	inline_ := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.inline_))))
	box_kind := compute_property_invalidation(.display, block, inline_)
	assert box_kind.needs_layout_tree_rebuild()
	assert box_kind.layout_tree_rebuild_root() == .parent

	old_content := &dom.StyleValue{css_text: '"old"'}
	new_content := &dom.StyleValue{css_text: '"new"'}
	content := compute_property_invalidation(.content, old_content, new_content)
	assert content.layout_tree_rebuild_root() == .self
}

fn test_style_invalidation_tracks_inherited_groups_and_flags() {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	invalidation.mark_inherited_style_group_changed(2)
	invalidation.mark_inherited_style_group_changed(5)
	assert invalidation.inherited_style_changed()
	assert invalidation.inherited_style_groups_changed() == 0x24
	assert !invalidation.is_none()

	invalidation.mark_all_inherited_style_groups_changed()
	assert invalidation.inherited_style_groups_changed() == 0x7f

	mut selection := RequiredInvalidationAfterStyleChange{}
	selection.repaint_selection = true
	assert !selection.is_none()
}

fn test_style_invalidation_merge_preserves_most_severe_rebuild_root() {
	left := RequiredInvalidationAfterStyleChange.rebuild_layout_tree_from(.self)
	mut right := RequiredInvalidationAfterStyleChange.rebuild_layout_tree_from(.box_presence_change)
	right.ensure_accumulated_visual_contexts_at_least(.update_values)
	right.needs_scroll_container_resnap = true

	merged := required_invalidation_after_style_change_or(left, right)
	assert merged.layout_tree_rebuild_root() == .box_presence_change
	assert merged.accumulated_visual_contexts() == .update_values
	assert merged.needs_scroll_container_resnap
	assert merged.needs_stacking_context_tree_rebuild()

	full := RequiredInvalidationAfterStyleChange.full()
	assert required_invalidation_after_style_change_is_full(full)
	assert full.layout_tree_rebuild_root() == .parent
}

fn test_decode_style_invalidation_unpacks_engine_fields() {
	packed := u32(InvalidationLevel.rebuild_layout_tree) | (u32(AccumulatedVisualContextInvalidation.rebuild) << 2) | (u32(LayoutTreeRebuildRoot.box_presence_change) << 4) | (u32(1) << 6) | (u32(1) << 7) | (u32(1) << 8) | (u32(1) << 9) | (u32(0x25) << 10) | (u32(1) << 17) | (u32(1) << 18) | (u32(1) << 19) | (u32(1) << 22)
	invalidation := decode_style_invalidation(packed)
	assert invalidation.needs_layout_tree_rebuild()
	assert invalidation.layout_tree_rebuild_root() == .box_presence_change
	assert invalidation.accumulated_visual_contexts() == .rebuild
	assert invalidation.needs_stacking_context_tree_rebuild()
	assert invalidation.needs_scrollable_overflow_recalculation_
	assert !invalidation.needs_scrollable_overflow_recalculation()
	assert invalidation.needs_scroll_container_resnap
	assert invalidation.recompute_descendant_styles
	assert invalidation.inherited_style_groups_changed() == 0x25
	assert invalidation.changes_containing_block_establishment
	assert invalidation.repaint_propagated_text_decorations
	assert invalidation.non_inherited_property_inheritance_sources_changed
	assert invalidation.affects_hit_testing
}
