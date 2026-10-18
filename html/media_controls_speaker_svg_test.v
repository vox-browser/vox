module html

import dom

fn speaker_svg_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing speaker SVG media task') }
		assert task.source() == .media_element
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn speaker_svg_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://speaker-svg.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing speaker SVG owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing speaker SVG model') }
	media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
	media.set_volume(0.75)!
	media.create_controls()
	speaker_svg_drain(media)
	return document, media, media.controls_ or { return error('Missing speaker SVG controls') }
}

fn speaker_svg_click(element &dom.Element, bubbles bool, handled bool) {
	event := dom.Event.construct_impl('click', dom.EventInit{bubbles: bubbles, cancelable: true}) or { panic(err) }
	assert !event.is_trusted()
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn test_speaker_svg_has_source_geometry_namespaces_and_clipping_definition_for_audio_and_video() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := speaker_svg_owner(kind)!
		defer { media.finalize(); document.finalize() }
		button := controls.dom_.mute_button?
		assert button.is_html_element() && button.local_name() == 'button'
		assert button.as_node().children_as_vector().len == 1
		icon := button.as_node().children_as_vector()[0].as_element()?
		assert icon.namespace_uri()? == 'http://www.w3.org/2000/svg' && icon.local_name() == 'svg'
		assert icon.get_attribute_value('class') == 'icon'
		assert icon.get_attribute_value('viewBox') == '0 0 24 24' && icon.get_attribute('viewbox') == none
		children := icon.as_node().children_as_vector()
		assert children.len == 5
		defs := children[0].as_element()?
		assert defs.namespace_uri()? == 'http://www.w3.org/2000/svg' && defs.local_name() == 'defs'
		assert defs.as_node().children_as_vector().len == 1
		clip := defs.as_node().children_as_vector()[0].as_element()?
		assert clip.namespace_uri()? == 'http://www.w3.org/2000/svg' && clip.local_name() == 'clipPath'
		assert clip.get_attribute_value('id') == 'muted-clip' && clip.as_node().children_as_vector().len == 1
		clip_path := clip.as_node().children_as_vector()[0].as_element()?
		assert clip_path.namespace_uri()? == 'http://www.w3.org/2000/svg' && clip_path.local_name() == 'path'
		assert clip_path.get_attribute_value('d') == 'M3 0h21v21ZM0 0v24h24z'
		for index, geometry in [
			'm5 5 14 14-1.5 1.5-14-14z',
			'M14 4.08v2.04c2.23.55 4 2.9 4 5.88 0 2.97-1.77 5.33-4 5.88v2.04c3.45-.56 6-3.96 6-7.92s-2.55-7.36-6-7.92Z',
			'M14 7.67v8.66c.35-.25.66-.55.92-.9A5.7 5.7 0 0 0 16 12c0-1.3-.39-2.5-1.08-3.43a4.24 4.24 0 0 0-.92-.9Z',
			'M4 9v6h4l4 5V4L8 9Z',
		] {
			path := children[index + 1].as_element()?
			assert path.namespace_uri()? == 'http://www.w3.org/2000/svg' && path.local_name() == 'path'
			assert path.get_attribute_value('class') == ['muted-line', 'volume-high', 'volume-low', 'speaker'][index]
			assert path.get_attribute_value('d') == geometry && path.document() == document
		}
	}
}

fn test_speaker_svg_clip_ids_stay_in_their_own_shadow_roots_through_adoption_and_recreation() {
	mut document, mut media, controls := speaker_svg_owner('audio')!
	mut second := document.create_element_ns(ns_html, 'video')!
	mut body := document.get_element_by_id('player')?.as_node().parent()?
	body.append_child(second.as_node())!
	mut other_media := html_media_element_for_dom_element(second)?
	other_media.create_controls()
	owner := document.get_element_by_id('player')?
	root := owner.shadow_root()?
	other_root := second.shadow_root()?
	clip := root.get_element_by_id('muted-clip')?
	other_clip := other_root.get_element_by_id('muted-clip')?
	assert clip != other_clip && clip.as_node().root() == unsafe { &dom.Node(root) }
	assert other_clip.as_node().root() == unsafe { &dom.Node(other_root) }
	assert document.get_element_by_id('muted-clip') == none
	url := dom.URL{value: 'https://adopted-speaker-svg.example/'}
	mut destination := parse_navigation_document('<!doctype html><div id="muted-clip"></div>', url, url.origin(), none)!
	defer { media.finalize(); other_media.finalize(); document.finalize(); destination.finalize() }
	author := destination.get_element_by_id('muted-clip')?
	destination.adopt_node(owner.as_node())
	mut parent := author.as_node().parent()?
	parent.append_child(owner.as_node())!
	assert root.get_element_by_id('muted-clip')? == clip && clip.document() == destination
	assert other_root.get_element_by_id('muted-clip')? == other_clip && other_clip.document() == document
	assert destination.get_element_by_id('muted-clip')? == author
	old_button := controls.dom_.mute_button?
	media.destroy_controls()
	assert !clip.is_connected() && !old_button.is_connected()
	speaker_svg_click(clip, true, false)
	assert !media.muted()
	media.create_controls()
	next_root := owner.shadow_root()?
	assert next_root != root && next_root.get_element_by_id('muted-clip')? != clip
	assert destination.get_element_by_id('muted-clip')? == author
}

fn test_speaker_svg_paths_bubble_to_one_mute_listener_and_survive_volume_state_changes() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := speaker_svg_owner(kind)!
		defer { media.finalize(); document.finalize() }
		mut button := controls.dom_.mute_button?
		icon := button.as_node().children_as_vector()[0].as_element()?
		children := icon.as_node().children_as_vector()
		speaker := children[4].as_element()?
		button_target := unsafe { &dom.EventTarget(button.as_node()) }
		icon_target := unsafe { &dom.EventTarget(icon.as_node()) }
		assert controls.registered_event_listeners_.filter(it.target == button_target && it.event_name == 'click').len == 1
		assert controls.registered_event_listeners_.filter(it.target == icon_target).len == 0
		mut classes := button.class_list()
		classes.add(['retained'])!
		before := media.event_count('volumechange')
		speaker_svg_click(speaker, false, false)
		assert !media.muted()
		speaker_svg_click(speaker, true, true)
		assert media.muted() && !classes.contains('muted')
		speaker_svg_drain(media)
		assert classes.contains('muted') && classes.contains('high')
		speaker_svg_click(icon, true, true)
		speaker_svg_drain(media)
		assert !media.muted() && !classes.contains('muted') && media.event_count('volumechange') == before + 2
		for volume in [0.0, 0.25, 0.75] {
			media.set_volume(volume)!
			speaker_svg_drain(media)
			assert classes.contains('low') == (volume > 0 && volume <= 0.5)
			assert classes.contains('high') == (volume > 0.5)
			assert classes.contains('retained') && !classes.contains('muted')
			assert icon.as_node().children_as_vector() == children
		}
		assert media.paused() && media.current_src() == ''
	}
}
