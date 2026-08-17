module painting

import math

pub enum BackgroundAttachment {
	fixed
	local
	scroll
}

pub enum BackgroundBoxKind {
	border_box
	padding_box
	content_box
	text
}

pub enum Repetition {
	repeat
	space
	round
	no_repeat
}

pub struct BackgroundBox {
pub mut:
	rect  Rect
	radii BorderRadiiData
}

pub fn (mut box BackgroundBox) shrink(top f64, right f64, bottom f64, left f64) {
	box.rect = box.rect.inflated(-top, -right, -bottom, -left)
	box.radii.shrink(top, right, bottom, left)
}

pub struct ResolvedBackgroundLayer {
pub:
	image_id                    string
	attachment                  BackgroundAttachment
	clip                        BackgroundBoxKind
	position_x                  f64
	position_y                  f64
	background_positioning_area Rect
	image_rect                  Rect
	repeat_x                    Repetition
	repeat_y                    Repetition
	blend_mode                  BlendMode
}

pub struct ResolvedBackground {
pub:
	color_box       BackgroundBox
	layers          []ResolvedBackgroundLayer
	needs_text_clip bool
	background_rect Rect
	color           Color
}

pub fn background_box_for_kind(kind BackgroundBoxKind, border_box BackgroundBox,
	metrics BoxModelMetrics) BackgroundBox {
	mut result := border_box
	match kind {
		.content_box {
			result.shrink(metrics.padding.top, metrics.padding.right, metrics.padding.bottom,
				metrics.padding.left)
			result.shrink(metrics.border.top, metrics.border.right, metrics.border.bottom,
				metrics.border.left)
		}
		.padding_box {
			result.shrink(metrics.border.top, metrics.border.right, metrics.border.bottom,
				metrics.border.left)
		}
		else {}
	}
	return result
}

fn repetition_step(mode Repetition, area_length f64, image_length f64) (bool, f64) {
	if image_length <= 0 {
		return false, 0
	}
	return match mode {
		.round {
			true, image_length
		}
		.repeat {
			true, image_length
		}
		.no_repeat {
			false, image_length
		}
		.space {
			whole_images := int(area_length / image_length)
			if whole_images <= 1 {
				false, image_length
			} else {
				space := math.mod(area_length, image_length)
				true, image_length + space / f64(whole_images - 1)
			}
		}
	}
}

// background_tiles resolves attachment, position and repetition into concrete
// destination rectangles. Clipping remains a display-list operation.
pub fn background_tiles(layer ResolvedBackgroundLayer, scroll_offset Point,
	viewport_offset Point, clip Rect) []Rect {
	mut area := layer.background_positioning_area
	match layer.attachment {
		.fixed { area = Rect{viewport_offset.x, viewport_offset.y, area.width, area.height} }
		.local { area = area.translated(scroll_offset.scale(-1)) }
		.scroll {}
	}
	base :=
		Rect{area.x + layer.position_x, area.y + layer.position_y, layer.image_rect.width, layer.image_rect.height}
	repeat_x, x_step := repetition_step(layer.repeat_x, area.width, base.width)
	repeat_y, y_step := repetition_step(layer.repeat_y, area.height, base.height)
	mut start_x := base.x
	mut start_y := base.y
	if repeat_x {
		for start_x > clip.left() {
			start_x -= x_step
		}
	}
	if repeat_y {
		for start_y > clip.top() {
			start_y -= y_step
		}
	}
	mut tiles := []Rect{}
	mut y := start_y
	for {
		mut x := start_x
		for {
			tile := Rect{x, y, base.width, base.height}
			if tile.intersects(clip) {
				tiles << tile
			}
			if !repeat_x || x + x_step >= clip.right() {
				break
			}
			x += x_step
		}
		if !repeat_y || y + y_step >= clip.bottom() {
			break
		}
		y += y_step
	}
	return tiles
}

pub fn border_commands(rect IntRect, radii CornerRadii, borders DeviceBordersData) []DisplayListCommand {
	mut commands := []DisplayListCommand{}
	if borders.top.width > 0 && borders.top.line_style != .none && borders.top.line_style != .hidden {
		commands << FillRect{IntRect{rect.x, rect.y, rect.width, borders.top.width}, borders.top.color}
	}
	if borders.right.width > 0 && borders.right.line_style != .none
		&& borders.right.line_style != .hidden {
		commands << FillRect{IntRect{rect.right() - borders.right.width, rect.y, borders.right.width, rect.height}, borders.right.color}
	}
	if borders.bottom.width > 0 && borders.bottom.line_style != .none
		&& borders.bottom.line_style != .hidden {
		commands << FillRect{IntRect{rect.x, rect.bottom() - borders.bottom.width, rect.width, borders.bottom.width}, borders.bottom.color}
	}
	if borders.left.width > 0 && borders.left.line_style != .none
		&& borders.left.line_style != .hidden {
		commands << FillRect{IntRect{rect.x, rect.y, borders.left.width, rect.height}, borders.left.color}
	}
	if radii.has_any_radius() && commands.len > 0 {
		commands.prepend(AddRoundedRectClip{radii, rect, .inside})
	}
	return commands
}

pub enum ConflictingElementKind {
	cell
	row
	row_group
	column
	column_group
	table
}

pub struct ConflictingBorder {
pub:
	border       DeviceBorderData
	element_kind ConflictingElementKind
	tree_order   int
}

fn style_precedence(style LineStyle) int {
	return match style {
		.hidden { 10 }
		.double { 9 }
		.solid { 8 }
		.dashed { 7 }
		.dotted { 6 }
		.ridge { 5 }
		.outset { 4 }
		.groove { 3 }
		.inset { 2 }
		.none { 1 }
	}
}

