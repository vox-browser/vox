module browserjs

import dom
import html
import page

fn time_ranges_media_runtime() !(&Runtime, &dom.Document, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://native-ranges.example.test/page'
	}
	owner := page.Page.create(1)!
	document := html.create_navigation_document_for_page(address, address.origin(), none,
		unsafe { &dom.Page(owner) })!
	mut runtime := Runtime.create()
	mut queries := URLSearchParamsHost.create(document)!
	queries.install(mut runtime)!
	mut urls := URLHost.create(document)!
	urls.install(mut runtime)!
	mut sources := MediaSourceHost.create(document)!
	sources.install(mut runtime)!
	runtime.evaluate_host('globalThis.source=new MediaSource();globalThis.address=URL.createObjectURL(source);')!
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	mut media := html.html_media_element_for_dom_element(element) or {
		return error('missing actual media owner')
	}
	media.set_source(runtime.native_utf16_string(runtime.evaluate_host_value('address')!)!.str())
	media.load()!
	time_ranges_drain_tasks()
	return runtime, document, media
}

fn time_ranges_drain_tasks() {
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
}

fn test_native_source_buffer_returns_fresh_time_ranges_objects() {
	$if !darwin { return }
	mut runtime, mut document, mut media := time_ranges_media_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		time_ranges_drain_tasks()
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");
 if(typeof TimeRanges!=="function"||!("buffered" in SourceBuffer.prototype))return false;
 const descriptor=Object.getOwnPropertyDescriptor(SourceBuffer.prototype,"buffered");let reads=0,brand=false;
 const proxy=new Proxy(buffer,{get(){reads++;throw "author proxy"},getPrototypeOf(){reads++;throw "author proxy"}});
 try{descriptor.get.call(proxy)}catch(error){brand=error instanceof TypeError}
 return brand&&reads===0&&descriptor.enumerable&&descriptor.configurable&&descriptor.set===undefined&&descriptor.get.name==="get buffered"&&descriptor.get.length===0&&Function.prototype.toString.call(descriptor.get).includes("[native code]")&&!Reflect.set(buffer,"buffered",null)&&buffer.buffered instanceof TimeRanges&&buffer.buffered!==buffer.buffered&&buffer.buffered.length===0;
})()')! == 'true'
}

fn test_native_time_ranges_metadata_identity_and_unsigned_index_conversion() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_time_ranges_binding()!
	mut native := &html.TimeRanges{}
	native.add_range(1.5, 3)
	native.add_range(5, 8)
	object := runtime.javascript_time_ranges(native)!
	assert runtime.javascript_time_ranges(native)! == object
	assert runtime.native_time_ranges(object)! == native
	runtime.define_value_host_function('actualRanges', fn [object] (_ voidptr, _ []voidptr) !voidptr {
		return object
	})!
	assert runtime.evaluate_host(r'(()=>{
 const ranges=actualRanges(),get=Object.getOwnPropertyDescriptor,length=get(TimeRanges.prototype,"length");
 const flags=length.enumerable&&length.configurable&&length.set===undefined&&length.get.name==="get length"&&length.get.length===0&&Function.prototype.toString.call(length.get).includes("[native code]");
 const methods=["start","end"].every(name=>{const d=get(TimeRanges.prototype,name);return d.writable&&d.enumerable&&d.configurable&&d.value.name===name&&d.value.length===1&&Function.prototype.toString.call(d.value).includes("[native code]")});
 const illegal=[()=>TimeRanges(),()=>new TimeRanges(),()=>Reflect.construct(TimeRanges,[])].every(call=>{try{call();return false}catch(error){return error instanceof TypeError}});
 const zero=[0,-0,-0.9,NaN,Infinity,-Infinity,undefined,null,false,"0",4294967296].every(index=>ranges.start(index)===1.5&&ranges.end(index)===3);
 const one=[1,1.9,"1.9",4294967297,-4294967295].every(index=>ranges.start(index)===5&&ranges.end(index)===8);
 return flags&&methods&&illegal&&zero&&one&&ranges.length===2&&ranges instanceof TimeRanges&&Object.getPrototypeOf(TimeRanges)===Function.prototype&&Object.getPrototypeOf(TimeRanges.prototype)===Object.prototype&&Object.prototype.toString.call(ranges)==="[object TimeRanges]"&&TimeRanges.name==="TimeRanges"&&TimeRanges.length===0&&!get(TimeRanges,"prototype").writable&&Object.keys(ranges).length===0&&!("0" in ranges)&&ranges[Symbol.iterator]===undefined&&!("addEventListener" in ranges);
})()')! == 'true'
}

fn test_native_time_ranges_brands_precede_conversion_and_index_errors_are_dom_exceptions() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_time_ranges_binding()!
	mut native := &html.TimeRanges{}
	native.add_range(1, 2)
	object := runtime.javascript_time_ranges(native)!
	runtime.define_value_host_function('actualRanges', fn [object] (_ voidptr, _ []voidptr) !voidptr {
		return object
	})!
	assert runtime.evaluate_host(r'(()=>{
 const ranges=actualRanges(),marker={},prototype=TimeRanges.prototype,get=Object.getOwnPropertyDescriptor;let reads=0;
 const poison={valueOf(){reads++;throw marker}},fake=Object.create(prototype),proxy=new Proxy(ranges,{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}});
 const brands=[()=>prototype.start.call(fake,poison),()=>prototype.end.call(proxy,poison),()=>get(prototype,"length").get.call(proxy)].every(call=>{try{call();return false}catch(error){return error instanceof TypeError}});
 const rejected=[()=>ranges.start(),()=>ranges.end(),()=>ranges.start(1n),()=>ranges.end(Symbol())].every(call=>{try{call();return false}catch(error){return error instanceof TypeError}});
 const outside=[()=>ranges.start(1),()=>ranges.end(-1),()=>ranges.start(4294967295),()=>ranges.end(2.9)].every(call=>{try{call();return false}catch(error){return error instanceof DOMException&&error.name==="IndexSizeError"&&error.code===1&&error.message==="Index argument is greater than or equal to the number of ranges represented by this TimeRanges object"}});
 let original=false;try{ranges.start(poison)}catch(error){original=error===marker}
 let hint="";const converted=ranges.end({[Symbol.toPrimitive](actual){hint=actual;return "0.9"}})===2;
 Object.setPrototypeOf(ranges,null);
 return brands&&rejected&&outside&&original&&reads===1&&converted&&hint==="number"&&prototype.start.call(ranges,0)===1&&get(prototype,"length").get.call(ranges)===1;
})()')! == 'true'
}

