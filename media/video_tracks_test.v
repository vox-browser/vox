module main

import browserjs
import dom
import html
import page
import painting
import time

fn native_video_tracks_fixture() !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document) {
	url := dom.URL{ value: 'https://video-tracks.example/dir/' }
	mut document := html.parse_navigation_document('<!doctype html><audio id="nvt-audio" preload="none"></audio><video id="nvt-video" preload="none"></video>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'audio' { 'nvtAudio' } else { 'nvtVideo' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	return runtime, host, document
}

fn native_video_tracks_drain(media &html.HTMLMediaElement) int {
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

fn test_native_video_tracks_interfaces_same_object_and_real_event_target_provider() {
	$if !darwin { return }
	mut runtime, host, mut document := native_video_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	media := host.media_element_for_binding(runtime.evaluate_host_value('nvtAudio')!)!
	list := media.video_tracks()
	// A native event-target consumer can request this owner before its IDL getter.
	wrapped := runtime.javascript_event_target(&list.EventTarget, none)!
	assert wrapped == runtime.evaluate_host_value('nvtAudio.videoTracks')!
	assert voidptr(runtime.native_event_target(wrapped)!) == voidptr(&list.EventTarget)
	assert runtime.evaluate_host(r'(()=>{
 const l=nvtAudio.videoTracks,p=VideoTrackList.prototype,t=VideoTrack.prototype,d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"videoTracks");
 if(l!==nvtAudio.videoTracks||l===nvtVideo.videoTracks||l.length!==0||l.selectedIndex!==-1||l[0]!==undefined||l.getTrackById("1")!==null||!(l instanceof VideoTrackList)||!(l instanceof EventTarget))return false;
 if(Object.getPrototypeOf(p)!==EventTarget.prototype||Object.getPrototypeOf(VideoTrackList)!==EventTarget||Object.getPrototypeOf(t)!==Object.prototype||Object.getPrototypeOf(VideoTrack)!==Function.prototype)return false;
 if(Object.prototype.toString.call(l)!=="[object VideoTrackList]"||Object.getOwnPropertyDescriptor(p,"length").set!==undefined||Object.getOwnPropertyDescriptor(p,"selectedIndex").set!==undefined||Object.getOwnPropertyDescriptor(p,"selectedIndex").get.name!=="get selectedIndex"||Object.hasOwn(p,"item")||Object.hasOwn(p,Symbol.iterator))return false;
 if(d.set!==undefined||!d.enumerable||!d.configurable||d.get.name!=="get videoTracks"||d.get.length!==0||!Function.prototype.toString.call(d.get).includes("[native code]"))return false;
 for(const [name,c,prototype] of [["VideoTrack",VideoTrack,t],["VideoTrackList",VideoTrackList,p]]){
  const cd=Object.getOwnPropertyDescriptor(c,"prototype"),global=Object.getOwnPropertyDescriptor(globalThis,name),tag=Object.getOwnPropertyDescriptor(prototype,Symbol.toStringTag);
  if(c.name!==name||c.length!==0||cd.value!==prototype||cd.writable||cd.enumerable||cd.configurable||!global.writable||!global.configurable||global.enumerable||tag.value!==name||tag.writable||tag.enumerable||!tag.configurable)return false;
  for(const f of [()=>c(),()=>new c(),()=>Reflect.construct(c,[])])try{f();return false}catch(e){if(!(e instanceof TypeError))return false}
 }
 return Object.keys(l).length===0&&Object.isExtensible(l)&&Reflect.preventExtensions(l)===false;
})()')! == 'true'
}

