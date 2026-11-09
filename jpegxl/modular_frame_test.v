module jpegxl

import crypto.sha256
import os

fn test_grouped_lossless_rgba_matches_complete_source_output() {
	mut count := 0
	mut permuted := 0
	mut multipass := 0
	mut lf_sections := 0
	mut grouped := 0
	mut lf_data := 0
	mut trees := 0
	mut squeeze := 0
	for line in $embed_file('testdata/grouped-pixels.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 6
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/grouped', f[0]))!
		decoded := decode_lossless_rgba(bytes, f[1] == '1') or {
			assert false, '${f[0]}: ${err.msg()}'
			return
		}
		assert decoded.width == f[2].int() && decoded.height == f[3].int() && decoded.pitch == f[4].int()
		assert sha256.sum(decoded.pixels).hex() == f[5], 'Grouped image ${f[0]}, paint=${f[1]}'
		mut reader := new_bit_reader(extract_codestream(bytes)!)
		file := reader.read_file_header()!
		context := file.frame_header_context()
		mut frame := reader.read_frame_header(context)!
		frame.postprocess(context)!
		if frame.num_groups() > 1 { grouped++ }
		toc := reader.read_toc(int(frame.num_toc_entries()))!
		if toc.permuted { permuted++ }
		if frame.passes.count > 1 { multipass++ }
		if frame.num_lf_groups() > 1 { lf_sections++ }
		// Partial section tables must not produce zero-filled output planes.
		if f[1] == '0' {
			mut sections := reader.read_sections(toc)!
			global := sections[0].read_modular_global_plan(file, frame)!
			buckets := plan_modular_sections(global.plan.coded.map(global.plan.buffers[it]), frame)!
			if buckets[1].len > 0 { lf_data++ }
			if global.tree != none { trees++ }
			if global.header.transforms.any(it.id == .squeeze) { squeeze++ }
			sections.delete_last()
			if _ := decode_modular_frame(file, frame, .signed32, mut sections) {
				assert false
			}
		}
		count++
	}
	assert count == 26
	assert grouped == 24
	assert permuted == 14 && multipass == 2 && lf_sections == 6
	assert lf_data == 2 && trees == 4 && squeeze == 4
	eprintln('JPEG XL fixture coverage: grouped=${grouped}, permuted=${permuted}, multipass=${multipass}, multiple-LF-groups=${lf_sections}, LF-data-files=${lf_data}, global-tree-files=${trees}, squeeze-files=${squeeze}')
}
