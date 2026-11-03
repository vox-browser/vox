module browserjs

import dom
import html
import highresolutiontime
import loader
import platform

fn C.JSGarbageCollect(context voidptr)

fn custom_registry_fixture() !(&Runtime, &dom.Document, &html.CustomElementRegistry) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://custom-registry.test/' }
	document := html.parse_navigation_document('<!doctype html><x-widget id="widget" observed="yes"></x-widget><button is="x-button" id="button"></button>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_custom_element_registry_binding()!
	window := unsafe { &html.WindowModel(settings.global_object()) }
	return runtime, document, window.custom_elements()
}

fn test_custom_registry_registration_has_native_identity_and_ordered_metadata() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.install_custom_element_registry_binding()!
	assert runtime.evaluate_host(r'
 globalThis.order=[];globalThis.Widget=function Widget(){};
 const callbacks=["connectedCallback","disconnectedCallback","connectedMoveCallback","adoptedCallback","attributeChangedCallback","formAssociatedCallback","formResetCallback","formDisabledCallback","formStateRestoreCallback"];
 for(const name of callbacks)Object.defineProperty(Widget.prototype,name,{get(){order.push(name);return function(){}}});
 Object.defineProperty(Widget,"observedAttributes",{get(){order.push("observedAttributes");return new Set(["observed","extra"])}});
 Object.defineProperty(Widget,"disabledFeatures",{get(){order.push("disabledFeatures");return ["shadow","internals"]}});
 Object.defineProperty(Widget,"formAssociated",{get(){order.push("formAssociated");return 1}});
 const result=customElements.define("x-widget",Widget);
 result===undefined&&customElements.get("x-widget")===Widget&&customElements.getName(Widget)==="x-widget"&&customElements.get("missing")===undefined&&customElements.getName(()=>{})===null&&
 order.join(",")==="connectedCallback,disconnectedCallback,connectedMoveCallback,adoptedCallback,attributeChangedCallback,observedAttributes,disabledFeatures,formAssociated,formAssociatedCallback,formResetCallback,formDisabledCallback,formStateRestoreCallback";
 ')! == 'true'
	id := registry.get('x-widget')?
	assert registry.get_name(id)? == 'x-widget'
	definition := registry.get_definition_with_name_and_local_name('x-widget', 'x-widget')?
	assert definition.observed_attributes() == ['observed', 'extra']
	assert definition.disable_shadow() && definition.disable_internals() && definition.form_associated()
	assert definition.lifecycle_callbacks().len == 9
	widget := document.get_element_by_id('widget')?
	assert widget.ensure_custom_element_reaction_queue().len == 1
	// Registration queues a real native upgrade; this slice does not execute
	// author constructors or claim that a queued element has been upgraded.
	assert widget.custom_element_state_ == .undefined_
	assert runtime.evaluate_host('globalThis.Button=function(){};customElements.define("x-button",Button,{extends:"button"});customElements.get("x-button")===Button')! == 'true'
	button_definition := registry.get_definition_with_name_and_local_name('x-button', 'button')?
	assert button_definition.local_name() == 'button'
	assert document.get_element_by_id('button')?.ensure_custom_element_reaction_queue().len == 1
}

fn test_custom_registry_webidl_brands_conversions_and_native_definition_checks() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.calls=[];const name={toString(){calls.push("name");return "x-convert"}},options={get extends(){calls.push("extends");return {toString(){calls.push("extends string");return "button"}}}};
 let brands=0;for(const call of [()=>CustomElementRegistry.prototype.get.call({},name),()=>CustomElementRegistry.prototype.define.call({},name,function(){}),()=>Object.getOwnPropertyDescriptor(globalThis,"customElements").get.call({})])try{call()}catch(error){if(error instanceof TypeError)brands++}
 if(calls.length||brands!==3)throw Error("brand order");
 let callable=false;try{customElements.define(name,{},options)}catch(error){callable=error instanceof TypeError}
 if(!callable||calls.join(",")!=="name")throw Error("callback conversion order");
 calls.length=0;let constructor=false;try{customElements.define(name,()=>{},options)}catch(error){constructor=error instanceof TypeError}
 if(!constructor||calls.join(",")!=="name,extends,extends string")throw Error("constructor validation order");
 let failures=0;const C=function(){};
 for(const [n,c,o,kind] of [["invalid",C,{},"SyntaxError"],["x-unknown",C,{extends:"nonesuch"},"NotSupportedError"],["x-custom",C,{extends:"x-parent"},"NotSupportedError"],["x-null",C,{extends:null},"NotSupportedError"]])try{customElements.define(n,c,o)}catch(error){if(error instanceof DOMException&&error.name===kind)failures++}
 customElements.define("x-valid",C);
 for(const action of [()=>customElements.define("x-valid",function(){}),()=>customElements.define("x-other",C)])try{action()}catch(error){if(error instanceof DOMException&&error.name==="NotSupportedError")failures++}
 let types=0;for(const action of [()=>CustomElementRegistry(),()=>customElements.get(),()=>customElements.getName(),()=>customElements.getName({}),()=>customElements.define("x-dictionary",function(){},7),()=>customElements.define(Symbol(),function(){})])try{action()}catch(error){if(error instanceof TypeError)types++}
 failures===6&&types===6&&customElements.getName(C)==="x-valid";
 ')! == 'true'
	assert registry.definition_count() == 1
}

