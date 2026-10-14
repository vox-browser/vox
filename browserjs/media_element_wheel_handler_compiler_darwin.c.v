// Raw media wheel and lifecycle handlers share FunctionBody compilation and scopes.
module browserjs

import dom
import html

fn (host &ElementWheelHost) live_raw_media_wheel_hosts() []&MediaElementHost {
	return host.runtime.media_element_hosts_.filter(!it.closed
		&& voidptr(it.runtime) == voidptr(host.runtime)
		&& voidptr(it.document) == voidptr(host.document)
		&& voidptr(it.settings) == voidptr(host.settings))
}

// Probe cached state only. The actual MediaElementHost bind creates the model.
fn cached_raw_wheel_media(element &dom.Element) ?&html.HTMLMediaElement {
	if element.local_name() == 'audio' {
		audio := unsafe { &dom.HTMLAudioElement(element) }
		if audio.media_element_model_ == unsafe { nil } { return none }
		return unsafe { &html.HTMLMediaElement(audio.media_element_model_) }
	}
	video := unsafe { &dom.HTMLVideoElement(element) }
	if video.media_element_model_ == unsafe { nil } { return none }
	return unsafe { &html.HTMLMediaElement(video.media_element_model_) }
}

fn (mut host ElementWheelHost) raw_media_wheel_handler_available(target &dom.EventTarget, element &dom.Element, name string) bool {
	if name !in ['wheel', 'play', 'pause', 'playing', 'waiting', 'canplay', 'canplaythrough', 'loadedmetadata', 'loadeddata', 'ratechange', 'volumechange', 'timeupdate', 'durationchange', 'seeking', 'seeked'] { return false }
	if host.live_raw_media_wheel_hosts().len == 0 { return false }
	binding := host.runtime.event_binding() or { return false }
	mut wrapper := binding.target_wrappers[voidptr(target)] or { voidptr(0) }
	if wrapper == unsafe { nil } {
		if host.resolver == unsafe { nil } { return false }
		slot := target.data.event_handler_map[name] or { return false }
		if slot.value.kind != .string { return false }
		body := slot.value.string_data
		// Upstream parses and checks early errors before creating scope wrappers.
		// Leave malformed bodies to compile() so it nulls only the handler value.
		if !host.runtime.raw_wheel_handler_body_is_valid(name, body) { return true }
		mut vm := host.runtime.agent_vm
		mut context := host.runtime.realm_context
		vm.push_execution_context(mut context)
		wrapper = host.resolve_wheel_element_wrapper(target) or { voidptr(0) }
		popped := vm.pop_execution_context()
		assert voidptr(popped) == voidptr(context)
		// A resolver may remove or replace the slot; do not compile stale source.
		current := target.data.event_handler_map[name] or { return false }
		if voidptr(current) != voidptr(slot) || current.value.kind != .string
			|| current.value.string_data != body { return false }
	}
	if host.closed || host.runtime.closed || host.runtime.context == unsafe { nil }
		|| wrapper == unsafe { nil } || voidptr(element.document()) != voidptr(host.document) {
		return false
	}
	bound_wrapper := binding.target_wrappers[voidptr(target)] or { voidptr(0) }
	if bound_wrapper != wrapper { return false }
	actual := binding.targets[wrapper] or { return false }
	if voidptr(actual) != voidptr(target) { return false }
	model := cached_raw_wheel_media(element) or { return false }
	if voidptr(model.event_target()) != voidptr(target) { return false }
	model_document := model.document() or { return false }
	if voidptr(model_document) != voidptr(host.document) { return false }
	for owner in host.live_raw_media_wheel_hosts() {
		owned := owner.records[wrapper] or { continue }
		if voidptr(owned) == voidptr(model) { return true }
	}
	return false
}
