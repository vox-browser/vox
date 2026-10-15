module browserjs

import dom
import html
import libjs

const mcon_first = 'urn:crossorigin-native-first'
const mcon_second = 'urn:crossorigin-native-second'
const mcon_prefixed = 'urn:crossorigin-native-prefixed'

@[heap]
struct MconProbe {
mut:
	replays int
	mode int
	fetches int
	volume_updates []f64
	element &dom.Element = unsafe { nil }
}

fn mcon_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document) {
	address := dom.URL{ value: 'https://crossorigin-native-namespace.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="mcon-video-first"></video><video id="mcon-video-last"></video><audio id="mcon-audio-first"></audio><audio id="mcon-audio-last"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.mconPlayers={};0')!
	for key, element in host.elements_for_binding() {
		if element.local_name() !in ['audio', 'video'] { continue }
		id := element.get_attribute('id') or { return error('Missing crossorigin namespace ID') }
		_ = runtime.evaluate_host('mconPlayers["${id}"]={};__ladybirdMediaElementBind(mconPlayers["${id}"],"${key}","${element.local_name()}");0')!
	}
	return runtime, host, document
}

fn mcon_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing crossorigin namespace element ${id}') }
}

fn mcon_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'crossorigin') or { return error('Missing crossorigin namespace attribute') }
}

fn mcon_foreign_intact(element &dom.Element, first &dom.Attr_, second &dom.Attr_, prefixed &dom.Attr_) ! {
	for index, attribute in [first, second, prefixed] {
		namespace := [mcon_first, mcon_second, mcon_prefixed][index]
		owner := attribute.owner_element() or { return error('Foreign crossorigin attribute lost its owner') }
		actual_namespace := attribute.namespace_uri() or { return error('Foreign crossorigin attribute lost its namespace') }
		assert voidptr(owner) == voidptr(element) && actual_namespace == namespace
		assert voidptr(mcon_attr(element, namespace)!) == voidptr(attribute) && attribute.local_name() == 'crossorigin'
	}
	assert first.value() == 'use-credentials' && second.value() == 'anonymous'
	assert first.name() == 'crossorigin' && second.name() == 'crossorigin'
	assert first.prefix() == none && second.prefix() == none
	assert prefixed.value() == 'prefixed raw' && prefixed.name() == 'p:crossorigin'
	prefix := prefixed.prefix() or { return error('Foreign crossorigin attribute lost its prefix') }
	assert prefix == 'p'
}

