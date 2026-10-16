module main

import browserjs
import dom
import fileapi
import html
import mediasourceextensions
import page
import time

@[heap]
struct NativeSrcObjectProbe {
mut:
	replays int
	fail bool
	reenter bool
}

fn native_src_object_fixture(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document) {
	url := dom.URL{ value: 'https://native-src-object.example/dir/' }
	owner := page.Page.create(1)!
	document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	mut runtime := browserjs.Runtime.create()
	mut streams := browserjs.ReadableStreamHost.create(document)!
	streams.install(mut runtime)!
	mut blobs := browserjs.BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := browserjs.FileHost.create(document)!
	files.install(mut runtime)!
	files.install_constructor()!
	mut sources := browserjs.MediaSourceHost.create(document)!
	sources.install(mut runtime)!
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.nsoVideo={};globalThis.nsoAudio={};__ladybirdMediaElementBind(nsoVideo,"__created_nso_video","video");__ladybirdMediaElementBind(nsoAudio,"__created_nso_audio","audio");0')!
	return runtime, host, document
}

fn native_src_object_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn test_native_src_object_metadata_receiver_and_union_brands_precede_replay_without_author_hooks() {
	$if !darwin { return }
	probe := &NativeSrcObjectProbe{}
	mut runtime, _, mut document := native_src_object_fixture(fn [probe] (_ &browserjs.Runtime) ! {
		mut state := unsafe { &NativeSrcObjectProbe(probe) };state.replays++
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"srcObject");
 if(!d||!d.enumerable||!d.configurable||d.get.name!=="get srcObject"||d.get.length!==0||d.set.name!=="set srcObject"||d.set.length!==1||Object.hasOwn(nsoVideo,"srcObject")||Object.hasOwn(nsoAudio,"srcObject")||![d.get,d.set].every(f=>Function.prototype.toString.call(f).includes("[native code]")))return false;
 let traps=0;const value={get [Symbol.toPrimitive](){traps++;throw "conversion"}},proxy=new Proxy(nsoVideo,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(nsoVideo,{});revoked.revoke();
 for(const receiver of [{},Object.create(nsoVideo),Object.create(HTMLMediaElement.prototype),proxy,revoked.proxy,null,undefined,1])for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,value),()=>d.set.call(receiver)]){
  try{call();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
 }
 const blob=new Blob(["data"]),source=new MediaSource(),blobProxy=new Proxy(blob,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),sourceProxy=Proxy.revocable(source,{});sourceProxy.revoke();
 for(const input of [value,{},Object.create(Blob.prototype),Object.create(MediaSource.prototype),blobProxy,sourceProxy.proxy,"blob:fake",1,1n,true,Symbol()]){
  try{d.set.call(nsoVideo,input);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="No union types matched")return false}
 }
 return traps===0;
})()')! == 'true'
	assert probe.replays == 0
	assert runtime.evaluate_host('nsoVideo.srcObject===null&&nsoAudio.srcObject===null')! == 'true'
	assert probe.replays == 2
}

fn test_native_src_object_blob_file_nullable_identity_and_live_typed_owner_reads() {
	$if !darwin { return }
	mut runtime, host, mut document := native_src_object_fixture(none)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nsoBlob=new Blob(["payload"],{type:"video/webm"});globalThis.nsoFile=new File(["file"],"sample.webm",{type:"video/webm",lastModified:0});(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"srcObject");
 Object.defineProperty(Blob,Symbol.hasInstance,{value(){throw "author instanceof"}});Object.defineProperty(MediaSource,Symbol.hasInstance,{value(){throw "author instanceof"}});
 Object.setPrototypeOf(nsoBlob,null);Object.setPrototypeOf(nsoFile,null);
 for(const player of [nsoVideo,nsoAudio]){
  player.preload="none";player.src="fallback.webm";
  for(const input of [nsoBlob,nsoFile]){
   if(d.set.call(player,input,{[Symbol.toPrimitive](){throw "extra argument"}})!==undefined||d.get.call(player)!==input||d.get.call(player)!==input||player.currentSrc!==""||player.networkState!==3||player.error.code!==4)return false;
  }
  for(const clear of [()=>d.set.call(player,null),()=>d.set.call(player,undefined),()=>d.set.call(player)]){
   if(clear()!==undefined||player.srcObject!==null||player.currentSrc!=="https://native-src-object.example/dir/fallback.webm")return false;
  }
 }
 nsoVideo.defaultPlaybackRate=-1;let failure;
 try{d.set.call(nsoVideo,nsoBlob)}catch(error){failure=error}
 if(!(failure instanceof DOMException)||failure.name!=="NotSupportedError"||failure.code!==9||failure.message!=="Playback rate is outside of the supported range."||nsoVideo.srcObject!==nsoBlob)return false;
 nsoVideo.defaultPlaybackRate=1;d.set.call(nsoVideo,null);return nsoVideo.srcObject===null;
})()')! == 'true'
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nsoVideo')!)!
	outside := fileapi.Blob.create('outside'.bytes(), 'audio/webm')
	media.set_src_object(html.MediaProviderObject.from_blob(outside))!
	actual := runtime.evaluate_host_value('nsoVideo.srcObject')!
	assert voidptr(runtime.native_blob(actual)!) == voidptr(outside)
	assert runtime.javascript_blob(outside)! == actual
	assert runtime.evaluate_host('nsoVideo.srcObject===nsoVideo.srcObject')! == 'true'
	media.set_src_object(none)!
	assert runtime.evaluate_host('nsoVideo.srcObject===null')! == 'true'
	native_src_object_drain(document)
}

