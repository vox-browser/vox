// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct ModularChannelInfo {
pub:
	width               int
	height              int
	shift               ?ModularShift
	bit_depth           BitDepth
	output_channel      ?u32
	followed_by_palette bool
}

fn (info ModularChannelInfo) equivalent(other ModularChannelInfo) bool {
	return info.width == other.width && info.height == other.height && info.shift == other.shift
		&& info.bit_depth == other.bit_depth
}

fn (info ModularChannelInfo) allocated() ModularChannelInfo {
	if info.width == 0 || info.height == 0 {
		return ModularChannelInfo{ ...info, width: 0, height: 0 }
	}
	return info
}

pub enum ModularStepKind {
	rct
	palette
	horizontal_squeeze
	vertical_squeeze
}

pub struct ModularTransformStep {
pub:
	kind       ModularStepKind
	inputs     []int
	outputs    []int
	rct_type   u32
	num_deltas u32
	predictor  Predictor
	weighted   WeightedPredictorHeader
}

pub struct ModularPlanLimits {
pub:
	max_channels        int = 65536
	max_palette_samples u64 = 67108864
	max_buffers         int = 1048576
}

pub struct ModularTransformPlan {
pub:
	outputs []int
pub mut:
	buffers         []ModularChannelInfo
	coded           []int
	steps           []ModularTransformStep
	palette_samples u64
}

struct ModularPlannedChannel {
	buffer int
	info   ModularChannelInfo
}

fn (mut plan ModularTransformPlan) add_buffer(info ModularChannelInfo, limits ModularPlanLimits) !int {
	if plan.buffers.len >= limits.max_buffers {
		return error('JPEG XL transform buffer limit exceeded')
	}
	modular_sample_count(info.width, info.height)!
	plan.buffers << info
	return plan.buffers.len - 1
}

fn check_modular_channel_range(channels []ModularPlannedChannel, first int, count int) ! {
	if first < 0 || count <= 0 || first > channels.len || count > channels.len - first {
		return error('Invalid JPEG XL transform channel range')
	}
	for i in first + 1 .. first + count {
		if !channels[first].info.equivalent(channels[i].info) {
			return error('JPEG XL transform mixes different channel shapes, shifts or depths')
		}
	}
}

pub fn default_modular_squeeze(channels []ModularChannelInfo) ![]SqueezeParams {
	if channels.len > 65536 { return error('Too many JPEG XL squeeze channels') }
	mut meta := 0
	for meta < channels.len && channels[meta].shift == none { meta++ }
	if meta == channels.len { return error('JPEG XL automatic squeeze needs a data channel') }
	mut width := channels[meta].width
	mut height := channels[meta].height
	modular_sample_count(width, height)!
	count := channels.len - meta
	mut result := []SqueezeParams{}
	if count > 2 && channels[meta + 1].width == width && channels[meta + 1].height == height {
		if width > 1 {
			result << SqueezeParams{ horizontal: true, begin_channel: u32(meta + 1), num_channels: 2 }
		}
		if height > 1 { result << SqueezeParams{ begin_channel: u32(meta + 1), num_channels: 2 } }
	}
	if width <= height && height > 8 {
		result << SqueezeParams{ in_place: true, begin_channel: u32(meta), num_channels: u32(count) }
		height = (height + 1) / 2
	}
	for width > 8 || height > 8 {
		if width > 8 {
			result << SqueezeParams{ horizontal: true, in_place: true, begin_channel: u32(meta), num_channels: u32(count) }
			width = (width + 1) / 2
		}
		if height > 8 {
			result << SqueezeParams{ in_place: true, begin_channel: u32(meta), num_channels: u32(count) }
			height = (height + 1) / 2
		}
	}
	return result
}

