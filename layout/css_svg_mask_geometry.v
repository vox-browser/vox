module layout

import css
import math
import painting

fn transparent_css_svg_mask_image(rect painting.Rect) []painting.SVGMaskPaintOperation {
	return [painting.SVGMaskPaintOperation{
		kind:         .path
		has_fill:     true
		fill_opacity: 0
		path:         painting.ClipPathVisualData{
			segments: [
				painting.ClipPathSegment{ kind: .move_to, point: painting.Point{rect.x, rect.y} },
				painting.ClipPathSegment{ kind: .line_to, point: painting.Point{rect.right(), rect.y} },
				painting.ClipPathSegment{ kind: .line_to, point: painting.Point{rect.right(), rect.bottom()} },
				painting.ClipPathSegment{ kind: .line_to, point: painting.Point{rect.x, rect.bottom()} },
				painting.ClipPathSegment{ kind: .close_path },
			]
		}
	}]
}

fn css_mask_layer_value(computed &css.ComputedProperties, property css.PropertyID,
	index int) ?css.StyleValue {
	value := computed.typed_property_value(property) or { return none }
	if list := value.as_value_list() {
		if list.separator() == .comma {
			if list.size() == 0 { return none }
			return list.value_at(index, true)
		}
	}
	return value
}

// The retained mask stream has no per-image viewport clip. Keep its existing
// replay for content that needs one, or whose filters/images have wider ink.
fn css_svg_mask_operations_fit_image(operations []painting.SVGMaskPaintOperation,
	width f64, height f64) bool {
	for operation in operations {
		if operation.kind in [.begin_opacity, .end_opacity] { continue }
		if operation.kind != .path { return false }
		mut bounds := painting_clip_path_bounds(operation.path) or { return false }
		if operation.has_stroke {
			inset := operation.stroke_width * math.max(1, operation.stroke_miter_limit) / 2
			bounds = painting.Rect{bounds.x - inset, bounds.y - inset, bounds.width + 2 * inset, bounds.height + 2 * inset}
		}
		mapped := operation.transform.map_rect(bounds)
		if mapped.x < -0.0001 || mapped.y < -0.0001
			|| mapped.right() > width + 0.0001 || mapped.bottom() > height + 0.0001 {
			return false
		}
	}
	return true
}

