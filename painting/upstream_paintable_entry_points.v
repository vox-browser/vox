module painting

import math

// PaintableState is the shared state behind the native Paintable hierarchy.
// The V port uses tagged kind data instead of dozens of GC subclasses, while
// preserving geometry, hit testing, selection, scrolling and paint dispatch.
pub struct PaintableState {
pub mut:
	id                                  string
	kind                                string
	layout_id                           string
	dom_id                              string
	navigable_id                        string
	parent_id                           string
	stacking_context_id                 string
	local_offset                        Point
	content_dimensions                  Size
	containing_block_position           Point
	metrics                             BoxModelMetrics
	override_borders                    ?BordersData
	radii                               BorderRadiiData
	visible                             bool = true
	pointer_events_enabled              bool = true
	positioned                          bool
	fixed_position                      bool
	sticky_position                     bool
	absolutely_positioned               bool
	floating                            bool
	inline                              bool
	non_invertible_transform            bool
	css_transform                       Affine = Affine{}
	selection                           SelectionState
	selection_has_styling               bool
	overflow                            ?OverflowData
	filter_value                        ?GfxFilter
	sticky                              StickyInsets
	grid_columns                        []f64
	grid_rows                           []f64
	table_row                           int = -1
	table_column                        int = -1
	enclosing_scroll_index              int
	own_scroll_index                    int
	visual_context_index                int
	descendant_visual_context_index     int
	commands_by_phase                   map[PaintPhase][]DisplayListCommand
	fragments_value                     []PaintableFragment
	children                            []PaintableState
	computed_path_value                 []Point
	computed_transform_value            ComputedTransforms
	paintable_boxes_with_auto_visibility []string
	scroll_state                        ScrollState
	visual_tree                         AccumulatedVisualContextTree = new_accumulated_visual_context_tree()
	needs_repaint                       bool
	resize                              ResizeHandle
}

pub fn PaintableState.create(id string, kind string, rect Rect) PaintableState {
	return PaintableState{id: id, kind: kind, local_offset: rect.location(), content_dimensions: rect.size()}
}

pub fn (state PaintableState) debug_description() string { return '${state.kind}(${state.id})' }
pub fn (state PaintableState) document() string { return state.dom_id }
pub fn (state PaintableState) containing_block() string { return state.parent_id }
pub fn (state PaintableState) computed_values() string { return state.kind }
pub fn (state PaintableState) is_visible() bool { return state.visible }
pub fn (state PaintableState) visible_for_hit_testing() bool { return state.visible && state.pointer_events_enabled && !state.non_invertible_transform }
pub fn (mut state PaintableState) set_dom_node(id string) { state.dom_id = id }
pub fn (state PaintableState) dom_node() string { return state.dom_id }
pub fn (state PaintableState) navigable() string { return state.navigable_id }
pub fn (state PaintableState) is_positioned() bool { return state.positioned }
pub fn (state PaintableState) is_fixed_position() bool { return state.fixed_position }
pub fn (state PaintableState) is_sticky_position() bool { return state.sticky_position }
pub fn (state PaintableState) is_absolutely_positioned() bool { return state.absolutely_positioned }
pub fn (state PaintableState) is_floating() bool { return state.floating }
pub fn (state PaintableState) is_inline() bool { return state.inline }
pub fn (state PaintableState) display() string { return state.kind }
pub fn (state PaintableState) forms_unconnected_subtree() bool { return state.kind in ['svg-clip', 'svg-mask', 'svg-pattern'] }
pub fn (state PaintableState) layout_node() string { return state.layout_id }
pub fn (state PaintableState) layout_box() string { return state.layout_id }
pub fn (state PaintableState) layout_node_with_style_and_box_metrics() string { return state.layout_id }
pub fn (state PaintableState) dom_node_of_svg() string { return state.dom_id }
pub fn (state PaintableState) navigable_container() string { return state.navigable_id }
pub fn (state PaintableState) is_navigable_container_viewport_paintable() bool { return state.kind == 'navigable-viewport' }
pub fn (state PaintableState) is_viewport_paintable() bool { return state.kind == 'viewport' || state.kind == 'navigable-viewport' }
pub fn (state PaintableState) is_paintable_with_lines() bool { return state.fragments_value.len > 0 || state.kind == 'lines' }
pub fn (state PaintableState) is_svg_paintable() bool { return state.kind.starts_with('svg') }
pub fn (state PaintableState) is_svg_svg_paintable() bool { return state.kind == 'svg-root' }
pub fn (state PaintableState) is_svg_path_paintable() bool { return state.kind == 'svg-path' }
pub fn (state PaintableState) is_svg_graphics_paintable() bool { return state.kind in ['svg-graphics', 'svg-path', 'svg-root'] }
pub fn (state PaintableState) is_text_paintable() bool { return state.kind == 'text' }
pub fn (state PaintableState) selection_state() SelectionState { return state.selection }
pub fn (state PaintableState) has_styling() bool { return state.selection_has_styling }
pub fn (state PaintableState) selection_style() string { return if state.selection_has_styling { 'selection' } else { '' } }
pub fn (mut state PaintableState) set_selection_state(value SelectionState) { state.selection = value }
pub fn (state PaintableState) box_type_agnostic_position() Point { return state.absolute_position() }
pub fn (state PaintableState) has_stacking_context() bool { return state.stacking_context_id.len > 0 }
pub fn (state PaintableState) enclosing_stacking_context() string { return state.stacking_context_id }
pub fn (mut state PaintableState) set_stacking_context(id string) { state.stacking_context_id = id }
pub fn (mut state PaintableState) invalidate_stacking_context() { state.stacking_context_id = '' }

