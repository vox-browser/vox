module browserjs

import dom

fn test_source_blob_constructor_installs_on_actual_global_independent_of_global_this_alias() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://source-blob-global.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut host := BlobHost.create(document)!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.__actualSourceBlobGlobal=globalThis;globalThis=new Proxy({},{defineProperty(){throw "author globalThis write"},get(){throw "author globalThis read"}});undefined')!
	host.install_constructor()!
	assert runtime.evaluate_host('typeof Blob==="function"&&__actualSourceBlobGlobal.Blob===Blob&&new Blob(["source"]).size===6&&Object.getOwnPropertyDescriptor(__actualSourceBlobGlobal,"Blob").writable')! == 'true'
}