// A non-repeating SVG mask has its own concrete image tile. In particular,
// contain/cover do not make a square element into a square SVG viewport.
// Resolve the CSS tile before collecting the isolated image document's paths.
fn css_svg_mask_image_operations(node &Node, source string, computed &css.ComputedProperties,
	index int, border_rect painting.Rect) ?[]painting.SVGMaskPaintOperation {
	repeat := css_mask_layer_value(computed, .mask_repeat, index) or { return none }
	if repeat !is css.RepeatStyleStyleValue { return none }
	if repeat.repeat_x() != .no_repeat || repeat.repeat_y() != .no_repeat { return none }
	origins := computed.mask_origin()
	clips := computed.mask_clip()
	if origins.len == 0 || clips.len == 0 { return none }
	if origins[index % origins.len] !in [.border_box, .stroke_box, .view_box]
		|| clips[index % clips.len] !in [.border_box, .stroke_box, .view_box] {
		return none
	}
	color_scheme := image_color_scheme(node.document(), computed)
	document := svg_image_document_for_source_in_viewport(node, source, color_scheme) or { return none }
	mut natural := svg_background_natural_size(document)
	if width := natural.width { natural.width = width.scaled(computed.layout_coordinate_scale()) }
	if height := natural.height {
		natural.height = height.scaled(computed.layout_coordinate_scale())
	}
	mut layer := css.BackgroundLayerData{ repeat_x: .no_repeat, repeat_y: .no_repeat }
	if size := css_mask_layer_value(computed, .mask_size, index) {
		if size is css.BackgroundSizeStyleValue {
			layer.size_x = css.LengthPercentageOrAuto.from_style_value_logic(size.size_x())
			layer.size_y = css.LengthPercentageOrAuto.from_style_value_logic(size.size_y())
		} else if size.to_keyword() == .contain {
			layer.size_type = .contain
		} else if size.to_keyword() == .cover {
			layer.size_type = .cover
		}
	}
	if position := css_mask_layer_value(computed, .mask_position, index) {
		if position is css.PositionStyleValue {
			resolved := position.with_resolved_keywords()
			layer.position_x = css.LengthPercentage.from_style_value_logic(resolved.edge_x().offset())
			layer.position_y = css.LengthPercentage.from_style_value_logic(resolved.edge_y().offset())
		}
	}
	chromium := node.document().font_rendering_policy() == .chromium
	// Blink fits contain/cover against its snapped positioning area, and rounds
	// contain's dependent dimension before resolving the position in free space.
	area := if chromium && layer.size_type in [.contain, .cover] {
		painting.Rect{math.floor(border_rect.x + .5), math.floor(border_rect.y + .5), math.floor(border_rect.right() + .5) - math.floor(border_rect.x + .5), math.floor(border_rect.bottom() + .5) - math.floor(border_rect.y + .5)}
	} else {
		border_rect
	}
	resolution := computed.length_resolution_context()
	resolved := painting.resolve_background_layer_with_natural_size(layer, source, area,
		resolution, natural) or { return transparent_css_svg_mask_image(border_rect) }
	mut width := resolved.image_rect.width
	mut height := resolved.image_rect.height
	if chromium && layer.size_type in [.contain, .cover] {
		if ratio := natural.aspect_ratio {
			aspect := ratio.to_double()
			if aspect > 0 {
				fit_height := area.width / aspect
				use_height := if layer.size_type == .contain {
					fit_height > area.height
				} else {
					fit_height < area.height
				}
				width = if use_height { area.height * aspect } else { area.width }
				height = if use_height { area.height } else { fit_height }
				width = math.trunc(width * 64) / 64
				height = math.trunc(height * 64) / 64
			}
		}
	}
	if chromium && layer.size_type == .contain {
		if width != area.width { width = math.max(1, math.floor(width + .5)) }
		if height != area.height { height = math.max(1, math.floor(height + .5)) }
	}
	x := border_rect.x + layer.position_x.to_px(resolution,
		css.CSSPixels.nearest_value_for(border_rect.width - width)).to_double()
	y := border_rect.y + layer.position_y.to_px(resolution,
		css.CSSPixels.nearest_value_for(border_rect.height - height)).to_double()
	if width <= 0 || height <= 0 { return transparent_css_svg_mask_image(border_rect) }
	// SVGImage keeps the fractional layout container separate from the rounded
	// recording size. Compose that residual scale after the SVG viewBox mapping.
	layout_width := if chromium { math.max(1.0 / 64, math.trunc(width * 64) / 64) } else { width }
	layout_height := if chromium {
		math.max(1.0 / 64, math.trunc(height * 64) / 64)
	} else {
		height
	}
	mut collection := SVGMaskPaintCollection{}
	if !collect_svg_vector_image_paint_operations(node, source,
		painting.Rect{0, 0, layout_width, layout_height}, color_scheme, mut collection) {
		return none
	}
	if collection.operations.len == 0 { return transparent_css_svg_mask_image(border_rect) }
	if !css_svg_mask_operations_fit_image(collection.operations, layout_width, layout_height) {
		return none
	}
	transform := if chromium {
		painting.Affine{
			a: math.max(1, math.floor(layout_width + .5)) / layout_width
			d: math.max(1, math.floor(layout_height + .5)) / layout_height
			e: math.floor(x + .5)
			f: math.floor(y + .5)
		}
	} else {
		painting.Affine{ e: x, f: y }
	}
	return transform_svg_mask_paint_operations(collection.operations, transform)
}