pub fn (state PaintableState) absolute_position() Point { return state.containing_block_position.add(state.local_offset) }
pub fn (state PaintableState) absolute_x() f64 { return state.absolute_position().x }
pub fn (state PaintableState) absolute_y() f64 { return state.absolute_position().y }
pub fn (state PaintableState) content_size() Size { return state.content_dimensions }
pub fn (state PaintableState) content_width() f64 { return state.content_dimensions.width }
pub fn (state PaintableState) content_height() f64 { return state.content_dimensions.height }
pub fn (state PaintableState) border_box_width() f64 { return state.content_width() + state.metrics.padding.left + state.metrics.padding.right + state.metrics.border.left + state.metrics.border.right }
pub fn (state PaintableState) border_box_height() f64 { return state.content_height() + state.metrics.padding.top + state.metrics.padding.bottom + state.metrics.border.top + state.metrics.border.bottom }
pub fn (mut state PaintableState) set_offset(offset Point) { state.local_offset = offset }
pub fn (mut state PaintableState) set_content_size(size Size) { state.content_dimensions = size }
pub fn (mut state PaintableState) set_content_width(width f64) { state.content_dimensions = Size{width, state.content_dimensions.height} }
pub fn (mut state PaintableState) set_content_height(height f64) { state.content_dimensions = Size{state.content_dimensions.width, height} }
pub fn (state PaintableState) box_model() BoxModelMetrics { return state.metrics }
pub fn (state PaintableState) compute_absolute_rect() Rect { return Rect{state.absolute_x(), state.absolute_y(), state.content_width(), state.content_height()} }
pub fn (state PaintableState) absolute_rect() Rect { return state.compute_absolute_rect() }
pub fn (state PaintableState) absolute_padding_box_rect() Rect { p := state.metrics.padding; return state.absolute_rect().inflated(p.top, p.right, p.bottom, p.left) }
pub fn (state PaintableState) absolute_border_box_rect() Rect { b := state.metrics.border; return state.absolute_padding_box_rect().inflated(b.top, b.right, b.bottom, b.left) }
pub fn (state PaintableState) absolute_united_content_rect() Rect { return state.united_rect_for_continuation_chain(.content_box) }
pub fn (state PaintableState) absolute_united_padding_box_rect() Rect { return state.united_rect_for_continuation_chain(.padding_box) }
pub fn (state PaintableState) absolute_united_border_box_rect() Rect { return state.united_rect_for_continuation_chain(.border_box) }
pub fn (state PaintableState) united_rect_for_continuation_chain(kind BackgroundBoxKind) Rect {
	mut result := match kind { .content_box { state.absolute_rect() } .padding_box { state.absolute_padding_box_rect() } else { state.absolute_border_box_rect() } }
	for child in state.children { result = result.united(child.united_rect_for_continuation_chain(kind)) }
	return result
}
pub fn (state PaintableState) absolute_resizer_rect() Rect { size := state.chrome_metrics().resize_gripper_size; border := state.absolute_border_box_rect(); return Rect{border.right() - size, border.bottom() - size, size, size} }
pub fn (state PaintableState) overflow_clip_edge_rect() Rect { return state.absolute_padding_box_rect() }
pub fn (state PaintableState) get_clip_rect() Rect { return state.overflow_clip_edge_rect() }
pub fn (state PaintableState) get_clip_area() ?Rect { return if state.visible { state.get_clip_rect() } else { none } }
pub fn (state PaintableState) get_mask_area() ?Rect { return if state.is_svg_paintable() { state.absolute_border_box_rect() } else { none } }
pub fn (state PaintableState) get_mask_type() SVGMaskType { return .alpha }
pub fn (state PaintableState) calculate_mask(converter DevicePixelConverter) DisplayList { return calculate_svg_mask_display_list(SVGMaskDefinition{id: state.id, area: state.absolute_border_box_rect()}, converter) }
pub fn (state PaintableState) calculate_clip(converter DevicePixelConverter) DisplayList { return calculate_svg_clip_display_list(SVGClipDefinition{id: state.id, area: state.get_clip_rect()}, converter) }
pub fn (state PaintableState) get_svg_mask_area() ?Rect { return state.get_mask_area() }
pub fn (state PaintableState) get_svg_clip_area() ?Rect { return state.get_clip_area() }
pub fn (state PaintableState) get_svg_mask_type() SVGMaskType { return state.get_mask_type() }
pub fn (state PaintableState) target_svg_transform() Affine { return state.computed_transform_value.svg_transform }

