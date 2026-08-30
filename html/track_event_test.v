module html

import dom

fn test_track_event_empty_by_default() {
	e := TrackEvent.create('addtrack', TrackEventInit{})
	assert e.interface_ == .track_event
	assert e.track().kind == .empty
	// Base Event fields are threaded through.
	assert e.type_ == 'addtrack'
	assert track_event_to_track_type_internal(TrackEventTrack{}).kind == .empty
}

fn test_track_event_holds_text_track() {
	mut track := TextTrack.create()
	track.set_id('captions-1')
	e := TrackEvent.create('addtrack', TrackEventInit{
		bubbles: true
		track:   TrackEventTrack.from_text(track)
	})
	got := e.track()
	assert got.kind == .text
	assert got.text?.id() == 'captions-1'
	assert e.bubbles_ == true
}

fn test_track_event_variant_constructors() {
	audio := AudioTrack.create(MediaTrackMetadata{ identifier: 7 }, fn () {},
		fn (track &AudioTrack, enabled bool) {})
	e := TrackEvent.create('change', TrackEventInit{
		track: TrackEventTrack.from_audio(audio)
	})
	assert e.track().kind == .audio
	assert e.track().audio?.base.id == '7'

	_ = dom.EventInterface.track_event
}