fn test_native_src_object_media_source_attachment_replacement_equal_write_and_buffer_detachment() {
	$if !darwin { return }
	mut runtime, host, mut document := native_src_object_fixture(none)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nsoFirst=new MediaSource();globalThis.nsoSecond=new MediaSource();globalThis.nsoEvents=[];for(const [label,source] of [["first",nsoFirst],["second",nsoSecond]])for(const type of ["sourceopen","sourceclose"])source.addEventListener(type,function(event){nsoEvents.push(label+":"+type+":"+(this===source&&event.target===source&&event.currentTarget===source&&event.isTrusted))});nsoVideo.srcObject=nsoFirst;nsoVideo.srcObject===nsoFirst&&nsoFirst.readyState==="open"&&nsoVideo.currentSrc===""&&nsoEvents.length===0')! == 'true'
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nsoVideo')!)!
	first := runtime.native_media_source(runtime.evaluate_host_value('nsoFirst')!)!
	second := runtime.native_media_source(runtime.evaluate_host_value('nsoSecond')!)!
	assert voidptr(first.media_element_assigned_to()?) == voidptr(media)
	assert media.src_object()?.media_source_handle == voidptr(first)
	native_src_object_drain(document)
	assert runtime.evaluate_host('nsoEvents.join(",")==="first:sourceopen:true"')! == 'true'
	assert runtime.evaluate_host('globalThis.nsoOldList=nsoFirst.sourceBuffers;globalThis.nsoOldBuffer=nsoFirst.addSourceBuffer("video/webm; codecs=vp9");nsoOldList.length===1')! == 'true'
	assert runtime.evaluate_host('nsoVideo.srcObject=nsoSecond;nsoFirst.readyState==="closed"&&nsoSecond.readyState==="open"&&nsoVideo.srcObject===nsoSecond&&nsoOldList.length===0')! == 'true'
	assert first.media_element_assigned_to() == none
	assert voidptr(second.media_element_assigned_to()?) == voidptr(media)
	native_src_object_drain(document)
	assert runtime.evaluate_host('nsoEvents.join(",")==="first:sourceopen:true,first:sourceclose:true,second:sourceopen:true"')! == 'true'
	assert runtime.evaluate_host('nsoVideo.srcObject=nsoSecond;nsoVideo.srcObject===nsoSecond&&nsoSecond.readyState==="open"')! == 'true'
	native_src_object_drain(document)
	assert runtime.evaluate_host('nsoEvents.slice(-2).join(",")==="second:sourceclose:true,second:sourceopen:true"')! == 'true'
	assert runtime.evaluate_host('nsoVideo.srcObject=null;nsoVideo.srcObject===null&&nsoSecond.readyState==="closed"&&nsoVideo.networkState===0')! == 'true'
	assert media.src_object() == none && second.media_element_assigned_to() == none
	element := host.elements_for_binding()['__created_nso_video'] or { panic('Missing video owner') }
	assert !element.has_attribute('src')
	native_src_object_drain(document)
	assert runtime.evaluate_host('nsoEvents[nsoEvents.length-1]==="second:sourceclose:true"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	outside := mediasourceextensions.MediaSource.create_for_constructor(settings.global_object())
	media.set_src_object(outside.as_media_provider())!
	actual := runtime.evaluate_host_value('nsoVideo.srcObject')!
	assert voidptr(runtime.native_media_source(actual)!) == voidptr(outside)
	assert runtime.javascript_media_source(outside)! == actual
	media.set_src_object(none)!
	native_src_object_drain(document)
}

fn test_native_src_object_replay_exceptions_reentry_adoption_and_closed_binding_guards() {
	$if !darwin { return }
	probe := &NativeSrcObjectProbe{fail: true}
	mut runtime, host, mut document := native_src_object_fixture(fn [probe] (runtime &browserjs.Runtime) ! {
		mut state := unsafe { &NativeSrcObjectProbe(probe) };state.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		if state.fail { _ = owner.evaluate_host_value('throw nsoReplayReason')! }
		if state.reenter { state.reenter=false;_ = owner.evaluate_host('nsoVideo.srcObject=nsoReplacement;0')! }
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nsoReplayReason={};globalThis.nsoReplacement=new Blob(["reentrant"]);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"srcObject");
 for(const call of [()=>d.get.call(nsoVideo),()=>d.set.call(nsoVideo,nsoReplacement),()=>d.set.call(nsoVideo,null),()=>d.set.call(nsoVideo)]){try{call();return false}catch(error){if(error!==nsoReplayReason)return false}}
 return true;
})()')! == 'true'
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nsoVideo')!)!
	assert media.src_object() == none && probe.replays == 4
	mut observation := unsafe { &NativeSrcObjectProbe(probe) }
	observation.fail=false;observation.reenter=true
	assert runtime.evaluate_host('nsoVideo.srcObject===nsoReplacement')! == 'true'
	assert probe.replays == 6
	provider := media.src_object()?
	assert voidptr(provider.blob?) == voidptr(runtime.native_blob(runtime.evaluate_host_value('nsoReplacement')!)!)
	url := dom.URL{ value: 'https://adopted-src-object.example/' }
	mut adopted := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	defer { adopted.finalize() }
	element := host.elements_for_binding()['__created_nso_video'] or { panic('Missing video owner') }
	adopted.adopt_node(element.as_node())
	assert runtime.evaluate_host('nsoVideo.srcObject===nsoReplacement&&nsoVideo instanceof HTMLVideoElement')! == 'true'
	media.set_src_object(none)!
	native_src_object_drain(document)
	actual := runtime.evaluate_host_value('nsoVideo')!
	runtime.close()
	if _ := host.media_element_for_binding(actual) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := runtime.evaluate_host('nsoVideo.srcObject') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
}

