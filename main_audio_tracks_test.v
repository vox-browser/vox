module main

import browserjs
import dom
import html
import page
import time

fn native_audio_tracks_fixture() !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document) {
	url := dom.URL{ value: 'https://audio-tracks.example/dir/' }
	mut document := html.parse_navigation_document('<!doctype html><audio id="nat-audio" preload="none"></audio><video id="nat-video" preload="none"></video>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'audio' { 'natAudio' } else { 'natVideo' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	return runtime, host, document
}

fn native_audio_tracks_drain(media &html.HTMLMediaElement) int {
	document := media.document() or { panic('Missing media document') }
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
	return count
}

fn test_native_audio_tracks_interfaces_same_object_and_real_event_target_provider() {
	$if !darwin { return }
	mut runtime, host, mut document := native_audio_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	media := host.media_element_for_binding(runtime.evaluate_host_value('natAudio')!)!
	list := media.audio_tracks()
	// A native event-target consumer can request this owner before its IDL getter.
	wrapped := runtime.javascript_event_target(list.event_target(), none)!
	assert wrapped == runtime.evaluate_host_value('natAudio.audioTracks')!
	assert voidptr(runtime.native_event_target(wrapped)!) == voidptr(list.event_target())
	assert runtime.evaluate_host(r'(()=>{
 const l=natAudio.audioTracks,p=AudioTrackList.prototype,t=AudioTrack.prototype,d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"audioTracks");
 if(l!==natAudio.audioTracks||l===natVideo.audioTracks||l.length!==0||l[0]!==undefined||l.getTrackById("1")!==null||!(l instanceof AudioTrackList)||!(l instanceof EventTarget))return false;
 if(Object.getPrototypeOf(p)!==EventTarget.prototype||Object.getPrototypeOf(AudioTrackList)!==EventTarget||Object.getPrototypeOf(t)!==Object.prototype||Object.getPrototypeOf(AudioTrack)!==Function.prototype)return false;
 if(Object.prototype.toString.call(l)!=="[object AudioTrackList]"||Object.getOwnPropertyDescriptor(p,"length").set!==undefined||Object.hasOwn(p,"item")||Object.hasOwn(p,Symbol.iterator))return false;
 if(d.set!==undefined||!d.enumerable||!d.configurable||d.get.name!=="get audioTracks"||d.get.length!==0||!Function.prototype.toString.call(d.get).includes("[native code]"))return false;
 for(const [name,c,prototype] of [["AudioTrack",AudioTrack,t],["AudioTrackList",AudioTrackList,p]]){
  const cd=Object.getOwnPropertyDescriptor(c,"prototype"),global=Object.getOwnPropertyDescriptor(globalThis,name),tag=Object.getOwnPropertyDescriptor(prototype,Symbol.toStringTag);
  if(c.name!==name||c.length!==0||cd.value!==prototype||cd.writable||cd.enumerable||cd.configurable||!global.writable||!global.configurable||global.enumerable||tag.value!==name||tag.writable||tag.enumerable||!tag.configurable)return false;
  for(const f of [()=>c(),()=>new c(),()=>Reflect.construct(c,[])])try{f();return false}catch(e){if(!(e instanceof TypeError))return false}
 }
 return Object.keys(l).length===0&&Object.isExtensible(l)&&Reflect.preventExtensions(l)===false;
})()')! == 'true'
}

