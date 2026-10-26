module layout

import css
import html
import math
import painting

// LayoutTheme suppresses native painting when a control's border/background
// is styled. Recognize the Chromium UA defaults here, leaving author-painted
// controls on the ordinary CSS path.
fn chromium_native_text_control(box &BlockBox) string {
	if !box.snaps_background_rect || box.layout_handle == unsafe { nil }
		|| box.form_control_color_scheme == .dark || box.decorations().background_images.len > 0
		|| !box_radii_are_zero(box.decorations().border_radii) {
		return ''
	}
	node := unsafe { &Node(box.layout_handle) }
	if node.computed_values().appearance() == .none_ { return '' }
	dom_node := node.dom_node() or { return '' }
	element := dom_node.as_element() or { return '' }
	if element.is_actually_disabled() { return '' }
	mut kind := ''
	mut border_width := 0.0
	mut style := box.border_styles.top
	mut fill := css.Color{255, 255, 255, 255}
	if node.is_textarea_box() || chromium_menu_list(node) {
		kind = 'textfield'
		border_width = 1
		style = .solid
	} else if node.is_text_input_box() {
		kind = 'textfield'
		border_width = 2
		style = .inset
	} else if box.tag_name in ['input', 'button'] {
		if box.tag_name == 'input' && element.get_attribute_value('type').to_lower() !in [
			'button',
			'submit',
			'reset',
		] {
			return ''
		}
		kind = 'button'
		border_width = 2
		style = .outset
		fill = css.Color{239, 239, 239, 255}
	} else {
		return ''
	}
	border_width *= node.document().layout_coordinate_scale()
	if box.background_color != fill || box.border != BoxEdges{border_width, border_width, border_width, border_width}
		|| box.border_styles != BoxBorderStyles{style, style, style, style}
		|| effective_border_colors(box.border_colors, box.border_color) != BoxColors{css.Color{118, 118, 118, 255}, css.Color{118, 118, 118, 255}, css.Color{118, 118, 118, 255}, css.Color{118, 118, 118, 255}} {
		return ''
	}
	return kind
}

// NativeThemeBase::{PaintButton,PaintTextField}: both paint into the snapped
// border box with a 1px stroke and 2px radius, regardless of the CSS border's
// contribution to layout. Keep fill and stroke in one GPU raster operation.
fn append_chromium_native_text_control(mut commands []PaintCommand, rect LayoutRect,
	kind string, scale f64, opacity f64) {
	snapped := pixel_snapped_layout_rect(rect)
	inset := scale / 2
	commands << PaintCommand{
		kind:                'fill_rect'
		x:                   snapped.x + inset
		y:                   snapped.y + inset
		width:               snapped.width - scale
		height:              snapped.height - scale
		radius:              2 * scale
		color:               if kind == 'button' { 'rgb(239 239 239)' } else { 'rgb(255 255 255)' }
		underlays_next:      true
		disable_antialias:   kind == 'textfield'
		opacity:             opacity
		force_dark_role:     .background
		force_dark_role_set: true
	}
	commands << PaintCommand{
		kind:                'stroke_rounded_rect'
		x:                   snapped.x + inset
		y:                   snapped.y + inset
		width:               snapped.width - scale
		height:              snapped.height - scale
		radius:              2 * scale
		stroke_width:        scale
		disable_antialias:   kind == 'textfield'
		color:               'rgb(118 118 118)'
		opacity:             opacity
		force_dark_role:     .border
		force_dark_role_set: true
	}
}

