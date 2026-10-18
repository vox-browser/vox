module html

import dom

fn attribute_controls_document(address string, markup string) !&dom.Document {
	url := dom.URL{value: address}
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn attribute_controls_event(target &dom.EventTarget, name string, handled bool) {
	event := dom.Event.create(name, dom.EventInit{cancelable: true})
	assert target.dispatch_event(event) == !handled
}

fn test_parsed_controls_materialize_after_the_actual_audio_video_model_is_published() {
	mut document := attribute_controls_document('https://parsed-controls.example/',
		'<!doctype html><audio id="audio" controls="false"></audio><video id="video" controls></video><audio id="plain"></audio>')!
	defer { document.finalize() }
	for kind in ['audio', 'video'] {
		element := document.get_element_by_id(kind)?
		mut media := html_media_element_for_dom_element(element)?
		defer { media.finalize() }
		controls := media.controls_?
		assert media.has_controls() && controls.media == media
		assert html_media_element_for_dom_element(element)? == media
		assert controls.dom_.container?.document() == document
		assert element.shadow_root()? == controls.owned_shadow_root_?
		assert controls.registered_event_listeners_.len == if kind == 'video' { 26 } else { 17 }
		assert media.paused() && media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.queued_media_task_ids_.len == 0
		assert element.get_attribute_ns(none, 'controls')? == if kind == 'audio' { 'false' } else { '' }
	}
	mut plain := html_media_element_for_dom_element(document.get_element_by_id('plain')?)?
	defer { plain.finalize() }
	assert !plain.has_controls()
}

fn test_live_controls_attribute_updates_preserve_identity_then_destroy_and_recreate_widgets() {
	mut document := attribute_controls_document('https://live-controls.example/',
		'<!doctype html><audio id="audio"></audio><video id="video"></video>')!
	defer { document.finalize() }
	assert document.as_node().is_scripting_enabled()
	for kind in ['audio', 'video'] {
		mut element := document.get_element_by_id(kind)?
		mut media := html_media_element_for_dom_element(element)?
		defer { media.finalize() }
		assert !media.has_controls() && element.shadow_root() == none
		element.set_attribute_value('controls', 'false')
		controls := media.controls_?
		root := element.shadow_root()?
		button := controls.dom_.mute_button?
		timer := controls.hover_timer_?
		for value in ['', 'controls', 'false'] {
			element.set_attribute_value('controls', value)
			assert media.controls_? == controls && element.shadow_root()? == root
			assert controls.hover_timer_? == timer && !controls.destroyed_
		}
		attribute_controls_event(unsafe { &dom.EventTarget(button.as_node()) }, 'click', true)
		assert media.muted()
		element.remove_attribute_ns(none, 'controls')
		assert !media.has_controls() && element.shadow_root() == none && controls.destroyed_
		assert !timer.is_active() && !timer.has_activity_root() && controls.registered_event_listeners_.len == 0
		attribute_controls_event(unsafe { &dom.EventTarget(button.as_node()) }, 'click', false)
		assert media.muted()
		element.set_attribute_value('controls', '')
		next := media.controls_?
		assert next != controls && element.shadow_root()? != root
		attribute_controls_event(unsafe { &dom.EventTarget(next.dom_.mute_button?.as_node()) }, 'click', true)
		assert !media.muted() && media.paused()
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
	}
}

fn test_video_first_lookup_reuses_the_model_created_while_initializing_parsed_controls() {
	mut document := attribute_controls_document('https://video-first-controls.example/',
		'<!doctype html><video id="player" controls poster="/poster.png"></video>')!
	defer { document.finalize() }
	element := document.get_element_by_id('player')?
	video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut media := html_media_element_for_dom_element(element)?
	defer { media.finalize() }
	assert video == media.video_element_model_?
	assert video == html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	assert video.poster_? == '/poster.png' && video.poster_fetch_generation_ == 0
	assert media.has_controls() && media.controls_?.placeholder_visible
}

fn test_controls_removal_uses_live_scripting_disabled_state_without_requiring_attribute_presence() {
	mut document := attribute_controls_document('https://disabled-controls.example/', '<!doctype html><audio id="audio" controls></audio>')!
	defer { document.finalize() }
	mut element := document.get_element_by_id('audio')?
	mut media := html_media_element_for_dom_element(element)?
	defer { media.finalize() }
	controls := media.controls_?
	document.set_scripting_enabled_by_embedder(false)
	assert element.as_node().is_scripting_disabled()
	element.remove_attribute_ns(none, 'controls')
	assert !element.has_attribute_ns(none, 'controls') && media.controls_? == controls
	assert !controls.destroyed_ && element.shadow_root() != none
	document.set_scripting_enabled_by_embedder(true)
	assert element.as_node().is_scripting_enabled()
	// Source applies this decision at an attribute change, not on a policy toggle.
	assert media.controls_? == controls
	element.set_attribute_value('controls', '')
	element.remove_attribute_ns(none, 'controls')
	assert controls.destroyed_ && !media.has_controls()
	mut inactive := dom.Document.create(dom.URL{value: 'https://no-context-controls.example/'})
	defer { inactive.finalize() }
	mut detached := inactive.create_element_ns(dom.namespace_html_uri, 'video')!
	mut detached_media := html_media_element_for_dom_element(detached)?
	defer { detached_media.finalize() }
	assert detached.as_node().is_scripting_disabled() && !detached_media.has_controls()
	detached.set_attribute_value('controls', '')
	kept := detached_media.controls_?
	detached.remove_attribute_ns(none, 'controls')
	assert detached_media.controls_? == kept && !kept.destroyed_
}

fn test_adopted_controls_attribute_hook_uses_destination_document_and_current_scripting_policy() {
	mut first := attribute_controls_document('https://old-controls.example/', '<!doctype html><video id="player" controls></video>')!
	mut second := attribute_controls_document('https://new-controls.example/', '<!doctype html><body></body>')!
	defer { first.finalize(); second.finalize() }
	mut element := first.get_element_by_id('player')?
	mut media := html_media_element_for_dom_element(element)?
	defer { media.finalize() }
	controls := media.controls_?
	second.set_scripting_enabled_by_embedder(false)
	second.adopt_node(element.as_node())
	assert media.document()? == second && element.as_node().is_scripting_disabled()
	element.remove_attribute_ns(none, 'controls')
	assert media.controls_? == controls && !controls.destroyed_
	second.set_scripting_enabled_by_embedder(true)
	first.set_scripting_enabled_by_embedder(false)
	element.set_attribute_value('controls', '')
	element.remove_attribute_ns(none, 'controls')
	assert !media.has_controls() && controls.destroyed_ && element.shadow_root() == none
	element.set_attribute_value('controls', 'new owner')
	next := media.controls_?
	assert next != controls && next.dom_.container?.document() == second
	assert next.relevant_window()? == unsafe { &WindowModel(second.get_window()?) }
}

fn test_controls_source_local_name_namespace_behavior_and_lazy_foreign_owner_boundaries() {
	mut document := attribute_controls_document('https://namespace-controls.example/', '<!doctype html><audio id="player"></audio>')!
	defer { document.finalize() }
	mut element := document.get_element_by_id('player')?
	mut media := html_media_element_for_dom_element(element)?
	defer { media.finalize() }
	// Pinned Source tests local name after the base hook, even in a namespace.
	element.set_attribute_value_ns('controls', 'foreign', 'p', 'urn:controls')
	assert media.has_controls() && !element.has_attribute_ns(none, 'controls')
	element.set_attribute_value('controls', '')
	old := media.controls_?
	element.remove_attribute_ns('urn:controls', 'controls')
	assert element.has_attribute_ns(none, 'controls') && !media.has_controls() && old.destroyed_
	element.set_attribute_value('controls', 'recreate')
	assert media.has_controls()
	mut lazy := document.create_element_ns(dom.namespace_html_uri, 'video')!
	lazy.set_attribute_value('controls', 'lazy')
	assert unsafe { &dom.HTMLVideoElement(lazy) }.media_element_model_ == unsafe { nil }
	mut lazy_media := html_media_element_for_dom_element(lazy)?
	defer { lazy_media.finalize() }
	assert lazy_media.has_controls() && lazy.get_attribute_ns(none, 'controls')? == 'lazy'
	mut foreign_only := document.create_element_ns(dom.namespace_html_uri, 'audio')!
	foreign_only.set_attribute_value_ns('controls', 'foreign', 'p', 'urn:controls')
	mut foreign_media := html_media_element_for_dom_element(foreign_only)?
	defer { foreign_media.finalize() }
	assert !foreign_media.has_controls()
	for namespace in [dom.namespace_svg_uri, 'urn:foreign-html'] {
		mut foreign := document.create_element_ns(namespace, 'video')!
		foreign.set_attribute_value('controls', '')
		assert html_media_element_for_dom_element(foreign) == none && foreign.shadow_root() == none
	}
}
