module html

import dom

enum ControlsRemovalReentry {
	explicit
	attribute
	finalize
}

@[heap]
struct ControlsRemovalProbe {
	media &HTMLMediaElement
	controls &MediaControls
	element &dom.Element
	root &dom.Node
	mode ControlsRemovalReentry
mut:
	calls int
}

fn controls_removal_reenter(target voidptr, subtree dom.NodeIsSubtreeRoot, ancestor ?&dom.Node, root &dom.Node) {
	mut probe := unsafe { &ControlsRemovalProbe(target) }
	probe.calls++
	assert probe.calls == 1 && subtree == .no
	assert (ancestor or { panic('Missing removed shadow ancestor') }) == probe.root
	assert root == probe.root && !root.is_connected()
	mut media := probe.media
	assert media.has_controls() && (media.controls_ or { panic('Missing controls') }) == probe.controls
	assert probe.controls.destroyed_ && probe.controls.registered_event_listeners_.len == 0
	assert probe.controls.hover_timer_ == none && probe.controls.request_animation_frame_id_ == 0
	media.create_controls()
	media.destroy_controls()
	assert media.has_controls() && (media.controls_ or { panic('Missing controls') }) == probe.controls
	match probe.mode {
		.explicit {}
		.attribute {
			mut element := probe.element
			element.set_attribute_value('controls', 'during-removal')
			element.remove_attribute('controls')
			element.set_attribute_value('controls', 'retained')
		}
		.finalize { media.finalize() }
	}
	media.create_controls()
	assert media.has_controls() && (media.controls_ or { panic('Missing controls') }) == probe.controls
	assert probe.controls.registered_event_listeners_.len == 0
}

fn controls_removal_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing media task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn controls_removal_check(mode ControlsRemovalReentry) ! {
	for kind in ['audio', 'video'] {
		url := dom.URL{value: 'https://controls-removal.example/'}
		mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
		mut element := document.get_element_by_id('player') or { return error('Missing media element') }
		mut media := html_media_element_for_dom_element(element) or { return error('Missing media owner') }
		defer { media.finalize(); document.finalize() }
		media.set_duration(60)
		media.set_ready_state(.have_enough_data)
		media.network_state_ = .idle
		media.set_paused(false)
		element.set_attribute_value('controls', '')
		controls_removal_drain(media)
		mut controls := media.controls_ or { return error('Missing controls') }
		root := element.shadow_root() or { return error('Missing shadow root') }
		mut bar := (controls.dom_.control_bar or { panic('Missing controls bar') }).as_node()
		button := controls.dom_.mute_button or { return error('Missing mute button') }
		listener_count := controls.registered_event_listeners_.len
		timer := controls.hover_timer_ or { return error('Missing hover timer') }
		assert timer.is_active() && timer.has_activity_root()
		mut window := unsafe { &WindowModel(document.get_window() or { panic('Missing Window') }) }
		frame := controls.request_animation_frame_id_
		assert frame != 0 && window.has_pending_animation_frame_callback(frame)
		probe := &ControlsRemovalProbe{media: media, controls: controls, element: element, root: unsafe { &dom.Node(root) }, mode: mode}
		bar.set_lifecycle_hook(dom.NodeLifecycleHook{target: probe, removed_from: controls_removal_reenter})
		match mode {
			.explicit { media.destroy_controls() }
			.attribute { element.remove_attribute('controls') }
			.finalize { media.finalize() }
		}
		assert probe.calls == 1 && !media.has_controls() && !media.destroying_controls_
		assert element.shadow_root() == none && root.host() == none && !bar.is_connected()
		assert controls.destroyed_ && !controls.shadow_tree_created && controls.dom_.control_bar == none
		assert controls.owned_shadow_root_ == none && controls.registered_event_listeners_.len == 0
		assert !timer.is_active() && !timer.has_activity_root()
		assert !window.has_pending_animation_frame_callback(frame)
		media.fire_event('playing')
		assert !window.has_animation_frame_callbacks()
		stale := dom.Event.create('click', dom.EventInit{cancelable: true})
		assert unsafe { &dom.EventTarget(button.as_node()) }.dispatch_event(stale)
		assert !stale.default_prevented() && !media.muted()
		media.destroy_controls()
		assert probe.calls == 1
		if mode == .finalize { continue }
		if mode == .attribute {
			// As in Optional::clear, a create request during destruction sees the
			// existing value. A later attribute change can create fresh controls.
			assert (element.get_attribute_ns(none, 'controls') or { panic('Missing controls attribute') }) == 'retained'
			element.set_attribute_value('controls', 'after-removal')
		} else {
			media.create_controls()
		}
		mut next := media.controls_ or { return error('Missing replacement controls') }
		assert next != controls && (next.owned_shadow_root_ or { panic('Missing replacement root') }) != root
		assert next.registered_event_listeners_.len == listener_count
		live := dom.Event.create('click', dom.EventInit{cancelable: true})
		assert !unsafe { &dom.EventTarget((next.dom_.mute_button or { panic('Missing replacement mute button') }).as_node()) }.dispatch_event(live)
		assert live.default_prevented() && media.muted()
		controls_removal_drain(media)
		// Caller-owned destruction must not stop the owner from clearing its slot.
		next.destroy()
		media.destroy_controls()
		assert !media.has_controls() && element.shadow_root() == none
	}
}

fn test_explicit_controls_teardown_keeps_the_owner_occupied_during_removal_callbacks() {
	controls_removal_check(.explicit)!
}

fn test_controls_attribute_reentry_cannot_install_an_orphaned_controller() {
	controls_removal_check(.attribute)!
}

fn test_recursive_media_finalization_cannot_restart_controls_timers_or_frames() {
	controls_removal_check(.finalize)!
}
