// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// Copyright (c) 2026, Sam Atkins <sam@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/TrackEvent.cpp.
// Unlike the other HTML-spec events (which live in dom/html_events.v), TrackEvent
// references the html-module track types (VideoTrack/AudioTrack/TextTrack), so it
// lives here and embeds dom.Event directly. It still sets a distinct
// dom.EventInterface (.track_event) so a base &dom.Event can be identified as one.
module html

import dom

// The C++ Variant<Empty, GC::Ref<VideoTrack>, GC::Ref<AudioTrack>, GC::Ref<TextTrack>>.
// V sum types can't hold reference members, so it is modelled as a discriminated struct;
// `.empty` is the Empty alternative.
pub enum TrackEventTrackKind {
	empty
	video
	audio
	text
}

pub struct TrackEventTrack {
pub:
	kind  TrackEventTrackKind = .empty
	video ?&VideoTrack
	audio ?&AudioTrack
	text  ?&TextTrack
}

pub fn track_event_to_track_type_internal(track TrackEventTrack) TrackEventTrack {
	return track
}

pub fn TrackEventTrack.from_video(track &VideoTrack) TrackEventTrack {
	return TrackEventTrack{
		kind:  .video
		video: track
	}
}

pub fn TrackEventTrack.from_audio(track &AudioTrack) TrackEventTrack {
	return TrackEventTrack{
		kind:  .audio
		audio: track
	}
}

pub fn TrackEventTrack.from_text(track &TextTrack) TrackEventTrack {
	return TrackEventTrack{
		kind: .text
		text: track
	}
}

pub struct TrackEventInit {
	dom.EventInit
pub mut:
	track TrackEventTrack
}

@[heap]
pub struct TrackEvent {
	dom.Event
mut:
	track_ TrackEventTrack
}

pub fn TrackEvent.create(event_name string, event_init TrackEventInit) &TrackEvent {
	return &TrackEvent{
		Event:  dom.Event{
			interface_:   .track_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
		track_: track_event_to_track_type_internal(event_init.track)
	}
}

pub fn TrackEvent.construct_impl(event_name string, event_init TrackEventInit) !&TrackEvent {
	return TrackEvent.create(event_name, event_init)
}

// https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track
pub fn (e &TrackEvent) track() TrackEventTrack {
	return e.track_
}
