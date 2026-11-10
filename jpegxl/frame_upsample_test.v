module jpegxl

import crypto.sha256
import math
import os

fn test_upsampled_complete_files_match_native_rgba_with_default_and_custom_kernels() {
	mut count := 0
	mut total := 0
	for line in $embed_file('testdata/upsampled-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/upsampled', f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		for premultiply in [false, true] {
			image := decode_vardct_rgba(bytes, premultiply)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width*4
			assert sha256.sum(image.pixels).hex() == f[4], 'Upsampled RGBA ${f[0]}'
		}
		total += f[1].int()*f[2].int()*4
		count++
	}
	assert count == 15 && total == 1933816
}

fn test_frame_upsampling_filters_at_coded_resolution_and_preserves_edge_crop() {
	mut reader := new_bit_reader([u8(1)])
	transform := reader.read_transform_data(true)!
	frame := FrameHeader{ width: 13, height: 11, upsampling: 2,
		restoration: RestorationFilter{ ...RestorationFilter.default(), epf_iterations: 0 } }
	mut samples := []f32{len: 64, init: 1000}
	for y in 0 .. 6 { for x in 0 .. 7 { samples[y*8+x] = f32((x+y*13)%17)/32 } }
	p := FloatPlane{ width: 8, height: 8, samples: samples }
	actual := render_vardct_frame(VarDctFramePlanes{ planes: [p,p,p]! }, frame, transform, []PatchFrameReference{})!
	for c in 0 .. 3 {
		cropped := crop_float_plane(p, 0, 0, 7, 6)!
		filtered := gaborish_plane(cropped, frame.restoration.gab_weights[c*2], frame.restoration.gab_weights[c*2+1])!
		expected := upsample_plane(filtered, 2, transform.weights2[..], 13, 11)!
		assert actual[c].width == 13 && actual[c].height == 11
		assert actual[c].samples.map(math.f32_bits(it)) == expected.samples.map(math.f32_bits(it))
	}
	if _ := upsample_frame_planes([p,p,p]!, FrameHeader{ ...frame, upsampling: 3 }, transform) { assert false }
	if _ := upsample_frame_planes([p,p,p]!, FrameHeader{ ...frame, width: 65536, height: 65536 }, transform) { assert false }
}

fn test_modular_lf_reference_saves_upsampled_source_planes_before_color_conversion() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl/guardian-photo.jxl'))!
	mut reader := new_bit_reader(extract_codestream(bytes)!)
	file := reader.read_file_header()!
	ctx := file.frame_header_context()
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	sections := reader.read_sections(toc)!
	mut baseline_sections := sections.clone()
	baseline := decode_lf_reference_frame(file, frame, .signed16, none, mut baseline_sections)!
	lf := FrameHeader{ ...frame, width: 196, height: 196, upsampling: 2 }
	owner := FileHeader{ ...file, size: Size{ width: 196, height: 196 } }
	mut inputs := sections.clone()
	actual := decode_lf_reference_frame(owner, lf, .signed16, none, mut inputs)!
	for c in 0 .. 3 {
		expected := upsample_plane(baseline[c], 2, file.transform.weights2[..], 25, 25)!
		assert actual[c].width == 25 && actual[c].height == 25
		assert actual[c].samples.map(math.f32_bits(it)) == expected.samples.map(math.f32_bits(it))
	}
	for section in inputs { assert section.available_bits() == 0 }
}
