module layout

import css
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
	if node.is_textarea_box() {
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