fn test_native_selected_video_track_zero_axes_replace_previous_dimensions_and_keep_event_order() {
	$if !darwin { return }
	mut runtime, host, mut document := native_video_tracks_fixture()!
	defer { runtime.close(); document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nvtVideo')!)!
	media.set_ready_state(.have_metadata)
	assert runtime.evaluate_host(r'globalThis.nvtZeroEvents=[];globalThis.nvtZeroList=nvtVideo.videoTracks;const zeroHandler=function(e){const target=e.type==="change"?nvtZeroList:nvtVideo;if(this!==target||e.target!==target||e.currentTarget!==target||!e.isTrusted)throw "zero-size owner";nvtZeroEvents.push(e.type+":"+nvtVideo.videoWidth+"x"+nvtVideo.videoHeight);};nvtZeroList.onchange=zeroHandler;nvtVideo.onresize=zeroHandler;0')! == '0'
	media.on_video_track_added(html.MediaTrackMetadata{identifier: 1, pixel_width: 320, pixel_height: 180})
	dimensions := [html.VideoDimensions{0,180}, html.VideoDimensions{640,0}, html.VideoDimensions{0,0}]
	for i, size in dimensions { media.on_video_track_added(html.MediaTrackMetadata{identifier: i64(i+2), pixel_width: size.width, pixel_height: size.height}) }
	assert native_video_tracks_drain(media) == 2
	assert runtime.evaluate_host('nvtZeroEvents.join(",")==="change:320x180,resize:320x180"')! == 'true'
	for i, size in dimensions {
		assert runtime.evaluate_host('nvtZeroEvents.length=0;nvtZeroList[${i+1}].selected=true;nvtVideo.videoWidth===${size.width}&&nvtVideo.videoHeight===${size.height}&&nvtZeroEvents.length===0')! == 'true'
		assert native_video_tracks_drain(media) == 2
		assert runtime.evaluate_host('nvtZeroEvents.join(",")==="change:${size.width}x${size.height},resize:${size.width}x${size.height}"')! == 'true'
	}
	assert runtime.evaluate_host('nvtZeroEvents.length=0;nvtZeroList[3].selected=false;nvtZeroList.selectedIndex===-1&&nvtVideo.videoWidth===0&&nvtVideo.videoHeight===0')! == 'true'
	assert native_video_tracks_drain(media) == 1
	assert runtime.evaluate_host('nvtZeroEvents.join(",")==="change:0x0"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0 && settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_video_dimensions_and_resize_follow_the_first_frame_without_a_prior_model_read() {
	$if !darwin { return }
	mut runtime, host, mut document := native_video_tracks_fixture()!
	defer { runtime.close(); document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nvtVideo')!)!
	owner := unsafe { &dom.HTMLVideoElement(document.get_element_by_id('nvt-video')?) }
	media.set_ready_state(.have_metadata)
	assert owner.video_element_model_ == unsafe { nil }
	assert runtime.evaluate_host(r'globalThis.nvtFrameEvents=[];nvtVideo.onresize=function(e){if(this!==nvtVideo||e.target!==this||e.currentTarget!==this||!e.isTrusted)throw "frame resize owner";nvtFrameEvents.push(e.type+":"+this.videoWidth+"x"+this.videoHeight);};0')! == '0'
	bitmap := &dom.Bitmap_{width: 2, height: 1, pitch: 8, data: [u8(255),0,0,255,0,255,0,255]}
	frame := painting.MediaVideoFrame.from_bitmap_with_color_space(bitmap, .display_p3)
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_video_frame: fn [frame] () ?&painting.MediaVideoFrame { return frame }
	})
	media.update_video_frame_and_timeline()
	assert media.ensure_video_frame_source().current_frame()? == frame
	assert runtime.evaluate_host('nvtVideo.videoWidth===2&&nvtVideo.videoHeight===1&&nvtVideo.videoTracks.length===0&&nvtFrameEvents.length===0')! == 'true'
	assert native_video_tracks_drain(media) == 1
	assert runtime.evaluate_host('nvtFrameEvents.join(",")==="resize:2x1"')! == 'true'
	media.update_video_frame_and_timeline()
	assert native_video_tracks_drain(media) == 0 && media.event_count('resize') == 1
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_video_tracks_live_index_descriptors_metadata_and_retained_tracks() {
	$if !darwin { return }
	mut runtime, host, mut document := native_video_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nvtAudio')!)!
	mut first := media.on_video_track_added(html.MediaTrackMetadata{ identifier: 17, name: 'Main\x00🎵', parsed_bcp47_language: 'en-US' })
	second := media.on_video_track_added(html.MediaTrackMetadata{ identifier: 17, name: 'Alternate', parsed_bcp47_language: 'und' })
	assert runtime.evaluate_host(r'(()=>{
 const l=nvtAudio.videoTracks;globalThis.nvtList=l;globalThis.nvtFirst=l[0];globalThis.nvtSecond=l[1];
 if(l.length!==2||l.selectedIndex!==0||l.getTrackById(17)!==nvtFirst||nvtFirst===nvtSecond||nvtFirst.id!=="17"||nvtFirst.kind!=="main"||nvtFirst.label!=="Main\0🎵"||nvtFirst.language!=="en-US"||!nvtFirst.selected||nvtSecond.selected||nvtSecond.kind!=="translation"||nvtSecond.language!=="")return false;
 if(!(nvtFirst instanceof VideoTrack)||nvtFirst instanceof EventTarget||Object.prototype.toString.call(nvtFirst)!=="[object VideoTrack]")return false;
 const d=Object.getOwnPropertyDescriptor(l,"0");if(d.value!==nvtFirst||d.writable||!d.enumerable||!d.configurable||!Object.hasOwn(l,"0")||!(1 in l)||2 in l)return false;
 if(Reflect.set(l,"0",null)||Reflect.set(l,"2",null)||Reflect.defineProperty(l,"0",{value:null})||Reflect.defineProperty(l,"3",{value:null})||Reflect.deleteProperty(l,"0")||!Reflect.deleteProperty(l,"2"))return false;
 const symbol=Symbol("expando");l.tail=3;l["01"]=4;l["-0"]=5;l["4294967295"]=6;l[symbol]=7;
 if(Reflect.ownKeys(l).map(x=>typeof x==="symbol"?"symbol":x).join(",")!=="0,1,tail,01,-0,4294967295,symbol")return false;
 if(l["00"]!==undefined||l["1.0"]!==undefined||l["-1"]!==undefined||l["4294967294"]!==undefined)return false;
 for(const name of ["id","kind","label","language","selected"]){const p=Object.getOwnPropertyDescriptor(VideoTrack.prototype,name);if(!p.enumerable||!p.configurable||p.get.name!=="get "+name||p.get.length!==0||((name==="selected")!==(typeof p.set==="function")))return false}
 return Object.keys(nvtFirst).length===0;
})()')! == 'true'
	first.base.set_kind('commentary')
	assert runtime.evaluate_host('nvtFirst.kind==="commentary"')! == 'true'
	mut list := media.video_tracks()
	list.remove_all_tracks()
	assert runtime.evaluate_host('nvtAudio.videoTracks===nvtList&&nvtList.length===0&&nvtList.selectedIndex===-1&&!Object.hasOwn(nvtList,"0")&&nvtList[0]===undefined&&nvtList.getTrackById("17")===null&&nvtFirst.id==="17"&&!nvtFirst.selected&&!nvtSecond.selected&&nvtList.tail===3')! == 'true'
	list.add_track(second)
	assert runtime.evaluate_host('nvtList.length===1&&nvtList.selectedIndex===-1&&nvtList[0]===nvtSecond&&nvtList.getTrackById("17")===nvtSecond&&Object.keys(nvtList)[0]==="0"')! == 'true'
}

fn test_native_video_tracks_branding_conversions_reentry_and_boolean_selected() {
	$if !darwin { return }
	mut runtime, host, mut document := native_video_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nvtAudio')!)!
	mut track := media.on_video_track_added(html.MediaTrackMetadata{ identifier: 9 })
	assert runtime.evaluate_host(r'(()=>{
 const l=nvtAudio.videoTracks,t=l[0],get=Object.getOwnPropertyDescriptor(VideoTrack.prototype,"id").get,set=Object.getOwnPropertyDescriptor(VideoTrack.prototype,"selected").set,method=VideoTrackList.prototype.getTrackById;
 let calls=0;const value={[Symbol.toPrimitive](){calls++;throw "converted"}},proxy=new Proxy(t,{get(){calls++;throw "trap"},getPrototypeOf(){calls++;throw "prototype"}}),revoked=Proxy.revocable(l,{});revoked.revoke();
 for(const fake of [Object.create(VideoTrack.prototype),Object.create(t),proxy,VideoTrack.prototype])for(const f of [()=>get.call(fake),()=>set.call(fake,value)])try{f();return false}catch(e){if(!(e instanceof TypeError))return false}
 for(const fake of [Object.create(VideoTrackList.prototype),Object.create(l),new Proxy(l,{}),revoked.proxy,t,nvtAudio.audioTracks])try{method.call(fake,value);return false}catch(e){if(!(e instanceof TypeError))return false}
 const index=Object.getOwnPropertyDescriptor(VideoTrackList.prototype,"selectedIndex").get,mediaGet=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"videoTracks").get;
 for(const fake of [Object.create(l),t,nvtAudio.audioTracks,new Proxy(l,{get(){calls++;throw "trap"}})])try{index.call(fake);return false}catch(e){if(!(e instanceof TypeError))return false}
 for(const fake of [l,t,Object.create(nvtAudio),new Proxy(nvtVideo,{get(){calls++;throw "trap"}})])try{mediaGet.call(fake);return false}catch(e){if(!(e instanceof TypeError))return false}
 if(calls!==0)return false;
 try{method.call(l);return false}catch(e){if(!(e instanceof TypeError))return false}
 try{method.call(l,Symbol());return false}catch(e){if(!(e instanceof TypeError))return false}
 const sentinel={};try{method.call(l,{toString(){throw sentinel}});return false}catch(e){if(e!==sentinel)return false}
 let conversions=0;const id={toString(){conversions++;t.selected=false;return "9"}};
 if(method.call(l,id)!==t||conversions!==1||t.selected)return false;
 t.selected=value;if(!t.selected||calls!==0)return false;
 set.call(t);if(t.selected)return false;
 t.selected=Symbol();if(!t.selected)return false;
 t.selected=0n;if(t.selected)return false;
 return method.call(l,undefined)===null&&method.call(l,null)===null&&method.call(l,"9\0")===null;
})()')! == 'true'
	assert !track.selected
	track.set_selected(true)
	assert runtime.evaluate_host('nvtAudio.videoTracks[0].selected')! == 'true'
}

