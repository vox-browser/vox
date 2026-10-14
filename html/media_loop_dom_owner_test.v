module html

import dom

fn media_loop_dom_drain_owner(media &HTMLMediaElement) {
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		event_loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_loop_reflection_reads_live_dom_preserves_adoption_and_keeps_ownerless_fallback() {
	mut source := parse_document('<!doctype html><video id="loop-parsed" loop="false"></video><audio id="loop-absent"></audio>')
	mut destination := dom.Document.create(dom.URL{ value: 'https://media-loop-adopted.example.test/' })
	defer {
		source.finalize()
		destination.finalize()
	}
	mut video_element := source.get_element_by_id('loop-parsed')?
	mut audio_element := source.get_element_by_id('loop-absent')?
	mut video := html_media_element_for_dom_element(video_element)?
	mut audio := html_media_element_for_dom_element(audio_element)?
	assert video.loop() && video_element.get_attribute('loop')? == 'false' && !audio.loop()
	video_element.remove_attribute('loop')
	assert !video.loop()
	video_element.set_attribute_value('loop', 'manual nonempty value')
	assert video.loop() && video_element.get_attribute('loop')? == 'manual nonempty value'
	video.set_loop(true)
	assert video.loop() && video_element.get_attribute('loop')? == ''
	video.set_loop(false)
	assert !video.loop() && !video_element.has_attribute('loop')
	audio.set_loop(true)
	assert audio.loop() && audio_element.get_attribute('loop')? == ''
	audio_element.remove_attribute('loop')
	assert !audio.loop()
	audio_element.set_attribute_value('loop', 'survives adoption')
	destination.adopt_node(audio_element.as_node())
	assert voidptr(audio_element.document()) == voidptr(destination)
	assert voidptr(html_media_element_for_dom_element(audio_element)?) == voidptr(audio)
	assert audio.loop() && audio_element.get_attribute('loop')? == 'survives adoption'
	audio_element.remove_attribute('loop')
	assert !audio.loop()
	audio.set_loop(true)
	assert audio.loop() && audio_element.get_attribute('loop')? == ''
	audio.set_loop(false)
	assert !audio.loop() && !audio_element.has_attribute('loop')
	for media in [video, audio] {
		assert media.paused() && !media.ended() && !media.seeking()
		assert media.current_time() == 0 && media.current_src() == ''
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['play', 'pause', 'ended', 'loadstart'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert !fallback.loop()
	fallback.set_loop(true)
	assert fallback.loop() && fallback.loop_
	fallback.set_loop(false)
	assert !fallback.loop() && !fallback.loop_
	assert fallback.paused() && fallback.current_time() == 0 && fallback.queued_media_task_ids_.len == 0
}

fn test_media_loop_endpoint_captures_live_presence_honors_paused_guard_and_preserves_cached_nonloop_end() {
	mut document := parse_document('<!doctype html><video id="loop-active"></video><audio id="loop-paused"></audio>')
	_ := WindowModel.create_top_level(document, none, 'media-loop-endpoint-owner')!
	defer { document.finalize() }
	mut active_element := document.get_element_by_id('loop-active')?
	mut paused_element := document.get_element_by_id('loop-paused')?
	mut active := html_media_element_for_dom_element(active_element)?
	mut paused := html_media_element_for_dom_element(paused_element)?
	for item in [active, paused] {
		mut media := unsafe { &HTMLMediaElement(item) }
		media.set_ready_state(.have_metadata)
		media.set_duration(1)
		media.seekable_.add_range(0, 1)
		media_loop_dom_drain_owner(media)
	}
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert document.is_fully_active() && !active.ended() && !paused.ended()
	// Attribute mutations bypass the V setter, so endpoint capture must read the actual owner.
	active_element.set_attribute_value('loop', 'active loop')
	active.set_current_playback_position(1)
	active.set_paused(false)
	active.reached_end_of_media_playback()
	assert active.loop_was_specified_at_end_ && active.current_time() == 0 && active.seeking()
	assert !active.paused() && active.event_count('pause') == 0 && active.event_count('ended') == 0
	event_loop.perform_a_microtask_checkpoint()
	assert !active.ended()
	media_loop_dom_drain_owner(active)
	event_loop.process()
	assert !active.ended() && !active.seeking() && !active.paused()
	assert active.event_count('seeking') == 1 && active.event_count('seeked') == 1
	assert active.event_count('pause') == 0 && active.event_count('ended') == 0
	paused_element.set_attribute_value('loop', 'paused loop')
	paused.set_current_playback_position(1)
	paused.reached_end_of_media_playback()
	assert paused.loop_was_specified_at_end_ && paused.current_time() == 1 && paused.paused()
	assert !paused.seeking() && paused.queued_media_task_ids_.len == 0
	event_loop.process()
	assert !paused.ended() && paused.event_count('seeking') == 0 && paused.event_count('ended') == 0
	// A later loop mutation cannot revise the endpoint's captured non-loop snapshot.
	active_element.remove_attribute('loop')
	active.set_current_playback_position(1)
	active.reached_end_of_media_playback()
	assert !active.loop_was_specified_at_end_ && !active.ended() && !active.paused()
	active_element.set_attribute_value('loop', 'added after endpoint')
	assert active.loop() && !active.loop_was_specified_at_end_ && active.has_ended_playback()
	event_loop.perform_a_microtask_checkpoint()
	assert !active.ended()
	media_loop_dom_drain_owner(active)
	assert active.ended() && active.paused()
	assert active.event_count('pause') == 1 && active.event_count('ended') == 1
	active_element.remove_attribute('loop')
	assert !active.loop() && active.ended()
	active.set_current_playback_position(0)
	assert active.ended()
	event_loop.process()
	assert !active.ended() && active.queued_media_task_ids_.len == 0
}