fn (mut plan ModularTransformPlan) apply_transform(transform ModularTransform, header ModularGroupHeader, mut channels []ModularPlannedChannel, limits ModularPlanLimits) ! {
	begin := int(transform.begin_channel)
	match transform.id {
		.rct {
			if transform.rct_type >= 42 {
				return error('Invalid JPEG XL reversible color transform')
			}
			check_modular_channel_range(channels, begin, 3)!
			mut inputs := []int{}
			mut outputs := []int{}
			for i in begin .. begin + 3 {
				outputs << channels[i].buffer
				info := ModularChannelInfo{ ...channels[i].info, output_channel: none }
				buffer := plan.add_buffer(info, limits)!
				inputs << buffer
				channels[i] = ModularPlannedChannel{ buffer: buffer, info: info }
			}
			plan.steps << ModularTransformStep{ kind: .rct, inputs: inputs, outputs: outputs, rct_type: transform.rct_type }
		}
		.palette {
			count := int(transform.num_channels)
			check_modular_channel_range(channels, begin, count)!
			predictor := predictor_from_id(transform.predictor_id)!
			colors := u64(transform.num_colors) + u64(transform.num_deltas)
			samples := colors * u64(count)
			if samples > limits.max_palette_samples || plan.palette_samples > limits.max_palette_samples - samples {
				return error('JPEG XL cumulative palette limit exceeded')
			}
			plan.palette_samples += samples
			base := channels[begin].info
			palette := ModularChannelInfo{ width: int(colors), height: count, bit_depth: base.bit_depth }
			palette_id := plan.add_buffer(palette, limits)!
			index_info := ModularChannelInfo{ ...base, output_channel: none, followed_by_palette: true }
			index_id := plan.add_buffer(index_info, limits)!
			outputs := channels[begin..begin + count].map(it.buffer)
			plan.steps << ModularTransformStep{ kind: .palette, inputs: [index_id, palette_id], outputs: outputs, num_deltas: transform.num_deltas, predictor: predictor, weighted: header.weighted }
			channels.delete_many(begin + 1, count - 1)
			channels[begin] = ModularPlannedChannel{ buffer: index_id, info: index_info }
			channels.insert(0, ModularPlannedChannel{ buffer: palette_id, info: palette })
		}
		.squeeze {
			steps := if transform.squeezes.len == 0 {
				default_modular_squeeze(channels.map(it.info))!
			} else {
				transform.squeezes
			}
			for step in steps {
				first := int(step.begin_channel)
				count := int(step.num_channels)
				if first > channels.len || count <= 0 || count > channels.len - first {
					return error('Invalid JPEG XL squeeze channel range')
				}
				last := first + count
				meta := channels[first].info.shift == none
				if meta != (channels[last - 1].info.shift == none) || (meta && !step.in_place) {
					return error('Invalid JPEG XL meta-channel squeeze')
				}
				offset := if step.in_place { last } else { channels.len }
				for i in 0 .. count {
					original := channels[first + i]
					mut shift := original.info.shift
					if value := shift {
						if value.horizontal > 30 || value.vertical > 30 {
							return error('Too many JPEG XL squeezes')
						}
						shift = if step.horizontal {
							ModularShift{ horizontal: value.horizontal + 1, vertical: value.vertical }
						} else {
							ModularShift{ horizontal: value.horizontal, vertical: value.vertical + 1 }
						}
					}
					average := ModularChannelInfo{
						...original.info
						width:          if step.horizontal {
							(original.info.width + 1) / 2
						} else {
							original.info.width
						}
						height:         if step.horizontal {
							original.info.height
						} else {
							(original.info.height + 1) / 2
						}
						shift:          shift
						output_channel: none
					}
					residual := ModularChannelInfo{
						...average
						width:  if step.horizontal {
							original.info.width - average.width
						} else {
							average.width
						}
						height: if step.horizontal {
							average.height
						} else {
							original.info.height - average.height
						}
					}
					average_id := plan.add_buffer(average, limits)!
					residual_id := plan.add_buffer(residual, limits)!
					plan.steps << ModularTransformStep{
						kind:    if step.horizontal {
							.horizontal_squeeze
						} else {
							.vertical_squeeze
						}
						inputs:  [average_id, residual_id]
						outputs: [original.buffer]
					}
					channels[first + i] = ModularPlannedChannel{ buffer: average_id, info: average }
					channels.insert(offset + i, ModularPlannedChannel{ buffer: residual_id, info: residual })
					if channels.len > limits.max_channels {
						return error('JPEG XL coded channel limit exceeded')
					}
				}
			}
		}
		.invalid { return error('Invalid JPEG XL modular transform') }
	}
}

pub fn plan_modular_transforms(input []ModularChannelInfo, header ModularGroupHeader, limits ModularPlanLimits) !ModularTransformPlan {
	if limits.max_channels < 0 || limits.max_channels > 65536 || limits.max_buffers < 0
		|| limits.max_buffers > 1048576 || input.len > limits.max_channels {
		return error('Invalid JPEG XL transform planning limits')
	}
	mut plan := ModularTransformPlan{ outputs: []int{len: input.len, init: index} }
	mut channels := []ModularPlannedChannel{cap: input.len}
	for info in input {
		buffer := plan.add_buffer(info, limits)!
		channels << ModularPlannedChannel{ buffer: buffer, info: info }
	}
	for transform in header.transforms {
		plan.apply_transform(transform, header, mut channels, limits)!
		if channels.len > limits.max_channels {
			return error('JPEG XL coded channel limit exceeded')
		}
	}
	plan.coded = channels.map(it.buffer)
	return plan
}
