// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct HfGroupMaps {
pub:
	width         int
	height        int
	raw_quant     []i32
	transform_ids []u8
	lf_contexts   []u8
}

pub struct HfGroupParameters {
pub:
	horizontal_shift [3]u32
	vertical_shift   [3]u32
	frame_passes     Passes
}

pub struct HfGroupInput {
pub:
	pass int
pub mut:
	reader BitReader
}

struct HfGroupBlock {
	x         int
	y         int
	transform HfTransform
	offset    int
}

struct HfGroupReaderState {
mut:
	symbols       SymbolReader
	nonzeros      [3]HfNonzeroMap
	histogram_set int
}

fn (maps HfGroupMaps) blocks(params HfGroupParameters, block_context BlockContextMap) ![]HfGroupBlock {
	if maps.width < 1 || maps.width > 32 || maps.height < 1 || maps.height > 32
		|| maps.raw_quant.len != maps.width * maps.height || maps.transform_ids.len != maps.raw_quant.len
		|| maps.lf_contexts.len != maps.raw_quant.len || params.horizontal_shift.any(it > 1)
		|| params.vertical_shift.any(it > 1) {
		return error('Invalid JPEG XL HF group geometry')
	}
	block_context.block_context(0, 0, 0, 0)!
	for context in block_context.context_map {
		if int(context) >= block_context.num_contexts { return error('Invalid JPEG XL HF block context map') }
	}
	mut covered := []bool{len: maps.raw_quant.len}
	mut blocks := []HfGroupBlock{}
	mut offset := 0
	for y in 0 .. maps.height {
		for x in 0 .. maps.width {
			index := y * maps.width + x
			id := maps.transform_ids[index]
			if id < 128 {
				if !covered[index] { return error('Incomplete JPEG XL HF transform coverage') }
				continue
			}
			transform := hf_transform_from_id(int(id & 127))!
			dims := transform.covered_blocks()
			if dims[0] > maps.width - x || dims[1] > maps.height - y || maps.raw_quant[index] <= 0
				|| int(maps.lf_contexts[index]) >= block_context.num_lf_contexts {
				return error('Invalid JPEG XL HF transform extent or parameters')
			}
			for c in 0 .. 3 {
				h := params.horizontal_shift[c]
				v := params.vertical_shift[c]
				if ((x >> h) << h) != x || ((y >> v) << v) != y { continue }
				if dims[0] > (maps.width >> h) - (x >> h) || dims[1] > (maps.height >> v) - (y >> v) {
					return error('Invalid JPEG XL subsampled HF transform extent')
				}
			}
			for iy in 0 .. dims[1] {
				for ix in 0 .. dims[0] {
					p := (y + iy) * maps.width + x + ix
					if covered[p] { return error('Overlapping JPEG XL HF transforms') }
					covered[p] = true
				}
			}
			blocks << HfGroupBlock{ x: x, y: y, transform: transform, offset: offset }
			offset += dims[0] * dims[1] * 64
		}
	}
	return blocks
}

// Buffers use the source's sequential transform order, with a full-sized slot
// for each component even where chroma alignment skips that component. Inputs
// expose their cursors on success or failure; buffers retain prior pass values.
pub fn decode_hf_group(maps HfGroupMaps, params HfGroupParameters, block_context BlockContextMap, global HfPasses, mut inputs []HfGroupInput, mut coefficients [3][]i32) ! {
	if global.histogram_sets < 1 || global.histogram_sets > 65536 || global.passes.len < 1
		|| global.passes.len > 11 || int(params.frame_passes.count) != global.passes.len
		|| params.frame_passes.shifts.len > global.passes.len - 1 || params.frame_passes.shifts.any(it > 3) {
		return error('Invalid JPEG XL HF group passes')
	}
	blocks := maps.blocks(params, block_context)!
	for pass in global.passes {
		if pass.coefficient_orders.len != coefficient_order_count * 3 {
			return error('Invalid JPEG XL HF group coefficient orders')
		}
	}
	for channel in coefficients {
		if channel.len != maps.width * maps.height * 64 { return error('Invalid JPEG XL HF group coefficient buffer') }
		if global.coefficient_storage == .signed16 {
			for value in channel {
				if value < -32768 || value > 32767 { return error('Invalid JPEG XL signed16 HF group buffer') }
			}
		}
	}
	for input in inputs {
		if input.pass < 0 || input.pass >= global.passes.len { return error('Invalid JPEG XL HF input pass') }
	}
	mut states := []HfGroupReaderState{cap: inputs.len}
	for i in 0 .. inputs.len {
		set := int(inputs[i].reader.read(ceil_log2(int(global.histogram_sets)))!)
		if set >= int(global.histogram_sets) { return error('Invalid JPEG XL HF histogram set index') }
		symbols := SymbolReader.new(global.passes[inputs[i].pass].histograms, mut inputs[i].reader, none)!
		states << HfGroupReaderState{
			symbols: symbols
			histogram_set: set
			nonzeros: [HfNonzeroMap.new(maps.width >> params.horizontal_shift[0], maps.height >> params.vertical_shift[0])!,
				HfNonzeroMap.new(maps.width >> params.horizontal_shift[1], maps.height >> params.vertical_shift[1])!,
				HfNonzeroMap.new(maps.width >> params.horizontal_shift[2], maps.height >> params.vertical_shift[2])!]!
		}
	}
	for block in blocks {
		dims := block.transform.covered_blocks()
		count := dims[0] * dims[1] * 64
		p := block.y * maps.width + block.x
		if params.frame_passes.count == 1 {
			for c in 0 .. 3 {
				for k in block.offset .. block.offset + count { coefficients[c][k] = 0 }
			}
		}
		for i in 0 .. states.len {
			pass_index := inputs[i].pass
			pass := global.passes[pass_index]
			context_offset := states[i].histogram_set * block_context.num_ac_contexts()
			shift := if pass_index < params.frame_passes.shifts.len { params.frame_passes.shifts[pass_index] } else { u32(0) }
			for c in [1, 0, 2] {
				x := block.x >> params.horizontal_shift[c]
				y := block.y >> params.vertical_shift[c]
				if (x << params.horizontal_shift[c]) != block.x || (y << params.vertical_shift[c]) != block.y { continue }
				prediction := states[i].nonzeros[c].predict_nonzeros(x, y)!
				context := block_context.block_context(int(maps.lf_contexts[p]), u32(maps.raw_quant[p]), block.transform.shape_id(), c)!
				nonzero_context := context_offset + block_context.nonzero_context(prediction, context)!
				nonzeros := states[i].symbols.read_unsigned(pass.histograms, nonzero_context, mut inputs[i].reader)!
				if nonzeros > u32(count - dims[0] * dims[1]) { return error('Invalid JPEG XL HF nonzero count') }
				states[i].nonzeros[c].record_block(x, y, block.transform, nonzeros)!
				channel_params := HfChannelParameters{
					transform: block.transform
					storage: global.coefficient_storage
					shift: shift
					nonzeros: nonzeros
					histogram_offset: context_offset + block_context.zero_density_context_offset(context)!
				}
				// This bounded view borrows one stable component allocation. Neither
				// the group nor the channel decoder resizes that allocation.
				mut channel := unsafe { coefficients[c][block.offset..block.offset + count] }
				decode_hf_channel(channel_params, pass.coefficient_orders[block.transform.shape_id() * 3 + c], pass.histograms,
					mut inputs[i].reader, mut states[i].symbols, mut channel)!
			}
		}
	}
	for i in 0 .. states.len {
		states[i].symbols.check_final_state(global.passes[inputs[i].pass].histograms, &inputs[i].reader)!
	}
}
