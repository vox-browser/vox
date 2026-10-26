module layout

import painting

pub struct PaintCheckboxThemeData {
	rect  painting.IntRect
	scale f64
}

// NativeTheme's canvas scales about the snapped device-pixel origin, while
// its rrects retain CSS dimensions. Flattening this into device-sized rrects
// changes Skia's floating-point corner coverage. Keep retained bounds physical
// and resolve this geometry only in the native player's working command.
pub fn (mut command PaintCommand) resolve_chromium_checkbox_geometry() {
	theme := command.checkbox_theme_data
	if theme == unsafe { nil } || theme.scale <= 0 { return }
	origin_x := f32(theme.rect.x)
	origin_y := f32(theme.rect.y)
	right := origin_x + f32(f64(theme.rect.width) / theme.scale)
	bottom := origin_y + f32(f64(theme.rect.height) / theme.scale)
	inset := if command.kind == 'fill_rect' { f32(0.2) } else { f32(0.5) }
	left := origin_x + inset
	top := origin_y + inset
	command.x = f64(left)
	command.y = f64(top)
	command.width = f64((right - inset) - left)
	command.height = f64((bottom - inset) - top)
	command.radius = 2
	command.stroke_width /= theme.scale
	command.transform = multiply_affine(command.transform, [theme.scale, 0, 0, theme.scale,
		f64(origin_x) * (1 - theme.scale), f64(origin_y) * (1 - theme.scale)]!)
	command.checkbox_theme_data = unsafe { nil }
}
