module painting

import math

// Renderer-independent equivalents of Painting's free algorithms. Native Skia
// conversions return stable descriptive values or the underlying affine data;
// the geometry and ordering decisions themselves are executed here.
pub fn add_spread_distance_to_border_radius(radius int, distance int) int {
	mut value := CornerRadii{top_left: CornerRadius{radius, radius}}
	value.adjust_for_spread_distance(distance)
	return value.top_left.horizontal
}

pub fn border_color(style LineStyle, color Color, edge BorderEdge) Color {
	if style !in [.inset, .outset, .groove, .ridge] { return color }
	light := light_color_for_inset_and_outset(color)
	dark := dark_color_for_inset_and_outset(color)
	return match style {
		.inset { if edge in [.top, .left] { dark } else { light } }
		.outset { if edge in [.top, .left] { light } else { dark } }
		.groove { if edge in [.top, .left] { dark } else { light } }
		.ridge { if edge in [.top, .left] { light } else { dark } }
		else { color }
	}
}

pub fn light_color_for_inset_and_outset(color Color) Color { return interpolate_color(color, Color{255, 255, 255, color.a}, 0.33) }
pub fn dark_color_for_inset_and_outset(color Color) Color { return interpolate_color(color, Color{0, 0, 0, color.a}, 0.33) }
pub fn borders_data_for_outline(border BorderData) BordersData { return BordersData{border, border, border, border} }
pub fn check_mark_path(rect IntRect) []IntPoint { return [IntPoint{rect.x + rect.width / 5, rect.y + rect.height / 2}, IntPoint{rect.x + rect.width * 2 / 5, rect.bottom() - rect.height / 5}, IntPoint{rect.right() - rect.width / 5, rect.y + rect.height / 5}] }
pub fn build_triangle_wave_path(rect Rect, wavelength f64) []Point {
	if wavelength <= 0 || rect.is_empty() { return [] }
	mut points := []Point{}
	mut x := rect.x
	mut up := true
	for x <= rect.right() { points << Point{x, if up { rect.y } else { rect.bottom() }}; x += wavelength / 2; up = !up }
	return points
}

pub fn command_bounding_rectangle(command DisplayListCommand) ?IntRect { return command_bounding_rect(command) }
pub fn command_nesting_level_change(command DisplayListCommand) int { return command_nesting_change(command) }
pub fn mix_blend_mode_to_compositing_and_blending_operator(mode BlendMode) CompositingAndBlendingOperator { return mix_blend_mode_to_operator(mode) }
pub fn replace_transition_hints_with_normal_color_stops(stops []ColorStop) []ColorStop { return replace_transition_hints(stops) }
pub fn expand_color_stops_for_painting(stops []ColorStop, repeat_length ?f64) []ColorStop { expanded := if length := repeat_length { expand_repeat_length(stops, length) } else { stops.clone() }; return replace_transition_hints(expanded) }

pub fn resolve_color_stop_positions(stops []ColorStop, repeating bool) ColorStopData {
	if stops.len == 0 { return ColorStopData{repeating: repeating} }
	mut result := stops.clone()
	result[0].position = math.max(0.0, result[0].position)
	result[result.len - 1].position = math.max(result[0].position, result[result.len - 1].position)
	mut previous := result[0].position
	for index := 1; index < result.len; index++ { result[index].position = math.max(previous, result[index].position); previous = result[index].position }
	repeat_length := if repeating { ?f64(result[result.len - 1].position - result[0].position) } else { none }
	return ColorStopData{list: result, repeat_length: repeat_length, repeating: repeating}
}

pub fn resolve_linear_gradient_data(angle f64, stops []ColorStop, method ColorInterpolationMethod, repeating bool) LinearGradientData { return LinearGradientData{gradient_angle: angle, color_stops: resolve_color_stop_positions(stops, repeating), interpolation_method: method} }
pub fn resolve_conic_gradient_data(angle f64, stops []ColorStop, method ColorInterpolationMethod, repeating bool) ConicGradientData { return ConicGradientData{start_angle: angle, color_stops: resolve_color_stop_positions(stops, repeating), interpolation_method: method} }
pub fn resolve_radial_gradient_data(stops []ColorStop, method ColorInterpolationMethod, repeating bool) RadialGradientData { return RadialGradientData{color_stops: resolve_color_stop_positions(stops, repeating), interpolation_method: method} }
pub fn resolve_css_filter(operations []ResolvedFilterOperation, svg ?GfxFilter) ResolvedCSSFilter { return ResolvedCSSFilter{operations: operations, svg_filter: svg} }
pub fn shadow_placement_from_css(inset bool) ShadowPlacement { return if inset { .inner } else { .outer } }