fn test_custom_registry_reentrancy_and_original_getter_iterator_exceptions_are_atomic() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.marker={original:true};globalThis.innerRejected=false;
 const Reentrant=function(){};Object.defineProperty(Reentrant.prototype,"connectedCallback",{get(){try{customElements.define("x-inner",function(){})}catch(error){innerRejected=error instanceof DOMException&&error.name==="NotSupportedError"}throw marker}});
 let original=0;try{customElements.define("x-outer",Reentrant)}catch(error){if(error===marker)original++}
 const BadIterator=function(){};BadIterator.prototype.attributeChangedCallback=function(){};BadIterator.observedAttributes={[Symbol.iterator](){return {next(){throw marker}}}};
 try{customElements.define("x-iterator",BadIterator)}catch(error){if(error===marker)original++}
 const BadString=function(){};BadString.disabledFeatures=[{toString(){throw marker}}];
 try{customElements.define("x-string",BadString)}catch(error){if(error===marker)original++}
 const ProxyC=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype")throw marker;return Reflect.get(target,key,receiver)}});
 try{customElements.define("x-proxy",ProxyC)}catch(error){if(error===marker)original++}
 let invalid=0;const BadCallback=function(){};BadCallback.prototype.connectedCallback=null;
 const BadSequence=function(){};BadSequence.prototype.attributeChangedCallback=function(){};BadSequence.observedAttributes="not a sequence object";
 for(const [name,C] of [["x-callback",BadCallback],["x-sequence",BadSequence]])try{customElements.define(name,C)}catch(error){if(error instanceof TypeError)invalid++}
 // Failed definitions neither reserve a name nor leak the native guard.
 customElements.define("x-outer",function(){});customElements.define("x-inner",function(){});
 original===4&&invalid===2&&innerRejected&&customElements.get("x-iterator")===undefined&&customElements.get("x-proxy")===undefined;
 ')! == 'true'
	assert registry.definition_count() == 2
	assert document.get_element_by_id('widget')?.ensure_custom_element_reaction_queue().len == 0
}

fn test_custom_registry_when_defined_uses_real_promises_and_exact_callback_values() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.fulfilled=[];globalThis.rejections=[];
 globalThis.pending=customElements.whenDefined("x-promise");
 const same=pending===customElements.whenDefined("x-promise");
 pending.then(value=>fulfilled.push(value));
 customElements.whenDefined("invalid").catch(error=>rejections.push(error instanceof DOMException&&error.name==="SyntaxError"));
 const marker={};customElements.whenDefined({toString(){throw marker}}).catch(error=>rejections.push(error===marker));
 CustomElementRegistry.prototype.whenDefined.call({},"x-other").catch(error=>rejections.push(error instanceof TypeError));
 customElements.whenDefined().catch(error=>rejections.push(error instanceof TypeError));
 globalThis.PromiseC=function(){};customElements.define("x-promise",PromiseC);
 customElements.whenDefined("x-promise").then(value=>fulfilled.push(value));
 same&&pending instanceof Promise&&customElements.whenDefined("x-promise")!==customElements.whenDefined("x-promise");
 ')! == 'true'
	assert runtime.evaluate_host('fulfilled.length===2&&fulfilled.every(value=>value===PromiseC)&&rejections.length===4&&rejections.every(Boolean)')! == 'true'
	assert registry.definition_count() == 1
}

