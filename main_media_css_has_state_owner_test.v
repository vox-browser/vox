module main

import css
import dom
import html
import layout

fn media_has_state_opacity(element &dom.Element) f32 {
	computed := css.computed_properties_for_element(element) or { panic('missing computed media style') }
	return computed.opacity()
}

fn test_tag_qualified_has_media_state_changes_refresh_ancestor_descendants() {
	for tag in ['video', 'audio'] {
		url := dom.URL{ value: 'https://media-has-state.example.test/' }
		mut document := html.parse_navigation_document('<style>
 body:has(${tag}:paused) #paused{opacity:.2}
 body:has(${tag}:playing) #playing{opacity:.3}
 body:has(${tag}:muted) #muted{opacity:.4}
 body:has(${tag}:seeking) #seeking{opacity:.5}
 body:has(${tag}:buffering) #buffering{opacity:.6}
 </style><${tag} id="player"></${tag}><div id="paused"></div><div id="playing"></div><div id="muted"></div><div id="seeking"></div><div id="buffering"></div>', url, url.origin(), none)!
		layout.install_document_layout_hook(document)
		_ = layout.run_document_layout(document, 320, 240) or { panic(err) }
		element := document.get_element_by_id('player')?
		mut media := html.html_media_element_for_dom_element(element)?
		paused := document.get_element_by_id('paused')?
		playing := document.get_element_by_id('playing')?
		muted := document.get_element_by_id('muted')?
		seeking := document.get_element_by_id('seeking')?
		buffering := document.get_element_by_id('buffering')?
		assert media_has_state_opacity(paused) == f32(0.2)
		assert media_has_state_opacity(playing) == f32(1)
		assert media_has_state_opacity(muted) == f32(1)
		assert media_has_state_opacity(seeking) == f32(1)
		assert media_has_state_opacity(buffering) == f32(0.6)
		media.set_muted(true)
		media.set_seeking(true)
		media.set_paused(false)
		media.set_ready_state(.have_future_data)
		document.update_style()
		assert media_has_state_opacity(paused) == f32(1)
		assert media_has_state_opacity(playing) == f32(0.3)
		assert media_has_state_opacity(muted) == f32(0.4)
		assert media_has_state_opacity(seeking) == f32(0.5)
		assert media_has_state_opacity(buffering) == f32(1)
		media.set_muted(false)
		media.set_seeking(false)
		media.set_paused(true)
		media.set_ready_state(.have_current_data)
		document.update_style()
		assert media_has_state_opacity(paused) == f32(0.2)
		assert media_has_state_opacity(playing) == f32(1)
		assert media_has_state_opacity(muted) == f32(1)
		assert media_has_state_opacity(seeking) == f32(1)
		assert media_has_state_opacity(buffering) == f32(0.6)
		mut loop := html.main_thread_event_loop()
		for _ in 0 .. 100 { loop.process() }
	}
}