pub fn compute_input_colors(accent Color, base Color, background Color, enabled bool) InputColors {
	gray := interpolate_color(base, background, 0.5)
	return InputColors{accent: if enabled { accent } else { gray }, base: base, gray: gray, mid_gray: interpolate_color(gray, background, 0.5), dark_gray: interpolate_color(gray, Color{a: 255}, 0.5), background: background}
}

pub fn compute_text_clip_paths(fragments []PaintableFragment) []Rect { return fragments.map(it.absolute_rect()) }
pub fn get_box(kind BackgroundBoxKind, border_box BackgroundBox, metrics BoxModelMetrics) BackgroundBox { return background_box_for_kind(kind, border_box, metrics) }
pub fn resolve_background_layers(color_box BackgroundBox, layers []ResolvedBackgroundLayer, color Color) ResolvedBackground { return ResolvedBackground{color_box: color_box, layers: layers, background_rect: color_box.rect, color: color, needs_text_clip: layers.any(it.clip == .text)} }
pub fn paint_background(background ResolvedBackground, converter DevicePixelConverter) []DisplayListCommand {
	mut commands := []DisplayListCommand{}
	if background.color.a > 0 { commands << FillRect{converter.enclosing_device_rect(background.color_box.rect), background.color} }
	for layer in background.layers { for tile in background_tiles(layer, Point{}, Point{}, background.background_rect) { commands << DrawScaledBitmap{destination: converter.enclosing_device_rect(tile), clip_rect: converter.enclosing_device_rect(background.background_rect), bitmap_id: layer.image_id, scaling: .bilinear} } }
	return commands
}
pub fn paint_border(rect IntRect, radii CornerRadii, borders DeviceBordersData) []DisplayListCommand { return border_commands(rect, radii, borders) }
pub fn paint_all_borders(rect IntRect, radii CornerRadii, borders DeviceBordersData) []DisplayListCommand { return border_commands(rect, radii, borders) }
pub fn paint_box_shadow(rect Rect, radii BorderRadiiData, shadows []ShadowData, converter DevicePixelConverter) []ResolvedShadow { return resolve_box_shadows(rect, radii, shadows, converter) }

pub struct TableCellEdge {
pub:
	rect IntRect
	border ConflictingBorder
	horizontal bool
	row ?int
	column ?int
}

pub fn collect_cell_boxes(root PaintableState) []Rect { mut result := []Rect{}; for child in root.children { if child.kind == 'table-cell' { result << child.absolute_border_box_rect() } else { result << collect_cell_boxes(child) } }; return result }
pub fn row_index_for_element_kind(index int, kind ConflictingElementKind) ?int { return if kind in [.cell, .row, .row_group] { index } else { none } }
pub fn column_index_for_element_kind(index int, kind ConflictingElementKind) ?int { return if kind in [.cell, .column, .column_group] { index } else { none } }
pub fn half_ceil(width int) int { return int(math.ceil(f64(width) / 2.0)) }
pub fn half_floor(width int) int { return int(math.floor(f64(width) / 2.0)) }
pub fn make_right_cell_edge(rect IntRect, border ConflictingBorder, row int, column int) TableCellEdge { return TableCellEdge{rect: IntRect{rect.right() - half_ceil(border.border.width), rect.y, border.border.width, rect.height}, border: border, horizontal: false, row: row, column: column} }
pub fn make_down_cell_edge(rect IntRect, border ConflictingBorder, row int, column int) TableCellEdge { return TableCellEdge{rect: IntRect{rect.x, rect.bottom() - half_ceil(border.border.width), rect.width, border.border.width}, border: border, horizontal: true, row: row, column: column} }
pub fn make_first_row_top_cell_edge(rect IntRect, border ConflictingBorder, column int) TableCellEdge { return TableCellEdge{rect: IntRect{rect.x, rect.y - half_floor(border.border.width), rect.width, border.border.width}, border: border, horizontal: true, row: 0, column: column} }
pub fn make_last_row_bottom_cell_edge(rect IntRect, border ConflictingBorder, row int, column int) TableCellEdge { return make_down_cell_edge(rect, border, row, column) }
pub fn make_first_column_left_cell_edge(rect IntRect, border ConflictingBorder, row int) TableCellEdge { return TableCellEdge{rect: IntRect{rect.x - half_floor(border.border.width), rect.y, border.border.width, rect.height}, border: border, horizontal: false, row: row, column: 0} }
pub fn make_last_column_right_cell_edge(rect IntRect, border ConflictingBorder, row int, column int) TableCellEdge { return make_right_cell_edge(rect, border, row, column) }
pub fn css_border_data_from_device_border_data(border DeviceBorderData, converter DevicePixelConverter) BorderData { return BorderData{color: border.color, line_style: border.line_style, width: converter.scale_to_css_pixels(border.width)} }
pub fn device_border_data_from_css_border_data(border BorderData, converter DevicePixelConverter) DeviceBorderData { return DeviceBorderData{color: border.color, line_style: border.line_style, width: converter.enclosing_device_pixels(border.width)} }
pub fn snap_cells_to_device_coordinates(cells []Rect, converter DevicePixelConverter) []IntRect { return cells.map(converter.enclosing_device_rect(it)) }
pub fn paint_collected_edges(edges []TableCellEdge) []DisplayListCommand { mut commands := []DisplayListCommand{}; for edge in edges { commands << FillRect{edge.rect, edge.border.border.color} }; return commands }
pub fn paint_separate_cell_borders(rect IntRect, borders DeviceBordersData) []DisplayListCommand { return border_commands(rect, CornerRadii{}, borders) }
pub fn paint_table_borders(edges []TableCellEdge) []DisplayListCommand { return paint_collected_edges(edges) }

