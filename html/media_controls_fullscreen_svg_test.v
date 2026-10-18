module html

import dom

fn fullscreen_svg_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://fullscreen-svg.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none" controls></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing SVG controls owner') }
	media := html_media_element_for_dom_element(element) or { return error('Missing SVG controls media') }
	return document, media, media.controls_ or { return error('Missing SVG controls') }
}

fn fullscreen_svg_click(element &dom.Element, handled bool) {
	event := dom.Event.construct_impl('click', dom.EventInit{bubbles: true, cancelable: true}) or { panic(err) }
	assert !event.is_trusted()
	assert unsafe { &dom.EventTarget(element.as_node()) }.dispatch_event(event) == !handled
	assert event.default_prevented() == handled
}

fn test_fullscreen_svg_uses_source_namespaces_viewbox_paths_and_separate_button_identity() {
	mut document, mut media, controls := fullscreen_svg_owner('video')!
	defer { media.finalize(); document.finalize() }
	mut button := controls.dom_.fullscreen_button?
	mut icon := controls.dom_.fullscreen_icon?
	assert button != icon && button.is_html_element() && button.local_name() == 'button'
	assert button.get_attribute_value('class') == 'control-button fullscreen-button'
	assert icon.namespace_uri()? == 'http://www.w3.org/2000/svg' && icon.local_name() == 'svg'
	assert icon.get_attribute_value('class') == 'icon fullscreen-icon'
	assert icon.get_attribute_value('viewBox') == '0 0 24 24'
	assert icon.get_attribute('viewbox') == none
	assert button.as_node().children_as_vector() == [icon.as_node()]
	paths := icon.as_node().children_as_vector()
	assert paths.len == 2
	for index, geometry in [
		'M3 3h6v2H5v4H3Zm12 0h6v6h-2V5h-4Zm6 12v6h-6v-2h4v-4ZM3 15v6h6v-2H5v-4Z',
		'M9 3v6H3V7h4V3Zm6 0v6h6V7h-4V3ZM3 15h6v6H7v-4H3Zm12 0v6h2v-4h4v-2Z',
	] {
		path := paths[index].as_element() or { panic('Missing SVG path') }
		assert path.namespace_uri()? == 'http://www.w3.org/2000/svg' && path.local_name() == 'path'
		assert path.get_attribute_value('d') == geometry
		assert path.get_attribute_value('class') == if index == 0 { 'fullscreen-maximize-path' } else { 'fullscreen-minimize-path' }
		assert path.document() == document && path.as_node().children_as_vector().len == 0
	}
	mut owner := document.get_element_by_id('player')?
	mut classes := icon.class_list()
	classes.add(['retained'])!
	assert owner.request_fullscreen(.web_driver).state() == .fulfilled
	assert classes.contains('fullscreen') && classes.contains('retained')
	assert !button.class_list().contains('fullscreen')
	assert document.exit_fullscreen().state() == .fulfilled
	assert !classes.contains('fullscreen') && classes.contains('retained')
}

fn test_fullscreen_svg_paths_bubble_activation_to_one_button_listener_and_cleanup_detaches_it() {
	mut document, mut media, controls := fullscreen_svg_owner('video')!
	defer { media.finalize(); document.finalize() }
	button := controls.dom_.fullscreen_button?
	icon := controls.dom_.fullscreen_icon?
	path := icon.as_node().children_as_vector()[0].as_element()?
	button_target := unsafe { &dom.EventTarget(button.as_node()) }
	icon_target := unsafe { &dom.EventTarget(icon.as_node()) }
	assert controls.registered_event_listeners_.len == 26
	assert controls.registered_event_listeners_.filter(it.target == button_target && it.event_name == 'click').len == 1
	assert controls.registered_event_listeners_.filter(it.target == icon_target).len == 0
	mut window := document.get_window()?
	window.set_last_activation_timestamp(dom.current_high_resolution_time(window))
	fullscreen_svg_click(path, true)
	assert document.fullscreen_element()? == document.get_element_by_id('player')?
	fullscreen_svg_click(icon, true)
	assert document.fullscreen_element() == none && media.paused() && media.current_src() == ''
	media.destroy_controls()
	assert controls.dom_.fullscreen_button == none && controls.dom_.fullscreen_icon == none
	fullscreen_svg_click(path, false)
	assert document.fullscreen_element() == none
	media.create_controls()
	assert media.controls_?.dom_.fullscreen_button? != button
	assert media.controls_?.dom_.fullscreen_icon? != icon
}

fn test_fullscreen_svg_is_video_only_and_does_not_replace_an_unowned_shadow_root() {
	mut document, mut media, controls := fullscreen_svg_owner('audio')!
	defer { media.finalize(); document.finalize() }
	assert controls.dom_.fullscreen_button == none && controls.dom_.fullscreen_icon == none
	mut video := document.create_element('video')!
	root := video.attach_a_user_agent_shadow_root(.named)
	mut video_media := html_media_element_for_dom_element(video)?
	defer { video_media.finalize() }
	video_media.create_controls()
	preserved := video_media.controls_?
	assert preserved.dom_.fullscreen_button == none && preserved.dom_.fullscreen_icon == none
	assert video.shadow_root()? == root && unsafe { &dom.Node(root) }.children_as_vector().len == 0
}
