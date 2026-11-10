module jpegxl

import crypto.sha256
import os

// libjxl's default effort emits a modular reference-only frame holding text
// glyphs and a visible frame that draws them through a patch dictionary.
// Every file must decode to the pinned native straight and paint RGBA8 bytes.
fn test_patch_reference_frames_match_native_pixels() {
	mut count := 0
	mut vardct := 0
	mut modular := 0
	mut grouped := 0
	mut gray := 0
	mut alpha := 0
	for line in $embed_file('testdata/patch-frame-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/patch-frames', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Patch frame ${f[0]}, paint=${paint}'
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut reference := reader.read_frame_header(ctx)!
		reference.postprocess(ctx)!
		assert reference.frame_type == .reference_only && reference.save_before_color_transform
		assert reference.encoding == .modular && !reference.is_last
		_ := reader.read_sections(reader.read_toc(int(reference.num_toc_entries()))!)!
		mut visible := reader.read_frame_header(ctx)!
		visible.postprocess(ctx)!
		assert visible.is_last && visible.has_patches()
		if visible.encoding == .vardct { vardct++ } else { modular++ }
		if visible.num_groups() > 1 { grouped++ }
		if file.metadata.color_encoding.color_space == .gray { gray++ }
		if file.metadata.extra_channels.len == 1 { alpha++ }
		count++
	}
	assert count == 44 && vardct > 0 && modular > 0 && grouped > 0 && gray == 2 && alpha == 12
}

fn test_patch_streams_require_reference_slots_before_reading() {
	frame := FrameHeader{ width: 8, height: 8, flags: 2, restoration: RestorationFilter.default() }
	mut reader := new_bit_reader([u8(255), 255])
	if _ := reader.read_lf_global(FileHeader{}, frame) { assert false }
	assert reader.position == 0
	mut modular := new_bit_reader([u8(255), 255])
	if _ := modular.read_modular_global_plan(FileHeader{}, FrameHeader{ ...frame, encoding: .modular }) { assert false }
	assert modular.position == 0
}

fn test_patch_reference_frames_reject_unsupported_services() {
	base := FrameHeader{ frame_type: .reference_only, encoding: .modular, width: 8, height: 8, can_be_referenced: true,
		save_before_color_transform: true, restoration: RestorationFilter.default() }
	for invalid in [FrameHeader{ ...base, frame_type: .regular }, FrameHeader{ ...base, is_last: true },
		FrameHeader{ ...base, save_before_color_transform: false }, FrameHeader{ ...base, encoding: .vardct },
		FrameHeader{ ...base, flags: 2 }, FrameHeader{ ...base, flags: 16 }, FrameHeader{ ...base, flags: 1 },
		FrameHeader{ ...base, save_as_reference: 4 }] {
		mut reader := new_bit_reader([u8(0)])
		if _ := decode_patch_reference_frame(FileHeader{}, invalid, .signed32, mut reader) { assert false }
		assert reader.position == 0
	}
}

fn test_frame_patches_reject_mismatched_planes() {
	plane := FloatPlane{ width: 2, height: 2, samples: []f32{len: 4} }
	other := FloatPlane{ width: 3, height: 2, samples: []f32{len: 6} }
	if _ := apply_frame_patches([plane, plane, other]!, PatchesDictionary{}, []PatchFrameReference{len: 4}) {
		assert false
	}
}
