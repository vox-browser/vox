module html

import dom

fn structure_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing controls structure media task') }
		assert task.source() == .media_element
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn structure_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://controls-structure.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing controls structure owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing controls structure model') }
	media.set_duration(60)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
		media.set_show_poster(false)
	}
	media.create_controls()
	structure_controls_drain(media)
	return document, media, media.controls_ or { return error('Missing controls structure') }
}

fn structure_controls_buttons(controls &MediaControls) &dom.Element {
	bar := controls.dom_.control_bar or { panic('Missing controls bar') }
	children := bar.as_node().children_as_vector()
	assert children.len == 2
	return children[1].as_element() or { panic('Missing controls button bar') }
}

fn structure_controls_click(element &dom.Element, handled bool) {
	event := dom.Event.construct_impl('click', dom.EventInit{bubbles: true, cancelable: true}) or { panic(err) }
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn test_controls_structure_matches_source_control_rows_order_and_timestamp_element() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := structure_controls_owner(kind)!
		defer { media.finalize(); document.finalize() }
		container := controls.dom_.container?
		bar := controls.dom_.control_bar?
		buttons := structure_controls_buttons(controls)
		assert container.get_attribute_value('class') == 'container ${kind}'
		assert buttons.is_html_element() && buttons.local_name() == 'div' && buttons.get_attribute_value('class') == 'button-bar'
		assert bar.as_node().children_as_vector() == [controls.dom_.timeline_element?.as_node(), buttons.as_node()]
		mut expected := [controls.dom_.play_button?.as_node(), controls.dom_.timestamp_element?.as_node(),
			controls.dom_.mute_button?.as_node(), controls.dom_.volume_area?.as_node()]
		if kind == 'video' { expected << controls.dom_.fullscreen_button?.as_node() }
		assert buttons.as_node().children_as_vector() == expected
		timestamp := controls.dom_.timestamp_element?
		assert timestamp.is_html_element() && timestamp.local_name() == 'span'
		assert timestamp.get_attribute_value('class') == 'timestamp' && timestamp.as_node().text_content()? == '00:00 / 01:00'
		assert controls.dom_.mute_button?.local_name() == 'button'
		assert controls.dom_.volume_area?.get_attribute_value('class') == 'volume-area'
		assert controls.dom_.volume_element?.as_node().children_as_vector() == [controls.dom_.volume_fill?.as_node()]
		assert controls.dom_.timeline_track?.as_node().children_as_vector() == [controls.dom_.timeline_fill?.as_node()]
		if kind == 'video' {
			assert container.as_node().children_as_vector() == [controls.dom_.video_overlay?.as_node(), bar.as_node()]
		} else {
			assert container.as_node().children_as_vector() == [bar.as_node()]
			assert controls.dom_.fullscreen_button == none && controls.dom_.video_overlay == none
		}
	}
}

fn test_controls_structure_preserves_bubbling_and_timestamp_updates_without_rebuilding_the_row() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := structure_controls_owner(kind)!
		defer { media.finalize(); document.finalize() }
		buttons := structure_controls_buttons(controls)
		children := buttons.as_node().children_as_vector()
		timestamp := controls.dom_.timestamp_element?
		structure_controls_click(buttons, false)
		structure_controls_click(timestamp, false)
		assert media.paused() && !media.muted()
		play_path := controls.dom_.play_pause_icon?.as_node().children_as_vector()[0].as_element()?
		structure_controls_click(play_path, true)
		structure_controls_drain(media)
		assert !media.paused() && media.event_count('play') == 1
		structure_controls_click(controls.dom_.mute_button?, true)
		structure_controls_drain(media)
		assert media.muted()
		media.set_current_playback_position(12.2)
		media.set_official_playback_position(12.2)
		media.fire_event('timeupdate')
		assert timestamp.as_node().text_content()? == '00:12 / 01:00'
		structure_controls_click(controls.dom_.play_button?, true)
		structure_controls_drain(media)
		assert media.paused() && media.event_count('pause') == 1
		assert structure_controls_buttons(controls) == buttons && buttons.as_node().children_as_vector() == children
		assert controls.dom_.timestamp_element? == timestamp && controls.dom_.timestamp_element?.local_name() == 'span'
	}
}

fn test_controls_structure_survives_adoption_and_recreates_fresh_rows_after_teardown() {
	mut document, mut media, controls := structure_controls_owner('video')!
	url := dom.URL{value: 'https://adopted-controls-structure.example/'}
	mut destination := parse_navigation_document('<!doctype html><main id="target"></main>', url, url.origin(), none)!
	defer { media.finalize(); document.finalize(); destination.finalize() }
	buttons := structure_controls_buttons(controls)
	timestamp := controls.dom_.timestamp_element?
	play := controls.dom_.play_button?
	owner := document.get_element_by_id('player')?
	destination.adopt_node(owner.as_node())
	mut parent := destination.get_element_by_id('target')?.as_node()
	parent.append_child(owner.as_node())!
	assert buttons.document() == destination && timestamp.document() == destination
	assert structure_controls_buttons(controls) == buttons
	media.destroy_controls()
	assert !buttons.is_connected() && !timestamp.is_connected()
	structure_controls_click(play, false)
	assert media.paused()
	media.create_controls()
	next := media.controls_?
	assert structure_controls_buttons(next) != buttons && next.dom_.timestamp_element? != timestamp
	assert next.dom_.timestamp_element?.local_name() == 'span' && next.dom_.timestamp_element?.document() == destination
	assert next.dom_.container?.get_attribute_value('class') == 'container video'
}
