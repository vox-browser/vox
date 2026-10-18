module html

import css
import dom

fn playback_svg_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing playback SVG media task') }
		assert task.source() == .media_element
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn playback_svg_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://playback-svg.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none" controls></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing playback SVG owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing playback SVG model') }
	media.set_duration(60)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
	}
	playback_svg_drain(media)
	return document, media, media.controls_ or { return error('Missing playback SVG controls') }
}

fn playback_svg_event(element &dom.Element, name string, bubbles bool, handled bool) {
	event := dom.Event.construct_impl(name, dom.EventInit{bubbles: bubbles, cancelable: true}) or { panic(err) }
	assert !event.is_trusted()
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn test_playback_svg_paths_keep_their_identity_through_audio_and_video_button_activation() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := playback_svg_owner(kind)!
		defer { media.finalize(); document.finalize() }
		button := controls.dom_.play_button?
		mut icon := controls.dom_.play_pause_icon?
		assert button.is_html_element() && button.local_name() == 'button'
		assert button.as_node().children_as_vector() == [icon.as_node()]
		assert icon.namespace_uri()? == 'http://www.w3.org/2000/svg' && icon.local_name() == 'svg'
		assert icon.get_attribute_value('class') == 'icon play-pause-icon'
		assert icon.get_attribute_value('viewBox') == '0 0 24 24' && icon.get_attribute('viewbox') == none
		paths := icon.as_node().children_as_vector()
		assert paths.len == 2
		for index, geometry in ['m6 5 13 7-13 7Z', 'M14 5h4v14h-4Zm-4 0H6v14h4z'] {
			path := paths[index].as_element()?
			assert path.namespace_uri()? == 'http://www.w3.org/2000/svg' && path.local_name() == 'path'
			assert path.get_attribute_value('class') == if index == 0 { 'play-path' } else { 'pause-path' }
			assert path.get_attribute_value('d') == geometry && path.document() == document
			assert path.as_node().children_as_vector().len == 0
		}
		mut classes := icon.class_list()
		classes.add(['retained'])!
		button_target := unsafe { &dom.EventTarget(button.as_node()) }
		icon_target := unsafe { &dom.EventTarget(icon.as_node()) }
		assert controls.registered_event_listeners_.filter(it.target == button_target && it.event_name == 'click').len == 1
		assert controls.registered_event_listeners_.filter(it.target == icon_target).len == 0
		playback_svg_event(paths[0].as_element()?, 'click', false, false)
		assert media.paused()
		playback_svg_event(paths[0].as_element()?, 'click', true, true)
		assert !media.paused() && classes.contains('playing') && classes.contains('retained')
		playback_svg_drain(media)
		playback_svg_event(paths[1].as_element()?, 'click', true, true)
		playback_svg_drain(media)
		assert media.paused() && !classes.contains('playing') && classes.contains('retained')
		assert media.event_count('play') == 1 && media.event_count('pause') == 1
		assert controls.dom_.play_pause_icon? == icon && icon.as_node().children_as_vector() == paths
	}
}

fn test_video_placeholder_svg_bubbles_to_the_overlay_and_follows_representation_visibility() {
	mut document, mut media, mut controls := playback_svg_owner('video')!
	defer { media.finalize(); document.finalize() }
	placeholder := controls.dom_.placeholder_circle?
	children := placeholder.as_node().children_as_vector()
	assert children.len == 1
	icon := children[0].as_element()?
	assert icon.namespace_uri()? == 'http://www.w3.org/2000/svg' && icon.local_name() == 'svg'
	assert icon.get_attribute_value('class') == 'placeholder-icon'
	assert icon.get_attribute_value('viewBox') == '0 0 24 24' && icon.get_attribute('viewbox') == none
	assert icon.as_node().children_as_vector().len == 1
	path := icon.as_node().children_as_vector()[0].as_element()?
	assert path.namespace_uri()? == 'http://www.w3.org/2000/svg' && path.local_name() == 'path'
	assert path.get_attribute_value('class') == 'play-path' && path.get_attribute_value('d') == 'm6 5 13 7-13 7Z'
	mut style := css.element_style(placeholder)
	assert controls.placeholder_visible && style.get_property_value('display') == 'flex'
	playback_svg_event(path, 'click', true, true)
	playback_svg_drain(media)
	assert !media.paused() && !controls.placeholder_visible && style.get_property_value('display') == 'none'
	playback_svg_event(path, 'click', true, true)
	playback_svg_drain(media)
	assert media.paused() && !media.show_poster() && style.get_property_value('display') == 'none'
	media.set_show_poster(true)
	controls.update_placeholder_visibility()
	assert controls.placeholder_visible && style.get_property_value('display') == 'flex'
	// An SVG descendant still reaches the overlay's separate fullscreen listener.
	mut window := document.get_window()?
	window.set_last_activation_timestamp(dom.current_high_resolution_time(window))
	playback_svg_event(path, 'dblclick', true, true)
	assert document.fullscreen_element()? == document.get_element_by_id('player')?
	assert document.exit_fullscreen().state() == .fulfilled
	assert placeholder.as_node().children_as_vector() == children
	assert media.event_count('play') == 1 && media.event_count('pause') == 1
}

fn test_playback_svg_destruction_releases_widgets_and_recreation_uses_fresh_paths() {
	mut document, mut media, controls := playback_svg_owner('video')!
	defer { media.finalize(); document.finalize() }
	icon := controls.dom_.play_pause_icon?
	path := icon.as_node().children_as_vector()[0].as_element()?
	placeholder := controls.dom_.placeholder_circle?
	overlay_path := placeholder.as_node().children_as_vector()[0].children_as_vector()[0].as_element()?
	media.destroy_controls()
	assert controls.dom_.play_pause_icon == none && controls.dom_.placeholder_circle == none
	assert !path.is_connected() && !overlay_path.is_connected()
	playback_svg_event(path, 'click', true, false)
	playback_svg_event(overlay_path, 'click', true, false)
	assert media.paused()
	media.create_controls()
	next := media.controls_?
	assert next.dom_.play_pause_icon? != icon && next.dom_.placeholder_circle? != placeholder
	new_path := next.dom_.play_pause_icon?.as_node().children_as_vector()[0].as_element()?
	assert new_path != path && new_path.is_connected()
	playback_svg_event(new_path, 'click', true, true)
	assert !media.paused()
	playback_svg_drain(media)
}
