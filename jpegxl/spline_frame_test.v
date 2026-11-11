module jpegxl

import crypto.sha256
import os

// Complete VarDCT spline frames against the pinned native jxl 0.7.0 RGBA8
// output. Variant 0 carries an empty spline set and must reproduce its
// unmodified noise control; variants 1 and 2 draw one spline with opposite
// color signs and must change the image.
fn test_complete_spline_vardct_images_match_native_pixels() {
	mut count := 0
	mut total := 0
	mut controls := 0
	mut drawn := 0
	for line in $embed_file('testdata/spline-frame-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/spline-frames', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		control := os.read_bytes(os.join_path(@VMODROOT, f[8]))!
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Spline VarDCT ${f[0]}, paint=${paint}'
			mut alpha := []u8{len: image.width * image.height}
			for i in 0 .. alpha.len { alpha[i] = image.pixels[i * 4 + 3] }
			assert sha256.sum(alpha).hex() == f[6]
			base := decode_rgba(control, paint)!
			assert sha256.sum(base.pixels).hex() == f[if paint { 10 } else { 9 }]
			if f[7] == '0' {
				assert image.pixels == base.pixels
			} else {
				assert image.pixels != base.pixels
			}
			total += image.pixels.len
		}
		if f[7] == '0' { controls++ } else { drawn++ }
		count++
	}
	assert count == 42 && controls == 14 && drawn == 28
	assert total == 2 * 4 * spline_frame_pixel_count()
}

fn spline_frame_pixel_count() int {
	mut pixels := 0
	for line in $embed_file('testdata/spline-frame-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		pixels += f[1].int() * f[2].int()
	}
	return pixels
}

fn test_spline_drawing_rejects_mismatched_cache_geometry() {
	plane := FloatPlane{ width: 2, height: 2, samples: []f32{len: 4} }
	planes := [plane, plane, plane]!
	empty := SplineDrawCache{}
	same := draw_frame_splines(planes, empty)!
	for c in 0 .. 3 { assert same[c].samples == plane.samples }
	cache := SplineDrawCache{ width: 3, height: 2, segments: [SplineSegment{}], row_starts: [0, 1, 1], row_indices: [0] }
	if _ := draw_frame_splines(planes, cache) { assert false }
}
