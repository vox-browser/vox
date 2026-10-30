@[has_globals]
module platform

import math

__global (
	ink_test_calls int
	ink_test_result i32 = 2
	ink_test_nonfinite bool
)

fn ink_test_register(_ &char, _ &char, _ &char, tags &u32, values &f32, count i32) i32 {
	assert count == 1
	assert unsafe { tags[0] } == 0x6f70737a
	assert unsafe { values[0] } == 17
	return 1
}

fn ink_test_measure(_ &char, index i32, size f32, weight i32, italic i32, disabled i32,
	glyphs &u16, positions &f32, count i32, top f32, bottom f32, output &f32, capacity i32) i32 {
	ink_test_calls++
	assert index == 0 && size == 22 && weight == 700 && italic == 0 && disabled == 0
	assert count == 2 && capacity == 4 && top == 1 && bottom == 3
	unsafe {
		assert glyphs[0] == 7 && glyphs[1] == 8
		assert positions[0] == 6 && positions[1] == 8
		assert positions[2] == 22 && positions[3] == 24
		output[0] = if ink_test_nonfinite { f32(math.inf(1)) } else { f32(1) }
		output[1] = 5
	}
	return ink_test_result
}

fn ink_test_run(policy FontRenderingPolicy) &GlyphRun {
	font := &Font{family:'Variable test',point_size:11,weight:700,font_rendering_policy:policy,
		system_face_override:SystemFontFace{path:'test.ttf',postscript_name:'Variable',
			variations:[FontVariationAxis{tag:0x6f70737a,value:17}]}}
	return &GlyphRun{font_:font,glyphs_:[
		Glyph{glyph_index:7,position:GlyphPosition{3,4}},
		Glyph{glyph_index:999999,should_paint:false},
		Glyph{glyph_index:8,position:GlyphPosition{11,12}}]}
}

fn test_variable_ink_intercepts_pack_only_visible_glyphs_at_the_requested_scale() {
	previous := chromium_glyph_intercept_lookup
	defer { chromium_glyph_intercept_lookup = previous }
	chromium_glyph_intercept_lookup = ChromiumGlyphInterceptLookup{attempted:true,
		intercepts:voidptr(ink_test_measure),register_face:voidptr(ink_test_register)}
	ink_test_calls = 0
	ink_test_result = 2
	ink_test_nonfinite = false
	assert ink_test_run(.chromium).glyph_intercepts(2,1,3) == [f32(1),5]
	assert ink_test_calls == 1
	for result in [i32(-1),3,5] {
		ink_test_result = result
		assert chromium_variable_glyph_intercepts(ink_test_run(.chromium),2,1,3) == none
	}
	ink_test_result = 2
	ink_test_nonfinite = true
	assert chromium_variable_glyph_intercepts(ink_test_run(.chromium),2,1,3) == none
	ink_test_nonfinite = false
	ink_test_result = 0
	assert (chromium_variable_glyph_intercepts(ink_test_run(.chromium),2,1,3) or { panic('missing empty result') }).len == 0
}

fn test_variable_ink_intercepts_retain_the_portable_fallback_without_a_bridge() {
	previous := chromium_glyph_intercept_lookup
	defer { chromium_glyph_intercept_lookup = previous }
	chromium_glyph_intercept_lookup = ChromiumGlyphInterceptLookup{attempted:true}
	assert chromium_variable_glyph_intercepts(ink_test_run(.chromium),2,1,3) == none
	chromium_glyph_intercept_lookup = ChromiumGlyphInterceptLookup{attempted:true,
		intercepts:voidptr(ink_test_measure),register_face:voidptr(ink_test_register)}
	ink_test_calls = 0
	assert chromium_variable_glyph_intercepts(ink_test_run(.libweb),2,1,3) == none
	assert chromium_variable_glyph_intercepts(ink_test_run(.chromium),2,3,1) == none
	assert chromium_variable_glyph_intercepts(ink_test_run(.chromium),2,1,f32(math.inf(1))) == none
	assert ink_test_calls == 0
}