fn test_native_time_ranges_wrappers_are_owned_by_each_runtime_and_capture_their_prototype() {
	$if !darwin { return }
	mut first := Runtime.create()
	defer { first.close() }
	mut second := Runtime.create()
	defer { second.close() }
	first.install_time_ranges_binding()!
	second.install_time_ranges_binding()!
	mut native := &html.TimeRanges{}
	native.add_range(2, 4)
	first_object := first.javascript_time_ranges(native)!
	second_object := second.javascript_time_ranges(native)!
	assert first_object != second_object
	assert first.native_time_ranges(first_object)! == native
	assert second.native_time_ranges(second_object)! == native
	if _ := second.native_time_ranges(first_object) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type TimeRanges'
	}
	first.evaluate_host('globalThis.rangePrototype=TimeRanges.prototype;globalThis.originalException=DOMException;globalThis.authorReads=0;globalThis.TimeRanges=function(){authorReads++;throw "author constructor"};globalThis.Number=function(){authorReads++;throw "author Number"};globalThis.DOMException=function(){authorReads++;throw "author DOMException"};')!
	object := first.javascript_time_ranges(&html.TimeRanges{})!
	first.define_value_host_function('actualEmptyRanges', fn [object] (_ voidptr, _ []voidptr) !voidptr {
		return object
	})!
	assert first.evaluate_host(r'(()=>{const ranges=actualEmptyRanges();try{ranges.start(undefined)}catch(error){return Object.getPrototypeOf(ranges)===rangePrototype&&error instanceof originalException&&error.name==="IndexSizeError"&&authorReads===0}return false})()')! == 'true'
	first.close()
	if _ := first.javascript_time_ranges(native) {
		assert false
	} else {
		assert err.msg() == 'JavaScript runtime is closed'
	}
	assert second.javascript_time_ranges(native)! == second_object
}

// Complete EBML initialization with one VP9 track, followed by one keyframe
// Cluster. This tests translated range records, not decoder/playback parity.
const time_ranges_webm_initialization = [u8(0x1a), 0x45, 0xdf, 0xa3, 0x80, 0x18, 0x53, 0x80, 0x67,
	0xff, 0x15, 0x49, 0xa9, 0x66, 0x92, 0x2a, 0xd7, 0xb1, 0x83, 0x0f, 0x42, 0x40, 0x44, 0x89, 0x88,
	0x40, 0x9f, 0x40, 0, 0, 0, 0, 0, 0x16, 0x54, 0xae, 0x6b, 0x97, 0xae, 0x95, 0xd7, 0x81, 1, 0x83,
	0x81, 1, 0x86, 0x85, 0x56, 0x5f, 0x56, 0x50, 0x39, 0x23, 0xe3, 0x83, 0x84, 1, 0xfc, 0xa0, 0x55]

const time_ranges_webm_cluster = [u8(0x1f), 0x43, 0xb6, 0x75, 0x8b, 0xe7, 0x81, 0, 0xa3, 0x86,
	0x81, 0, 0, 0x80, 1, 2]

fn test_native_buffered_ranges_follow_actual_append_and_remove_without_changing_old_snapshots() {
	$if !darwin { return }
	mut runtime, mut document, mut media := time_ranges_media_runtime()!
	defer {
		media.set_source(none)
		media.load() or {}
		time_ranges_drain_tasks()
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");globalThis.empty=buffer.buffered;buffer.appendBuffer(new Uint8Array(${time_ranges_webm_initialization}));')!
	time_ranges_drain_tasks()
	assert runtime.evaluate_host('source.readyState==="open"&&!buffer.updating&&buffer.buffered.length===0')! == 'true'
	runtime.evaluate_host('buffer.appendBuffer(new Uint8Array(${time_ranges_webm_cluster}));')!
	time_ranges_drain_tasks()
	assert runtime.evaluate_host(r'globalThis.saved=buffer.buffered;globalThis.savedEnd=saved.end(0);saved.length===1&&saved.start(0)===0&&savedEnd>0.033&&savedEnd<0.034&&empty.length===0&&saved!==buffer.buffered')! == 'true'
	assert media.buffered().length() == 1
	assert runtime.evaluate_host('buffer.remove(0,Infinity);buffer.updating&&saved.length===1&&buffer.buffered.length===1')! == 'true'
	time_ranges_drain_tasks()
	assert runtime.evaluate_host('!buffer.updating&&buffer.buffered.length===0&&saved.length===1&&saved.end(0)===savedEnd&&empty.length===0')! == 'true'
	media.set_source(none)
	media.load()!
	assert runtime.evaluate_host(r'(()=>{try{buffer.buffered;return false}catch(error){return error instanceof DOMException&&error.name==="InvalidStateError"&&saved.end(0)===savedEnd&&empty.length===0}})()')! == 'true'
}
