// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/AudioBus.
module webaudio

import math

const speaker_left = 0
const speaker_right = 1
const speaker_center = 2
const speaker_surround_left = 4
const speaker_surround_right = 5

pub struct AudioBus {
mut:
	channels_    [][]f32
	frame_count_ int
}

pub fn AudioBus.create(channel_count int, frame_count int) &AudioBus {
	assert channel_count >= 0
	assert frame_count >= 0
	mut bus := &AudioBus{
		frame_count_: frame_count
	}
	bus.set_channel_count(channel_count)
	return bus
}

pub fn (bus &AudioBus) channel_count() int {
	return bus.channels_.len
}

pub fn (bus &AudioBus) frame_count() int {
	return bus.frame_count_
}

pub fn (bus &AudioBus) channel(index int) []f32 {
	return bus.channels_[index]
}

pub fn (mut bus AudioBus) set_channel(index int, samples []f32) {
	assert index >= 0 && index < bus.channels_.len
	assert samples.len == bus.frame_count_
	for frame, sample in samples {
		bus.channels_[index][frame] = sample
	}
}

pub fn (mut bus AudioBus) zero() {
	for channel in 0 .. bus.channels_.len {
		for frame in 0 .. bus.frame_count_ {
			bus.channels_[channel][frame] = 0
		}
	}
}

pub fn (bus &AudioBus) is_silent() bool {
	for channel in bus.channels_ {
		for sample in channel {
			if sample != 0 {
				return false
			}
		}
	}
	return true
}

// Changing the channel count replaces all sample storage, matching upstream's
// deliberate non-preserving resize.
pub fn (mut bus AudioBus) set_channel_count(channel_count int) {
	assert channel_count >= 0
	if bus.channels_.len == channel_count {
		return
	}
	bus.channels_ = [][]f32{len: channel_count, init: []f32{len: bus.frame_count_}}
}

pub fn (mut bus AudioBus) copy_from(source &AudioBus) {
	assert source.frame_count() == bus.frame_count()
	bus.set_channel_count(source.channel_count())
	for channel in 0 .. source.channel_count() {
		bus.set_channel(channel, source.channel(channel))
	}
}

pub fn (mut bus AudioBus) sum_from(source &AudioBus,
	channel_interpretation ChannelInterpretation) {
	assert source.frame_count() == bus.frame_count()
	if channel_interpretation == .speakers {
		bus.sum_from_speakers(source)
	} else {
		bus.sum_from_discrete(source)
	}
}

fn (mut bus AudioBus) sum_channel(source &AudioBus, destination_index int,
	source_index int, gain f32) {
	for frame in 0 .. bus.frame_count_ {
		bus.channels_[destination_index][frame] += source.channels_[source_index][frame] * gain
	}
}

// https://webaudio.github.io/web-audio-api/#UpMix-sub
// https://webaudio.github.io/web-audio-api/#down-mix
pub fn (mut bus AudioBus) sum_from_speakers(source &AudioBus) {
	source_channels := source.channel_count()
	destination_channels := bus.channel_count()
	if source_channels == destination_channels {
		for channel in 0 .. source_channels {
			bus.sum_channel(source, channel, channel, 1)
		}
		return
	}

	if source_channels == 1 && destination_channels == 2 {
		bus.sum_channel(source, speaker_left, 0, 1)
		bus.sum_channel(source, speaker_right, 0, 1)
		return
	}
	if source_channels == 1 && destination_channels == 4 {
		bus.sum_channel(source, speaker_left, 0, 1)
		bus.sum_channel(source, speaker_right, 0, 1)
		return
	}
	if source_channels == 1 && destination_channels == 6 {
		bus.sum_channel(source, speaker_center, 0, 1)
		return
	}
	if source_channels == 2 && destination_channels == 4 {
		bus.sum_channel(source, speaker_left, speaker_left, 1)
		bus.sum_channel(source, speaker_right, speaker_right, 1)
		return
	}
	if source_channels == 2 && destination_channels == 6 {
		bus.sum_channel(source, speaker_left, speaker_left, 1)
		bus.sum_channel(source, speaker_right, speaker_right, 1)
		return
	}
	if source_channels == 4 && destination_channels == 6 {
		bus.sum_channel(source, speaker_left, speaker_left, 1)
		bus.sum_channel(source, speaker_right, speaker_right, 1)
		bus.sum_channel(source, speaker_surround_left, 2, 1)
		bus.sum_channel(source, speaker_surround_right, 3, 1)
		return
	}

	if source_channels == 2 && destination_channels == 1 {
		bus.sum_channel(source, 0, speaker_left, 0.5)
		bus.sum_channel(source, 0, speaker_right, 0.5)
		return
	}
	if source_channels == 4 && destination_channels == 1 {
		for channel in 0 .. 4 {
			bus.sum_channel(source, 0, channel, 0.25)
		}
		return
	}
	if source_channels == 6 && destination_channels == 1 {
		sqrt_half := f32(math.sqrt(0.5))
		bus.sum_channel(source, 0, speaker_left, sqrt_half)
		bus.sum_channel(source, 0, speaker_right, sqrt_half)
		bus.sum_channel(source, 0, speaker_center, 1)
		bus.sum_channel(source, 0, speaker_surround_left, 0.5)
		bus.sum_channel(source, 0, speaker_surround_right, 0.5)
		return
	}
	if source_channels == 4 && destination_channels == 2 {
		bus.sum_channel(source, speaker_left, speaker_left, 0.5)
		bus.sum_channel(source, speaker_left, 2, 0.5)
		bus.sum_channel(source, speaker_right, speaker_right, 0.5)
		bus.sum_channel(source, speaker_right, 3, 0.5)
		return
	}
	if source_channels == 6 && destination_channels == 2 {
		sqrt_half := f32(math.sqrt(0.5))
		bus.sum_channel(source, speaker_left, speaker_left, 1)
		bus.sum_channel(source, speaker_left, speaker_center, sqrt_half)
		bus.sum_channel(source, speaker_left, speaker_surround_left, sqrt_half)
		bus.sum_channel(source, speaker_right, speaker_right, 1)
		bus.sum_channel(source, speaker_right, speaker_center, sqrt_half)
		bus.sum_channel(source, speaker_right, speaker_surround_right, sqrt_half)
		return
	}
	if source_channels == 6 && destination_channels == 4 {
		sqrt_half := f32(math.sqrt(0.5))
		bus.sum_channel(source, speaker_left, speaker_left, 1)
		bus.sum_channel(source, speaker_left, speaker_center, sqrt_half)
		bus.sum_channel(source, speaker_right, speaker_right, 1)
		bus.sum_channel(source, speaker_right, speaker_center, sqrt_half)
		bus.sum_channel(source, 2, speaker_surround_left, 1)
		bus.sum_channel(source, 3, speaker_surround_right, 1)
		return
	}

	bus.sum_from_discrete(source)
}

pub fn (mut bus AudioBus) sum_from_discrete(source &AudioBus) {
	channels_to_sum := min_int(source.channel_count(), bus.channel_count())
	for channel in 0 .. channels_to_sum {
		bus.sum_channel(source, channel, channel, 1)
	}
}
