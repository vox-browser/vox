module html

import dom

@[heap]
struct DirectControlsRemovalProbe {
	media &HTMLMediaElement
	controls &MediaControls
	element &dom.Element
	root &dom.Node
	owned bool
mut:
	calls int
}

fn direct_controls_removed(target voidptr, subtree dom.NodeIsSubtreeRoot, ancestor ?&dom.Node, root &dom.Node) {
	mut probe := unsafe { &DirectControlsRemovalProbe(target) }
	probe.calls++
	assert probe.calls == 1 && subtree == .no
	assert (ancestor or { panic('Missing old shadow ancestor') }) == probe.root && root == probe.root
	mut media := probe.media
	assert media.destroying_controls_ && media.has_controls() == probe.owned
	assert probe.controls.destroyed_ && probe.controls.registered_event_listeners_.len == 0
	assert probe.controls.hover_timer_ == none && probe.controls.request_animation_frame_id_ == 0
	media.create_controls()
	media.destroy_controls()
	mut controls := probe.controls
	controls.destroy()
	mut element := probe.element
	element.set_attribute_value('controls', 'reentered')
	element.remove_attribute('controls')
	media.finalize()
	media.create_controls()
	assert media.has_controls() == probe.owned && media.destroying_controls_
	if probe.owned {
		assert (media.controls_ or { panic('Missing retiring controls') }) == controls
	} else {
		assert media.controls_ == none
	}
}

fn direct_controls_drain(media &HTMLMediaElement) {
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

fn direct_controls_check(owned bool) ! {
	for kind in ['audio', 'video'] {
		url := dom.URL{value: 'https://direct-controls.example/'}
		mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
		mut element := document.get_element_by_id('player') or { return error('Missing player') }
		mut media := html_media_element_for_dom_element(element) or { return error('Missing media') }
		defer { media.finalize(); document.finalize() }
		media.set_duration(60)
		media.set_ready_state(.have_enough_data)
		media.network_state_ = .idle
		media.set_paused(false)
		mut controls := if owned {
			media.create_controls()
			media.controls_ or { return error('Missing owned controls') }
		} else { MediaControls.create(media) }
		direct_controls_drain(media)
		root := element.shadow_root() or { return error('Missing shadow root') }
		button := controls.dom_.mute_button or { return error('Missing mute button') }
		mut bar := (controls.dom_.control_bar or { panic('Missing controls bar') }).as_node()
		timer := controls.hover_timer_ or { return error('Missing timer') }
		mut window := unsafe { &WindowModel(document.get_window() or { panic('Missing Window') }) }
		frame := controls.request_animation_frame_id_
		assert timer.is_active() && timer.has_activity_root()
		assert frame != 0 && window.has_pending_animation_frame_callback(frame)
		probe := &DirectControlsRemovalProbe{media: media, controls: controls, element: element, root: unsafe { &dom.Node(root) }, owned: owned}
		bar.set_lifecycle_hook(dom.NodeLifecycleHook{target: probe, removed_from: direct_controls_removed})
		controls.destroy()
		assert probe.calls == 1 && !media.has_controls() && !media.destroying_controls_
		assert element.shadow_root() == none && root.host() == none && !bar.is_connected()
		assert controls.destroyed_ && !controls.shadow_tree_created && controls.owned_shadow_root_ == none
		assert controls.dom_.control_bar == none && controls.registered_event_listeners_.len == 0
		assert !timer.is_active() && !timer.has_activity_root()
		assert !window.has_pending_animation_frame_callback(frame)
		stale := dom.Event.create('click', dom.EventInit{cancelable: true})
		assert unsafe { &dom.EventTarget(button.as_node()) }.dispatch_event(stale)
		assert !media.muted() && !stale.default_prevented()
		controls.destroy()
		media.destroy_controls()
		assert probe.calls == 1
		element.set_attribute_value('controls', 'after-destruction')
		mut next := media.controls_ or { return error('Missing new controls') }
		assert next != controls && (next.owned_shadow_root_ or { panic('Missing new root') }) != root
		live := dom.Event.create('click', dom.EventInit{cancelable: true})
		assert !unsafe { &dom.EventTarget((next.dom_.mute_button or { panic('Missing new mute button') }).as_node()) }.dispatch_event(live)
		assert media.muted() && live.default_prevented()
		direct_controls_drain(media)
		next.destroy()
		assert !media.has_controls() && element.shadow_root() == none && !media.destroying_controls_
	}
}

fn test_direct_destruction_of_owned_controls_uses_the_media_teardown_barrier() {
	direct_controls_check(true)!
}

fn test_direct_standalone_adapter_destruction_blocks_reentrant_control_creation() {
	direct_controls_check(false)!
}

fn test_destroying_a_preserving_adapter_keeps_the_actual_controller_and_its_events() {
	url := dom.URL{value: 'https://preserving-controls.example/'}
	mut document := parse_navigation_document('<!doctype html><audio id="player" controls preload="none"></audio>', url, url.origin(), none)!
	mut element := document.get_element_by_id('player')?
	mut media := html_media_element_for_dom_element(element)?
	defer { media.finalize(); document.finalize() }
	mut controls := media.controls_?
	root := element.shadow_root()?
	mut adapter := MediaControls.create(media)
	assert adapter.owned_shadow_root_ == none && adapter.registered_event_listeners_.len == 13
	adapter.destroy()
	assert adapter.destroyed_ && adapter.registered_event_listeners_.len == 0
	assert !media.destroying_controls_ && media.controls_? == controls && !controls.destroyed_
	assert element.shadow_root()? == root && controls.registered_event_listeners_.len == 17
	click := dom.Event.create('click', dom.EventInit{cancelable: true})
	assert !unsafe { &dom.EventTarget(controls.dom_.mute_button?.as_node()) }.dispatch_event(click)
	assert media.muted() && click.default_prevented()
	direct_controls_drain(media)
	controls.destroy()
	assert !media.has_controls() && element.shadow_root() == none
	mut ownerless := HTMLMediaElement.create(none, url)
	mut standalone := MediaControls.create(ownerless)
	standalone.destroy()
	assert !ownerless.has_controls() && !ownerless.destroying_controls_
	ownerless.create_controls()
	mut owned := ownerless.controls_?
	owned.destroy()
	assert !ownerless.has_controls() && !ownerless.destroying_controls_ && owned.destroyed_
	ownerless.finalize()
}