fn element_precedence(kind ConflictingElementKind) int {
	return match kind {
		.cell { 6 }
		.row { 5 }
		.row_group { 4 }
		.column { 3 }
		.column_group { 2 }
		.table { 1 }
	}
}

pub fn resolve_table_border_conflict(first ConflictingBorder,
	second ConflictingBorder) ConflictingBorder {
	if first.border.line_style == .hidden {
		return first
	}
	if second.border.line_style == .hidden {
		return second
	}
	if first.border.line_style == .none {
		return second
	}
	if second.border.line_style == .none {
		return first
	}
	if first.border.width != second.border.width {
		return if first.border.width > second.border.width { first } else { second }
	}
	first_style := style_precedence(first.border.line_style)
	second_style := style_precedence(second.border.line_style)
	if first_style != second_style {
		return if first_style > second_style { first } else { second }
	}
	first_element := element_precedence(first.element_kind)
	second_element := element_precedence(second.element_kind)
	if first_element != second_element {
		return if first_element > second_element { first } else { second }
	}
	// For otherwise identical borders, CSS 2.2 gives the edge further left/top
	// precedence. tree_order stores that monotonically increasing position.
	return if first.tree_order <= second.tree_order { first } else { second }
}

pub fn fieldset_effective_border_top(border_top f64, legend_margin_height f64,
	legend_border_height f64, has_rendered_legend bool) f64 {
	if !has_rendered_legend {
		return border_top
	}
	return math.max(border_top, legend_margin_height + legend_border_height)
}

pub enum MarkerKind {
	square
	circle
	disc
	disclosure_closed
	disclosure_open
}

pub fn marker_command(kind MarkerKind, rect IntRect, color Color) DisplayListCommand {
	return match kind {
		.square {
			FillRect{rect, color}
		}
		.circle {
			DrawEllipse{rect, color, 1}
		}
		.disc {
			FillEllipse{rect, color}
		}
		.disclosure_closed {
			FillPath{
				path_id:            'triangle-right'
				path_bounding_rect: rect
				color:              color
				winding_rule:       .even_odd
			}
		}
		.disclosure_open {
			FillPath{
				path_id:            'triangle-down'
				path_bounding_rect: rect
				color:              color
				winding_rule:       .even_odd
			}
		}
	}
}

pub struct InputColors {
pub:
	accent     Color
	base       Color
	gray       Color
	mid_gray   Color
	dark_gray  Color
	background Color
}

pub fn checkbox_commands(rect IntRect, checked bool, indeterminate bool, enabled bool,
	colors InputColors) []DisplayListCommand {
	radius := rect.width / 5
	mut commands := []DisplayListCommand{}
	if checked && !indeterminate {
		background := if enabled { colors.accent } else { colors.mid_gray }
		commands << FillRoundedRect{rect, background, uniform_corner_radii(radius)}
		commands << FillPath{
			path_id:            'checkbox-checkmark'
			path_bounding_rect: rect
			color:              colors.base
			winding_rule:       .even_odd
		}
		return commands
	}
	border_thickness := max_int(1, rect.width / 10)
	commands << FillRoundedRect{rect, if enabled { colors.gray } else { colors.mid_gray }, uniform_corner_radii(radius)}
	inner := rect.inflated(-border_thickness, -border_thickness, -border_thickness,
		-border_thickness)
	commands << FillRoundedRect{inner, colors.background, uniform_corner_radii(max_int(0,
		radius - border_thickness))}
	if indeterminate {
		dash :=
			IntRect{rect.x + int(f64(rect.width) * 0.2), rect.y + int(f64(rect.height) * 0.4), int(f64(rect.width) * 0.6), int(f64(rect.height) * 0.2)}
		commands << FillRoundedRect{dash, colors.dark_gray, uniform_corner_radii(max_int(0,
			int(f64(rect.width) * 0.05)))}
	}
	return commands
}

pub fn radio_button_commands(rect IntRect, checked bool, enabled bool,
	colors InputColors) []DisplayListCommand {
	outer := max_int(1, int(math.ceil(f64(rect.width) / 13.0)))
	inner := max_int(2, int(math.ceil(f64(rect.width) / 4.0)))
	fill := if enabled {
		if checked { colors.accent } else { colors.gray }
	} else {
		colors.mid_gray
	}
	mut commands := [
		DisplayListCommand(FillRoundedRect{rect, fill, uniform_corner_radii(rect.width / 2)}),
	]
	middle_rect := rect.inflated(-outer, -outer, -outer, -outer)
	commands << FillRoundedRect{middle_rect, colors.background, uniform_corner_radii(middle_rect.width / 2)}
	if checked {
		inner_rect := rect.inflated(-inner, -inner, -inner, -inner)
		commands << FillRoundedRect{inner_rect, fill, uniform_corner_radii(inner_rect.width / 2)}
	}
	return commands
}

pub fn uniform_corner_radii(radius int) CornerRadii {
	corner := CornerRadius{radius, radius}
	return CornerRadii{corner, corner, corner, corner}
}

pub enum ReplacedContentKind {
	canvas
	image
	video
	navigable_viewport
}

pub fn replaced_content_command(kind ReplacedContentKind, source_id string, rect IntRect,
	clip IntRect, scaling ScalingMode) DisplayListCommand {
	return match kind {
		.canvas, .image { DrawScaledBitmap{rect, clip, source_id, scaling} }
		.video, .navigable_viewport { DrawExternalContent{rect, source_id, scaling} }
	}
}
