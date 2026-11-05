// Same-executable JavaScriptCore component. Runtime-loaded inputs prevent
// literal specialization; every result is checked against the original URL.
module main

import browserjs
import dom
import os
import platform
import processmetrics
import strconv
import x.json2

struct HrefTextInput {
	input string
	base string
}

struct HrefTextCase {
	name string
	inputs []HrefTextInput
	iterations int
}

fn main() {
	if os.args.len != 2 { panic('expected an href URL case manifest') }
	cases := json2.decode[[]HrefTextCase](os.read_file(os.args[1]) or { panic(err) }) or { panic(err) }
	for entry in cases {
		assert entry.inputs.len > 0 && entry.iterations > 0 && entry.iterations % 100 == 0
		mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
		mut document := dom.Document.create(dom.url_about_blank())
		mut params := browserjs.URLSearchParamsHost.create(document) or { panic(err) }
		params.install(mut runtime) or { panic(err) }
		mut urls := browserjs.URLHost.create(document) or { panic(err) }
		urls.install(mut runtime) or { panic(err) }
		_ = runtime.evaluate_host('globalThis.hrefInputs=' + json2.encode(entry.inputs) + r';
globalThis.hrefOriginal=function(value,base){try{return new URL(value,base).href;}catch(error){return value;}};
globalThis.hrefExpected=hrefInputs.map(value=>hrefOriginal(value.input,value.base));
globalThis.hrefRead=typeof __ladybirdSerializeURLText==="function"?function(value,base){const text=__ladybirdSerializeURLText(value,base);return typeof text==="string"?text:hrefOriginal(value,base);}:hrefOriginal;
globalThis.hrefOffset=0;') or { panic(err) }
		mut checksum := u64(0)
		before := processmetrics.instruction_snapshot()
		for _ in 0 .. entry.iterations / 100 {
			work := platform.begin_thread_scratch('href URL text batch')
			value := runtime.evaluate_host(r'(()=>{let sum=0;for(let i=0;i<100;i++){const index=hrefOffset++%hrefInputs.length,input=hrefInputs[index],actual=hrefRead(input.input,input.base);if(actual!==hrefExpected[index])throw new Error("href output mismatch");sum+=actual.length;}return sum;})()') or { panic(err) }
			checksum += strconv.parse_uint(value, 10, 64) or { panic(err) }
			work.finish()
		}
		instructions := processmetrics.instruction_snapshot().since(before) or { panic('instruction counter unavailable') }
		println(json2.encode({'scene':json2.Any(entry.name), 'instructions':json2.Any(instructions), 'iterations':json2.Any(entry.iterations), 'checksum':json2.Any(checksum)}))
		runtime.close()
		document.finalize()
	}
}
