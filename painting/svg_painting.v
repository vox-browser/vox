module painting

import math

pub enum SVGSpreadMethod {
	pad
	repeat
	reflect
}

pub struct SVGGradientPaintStyle {
pub mut:
	color_stops        []ColorStop
	repeat_length      ?f64
	gradient_transform ?Affine
	spread_method      SVGSpreadMethod
	color_space        ColorInterpolationMethod
}

pub fn (mut style SVGGradientPaintStyle) add_color_stop(stop ColorStop, should_sort bool) {
	style.color_stops << stop
	if should_sort {
		style.color_stops.sort_with_compare(fn (a &ColorStop, b &ColorStop) int {
			if a.position < b.position {
				return -1
			}
			if a.position > b.position {
				return 1
			}
			return 0
		})
	}
}

pub struct SVGLinearGradientPaintStyle {
pub mut:
	gradient    SVGGradientPaintStyle
	start_point Point
	end_point   Point
}

pub struct SVGRadialGradientPaintStyle {
pub mut:
	gradient     SVGGradientPaintStyle
	start_center Point
	start_radius f64
	end_center   Point
	end_radius   f64
}

pub struct SVGPatternPaintStyle {
pub:
	tile_display_list_id string
	tile_rect            Rect
	pattern_transform    ?Affine
}

pub type SVGPaintStyle = SVGLinearGradientPaintStyle
	| SVGPatternPaintStyle
	| SVGRadialGradientPaintStyle

pub enum SVGPaintableKind {
	clip
	foreign_object
	graphics
	mask
	path
	pattern
	svg
}

pub struct SVGPaintable {
pub:
	id             string
	kind           SVGPaintableKind
	absolute_rect  Rect
	transform      Affine = Affine{}
	anti_alias     bool   = true
	path           []Point
	stroke_width   f64
	fill_enabled   bool = true
	stroke_enabled bool
	fill_rule      WindingRule = .nonzero
	clip_rule      WindingRule = .nonzero
	children       []SVGPaintable
}

pub fn (paintable SVGPaintable) compute_absolute_rect() Rect { return paintable.transform.map_rect(paintable.absolute_rect) }
pub fn (paintable SVGPaintable) is_svg_paintable() bool { return true }
pub fn (paintable SVGPaintable) layout_box() string { return paintable.id }
pub fn (paintable SVGPaintable) should_anti_alias() bool { return paintable.anti_alias }

fn distance_to_segment(point Point, start Point, end Point) f64 {
	dx := end.x - start.x
	dy := end.y - start.y
	if dx == 0 && dy == 0 {
		return math.sqrt((point.x - start.x) * (point.x - start.x) +
			(point.y - start.y) * (point.y - start.y))
	}
	t := math.max(0.0, math.min(1.0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (
		dx * dx + dy * dy)))
	projection := Point{start.x + t * dx, start.y + t * dy}
	return math.sqrt((point.x - projection.x) * (point.x - projection.x) +
		(point.y - projection.y) * (point.y - projection.y))
}

pub fn (paintable SVGPaintable) hit_test(screen_point Point) bool {
	inverse := paintable.transform.inverse() or { return false }
	local := inverse.map_point(screen_point)
	if paintable.fill_enabled
		&& polygon_contains_with_rule(paintable.path, local, paintable.fill_rule) {
		return true
	}
	if paintable.stroke_enabled && paintable.path.len >= 2 {
		for index := 1; index < paintable.path.len; index++ {
			if distance_to_segment(local, paintable.path[index - 1], paintable.path[index]) <= paintable.stroke_width / 2.0 {
				return true
			}
		}
	}
	return false
}

pub fn (paintable SVGPaintable) paint_commands(phase PaintPhase, converter DevicePixelConverter,
	color Color) []DisplayListCommand {
	if phase != .foreground || paintable.kind != .path {
		return []
	}
	mut commands := []DisplayListCommand{}
	path_bounds := converter.enclosing_device_rect(paintable.absolute_rect)
	if paintable.fill_enabled {
		commands << FillPath{
			path_id:            paintable.id
			path_bounding_rect: path_bounds
			color:              color
			winding_rule:       paintable.fill_rule
			anti_alias:         paintable.anti_alias
		}
	}
	if paintable.stroke_enabled {
		commands << StrokePath{
			path_id:            paintable.id
			path_bounding_rect: path_bounds
			cap_style:          .butt
			join_style:         .miter
			miter_limit:        4
			color:              color
			thickness:          paintable.stroke_width
			anti_alias:         paintable.anti_alias
		}
	}
	return commands
}

pub enum SVGMaskType {
	alpha
	luminance
}

pub struct SVGMaskDefinition {
pub:
	id        string
	area      Rect
	mask_type SVGMaskType
	content   []SVGPaintable
}

pub struct SVGClipDefinition {
pub:
	id      string
	area    Rect
	content []SVGPaintable
}

pub fn calculate_svg_mask_display_list(mask SVGMaskDefinition,
	converter DevicePixelConverter) DisplayList {
	mut recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	mask_rect := converter.enclosing_device_rect(mask.area)
	recorder.translate(IntPoint{-mask_rect.x, -mask_rect.y})
	for paintable in mask.content {
		for command in paint_svg_descendants(paintable, .foreground, converter, Color{
			r: 255
			g: 255
			b: 255
		}) {
			recorder.append(command)
		}
	}
	return recorder.display_list
}

pub fn calculate_svg_clip_display_list(clip SVGClipDefinition,
	converter DevicePixelConverter) DisplayList {
	mut recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	clip_rect := converter.enclosing_device_rect(clip.area)
	recorder.translate(IntPoint{-clip_rect.x, -clip_rect.y})
	for paintable in clip.content {
		for command in paint_svg_clip_descendants(paintable, converter) {
			recorder.append(command)
		}
	}
	return recorder.display_list
}

fn paint_svg_clip_descendants(root SVGPaintable,
	converter DevicePixelConverter) []DisplayListCommand {
	mut commands := []DisplayListCommand{}
	if root.kind == .path && root.path.len >= 3 {
		commands << FillPath{
			path_id:            root.id
			path_bounding_rect: converter.enclosing_device_rect(root.absolute_rect)
			color:              Color{}
			winding_rule:       root.clip_rule
			anti_alias:         root.anti_alias
		}
	}
	for child in root.children {
		commands << paint_svg_clip_descendants(child, converter)
	}
	return commands
}

pub fn paint_svg_descendants(root SVGPaintable, phase PaintPhase,
	converter DevicePixelConverter, color Color) []DisplayListCommand {
	mut commands := root.paint_commands(phase, converter, color)
	for child in root.children {
		commands << paint_svg_descendants(child, phase, converter, color)
	}
	return commands
}