pub fn (state PaintableState) has_scrollable_overflow() bool { return if overflow := state.overflow { overflow.has_scrollable_overflow } else { false } }
pub fn (state PaintableState) scrollable_overflow_rect() Rect { return if overflow := state.overflow { overflow.scrollable_overflow_rect } else { state.absolute_padding_box_rect() } }
pub fn (mut state PaintableState) set_overflow_data(value OverflowData) { state.overflow = value }
pub fn (state PaintableState) overflow_property_applies() bool { return state.overflow != none }
pub fn (state PaintableState) available_scrollbar_length(direction ScrollDirection) f64 { rect := state.absolute_padding_box_rect(); return if direction == .horizontal { rect.width } else { rect.height } }
pub fn (state PaintableState) scrollbar(direction ScrollDirection) ?ScrollbarData { return state.compute_scrollbar_data(direction) }
pub fn (state PaintableState) compute_scrollbar_data(direction ScrollDirection) ?ScrollbarData {
	metrics := state.chrome_metrics()
	return compute_scrollbar_data(ScrollbarGeometryInput{direction: direction, padding_rect: state.absolute_padding_box_rect(), scrollable_overflow: state.scrollable_overflow_rect(), metrics: metrics, chrome_mirrored: state.is_chrome_mirrored(), has_resizer: state.has_resizer()})
}
pub fn (state PaintableState) absolute_scrollbar_rect(direction ScrollDirection) Rect { return if data := state.compute_scrollbar_data(direction) { if data.gutter_rect.is_empty() { data.thumb_rect } else { data.gutter_rect } } else { Rect{} } }
pub fn (mut state PaintableState) ensure_scrollbar(direction ScrollDirection) ?ScrollbarData { return state.compute_scrollbar_data(direction) }
pub fn (state PaintableState) has_resizer() bool { return state.kind.contains('resizable') }
pub fn (state PaintableState) is_chrome_mirrored() bool { return state.kind.contains('rtl') }
pub fn (state PaintableState) resize_handle() ResizeHandle { return state.resize }
pub fn (mut state PaintableState) ensure_resize_handle() &ResizeHandle { return &state.resize }
pub fn (state PaintableState) resizer_contains(point Point) bool { return state.absolute_resizer_rect().contains(point) }
pub fn (state PaintableState) physical_resize_axes() PhysicalResizeAxes { return PhysicalResizeAxes{horizontal: state.has_resizer(), vertical: state.has_resizer()} }
pub fn (state PaintableState) chrome_metrics() ChromeMetrics { return new_chrome_metrics(1) or { ChromeMetrics{} } }
pub fn (mut state PaintableState) handle_mousewheel(delta Point) bool { return state.set_scroll_offset(Point{state.scroll_offset().x + delta.x, state.scroll_offset().y + delta.y}) }
pub fn (state PaintableState) scroll_offset() Point { return state.scroll_state.cumulative_offset(state.own_scroll_index) }
pub fn (mut state PaintableState) set_scroll_offset(offset Point) bool {
	if state.own_scroll_index <= 0 || state.own_scroll_index >= state.scroll_state.frames.len { return false }
	if state.scroll_state.frames[state.own_scroll_index].own_offset == offset { return false }
	state.scroll_state.frames[state.own_scroll_index].own_offset = offset
	return true
}
pub fn (mut state PaintableState) scroll_ancestor_to_offset_into_view(offset Point) bool { return state.set_scroll_offset(offset) }
pub fn (state PaintableState) nearest_scroll_frame_index() int { return if state.own_scroll_index > 0 { state.own_scroll_index } else { state.enclosing_scroll_index } }
pub fn (state PaintableState) nearest_scrollable_ancestor() int { return state.scroll_state.nearest_scrolling_ancestor(state.nearest_scroll_frame_index()) }
pub fn (mut state PaintableState) set_enclosing_scroll_frame_index(index int) { state.enclosing_scroll_index = index }
pub fn (mut state PaintableState) set_own_scroll_frame_index(index int) { state.own_scroll_index = index }
pub fn (state PaintableState) enclosing_scroll_frame_index() int { return state.enclosing_scroll_index }
pub fn (state PaintableState) own_scroll_frame_index() int { return state.own_scroll_index }

