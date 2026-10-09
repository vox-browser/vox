module main

import browserjs
import css
import dom
import html
import layout
import page
import time

fn media_css_opacity(element &dom.Element) f32 {
	computed := css.computed_properties_for_element(element) or { panic('missing computed media style') }
	return computed.opacity()
}

fn test_native_media_state_changes_refresh_real_sibling_has_and_pseudo_element_styles() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<style>
 #player{opacity:.1}#player:paused{opacity:.2}#player:playing{opacity:.3}
 #sibling,#ancestor{opacity:.1}#player:muted + #sibling{opacity:.4}
 body:has(#player:muted) #ancestor{opacity:.5}
 #player::before{content:"state";opacity:.1}#player:muted::before{opacity:.6}
 </style><video id="player"></video><div id="sibling"></div><div id="ancestor"></div>', dom.URL{
		value: 'https://native-media-css.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	layout.install_document_layout_hook(document)
	_ = layout.run_document_layout(document, 320, 240) or { panic(err) }
	element := document.get_element_by_id('player')?
	sibling := document.get_element_by_id('sibling')?
	ancestor := document.get_element_by_id('ancestor')?
	mut media := html.html_media_element_for_dom_element(element)?
	assert media_css_opacity(element) == f32(0.2)
	assert media_css_opacity(sibling) == f32(0.1) && media_css_opacity(ancestor) == f32(0.1)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.volumeEvents=0;EventTarget.prototype.addEventListener.call(player,"volumechange",()=>volumeEvents++);'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('player.muted=true;player.muted&&volumeEvents===0')! == 'true'
	assert element.as_node().needs_style_update()
	document.update_style()
	assert media_css_opacity(sibling) == f32(0.4) && media_css_opacity(ancestor) == f32(0.5)
	assert css.computed_properties_for_pseudo_element(element, .before)?.opacity() == f32(0.6)
	assert runtime.evaluate_host('player.muted=false;!player.muted&&volumeEvents===0')! == 'true'
	document.update_style()
	assert media_css_opacity(sibling) == f32(0.1) && media_css_opacity(ancestor) == f32(0.1)
	assert css.computed_properties_for_pseudo_element(element, .before)?.opacity() == f32(0.1)
	media.play()
	assert !media.paused() && media.blocked()
	document.update_style()
	assert media_css_opacity(element) == f32(0.3)
	assert runtime.evaluate_host('player.pause();player.paused')! == 'true'
	document.update_style()
	assert media_css_opacity(element) == f32(0.2)
	owner.set_page_mute_state(.muted)
	assert !element.as_node().needs_style_update()
	document.update_style()
	assert media_css_opacity(sibling) == f32(0.1)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('volumeEvents===2')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_seeking_and_buffering_dependencies_follow_the_adopted_actual_document() {
	url := dom.URL{ value: 'https://adopted-media-css.example.test/' }
	mut source := html.parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	mut destination := html.parse_navigation_document('<style>
 #player{opacity:.1}#player:seeking{opacity:.7}
 #probe{opacity:.2}#player:buffering + #probe{opacity:.8}
 </style><div id="probe"></div>', url, url.origin(), none)!
	layout.install_document_layout_hook(source)
	layout.install_document_layout_hook(destination)
	element := source.get_element_by_id('player')?
	mut media := html.html_media_element_for_dom_element(element)?
	mut node := element.as_node()
	node.remove(false)
	destination.adopt_node(node)
	body := unsafe { &dom.Element(destination.body()?) }
	mut body_node := body.as_node()
	body_node.insert_before(node, body_node.first_child(), false)
	_ = layout.run_document_layout(destination, 320, 240) or { panic(err) }
	probe := destination.get_element_by_id('probe')?
	assert media.document()? == destination
	assert media_css_opacity(element) == f32(0.1) && media_css_opacity(probe) == f32(0.8)
	media.set_seeking(true)
	destination.update_style()
	assert media_css_opacity(element) == f32(0.7)
	media.set_ready_state(.have_future_data)
	destination.update_style()
	assert media_css_opacity(probe) == f32(0.2)
	media.set_seeking(false)
	media.set_ready_state(.have_current_data)
	destination.update_style()
	assert media_css_opacity(element) == f32(0.1) && media_css_opacity(probe) == f32(0.8)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
}

fn test_media_state_dependencies_refresh_inside_the_owning_shadow_style_scope() {
	url := dom.URL{ value: 'https://shadow-media-css.example.test/' }
	mut document := html.parse_navigation_document('<div id="host"></div><div id="outside" class="probe"></div>', url, url.origin(), none)!
	mut host := document.get_element_by_id('host')?
	root := host.attach_shadow(dom.ShadowRootInit{ mode: .closed })!
	video := document.create_element('video')!
	mut probe := document.create_element('span')!
	probe.set_attribute_value('class', 'probe')
	mut root_node := unsafe { &dom.Node(root) }
	root_node.append_child(video.as_node())!
	root_node.append_child(probe.as_node())!
	css.add_shadow_root_author_style_sheet(root,
		'video{opacity:.1}video:paused{opacity:.2}video:playing{opacity:.3}.probe{opacity:.4}video:muted ~ .probe{opacity:.7}')
	layout.install_document_layout_hook(document)
	_ = layout.run_document_layout(document, 320, 240) or { panic(err) }
	mut media := html.html_media_element_for_dom_element(video)?
	assert media_css_opacity(video) == f32(0.2) && media_css_opacity(probe) == f32(0.4)
	media.set_paused(false)
	media.set_muted(true)
	document.update_style()
	assert media_css_opacity(video) == f32(0.3) && media_css_opacity(probe) == f32(0.7)
	outside := document.get_element_by_id('outside')?
	assert media_css_opacity(outside) == f32(1)
	media.set_paused(true)
	media.set_muted(false)
	document.update_style()
	assert media_css_opacity(video) == f32(0.2) && media_css_opacity(probe) == f32(0.4)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
}
