// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct ModularFramePlanes {
pub:
	quantization LfQuantFactors
	channels     []ModularChannel
	noise        ?NoiseParams
	patches      ?PatchesDictionary
}

fn finish_modular_section(mut reader BitReader, index int, unused bool) ! {
	// The pinned decoder bounds every section and rejects over-reads, but it
	// never requires a section to be fully consumed. Encoders may leave an
	// empty entropy stream when no pixels are coded, and valid streams can
	// carry trailing bits after the last symbol; both are ignored.
	_ = index
	_ = unused
	reader.skip(reader.available_bits())!
}

fn decode_modular_group_bucket(mut reader BitReader, frame FrameHeader, infos []ModularChannelInfo, indices []int, lf bool, group u64, stream u32, tree ?ModularTree, storage ModularStorage, mut coded []ModularChannel, mut written []u64) !bool {
	mut selected := []int{}
	mut tiles := []ModularTile{}
	mut inputs := []ModularChannelInfo{}
	for c in indices {
		tile := modular_group_tile(infos[c], frame, lf, group)!
		// Source group allocation omits empty tiles from channel numbering.
		if tile.width == 0 && tile.height == 0 { continue }
		selected << c
		tiles << tile
		inputs << ModularChannelInfo{ ...infos[c], width: tile.width, height: tile.height }
	}
	decoded := reader.decode_modular_stream(inputs, storage, stream, none, tree)!
	for i, c in selected {
		tile := tiles[i]
		decoded[i].matches_info(inputs[i])!
		for y in 0 .. tile.height {
			for x in 0 .. tile.width {
				coded[c].samples[(tile.y + y) * coded[c].width + tile.x + x] = decoded[i].samples[y * tile.width + x]
			}
		}
		written[c] += u64(decoded[i].samples.len)
	}
	return inputs.len == 0
}

// Decode whole raw modular planes by stitching coded tiles before reversing
// global transforms. Rendering, partial recovery and frame composition are separate.
pub fn decode_modular_frame(file FileHeader, frame FrameHeader, storage ModularStorage, mut sections []BitReader) !ModularFramePlanes {
	return decode_modular_frame_refs(file, frame, storage, []PatchReferenceInfo{}, mut sections)
}

pub fn decode_modular_frame_refs(file FileHeader, frame FrameHeader, storage ModularStorage, patch_refs []PatchReferenceInfo, mut sections []BitReader) !ModularFramePlanes {
	validate_modular_group_geometry(frame)!
	if frame.num_toc_entries() > u64(max_permutation_entries) || sections.len != int(frame.num_toc_entries()) {
		return error('Incorrect JPEG XL modular frame section count')
	}
	global := sections[0].read_modular_global_plan_refs(file, frame, patch_refs)!
	mut state := new_modular_frame_state(global.plan, frame)!
	unused_global := state.read_global(mut sections[0], global.header, global.tree, storage)!
	combined := sections.len == 1
	if !combined {
		finish_modular_section(mut sections[0], 0, unused_global)!
	}
	for group in u64(0) .. frame.num_lf_groups() {
		index := if combined { 0 } else { 1 + int(group) }
		unused := state.read_group(mut sections[index], frame, true, group, 0, global.tree, storage)!
		if !combined { finish_modular_section(mut sections[index], index, unused)! }
	}
	// Modular HF-global has no payload.
	if !combined {
		finish_modular_section(mut sections[1 + int(frame.num_lf_groups())], 1 + int(frame.num_lf_groups()), true)!
	}
	for pass in 0 .. int(frame.passes.count) {
		for group in u64(0) .. frame.num_groups() {
			index := if combined {
				0
			} else {
				2 + int(frame.num_lf_groups()) + pass * int(frame.num_groups()) + int(group)
			}
			unused := state.read_group(mut sections[index], frame, false, group, pass, global.tree, storage)!
			if !combined { finish_modular_section(mut sections[index], index, unused)! }
		}
	}
	if combined { finish_modular_section(mut sections[0], 0, false)! }
	return ModularFramePlanes{ quantization: global.quantization, channels: state.reconstruct(storage)!, noise: global.noise, patches: global.patches }
}
