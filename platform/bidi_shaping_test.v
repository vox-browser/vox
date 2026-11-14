module platform

fn test_chromium_shapes_ascii_neutrals_in_the_resolved_rtl_direction() {
	for policy in [FontRenderingPolicy.chromium, .libweb] {
		font := &Font{family: 'Arial', point_size: 13, font_rendering_policy: policy}
		rtl := shape_text(0, 0, '+ ', font, .rtl)
		assert rtl.glyphs_.len == 2
		assert rtl.glyphs_[0].code_point == if policy == .chromium { u32(` `) } else { u32(`+`) }
		ltr := shape_text(0, 0, '+ ', font, .ltr)
		assert ltr.glyphs_[0].code_point == u32(`+`)
	}
}
