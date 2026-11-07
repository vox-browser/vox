module main

import browserjs
import dom
import html

fn test_native_transition_and_animation_events_expose_their_members() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'globalThis.seen=[];target.addEventListener("transitionend",e=>seen.push([e instanceof TransitionEvent,e.propertyName,e.elapsedTime,JSON.stringify(e.pseudoElement)].join(" ")));target.addEventListener("animationstart",e=>seen.push([e instanceof AnimationEvent,e.animationName,e.elapsedTime].join(" ")));',
	], runtime, mut messages)
	target := document.get_element_by_id('target') or { panic('missing target') }
	for item in [['transitionend', 'opacity'], ['animationstart', 'spin']] {
		mut event := dom.Event.create(item[0], dom.EventInit{ bubbles: true })
		event.interface_ = if item[0] == 'transitionend' { dom.EventInterface.transition_event } else { .animation_event }
		event.css_event_members_ = &dom.CSSEventMembers{
			name:         item[1]
			elapsed_time: 0.5
		}
		target.as_node().dispatch_event(event)
	}
	assert runtime.evaluate_host('seen.join("|")')! == 'true opacity 0.5 ""|true spin 0.5'
}
