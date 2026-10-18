module html

import css
import dom

fn styled_controls_owner(kind string, head string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://controls-style.example/player/'}
	document := parse_navigation_document('<!doctype html>${head}<${kind} id="player" preload="none"></${kind}><span id="outside" class="timestamp">outside</span>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing styled controls owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing styled media model') }
	media.set_duration(60)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
	if kind == 'video' {
		media.on_video_track_added(MediaTrackMetadata{identifier: 2, pixel_width: 320, pixel_height: 180})
	}
	media.set_show_poster(false)
	media.create_controls()
	return document, media, media.controls_ or { return error('Missing styled controls') }
}

fn styled_controls_style(controls &MediaControls) &dom.Element {
	root := controls.owned_shadow_root_ or { panic('Missing styled shadow root') }
	children := unsafe { &dom.Node(root) }.children_as_vector()
	assert children.len == 2
	assert children[1] == (controls.dom_.container or { panic('Missing container') }).as_node()
	style := children[0].as_element() or { panic('Missing style element') }
	assert style.is_html_element() && style.local_name() == 'style'
	return style
}

fn styled_controls_value(element &dom.Element, property css.PropertyID, expected string) {
	actual := css.computed_value_for(element, property) or { panic('Missing computed value') }
	assert actual == expected, '${property}: expected ${expected}, got ${actual}'
}

fn test_controls_stylesheet_owns_one_embedded_sheet_per_shadow_scope_and_isolates_author_rules() {
	for kind in ['audio', 'video'] {
		mut document, mut media, controls := styled_controls_owner(kind, '<style>.timestamp {color:red!important} .controls {display:block!important}</style>')!
		defer { media.finalize(); document.finalize() }
		style := styled_controls_style(controls)
		assert style.as_node().text_content()? == media_controls_stylesheet_source
		sheet := css.style_element_sheet(style)?
		assert sheet.base.owner_node? == style && sheet.css_rules().length() > 30
		root := controls.owned_shadow_root_?
		mut scope := css.style_scope_for_dom_node(unsafe { &dom.Node(root) })
		assert scope.style_sheet_list().sheets == [sheet]
		mut document_scope := css.style_scope_for_dom_node(document.as_node())
		assert document_scope.style_sheet_list().sheets.len == 1
		assert document_scope.style_sheet_list().sheets[0] != sheet
		styled_controls_value(controls.dom_.control_bar?, .display, 'flex')
		styled_controls_value(controls.dom_.timestamp_element?, .color, 'rgb(255, 255, 255)')
		styled_controls_value(document.get_element_by_id('outside')?, .color, 'rgb(255, 0, 0)')
		styled_controls_value(document.get_element_by_id('outside')?, .white_space_collapse, 'collapse')
		media.create_controls()
		assert styled_controls_style(media.controls_?) == style && scope.style_sheet_list().sheets == [sheet]
	}
}