fn test_compact_src_object_parsed_and_created_owners_preserve_native_provider_through_dirty_replay() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="nso-parsed" preload="none" src="fallback.webm"></video><div id="nso-result"></div>', dom.URL{ value: 'https://compact-src-object.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.nsoParsed=document.getElementById("nso-parsed");globalThis.nsoCreated=document.createElement("audio");nsoCreated.id="nso-created";document.body.appendChild(nsoCreated);
globalThis.nsoSources=[new MediaSource(),new MediaSource()];globalThis.nsoPlayers=[nsoParsed,nsoCreated];globalThis.nsoOwnerEvents=[];
for(let i=0;i<2;i++){const source=nsoSources[i],player=nsoPlayers[i];source.onsourceopen=function(event){nsoOwnerEvents.push(i+":"+(this===source&&event.target===source&&event.currentTarget===source&&event.isTrusted))};player.srcObject=source;player.setAttribute("data-provider","retained");if(player.srcObject!==source||Object.hasOwn(player,"srcObject")||player.hasAttribute("srcObject"))throw "native provider identity";}
document.getElementById("nso-result").textContent="providers assigned";
'], runtime, mut messages)
	assert messages == []
	for index, id in ['nso-parsed','nso-created'] {
		element := document.get_element_by_id(id)?
		media := html.html_media_element_for_dom_element(element)?
		source := runtime.native_media_source(runtime.evaluate_host_value('nsoSources[${index}]')!)!
		assert media.src_object()?.media_source_handle == voidptr(source)
		assert voidptr(source.media_element_assigned_to()?) == voidptr(media)
		assert element.get_attribute('data-provider')? == 'retained'
		assert !element.has_attribute('srcObject')
	}
	native_src_object_drain(document)
	assert runtime.evaluate_host('nsoOwnerEvents.join(",")==="0:true,1:true"&&nsoPlayers.every((p,i)=>p.srcObject===nsoSources[i])')! == 'true'
	assert document.get_element_by_id('nso-parsed')?.get_attribute('src')? == 'fallback.webm'
	assert document.get_element_by_id('nso-result')?.as_node().text_content()? == 'providers assigned'
	assert runtime.evaluate_host('nsoParsed.setAttribute("data-after","yes");nsoParsed.srcObject=null;nsoParsed.srcObject===null&&nsoSources[0].readyState==="closed"&&nsoParsed.currentSrc==="https://compact-src-object.example/fallback.webm"&&nsoCreated.srcObject===nsoSources[1]&&nsoSources[1].readyState==="open"')! == 'true'
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document,snapshot,runtime,mut messages)
	assert messages == [] && document.get_element_by_id('nso-parsed')?.get_attribute('data-after')? == 'yes'
	assert runtime.evaluate_host('nsoCreated.srcObject=undefined;nsoCreated.srcObject===null&&nsoSources[1].readyState==="closed"')! == 'true'
	native_src_object_drain(document)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
