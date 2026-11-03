module css

import platform

fn test_device_layout_keeps_the_css_system_font_optical_instance() {
	$if !macos { return }
	mut source := FontCascadeList.create()
	source.add(PlatformFont{
		typeface: &PlatformTypeface{family_name: 'SystemUi'}
		point_size: 15
		pixel_size_override_: 20
		variations: FontVariationSettings{weight: 500, opsz: 20}
		font_rendering_policy: .chromium
	}, [])
	original := source.fonts[0].font.font_for_rendering()
	face := original.system_face() or { panic('system font') }
	assert platform.FontVariationAxis{tag: 0x6f70737a, value: 20} in face.variations
	for scale in [f64(2), 3] {
		projected := device_layout_fonts(source, scale, 20 * scale)
		font := projected.fonts[0].font.font_for_rendering()
		projected_face := font.system_face() or { panic('projected system font') }
		assert projected_face.variations == face.variations
		assert font.point_size == f32(20 * scale)
		assert projected_face.metrics.ascent == face.metrics.ascent * scale
		assert projected_face.metrics.descent == face.metrics.descent * scale
		assert projected_face.metrics.cap_height == face.metrics.cap_height * scale
	}
	assert original.point_size == 20
	assert original.system_face()?.variations == face.variations
}
