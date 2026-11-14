module metal

pub enum TextureFormat {
	rgba8
	r8
	rg8
	srgba8
	r8_snorm
	rg8_snorm
	rgba8_snorm
	r16f
	rg16f
	rgba16f
	r32f
	rg32f
	rgba32f
	r8i
	rg8i
	rgba8i
	r8ui
	rg8ui
	rgba8ui
	r16i
	rg16i
	rgba16i
	r16ui
	rg16ui
	rgba16ui
	r32i
	rg32i
	rgba32i
	r32ui
	rg32ui
	rgba32ui
	rgb10a2
	rgb10a2ui
	rg11b10f
	rgb9e5
	depth16
	depth32
	depth_stencil
	stencil8
}

pub fn (format TextureFormat) pixel_size() int {
    return match format {
        .rgba8 { 4 }
        .r8 { 1 }
        .rg8 { 2 }
        .srgba8 { 4 }
        .r8_snorm { 1 }
        .rg8_snorm { 2 }
        .rgba8_snorm { 4 }
        .r16f { 2 }
        .rg16f { 4 }
        .rgba16f { 8 }
        .r32f { 4 }
        .rg32f { 8 }
        .rgba32f { 16 }
        .r8i { 1 }
        .rg8i { 2 }
        .rgba8i { 4 }
        .r8ui { 1 }
        .rg8ui { 2 }
        .rgba8ui { 4 }
        .r16i { 2 }
        .rg16i { 4 }
        .rgba16i { 8 }
        .r16ui { 2 }
        .rg16ui { 4 }
        .rgba16ui { 8 }
        .r32i { 4 }
        .rg32i { 8 }
        .rgba32i { 16 }
        .r32ui { 4 }
        .rg32ui { 8 }
        .rgba32ui { 16 }
        .rgb10a2 { 4 }
        .rgb10a2ui { 4 }
        .rg11b10f { 4 }
        .rgb9e5 { 4 }
        .depth16 { 2 }
        .depth32 { 4 }
        .depth_stencil { 8 }
        .stencil8 { 1 }
    }
}
