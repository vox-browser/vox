module browserjs

import dom
import html
import libjs

fn track_event_native_fixture() !(&Runtime, &MediaElementHost, &dom.Document) {
	url := dom.URL{value: 'https://track-event.example/'}
	mut document := html.parse_navigation_document('<!doctype html><audio preload="none"></audio>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.nteMedia={};__ladybirdMediaElementBind(nteMedia,"${key}","audio");0')!
		}
	}
	return runtime, host, document
}

fn track_event_native_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++;assert count < 100
		task.execute()
	}
}

fn test_track_event_window_metadata_defaults_subclasses_and_retained_parent() {
	$if !darwin { return }
	mut runtime, _, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n)},C=TrackEvent,p=C.prototype,d=Object.getOwnPropertyDescriptor(p,"track"),g=Object.getOwnPropertyDescriptor(globalThis,"TrackEvent");
 check(C.name==="TrackEvent"&&C.length===1&&Object.getPrototypeOf(C)===Event&&Object.getPrototypeOf(p)===Event.prototype&&!Object.getOwnPropertyDescriptor(C,"prototype").writable&&g.writable&&g.configurable&&!g.enumerable,"constructor metadata");
 check(d.get.name==="get track"&&d.get.length===0&&d.set===undefined&&d.enumerable&&d.configurable&&Function.prototype.toString.call(d.get).includes("[native code]")&&Object.getOwnPropertyNames(p).sort().join(",")==="constructor,track","getter metadata");
 const tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag);check(tag.value==="TrackEvent"&&!tag.writable&&!tag.enumerable&&tag.configurable,"tag");
 const e=new C("λ\0event"),extra={get ignored(){throw 1}};class Child extends C{}const child=new Child("child",null,extra);
 check(e instanceof C&&e instanceof Event&&!(e instanceof UIEvent)&&Object.prototype.toString.call(e)==="[object TrackEvent]"&&e.type==="λ\0event"&&e.track===null&&!e.isTrusted&&!e.bubbles&&!e.cancelable&&!e.composed&&e.timeStamp>=0&&e.timeStamp<10000&&!Object.hasOwn(e,"track")&&child instanceof Child&&child.track===null,"defaults and subclass");
 for(const op of [()=>C("call"),()=>new C(),()=>new C(Symbol()),()=>Reflect.construct(function(){},[],d.get)]){let rejected=false;try{op()}catch(e){rejected=e instanceof TypeError}check(rejected,"constructor requirement")}
 let gets=0,conversions=0;const marker={},next=new Proxy(function Next(){},{get(t,k,r){if(k==="prototype"){gets++;throw marker}return Reflect.get(t,k,r)}});
 for(const args of [[],[{toString(){conversions++;return "x"}}]])try{Reflect.construct(C,args,next);throw 0}catch(e){check(e===marker,"prototype exception identity")}
 check(gets===2&&conversions===0,"prototype before arity and conversion");const Other=function(){};Other.prototype=1;check(Object.getPrototypeOf(Reflect.construct(C,["fallback"],Other))===p,"prototype fallback");
 globalThis.savedTrackEvent=C;globalThis.savedTrackEventParent=Event;globalThis.Event=function Replacement(){};globalThis.TrackEvent=null;check(Object.getPrototypeOf(C)===savedTrackEventParent&&new C("saved") instanceof savedTrackEventParent,"retained parent");return true;
})()')! == 'true'
	mut unbound := Runtime.create()
	defer { unbound.close() }
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof TrackEvent==="undefined"')! == 'true'
	unbound.evaluate_host('globalThis.savedBaseEvent=Event;Event=function Replaced(){};globalThis={};0')!
	unbound.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host('typeof TrackEvent==="function"&&Object.getPrototypeOf(TrackEvent)===savedBaseEvent&&new TrackEvent("late").track===null&&globalThis.TrackEvent===undefined')! == 'true'
	constructor := unbound.evaluate_host_value('TrackEvent')!
	unbound.install_event_target_binding()!
	assert unbound.evaluate_host_value('TrackEvent')! == constructor
}

