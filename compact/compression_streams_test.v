module main

import browserjs
import encoding.base64
import html
import x.json2

fn test_compact_compression_query_round_trips_each_format() {
	input := 'hello hello hello compression'.bytes()
	for format in ['deflate', 'deflate-raw', 'gzip'] {
		compressed := json2.decode[string](compact_compression_query(json2.encode({
			'kind':   json2.Any('compress')
			'format': json2.Any(format)
			'data':   json2.Any(base64.encode(input))
		}))!)!
		decompressed := json2.decode[string](compact_compression_query(json2.encode({
			'kind':   json2.Any('decompress')
			'format': json2.Any(format)
			'data':   json2.Any(compressed)
		}))!)!
		assert base64.decode(decompressed) == input, format
	}
	compact_compression_query('{"kind":"decompress","format":"gzip","data":"AQID"}') or {
		assert err.msg().starts_with('TypeError: ')
		return
	}
	assert false, 'corrupt gzip input was accepted'
}

fn test_compact_compression_streams_expose_transform_sides_and_validate_formats() {
	mut document := html.parse_document('<!doctype html><p></p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
for(const constructor of [CompressionStream,DecompressionStream]){
 const stream=new constructor("gzip");
 if(!(stream.readable instanceof ReadableStream)||!(stream.writable instanceof WritableStream)||stream.readable!==stream.readable)fail(constructor.name+" sides");
 let threw=false;try{new constructor("zip");}catch(error){threw=error instanceof TypeError;}
 if(!threw)fail(constructor.name+" invalid format");
 threw=false;try{constructor("gzip");}catch(error){threw=error instanceof TypeError;}
 if(!threw)fail(constructor.name+" without new");
}
console.log("compression passed");
'], runtime, mut messages)
	assert messages == ['compression passed']
}
