module main

import browserjs
import dom
import html
import libjs
import page
import time

fn native_text_tracks_fixture() !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document) {
	url := dom.URL{ value: 'https://text-tracks.example/dir/' }
	mut document := html.parse_navigation_document('<!doctype html><audio id="ntt-audio" preload="none"></audio><video id="ntt-video" preload="none"></video>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'audio' { 'nttAudio' } else { 'nttVideo' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	return runtime, host, document
}

fn native_text_tracks_drain(document &dom.Document) int {
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

fn test_native_text_tracks_metadata_same_object_and_event_target_owner_providers() {
	$if !darwin { return }
	mut runtime, host, mut document := native_text_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nttVideo')!)!
	track := media.add_text_track(.captions, 'English', 'en')
	list := media.text_tracks()
	list_wrapper := runtime.javascript_event_target(&list.EventTarget, none)!
	track_wrapper := runtime.javascript_event_target(&track.EventTarget, none)!
	assert list_wrapper == runtime.evaluate_host_value('nttVideo.textTracks')!
	assert track_wrapper == runtime.evaluate_host_value('nttVideo.textTracks[0]')!
	assert voidptr(runtime.native_event_target(track_wrapper)!) == voidptr(track)
	assert runtime.evaluate_host(r'(()=>{
 const l=nttVideo.textTracks,t=l[0],p=TextTrack.prototype,lp=TextTrackList.prototype,d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"textTracks");
 if(l!==nttVideo.textTracks||l===nttAudio.textTracks||!(l instanceof TextTrackList)||!(t instanceof TextTrack)||!(l instanceof EventTarget)||!(t instanceof EventTarget)||Object.getPrototypeOf(p)!==EventTarget.prototype||Object.getPrototypeOf(lp)!==EventTarget.prototype)return false;
 if(t.kind!=="captions"||t.label!=="English"||t.language!=="en"||t.id!==""||t.mode!=="hidden"||l.getTrackById("")!==t||Object.prototype.toString.call(t)!=="[object TextTrack]"||Object.prototype.toString.call(l)!=="[object TextTrackList]")return false;
 if(d.set!==undefined||!d.enumerable||!d.configurable||d.get.name!=="get textTracks"||d.get.length!==0||HTMLMediaElement.prototype.addTextTrack.length!==1||HTMLMediaElement.prototype.addTextTrack.name!=="addTextTrack")return false;
 for(const name of ["id","kind","label","language","mode","oncuechange"]){const x=Object.getOwnPropertyDescriptor(p,name);if(!x.enumerable||!x.configurable||x.get.name!=="get "+name||x.get.length!==0||((name==="mode"||name==="oncuechange")!==(typeof x.set==="function")))return false}
 for(const c of [TextTrack,TextTrackList]){const x=Object.getOwnPropertyDescriptor(c,"prototype");if(c.length!==0||Object.getPrototypeOf(c)!==EventTarget||x.writable||x.enumerable||x.configurable||!Function.prototype.toString.call(c).includes("[native code]"))return false;for(const call of [()=>c(),()=>new c()])try{call();return false}catch(e){if(!(e instanceof TypeError))return false}}
 return !Object.hasOwn(t,"kind")&&!Object.hasOwn(lp,"item");
})()')! == 'true'
	assert track.readiness_state() == .loaded && track.cues().length() == 0
}

