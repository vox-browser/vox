module html

import css
import dom
import page

fn media_css_document(markup string) !&dom.Document {
	url := dom.URL{ value: 'https://media-css.example.test/' }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn media_css_drain(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn media_css_property(name string) dom.StyleInvalidationSet {
	return dom.StyleInvalidationSet{
		properties: [dom.InvalidationProperty{ type_: .pseudo_class, pseudo_class_name: name }]
	}
}

fn test_media_selectors_query_initial_lazy_and_created_owners_and_respect_namespaces() {
	document := media_css_document('<video id="video"></video><audio id="audio"></audio><div id="div"></div>')!
	for id in ['video', 'audio'] {
		element := document.get_element_by_id(id)?
		assert css.element_matches_selector(element, ':paused:buffering:not(:playing):not(:muted):not(:seeking)')
		assert !css.element_matches_selector(element, ':stalled, :volume-locked')
		assert voidptr(html_media_element_for_dom_element(element)?) == voidptr(html_media_element_for_dom_element(element)?)
	}
	created := document.create_element('video')!
	assert css.element_matches_selector(created, ':paused:buffering')
	foreign := document.create_element_ns('http://www.w3.org/2000/svg', 'video')!
	assert html_media_element_for_dom_element(foreign) == none
	ordinary := document.get_element_by_id('div')?
	for element in [foreign, ordinary] {
		assert !css.element_matches_selector(element, ':paused, :playing, :buffering, :muted, :seeking, :stalled, :volume-locked')
	}
}

fn test_resource_less_play_and_pause_synchronously_change_playing_and_paused_selectors() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	document := media_css_document('<video id="player"></video>')!
	element := document.get_element_by_id('player')?
	mut media := html_media_element_for_dom_element(element)?
	assert css.element_matches_selector(element, ':paused:not(:playing)')
	media.play()
	assert !media.paused() && media.blocked() && !media.is_playing_audio()
	assert css.element_matches_selector(element, ':playing:buffering:not(:paused)')
	media.pause()
	assert media.paused() && media.blocked()
	assert css.element_matches_selector(element, ':paused:buffering:not(:playing)')
	media_css_drain(media)
}

fn test_muted_selector_uses_element_state_instead_of_effective_volume_or_page_mute() {
	mut document := media_css_document('<audio id="player"></audio>')!
	mut owner := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	element := document.get_element_by_id('player')?
	mut media := html_media_element_for_dom_element(element)?
	media.set_volume(0)!
	owner.set_page_mute_state(.muted)
	assert media.effective_media_volume() == 0 && !media.muted()
	assert !css.element_matches_selector(element, ':muted')
	media.set_muted(true)
	assert css.element_matches_selector(element, ':muted')
	assert element.includes_properties_from_invalidation_set(media_css_property('muted'))
	media.set_muted(false)
	assert !css.element_matches_selector(element, ':muted')
	assert !element.includes_properties_from_invalidation_set(media_css_property('muted'))
	assert media.effective_media_volume() == 0
	owner.set_page_mute_state(.unmuted)
	media_css_drain(media)
}

fn test_media_state_changes_invalidate_once_and_keep_buffering_threshold_independent_of_playing() {
	document := media_css_document('<video id="player"></video>')!
	css.css_style_computer_for(document)
	element := document.get_element_by_id('player')?
	mut node := element.as_node()
	mut media := html_media_element_for_dom_element(element)?
	node.set_needs_style_update(false)
	media.set_paused(false)
	assert node.needs_style_update()
	assert css.element_matches_selector(element, ':playing:buffering')
	assert element.includes_properties_from_invalidation_set(media_css_property('playing'))
	assert !element.includes_properties_from_invalidation_set(media_css_property('paused'))
	node.set_needs_style_update(false)
	media.set_paused(false)
	assert !node.needs_style_update()
	media.set_ready_state(.have_metadata)
	assert !node.needs_style_update()
	media.set_ready_state(.have_current_data)
	assert !node.needs_style_update()
	media.set_ready_state(.have_future_data)
	assert node.needs_style_update()
	assert css.element_matches_selector(element, ':playing:not(:buffering)')
	node.set_needs_style_update(false)
	media.set_ready_state(.have_enough_data)
	assert !node.needs_style_update()
	media.set_ready_state(.have_current_data)
	assert node.needs_style_update()
	assert css.element_matches_selector(element, ':playing:buffering')
	node.set_needs_style_update(false)
	media.set_seeking(true)
	assert node.needs_style_update() && css.element_matches_selector(element, ':seeking')
	assert element.includes_properties_from_invalidation_set(media_css_property('seeking'))
	node.set_needs_style_update(false)
	media.set_seeking(true)
	assert !node.needs_style_update()
	media.set_seeking(false)
	assert node.needs_style_update() && !css.element_matches_selector(element, ':seeking')
	media.set_paused(true)
	media_css_drain(media)
}

fn test_muted_invalidation_follows_the_manager_hook_and_skips_equal_values_and_page_changes() {
	mut document := media_css_document('<audio id="player"></audio>')!
	css.css_style_computer_for(document)
	mut owner := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(owner) })
	element := document.get_element_by_id('player')?
	mut node := element.as_node()
	mut media := html_media_element_for_dom_element(element)?
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_volume: fn [element, node] (_ f64) {
			assert !node.needs_style_update()
			assert css.element_matches_selector(element, ':muted')
		}
	})
	node.set_needs_style_update(false)
	media.set_muted(true)
	assert node.needs_style_update() && media.event_count('volumechange') == 0
	node.set_needs_style_update(false)
	media.set_muted(true)
	assert !node.needs_style_update()
	owner.set_page_mute_state(.muted)
	assert !node.needs_style_update()
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{})
	media_css_drain(media)
	assert media.event_count('volumechange') == 1
	media.set_muted(false)
	assert node.needs_style_update()
	media_css_drain(media)
}
