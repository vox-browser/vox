module browserjs

import css
import dom
import html
import json2
import page

@[heap]
struct ElementWheelFixture {
	runtime  &Runtime
	host     &ElementWheelHost
	owner    &page.Page
	document &dom.Document
	settings &html.EnvironmentSettingsObject
}

fn element_wheel_fixture() !&ElementWheelFixture {
	owner := page.Page.create(1)!
	url := dom.URL{
		value: 'https://native-element-wheel.example.test/'
	}
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document,
		'<div id="wheelDiv"><span></span></div><button id="wheelButton"></button><svg id="wheelSVG"></svg><img id="wheelImage">')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := ElementWheelHost.create(document)!
	host.install(mut runtime)!
	runtime.install_window_event_handler_binding()!
	runtime.evaluate_host(r'
globalThis.elementWheelSpecs=Object.create(null);globalThis.elementWheelFacades=Object.create(null);
globalThis.elementWheelResolverCalls=0;
globalThis.elementWheelLegacyFacade=function(){return {
 legacyAdds:[],legacyRemoves:[],
 addEventListener:function(type,callback,options){this.legacyAdds.push([type,callback,options,arguments.length]);},
 removeEventListener:function(type,callback,options){this.legacyRemoves.push([type,callback,options,arguments.length]);}
}};
globalThis.elementWheelResolve=function(key){
 if(elementWheelFacades[key])return elementWheelFacades[key];
 const spec=elementWheelSpecs[key];if(!spec)return null;
 const wrapper=elementWheelLegacyFacade();
 __ladybirdElementWheelBind(wrapper,key,spec.tag,spec.namespace);
 elementWheelFacades[key]=wrapper;elementWheelResolverCalls++;return wrapper;
};
__ladybirdElementWheelSetResolver(elementWheelResolve);
0')!
	for key, element in host.elements_for_binding() {
		id := element.get_attribute_value('id')
		namespace := element.namespace_uri() or { '' }
		spec := json2.encode({
			'tag':       element.local_name()
			'namespace': namespace
		})
		runtime.evaluate_host('elementWheelSpecs[${json2.encode(key)}]=${spec};0')!
		if id != '' {
			runtime.evaluate_host('globalThis[${json2.encode(id)}]=elementWheelResolve(${json2.encode(key)});0')!
		}
	}
	handle := voidptr(runtime)
	runtime.define_value_host_function('__elementWheelContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	return &ElementWheelFixture{
		runtime:  runtime
		host:     host
		owner:    owner
		document: document
		settings: settings
	}
}

fn element_wheel_native_event(fixture &ElementWheelFixture) &dom.Event {
	view := voidptr(fixture.document.get_window() or { panic('missing wheel owner Window') })
	wheel := dom.WheelEvent.create_from_platform_event(view, 'wheel', dom.CSSPixelPoint_{
		x_: 30.5
		y_: -40.75
	}, dom.CSSPixelPoint_{
		x_: 13.75
		y_: 24.625
	}, dom.CSSPixelPoint_{
		x_: 3.75
		y_: 4.625
	}, dom.CSSPixelPoint_{
		x_: 1.25
		y_: 2.5
	}, 2.5, -3.5, 2, 5, dom.modifier_ctrl | dom.modifier_alt)
	return unsafe { &dom.Event(wheel) }
}