fn test_native_audio_tracks_live_index_descriptors_metadata_and_retained_tracks() {
	$if !darwin { return }
	mut runtime, host, mut document := native_audio_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('natAudio')!)!
	mut first := media.on_audio_track_added(html.MediaTrackMetadata{ identifier: 17, name: 'Main\x00🎵', parsed_bcp47_language: 'en-US' })
	second := media.on_audio_track_added(html.MediaTrackMetadata{ identifier: 17, name: 'Alternate', parsed_bcp47_language: 'und' })
	assert runtime.evaluate_host(r'(()=>{
 const l=natAudio.audioTracks;globalThis.natList=l;globalThis.natFirst=l[0];globalThis.natSecond=l[1];
 if(l.length!==2||l.getTrackById(17)!==natFirst||natFirst===natSecond||natFirst.id!=="17"||natFirst.kind!=="main"||natFirst.label!=="Main\0🎵"||natFirst.language!=="en-US"||!natFirst.enabled||natSecond.enabled||natSecond.kind!=="translation"||natSecond.language!=="")return false;
 if(!(natFirst instanceof AudioTrack)||natFirst instanceof EventTarget||Object.prototype.toString.call(natFirst)!=="[object AudioTrack]")return false;
 const d=Object.getOwnPropertyDescriptor(l,"0");if(d.value!==natFirst||d.writable||!d.enumerable||!d.configurable||!Object.hasOwn(l,"0")||!(1 in l)||2 in l)return false;
 if(Reflect.set(l,"0",null)||Reflect.set(l,"2",null)||Reflect.defineProperty(l,"0",{value:null})||Reflect.defineProperty(l,"3",{value:null})||Reflect.deleteProperty(l,"0")||!Reflect.deleteProperty(l,"2"))return false;
 const symbol=Symbol("expando");l.tail=3;l["01"]=4;l["-0"]=5;l["4294967295"]=6;l[symbol]=7;
 if(Reflect.ownKeys(l).map(x=>typeof x==="symbol"?"symbol":x).join(",")!=="0,1,tail,01,-0,4294967295,symbol")return false;
 if(l["00"]!==undefined||l["1.0"]!==undefined||l["-1"]!==undefined||l["4294967294"]!==undefined)return false;
 for(const name of ["id","kind","label","language","enabled"]){const p=Object.getOwnPropertyDescriptor(AudioTrack.prototype,name);if(!p.enumerable||!p.configurable||p.get.name!=="get "+name||p.get.length!==0||((name==="enabled")!==(typeof p.set==="function")))return false}
 return Object.keys(natFirst).length===0;
})()')! == 'true'
	first.base.set_kind('commentary')
	assert runtime.evaluate_host('natFirst.kind==="commentary"')! == 'true'
	mut list := media.audio_tracks()
	list.remove_all_tracks()
	assert runtime.evaluate_host('natAudio.audioTracks===natList&&natList.length===0&&!Object.hasOwn(natList,"0")&&natList[0]===undefined&&natList.getTrackById("17")===null&&natFirst.id==="17"&&!natFirst.enabled&&!natSecond.enabled&&natList.tail===3')! == 'true'
	list.add_track(second)
	assert runtime.evaluate_host('natList.length===1&&natList[0]===natSecond&&natList.getTrackById("17")===natSecond&&Object.keys(natList)[0]==="0"')! == 'true'
}

fn test_native_audio_tracks_branding_conversions_reentry_and_boolean_enabled() {
	$if !darwin { return }
	mut runtime, host, mut document := native_audio_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('natAudio')!)!
	mut track := media.on_audio_track_added(html.MediaTrackMetadata{ identifier: 9 })
	assert runtime.evaluate_host(r'(()=>{
 const l=natAudio.audioTracks,t=l[0],get=Object.getOwnPropertyDescriptor(AudioTrack.prototype,"id").get,set=Object.getOwnPropertyDescriptor(AudioTrack.prototype,"enabled").set,method=AudioTrackList.prototype.getTrackById;
 let calls=0;const value={[Symbol.toPrimitive](){calls++;throw "converted"}},proxy=new Proxy(t,{get(){calls++;throw "trap"},getPrototypeOf(){calls++;throw "prototype"}}),revoked=Proxy.revocable(l,{});revoked.revoke();
 for(const fake of [Object.create(AudioTrack.prototype),Object.create(t),proxy,AudioTrack.prototype])for(const f of [()=>get.call(fake),()=>set.call(fake,value)])try{f();return false}catch(e){if(!(e instanceof TypeError))return false}
 for(const fake of [Object.create(AudioTrackList.prototype),Object.create(l),new Proxy(l,{}),revoked.proxy,t])try{method.call(fake,value);return false}catch(e){if(!(e instanceof TypeError))return false}
 if(calls!==0)return false;
 try{method.call(l);return false}catch(e){if(!(e instanceof TypeError))return false}
 try{method.call(l,Symbol());return false}catch(e){if(!(e instanceof TypeError))return false}
 const sentinel={};try{method.call(l,{toString(){throw sentinel}});return false}catch(e){if(e!==sentinel)return false}
 let conversions=0;const id={toString(){conversions++;t.enabled=false;return "9"}};
 if(method.call(l,id)!==t||conversions!==1||t.enabled)return false;
 t.enabled=value;if(!t.enabled||calls!==0)return false;
 set.call(t);if(t.enabled)return false;
 t.enabled=Symbol();if(!t.enabled)return false;
 t.enabled=0n;if(t.enabled)return false;
 return method.call(l,undefined)===null&&method.call(l,null)===null&&method.call(l,"9\0")===null;
})()')! == 'true'
	assert !track.enabled
	track.set_enabled(true)
	assert runtime.evaluate_host('natAudio.audioTracks[0].enabled')! == 'true'
}

@[heap]
struct NativeAudioTracksBackend {
mut:
	changes []string
}

