// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

// Coded modular buffers are shared by global/LF/HF sections. Reconstruct only
// after every assigned tile has arrived, including VarDCT extra channels.
struct ModularFrameState {
	plan ModularTransformPlan
	infos []ModularChannelInfo
	buckets [][]int
mut:
	coded []ModularChannel
	written []u64
}

fn new_modular_frame_state(plan ModularTransformPlan, frame FrameHeader) !ModularFrameState {
	infos := plan.coded.map(plan.buffers[it])
	buckets := plan_modular_sections(infos, frame)!
	mut assigned := []int{len: infos.len}
	for bucket in buckets { for c in bucket { assigned[c]++ } }
	if assigned.any(it != 1) { return error('JPEG XL coded channel has no unique section') }
	return ModularFrameState{ plan: plan, infos: infos, buckets: buckets,
		coded: plan.allocate_coded_channels()!, written: []u64{len: infos.len} }
}

fn (mut state ModularFrameState) read_global(mut reader BitReader, header ?ModularGroupHeader, tree ?ModularTree, storage ModularStorage) !bool {
	selected := state.buckets[0].filter(state.infos[it].width != 0 || state.infos[it].height != 0)
	inputs := selected.map(state.infos[it].allocated())
	decoded := reader.decode_modular_stream(inputs, storage, 0, header, tree)!
	for i,c in selected {
		decoded[i].matches_info(state.infos[c])!
		state.coded[c] = decoded[i]
		state.written[c] = u64(decoded[i].samples.len)
	}
	return inputs.all(it.width == 0 || it.height == 0)
}

fn (mut state ModularFrameState) read_group(mut reader BitReader, frame FrameHeader, lf bool, group u64, pass int, tree ?ModularTree, storage ModularStorage) !bool {
	if !lf && (pass < 0 || pass >= int(frame.passes.count)) { return error('Invalid JPEG XL modular frame pass') }
	bucket := if lf { 1 } else { 2 + pass }
	stream := if lf { frame.modular_lf_stream_id(group)! } else { frame.modular_hf_stream_id(pass, group)! }
	return decode_modular_group_bucket(mut reader, frame, state.infos, state.buckets[bucket], lf, group, stream, tree, storage, mut state.coded, mut state.written)
}

fn (state ModularFrameState) reconstruct(storage ModularStorage) ![]ModularChannel {
	for c,channel in state.coded {
		if state.written[c] != u64(channel.samples.len) { return error('Incomplete JPEG XL modular channel tiles') }
	}
	return state.plan.reconstruct(state.coded, storage)
}
