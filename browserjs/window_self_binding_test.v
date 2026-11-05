module browserjs

import dom
import html
import page

fn window_self_fixture() !(&Runtime, &dom.Document) {
	owner := page.Page.create(1)!
	address := dom.URL{ value: 'https://self.example/' }
	document := html.create_navigation_document_for_page(address, address.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings)!
	runtime.install_window_self_binding()!
	return runtime, document
}

fn test_window_self_uses_actual_global_identity_and_replaceable_attribute_semantics() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_self_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const attribute=Object.getOwnPropertyDescriptor(globalThis,"self");
 const metadata=attribute.enumerable&&attribute.configurable&&attribute.get.name==="get self"&&attribute.get.length===0&&attribute.set.name==="set self"&&attribute.set.length===1&&attribute.get.prototype===undefined&&attribute.set.prototype===undefined;
 let invalid=0;for(const callback of [()=>attribute.get.call({}),()=>attribute.set.call({},1)]){try{callback()}catch(error){if(error instanceof TypeError)invalid++}}
 const identity=self===globalThis&&self.self===self&&attribute.get.call(null)===globalThis;
 const marker={};self=marker;const replaced=Object.getOwnPropertyDescriptor(globalThis,"self");
 const replaceable=self===marker&&replaced.value===marker&&replaced.writable&&replaced.enumerable&&replaced.configurable&&replaced.get===undefined&&attribute.get.call(globalThis)===globalThis;
 delete globalThis.self;globalThis.savedSelfGetter=attribute.get;
 metadata&&identity&&replaceable&&invalid===2&&!("self" in globalThis);
 ')! == 'true'
	runtime.install_window_self_binding()!
	assert runtime.evaluate_host('!("self" in globalThis)&&savedSelfGetter.call(globalThis)===globalThis')! == 'true'
}

fn test_window_self_is_isolated_between_actual_window_realms() {
	$if !darwin && !linux {
		return
	}
	mut first, mut first_document := window_self_fixture()!
	mut second, mut second_document := window_self_fixture()!
	defer {
		first.close()
		second.close()
		first_document.finalize()
		second_document.finalize()
	}
	assert first.evaluate_host('self===globalThis')! == 'true'
	assert second.evaluate_host('self===globalThis')! == 'true'
	first.evaluate_host('self="replaced in first realm"')!
	assert second.evaluate_host('self===globalThis&&typeof self==="object"')! == 'true'
	assert first.evaluate_host('self==="replaced in first realm"')! == 'true'
}

fn test_window_interface_object_brands_the_actual_global() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_self_fixture()!
	mut other, mut other_document := window_self_fixture()!
	defer {
		runtime.close()
		other.close()
		document.finalize()
		other_document.finalize()
	}
	assert runtime.evaluate_host(r'
 let illegal=false;try{new Window()}catch(error){illegal=error instanceof TypeError}
 const descriptor=Object.getOwnPropertyDescriptor(globalThis,"Window");
 const brand=globalThis instanceof Window&&self instanceof Window&&!({} instanceof Window)&&!(Object.create(null) instanceof Window);
 const tag=Object.prototype.toString.call(globalThis)==="[object Window]";
 const proto=Window.prototype.constructor===Window&&(typeof EventTarget!=="function"||Object.getPrototypeOf(Window.prototype)===EventTarget.prototype);
 illegal&&brand&&tag&&proto&&descriptor.writable&&!descriptor.enumerable&&descriptor.configurable;
 ')! == 'true'
	// Each realm's interface object recognizes only its own global.
	other.evaluate_host('globalThis.otherWindow=Window')!
	assert runtime.evaluate_host('typeof Window==="function"')! == 'true'
	assert other.evaluate_host('otherWindow===Window&&globalThis instanceof Window')! == 'true'
}