fn test_native_add_text_track_converts_in_order_preserves_utf16_and_rejects_before_mutation() {
	$if !darwin { return }
	mut runtime, host, mut document := native_text_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const v=nttVideo,add=HTMLMediaElement.prototype.addTextTrack,l=v.textTracks;let log=[];
 const kind={toString(){log.push("kind");return "captions"}},label={toString(){log.push("label");return "a\0\ud800🎵"}},language={toString(){log.push("language");return "en\udfff"}};
 globalThis.nttFirst=add.call(v,kind,label,language,Symbol());
 if(log.join(",")!=="kind,label,language"||l.length!==1||l[0]!==nttFirst||nttFirst.label!=="a\0\ud800🎵"||nttFirst.language!=="en\udfff"||nttFirst.mode!=="hidden")return false;
 for(const k of ["subtitles","descriptions","chapters","metadata"])if(v.addTextTrack(k).kind!==k)return false;
 if(v.addTextTrack("metadata",undefined,undefined).label!==""||v.addTextTrack("captions",null,null).language!=="null")return false;
 const before=l.length,sentinel={};for(const operation of [()=>add.call(v),()=>add.call(v,undefined),()=>add.call(v,null),()=>add.call(v,"Captions"),()=>add.call(v,Symbol()),()=>add.call(v,"captions",Symbol()),()=>add.call(v,"captions","x",Symbol())])try{operation();return false}catch(e){if(!(e instanceof TypeError)||l.length!==before)return false}
 for(const position of [0,1,2]){let args=["captions","x","en"];args[position]={toString(){throw sentinel}};try{add.apply(v,args);return false}catch(e){if(e!==sentinel||l.length!==before)return false}}
 let traps=0;const value={toString(){traps++;throw "converted"}};for(const fake of [Object.create(v),Object.create(HTMLMediaElement.prototype),new Proxy(v,{get(){traps++;throw "trap"}}),l,nttFirst])try{add.call(fake,value);return false}catch(e){if(!(e instanceof TypeError))return false}
 const outer=v.addTextTrack("captions",{toString(){v.addTextTrack("metadata","inner");return "outer"}});
 return traps===0&&l[l.length-1]===outer&&l[l.length-2].label==="inner"&&outer.label==="outer"&&l.getTrackById("")===nttFirst;
})()')! == 'true'
	media := host.media_element_for_binding(runtime.evaluate_host_value('nttVideo')!)!
	first := media.text_tracks().item(0)?
	assert libjs.utf16_string_from_utf8_without_validation(first.label()).code_units() == [u16(97), 0, 0xd800, 0xd83c, 0xdfb5]
	assert libjs.utf16_string_from_utf8_without_validation(first.language()).code_units() == [u16(101), 110, 0xdfff]
}

fn test_native_text_tracks_live_indices_mode_conversion_and_native_metadata_changes() {
	$if !darwin { return }
	mut runtime, host, mut document := native_text_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nttAudio')!)!
	mut first := media.add_text_track(.metadata, 'Native', 'en')
	first.set_id(libjs.utf16_string_from_code_units([u16(0xd800), 0]).str())
	assert runtime.evaluate_host(r'(()=>{
 const l=nttAudio.textTracks,t=l[0],mode=Object.getOwnPropertyDescriptor(TextTrack.prototype,"mode").set,lookup=TextTrackList.prototype.getTrackById;
 if(l.getTrackById("\ud800\0")!==t||t.id!=="\ud800\0")return false;
 const d=Object.getOwnPropertyDescriptor(l,"0");if(d.value!==t||d.writable||!d.enumerable||!d.configurable||Reflect.set(l,"0",null)||Reflect.set(l,"1",null)||Reflect.defineProperty(l,"3",{value:null})||Reflect.deleteProperty(l,"0")||!Reflect.deleteProperty(l,"2"))return false;
 l["01"]=7;const symbol=Symbol();l[symbol]=8;if(Reflect.ownKeys(l).map(k=>typeof k==="symbol"?"symbol":k).join(",")!=="0,01,symbol"||l["4294967294"]!==undefined||l["-0"]!==undefined||Reflect.preventExtensions(l))return false;
 let calls=0;for(const m of ["disabled","hidden","showing"]){mode.call(t,{toString(){calls++;return m}});if(t.mode!==m)return false}if(calls!==3)return false;
 for(const m of [undefined,null,"Showing","",Symbol()])if(mode.call(t,m)!==undefined||t.mode!=="showing")return false;
 const sentinel={};if(mode.call(t,{toString(){throw sentinel}})!==undefined||t.mode!=="showing")return false;
 for(const fake of [Object.create(t),new Proxy(t,{}),l,nttAudio.audioTracks])try{mode.call(fake,{toString(){calls++;return "hidden"}});return false}catch(e){if(!(e instanceof TypeError)||calls!==3)return false}
 for(const fake of [Object.create(l),new Proxy(l,{}),t,nttAudio.videoTracks])try{lookup.call(fake,{toString(){calls++;return "x"}});return false}catch(e){if(!(e instanceof TypeError)||calls!==3)return false}
 return lookup.call(l,{toString(){t.mode="hidden";return "\ud800\0"}})===t&&t.mode==="hidden"&&l.getTrackById("missing")===null;
})()')! == 'true'
	assert first.mode() == .hidden
	first.set_kind(.chapters);first.set_label('Updated');first.set_language('fr');first.set_mode(.showing)
	assert runtime.evaluate_host('nttAudio.textTracks[0].kind==="chapters"&&nttAudio.textTracks[0].label==="Updated"&&nttAudio.textTracks[0].language==="fr"&&nttAudio.textTracks[0].mode==="showing"')! == 'true'
}

