// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AnimationPlaybackEvent.{h,cpp,idl}.
module animations

import dom

pub struct AnimationPlaybackEventInit {
	dom.EventInit
pub mut:
	current_time  ?CSSNumberish
	timeline_time ?CSSNumberish
}

@[heap]
pub struct AnimationPlaybackEvent {
	dom.Event
pub mut:
	current_time_  ?CSSNumberish
	timeline_time_ ?CSSNumberish
}

pub fn AnimationPlaybackEvent.create(event_name string, init AnimationPlaybackEventInit) &AnimationPlaybackEvent {
	return &AnimationPlaybackEvent{
		Event:          dom.Event{
			interface_:   .animation_playback_event
			type_:        event_name
			bubbles_:     init.bubbles
			cancelable_:  init.cancelable
			composed_:    init.composed
			initialized_: true
		}
		current_time_:  init.current_time
		timeline_time_: init.timeline_time
	}
}

pub fn AnimationPlaybackEvent.construct_impl(event_name string, init AnimationPlaybackEventInit) !&AnimationPlaybackEvent {
	return AnimationPlaybackEvent.create(event_name, init)
}

pub fn AnimationPlaybackEvent.to_numberish_internal(value ?CSSNumberish) ?CSSNumberish {
	return value
}

pub fn AnimationPlaybackEvent.to_nullable_numberish(value ?CSSNumberish) NullableCSSNumberish {
	return NullableCSSNumberish{
		value: value
	}
}

pub fn (event &AnimationPlaybackEvent) current_time() ?CSSNumberish {
	return event.current_time_
}

pub fn (event &AnimationPlaybackEvent) timeline_time() ?CSSNumberish {
	return event.timeline_time_
}