fn test_controls_stylesheet_resolves_widget_geometry_and_live_play_mute_volume_and_fullscreen_rules() {
	for kind in ['audio', 'video'] {
		mut document, mut media, mut controls := styled_controls_owner(kind, '')!
		defer { media.finalize(); document.finalize() }
		bar := controls.dom_.control_bar?
		buttons := bar.as_node().children_as_vector()[1].as_element()?
		styled_controls_value(bar, .flex_direction, 'column')
		styled_controls_value(buttons, .display, 'flex')
		styled_controls_value(buttons, .align_items, 'center')
		styled_controls_value(controls.dom_.play_button?, .width, '24px')
		styled_controls_value(controls.dom_.timeline_track?, .height, '5px')
		styled_controls_value(controls.dom_.volume_element?, .height, '6px')
		styled_controls_value(controls.dom_.timestamp_element?, .white_space_collapse, 'collapse')
		styled_controls_value(controls.dom_.timestamp_element?, .text_wrap_mode, 'nowrap')
		play_paths := controls.dom_.play_pause_icon?.as_node().children_as_vector()
		play := play_paths[0].as_element()?
		pause := play_paths[1].as_element()?
		styled_controls_value(play, .display, 'inline')
		styled_controls_value(pause, .display, 'none')
		styled_controls_value(play, .fill, 'rgb(255, 255, 255)')
		media.set_paused(false)
		media.fire_event('play')
		styled_controls_value(play, .display, 'none')
		styled_controls_value(pause, .display, 'inline')
		media.set_paused(true)
		media.fire_event('pause')
		styled_controls_value(play, .display, 'inline')
		mute_paths := controls.dom_.mute_button?.as_node().children_as_vector()[0].children_as_vector()
		muted_line := mute_paths[1].as_element()?
		high := mute_paths[2].as_element()?
		low := mute_paths[3].as_element()?
		styled_controls_value(muted_line, .display, 'none')
		media.set_volume(0.25)!
		media.fire_event('volumechange')
		styled_controls_value(low, .display, 'inline')
		styled_controls_value(high, .display, 'none')
		media.set_volume(0.75)!
		media.fire_event('volumechange')
		styled_controls_value(high, .display, 'inline')
		media.set_muted(true)
		media.fire_event('volumechange')
		styled_controls_value(muted_line, .display, 'inline')
		assert (css.computed_value_for(low, .clip_path) or { '' }).contains('#muted-clip')
		mut tracks := media.audio_tracks()
		tracks.remove_all_tracks()
		media.fire_event('volumechange')
		styled_controls_value(controls.dom_.volume_area?, .display, 'none')
		if kind == 'video' {
			paths := controls.dom_.fullscreen_icon?.as_node().children_as_vector()
			maximize := paths[0].as_element()?
			minimize := paths[1].as_element()?
			styled_controls_value(maximize, .display, 'inline')
			styled_controls_value(minimize, .display, 'none')
			mut owner := document.get_element_by_id('player')?
			assert owner.request_fullscreen(.web_driver).state() == .fulfilled
			styled_controls_value(maximize, .display, 'none')
			styled_controls_value(minimize, .display, 'inline')
			assert document.exit_fullscreen().state() == .fulfilled
			controls.hide_controls()
			styled_controls_value(bar, .pointer_events, 'none')
			controls.show_controls()
			styled_controls_value(bar, .pointer_events, 'auto')
		}
	}
}

fn test_controls_stylesheet_follows_adoption_and_is_removed_on_teardown_before_fresh_recreation() {
	mut document, mut media, controls := styled_controls_owner('video', '')!
	url := dom.URL{value: 'https://adopted-controls-style.example/'}
	mut destination := parse_navigation_document('<!doctype html><main id="target"></main>', url, url.origin(), none)!
	defer { media.finalize(); document.finalize(); destination.finalize() }
	style := styled_controls_style(controls)
	root := controls.owned_shadow_root_?
	mut scope := css.style_scope_for_dom_node(unsafe { &dom.Node(root) })
	owner := document.get_element_by_id('player')?
	destination.adopt_node(owner.as_node())
	mut parent := destination.get_element_by_id('target')?.as_node()
	parent.append_child(owner.as_node())!
	assert style.document() == destination && styled_controls_style(controls) == style
	sheet := css.style_element_sheet(style)?
	assert scope.style_sheet_list().sheets == [sheet] && sheet.base.owner_node? == style
	styled_controls_value(controls.dom_.control_bar?, .display, 'flex')
	media.destroy_controls()
	assert !style.is_connected() && css.style_element_sheet(style) == none
	assert scope.style_sheet_list().sheets.len == 0 && sheet.base.owner_node == none
	media.create_controls()
	next := media.controls_?
	assert styled_controls_style(next) != style && styled_controls_style(next).document() == destination
	assert css.style_element_sheet(styled_controls_style(next)) != none
	styled_controls_value(next.dom_.control_bar?, .display, 'flex')
}

fn test_controls_stylesheet_uses_normal_style_element_csp_checks_without_fetching_a_link() {
	mut document, mut media, controls := styled_controls_owner('audio', '<meta http-equiv="Content-Security-Policy" content="style-src &apos;none&apos;">')!
	defer { media.finalize(); document.finalize() }
	style := styled_controls_style(controls)
	assert style.as_node().text_content()? == media_controls_stylesheet_source
	assert document.should_block_inline_content(style, 'style', media_controls_stylesheet_source)
	assert css.style_element_sheet(style) == none
	mut scope := css.style_scope_for_dom_node(unsafe { &dom.Node(controls.owned_shadow_root_?) })
	assert scope.style_sheet_list().sheets.len == 0
	assert css.query_selector_all(unsafe { &dom.Node(controls.owned_shadow_root_?) }, 'link').len == 0
}