fn test_native_crossorigin_namespace_nullable_reflection_preserves_foreign_identity_and_adopted_owner() {
	$if !darwin { return }
	mut runtime, _, mut document := mcon_fixture(none)!
	address := dom.URL{ value: 'https://crossorigin-native-adopted.example.test/' }
	mut destination := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	defer { runtime.close(); document.finalize(); destination.finalize() }
	probe := &MconProbe{}
	_ = runtime.evaluate_host('globalThis.mconSync=[];globalThis.mconSetter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"crossOrigin").set;__ladybirdMediaElementSetAttributeSync((receiver,name,value)=>mconSync.push([receiver,name,value]));0')!
	for index, id in ['mcon-video-first', 'mcon-video-last', 'mcon-audio-first', 'mcon-audio-last'] {
		mut element := mcon_element(document, id)!
		if index % 2 == 0 { element.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS') }
		element.set_attribute_ns_for_bindings(mcon_first, 'crossorigin', 'use-credentials')!
		element.set_attribute_ns_for_bindings(mcon_second, 'crossorigin', 'anonymous')!
		element.set_attribute_ns_for_bindings(mcon_prefixed, 'p:crossorigin', 'prefixed raw')!
		if index % 2 == 1 { element.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS') }
		first := mcon_attr(element, mcon_first)!
		second := mcon_attr(element, mcon_second)!
		prefixed := mcon_attr(element, mcon_prefixed)!
		original := mcon_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing crossorigin namespace model') }
		media.set_current_time(f64(index) + 3.25)
		media.set_paused(index % 2 == 0)
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MconProbe(probe) }; observed.fetches++
			return error('source-less crossorigin namespace reflection must not fetch')
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			set_volume: fn [probe] (volume f64) {
				mut observed := unsafe { &MconProbe(probe) }; observed.volume_updates << volume
			}
		})
		player := 'mconPlayers["${id}"]'
		assert runtime.evaluate_host('${player}.crossOrigin==="use-credentials"')! == 'true'
		assert media.cross_origin()? == 'use-credentials' && media.crossorigin() == .use_credentials
		for raw in ['ANONYMOUS', 'UsE-CrEdEnTiAlS', '', 'invalid', ' use-credentials '] {
			canonical := if raw == 'UsE-CrEdEnTiAlS' { 'use-credentials' } else { 'anonymous' }
			assert runtime.evaluate_host('${player}.crossOrigin="${raw}";${player}.crossOrigin==="${canonical}"')! == 'true'
			assert media.cross_origin()? == canonical && original.value() == raw
			assert voidptr(mcon_attr(element, none)!) == voidptr(original)
			mcon_foreign_intact(element, first, second, prefixed)!
		}
		for argument in ['null', 'undefined', ''] {
			element.set_attribute_value('crossorigin', 'USE-CREDENTIALS')
			removed := mcon_attr(element, none)!
			suffix := if argument == '' { '' } else { ',' + argument }
			assert runtime.evaluate_host('mconSetter.call(${player}${suffix})===undefined&&${player}.crossOrigin===null&&mconSync[mconSync.length-1][0]===${player}&&mconSync[mconSync.length-1][1]==="crossorigin"&&mconSync[mconSync.length-1][2]===false')! == 'true'
			assert media.cross_origin() == none && media.crossorigin() == .no_cors && removed.owner_element() == none
			assert element.has_attribute('crossorigin') && !element.has_attribute_ns(none, 'crossorigin')
			mcon_foreign_intact(element, first, second, prefixed)!
		}
		element.set_attribute_value('crossorigin', 'ANONYMOUS')
		assert runtime.evaluate_host('${player}.crossOrigin==="anonymous"')! == 'true'
		element.remove_attribute_ns(none, 'crossorigin')
		assert runtime.evaluate_host('${player}.crossOrigin===null')! == 'true'
		assert media.paused() == (index % 2 == 0) && media.current_time() == f64(index) + 3.25
		media.set_paused(true)
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html.html_media_element_for_dom_element(element) or { panic('Missing adopted crossorigin owner') }) == voidptr(media)
		assert runtime.evaluate_host('${player}.crossOrigin="USE-CREDENTIALS";${player}.crossOrigin==="use-credentials"')! == 'true'
		assert media.crossorigin() == .use_credentials && mcon_attr(element, none)!.value() == 'USE-CREDENTIALS'
		assert runtime.evaluate_host('${player}.crossOrigin=null;${player}.crossOrigin===null')! == 'true'
		mcon_foreign_intact(element, first, second, prefixed)!
		assert !media.muted() && media.volume() == 1 && media.current_time() == f64(index) + 3.25
		assert media.paused() && media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['volumechange', 'play', 'playing', 'pause', 'loadstart', 'seeking'] { assert media.event_count(name) == 0 }
	}
	assert probe.fetches == 0 && probe.volume_updates == []
}