fn test_native_text_track_addition_tasks_handlers_and_cue_targets_use_real_owners() {
	$if !darwin { return }
	mut runtime, host, mut document := native_text_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nttList=nttVideo.textTracks;globalThis.nttEvents=[];globalThis.nttAdded=[];globalThis.nttOnadd=function(e){nttEvents.push(e.type);nttAdded.push(this===nttList&&e.target===nttList&&e.currentTarget===nttList&&!e.isTrusted);if(nttEvents.length===1)nttVideo.addTextTrack("metadata","reentrant")};nttList.onaddtrack=nttOnadd;nttList.onchange=e=>nttEvents.push("unexpected change");nttList.onremovetrack=e=>nttEvents.push("unexpected remove");globalThis.nttTrack=nttVideo.addTextTrack("captions","first");nttVideo.addTextTrack("metadata","second");nttTrack.mode="showing";nttEvents.length===0&&nttList.onaddtrack===nttOnadd&&nttList.length===2')! == 'true'
	assert native_text_tracks_drain(document) == 3
	assert runtime.evaluate_host('nttEvents.join(",")==="addtrack,addtrack,addtrack"&&nttAdded.every(Boolean)&&nttList[0]===nttTrack&&nttList[2].label==="reentrant"')! == 'true'
	assert runtime.evaluate_host(r'globalThis.nttCue=[];globalThis.nttCueHandler=function(e){nttCue.push(this===nttTrack&&e.target===nttTrack&&e.currentTarget===nttTrack&&e.isTrusted)};nttTrack.oncuechange=nttCueHandler;nttTrack.oncuechange===nttCueHandler')! == 'true'
	media := host.media_element_for_binding(runtime.evaluate_host_value('nttVideo')!)!
	track := media.text_tracks().item(0)?
	track.dispatch_event(dom.Event.create('cuechange', dom.EventInit{}))
	assert runtime.evaluate_host('nttCue.length===1&&nttCue[0]&&nttTrack instanceof EventTarget')! == 'true'
	assert runtime.evaluate_host('nttTrack.oncuechange=3;nttList.onaddtrack=null;nttTrack.oncuechange===null&&nttList.onaddtrack===null')! == 'true'
	assert native_text_tracks_drain(document) == 0
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_compact_text_tracks_created_media_factory_and_retained_interfaces() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="ntt-parsed" preload="none"></video>', dom.URL{ value: 'https://text-tracks.example/dir/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.nttParsed=document.getElementById("ntt-parsed");globalThis.nttCreated=document.createElement("audio");nttCreated.id="ntt-created";nttCreated.preload="none";document.body.appendChild(nttCreated);globalThis.nttFactory=new Audio();nttFactory.id="ntt-factory";nttFactory.preload="none";document.body.appendChild(nttFactory);
globalThis.nttOwners=[nttParsed,nttCreated,nttFactory];globalThis.nttSavedList=TextTrackList;globalThis.nttSavedTrack=TextTrack;globalThis.nttLists=nttOwners.map(o=>o.textTracks);globalThis.TextTrackList=null;globalThis.TextTrack=function Replacement(){};
globalThis.nttTracks=nttOwners.map((o,i)=>o.addTextTrack("captions","Owner "+i,"en"));
if(!nttTracks.every((t,i)=>t instanceof nttSavedTrack&&t instanceof EventTarget&&nttLists[i] instanceof nttSavedList&&nttLists[i]===nttOwners[i].textTracks&&nttLists[i][0]===t&&t.label==="Owner "+i))throw "text owner";
nttCreated.setAttribute("data-owner","preserved");nttCreated.remove();document.body.appendChild(nttCreated);if(nttCreated.textTracks!==nttLists[1])throw "moved list";
'], runtime, mut messages)
	assert messages == []
	for index, id in ['ntt-parsed', 'ntt-created', 'ntt-factory'] {
		element := document.get_element_by_id(id)?
		media := html.html_media_element_for_dom_element(element)?
		track := media.text_tracks().item(0)?
		assert track.label() == 'Owner ${index}' && track.kind() == .captions && track.mode() == .hidden
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nttTracks[${index}]')!)!) == voidptr(track)
	}
	assert document.get_element_by_id('ntt-created')?.get_attribute('data-owner')? == 'preserved'
	mut other, _, mut other_document := native_text_tracks_fixture()!
	defer { other.close();other_document.finalize() }
	runtime.close()
	assert other.evaluate_host('nttAudio.addTextTrack("metadata") instanceof TextTrack&&nttAudio.textTracks instanceof TextTrackList')! == 'true'
}
