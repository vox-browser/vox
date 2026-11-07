module browserjs

import dom

// CSS TransitionEvent and AnimationEvent are dispatched as base Events that
// carry their members; script sees them through the realm's TransitionEvent
// and AnimationEvent interfaces.
pub fn (mut runtime Runtime) install_css_event_wrappers() ! {
	owner := voidptr(&runtime)
	runtime.install_event_wrapper_provider(EventWrapperProvider{
		owner:  owner
		create: fn [owner] (event &dom.Event) !voidptr {
			members := event.css_event_members_
			if members == unsafe { nil } { return unsafe { nil } }
			name := match event.interface_ {
				.transition_event { 'TransitionEvent' }
				.animation_event { 'AnimationEvent' }
				else { return unsafe { nil } }
			}
			mut runtime := unsafe { &Runtime(owner) }
			global := C.JSContextGetGlobalObject(runtime.context)
			constructor := runtime.binding_property(global, name)!
			if !C.JSValueIsObject(runtime.context, constructor) { return unsafe { nil } }
			prototype := runtime.binding_property(constructor, 'prototype')!
			adopt := runtime.binding_property(global, '__compactAdoptEventMembers')!
			if !C.JSValueIsObject(runtime.context, adopt) { return unsafe { nil } }
			events := runtime.event_binding()!
			wrapper := runtime.call_javascript_function(events.factory, C.vox_jsc_JSValueMakeUndefined(runtime.context),
				[runtime.binding_string('event'), prototype])!
			runtime.call_javascript_function(adopt, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
				wrapper,
				runtime.binding_string(members.name),
				C.vox_jsc_JSValueMakeNumber(runtime.context, members.elapsed_time),
				runtime.binding_string(members.pseudo_element),
			])!
			return wrapper
		}
	})!
}
