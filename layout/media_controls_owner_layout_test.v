module layout

import css
import dom
import html
import math

fn owner_controls_document(kind string) !(&dom.Document, &dom.Element) {
	url := dom.URL{value: 'https://controls-layout.example/player/'}
	document := html.parse_navigation_document('<!doctype html><style>html,body{margin:0}audio,video{display:block;width:320px;height:180px}</style><${kind} id="player" controls="raw controls" preload="none"></${kind}>', url, url.origin(), none)!
	owner := document.get_element_by_id('player') or { return error('Missing controls layout owner') }
	return document, owner
}

fn owner_controls_widget(owner &dom.Element, selector string) &dom.Element {
	root := owner.shadow_root() or { panic('Missing controls layout shadow root') }
	return css.query_selector(root.as_node(), selector) or { panic('Missing controls widget ${selector}') }
}

fn owner_controls_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && owner == document
		}) or { return }
		task.execute()
	}
	panic('Controls layout media tasks did not finish')
}

fn owner_controls_click(element &dom.Element, handled bool) {
	event := dom.Event.construct_impl('click', dom.EventInit{bubbles: true, cancelable: true}) or { panic(err) }
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn test_media_controls_layout_materializes_one_live_owner_with_complete_widget_styles_and_retains_it() {
	for kind in ['audio', 'video'] {
		mut document, owner := owner_controls_document(kind)!
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 240)
		mut media := html.html_media_element_for_dom_element(owner)?
		defer { media.finalize() }
		assert media.has_controls() && media.paused() && media.current_src() == ''
		root := owner.shadow_root()?
		assert root.is_user_agent_internal() && root.mode() == .closed && owner.shadow_root_for_bindings() == none
		style := owner_controls_widget(owner, 'style')
		sheet := css.style_element_sheet(style)?
		assert sheet.base.owner_node? == style && sheet.css_rules().length() > 30
		container := owner_controls_widget(owner, '.container.${kind}')
		button := owner_controls_widget(owner, '.play-pause-button')
		assert container.as_node().unsafe_layout_node() != none && button.get_bounding_client_rect().width == 24
		assert owner_controls_widget(owner, '.play-pause-icon').as_node().child_count() == 2
		assert owner_controls_widget(owner, '.timestamp').as_node().text_content()? == '00:00 / 00:00'
		assert owner_controls_widget(owner, '.volume-area') != owner_controls_widget(owner, '.volume')
		assert (css.query_selector(root.as_node(), '.fullscreen-button') != none) == (kind == 'video')
		_ = layout_document_typed_in_viewport(document, 500, 300)
		assert owner.shadow_root()? == root && owner_controls_widget(owner, '.play-pause-button') == button
		assert css.style_element_sheet(style)? == sheet && html.html_media_element_for_dom_element(owner)? == media
		assert owner.get_attribute_ns(none, 'controls')? == 'raw controls'
		assert media.event_count('loadstart') == 0 && media.event_count('play') == 0
	}
}

fn test_media_controls_layout_uses_live_timestamp_play_mute_and_real_volume_geometry() {
	for kind in ['audio', 'video'] {
		mut document, owner := owner_controls_document(kind)!
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 240)
		mut media := html.html_media_element_for_dom_element(owner)?
		defer { media.finalize() }
		media.set_fetch_hook(fn [kind] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{mime_type: 'audio/mpeg', duration: 60, buffered_end: 60,
				audio_tracks: [html.MediaTrackMetadata{identifier: 1}],
				video_tracks: if kind == 'video' { [html.MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180}] } else { []html.MediaTrackMetadata{} }}
		})
		media.set_source('controlled.mp3')
		media.load()!
		owner_controls_drain(document)
		media.set_current_playback_position(12)
		media.set_official_playback_position(12)
		timeupdate := dom.Event.construct_impl('timeupdate', dom.EventInit{})!
		media.event_target().dispatch_event(timeupdate)
		assert owner_controls_widget(owner, '.timestamp').as_node().text_content()? == '00:12 / 01:00'
		play_path := owner_controls_widget(owner, '.play-pause-button .play-path')
		owner_controls_click(play_path, true)
		owner_controls_drain(document)
		mut play_icon := owner_controls_widget(owner, '.play-pause-icon')
		assert !media.paused() && play_icon.class_list().contains('playing')
		owner_controls_click(owner_controls_widget(owner, '.play-pause-button'), true)
		owner_controls_drain(document)
		assert media.paused() && media.event_count('play') == 1 && media.event_count('pause') == 1
		owner_controls_click(owner_controls_widget(owner, '.mute-button'), true)
		owner_controls_drain(document)
		mut mute_button := owner_controls_widget(owner, '.mute-button')
		assert media.muted() && mute_button.class_list().contains('muted')
		_ = layout_document_typed_in_viewport(document, 400, 240)
		volume := owner_controls_widget(owner, '.volume')
		rect := volume.get_bounding_client_rect()
		assert rect.width > 0 && rect.height == 6
		event := dom.MouseEvent.construct_impl('mousedown', dom.MouseEventInit{
			client_x: rect.x + rect.width * 0.25, client_y: rect.y + rect.height / 2,
			button: 0, bubbles: true, cancelable: true
		})!
		assert !unsafe { &dom.EventTarget(owner_controls_widget(owner, '.volume-area').as_node()) }.dispatch_event(unsafe { &dom.Event(event) })
		assert math.abs(media.volume() - 0.25) < 0.00001 && !media.muted()
		window := document.get_window()?
		up := dom.MouseEvent.construct_impl('mouseup', dom.MouseEventInit{
			client_x: rect.x + rect.width * 0.25, client_y: rect.y + rect.height / 2,
			button: 0, cancelable: true
		})!
		assert !unsafe { &dom.EventTarget(window) }.dispatch_event(unsafe { &dom.Event(up) })
		owner_controls_drain(document)
		assert css.element_style(owner_controls_widget(owner, '.volume-fill')).get_property_value('width') == '25%'
	}
}

fn test_media_controls_layout_teardown_removes_the_owned_sheet_and_listeners_and_recreates_fresh_widgets() {
	for kind in ['audio', 'video'] {
		mut document, mut owner := owner_controls_document(kind)!
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 240)
		mut media := html.html_media_element_for_dom_element(owner)?
		defer { media.finalize() }
		root := owner.shadow_root()?
		button := owner_controls_widget(owner, '.mute-button')
		style := owner_controls_widget(owner, 'style')
		assert owner.as_node().is_scripting_enabled()
		owner.remove_attribute_ns(none, 'controls')
		_ = layout_document_typed_in_viewport(document, 400, 240)
		assert !media.has_controls() && owner.shadow_root() == none && !button.is_connected()
		assert css.style_element_sheet(style) == none
		owner_controls_click(button, false)
		assert !media.muted() && media.paused()
		owner.set_attribute_value('controls', 'again')
		_ = layout_document_typed_in_viewport(document, 400, 240)
		assert media.has_controls() && owner.shadow_root()? != root && owner_controls_widget(owner, '.mute-button') != button
		assert html.html_media_element_for_dom_element(owner)? == media
		owner_controls_click(owner_controls_widget(owner, '.mute-button'), true)
		owner_controls_drain(document)
		assert media.muted() && media.current_src() == '' && media.event_count('loadstart') == 0
	}
}