fn test_track_event_ordered_dictionary_nullable_union_and_original_exceptions() {
	$if !darwin { return }
	mut runtime, host, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nteMedia')!)!
	media.on_audio_track_added(html.MediaTrackMetadata{identifier: 1})
	media.on_video_track_added(html.MediaTrackMetadata{identifier: 2})
	media.add_text_track(.captions, 'caption', 'en')
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n)},tracks=[nteMedia.videoTracks[0],nteMedia.audioTracks[0],nteMedia.textTracks[0]],log=[];
 globalThis.nteTracks=tracks;
 const dictionary=new Proxy({bubbles:true,cancelable:{valueOf(){throw 0}},composed:true,track:tracks[0]},{get(t,k){log.push(k);return t[k]}}),e=new TrackEvent({toString(){log.push("type");return "ordered"}},dictionary);
 check(log.join(",")==="type,bubbles,cancelable,composed,track"&&e.bubbles&&e.cancelable&&e.composed&&e.track===tracks[0],"dictionary order and ToBoolean");
 for(const track of tracks){const e=new TrackEvent("union",{track});check(e.track===track,"native nullable union");Object.defineProperty(track,"constructor",{get(){throw 0},configurable:true});check(new TrackEvent("no inspection",{track}).track===track,"no author constructor read")}
 for(const dictionary of [undefined,null])check(new TrackEvent("default",dictionary).track===null,"null dictionary");for(const track of [null,undefined])check(new TrackEvent("null track",{track}).track===null,"null track default");
 const old=Object.getOwnPropertyDescriptor(Object.prototype,"track");let reads=0,correct=true;Object.defineProperty(Object.prototype,"track",{get(){reads++;return tracks[1]},configurable:true});try{for(const d of [undefined,null])if(new TrackEvent("skip",d).track!==null)correct=false;if(new TrackEvent("inherit",{}).track!==tracks[1]||reads!==1)correct=false}finally{if(old)Object.defineProperty(Object.prototype,"track",old);else delete Object.prototype.track}check(correct,"nullish dictionary bypasses prototype");
 for(const d of [1,true,"x",Symbol()]){let ok=false;try{new TrackEvent("dict",d)}catch(e){ok=e instanceof TypeError}check(ok,"dictionary brand")}
 const marker={};let later=0;for(const where of ["type","bubbles","track"]){const args=where==="type"?[{toString(){throw marker}},{get bubbles(){later++}}]:["abrupt",where==="bubbles"?{get bubbles(){throw marker},get track(){later++}}:{get track(){throw marker}}];let same=false;try{new TrackEvent(...args)}catch(e){same=e===marker}check(same,"original exception")}
 let traps=0;for(const track of [1,"track",{},Object.create(AudioTrack.prototype),Object.create(tracks[0]),new Proxy(tracks[1],{get(){traps++;throw 0},getPrototypeOf(){traps++;throw 0}}),nteMedia.audioTracks]){let ok=false;try{new TrackEvent("brand",{track})}catch(e){ok=e instanceof TypeError}check(ok,"union rejects forgery")}
 const get=Object.getOwnPropertyDescriptor(TrackEvent.prototype,"track").get;for(const fake of [{},Object.create(e),new Proxy(e,{get(){traps++;throw 0}}),new Event("base"),new DragEvent("other")]){let ok=false;try{get.call(fake)}catch(e){ok=e instanceof TypeError}check(ok,"getter brand")}
 return later===0&&traps===0;
})()')! == 'true'
	for index, kind in [html.TrackEventTrackKind.video, .audio, .text] {
		value := runtime.evaluate_host_value('new TrackEvent("native",{track:nteTracks[${index}]})')!
		event := runtime.native_event(value)!
		assert event.interface_ == .track_event && !event.is_trusted()
		assert unsafe { &html.TrackEvent(event) }.track().kind == kind
	}
}

fn test_track_event_native_audio_video_delivery_and_public_redispatch_keep_identity() {
	$if !darwin { return }
	mut runtime, host, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nteEvents=[];globalThis.ntePayloads=[];for(const list of [nteMedia.audioTracks,nteMedia.videoTracks])list.onaddtrack=function(e){if(!(e instanceof TrackEvent)||!(e instanceof Event)||e.target!==this||e.currentTarget!==this||e.isTrusted||e.track!==this[this.length-1])throw "native add payload";nteEvents.push(e);ntePayloads.push(e.track)};0')! == '0'
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nteMedia')!)!
	audio := media.on_audio_track_added(html.MediaTrackMetadata{identifier: 7})
	video := media.on_video_track_added(html.MediaTrackMetadata{identifier: 8})
	assert runtime.evaluate_host(r'(()=>{
 const a=nteEvents[0],v=nteEvents[1],list=nteMedia.audioTracks;let same=false;list.addEventListener("addtrack",e=>{same=e===a&&e.track===ntePayloads[0]});list.dispatchEvent(a);
 return same&&nteEvents.length===3&&a.track===nteMedia.audioTracks[0]&&v.track===nteMedia.videoTracks[0]&&a.track instanceof AudioTrack&&v.track instanceof VideoTrack&&a.currentTarget===null;
})()')! == 'true'
	assert runtime.native_track_event_payload(runtime.evaluate_host_value('ntePayloads[0]')!)!.audio? == audio
	assert runtime.native_track_event_payload(runtime.evaluate_host_value('ntePayloads[1]')!)!.video? == video
	track_event_native_drain(document)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_track_event_deferred_text_track_delivery_and_reentrant_constructor() {
	$if !darwin { return }
	mut runtime, _, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nteTextEvents=[];nteMedia.textTracks.onaddtrack=function(e){if(!(e instanceof TrackEvent)||e.track!==this[nteTextEvents.length]||!(e.track instanceof TextTrack)||e.target!==this||e.isTrusted)throw "text payload";nteTextEvents.push(e);if(nteTextEvents.length===1)nteMedia.addTextTrack("metadata","reentrant")};globalThis.nteText=nteMedia.addTextTrack("captions","first");nteTextEvents.length===0')! == 'true'
	track_event_native_drain(document)
	assert runtime.evaluate_host(r'(()=>{
 const e=nteTextEvents[0];if(nteTextEvents.length!==2||e.track!==nteText||nteTextEvents[1].track.label!=="reentrant")return false;
 const inner=nteMedia.addTextTrack("metadata","inner"),outer=new TrackEvent({toString(){nteText.mode="showing";return "reentrant constructor"}},{get bubbles(){inner.mode="hidden";return false},get track(){return inner}});
 return outer.track===inner&&outer.type==="reentrant constructor"&&nteText.mode==="showing"&&e.track===nteText;
})()')! == 'true'
	// The handler above was deliberately specific to the first two additions.
	runtime.evaluate_host('nteMedia.textTracks.onaddtrack=null;0')!
	track_event_native_drain(document)
}

