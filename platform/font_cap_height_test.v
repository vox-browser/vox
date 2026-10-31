module platform

import math
import x.ttf

fn test_cap_height_uses_native_font_metrics_at_fractional_sizes() {
	$if macos {
		for size in [f32(12), 16, 23.5] {
			font := Font{family: 'Arial', point_size: size, font_rendering_policy: .chromium}
			face := font.system_face() or { panic('missing native Arial') }
			metrics := font.pixel_metrics()
			assert math.abs(f64(metrics.cap_height) - face.metrics.cap_height) < 0.00001
			assert metrics.cap_height > 0 && metrics.cap_height < metrics.ascent
			assert font.pixel_metrics() == metrics
		}
	}
}

fn test_cap_height_of_decoded_faces_scales_independently_from_ascent() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	small := Font{family: 'CapHeightFixture', point_size: 12, source_path: path}.pixel_metrics()
	large := Font{family: 'CapHeightFixture', point_size: 24, source_path: path}.pixel_metrics()
	assert small.cap_height > 0 && small.cap_height < small.ascent
	assert large.cap_height == 2 * small.cap_height
	assert large.x_height < large.cap_height
}

fn test_cap_height_without_os2_cap_metrics_uses_the_capital_h_outline() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	mut bytes := read_outline_face_bytes(path,0) or { panic('missing font bytes') }
	normalize_table_checksums(mut bytes)
	mut face := &ttf.TTF_File{buf:bytes,panose_array:[]u8{len:12},width_scale:1}
	face.init()
	cap_glyph := face.map_code(int(`H`))
	_,_,_,cap_top := face.read_glyph_dim(cap_glyph)
	os2 := font_table_offset(face.buf,'OS/2') or { panic('missing OS/2') }
	face.buf[os2] = 0
	face.buf[os2+1] = 1
	font := Font{family:'CapOutlineFixture',point_size:16,decoded_face_:face}
	assert font.pixel_metrics().cap_height == f32(cap_top)*16/f32(face.units_per_em)
}