fn test_custom_registry_scoped_definitions_are_isolated_and_bind_actual_nodes() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.scoped=new CustomElementRegistry();globalThis.Other=function(){};
 class Derived extends CustomElementRegistry{};const derived=new Derived();
 scoped.define("x-widget",Other);derived.define("x-widget",Other);
 let customized=false;try{scoped.define("x-button",function(){},{extends:"button"})}catch(error){customized=error instanceof DOMException&&error.name==="NotSupportedError"}
 let nodes=0;for(const method of ["upgrade","initialize"])try{scoped[method]({nodeType:1})}catch(error){if(error instanceof TypeError)nodes++}
 const property=Object.getOwnPropertyDescriptor(globalThis,"customElements"),method=Object.getOwnPropertyDescriptor(CustomElementRegistry.prototype,"define");
 property.get&&property.set===undefined&&property.enumerable&&property.configurable&&method.enumerable&&method.writable&&method.configurable&&
 customElements===globalThis.customElements&&customElements instanceof CustomElementRegistry&&Object.prototype.toString.call(scoped)==="[object CustomElementRegistry]"&&
 derived instanceof Derived&&Object.getPrototypeOf(derived)===Derived.prototype&&scoped.get("x-widget")===Other&&derived.get("x-widget")===Other&&customElements.get("x-widget")===undefined&&customized&&nodes===2;
 ')! == 'true'
	assert registry.definition_count() == 0
	assert document.get_element_by_id('widget')?.ensure_custom_element_reaction_queue().len == 0
	mut element := document.get_element_by_id('widget')?
	wrapper := runtime.evaluate_host_value('({})')!
	runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(element) })!
	runtime.define_value_host_function('__registryNode', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	runtime.evaluate_host('customElements.define("x-widget",function(){});')!
	assert element.take_custom_element_reactions().len == 1
	runtime.evaluate_host('customElements.upgrade(__registryNode());')!
	assert element.take_custom_element_reactions().len == 1
	runtime.evaluate_host('customElements.initialize(__registryNode());')!
	assert element.take_custom_element_reactions().len == 1
}

fn test_custom_registry_keeps_captured_callbacks_across_scratch_reset_and_gc() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	mut scratch := platform.begin_thread_scratch('custom element registration')
	runtime.evaluate_host(r'
 globalThis.Retained=function(){};Retained.prototype.connectedCallback=function connected(){};
 customElements.define("x-retained",Retained);
 Retained.prototype.connectedCallback=null;
 ')!
	scratch.finish()
	gc_collect()
	C.JSGarbageCollect(runtime.context)
	assert runtime.evaluate_host('customElements.get("x-retained")===Retained&&customElements.getName(Retained)==="x-retained"')! == 'true'
	definition := registry.get_definition_with_name_and_local_name('x-retained', 'x-retained')?
	assert definition.lifecycle_callbacks() == ['connectedCallback']
	binding := custom_element_registry_bindings_[voidptr(runtime)] or { panic("Missing registry binding") }
	// The registration roots the original callback snapshot, rather than
	// looking up a subsequently replaced prototype property during delivery.
	for _, bound in binding.registries {
		for _, metadata in bound.metadata {
			callback_values := runtime.binding_property(metadata, '5')!
			callback := runtime.binding_property(callback_values, '0')!
			assert C.JSObjectIsFunction(runtime.context, callback)
		}
	}
}

fn test_custom_registry_rejects_unowned_and_worker_environments() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	if _ := runtime.install_custom_element_registry_binding() { assert false } else { assert err.msg().contains('Window settings') }
	assert runtime.evaluate_host('typeof customElements')! == 'undefined'
	url := dom.URL{ value: 'https://custom-registry.test/worker.js' }
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{ creation_url: url, api_base_url: url, origin: url.origin(),
			global: html.SerializedWorkerGlobalScope{ relevant_settings_object_is_secure_context: true }
		}, highresolutiontime.unsafe_shared_current_time())
	mut worker := Runtime.create_for_worker()
	defer { worker.close() }
	worker.bind_scripting_environment(environment.settings)!
	if _ := worker.install_custom_element_registry_binding() { assert false } else { assert err.msg().contains('actual Window') }
	assert worker.evaluate_host('typeof CustomElementRegistry')! == 'undefined'
}

