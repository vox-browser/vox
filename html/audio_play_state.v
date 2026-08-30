// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/AudioPlayState.h.
module html

pub enum AudioPlayState {
	paused
	playing
}

pub enum MuteState {
	muted
	unmuted
}

pub fn invert_mute_state(mute_state MuteState) MuteState {
	return match mute_state {
		.muted { .unmuted }
		.unmuted { .muted }
	}
}
