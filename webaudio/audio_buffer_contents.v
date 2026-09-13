// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rendering/AudioData's AudioBufferContents.
module webaudio

@[heap]
pub struct AudioBufferContents {
pub:
	channels    [][]f32
	sample_rate f32
}

pub fn (contents &AudioBufferContents) length() int {
	if contents.channels.len == 0 {
		return 0
	}
	return contents.channels[0].len
}

pub fn (contents &AudioBufferContents) duration() f64 {
	return f64(contents.length()) / f64(contents.sample_rate)
}