pub fn (state PaintableState) has_css_transform() bool { return state.css_transform != Affine{} }
pub fn (state PaintableState) has_non_invertible_css_transform() bool { return state.non_invertible_transform }
pub fn (mut state PaintableState) set_has_non_invertible_css_transform(value bool) { state.non_invertible_transform = value }
pub fn (state PaintableState) transform_point_to_local(point Point) ?Point { return state.inverse_transform_point(point) }
pub fn (state PaintableState) transform_point_to_local_for_descendants(point Point) ?Point { return state.inverse_transform_point(point) }
pub fn (state PaintableState) inverse_transform_point(point Point) ?Point { inverse := state.css_transform.inverse() or { return none }; return inverse.map_point(point.subtract(state.absolute_position())) }
pub fn (state PaintableState) transform_to_local_coordinates(point Point) ?Point { return state.inverse_transform_point(point) }
pub fn (state PaintableState) transform_rect_to_viewport(rect Rect) Rect { return state.css_transform.map_rect(rect).translated(state.absolute_position()) }
pub fn (state PaintableState) transform_reference_box() Rect { return state.absolute_border_box_rect() }
pub fn (mut state PaintableState) set_accumulated_visual_context(index int) { state.visual_context_index = index }
pub fn (state PaintableState) accumulated_visual_context_index() int { return state.visual_context_index }
pub fn (mut state PaintableState) set_accumulated_visual_context_for_descendants(index int) { state.descendant_visual_context_index = index }
pub fn (state PaintableState) accumulated_visual_context_for_descendants_index() int { return state.descendant_visual_context_index }

