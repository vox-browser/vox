module browserjs

import dom
import fetch
import highresolutiontime
import html
import time

fn fetch_text_stream_fixture(worker bool) !(&Runtime, &FetchHost, &dom.Document) {
	url := dom.URL{value: 'https://body-text-stream.test/'}
	mut document := dom.Document.create(url)
	document.set_origin(url.origin())
	mut runtime := if worker { Runtime.create_for_worker() } else { Runtime.create() }
	mut settings := unsafe { &html.EnvironmentSettingsObject(nil) }
	if worker {
		mut realm := &html.ScriptingRealm{}
		scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
		environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
			html.SerializedEnvironmentSettingsObject{creation_url: url, api_base_url: url, origin: url.origin(),
				global: html.SerializedWorkerGlobalScope{relevant_settings_object_is_secure_context: true}},
			highresolutiontime.unsafe_shared_current_time())
		settings = environment.settings
		mut global := WorkerGlobalHost.create(environment)!
		global.install(mut runtime)!
	} else {
		window := html.WindowModel.create_top_level(document, none, 'text-stream')!
		settings = unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		assert voidptr(settings.global_object()) == voidptr(window)
	}
	mut readable := ReadableStreamHost.create_for_settings(settings)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create_for_settings(settings)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut abort := AbortSignalHost.create_for_settings(settings)!
	abort.install(mut runtime)!
	runtime.install_text_encoder_binding()!
	mut host := FetchHost.create_for_settings(settings, &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('textStream tests must not fetch') }
	})!
	host.install(mut runtime)!
	return runtime, host, document
}

