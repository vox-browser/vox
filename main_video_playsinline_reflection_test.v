module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct PlaysInlineProbe {
mut:
	replays int
}

fn plays_inline_fixture(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document, &dom.Element) {
	address := dom.URL{ value: 'https://plays-inline.example/page.html' }
	mut document := html.parse_navigation_document('<!doctype html><video id="pi-video" preload="none"></video><audio id="pi-audio"></audio>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'video' { 'piVideo' } else { 'piAudio' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	element := document.get_element_by_id('pi-video') or { return error('missing playsInline video') }
	return runtime, host, document, element
}

fn plays_inline_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_video_playsinline_native_metadata_and_brand_precede_replay() {
	$if !darwin { return }
	probe := &PlaysInlineProbe{}
	mut runtime, _, mut document, element := plays_inline_fixture(fn [probe] (_ &browserjs.Runtime) ! {
		mut state := unsafe { &PlaysInlineProbe(probe) }
		state.replays++
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLVideoElement.prototype,d=Object.getOwnPropertyDescriptor(p,"playsInline");
 if(!d||!d.enumerable||!d.configurable||d.get.name!=="get playsInline"||d.get.length!==0||d.set.name!=="set playsInline"||d.set.length!==1||![d.get,d.set].every(f=>Function.prototype.toString.call(f).includes("[native code]"))||Object.hasOwn(piVideo,"playsInline")||"playsInline" in piAudio)return false;
 let traps=0;const value=new Proxy({},{get(){traps++;throw "value"}}),proxy=new Proxy(piVideo,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(piVideo,{});revoked.revoke();
 for(const receiver of [piAudio,{},Object.create(piVideo),Object.create(p),proxy,revoked.proxy,null,undefined,1]){
  for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,value),()=>d.set.call(receiver)]){
   try{call();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLVideoElement")return false}
  }
 }
 return traps===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('playsinline')
	assert runtime.evaluate_host('piVideo.playsInline===false')! == 'true'
	assert probe.replays == 1
}

fn test_video_playsinline_uses_boolean_truthiness_without_author_hooks_and_syncs_before_write() {
	$if !darwin { return }
	mut runtime, _, mut document, element := plays_inline_fixture(none)!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.piSync=[];__ladybirdMediaElementSetAttributeSync((receiver,name,value,qualified)=>piSync.push([receiver,name,value,qualified,receiver.playsInline]));(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,"playsInline"),revoked=Proxy.revocable({},{});revoked.revoke();
 const trap=new Proxy({},{get(){throw "author get"},getPrototypeOf(){throw "author prototype"}}),coercion={[Symbol.toPrimitive](){throw "convert"},valueOf(){throw "valueOf"},toString(){throw "toString"}};
 const cases=[[true,true],[false,false],[undefined,false],[null,false],[0,false],[-0,false],[NaN,false],["",false],[0n,false],[1n,true],[-1,true],[Infinity,true],["false",true],[Symbol(),true],[Object(false),true],[coercion,true],[trap,true],[revoked.proxy,true]];
 let before=false;globalThis.Boolean=()=>{throw "author Boolean"};
 for(const [value,expected] of cases){
  if(d.set.call(piVideo,value)!==undefined||d.get.call(piVideo)!==expected)return false;
  const last=piSync[piSync.length-1];if(last[0]!==piVideo||last[1]!=="playsinline"||last[2]!==expected||last[3]!==true||last[4]!==before)return false;
  before=expected;
 }
 d.set.call(piVideo);return piVideo.playsInline===false&&piSync[piSync.length-1][2]===false;
})()')! == 'true'
	assert !element.has_attribute('playsinline')
}