fn test_native_audio_tracks_route_enabled_and_event_handlers_to_actual_media_owner() {
	$if !darwin { return }
	mut runtime, host, mut document := native_audio_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('natAudio')!)!
	state := &NativeAudioTracksBackend{}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_audio_track: fn [state] (track &html.AudioTrack, enabled bool) {
			mut observation := unsafe { &NativeAudioTracksBackend(state) }
			assert track.enabled == enabled
			observation.changes << '${track.base.id}:${enabled}'
		}
	})
	assert runtime.evaluate_host(r'globalThis.natList=natAudio.audioTracks;globalThis.natEvents=[];globalThis.natHandler=function(e){natEvents.push([e.type,this===natList,e.target===natList,e.currentTarget===natList,e.isTrusted,natList.length])};natList.onaddtrack=natHandler;natList.onchange=natHandler;natList.onremovetrack=natHandler;natList.onaddtrack===natHandler&&natList.onchange===natHandler&&natList.onremovetrack===natHandler')! == 'true'
	_ = media.on_audio_track_added(html.MediaTrackMetadata{ identifier: 1 })
	_ = media.on_audio_track_added(html.MediaTrackMetadata{ identifier: 2 })
	assert state.changes == ['1:true']
	assert runtime.evaluate_host('JSON.stringify(natEvents)')! == '[["addtrack",true,true,true,false,1],["addtrack",true,true,true,false,2]]'
	native_audio_tracks_drain(media)
	assert runtime.evaluate_host('JSON.stringify(natEvents[2])')! == '["change",true,true,true,true,2]'
	assert runtime.evaluate_host('natEvents.length=0;natList[1].enabled=true;natList[1].enabled=true;natList[0].enabled=false;natEvents.length')! == '0'
	assert state.changes == ['1:true', '2:true', '1:false']
	native_audio_tracks_drain(media)
	assert runtime.evaluate_host('JSON.stringify(natEvents)')! == '[["change",true,true,true,true,2],["change",true,true,true,true,2]]'
	assert runtime.evaluate_host('globalThis.natSaved=natList[1];natEvents.length=0;natList.onaddtrack=3;natList.onaddtrack===null')! == 'true'
	mut list := media.audio_tracks()
	list.remove_all_tracks()
	native_audio_tracks_drain(media)
	assert state.changes == ['1:true', '2:true', '1:false', '2:false']
	assert runtime.evaluate_host('JSON.stringify(natEvents)')! == '[["change",true,true,true,true,0]]'
	assert runtime.evaluate_host('natEvents.length=0;natSaved.enabled=true;natSaved.enabled&&!natList.length')! == 'true'
	assert state.changes.last() == '2:true'
	assert native_audio_tracks_drain(media) == 0
	assert runtime.evaluate_host('natList.dispatchEvent(new Event("removetrack"));natEvents.length===1&&natEvents[0][0]==="removetrack"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_compact_audio_tracks_parsed_created_video_live_owner_and_retained_prototypes() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><audio id="nat-parsed" preload="none"></audio><video id="nat-video" preload="none"></video>', dom.URL{ value: 'https://audio-tracks.example/dir/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.natParsed=document.getElementById("nat-parsed");globalThis.natCreated=document.createElement("audio");natCreated.id="nat-created";natCreated.preload="none";document.body.appendChild(natCreated);
globalThis.natOwners=[natParsed,natCreated,document.getElementById("nat-video")];globalThis.natLists=natOwners.map(o=>o.audioTracks);globalThis.natSavedList=AudioTrackList;globalThis.natSavedTrack=AudioTrack;
if(!natLists.every((l,i)=>l===natOwners[i].audioTracks&&l instanceof AudioTrackList&&l.length===0)||new Set(natLists).size!==3)throw "list ownership";
globalThis.AudioTrackList=null;globalThis.AudioTrack=function Replacement(){};
natCreated.setAttribute("data-owner","retained");natCreated.remove();document.body.appendChild(natCreated);
if(natCreated.audioTracks!==natLists[1])throw "moved list";
'], runtime, mut messages)
	assert messages == []
	for index, id in ['nat-parsed', 'nat-created', 'nat-video'] {
		element := document.get_element_by_id(id)?
		mut media := html.html_media_element_for_dom_element(element)?
		_ = media.on_audio_track_added(html.MediaTrackMetadata{ identifier: index + 10, name: 'Native ${index}' })
		assert runtime.evaluate_host('natLists[${index}]===natOwners[${index}].audioTracks&&natLists[${index}].length===1&&natLists[${index}][0].id==="${index + 10}"&&natLists[${index}][0].label==="Native ${index}"&&natLists[${index}] instanceof natSavedList&&natLists[${index}][0] instanceof natSavedTrack')! == 'true'
	}
	assert document.get_element_by_id('nat-created')?.get_attribute('data-owner')? == 'retained'
	mut other, _, mut other_document := native_audio_tracks_fixture()!
	defer { other.close();other_document.finalize() }
	assert other.evaluate_host('AudioTrackList.name==="AudioTrackList"&&AudioTrack.name==="AudioTrack"&&natAudio.audioTracks.length===0')! == 'true'
	runtime.close()
	assert other.evaluate_host('natAudio.audioTracks instanceof AudioTrackList&&natAudio.audioTracks.length===0')! == 'true'
}