fn element_wheel_assert_contexts(fixture &ElementWheelFixture) {
	assert fixture.settings.realm().script_execution_depth == 0
	assert fixture.settings.realm().callback_execution_depth == 0
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn element_wheel_expect_original_exception(mut runtime Runtime, source string, value voidptr) {
	runtime.evaluate_host_value(source) or {
		if err is JavaScriptValueException {
			assert err.value == value
			return
		}
		panic('expected actual JavaScript exception: ${err}')
	}
	panic('missing actual JavaScript exception')
}

fn test_native_element_wheel_host_brands_before_conversion_and_preserves_legacy_and_lazy_identity() {
	$if !darwin { return }
	fixture := element_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(function(){
 const add=wheelDiv.addEventListener,remove=wheelDiv.removeEventListener,dispatch=wheelDiv.dispatchEvent;
 let reads=0;const type={toString(){reads++;return "wheel"}},options=new Proxy({}, {get(){reads++;throw "options"}}),validEvent=new Event("brand");
 const proxy=new Proxy(wheelDiv,{get(){reads++;throw "receiver"},getPrototypeOf(){reads++;throw "receiver"}});
 for(const receiver of [{},null,undefined,1,proxy])for(const invoke of [
  ()=>add.call(receiver,type,()=>{},options),()=>remove.call(receiver,type,()=>{},options),()=>dispatch.call(receiver,validEvent)
 ]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 if(reads!==0)return false;
 for(const invoke of [()=>add.call(wheelDiv,type),()=>remove.call(wheelDiv,type),()=>dispatch.call(wheelDiv)]){
  let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}if(!rejected)return false;
 }
 if(reads!==0)return false;
 const callback={};const legacyType={[Symbol.toPrimitive](hint){reads++;if(hint!=="string")throw "hint";return "load"}};
 add.call(wheelDiv,legacyType,callback,options);remove.call(wheelDiv,legacyType,callback,options);
 const added=wheelDiv.legacyAdds[0],removed=wheelDiv.legacyRemoves[0];
 if(reads!==2||added[0]!=="load"||removed[0]!=="load"||added[1]!==callback||removed[1]!==callback||added[2]!==options||removed[2]!==options)return false;
 const noop=()=>{};add.call(wheelDiv,type,noop);remove.call(wheelDiv,"wheel",noop);
 if(reads!==3)return false;
 let captureReads=0;remove.call(wheelDiv,"wheel",noop,{get capture(){captureReads++;return false},get once(){throw "once"},get passive(){throw "passive"},get signal(){throw "signal"}});
 if(captureReads!==1)return false;
 globalThis.elementWheelOriginalReason={actual:true};
 try{wheelDiv.addEventListener({toString(){throw elementWheelOriginalReason}},()=>{});return false}catch(error){if(error!==elementWheelOriginalReason)return false}
 for(const value of [Symbol("type")]){try{wheelDiv.addEventListener(value,()=>{});return false}catch(error){if(!(error instanceof TypeError))return false}}
 globalThis.elementWheelCreated=elementWheelLegacyFacade();
 __ladybirdElementWheelBind(elementWheelCreated,"__created_element_wheel","div","http://www.w3.org/1999/xhtml");
 __ladybirdElementWheelBind(elementWheelCreated,"__created_element_wheel","div","http://www.w3.org/1999/xhtml");
 globalThis.elementWheelQualified=elementWheelLegacyFacade();
 __ladybirdElementWheelBind(elementWheelQualified,"__created_qualified_wheel","svg:rect","http://www.w3.org/2000/svg");
 globalThis.elementWheelNullNamespace=elementWheelLegacyFacade();
 __ladybirdElementWheelBind(elementWheelNullNamespace,"__created_null_wheel","widget",null);
 for(const [tag,namespace] of [["bad name","http://www.w3.org/2000/svg"],["svg:rect",null]]){
  let rejected=false;try{__ladybirdElementWheelBind(elementWheelLegacyFacade(),"__created_invalid_wheel",tag,namespace)}catch(error){rejected=error instanceof Error}
  if(!rejected)return false;
 }
 return typeof add==="function"&&add.length===2&&remove.length===2&&dispatch.length===1&&!!Object.getOwnPropertyDescriptor(wheelDiv,"onwheel");
})()')! == 'true'
	marker := runtime.evaluate_host_value('elementWheelOriginalReason')!
	element_wheel_expect_original_exception(mut runtime,
		'wheelDiv.addEventListener("wheel",()=>{},{get capture(){throw elementWheelOriginalReason}})',
		marker)
	element_wheel_expect_original_exception(mut runtime,
		'wheelDiv.removeEventListener({toString(){throw elementWheelOriginalReason}},()=>{})',
		marker)
	for name in ['wheelDiv', 'wheelButton', 'wheelSVG', 'wheelImage'] {
		element := fixture.document.get_element_by_id(name) or { panic('missing bound element') }
		wrapper := runtime.evaluate_host_value(name)!
		assert voidptr(runtime.native_event_target(wrapper)!) == voidptr(element.as_node())
		assert runtime.javascript_event_target(unsafe { &dom.EventTarget(element) }, none)! == wrapper
	}
	created := fixture.host.elements_for_binding()['__created_element_wheel'] or {
		panic('created wheel element was not retained')
	}
	assert created.local_name() == 'div'
	assert (created.namespace_uri() or { '' }) == 'http://www.w3.org/1999/xhtml'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('elementWheelCreated')!)!) == voidptr(created.as_node())
	assert voidptr(runtime.canvas_elements_for_binding()['__created_element_wheel'] or {
		panic('created wheel element provider is missing')
	}) == voidptr(created)
	qualified := fixture.host.elements_for_binding()['__created_qualified_wheel'] or {
		panic('qualified SVG owner is missing')
	}
	assert qualified.local_name() == 'rect' && qualified.qualified_name_str() == 'svg:rect'
	assert (qualified.namespace_uri() or { '' }) == 'http://www.w3.org/2000/svg'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('elementWheelQualified')!)!) == voidptr(qualified)
	null_namespace := fixture.host.elements_for_binding()['__created_null_wheel'] or {
		panic('null namespace owner is missing')
	}
	assert null_namespace.namespace_uri() == none
	assert '__created_invalid_wheel' !in fixture.host.elements_for_binding()
	assert runtime.evaluate_host('globalThis.elementWheelCreatedChecks=[];elementWheelCreated.addEventListener("wheel",function(event){elementWheelCreatedChecks.push(this===elementWheelCreated&&event.target===elementWheelCreated&&event.isTrusted&&__elementWheelContext());event.preventDefault()},{once:true});0')! == '0'
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(created) },
		element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelCreatedChecks.length===1&&elementWheelCreatedChecks[0]')! == 'true'
	assert runtime.evaluate_host(r'globalThis.elementWheelLazyChecks=[];wheelDiv.addEventListener("wheel",function(event){elementWheelLazyChecks.push(event.target===elementWheelFacades[Object.keys(elementWheelSpecs).find(key=>elementWheelSpecs[key].tag==="span")]&&event.currentTarget===wheelDiv&&this===wheelDiv&&event.isTrusted)});0')! == '0'
	span := css.query_selector(unsafe { &dom.Node(fixture.document) }, 'span') or {
		panic('missing lazy span')
	}
	span_target := unsafe { &dom.EventTarget(span) }
	assert dom.event_target_dispatch_event(span_target, element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelLazyChecks.length===1&&elementWheelLazyChecks[0]&&elementWheelResolverCalls===5')! == 'true'
	lazy := runtime.javascript_event_target(span_target, none)!
	assert voidptr(runtime.native_event_target(lazy)!) == voidptr(span.as_node())
	element_wheel_assert_contexts(fixture)
}