fn test_video_playsinline_qualified_removal_preserves_remaining_attrs_and_adopted_owner() {
	$if !darwin { return }
	mut runtime, _, mut document, mut element := plays_inline_fixture(none)!
	defer { runtime.close(); document.finalize() }
	element.set_attribute_value_ns('playsinline', 'foreign first', none, 'urn:pi-first')
	element.set_attribute_ns_for_bindings('urn:pi-prefixed', 'q:playsinline', 'prefixed')!
	element.set_attribute_value('playsinline', 'null last')
	foreign := element.get_attribute_node_ns('urn:pi-first', 'playsinline')?
	prefixed := element.get_attribute_node_ns('urn:pi-prefixed', 'playsinline')?
	plain := element.get_attribute_node_ns(none, 'playsinline')?
	assert runtime.evaluate_host('piVideo.playsInline=true;piVideo.playsInline===true')! == 'true'
	assert element.get_attribute_ns(none, 'playsinline')? == ''
	assert element.get_attribute_ns('urn:pi-first', 'playsinline')? == 'foreign first'
	assert voidptr(element.get_attribute_node_ns('urn:pi-first', 'playsinline')?) == voidptr(foreign)
	assert voidptr(element.get_attribute_node_ns(none, 'playsinline')?) == voidptr(plain)
	assert runtime.evaluate_host('piVideo.playsInline=false;piVideo.playsInline===true')! == 'true'
	assert element.get_attribute_node_ns('urn:pi-first', 'playsinline') == none
	assert voidptr(element.get_attribute_node_ns(none, 'playsinline')?) == voidptr(plain)
	assert runtime.evaluate_host('piVideo.playsInline=false;piVideo.playsInline=false;piVideo.playsInline===false')! == 'true'
	assert element.get_attribute_node_ns(none, 'playsinline') == none
	assert voidptr(element.get_attribute_node_ns('urn:pi-prefixed', 'playsinline')?) == voidptr(prefixed)
	address := dom.URL{ value: 'https://adopted-plays-inline.example/' }
	mut adopted := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	defer { adopted.finalize() }
	adopted.adopt_node(unsafe { &dom.Node(element) })
	element.set_attribute_value_ns('playsinline', 'false', none, 'urn:pi-first')
	assert runtime.evaluate_host('piVideo.playsInline===true')! == 'true'
	assert runtime.evaluate_host('piVideo.playsInline=false;piVideo.playsInline===false')! == 'true'
	assert element.document() == adopted && element.has_attribute_ns('urn:pi-prefixed', 'playsinline')
}

fn test_video_playsinline_replay_and_sync_exceptions_keep_identity_and_close_guards() {
	$if !darwin { return }
	probe := &PlaysInlineProbe{}
	mut runtime, host, mut document, element := plays_inline_fixture(fn [probe] (runtime &browserjs.Runtime) ! {
		mut state := unsafe { &PlaysInlineProbe(probe) }
		state.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		_ = owner.evaluate_host_value('throw piReason')!
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.piReason={};globalThis.piSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>piSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,"playsInline");
 for(const call of [()=>d.get.call(piVideo),()=>d.set.call(piVideo,true),()=>d.set.call(piVideo)]){try{call();return false}catch(error){if(error!==piReason)return false}}
 return piSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute('playsinline')
	value := runtime.evaluate_host_value('piVideo')!
	runtime.close()
	if _ := runtime.evaluate_host('piVideo.playsInline') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.media_element_for_binding(value) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	assert host.elements_for_binding().len == 0
	mut second, _, mut other, other_element := plays_inline_fixture(none)!
	defer { second.close(); other.finalize() }
	assert second.evaluate_host(r'globalThis.piReason={};__ladybirdMediaElementSetAttributeSync(()=>{throw piReason});(()=>{try{piVideo.playsInline=true;return false}catch(error){return error===piReason&&piVideo.playsInline===false}})()')! == 'true'
	assert !other_element.has_attribute('playsinline')
}

fn test_compact_video_playsinline_replays_parsed_and_created_owners_with_captured_reflection() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="pi-parsed" playsinline="false" preload="none"></video>',
		dom.URL{ value: 'https://plays-inline.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.piPlayers=[document.getElementById("pi-parsed")];const created=document.createElement("video");created.id="pi-created";created.preload="none";created.setAttribute("playsinline","anything");document.body.appendChild(created);piPlayers.push(created);for(const p of piPlayers){if(p.playsInline!==true||Object.hasOwn(p,"playsInline"))throw "playsInline owner";p.__state.playsInline=false;p.playsInline=false;if(p.hasAttribute("playsinline")||p.playsInline)throw "playsInline remove";p.setAttribute("playsinline","false");if(!p.playsInline)throw "playsInline replay";p.removeAttribute("playsinline");p.playsInline=true;if(!p.hasAttribute("playsinline")||p.getAttribute("playsinline")!=="")throw "playsInline sync";p.setAttribute=p.removeAttribute=()=>{throw "author mutation"};p.playsInline=false;p.playsInline=true;}0'], runtime, mut messages)
	assert messages == []
	for index, id in ['pi-parsed', 'pi-created'] {
		mut element := document.get_element_by_id(id) or { panic('missing playsInline owner') }
		assert element.get_attribute_ns(none, 'playsinline')? == ''
		mut video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		assert video.media.paused() && video.media.current_src() == '' && video.media.ready_state() == .have_nothing
		assert runtime.evaluate_host('piPlayers[${index}].playsInline=false;piPlayers[${index}].playsInline===false&&!piPlayers[${index}].hasAttribute("playsinline")')! == 'true'
		plays_inline_flush(document, runtime)!
		plays_inline_flush(document, runtime)!
		assert !element.has_attribute('playsinline')
		element.set_attribute_value('playsinline', 'live owner')
		assert runtime.evaluate_host('piPlayers[${index}].playsInline===true')! == 'true'
	}
}

