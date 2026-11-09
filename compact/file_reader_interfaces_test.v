module main

import browserjs
import dom
import fetch
import html
import http
import time

fn file_reader_agent(source string, module_ bool, shared bool) !&browserjs.WorkerAgentRuntime {
	url := dom.URL{ value: 'https://file-readers.test/entry.js' }
	transport := &fetch.FetchHost{
		perform: fn [source] (_ &fetch.Request) !&fetch.Response {
			mut response := fetch.Response.create()
			response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
			response.set_body_bytes(source.bytes())
			return response
		}
	}
	outside := html.SerializedEnvironmentSettingsObject{
		creation_url: url
		api_base_url: url
		origin:       url.origin()
		global:       html.SerializedWindow{ associated_document: html.SerializedDocument{ url: url, relevant_settings_object_is_secure_context: true } }
	}
	options := html.WorkerOptions{ type_: if module_ { .module_ } else { .classic } }
	if shared {
		return browserjs.WorkerAgentRuntime.create_shared(url, options, outside, 1, transport)
	}
	return browserjs.WorkerAgentRuntime.create(url, options, outside, 1, transport)
}

fn test_file_reader_sync_uses_native_bytes_decoding_and_worker_interface_metadata() {
	for module_ in [false, true] {
		mut agent := file_reader_agent(r'
const check=(value,message)=>{if(!value)throw Error(message)};
class Derived extends FileReaderSync{};const reader=new Derived();
check(reader instanceof Derived&&reader instanceof FileReaderSync&&!(reader instanceof EventTarget),"inheritance");
check(FileReaderSync.length===0&&FileReaderSync.name==="FileReaderSync"&&Object.prototype.toString.call(reader)==="[object FileReaderSync]","interface");
const blob=new Blob([new Uint8Array([0,128,255])]);Object.defineProperty(blob,"type",{get(){throw Error("author type getter")}});
const first=reader.readAsArrayBuffer(blob),second=reader.readAsArrayBuffer(blob);
check(first!==second&&Array.from(new Uint8Array(first)).join()==="0,128,255","fresh native ArrayBuffers");
first.transfer();check(Array.from(new Uint8Array(second)).join()==="0,128,255","independent bytes");
check(reader.readAsBinaryString(blob)==="\x00\x80\xff","binary string");
check(reader.readAsText(new Blob([new Uint8Array([255,254,65,0])]),"UTF-8")==="A","BOM wins");
check(reader.readAsText(new Blob([new Uint8Array([128])],{type:"text/plain;charset=windows-1252"}))==="€","MIME charset");
check(reader.readAsDataURL(new Blob())==="data:application/octet-stream;base64,","empty data URL");
check(reader.readAsDataURL(new File(["a"],"a.txt",{type:"text/plain"}))==="data:text/plain;base64,YQ==","File bytes");
let errors=0;for(const call of [()=>FileReaderSync(),()=>new reader.readAsText(blob),()=>reader.readAsText(),()=>reader.readAsText({}),()=>reader.readAsText(new Proxy(blob,{})),()=>FileReaderSync.prototype.readAsText.call({},blob),()=>reader.readAsText(blob,Symbol())])try{call()}catch(e){if(e instanceof TypeError)errors++;}
const marker={};let preserved=false;try{reader.readAsText(blob,{toString(){throw marker}})}catch(e){preserved=e===marker}
check(errors===7&&preserved&&reader.readAsText.length===1&&!("prototype" in reader.readAsText),"IDL conversion");
postMessage("passed");
', module_, false)!
		defer { agent.close() }
		agent.load_entry()!
		agent.process()
		frames := agent.take_outgoing()
		assert frames.len == 1, 'module=${module_}'
		mut receiver := browserjs.Runtime.create()
		defer { receiver.close() }
		bridge := browserjs.ArrayBufferTransferBridge.create(receiver)!
		actual := bridge.deserialize(browserjs.decode_worker_message(frames[0])!)!
		assert receiver.native_utf16_string(actual)!.str() == 'passed'
	}
}

fn test_file_reader_sync_is_available_to_shared_workers_and_rejected_for_window_installation() {
	mut window := browserjs.Runtime.create()
	defer { window.close() }
	if _ := window.install_file_reader_sync_binding() {
		assert false
	}
	assert window.evaluate_host('typeof FileReaderSync')! == 'undefined'
	mut agent := file_reader_agent(r'
const reader=new FileReaderSync();if(reader.readAsText(new Blob(["shared"]))!=="shared")throw Error("shared reader");
', false, true)!
	defer { agent.close() }
	agent.load_entry()!
	assert agent.environment.settings.realm().reported_exceptions.len == 0
}

fn file_reader_window() (&browserjs.Runtime, &dom.Document) {
	mut runtime := browserjs.Runtime.create()
	document := dom.Document.create(dom.URL{ value: 'https://file-readers.test/window' })
	mut streams := browserjs.TransformStreamHost.create(document) or { panic(err) }
	streams.install(mut runtime) or { panic(err) }
	mut blobs := browserjs.BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	runtime.install_file_reader_binding() or { panic(err) }
	return runtime, document
}

fn file_reader_until(runtime &browserjs.Runtime, document &dom.Document, condition string) ! {
	mut loop := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.responsible_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	for runtime.evaluate_host(condition)! != 'true' && time.sys_mono_now() < deadline {
		loop.process()
	}
	assert runtime.evaluate_host(condition)! == 'true'
}

fn test_file_reader_window_keeps_native_events_decoding_and_stable_array_buffer_results() {
	mut runtime, mut document := file_reader_window()
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
globalThis.readers=[];globalThis.finished=0;globalThis.readerChecks=[];
class Derived extends FileReader{};const check=value=>readerChecks.push(value);
check(Object.getPrototypeOf(FileReader)===EventTarget&&new Derived() instanceof EventTarget);
check(FileReader.length===0&&FileReader.name==="FileReader"&&Object.prototype.toString.call(new FileReader())==="[object FileReader]");
check(FileReader.EMPTY===0&&FileReader.LOADING===1&&FileReader.DONE===2&&FileReader.prototype.DONE===2);
const handler=Object.getOwnPropertyDescriptor(FileReader.prototype,"onload");check(handler.get.name==="get onload"&&handler.set.name==="set onload"&&handler.get.length===0&&handler.set.length===1);
for(const [method,bytes,type,encoding,expected] of [
 ["readAsArrayBuffer",[0,128,255],"",undefined,"0,128,255"],
 ["readAsBinaryString",[0,128,255],"",undefined,"\x00\x80\xff"],
 ["readAsText",[255,254,65,0],"text/plain;charset=windows-1252","UTF-8","A"],
 ["readAsDataURL",[97],"text/plain",undefined,"data:text/plain;base64,YQ=="]]){
 const reader=new Derived(),events=[];readers.push(reader);
 check(reader.readyState===0&&reader.result===null&&reader.error===null);
 for(const name of ["loadstart","progress","load","loadend"])reader.addEventListener(name,function(event){
  check(this===reader&&event.target===reader&&event.currentTarget===reader&&!event.bubbles&&!event.cancelable);
  events.push(name);
 });
 reader.onloadstart=()=>check(reader.readyState===1&&reader.result===null);
 reader.onloadend=()=>{
  check(reader.readyState===2&&reader.error===null&&events.join()==="loadstart,progress,load,loadend");
  if(method==="readAsArrayBuffer"){
   const result=reader.result;check(result instanceof ArrayBuffer&&result===reader.result&&Array.from(new Uint8Array(result)).join()===expected);
   result.transfer();check(reader.result===result&&reader.result.byteLength===0);
   reader.onloadend=()=>{
    const next=reader.result;check(next!==result&&next===reader.result&&new Uint8Array(next)[0]===42);
    try{reader.readAsText({})}catch(error){check(error instanceof TypeError)}check(reader.result===next);finished++;
   };
   reader.readAsArrayBuffer(new Blob([new Uint8Array([42])]));check(reader.readyState===1&&reader.result===null);return;
  }else check(reader.result===expected);
  finished++;
 };
 const blob=new Blob([new Uint8Array(bytes)],{type});Object.defineProperty(blob,"type",{get(){throw Error("author type getter")}});
 check(reader[method](blob,encoding)===undefined&&reader.readyState===1&&events.length===0);
}
true
')! == 'true'
	file_reader_until(runtime, document, 'finished===4')!
	assert runtime.evaluate_host('readerChecks.length>30&&readerChecks.every(Boolean)&&typeof FileReaderSync==="undefined"')! == 'true'
}

fn test_file_reader_conversions_exceptions_abort_and_replacement_preserve_native_state() {
	mut runtime, mut document := file_reader_window()
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
globalThis.reader=new FileReader();globalThis.readerChecks=[];const check=value=>readerChecks.push(value);const blob=new Blob(["old"]);
let errors=0;for(const call of [()=>FileReader(),()=>new reader.abort(),()=>reader.readAsText(),()=>reader.readAsText({}),()=>reader.readAsText(new Proxy(blob,{})),()=>FileReader.prototype.abort.call({}),()=>reader.readAsText(blob,Symbol()),()=>Object.getOwnPropertyDescriptor(FileReader.prototype,"result").get.call({})])try{call()}catch(e){if(e instanceof TypeError)errors++}
check(errors===8&&reader.readyState===0&&reader.abort()===undefined&&reader.readyState===0);
reader.readAsArrayBuffer(blob);const marker={};let original=false;try{reader.readAsText(blob,{toString(){throw marker}})}catch(error){original=error===marker}check(original);
for(const method of ["readAsArrayBuffer","readAsBinaryString","readAsText","readAsDataURL"]){try{reader[method](blob);check(false)}catch(error){check(error instanceof DOMException&&error.name==="InvalidStateError"&&error.code===11)}}
reader.onabort=()=>check(reader.readyState===2&&reader.result===null&&reader.error===null);
reader.abort();check(reader.result===null);reader.readAsText(new Blob([new Uint8Array([128])],{type:"text/plain;charset=windows-1252"}));
globalThis.finished=false;reader.onloadend=()=>{check(reader.result==="€");reader.abort();check(reader.result===null&&reader.readyState===2);finished=true};true
')! == 'true'
	file_reader_until(runtime, document, 'finished')!
	assert runtime.evaluate_host('readerChecks.length===10&&readerChecks.every(Boolean)')! == 'true'
}

fn test_file_reader_reentrant_abort_before_loadstart_discards_the_previous_operation() {
	mut runtime, mut document := file_reader_window()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
globalThis.reader=new FileReader();globalThis.events=[];globalThis.results=[];
for(const name of ["abort","loadstart","load","loadend"])reader.addEventListener(name,()=>{events.push(name);if(name==="load")results.push(reader.result)});
reader.onabort=()=>reader.readAsText(new Blob(["second"]));reader.readAsText(new Blob(["first"]));reader.abort();
')!
	file_reader_until(runtime, document, 'events.includes("loadend")')!
	mut loop := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.responsible_event_loop()
	for _ in 0 .. 20 { loop.process() }
	assert runtime.evaluate_host('JSON.stringify([events,results])')! == '[["abort","loadstart","load","loadend"],["second"]]'
}

fn test_file_reader_async_worker_readers_use_the_actual_classic_module_and_shared_event_loops() {
	for shared in [false, true] {
		for module_ in [false, true] {
			mut agent := file_reader_agent(r'
const reader=new FileReader();reader.onload=()=>{if(!(reader instanceof EventTarget)||reader.result!=="worker"||reader.readyState!==2)throw Error("native worker reader");if(typeof postMessage==="function")postMessage("passed")};reader.readAsText(new Blob(["worker"]));
', module_, shared)!
			defer { agent.close() }
			agent.load_entry()!
			for _ in 0 .. 32 { agent.process() }
			assert agent.environment.settings.realm().reported_exceptions.len == 0
			if !shared {
				assert agent.take_outgoing().len == 1
			}
		}
	}
}

fn test_file_reader_close_cancels_pending_native_event_delivery() {
	mut runtime, mut document := file_reader_window()
	defer { document.finalize() }
	runtime.evaluate_host('globalThis.reader=new FileReader();reader.onload=()=>{throw Error("closed realm")};reader.readAsText(new Blob(["pending"]));')!
	runtime.close()
	mut loop := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.responsible_event_loop()
	for _ in 0 .. 12 { loop.process() }
}