pub fn (state PaintableState) border_radii_data() BorderRadiiData { return state.radii }
pub fn (state PaintableState) normalized_border_radii_data() BorderRadiiData { return normalize_border_radii_data(state.radii, state.absolute_border_box_rect().size()) }
pub fn (state PaintableState) outline_data() BorderData { return BorderData{line_style: .none} }
pub fn (state PaintableState) outline_offset() f64 { return 0 }
pub fn (mut state PaintableState) set_override_borders_data(value BordersData) { state.override_borders = value }
pub fn (state PaintableState) override_borders_data() ?BordersData { return state.override_borders }
pub fn (mut state PaintableState) remove_element_kind_from_borders_data() { state.override_borders = none }
pub fn (mut state PaintableState) set_table_cell_coordinates(row int, column int) { state.table_row = row; state.table_column = column }
pub fn (state PaintableState) table_cell_coordinates() (int, int) { return state.table_row, state.table_column }
pub fn (mut state PaintableState) set_filter(value ?GfxFilter) { state.filter_value = value }
pub fn (state PaintableState) filter() ?GfxFilter { return state.filter_value }
pub fn (state PaintableState) sticky_insets() StickyInsets { return state.sticky }
pub fn (mut state PaintableState) set_sticky_insets(value StickyInsets) { state.sticky = value }
pub fn (mut state PaintableState) set_used_values_for_grid_template_columns(values []f64) { state.grid_columns = values.clone() }
pub fn (state PaintableState) used_values_for_grid_template_columns() []f64 { return state.grid_columns.clone() }
pub fn (mut state PaintableState) set_used_values_for_grid_template_rows(values []f64) { state.grid_rows = values.clone() }
pub fn (state PaintableState) used_values_for_grid_template_rows() []f64 { return state.grid_rows.clone() }
pub fn (mut state PaintableState) set_needs_repaint(value bool) { state.needs_repaint = value }

pub fn (state PaintableState) has_cached_commands(phase PaintPhase) bool { return phase in state.commands_by_phase }
pub fn (state PaintableState) cached_commands(phase PaintPhase) []DisplayListCommand { return state.commands_by_phase[phase].clone() }
pub fn (mut state PaintableState) set_cached_commands(phase PaintPhase, commands []DisplayListCommand) { state.commands_by_phase[phase] = commands.clone() }
pub fn (mut state PaintableState) reset_for_relayout() { state.fragments_value.clear(); state.commands_by_phase.clear(); state.visual_context_index = 0; state.descendant_visual_context_index = 0 }

pub fn (state PaintableState) hit_test(point Point) ?HitTestResult {
	if !state.visible_for_hit_testing() { return none }
	for child in state.children.reverse() { if hit := child.hit_test(point) { return hit } }
	for fragment in state.fragments_value.reverse() { if fragment.absolute_rect().contains(point) { return HitTestResult{paintable_id: state.id, index_in_node: fragment.index_in_node_for_point(point), internal_position: .inside} } }
	if state.absolute_border_box_rect().contains(point) { return HitTestResult{paintable_id: state.id, internal_position: .inside} }
	return none
}
pub fn (state PaintableState) hit_test_children(point Point) ?HitTestResult { for child in state.children.reverse() { if hit := child.hit_test(point) { return hit } }; return none }
pub fn (state PaintableState) hit_test_chrome(point Point) ?HitTestResult { return if state.resizer_contains(point) { HitTestResult{paintable_id: state.id, chrome_widget_id: 'resizer', internal_position: .inside} } else { none } }
pub fn (state PaintableState) hit_test_continuation(point Point) ?HitTestResult { return state.hit_test(point) }
pub fn (state PaintableState) hit_test_fragments(point Point) ?HitTestResult { for fragment in state.fragments_value.reverse() { if fragment.absolute_rect().contains(point) { return HitTestResult{paintable_id: state.id, index_in_node: fragment.index_in_node_for_point(point), internal_position: .inside} } }; return none }