fn test_compact_video_playsinline_qualified_removal_survives_flushes_and_poisoned_intrinsics() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="pi-namespaced" preload="none"></video>',
		dom.URL{ value: 'https://plays-inline.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut element := document.get_element_by_id('pi-namespaced') or { panic('missing namespace video') }
	element.set_attribute_value_ns('playsinline', 'foreign first', none, 'urn:pi-first')
	element.set_attribute_ns_for_bindings('urn:pi-prefixed', 'q:playsinline', 'prefixed')!
	element.set_attribute_value('playsinline', 'plain last')
	prefixed := element.get_attribute_node_ns('urn:pi-prefixed', 'playsinline')?
	plain := element.get_attribute_node_ns(none, 'playsinline')?
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.piOwner=document.getElementById("pi-namespaced");piOwner.playsInline=true;if(piOwner.getAttribute("playsinline")!=="foreign first")throw "playsInline foreign projection";piOwner.playsInline=false;if(!piOwner.playsInline||piOwner.getAttribute("playsinline")!=="")throw "playsInline qualified first removal";0'], runtime, mut messages)
	assert messages == []
	assert element.get_attribute_node_ns('urn:pi-first', 'playsinline') == none
	assert voidptr(element.get_attribute_node_ns(none, 'playsinline')?) == voidptr(plain)
	plays_inline_flush(document, runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const saved={define:Object.defineProperty,create:Object.create,keys:Object.keys,remove:Reflect.deleteProperty,apply:Reflect.apply,push:Array.prototype.push,splice:Array.prototype.splice,get:WeakMap.prototype.get,set:WeakMap.prototype.set,boolean:Boolean};let traps=0;
 const poison=()=>{traps++;throw "author intrinsic"};Object.defineProperty=Reflect.deleteProperty=Reflect.apply=Array.prototype.push=Array.prototype.splice=WeakMap.prototype.get=WeakMap.prototype.set=globalThis.Boolean=poison;
 try{piOwner.playsInline=false;piOwner.playsInline=false;return traps===0&&!piOwner.playsInline&&!piOwner.hasAttribute("playsinline")&&piOwner.getAttribute("q:playsinline")==="prefixed"}
 finally{Object.defineProperty=saved.define;Object.create=saved.create;Object.keys=saved.keys;Reflect.deleteProperty=saved.remove;Reflect.apply=saved.apply;Array.prototype.push=saved.push;Array.prototype.splice=saved.splice;WeakMap.prototype.get=saved.get;WeakMap.prototype.set=saved.set;globalThis.Boolean=saved.boolean}
})()')! == 'true'
	plays_inline_flush(document, runtime)!
	plays_inline_flush(document, runtime)!
	assert element.get_attribute_node_ns(none, 'playsinline') == none
	assert voidptr(element.get_attribute_node_ns('urn:pi-prefixed', 'playsinline')?) == voidptr(prefixed)
	assert runtime.evaluate_host('piOwner.playsInline=true;piOwner.getAttribute("playsinline")===""&&piOwner.playsInline')! == 'true'
	plays_inline_flush(document, runtime)!
	assert element.get_attribute_ns(none, 'playsinline')? == ''
	assert voidptr(element.get_attribute_node_ns('urn:pi-prefixed', 'playsinline')?) == voidptr(prefixed)
}
