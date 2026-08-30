module painting

import math

pub fn (fragment PaintableFragment) layout_node() string { return fragment.layout_node_id }
pub fn (fragment PaintableFragment) paintable() string { return fragment.paintable_id }
pub fn (fragment PaintableFragment) start_offset() int { return fragment.start_offset }
pub fn (fragment PaintableFragment) length_in_code_units() int { return fragment.length_in_code_units }
pub fn (fragment PaintableFragment) baseline() f64 { return fragment.baseline }
pub fn (fragment PaintableFragment) offset() Point { return fragment.offset }
pub fn (mut fragment PaintableFragment) set_offset(offset Point) { fragment.offset = offset }
pub fn (fragment PaintableFragment) size() Size { return fragment.size }
pub fn (fragment PaintableFragment) width() f64 { return fragment.size.width }
pub fn (fragment PaintableFragment) height() f64 { return fragment.size.height }
pub fn (fragment PaintableFragment) shadows() []ShadowData { return fragment.shadow_values.clone() }
pub fn (mut fragment PaintableFragment) set_shadows(shadows []ShadowData) { fragment.shadow_values = shadows.clone() }
pub fn (fragment PaintableFragment) glyph_run() []GlyphMetric { return fragment.glyphs.clone() }
pub fn (fragment PaintableFragment) text_decoration_thickness() f64 { return fragment.decoration_thickness }
pub fn (mut fragment PaintableFragment) set_text_decoration_thickness(value f64) { fragment.decoration_thickness = value }
pub fn (fragment PaintableFragment) has_trailing_whitespace() bool { return fragment.has_trailing_whitespace }
pub fn (fragment PaintableFragment) orientation() Orientation { return fragment.orientation }
pub fn (fragment PaintableFragment) text() string { return fragment.text_value }
pub fn (fragment PaintableFragment) selection_range_for_text_control(state SelectionState, start int, end int) ?SelectionOffsets { return fragment.compute_selection_offsets(state, start, end) }
pub fn (fragment PaintableFragment) selection_rect(state SelectionState, start int, end int) Rect { return fragment.range_rect(state, start, end) }

pub fn (radii CornerRadii) adjust_corners_for_spread_distance(distance int) CornerRadii { mut result := radii; result.adjust_for_spread_distance(distance); return result }
pub fn (radius CornerRadius) bool() bool { return radius.is_present() }
pub fn (radius BorderRadiusData) bool() bool { return radius.is_present() }

pub fn SVGGradientPaintStyle.create() SVGGradientPaintStyle { return SVGGradientPaintStyle{} }
pub fn (style SVGGradientPaintStyle) gradient_transform() ?Affine { return style.gradient_transform }
pub fn (mut style SVGGradientPaintStyle) set_gradient_transform(value ?Affine) { style.gradient_transform = value }
pub fn (style SVGGradientPaintStyle) spread_method() SVGSpreadMethod { return style.spread_method }
pub fn (mut style SVGGradientPaintStyle) set_spread_method(value SVGSpreadMethod) { style.spread_method = value }
pub fn (style SVGGradientPaintStyle) color_stops() []ColorStop { return style.color_stops.clone() }
pub fn (style SVGGradientPaintStyle) repeat_length() ?f64 { return style.repeat_length }
pub fn (style SVGGradientPaintStyle) color_space() ColorInterpolationMethod { return style.color_space }
pub fn (mut style SVGGradientPaintStyle) set_color_space(value ColorInterpolationMethod) { style.color_space = value }

pub fn SVGLinearGradientPaintStyle.create(start Point, end Point) SVGLinearGradientPaintStyle { return SVGLinearGradientPaintStyle{start_point: start, end_point: end} }
pub fn (style SVGLinearGradientPaintStyle) start_point() Point { return style.start_point }
pub fn (style SVGLinearGradientPaintStyle) end_point() Point { return style.end_point }
pub fn (mut style SVGLinearGradientPaintStyle) set_start_point(value Point) { style.start_point = value }
pub fn (mut style SVGLinearGradientPaintStyle) set_end_point(value Point) { style.end_point = value }