fn test_track_event_removal_first_wrapper_and_saved_event_payloads_survive_cleared_lists() {
	$if !darwin { return }
	mut runtime, host, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nteMedia')!)!
	// No indexed getter or addtrack listener has materialized either wrapper.
	audio := media.on_audio_track_added(html.MediaTrackMetadata{identifier: 31})
	video := media.on_video_track_added(html.MediaTrackMetadata{identifier: 32})
	mut audio_list := media.audio_tracks()
	mut video_list := media.video_tracks()
	audio_list.remove_all_tracks();video_list.remove_all_tracks()
	runtime.evaluate_host(r'globalThis.nteRemoved=[];for(const l of [nteMedia.audioTracks,nteMedia.videoTracks])l.onremovetrack=function(e){if(!(e instanceof TrackEvent)||e.track.id!==(this===nteMedia.audioTracks?"31":"32")||this.length!==0||e.target!==this)throw "removed payload";nteRemoved.push(e)};0')!
	audio_event := html.TrackEvent.create('removetrack', html.TrackEventInit{track: html.TrackEventTrack.from_audio(audio)})
	video_event := html.TrackEvent.create('removetrack', html.TrackEventInit{track: html.TrackEventTrack.from_video(video)})
	audio_list.dispatch_event(unsafe { &dom.Event(audio_event) })
	video_list.dispatch_event(unsafe { &dom.Event(video_event) })
	assert runtime.evaluate_host(r'(()=>{const [a,v]=nteRemoved;if(!a||!v||!(a.track instanceof AudioTrack)||!(v.track instanceof VideoTrack)||a.track.enabled||v.track.selected)return false;const saved=new TrackEvent("saved",{track:a.track});return saved.track===a.track&&a.track===a.track&&v.track===v.track&&a.currentTarget===null})()')! == 'true'
	track_event_native_drain(document)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
}

fn test_track_event_runtime_local_brands_and_independent_close() {
	$if !darwin { return }
	mut runtime, host, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	mut other, mut other_host, mut other_document := track_event_native_fixture()!
	defer { other.close();other_document.finalize() }
	mut media := host.media_element_for_binding(runtime.evaluate_host_value('nteMedia')!)!
	track := media.add_text_track(.metadata, 'owner', '')
	wrapper := runtime.evaluate_host_value('nteMedia.textTracks[0]')!
	foreign := other_host.wrap_text_track(track)!
	assert wrapper != foreign
	assert runtime.native_track_event_payload(wrapper)!.text? == track
	assert other.native_track_event_payload(foreign)!.text? == track
	if _ := runtime.native_track_event_payload(foreign) { assert false, 'accepted foreign track' }
	if _ := other.native_track_event_payload(wrapper) { assert false, 'accepted foreign track' }
	unknown := html.TrackEvent.create('unavailable', html.TrackEventInit{track: html.TrackEventTrack.from_audio(html.AudioTrack.create(html.MediaTrackMetadata{}, fn () {}, fn (_ &html.AudioTrack, _ bool) {}))})
	if _ := runtime.javascript_track_event_payload(unknown) { assert false, 'fabricated a media owner' }
	runtime.close()
	if _ := runtime.native_track_event_payload(wrapper) { assert false, 'accepted closed binding' }
	assert other.evaluate_host('new TrackEvent("independent").track===null')! == 'true'
}

fn test_track_event_type_keeps_nul_non_bmp_and_lone_utf16_surrogates() {
	$if !darwin { return }
	mut runtime, _, mut document := track_event_native_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const names=["","\0","λ🎵","\ud800","\udfff","a\ud800\0\udfff🎵","\ufeffprefix"];
 for(const name of names){let calls=0;const e=new TrackEvent({toString(){calls++;return name}});if(e.type!==name||calls!==1||e.track!==null)return false}
 globalThis.nteUtf16=new TrackEvent("a\ud800\0\udfff🎵");return true;
})()')! == 'true'
	value := runtime.evaluate_host_value('nteUtf16')!
	event := runtime.native_event(value)!
	assert libjs.utf16_string_from_utf8_without_validation(event.type_name()).code_units() == [u16(97), 0xd800, 0, 0xdfff, 0xd83c, 0xdfb5]
	assert runtime.javascript_event(event)! == value
	assert runtime.evaluate_host(r'nteUtf16.type==="a\ud800\0\udfff🎵"')! == 'true'
}
