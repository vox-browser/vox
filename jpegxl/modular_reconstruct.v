// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

fn (plan ModularTransformPlan) validate_graph() ! {
	if plan.buffers.len > 1048576 || plan.coded.len > 65536 || plan.outputs.len > 65536 {
		return error('Invalid JPEG XL transform graph size')
	}
	mut ready := []bool{len: plan.buffers.len}
	for info in plan.buffers { modular_sample_count(info.width, info.height)! }
	for id in plan.coded {
		if id < 0 || id >= ready.len || ready[id] {
			return error('Invalid JPEG XL coded buffer identity')
		}
		ready[id] = true
	}
	for i := plan.steps.len - 1; i >= 0; i-- {
		step := plan.steps[i]
		valid_shape := match step.kind {
			.rct { step.inputs.len == 3 && step.outputs.len == 3 && step.rct_type < 42 }
			.palette { step.inputs.len == 2 && step.outputs.len > 0 }
			.horizontal_squeeze, .vertical_squeeze { step.inputs.len == 2 && step.outputs.len == 1 }
		}
		if !valid_shape { return error('Invalid JPEG XL transform step') }
		for id in step.inputs {
			if id < 0 || id >= ready.len || !ready[id] {
				return error('Unavailable JPEG XL transform input')
			}
			ready[id] = false
		}
		for id in step.outputs {
			if id < 0 || id >= ready.len || ready[id] {
				return error('Invalid JPEG XL transform output')
			}
			ready[id] = true
		}
	}
	for id in plan.outputs {
		if id < 0 || id >= ready.len || !ready[id] {
			return error('Missing JPEG XL output channel')
		}
		ready[id] = false
	}
}

pub fn (plan ModularTransformPlan) allocate_coded_channels() ![]ModularChannel {
	plan.validate_graph()!
	mut total := u64(0)
	for id in plan.coded {
		info := plan.buffers[id]
		total += u64(info.width) * u64(info.height)
		if total > 67108864 { return error('JPEG XL coded sample limit exceeded') }
	}
	mut result := []ModularChannel{cap: plan.coded.len}
	for id in plan.coded {
		info := plan.buffers[id].allocated()
		result << ModularChannel.new(info.width, info.height, info.shift)!
	}
	return result
}

fn (channel ModularChannel) matches_info(info ModularChannelInfo) ! {
	channel.validate()!
	allocated := info.allocated()
	if channel.width != allocated.width || channel.height != allocated.height || channel.shift != allocated.shift {
		return error('JPEG XL channel does not match transform buffer metadata')
	}
}

fn take_modular_buffer(mut buffers []ModularChannel, index int) ModularChannel {
	result := buffers[index]
	buffers[index] = ModularChannel{}
	return result
}

// Returns independently owned output samples; coded caller buffers are preserved.
pub fn (plan ModularTransformPlan) reconstruct(coded []ModularChannel, storage ModularStorage) ![]ModularChannel {
	plan.validate_graph()!
	if coded.len != plan.coded.len { return error('Incorrect JPEG XL coded channel count') }
	mut total := u64(0)
	for i, id in plan.coded {
		coded[i].matches_info(plan.buffers[id])!
		total += u64(coded[i].samples.len)
		if total > 67108864 { return error('JPEG XL coded sample limit exceeded') }
	}
	mut buffers := []ModularChannel{len: plan.buffers.len}
	for i, id in plan.coded {
		buffers[id] = ModularChannel{ ...coded[i], samples: coded[i].samples.clone() }
	}
	for s := plan.steps.len - 1; s >= 0; s-- {
		step := plan.steps[s]
		match step.kind {
			.rct {
				mut first := take_modular_buffer(mut buffers, step.inputs[0])
				mut second := take_modular_buffer(mut buffers, step.inputs[1])
				mut third := take_modular_buffer(mut buffers, step.inputs[2])
				if first.width != second.width || first.width != third.width || first.height != second.height || first.height != third.height {
					return error('Incompatible JPEG XL RCT buffers')
				}
				for x in 0 .. first.samples.len {
					if storage == .signed16 {
						out := rct_sample16(step.rct_type, i16(first.samples[x]), i16(second.samples[x]), i16(third.samples[x]))
						first.samples[x] = out[0]
						second.samples[x] = out[1]
						third.samples[x] = out[2]
					} else {
						out := rct_sample32(step.rct_type, first.samples[x], second.samples[x], third.samples[x])
						first.samples[x] = out[0]
						second.samples[x] = out[1]
						third.samples[x] = out[2]
					}
				}
				buffers[step.outputs[0]] = first
				buffers[step.outputs[1]] = second
				buffers[step.outputs[2]] = third
			}
			.palette {
				indices := take_modular_buffer(mut buffers, step.inputs[0])
				palette := take_modular_buffer(mut buffers, step.inputs[1])
				depths := step.outputs.map(plan.buffers[it].bit_depth.bits_per_sample)
				out := inverse_modular_palette(indices, palette, depths, step.num_deltas, step.predictor, step.weighted, storage, false)!
				for i, id in step.outputs { buffers[id] = out[i] }
			}
			.horizontal_squeeze, .vertical_squeeze {
				average := take_modular_buffer(mut buffers, step.inputs[0])
				residual := take_modular_buffer(mut buffers, step.inputs[1])
				id := step.outputs[0]
				output_info := plan.buffers[id].allocated()
				if output_info.width == 0 || output_info.height == 0 {
					if average.samples.len != 0 || residual.samples.len != 0 {
						return error('Incompatible JPEG XL empty squeeze buffers')
					}
					buffers[id] = ModularChannel.new(output_info.width, output_info.height, output_info.shift)!
				} else {
					// Empty allocated buffers have shape 0x0. The inverse still
					// needs their logical width/height to validate a singleton axis.
					average_info := plan.buffers[step.inputs[0]]
					residual_info := plan.buffers[step.inputs[1]]
					buffers[id] = inverse_modular_squeeze(ModularChannel{ ...average, width: average_info.width, height: average_info.height },
						ModularChannel{ ...residual, width: residual_info.width, height: residual_info.height },
						step.kind == .horizontal_squeeze, storage, output_info.shift)!
				}
			}
		}
		for id in step.outputs { buffers[id].matches_info(plan.buffers[id])! }
	}
	total = 0
	for id in plan.outputs {
		total += u64(buffers[id].samples.len)
		if total > 67108864 { return error('JPEG XL output sample limit exceeded') }
	}
	mut result := []ModularChannel{cap: plan.outputs.len}
	for id in plan.outputs { result << take_modular_buffer(mut buffers, id) }
	return result
}