pub fn SVGRadialGradientPaintStyle.create(start Point, start_radius f64, end Point, end_radius f64) SVGRadialGradientPaintStyle { return SVGRadialGradientPaintStyle{start_center: start, start_radius: start_radius, end_center: end, end_radius: end_radius} }
pub fn (style SVGRadialGradientPaintStyle) start_center() Point { return style.start_center }
pub fn (style SVGRadialGradientPaintStyle) start_radius() f64 { return style.start_radius }
pub fn (style SVGRadialGradientPaintStyle) end_center() Point { return style.end_center }
pub fn (style SVGRadialGradientPaintStyle) end_radius() f64 { return style.end_radius }
pub fn (mut style SVGRadialGradientPaintStyle) set_start_center(value Point) { style.start_center = value }
pub fn (mut style SVGRadialGradientPaintStyle) set_start_radius(value f64) { style.start_radius = math.max(0.0, value) }
pub fn (mut style SVGRadialGradientPaintStyle) set_end_center(value Point) { style.end_center = value }
pub fn (mut style SVGRadialGradientPaintStyle) set_end_radius(value f64) { style.end_radius = math.max(0.0, value) }

pub fn SVGPatternPaintStyle.create(id string, rect Rect, transform ?Affine) SVGPatternPaintStyle { return SVGPatternPaintStyle{id, rect, transform} }
pub fn (style SVGPatternPaintStyle) tile_display_list() string { return style.tile_display_list_id }
pub fn (style SVGPatternPaintStyle) tile_rect() Rect { return style.tile_rect }
pub fn (style SVGPatternPaintStyle) pattern_transform() ?Affine { return style.pattern_transform }

pub fn (frame ScrollFrame) paintable_box() string { return frame.paintable_id }
pub fn (frame ScrollFrame) is_sticky() bool { return frame.is_sticky }
pub fn (frame ScrollFrame) own_offset() Point { return frame.own_offset }
pub fn (mut frame ScrollFrame) set_own_offset(offset Point) { frame.own_offset = offset }
pub fn (frame ScrollFrame) parent_index() int { return frame.parent_index }
pub fn (mut frame ScrollFrame) set_sticky_constraints(value StickyConstraints) { frame.sticky_constraints = value }
pub fn (frame ScrollFrame) has_sticky_constraints() bool { return frame.sticky_constraints != none }
pub fn (frame ScrollFrame) sticky_constraints() ?StickyConstraints { return frame.sticky_constraints }

pub fn ScrollState.create() ScrollState { return ScrollState{} }
pub fn (mut state ScrollState) create_scroll_frame_for(id string, parent int) int { return state.create_scroll_frame(id, parent) }
pub fn (mut state ScrollState) create_sticky_frame_for(id string, parent int) int { return state.create_sticky_frame(id, parent) }
pub fn (state ScrollState) frame_at(index int) ?ScrollFrame { return if index >= 0 && index < state.frames.len { state.frames[index] } else { none } }
pub fn (state ScrollState) for_each_scroll_frame() []ScrollFrame { return state.scrolling_frame_indices().map(state.frames[it]) }
pub fn (state ScrollState) for_each_sticky_frame() []ScrollFrame { return state.sticky_frame_indices().map(state.frames[it]) }
pub fn ScrollStateSnapshot.create(state ScrollState, device_scale f64) ScrollStateSnapshot { return state.snapshot(device_scale) }

pub struct Scrollbar {
pub mut:
	direction_value ScrollDirection
	geometry ScrollbarData
	enlarged bool
	pointer_grab ?f64
	scroll_fraction f64
}

pub fn Scrollbar.create(direction ScrollDirection, geometry ScrollbarData) Scrollbar { return Scrollbar{direction_value: direction, geometry: geometry} }
pub fn (bar Scrollbar) direction() ScrollDirection { return bar.direction_value }
pub fn (bar Scrollbar) is_enlarged() bool { return bar.enlarged }
pub fn (bar Scrollbar) contains(point Point) bool { return bar.geometry.thumb_rect.contains(point) || bar.geometry.gutter_rect.contains(point) }
pub fn (bar Scrollbar) cursor() ResizeCursor { return if bar.direction_value == .horizontal { .ew_resize } else { .ns_resize } }
pub fn (mut bar Scrollbar) mouse_enter() { bar.enlarged = true }
pub fn (mut bar Scrollbar) mouse_leave() { bar.enlarged = false; bar.pointer_grab = none }
pub fn (mut bar Scrollbar) mouse_move(position Point) f64 { return bar.scroll_to_mouse_position(position) }
pub fn (mut bar Scrollbar) mouse_up() { bar.pointer_grab = none }
pub fn (mut bar Scrollbar) scroll_to_mouse_position(position Point) f64 {
	is_horizontal := bar.direction_value == .horizontal
	gutter := if bar.geometry.gutter_rect.is_empty() { bar.geometry.thumb_rect } else { bar.geometry.gutter_rect }
	coordinate := if is_horizontal { position.x } else { position.y }
	start := if is_horizontal { gutter.x } else { gutter.y }
	length := if is_horizontal { gutter.width } else { gutter.height }
	thumb_length := if is_horizontal { bar.geometry.thumb_rect.width } else { bar.geometry.thumb_rect.height }
	fraction, grab := scrollbar_offset_for_pointer(coordinate, start, length, thumb_length, bar.pointer_grab)
	bar.pointer_grab = grab
	bar.scroll_fraction = fraction
	return fraction
}
pub fn (mut bar Scrollbar) handle_pointer_event(event_type string, point Point) MouseAction {
	if event_type == 'pointerdown' && bar.contains(point) { bar.scroll_to_mouse_position(point); return .capture_input }
	if event_type == 'pointermove' && bar.pointer_grab != none { bar.mouse_move(point); return .capture_input }
	if event_type == 'pointerup' { bar.mouse_up() }
	return .none
}