fn test_native_crossorigin_namespace_orders_nullable_conversion_replay_and_abrupt_completion() {
	$if !darwin { return }
	probe := &MconProbe{}
	mut runtime, _, mut document := mcon_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MconProbe(probe) }; observed.replays++
		_ = runtime.evaluate_host('mconOrder.push("replay");0')!
		mut element := unsafe { &dom.Element(observed.element) }
		match observed.mode {
			1 { element.set_attribute_ns_for_bindings(mcon_first, 'crossorigin', 'use-credentials')! }
			2 { element.set_attribute_value('crossorigin', 'ANONYMOUS') }
			3 { element.remove_attribute_ns(none, 'crossorigin') }
			4 {
				mut owner := unsafe { &Runtime(runtime) }
				_ = owner.evaluate_host_value('throw mconReplayReason')!
			}
			else {}
		}
	})!
	defer { runtime.close(); document.finalize() }
	mut observed := unsafe { &MconProbe(probe) }
	mut element := mcon_element(document, 'mcon-video-first')!
	observed.element = element
	media := html.html_media_element_for_dom_element(element) or { panic('Missing crossorigin replay model') }
	_ = runtime.evaluate_host(r'globalThis.mconVideo=mconPlayers["mcon-video-first"];globalThis.mconSync=[];globalThis.mconOrder=[];globalThis.mconConversions=0;globalThis.mconReplayReason={};globalThis.mconConversionReason={};globalThis.mconDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"crossOrigin");__ladybirdMediaElementSetAttributeSync((receiver,name,value)=>{mconOrder.push("sync");mconSync.push([receiver,name,value])});0')!
	assert runtime.evaluate_host(r'(()=>{let conversions=0,traps=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};const revoked=Proxy.revocable(mconVideo,{});revoked.revoke();const proxy=new Proxy(mconVideo,{get(){traps++;throw "proxy"}});for(const receiver of [proxy,revoked.proxy,Object.create(HTMLMediaElement.prototype)])for(const operation of [()=>mconDescriptor.get.call(receiver),()=>mconDescriptor.set.call(receiver,value),()=>mconDescriptor.set.call(receiver)]){try{operation();return false}catch(error){if(!(error instanceof TypeError))return false}}return conversions===0&&traps===0})()')! == 'true'
	assert probe.replays == 0
	observed.mode = 1
	assert runtime.evaluate_host('mconVideo.crossOrigin===null')! == 'true'
	assert media.cross_origin() == none && media.crossorigin() == .no_cors
	first := mcon_attr(element, mcon_first)!
	element.set_attribute_ns_for_bindings(mcon_second, 'crossorigin', 'anonymous')!
	element.set_attribute_ns_for_bindings(mcon_prefixed, 'p:crossorigin', 'prefixed raw')!
	second := mcon_attr(element, mcon_second)!
	prefixed := mcon_attr(element, mcon_prefixed)!
	observed.mode = 2
	assert runtime.evaluate_host('mconVideo.crossOrigin==="anonymous"')! == 'true'
	original := mcon_attr(element, none)!
	assert media.crossorigin() == .anonymous && original.value() == 'ANONYMOUS'
	observed.mode = 3
	assert runtime.evaluate_host('mconVideo.crossOrigin===null')! == 'true'
	assert original.owner_element() == none && media.cross_origin() == none
	observed.mode = 1
	assert runtime.evaluate_host(r'(()=>{mconOrder.length=0;const value={[Symbol.toPrimitive](hint){mconConversions++;mconOrder.push("convert:"+hint);return "UsE-CrEdEnTiAlS"}};if(mconDescriptor.set.call(mconVideo,value)!==undefined||mconOrder.join(",")!=="convert:string,replay,sync")return false;return mconConversions===1&&mconVideo.crossOrigin==="use-credentials"})()')! == 'true'
	assert probe.replays == 5 && mcon_attr(element, none)!.value() == 'UsE-CrEdEnTiAlS'
	assert runtime.evaluate_host(r'globalThis.mconRaw="\u0000\uD800X\uDC00\u{1F642}";mconVideo.crossOrigin=mconRaw;mconVideo.crossOrigin==="anonymous"&&mconSync[1][2]===mconRaw')! == 'true'
	null_attr := mcon_attr(element, none)!
	assert libjs.utf16_string_from_utf8_without_validation(null_attr.value()).code_units() == [u16(0), 0xd800, 0x58, 0xdc00, 0xd83d, 0xde42]
	assert media.crossorigin() == .anonymous && probe.replays == 7
	observed.mode = 4
	assert runtime.evaluate_host(r'(()=>{try{mconDescriptor.set.call(mconVideo,{[Symbol.toPrimitive](){throw mconConversionReason}});return false}catch(error){if(error!==mconConversionReason)return false}try{mconDescriptor.set.call(mconVideo,Symbol());return false}catch(error){if(!(error instanceof TypeError))return false}mconOrder.length=0;for(const operation of [()=>mconDescriptor.get.call(mconVideo),()=>mconDescriptor.set.call(mconVideo,{[Symbol.toPrimitive](hint){mconOrder.push("convert:"+hint);return "anonymous"}}),()=>mconDescriptor.set.call(mconVideo)]){try{operation();return false}catch(error){if(error!==mconReplayReason)return false}}return mconOrder.join(",")==="replay,convert:string,replay,replay"&&mconSync.length===2&&mconSync[0][0]===mconVideo&&mconSync[0][1]==="crossorigin"&&mconSync[0][2]==="UsE-CrEdEnTiAlS"})()')! == 'true'
	assert probe.replays == 10 && voidptr(mcon_attr(element, none)!) == voidptr(null_attr)
	assert libjs.utf16_string_from_utf8_without_validation(null_attr.value()).code_units() == [u16(0), 0xd800, 0x58, 0xdc00, 0xd83d, 0xde42]
	mcon_foreign_intact(element, first, second, prefixed)!
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	for name in ['volumechange', 'play', 'playing', 'pause', 'loadstart'] { assert media.event_count(name) == 0 }
}
