module browserjs

import dom
import html
import page

fn mouse_related_owner_fixture() !(&Runtime, &dom.Document, &html.EnvironmentSettingsObject, &html.WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{
		value: 'https://mouse-related-owner.example.test/'
	}
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	html.parse_html_from_a_string(document,
		'<!doctype html><body><div id="outside"></div><div id="host"></div></body>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings)!
	runtime.install_event_target_binding()!
	runtime.evaluate_host('this.window=this;0')!
	runtime.install_window_current_event_binding()!
	handle := voidptr(runtime)
	// A private test observer over actual native records. This is not a public
	// MouseEvent interface or a replacement event-dispatch implementation.
	runtime.define_value_host_function('__nativeMouseRelated', fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(handle) }
		event := runtime.native_event(args[0])!
		if event.interface_ !in [.mouse_event, .pointer_event, .wheel_event, .drag_event] {
			return error('related-target probe requires an actual mouse-family record')
		}
		mouse := unsafe { &dom.MouseEvent(event) }
		if related := mouse.related_target() {
			return runtime.javascript_event_target(related, none)!
		}
		return C.vox_jsc_JSValueMakeNull(runtime.context)
	})!
	for window in html.all_windows() {
		if voidptr(window) == voidptr(settings.global_object()) {
			return runtime, document, settings, window
		}
	}
	return error('missing actual related-target owner Window')
}

fn mouse_related_owner_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn mouse_related_owner_events(view voidptr, related &dom.EventTarget, composed bool) []&dom.Event {
	init := dom.MouseEventInit{
		EventModifierInit: dom.EventModifierInit{
			UIEventInit: dom.UIEventInit{
				EventInit: dom.EventInit{
					bubbles:    true
					cancelable: true
					composed:   composed
				}
				detail:    7
				view:      view
			}
		}
		related_target:    related
	}
	mouse := dom.MouseEvent.create('related-owner', init)
	pointer :=
		dom.PointerEvent.create('related-owner', dom.PointerEventInit{ MouseEventInit: init })
	wheel := dom.WheelEvent.create('related-owner', dom.WheelEventInit{ MouseEventInit: init })
	drag := html.DragEvent.create('related-owner', html.DragEventInit{ MouseEventInit: init }, 0,
		0, 0, 0)
	return [unsafe { &dom.Event(mouse) }, unsafe { &dom.Event(pointer) }, unsafe { &dom.Event(wheel) },
		unsafe { &dom.Event(drag) }]
}