pub fn (state PaintableState) paint(phase PaintPhase, converter DevicePixelConverter, color Color) []DisplayListCommand {
	if !state.visible { return [] }
	if state.kind == 'svg-path' { return SVGPaintable{id: state.id, kind: .path, absolute_rect: state.absolute_rect(), transform: state.css_transform, path: state.computed_path_value}.paint_commands(phase, converter, color) }
	if commands := state.commands_by_phase[phase] { return commands.clone() }
	return []
}
pub fn (state PaintableState) paint_background(converter DevicePixelConverter, color Color) []DisplayListCommand { rect := converter.enclosing_device_rect(state.absolute_border_box_rect()); return if rect.is_empty() || color.a == 0 { [] } else { [DisplayListCommand(FillRect{rect, color})] } }
pub fn (state PaintableState) paint_border(converter DevicePixelConverter) []DisplayListCommand { return border_commands(converter.enclosing_device_rect(state.absolute_border_box_rect()), state.radii.as_corners(converter), BordersData{}.to_device_pixels(converter)) }
pub fn (state PaintableState) paint_box_shadow(converter DevicePixelConverter, shadows []ShadowData) []ResolvedShadow { return resolve_box_shadows(state.absolute_border_box_rect(), state.radii, shadows, converter) }
pub fn (state PaintableState) paint_backdrop_filter() ?ApplyBackdropFilter { return if filter := state.filter_value { ApplyBackdropFilter{backdrop_region: IntRect{int(state.absolute_x()), int(state.absolute_y()), int(state.content_width()), int(state.content_height())}, filter: filter} } else { none } }
pub fn (state PaintableState) paint_inspector_overlay() Rect { return state.absolute_border_box_rect() }
pub fn (state PaintableState) paint_inspector_overlay_internal() Rect { return state.paint_inspector_overlay() }
pub fn (state PaintableState) paint_text_fragment_debug_highlight(index int) Rect { return if index >= 0 && index < state.fragments_value.len { state.fragments_value[index].absolute_rect() } else { Rect{} } }
pub fn (state PaintableState) paint_cursor(index int) Rect { return if index >= 0 && index < state.fragments_value.len { state.fragments_value[index].range_rect(.start_and_end, 0, 0) } else { Rect{} } }
pub fn (state PaintableState) paint_svg_box() Rect { return state.absolute_border_box_rect() }
pub fn (state PaintableState) paint_descendants(phase PaintPhase, converter DevicePixelConverter, color Color) []DisplayListCommand { mut result := []DisplayListCommand{}; for child in state.children { result << child.paint(phase, converter, color); result << child.paint_descendants(phase, converter, color) }; return result }
pub fn (state PaintableState) should_anti_alias() bool { return true }

pub fn (state PaintableState) fragments() []PaintableFragment { return state.fragments_value.clone() }
pub fn (mut state PaintableState) add_fragment(fragment PaintableFragment) { state.fragments_value << fragment }
pub fn (state PaintableState) fragment_at_position(point Point) ?PaintableFragment { for fragment in state.fragments_value { if fragment.absolute_rect().contains(point) { return fragment } }; return none }
pub fn (state PaintableState) line_index(fragment_index int) int { return if fragment_index < 0 { 0 } else { fragment_index } }
pub fn (state PaintableState) compute_render_spans() []Rect { return state.fragments_value.map(it.absolute_rect()) }
pub fn (state PaintableState) resolve_text_fragment_properties(index int) PaintableFragment { return if index >= 0 && index < state.fragments_value.len { state.fragments_value[index] } else { PaintableFragment{} } }
pub fn (state PaintableState) paint_text_fragment(index int) Rect { return state.paint_text_fragment_debug_highlight(index) }

