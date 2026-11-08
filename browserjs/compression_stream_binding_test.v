module browserjs

import dom
import os

fn test_compression_binding_emits_before_close_and_errors_both_sides_on_extra_input() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://compression-binding.test/'}
	mut host := TransformStreamHost.create(&dom.Document{url: url, origin_: url.origin()})!
	host.install(mut runtime)!
	runtime.evaluate_host(r'
globalThis.compressionResults=[];globalThis.compressionErrors=[];
const vectors=[
 ["deflate",[120,156,75,173,40,72,77,46,73,77,81,200,47,45,41,40,45,1,0,48,173,6,36]],
 ["gzip",[31,139,8,0,0,0,0,0,0,3,75,173,40,72,77,46,73,77,81,200,47,45,41,40,45,1,0,176,1,57,179,15,0,0,0]],
 ["deflate-raw",[75,173,40,72,77,46,73,77,81,200,47,45,41,40,45,1,0]],
 ["brotli",[33,56,0,4,101,120,112,101,99,116,101,100,32,111,117,116,112,117,116,3]]
];
for(const [format,input] of vectors)(async()=>{
 const stream=new DecompressionStream(format),reader=stream.readable.getReader(),writer=stream.writable.getWriter();
 let writeFailed=false;const written=writer.write(new Uint8Array([...input,0]));written.catch(()=>{});
 const part=await reader.read();if(part.done||String.fromCharCode(...part.value)!=="expected output")throw new Error(format+" output");
 let readFailed=false;try{await reader.read()}catch(error){readFailed=error instanceof TypeError}
 await written.catch(error=>{writeFailed=error instanceof TypeError});
 if(!readFailed||!writeFailed)throw new Error(format+" terminal error");compressionResults.push(format);
})().catch(error=>compressionErrors.push(String(error)));
')!
	assert runtime.evaluate_host('compressionErrors.join("|")')! == ''
	assert runtime.evaluate_host('compressionResults.length')! == '4'
}

fn test_compression_binding_copies_internal_buffer_slots_and_cancels_codec_state() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://compression-binding.test/'}
	mut host := TransformStreamHost.create(&dom.Document{url: url, origin_: url.origin()})!
	host.install(mut runtime)!
	runtime.evaluate_host(r'
globalThis.compressionChecks=[];globalThis.compressionFailures=[];
(async()=>{
 const compressed=new CompressionStream("gzip"),writer=compressed.writable.getWriter(),reader=compressed.readable.getReader();
 const chunk=new Uint8Array([65,66,67]);Object.defineProperty(chunk,"buffer",{get(){throw new Error("author buffer getter")}});
 const first=reader.read();await writer.write(chunk);const header=await first;if(header.done||!header.value.length)throw new Error("incremental output");
 await reader.cancel();try{await writer.closed}catch(error){}compressionChecks.push("cancel");
 const broken=new DecompressionStream("deflate"),badReader=broken.readable.getReader(),badWriter=broken.writable.getWriter();
 const pending=badReader.read().catch(error=>error instanceof TypeError);badWriter.write("bytes").catch(()=>{});
 if(!await pending)throw new Error("buffer validation");compressionChecks.push("invalid chunk");
})().catch(error=>compressionFailures.push(String(error)));
')!
	assert runtime.evaluate_host('compressionFailures.join("|")')! == ''
	assert runtime.evaluate_host('compressionChecks.join("|")')! == 'cancel|invalid chunk'
	owner := voidptr(runtime)
	binding := compression_bindings_[owner] or { panic('missing compression binding') }
	assert binding.records.len == 0
}

// Optional external integration check; execute the pinned upstream assertions
// through the stock shell harness and the actual native stream bindings.
fn test_upstream_decompression_extra_input() {
	root := os.getenv('VOX_PINNED_WPT_ROOT')
	if root == '' { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://compression-upstream.test/compression/decompression-extra-input.any.html'}
	mut host := TransformStreamHost.create(&dom.Document{url: url, origin_: url.origin()})!
	host.install(mut runtime)!
	runtime.install_text_encoder_binding()!
	runtime.evaluate_host('globalThis.self=globalThis;globalThis.nativeWptResult=null;')!
	runtime.evaluate_host(os.read_file(os.join_path(root, 'resources/testharness.js'))!)!
	runtime.evaluate_host('setup({output:false,explicit_done:true});add_completion_callback((tests,status)=>{globalThis.nativeWptResult={harness:status.status,tests:tests.map(t=>({name:t.name,status:t.status,message:t.message}))}});')!
	for source in ['compression/resources/decompression-input.js', 'compression/decompression-extra-input.any.js'] {
		runtime.evaluate_host(os.read_file(os.join_path(root, source))!)!
	}
	runtime.evaluate_host('done()')!
	for turn in 0 .. 1000 {
		runtime.evaluate_host('void 0')!
		if runtime.evaluate_host('nativeWptResult!==null')! == 'true' { break }
		assert turn < 999, 'upstream harness did not finish'
	}
	result := runtime.evaluate_host('JSON.stringify(nativeWptResult)')!
	if output := os.getenv_opt('VOX_COMPRESSION_WPT_RESULT') { os.write_file(output, result)! }
	println(result)
	assert runtime.evaluate_host('nativeWptResult.harness===0&&nativeWptResult.tests.length===4&&nativeWptResult.tests.every(t=>t.status===0)')! == 'true', result
}