// ThemePainterDefault::SetupMenuListArrow and NativeThemeBase::PaintMenuList.
// The theme receives an integer native-coordinate rectangle. Its open V has
// an 8px base and a two-device-pixel stroke, also on Retina displays.
fn append_chromium_menu_list_arrow(mut commands []PaintCommand, box &BlockBox,
	rect LayoutRect, opacity f64) {
	if !box.snaps_background_rect || box.layout_handle == unsafe { nil } { return }
	node := unsafe { &Node(box.layout_handle) }
	if !chromium_menu_list(node) { return }
	scale := node.document().layout_coordinate_scale()
	snapped := pixel_snapped_layout_rect(rect)
	values := node.computed_values()
	horizontal := values.writing_mode() == .horizontal_tb
	forward := values.direction() == .ltr
	intended := f64(int(8 * scale))
	short := math.floor(intended / 2)
	arrow_padding := html.chromium_menu_list_arrow_padding() * scale
	mut arrow := LayoutRect{}
	if horizontal {
		left := snapped.x + math.floor(box.border.left)
		right := snapped.x + snapped.width - math.floor(box.border.right)
		arrow = LayoutRect{
			x:      f64(int(if forward {
				right - (arrow_padding + intended) / 2
			} else {
				left + (arrow_padding - intended) / 2
			}))
			y:      snapped.y + math.floor(snapped.height / 2) - math.floor(short / 2)
			width:  intended
			height: short
		}
	} else {
		top := snapped.y + math.floor(box.border.top)
		bottom := snapped.y + snapped.height - math.floor(box.border.bottom)
		arrow = LayoutRect{
			x:      snapped.x + math.floor(snapped.width / 2) - math.floor(short / 2)
			y:      f64(int(if forward {
				bottom - (arrow_padding + intended) / 2
			} else {
				top + (arrow_padding - intended) / 2
			}))
			width:  short
			height: intended
		}
	}
	// A narrow authored control shrinks the chevron instead of clipping it.
	width := math.max(0.0, math.min(arrow.x + arrow.width, snapped.x + snapped.width) - math.max(arrow.x, snapped.x))
	height := math.max(0.0, math.min(arrow.y + arrow.height, snapped.y + snapped.height) - math.max(arrow.y, snapped.y))
	if width != arrow.width || height != arrow.height {
		new_width := if horizontal {
			math.min(width, height * 2)
		} else {
			math.min(width, math.floor(height / 2))
		}
		new_height := if horizontal { math.floor(new_width / 2) } else { new_width * 2 }
		arrow = LayoutRect{
			x:      arrow.x + math.floor((arrow.width - new_width) / 2)
			y:      arrow.y + math.floor((arrow.height - new_height) / 2)
			width:  new_width
			height: new_height
		}
	}
	if arrow.width <= 0 || arrow.height <= 0 { return }
	mut points := []painting.Point{}
	if horizontal {
		points = [painting.Point{arrow.x, arrow.y},
			painting.Point{arrow.x + math.floor(arrow.width / 2), arrow.y + arrow.height},
			painting.Point{arrow.x + arrow.width, arrow.y}]
	} else if values.writing_mode() in [.vertical_rl, .sideways_rl] {
		points = [painting.Point{arrow.x + arrow.width, arrow.y},
			painting.Point{arrow.x, arrow.y + math.floor(arrow.height / 2)},
			painting.Point{arrow.x + arrow.width, arrow.y + arrow.height}]
	} else {
		points = [painting.Point{arrow.x, arrow.y},
			painting.Point{arrow.x + arrow.width, arrow.y + math.floor(arrow.height / 2)},
			painting.Point{arrow.x, arrow.y + arrow.height}]
	}
	path := painting.ClipPathVisualData{
		segments: [
			painting.ClipPathSegment{ kind: .move_to, point: points[0] },
			painting.ClipPathSegment{ kind: .line_to, point: points[1] },
			painting.ClipPathSegment{ kind: .line_to, point: points[2] },
		]
	}
	commands << PaintCommand{
		kind:                'draw_svg_path'
		x:                   snapped.x
		y:                   snapped.y
		width:               snapped.width
		height:              snapped.height
		svg_data:            &PaintSVGPathData{ path: painting_path_svg(path), path_data: compatibility_pack_clip_path_segments(path) }
		stroke_width:        2
		stroke_color:        box.text_color.serialize()
		opacity:             opacity
		force_dark_role:     .foreground
		force_dark_role_set: true
	}
}

// ScrollableAreaPainter::DrawPlatformResizerImage's fixed 7px grip, inset
// 2px from the padding edge. Its two paths use 60% black and white strokes.
fn append_chromium_resizer(mut commands []PaintCommand, padding_rect LayoutRect,
	mirrored bool, scale f64, opacity f64) {
	rect := pixel_snapped_layout_rect(padding_rect)
	spacing := math.round(2 * scale)
	size := math.round(7 * scale)
	small := math.floor(size / 2)
	x := if mirrored { rect.x + spacing } else { rect.x + rect.width - spacing }
	direction := if mirrored { 1.0 } else { -1.0 }
	bottom := rect.y + rect.height - spacing
	stroke := math.ceil(scale)
	grip := LayoutRect{math.min(x, x + direction * size) - stroke, bottom - size - stroke, size + 2 * stroke, size + 2 * stroke}
	for light in [false, true] {
		color := if light { css.Color{255, 255, 255, 153} } else { css.Color{0, 0, 0, 153} }
		mut segments := []painting.ClipPathSegment{}
		for length in [size, small] {
			start_y := bottom - length + if light { stroke } else { 0.0 }
			end_x := x + direction * length - if light { direction * stroke } else { 0.0 }
			segments << painting.ClipPathSegment{
				kind:  .move_to
				point: painting.Point{x, start_y}
			}
			segments << painting.ClipPathSegment{
				kind:  .line_to
				point: painting.Point{end_x, bottom}
			}
		}
		path := painting.ClipPathVisualData{ segments: segments }
		commands << PaintCommand{
			kind:                'draw_svg_path'
			x:                   grip.x
			y:                   grip.y
			width:               grip.width
			height:              grip.height
			svg_data:            &PaintSVGPathData{
				path:      painting_path_svg(path)
				path_data: compatibility_pack_clip_path_segments(path)
			}
			stroke_width:        stroke
			stroke_color:        color.serialize()
			opacity:             opacity
			force_dark_role:     .foreground
			force_dark_role_set: true
		}
	}
}