pub fn (mut state PaintableState) build_stacking_context_tree() StackingContext { mut context := StackingContext{paintable_id: state.id}; for child in state.children { context.children << StackingContext{paintable_id: child.id} }; context.sort(); return context }
pub fn (state PaintableState) paint_all_phases(converter DevicePixelConverter, color Color) []DisplayListCommand { mut result := []DisplayListCommand{}; for phase in [PaintPhase.background, .border, .table_collapsed_border, .foreground, .outline, .overlay] { result << state.paint(phase, converter, color) }; return result }
pub fn (mut state PaintableState) assign_scroll_frames() { if state.own_scroll_index == 0 { state.own_scroll_index = state.scroll_state.create_scroll_frame(state.id, state.enclosing_scroll_index) } }
pub fn (mut state PaintableState) assign_accumulated_visual_contexts() { state.visual_context_index = 0; state.descendant_visual_context_index = 0 }
pub fn (state PaintableState) selection() SelectionState { return state.selection }
pub fn (state PaintableState) scroll_state_snapshot() ScrollStateSnapshot { return state.scroll_state.snapshot(1) }
pub fn (mut state PaintableState) set_paintable_boxes_with_auto_content_visibility(ids []string) { state.paintable_boxes_with_auto_visibility = ids.clone() }
pub fn (state PaintableState) paintable_boxes_with_auto_content_visibility() []string { return state.paintable_boxes_with_auto_visibility.clone() }
pub fn (state PaintableState) visual_context_tree() AccumulatedVisualContextTree { return state.visual_tree }

pub fn (mut state PaintableState) set_computed_transforms(value ComputedTransforms) { state.computed_transform_value = value }
pub fn (state PaintableState) computed_transforms() ComputedTransforms { return state.computed_transform_value }
pub fn (mut state PaintableState) set_computed_path(path []Point) { state.computed_path_value = path.clone() }
pub fn (state PaintableState) computed_path() []Point { return state.computed_path_value.clone() }
pub fn (state PaintableState) effective_border_top() f64 { return state.metrics.border.top }
pub fn (state PaintableState) visual_border_box_rect() Rect { return state.absolute_border_box_rect() }

pub struct ComputedTransforms {
pub:
	svg_to_viewbox_transform Affine = Affine{}
	svg_transform Affine = Affine{}
	svg_to_device_pixels_transform Affine = Affine{}
}

pub fn (value ComputedTransforms) svg_to_viewbox_transform() Affine { return value.svg_to_viewbox_transform }
pub fn (value ComputedTransforms) svg_transform() Affine { return value.svg_transform }
pub fn (value ComputedTransforms) svg_to_device_pixels_transform() Affine { return value.svg_to_device_pixels_transform }

pub fn normalize_border_radii_data(radii BorderRadiiData, size Size) BorderRadiiData {
	mut scale := 1.0
	pairs := [radii.top_left.horizontal + radii.top_right.horizontal, radii.bottom_left.horizontal + radii.bottom_right.horizontal, radii.top_left.vertical + radii.bottom_left.vertical, radii.top_right.vertical + radii.bottom_right.vertical]
	limits := [size.width, size.width, size.height, size.height]
	for index, pair in pairs { if pair > 0 { scale = math.min(scale, limits[index] / pair) } }
	if scale >= 1 { return radii }
	return BorderRadiiData{
		top_left: BorderRadiusData{radii.top_left.horizontal * scale, radii.top_left.vertical * scale}
		top_right: BorderRadiusData{radii.top_right.horizontal * scale, radii.top_right.vertical * scale}
		bottom_right: BorderRadiusData{radii.bottom_right.horizontal * scale, radii.bottom_right.vertical * scale}
		bottom_left: BorderRadiusData{radii.bottom_left.horizontal * scale, radii.bottom_left.vertical * scale}
	}
}