@[heap]
struct NativeVideoTracksBackend {
mut:
	changes []string
}

fn test_native_video_tracks_selection_reaches_backend_and_changes_precede_resize() {
	$if !darwin { return }
	mut runtime, host, mut document := native_video_tracks_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nvtVideo')!)!
	owner := unsafe { &dom.HTMLVideoElement(document.get_element_by_id('nvt-video')?) }
	assert owner.video_element_model_ == unsafe { nil }
	media.set_ready_state(.have_metadata)
	state := &NativeVideoTracksBackend{}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_video_track: fn [state, media] (track ?&html.VideoTrack) {
			mut observation := unsafe { &NativeVideoTracksBackend(state) }
			if selected := track {
				assert selected.selected
				assert voidptr(media.selected_video_track_sink() or { panic('Missing selected owner') }) == voidptr(selected)
				observation.changes << selected.base.id
			} else {
				assert media.selected_video_track_sink() == none
				observation.changes << 'none'
			}
		}
	})
	assert runtime.evaluate_host(r'globalThis.nvtList=nvtVideo.videoTracks;globalThis.nvtEvents=[];globalThis.nvtHandler=function(e){if(this!==nvtList||e.target!==nvtList||e.currentTarget!==nvtList||e.isTrusted!==(e.type==="change"))throw "list owner";nvtEvents.push(e.type+":"+nvtList.selectedIndex+":"+nvtVideo.videoWidth)};nvtList.onaddtrack=nvtHandler;nvtList.onchange=nvtHandler;nvtList.onremovetrack=nvtHandler;nvtVideo.onresize=function(e){if(this!==nvtVideo||e.target!==nvtVideo||e.currentTarget!==nvtVideo||!e.isTrusted)throw "resize owner";nvtEvents.push("resize:"+nvtList.selectedIndex+":"+nvtVideo.videoWidth)};nvtList.onaddtrack===nvtHandler&&nvtList.onchange===nvtHandler&&nvtList.onremovetrack===nvtHandler')! == 'true'
	_ = media.on_video_track_added(html.MediaTrackMetadata{ identifier: 1, pixel_width: 320, pixel_height: 180 })
	_ = media.on_video_track_added(html.MediaTrackMetadata{ identifier: 2, pixel_width: 640, pixel_height: 360 })
	assert state.changes == ['1']
	assert runtime.evaluate_host('JSON.stringify(nvtEvents)')! == '["addtrack:0:320","addtrack:0:320"]'
	native_video_tracks_drain(media)
	assert runtime.evaluate_host('JSON.stringify(nvtEvents)')! == '["addtrack:0:320","addtrack:0:320","change:0:320","resize:0:320"]'
	assert runtime.evaluate_host('nvtEvents.length=0;nvtList[1].selected=true;nvtList[1].selected=true;nvtList[0].selected=false;nvtEvents.length===0&&nvtList.selectedIndex===1&&!nvtList[0].selected&&nvtList[1].selected&&nvtVideo.videoWidth===640&&nvtVideo.videoHeight===360')! == 'true'
	assert state.changes == ['1', '2']
	native_video_tracks_drain(media)
	assert runtime.evaluate_host('JSON.stringify(nvtEvents)')! == '["change:1:640","resize:1:640"]'
	assert runtime.evaluate_host('nvtEvents.length=0;nvtList[1].selected=false;nvtList.selectedIndex===-1&&!nvtList[0].selected&&!nvtList[1].selected&&nvtVideo.videoWidth===0')! == 'true'
	assert state.changes == ['1', '2', 'none']
	native_video_tracks_drain(media)
	assert runtime.evaluate_host('JSON.stringify(nvtEvents)')! == '["change:-1:0"]'
	assert runtime.evaluate_host('nvtList[1].selected=true;globalThis.nvtSaved=nvtList[1];0')! == '0'
	native_video_tracks_drain(media)
	assert runtime.evaluate_host('nvtEvents.length=0;nvtList.onaddtrack=3;nvtList.onaddtrack===null')! == 'true'
	mut list := media.video_tracks()
	list.remove_all_tracks()
	assert state.changes == ['1', '2', 'none', '2', 'none']
	assert runtime.evaluate_host('nvtList.length===0&&nvtList.selectedIndex===-1&&!nvtSaved.selected&&nvtList[0]===undefined&&nvtVideo.videoWidth===0')! == 'true'
	native_video_tracks_drain(media)
	assert runtime.evaluate_host('JSON.stringify(nvtEvents)')! == '["change:-1:0"]'
	assert runtime.evaluate_host('nvtEvents.length=0;nvtSaved.selected=true;nvtSaved.selected&&nvtList.selectedIndex===-1&&nvtVideo.videoWidth===640')! == 'true'
	assert state.changes.last() == '2'
	native_video_tracks_drain(media)
	// Source still calls its media backend for a retained, detached track; only
	// list changes stop. The resulting resize continues to target the video.
	assert runtime.evaluate_host('JSON.stringify(nvtEvents)')! == '["resize:-1:640"]'
	assert native_video_tracks_drain(media) == 0
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_compact_video_tracks_parsed_created_video_live_owner_and_retained_prototypes() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="nvt-parsed" preload="none"></video><video id="nvt-video" preload="none"></video>', dom.URL{ value: 'https://video-tracks.example/dir/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.nvtParsed=document.getElementById("nvt-parsed");globalThis.nvtCreated=document.createElement("video");nvtCreated.id="nvt-created";nvtCreated.preload="none";document.body.appendChild(nvtCreated);
globalThis.nvtOwners=[nvtParsed,nvtCreated,document.getElementById("nvt-video")];globalThis.nvtLists=nvtOwners.map(o=>o.videoTracks);globalThis.nvtSavedList=VideoTrackList;globalThis.nvtSavedTrack=VideoTrack;
if(!nvtLists.every((l,i)=>l===nvtOwners[i].videoTracks&&l instanceof VideoTrackList&&l.length===0)||new Set(nvtLists).size!==3)throw "list ownership";
globalThis.VideoTrackList=null;globalThis.VideoTrack=function Replacement(){};
nvtCreated.setAttribute("data-owner","retained");nvtCreated.remove();document.body.appendChild(nvtCreated);
if(nvtCreated.videoTracks!==nvtLists[1])throw "moved list";
'], runtime, mut messages)
	assert messages == []
	for index, id in ['nvt-parsed', 'nvt-created', 'nvt-video'] {
		element := document.get_element_by_id(id)?
		mut media := html.html_media_element_for_dom_element(element)?
		_ = media.on_video_track_added(html.MediaTrackMetadata{ identifier: index + 10, name: 'Native ${index}' })
		assert runtime.evaluate_host('nvtLists[${index}]===nvtOwners[${index}].videoTracks&&nvtLists[${index}].length===1&&nvtLists[${index}][0].id==="${index + 10}"&&nvtLists[${index}][0].label==="Native ${index}"&&nvtLists[${index}] instanceof nvtSavedList&&nvtLists[${index}][0] instanceof nvtSavedTrack')! == 'true'
	}
	assert document.get_element_by_id('nvt-created')?.get_attribute('data-owner')? == 'retained'
	mut other, _, mut other_document := native_video_tracks_fixture()!
	defer { other.close();other_document.finalize() }
	assert other.evaluate_host('VideoTrackList.name==="VideoTrackList"&&VideoTrack.name==="VideoTrack"&&nvtAudio.videoTracks.length===0')! == 'true'
	runtime.close()
	assert other.evaluate_host('nvtAudio.videoTracks instanceof VideoTrackList&&nvtAudio.videoTracks.length===0')! == 'true'
}