fn fetch_text_stream_until(host &FetchHost, runtime &Runtime, expression string) {
	deadline := time.sys_mono_now() + 5 * time.second
	mut owner := host.settings.responsible_event_loop()
	owner.spin_until(fn [runtime, expression, deadline] () bool {
		return runtime.evaluate_host(expression) or { 'false' } == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host(expression) or { 'false' } == 'true', expression
}

// The fourteen assertions groups imported by f556fdc run against both native
// Window and Worker owners. No network or author TextDecoderStream is used.
fn test_fetch_text_stream_window_and_worker_body_contracts() {
	for worker in [false, true] {
		mut runtime, host, mut document := fetch_text_stream_fixture(worker)!
		runtime.evaluate_host(r'
globalThis.textStreamDone=false;globalThis.textStreamFailure=null;
const check=(value,label)=>{if(!value)throw new Error(label)};
const throws=call=>{try{call();return false}catch(error){return error instanceof TypeError}};
async function readText(stream){let text="",chunks=0;const reader=stream.getReader();for(;;){const item=await reader.read();if(item.done)return {text,chunks};check(typeof item.value==="string","string chunk");text+=item.value;chunks++}}
globalThis.TextDecoderStream=function(){throw new Error("author decoder")};
(async()=>{
 for(const prototype of [Request.prototype,Response.prototype]){
  const descriptor=Object.getOwnPropertyDescriptor(prototype,"textStream");
  check(descriptor.value.name==="textStream"&&descriptor.value.length===0&&descriptor.enumerable&&descriptor.writable&&descriptor.configurable,"method metadata");
  check(throws(()=>descriptor.value.call({})),"receiver brand");
 }
 for(const request of [false,true]){
  const make=(body,headers)=>request?new Request("https://example.test/",{method:"POST",body,headers}):new Response(body,{headers});
  const value=make("hello world");check(!value.bodyUsed,"fresh body");const decoded=value.textStream();
  check(decoded instanceof ReadableStream&&value.bodyUsed,"immediate body consumption");
  const result=await readText(decoded);check(result.text==="hello world"&&result.chunks>0,"body decoded");
  check(throws(()=>value.textStream()),"disturbed body throws synchronously");
  const consumed=make("used");consumed.text();check(throws(()=>consumed.textStream()),"consumed body");
  const locked=make("locked");locked.body.getReader();check(throws(()=>locked.textStream()),"locked body");
  const empty=request?new Request("https://example.test/"):new Response();
  const first=empty.textStream(),second=empty.textStream();
  check(first!==second&&first instanceof ReadableStream&&second instanceof ReadableStream&&!empty.bodyUsed,"null body fresh streams");
  check(throws(()=>first.getReader({mode:"byob"})),"null body is a default stream");
  check((await readText(first)).chunks===0&&(await readText(second)).chunks===0,"null body closed");
  const utf16=make(new Uint8Array([104,0,101,0,108,0,108,0,111,0]),{"Content-Type":"text/plain;charset=utf-16le"});
  check((await readText(utf16.textStream())).text==="h\0e\0l\0l\0o\0","MIME charset ignored");
 }
 const chunked=new Response(new ReadableStream({start(controller){controller.enqueue(new TextEncoder().encode("hello "));controller.enqueue(new TextEncoder().encode("world"));controller.close()}}));
 check((await readText(chunked.textStream())).text==="hello world","chunked input");
 const emptyBytes=new Response("");const emptyStream=emptyBytes.textStream();check(emptyBytes.bodyUsed&&(await readText(emptyStream)).chunks===0,"empty non-null body");
 const invalidCharset=new Response("hello",{headers:{"Content-Type":"text/plain;charset=invalid-charset"}});
 check((await readText(invalidCharset.textStream())).text==="hello","invalid MIME charset ignored");
 textStreamDone=true;
})().catch(error=>textStreamFailure=String(error));
')!
		fetch_text_stream_until(host, runtime, 'textStreamDone||textStreamFailure!==null')
		assert runtime.evaluate_host('textStreamFailure')! == 'null'
		runtime.close()
		document.finalize()
	}
}

fn test_fetch_text_stream_incremental_decoding_errors_and_cancellation() {
	mut runtime, host, mut document := fetch_text_stream_fixture(false)!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(r'
globalThis.incrementalDone=false;globalThis.incrementalFailure=null;
const check=(value,label)=>{if(!value)throw new Error(label)};
(async()=>{
 let controller;const source=new ReadableStream({start(value){controller=value}});
 const reader=new Response(source).textStream().getReader();
 for(const bytes of [[0xef],[0xbb,0xbf,0xe2],[0x82],[0xac]])controller.enqueue(new Uint8Array(bytes));
 const first=await reader.read();check(!first.done&&first.value==="€","split BOM and UTF-8 sequence before close");
 controller.enqueue(new Uint8Array([0xe2,0x82]));controller.close();
 const last=await reader.read();check(!last.done&&last.value==="�","incomplete sequence flushed");
 check((await reader.read()).done,"decoded stream closed");
 const marker={source:true};const failed=new Response(new ReadableStream({start(value){value.error(marker)}})).textStream();
 check((await failed.getReader().read().catch(error=>error))===marker,"source error identity");
 let canceled;const cancelMarker={stop:true};const cancelStream=new Response(new ReadableStream({cancel(reason){canceled=reason}})).textStream();
 await cancelStream.cancel(cancelMarker);check(canceled===cancelMarker,"cancellation propagated");
 let invalidCanceled;const invalid=new Response(new ReadableStream({start(value){value.enqueue("not bytes")},cancel(reason){invalidCanceled=reason}})).textStream();
 const bad=await invalid.getReader().read().catch(error=>error);check(bad instanceof TypeError,"invalid chunk TypeError");
 await Promise.resolve();check(invalidCanceled===bad,"cancel receives the same decoder error");
 incrementalDone=true;
})().catch(error=>incrementalFailure=String(error));
')!
	fetch_text_stream_until(host, runtime, 'incrementalDone||incrementalFailure!==null')
	assert runtime.evaluate_host('incrementalFailure')! == 'null'
}

fn test_fetch_text_stream_uses_the_receiver_realm_for_null_and_byte_bodies() {
	mut method_runtime, _, mut method_document := fetch_text_stream_fixture(false)!
	mut receiver_runtime, host, mut receiver_document := fetch_text_stream_fixture(false)!
	defer { method_runtime.close(); receiver_runtime.close(); method_document.finalize(); receiver_document.finalize() }
	method := method_runtime.evaluate_host_value('Response.prototype.textStream')!
	receiver_runtime.define_value_host_function('__otherTextStream', fn [method] (_ voidptr, _ []voidptr) !voidptr { return method })!
	receiver_runtime.evaluate_host(r'
globalThis.realmDone=false;globalThis.realmFailure=null;
(async()=>{
 for(const body of [null,"text"]){
  const receiver=new Response(body),stream=__otherTextStream().call(receiver);
  if(!(stream instanceof ReadableStream))throw new Error("wrong receiver realm");
  await stream.cancel();
 }
 realmDone=true;
})().catch(error=>realmFailure=String(error));
')!
	fetch_text_stream_until(host, receiver_runtime, 'realmDone||realmFailure!==null')
	assert receiver_runtime.evaluate_host('realmFailure')! == 'null'
}