pub fn effective_css_clip_rect(rect Rect, clip ?Rect) Rect { return if value := clip { rect.intersection(value) } else { rect } }
pub fn scale_matrix_for_device_pixels(matrix Affine, scale f64) Affine { return Affine{matrix.a * scale, matrix.b * scale, matrix.c * scale, matrix.d * scale, matrix.e * scale, matrix.f * scale} }
pub fn compute_transform(transform Affine, origin Point) TransformVisualData { return TransformVisualData{origin: origin, matrix: transform} }
pub fn compute_perspective_matrix(matrix Affine) PerspectiveVisualData { return PerspectiveVisualData{matrix: matrix} }
pub fn compute_clip_data(rect IntRect, radii CornerRadii) ClipVisualData { return ClipVisualData{rect: rect, corner_radii: radii} }
pub fn set_paint_viewport_scrollbars(mut state PaintableState, horizontal bool, vertical bool) { if horizontal || vertical { state.kind += '-scrollbars' } }

pub fn first_child_layout_node_of_type(root PaintableState, kind string) ?string { for child in root.children { if child.kind == kind { return child.layout_id } }; return none }
pub fn get_mask_box(state PaintableState) Rect { return state.get_mask_area() or { Rect{} } }
pub fn get_clip_box(state PaintableState) Rect { return state.get_clip_area() or { Rect{} } }
pub fn mask_type_to_gfx_mask_kind(kind SVGMaskType) MaskKind { return if kind == .luminance { .luminance } else { .alpha } }
pub fn paint_mask_or_clip_to_display_list(content []SVGPaintable, area Rect, converter DevicePixelConverter, mask bool) DisplayList { return if mask { calculate_svg_mask_display_list(SVGMaskDefinition{area: area, content: content}, converter) } else { calculate_svg_clip_display_list(SVGClipDefinition{area: area, content: content}, converter) } }

pub fn to_gfx_winding_rule(rule WindingRule) WindingRule { return rule }
pub fn to_paint_phase(phase int) PaintPhase { return match phase { 0 { .background } 1 { .border } 2 { .table_collapsed_border } 3 { .foreground } 4 { .outline } else { .overlay } } }
pub fn paint_node(node PaintableState, phase PaintPhase, converter DevicePixelConverter, color Color) []DisplayListCommand { return node.paint(phase, converter, color) }
pub fn paint_text_decoration(fragment PaintableFragment, color Color, converter DevicePixelConverter) []DisplayListCommand { rect := converter.enclosing_device_rect(fragment.absolute_rect()); thickness := math.max(1, converter.rounded_device_pixels(fragment.text_decoration_thickness())); return [DisplayListCommand(FillRect{IntRect{rect.x, rect.bottom() - thickness, rect.width, thickness}, color})] }

pub fn to_skia_interpolation(method ColorInterpolationMethod) string { return '${method}' }
pub fn to_skia_matrix(matrix Affine) Affine { return matrix }
pub fn to_skia_matrix4x4(matrix Affine) []f64 { return [matrix.a, matrix.c, 0, matrix.e, matrix.b, matrix.d, 0, matrix.f, 0, 0, 1, 0, 0, 0, 0, 1] }
pub fn to_skia_rrect(rect IntRect, radii CornerRadii) string { return '${rect}:${radii}' }
pub fn to_skia_tile_mode(method SVGSpreadMethod) string { return match method { .pad { 'clamp' } .repeat { 'repeat' } .reflect { 'mirror' } } }
pub fn gradient_paint_style_to_skia_paint(style SVGPaintStyle) string { return match style { SVGLinearGradientPaintStyle { 'linear-gradient:${style.gradient.color_stops.len}' } SVGRadialGradientPaintStyle { 'radial-gradient:${style.gradient.color_stops.len}' } SVGPatternPaintStyle { 'pattern:${style.tile_display_list_id}' } } }