fn test_native_mouse_family_ui_owner_listener_observes_shadow_retargeted_related_target() {
	$if !darwin { return }
	mut runtime, mut document, settings, window := mouse_related_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := document.get_element_by_id('host')?
	outside := document.get_element_by_id('outside')?
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	related := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut shadow_node := dom.shadow_root_as_node(shadow)
	shadow_node.append_child(related.as_node())!
	out_target := unsafe { &dom.EventTarget(outside) }
	host_target := unsafe { &dom.EventTarget(host) }
	mouse_related_owner_export(mut runtime, '__outsideRelatedOwner', runtime.javascript_event_target(out_target,
		none)!)!
	mouse_related_owner_export(mut runtime, '__relatedShadowHost', runtime.javascript_event_target(host_target,
		none)!)!
	runtime.evaluate_host(r'
globalThis.relatedOwnerTarget=__outsideRelatedOwner();globalThis.relatedOwnerHost=__relatedShadowHost();globalThis.relatedOwnerCalls=0;globalThis.relatedOwnerChecks=[];
relatedOwnerTarget.addEventListener("related-owner",function(event){relatedOwnerCalls++;relatedOwnerChecks.push(this===relatedOwnerTarget&&event===currentRelatedOwnerEvent&&event instanceof UIEvent&&event instanceof Event&&event.isTrusted&&event.view===window&&event.detail===7&&event.target===relatedOwnerTarget&&event.currentTarget===relatedOwnerTarget&&window.event===event&&__nativeMouseRelated(event)===relatedOwnerHost)});0
')!
	for index, event in mouse_related_owner_events(voidptr(window.window().dom_proxy()),
		unsafe { &dom.EventTarget(related) }, true) {
		wrapper := runtime.javascript_event(event)!
		export_name := '__currentRelatedOwnerEvent${index}'
		mouse_related_owner_export(mut runtime, export_name, wrapper)!
		runtime.evaluate_host('globalThis.currentRelatedOwnerEvent=${export_name}();0')!
		assert out_target.dispatch_event(event)
		assert runtime.javascript_event(event)! == wrapper
		assert event.current_target() == none && event.event_phase() == 0
		assert voidptr(event.target()?) == voidptr(out_target)
		assert event.related_target() != none
		assert voidptr(event.related_target()?) == voidptr(host_target)
		mouse := unsafe { &dom.MouseEvent(event) }
		assert voidptr(mouse.related_target()?) == voidptr(host_target)
		assert voidptr(mouse.related_target_mouse()?) == voidptr(host_target)
	}
	assert runtime.evaluate_host('relatedOwnerCalls===4&&relatedOwnerChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert document.get_window()?.current_event() == none
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_mouse_family_nested_shadow_dispatch_clears_related_target_and_restores_owner_after_throw() {
	$if !darwin { return }
	mut runtime, mut document, settings, window := mouse_related_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := document.get_element_by_id('host')?
	outside := document.get_element_by_id('outside')?
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	related := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut shadow_node := dom.shadow_root_as_node(shadow)
	shadow_node.append_child(child.as_node())!
	shadow_node.append_child(related.as_node())!
	child_target := unsafe { &dom.EventTarget(child) }
	related_target := unsafe { &dom.EventTarget(related) }
	out_target := unsafe { &dom.EventTarget(outside) }
	for name, target in {
		'__nestedRelatedOwner':   child_target
		'__nestedRelatedSibling': related_target
		'__nestedRelatedOutside': out_target
		'__nestedRelatedHost':    unsafe { &dom.EventTarget(host) }
	} {
		mouse_related_owner_export(mut runtime, name,
			runtime.javascript_event_target(target, none)!)!
	}
	runtime.evaluate_host(r'
globalThis.nestedRelatedTarget=__nestedRelatedOwner();globalThis.nestedRelatedSibling=__nestedRelatedSibling();globalThis.nestedRelatedOutside=__nestedRelatedOutside();globalThis.nestedRelatedHost=__nestedRelatedHost();globalThis.nestedRelatedChecks=[];globalThis.nestedRelatedCalls=0;globalThis.nestedRelatedHostCalls=0;globalThis.nestedRelatedReason={original:true};
nestedRelatedTarget.addEventListener("related-owner",function(event){nestedRelatedCalls++;nestedRelatedChecks.push(this===nestedRelatedTarget&&event===currentNestedRelatedEvent&&event instanceof UIEvent&&!event.isTrusted&&event.view===window&&event.target===nestedRelatedTarget&&event.currentTarget===nestedRelatedTarget&&window.event===currentOuterRelatedEvent&&__nativeMouseRelated(event)===nestedRelatedSibling);throw nestedRelatedReason});
nestedRelatedTarget.addEventListener("related-owner",function(event){nestedRelatedChecks.push(event===currentNestedRelatedEvent&&window.event===currentOuterRelatedEvent&&__nativeMouseRelated(event)===nestedRelatedSibling)});
nestedRelatedHost.addEventListener("related-owner",function(){nestedRelatedHostCalls++});
nestedRelatedOutside.addEventListener("outer-owner",function(event){nestedRelatedChecks.push(this===nestedRelatedOutside&&event===currentOuterRelatedEvent&&window.event===event);nestedRelatedChecks.push(nestedRelatedTarget.dispatchEvent(currentNestedRelatedEvent)===true);nestedRelatedChecks.push(window.event===event&&currentNestedRelatedEvent.currentTarget===null&&currentNestedRelatedEvent.eventPhase===Event.NONE&&currentNestedRelatedEvent.target===null&&__nativeMouseRelated(currentNestedRelatedEvent)===null)});0
')!
	before_exceptions := settings.realm().reported_exceptions.len
	for index, inner in mouse_related_owner_events(voidptr(window.window().dom_proxy()),
		related_target, true) {
		outer := dom.UIEvent.create('outer-owner', dom.UIEventInit{
			view: voidptr(window.window().dom_proxy())
		})
		inner_wrapper := runtime.javascript_event(inner)!
		outer_wrapper := runtime.javascript_event(unsafe { &dom.Event(outer) })!
		inner_export := '__innerRelatedEvent${index}'
		outer_export := '__outerRelatedEvent${index}'
		mouse_related_owner_export(mut runtime, inner_export, inner_wrapper)!
		mouse_related_owner_export(mut runtime, outer_export, outer_wrapper)!
		runtime.evaluate_host('globalThis.currentNestedRelatedEvent=${inner_export}();globalThis.currentOuterRelatedEvent=${outer_export}();0')!
		assert out_target.dispatch_event(unsafe { &dom.Event(outer) })
		assert runtime.javascript_event(inner)! == inner_wrapper
		assert inner.target() == none && inner.current_target() == none
			&& inner.related_target() == none
		mouse := unsafe { &dom.MouseEvent(inner) }
		assert mouse.related_target() == none && mouse.related_target_mouse() == none
		assert document.get_window()?.current_event() == none
	}
	assert runtime.evaluate_host('nestedRelatedCalls===4&&nestedRelatedHostCalls===0&&nestedRelatedChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert settings.realm().reported_exceptions.len == before_exceptions + 4
	for report in settings.realm().reported_exceptions[before_exceptions..] {
		assert runtime.actual_webidl_value(report.value.as_webidl_value()!)! == runtime.evaluate_host_value('nestedRelatedReason')!
	}
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
