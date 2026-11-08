module browserjs

import dom
import html

fn test_blob_text_stream_binding_uses_native_utf8_pipeline_and_checks_receivers() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://blob-text-stream.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	assert runtime.evaluate_host(r'
const descriptor=Object.getOwnPropertyDescriptor(Blob.prototype,"textStream"),method=descriptor.value;
if(method.name!=="textStream"||method.length!==0||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("metadata");
let rejected=false;try{method.call({})}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("receiver");
globalThis.textStreamResults=[];globalThis.textStreamErrors=[];
const cases=[
 [new Blob(["hello ","world"]),"hello world"],
 [new Blob(),""],
 [new Blob([new Uint8Array([104,0,105,0])],{type:"text/plain;charset=utf-16le"}),"h\0i\0"],
 [new Blob([new Uint8Array([0xef,0xbb,0xbf,0xc3,0xa9])]),"é"],
 [new Blob([new Uint8Array([0xff,0xfe,97,0])]),"\ufffd\ufffda\0"],
 [new Blob([new Uint8Array([65,0xc3])]),"A\ufffd"],
 [new Blob([new Uint8Array([0xef,0xbb,0xbf])]),""],
 [new Blob([new Uint8Array([0xef,0xbb,0xbf,0xef,0xbb,0xbf,80])]),"\ufeffP"]
];
const NativeReadableStream=ReadableStream;
globalThis.TextDecoderStream=function(){throw new Error("author decoder")};
for(const [blob,expected] of cases){
 const first=blob.textStream(),second=blob.textStream();
 if(first===second||!(first instanceof NativeReadableStream))throw new Error("stream identity");
 const reader=first.getReader();
 (async()=>{let text="";for(;;){const part=await reader.read();if(part.done)break;if(typeof part.value!=="string")throw new Error("chunk");text+=part.value}if(text!==expected)throw new Error("decoded "+JSON.stringify(text));textStreamResults.push(text)})().catch(error=>textStreamErrors.push(String(error)));
 second.cancel();
}
textStreamResults.length===0&&textStreamErrors.length===0
')! == 'true'
	mut queue := readable.settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		task.execute()
	}
	mut owner := unsafe { &html.EventLoop(readable.settings.responsible_event_loop()) }
	owner.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('textStreamErrors.join("|")')! == ''
	assert runtime.evaluate_host('textStreamResults.length')! == '8'
}