fn test_native_element_wheel_host_uses_source_listener_options_and_actual_wheel_payload() {
	$if !darwin { return }
	fixture := element_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
globalThis.elementWheelChecks=[];globalThis.elementWheelOrder=[];
for(const player of [wheelDiv,wheelButton,wheelSVG,wheelImage]){
 const event=new WheelEvent("wheel",{cancelable:true});let calls=0;
 const first=function(actual){calls++;elementWheelChecks.push(this===player&&actual===event&&actual.currentTarget===player&&__elementWheelContext());return false};
 player.addEventListener("wheel",first);player.addEventListener("wheel",first,{once:true,passive:true});
 player.addEventListener("wheel",first,true);
 const passive=function(actual){elementWheelChecks.push(actual===event);actual.preventDefault()};
 player.addEventListener("wheel",passive,{once:true,passive:true});
 elementWheelChecks.push(player.dispatchEvent(event)===true&&!event.defaultPrevented&&calls===2);
 player.removeEventListener("wheel",first);player.removeEventListener("wheel",first,true);
 elementWheelChecks.push(player.dispatchEvent(new WheelEvent("wheel",{cancelable:true}))===true&&calls===2);
}
globalThis.elementWheelNativeCalls=0;globalThis.elementWheelNativeEvent=null;
const order=[];const optionCallback=function(event){elementWheelNativeCalls++;elementWheelNativeEvent=event;elementWheelChecks.push(this===wheelDiv&&event.target===wheelDiv&&event.currentTarget===wheelDiv&&event instanceof WheelEvent&&event.isTrusted&&event.deltaX===2.5&&event.deltaY===-3.5&&event.deltaMode===0&&event.clientX===3.75&&event.offsetY===2.5&&event.ctrlKey&&event.altKey&&__elementWheelContext());event.preventDefault()};
wheelDiv.addEventListener("wheel",optionCallback,{get signal(){order.push("signal");return undefined},get passive(){order.push("passive");return false},get once(){order.push("once");return true},get capture(){order.push("capture");return false}});
elementWheelChecks.push(order.join(",")==="capture,once,passive,signal");
0')! == '0'
	target := unsafe {
		&dom.EventTarget(fixture.document.get_element_by_id('wheelDiv') or {
			panic('missing native wheel div')
		})
	}
	event := element_wheel_native_event(fixture)
	assert !dom.event_target_dispatch_event(target, event)
	assert dom.event_target_dispatch_event(target, element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelNativeCalls===1&&elementWheelChecks.every(Boolean)&&elementWheelNativeEvent.currentTarget===null')! == 'true'
	signal := dom.AbortSignal.new()
	signal_wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(signal) }, none)!
	runtime.define_value_host_function('__elementWheelSignal', fn [signal_wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return signal_wrapper
	})!
	assert runtime.evaluate_host('globalThis.elementWheelAbortCalls=0;wheelDiv.addEventListener("wheel",()=>elementWheelAbortCalls++,{signal:__elementWheelSignal()});0')! == '0'
	mut mutable_signal := signal
	mutable_signal.signal_abort(dom.js_string('wheel abort'))
	assert dom.event_target_dispatch_event(target, element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelAbortCalls===0')! == 'true'
	root := fixture.document.document_element() or { panic('missing document element') }
	body := fixture.document.body() or { panic('missing wheel body') }
	for index, element in [root, unsafe { &dom.Element(body) }] {
		wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(element) }, none)!
		name := '__elementWheelPassive${index}'
		runtime.define_value_host_function(name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
			return wrapper
		})!
		assert runtime.evaluate_host('(function(){const target=${name}(),event=new WheelEvent("wheel",{cancelable:true});const listener=event=>event.preventDefault();target.addEventListener("wheel",listener,{once:true});const passive=target.dispatchEvent(event)&&!event.defaultPrevented;target.addEventListener("wheel",listener,{once:true,passive:false});const active=new WheelEvent("wheel",{cancelable:true});return passive&&target.dispatchEvent(active)===false&&active.defaultPrevented})()')! == 'true'
	}
	element_wheel_assert_contexts(fixture)
}