pub fn ResizeHandle.create() ResizeHandle { return ResizeHandle{} }
pub fn (handle ResizeHandle) contains(point Point) bool { return handle.is_resizing && point.x >= handle.origin.x && point.y >= handle.origin.y }
pub fn (handle ResizeHandle) cursor() ResizeCursor { return .se_resize }
pub fn (mut handle ResizeHandle) mouse_enter() { handle.last_point = handle.origin }
pub fn (mut handle ResizeHandle) mouse_leave() { if !handle.is_resizing { handle.last_point = Point{} } }

pub fn AccumulatedVisualContextTree.create() AccumulatedVisualContextTree { return new_accumulated_visual_context_tree() }
pub fn (tree AccumulatedVisualContextTree) build_ancestor_chain(index int) []int { return tree.ancestor_chain(index) }
pub fn (tree AccumulatedVisualContextTree) node_at(index int) ?AccumulatedVisualContextNode { return if index >= 0 && index < tree.nodes.len { tree.nodes[index] } else { none } }
pub fn (tree AccumulatedVisualContextTree) has_empty_effective_clip(index int) bool { return if index >= 0 && index < tree.nodes.len { tree.nodes[index].has_empty_effective_clip } else { true } }

pub fn (mut manager BackingStoreManager) restart_resize_timer() { manager.next_bitmap_id++ }
pub fn (mut manager BackingStoreManager) reallocate_backing_stores(size IntSize) bool { return manager.resize_if_needed(size, false, true, false) }
pub fn (mut manager BackingStoreManager) resize_backing_stores_if_needed(size IntSize, resizing bool) bool { return manager.resize_if_needed(size, resizing, true, false) }

pub fn (colors InputColors) background_color() Color { return colors.background }
pub fn (colors InputColors) border_color() Color { return colors.gray }
pub fn (colors InputColors) get_shade(enabled bool, active bool) Color { return if !enabled { colors.mid_gray } else if active { colors.dark_gray } else { colors.base } }

pub fn (mut player DisplayListPlayer) paint_style_to_skia_paint(style SVGPaintStyle) string { result := match style { SVGLinearGradientPaintStyle { 'linear-gradient' } SVGRadialGradientPaintStyle { 'radial-gradient' } SVGPatternPaintStyle { 'pattern' } }; player.record(result); return result }
pub fn (state PaintableState) is_paintable_box() bool { return true }
pub fn (shadow ShadowData) from_css() ShadowData { return shadow }

pub struct SVGMaskable {
pub:
	state PaintableState
}
pub fn (maskable SVGMaskable) get_svg_mask_area() ?Rect { return maskable.state.get_svg_mask_area() }
pub fn (maskable SVGMaskable) get_svg_clip_area() ?Rect { return maskable.state.get_svg_clip_area() }
pub fn (maskable SVGMaskable) get_svg_mask_type() SVGMaskType { return maskable.state.get_svg_mask_type() }
pub fn (maskable SVGMaskable) target_svg_transform() Affine { return maskable.state.target_svg_transform() }
pub fn (maskable SVGMaskable) calculate_svg_mask_display_list(converter DevicePixelConverter) DisplayList { return maskable.state.calculate_mask(converter) }
pub fn (maskable SVGMaskable) calculate_svg_clip_display_list(converter DevicePixelConverter) DisplayList { return maskable.state.calculate_clip(converter) }
