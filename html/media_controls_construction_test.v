module html

import css
import dom

enum ControlsConstructionAction {
	keep
	cancel
	replace
}

@[heap]
struct ControlsConstructionProbe {
	media &HTMLMediaElement
	element &dom.Element
	action ControlsConstructionAction
mut:
	calls int
	first ?&MediaControls
	first_root ?&dom.ShadowRoot
	first_style ?&dom.Element
}

fn controls_construction_policy(target voidptr, style &dom.Element, kind string, source string) bool {
	mut probe := unsafe { &ControlsConstructionProbe(target) }
	assert kind == 'style' && source == media_controls_stylesheet_source
	mut media := probe.media
	mut controls := media.controls_ or { panic('Controller must be published before the policy callback') }
	assert controls.media == media && !controls.destroyed_
	assert controls.registered_event_listeners_.len == 0 && controls.hover_timer_ == none
	assert controls.dom_.container == none && !controls.shadow_tree_created
	root := controls.owned_shadow_root_ or { panic('Missing constructing root') }
	assert (probe.element.shadow_root() or { panic('Missing attached root') }) == root
	assert style.as_node().is_connected()
	probe.calls++
	media.create_controls()
	assert (media.controls_ or { panic('Lost constructing controller') }) == controls
	if probe.calls == 1 {
		probe.first = controls
		probe.first_root = root
		probe.first_style = style
		if probe.action != .keep {
			mut element := probe.element
			element.remove_attribute('controls')
			assert !media.has_controls() && controls.destroyed_ && element.shadow_root() == none
			if probe.action == .replace {
				element.set_attribute_value('controls', 'replacement')
				assert (media.controls_ or { panic('Missing replacement controller') }) != controls
			}
		}
	} else {
		assert probe.action == .replace && probe.calls == 2
		assert (probe.first or { panic('Missing first controller') }) != controls
	}
	// Keep the genuine translated policy decision, including blocked styles.
	return dom_inline_csp_check(unsafe { nil }, style, kind, source)
}

fn controls_construction_check(action ControlsConstructionAction) ! {
	for kind in ['audio', 'video'] {
		url := dom.URL{value: 'https://constructing-controls.example/'}
		head := if action == .keep { '' } else { '<meta http-equiv="Content-Security-Policy" content="style-src \'none\'">' }
		mut document := parse_navigation_document('<!doctype html>${head}<${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
		mut element := document.get_element_by_id('player') or { return error('Missing player') }
		mut media := html_media_element_for_dom_element(element) or { return error('Missing media') }
		defer { media.finalize(); document.finalize() }
		probe := &ControlsConstructionProbe{media: media, element: element, action: action}
		document.set_csp_hook(dom.DocumentCSPHook{target: probe, inline_check: controls_construction_policy})
		element.set_attribute_value('controls', 'initial')
		first := probe.first or { return error('Policy callback did not run') }
		old_root := probe.first_root or { return error('Missing first root') }
		style := probe.first_style or { return error('Missing first style') }
		assert probe.calls == if action == .replace { 2 } else { 1 }
		if action != .keep {
			assert first.destroyed_ && !first.shadow_tree_created && first.dom_.container == none
			assert first.registered_event_listeners_.len == 0 && first.hover_timer_ == none
			assert first.request_animation_frame_id_ == 0 && first.owned_shadow_root_ == none
			assert old_root.host() == none && !style.as_node().is_connected()
			assert css.style_element_sheet(style) == none
		}
		if action == .cancel {
			assert !media.has_controls() && element.shadow_root() == none
			mut window := unsafe { &WindowModel(document.get_window() or { panic('Missing Window') }) }
			assert !window.has_animation_frame_callbacks()
			continue
		}
		controls := media.controls_ or { return error('Missing finished controller') }
		assert (controls == first) == (action == .keep)
		assert controls.shadow_tree_created && !controls.destroyed_
		assert controls.registered_event_listeners_.len == if kind == 'video' { 26 } else { 17 }
		assert (element.shadow_root() or { panic('Missing final root') }) == (controls.owned_shadow_root_ or { panic('Missing owned root') })
		assert (controls.dom_.container or { panic('Missing container') }).as_node().is_connected()
		if action == .keep { assert css.style_element_sheet(style) != none }
		button := controls.dom_.mute_button or { return error('Missing mute button') }
		click := dom.Event.create('click', dom.EventInit{cancelable: true})
		assert !unsafe { &dom.EventTarget(button.as_node()) }.dispatch_event(click)
		assert click.default_prevented() && media.muted()
		mut queue := main_thread_event_loop().task_queue()
		for _ in 0 .. 100 {
			if media.queued_media_task_ids_.len == 0 { break }
			task := queue.take_first_runnable_matching(fn [media] (task &Task) bool { return task.id() in media.queued_media_task_ids_ }) or { panic('Missing media task') }
			task.execute()
		}
		assert media.queued_media_task_ids_.len == 0
		media.destroy_controls()
		assert !media.has_controls() && element.shadow_root() == none
	}
}

fn test_controls_are_published_before_a_reentrant_stylesheet_policy_check() {
	controls_construction_check(.keep)!
}

fn test_controls_construction_stops_when_the_policy_callback_removes_controls() {
	controls_construction_check(.cancel)!
}

fn test_cancelled_controls_construction_cannot_overwrite_a_reentrant_replacement() {
	controls_construction_check(.replace)!
}
