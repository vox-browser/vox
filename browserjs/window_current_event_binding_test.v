module browserjs

import dom
import html
import page

fn native_window_current_event_fixture() !(&Runtime, &dom.Document, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{'https://native-window-event.example/'}
	document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings)!
	runtime.evaluate_host('this.window=this')!
	runtime.install_window_current_event_binding()!
	return runtime, document, settings
}

fn test_native_window_event_has_source_accessor_metadata_brand_checks_and_replaceable_data_property() {
	$if !darwin {
		return
	}
	mut runtime, mut document, _ := native_window_current_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const own=Object.getOwnPropertyDescriptor(window,"event"),prototype=Object.getPrototypeOf(window);
 globalThis.originalEventGetter=own.get;
 let invalid=0;for(const callback of [()=>own.get.call({}),()=>own.set.call({},1),()=>own.get.call(prototype)]){try{callback()}catch(reason){if(reason instanceof TypeError)invalid++}}
 const metadata=own.enumerable&&own.configurable&&own.get.name==="get event"&&own.get.length===0&&own.set.name==="set event"&&own.set.length===1&&own.get.prototype===undefined&&own.set.prototype===undefined&&window.event===undefined&&own.get.call(null)===undefined&&invalid===3;
 const marker={};window.event=marker;const replacement=Object.getOwnPropertyDescriptor(window,"event");
 const replaceable=window.event===marker&&replacement.value===marker&&replacement.writable&&replacement.enumerable&&replacement.configurable&&replacement.get===undefined;
 delete window.event;metadata&&replaceable&&window.event===undefined&&!Object.prototype.hasOwnProperty.call(window,"event")&&Object.getPrototypeOf(window)===prototype;
 ')! == 'true'
	runtime.install_window_current_event_binding()!
	assert runtime.evaluate_host('!Object.prototype.hasOwnProperty.call(window,"event")&&originalEventGetter.call(window)===undefined')! == 'true'
	assert document.get_window()?.current_event() == none
}

fn test_native_window_event_keeps_original_event_identity_across_nested_dispatch_and_exception() {
	$if !darwin {
		return
	}
	mut runtime, mut document, settings := native_window_current_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.currentEventOrder=[];globalThis.originalCurrentEventError={};
 const outerTarget=new EventTarget(),innerTarget=new EventTarget(),outer=new Event("outer"),inner=new Event("inner");
 innerTarget.addEventListener("inner",function(value){currentEventOrder.push(window.event===value&&value===inner);throw originalCurrentEventError});
 outerTarget.addEventListener("outer",function(value){currentEventOrder.push(window.event===value&&value===outer);innerTarget.dispatchEvent(inner);currentEventOrder.push(window.event===value)});
 const before=window.event===undefined;outerTarget.dispatchEvent(outer);before&&currentEventOrder.length===3&&currentEventOrder.every(Boolean)&&window.event===undefined;
 ')! == 'true'
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('originalCurrentEventError')!
	assert document.get_window()?.current_event() == none
}

fn test_native_window_event_replacement_and_deletion_leave_the_native_current_event_slot_intact() {
	$if !darwin {
		return
	}
	mut runtime, mut document, _ := native_window_current_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const target=new EventTarget(),nativeEvent=new Event("replacement"),marker={},getCurrent=Object.getOwnPropertyDescriptor(window,"event").get;
 let correct=false;target.addEventListener("replacement",function(value){window.event=marker;const own=Object.getOwnPropertyDescriptor(window,"event");const replaced=window.event===marker&&own.value===marker;delete window.event;correct=replaced&&window.event===undefined&&getCurrent.call(window)===value&&value===nativeEvent});
 target.dispatchEvent(nativeEvent);correct&&window.event===undefined&&getCurrent.call(window)===undefined;
 ')! == 'true'
	assert document.get_window()?.current_event() == none
}

fn test_native_window_event_preserves_source_shadow_tree_current_event_rule() {
	$if !darwin {
		return
	}
	mut runtime, mut document, _ := native_window_current_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut shadow_node := dom.shadow_root_as_node(shadow)
	shadow_node.append_child(child.as_node())!
	wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(child) }, none)!
	runtime.define_value_host_function('__actualShadowEventTarget', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	assert runtime.evaluate_host(r'
 const shadowTarget=__actualShadowEventTarget(),shadow=new Event("shadow"),outerTarget=new EventTarget(),outer=new Event("outer");
 let calls=0,correct=true;shadowTarget.addEventListener("shadow",function(value){correct=correct&&value===shadow&&window.event===(calls===0?undefined:outer);calls++});
 shadowTarget.dispatchEvent(shadow);outerTarget.addEventListener("outer",function(value){shadowTarget.dispatchEvent(shadow);correct=correct&&window.event===value});outerTarget.dispatchEvent(outer);
 correct&&calls===2&&window.event===undefined;
 ')! == 'true'
	assert document.get_window()?.current_event() == none
}

fn test_native_window_event_registration_uses_actual_global_after_author_replaces_global_this() {
	$if !darwin {
		return
	}
	owner := page.Page.create(1)!
	url := dom.URL{'https://native-window-event.example/'}
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.bind_scripting_environment(settings)!
	runtime.install_event_target_binding()!
	runtime.evaluate_host('this.window=this;this.replacedGlobal={};this.globalThis=replacedGlobal')!
	runtime.install_window_current_event_binding()!
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(window,"event").get!==undefined&&window.event===undefined&&!Object.prototype.hasOwnProperty.call(replacedGlobal,"event")')! == 'true'
}

fn test_native_window_event_replaceable_setter_throws_when_its_data_property_cannot_be_created() {
	$if !darwin {
		return
	}
	mut runtime, mut document, _ := native_window_current_event_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const setter=Object.getOwnPropertyDescriptor(window,"event").set,marker=Symbol("original");
 window.event=marker;Object.defineProperty(window,"event",{writable:false,configurable:false});
 let correct=false;try{setter.call(window,{toString(){throw "unexpected conversion"}})}catch(reason){correct=reason instanceof TypeError}
 correct&&window.event===marker;
 ')! == 'true'
	assert document.get_window()?.current_event() == none
}