fn test_native_element_wheel_host_keeps_live_object_callbacks_exceptions_owner_gate_and_close() {
	$if !darwin { return }
	fixture := element_wheel_fixture()!
	mut runtime := fixture.runtime
	mut owner := fixture.owner
	assert runtime.evaluate_host(r'
globalThis.elementWheelThrown={original:true};globalThis.elementWheelObjectReads=0;globalThis.elementWheelObjectCalls=0;globalThis.elementWheelLaterCalls=0;globalThis.elementWheelObjectChecks=[];
globalThis.elementWheelObjectFunction=function(event){elementWheelObjectCalls++;elementWheelObjectChecks.push(this===elementWheelObject&&event.target===wheelDiv&&__elementWheelContext());return false};
globalThis.elementWheelObject={get handleEvent(){elementWheelObjectReads++;return elementWheelObjectFunction}};
wheelDiv.addEventListener("wheel",elementWheelObject);
wheelDiv.addEventListener("wheel",function(){throw elementWheelThrown},{once:true});
wheelDiv.addEventListener("wheel",function(event){elementWheelLaterCalls++;elementWheelObjectChecks.push(this===wheelDiv&&event.currentTarget===wheelDiv&&__elementWheelContext());return false});
0')! == '0'
	target := unsafe {
		&dom.EventTarget(fixture.document.get_element_by_id('wheelDiv') or {
			panic('missing gated wheel div')
		})
	}
	assert dom.event_target_dispatch_event(target, element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelObjectReads===1&&elementWheelObjectCalls===1&&elementWheelLaterCalls===1&&elementWheelObjectChecks.every(Boolean)')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 1
	reported := fixture.settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('elementWheelThrown')!
	assert runtime.evaluate_host('elementWheelObjectFunction=function(event){elementWheelObjectCalls++;elementWheelObjectChecks.push(this===elementWheelObject);event.preventDefault()};0')! == '0'
	owner.set_is_scripting_enabled(false)
	assert dom.event_target_dispatch_event(target, element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelObjectReads===1&&elementWheelLaterCalls===1')! == 'true'
	owner.set_is_scripting_enabled(true)
	assert !dom.event_target_dispatch_event(target, element_wheel_native_event(fixture))
	assert runtime.evaluate_host('elementWheelObjectReads===2&&elementWheelObjectCalls===2&&elementWheelLaterCalls===2&&elementWheelObjectChecks.every(Boolean)')! == 'true'
	element_wheel_assert_contexts(fixture)
	assert runtime.protected_values_.len > 0
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert fixture.host.closed && fixture.host.records.len == 0
	assert fixture.host.elements.len == 0 && fixture.host.resolver == unsafe { nil }
	assert dom.event_target_dispatch_event(target, element_wheel_native_event(fixture))
	element_wheel_assert_contexts(fixture)
}