fn test_custom_registry_preserves_domstrings_and_reads_only_required_metadata() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 const property=Object.getOwnPropertyDescriptor(globalThis,"customElements");
 if(property.get.call(null)!==customElements||property.get.call(undefined)!==customElements)throw Error("Window default receiver");
 globalThis.reads=0;const C=function(){};Object.defineProperty(C,"observedAttributes",{get(){reads++;throw Error("must not read")}});
 customElements.define("x-\uFFFD",C);
 if(customElements.get("x-\uD800")!==undefined)throw Error("surrogate aliased replacement");
 const Surrogate=function(){};customElements.define("x-\uD800",Surrogate);
 if(customElements.get("x-\uD800")!==Surrogate||customElements.getName(Surrogate)!=="x-\uD800")throw Error("DOMString code units lost");
 const A=function(){};A.prototype.attributeChangedCallback=function(){};A.observedAttributes=["\uD800"];
 customElements.define("x-attributes",A);
 // Duplicate rejection precedes prototype getters, and snapshots do not
 // consult mutable Array iterator/indexOf methods.
 let duplicate=false;const ProxyC=new Proxy(function(){},{get(){throw Error("must not read prototype")}});
 try{customElements.define("x-attributes",ProxyC)}catch(error){duplicate=error instanceof DOMException&&error.name==="NotSupportedError"}
 const saved=Array.prototype[Symbol.iterator],savedIndex=Array.prototype.indexOf;
 try{Array.prototype[Symbol.iterator]=function(){throw Error("ambient array iterator")};Array.prototype.indexOf=function(){throw Error("ambient indexOf")};customElements.define("x-intrinsics",function(){})}
 finally{Array.prototype[Symbol.iterator]=saved;Array.prototype.indexOf=savedIndex}
 duplicate&&reads===0&&customElements.get("x-\uFFFD")===C;
 ')! == 'true'
	assert registry.definition_count() == 4
	definition := registry.get_definition_with_name_and_local_name('x-attributes', 'x-attributes')?
	attributes := definition.observed_attributes()
	assert attributes.len == 1
	assert attributes[0].bytes() == [u8(0xed), 0xa0, 0x80]
}

fn test_custom_registry_cross_registry_metadata_reentry_preserves_constructor_identity() {
	mut runtime, mut document, registry := custom_registry_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 const scoped=new CustomElementRegistry();let nested=false;
 const Shared=function(){};Object.defineProperty(Shared.prototype,"connectedCallback",{get(){if(!nested){nested=true;scoped.define("x-shared",Shared)}return function(){}}});
 customElements.define("x-shared",Shared);
 if(customElements.getName(Shared)!=="x-shared"||scoped.getName(Shared)!=="x-shared")throw Error("nested constructor identity");
 let duplicate=0;for(const r of [customElements,scoped])try{r.define("x-duplicate",Shared)}catch(error){if(error instanceof DOMException&&error.name==="NotSupportedError")duplicate++}
 const marker={};let failedNested=false;
 const Retried=function(){};Object.defineProperty(Retried.prototype,"connectedCallback",{get(){if(!failedNested){failedNested=true;scoped.define("x-retried",Retried);throw marker}return undefined}});
 let original=false;try{customElements.define("x-retried",Retried)}catch(error){original=error===marker}
 if(customElements.get("x-retried")!==undefined||scoped.getName(Retried)!=="x-retried")throw Error("failed outer reservation");
 customElements.define("x-retried",Retried);
 duplicate===2&&original&&customElements.getName(Retried)==="x-retried"&&scoped.get("x-retried")===Retried;
 ')! == 'true'
	assert registry.definition_count() == 2
	// Unpublished reservations leave no constructor keys or object roots. The
	// existing exception transport retains each original thrown value, so use
	// a primitive exception and check object roots separately from that policy.
	binding := custom_element_registry_bindings_[voidptr(runtime)] or { panic('Missing registry binding') }
	before_ids := binding.constructor_ids.len
	before := custom_registry_object_roots(runtime)
	assert runtime.evaluate_host(r'
 for(let i=0;i<20;i++){const C=function(){};Object.defineProperty(C.prototype,"connectedCallback",{get(){throw 1}});try{customElements.define("x-failed-"+i,C)}catch(error){if(error!==1)throw error}}
 true;
 ')! == 'true'
	assert binding.constructor_ids.len == before_ids
	assert custom_registry_object_roots(runtime) == before
}

fn custom_registry_object_roots(runtime &Runtime) int {
	mut count := 0
	for value in runtime.protected_values_ {
		if C.JSValueIsObject(runtime.context, value) { count++ }
	}
	return count
}
