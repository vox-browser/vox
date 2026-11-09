module main

import browserjs
import dom
import html

fn create_cross_realm_blob_runtime(address string) !(&browserjs.Runtime, &dom.Document) {
	mut runtime := browserjs.Runtime.create()
	url := dom.URL{value: address}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut readable := browserjs.ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := browserjs.BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	return runtime, document
}

fn cross_realm_blob_tasks() {
	mut queue := html.main_thread_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		task.execute()
	}
}

fn test_blob_borrowed_methods_keep_the_receivers_realm_and_conversion_exceptions() {
	mut receiver, mut document := create_cross_realm_blob_runtime('https://blob-receiver.example/')!
	mut foreign, mut foreign_document := create_cross_realm_blob_runtime('https://blob-method.example/')!
	defer { foreign.close(); receiver.close(); foreign_document.finalize(); document.finalize() }
	prototype := foreign.evaluate_host_value('Blob.prototype')!
	foreign_type_error := foreign.evaluate_host_value('TypeError')!
	receiver.define_value_host_function('__foreignBlobPrototype', fn [prototype] (_ voidptr, _ []voidptr) !voidptr { return prototype })!
	receiver.define_value_host_function('__foreignBlobTypeError', fn [foreign_type_error] (_ voidptr, _ []voidptr) !voidptr { return foreign_type_error })!
	receiver.evaluate_host('globalThis.foreignPrototype=__foreignBlobPrototype();globalThis.foreignTypeError=__foreignBlobTypeError();undefined')!
	foreign.close()
	assert receiver.evaluate_host(r'(()=>{
 const prototype=foreignPrototype,blob=new Blob(["foobar"]);
 const sliced=prototype.slice.call(blob,1,3);
 if(!(sliced instanceof Blob)||sliced.size!==2)throw Error("slice receiver realm");
 if(Object.getOwnPropertyDescriptor(prototype,"size").get.call(blob)!==6)throw Error("foreign size getter");
 const marker={};let caught;try{prototype.slice.call(blob,{valueOf(){throw marker}})}catch(error){caught=error}
 if(caught!==marker)throw Error("conversion exception identity");
 for(const args of [[1n],[0,1n],[0,1,Symbol()]]){let reason;try{prototype.slice.call(blob,...args)}catch(error){reason=error}if(!(reason instanceof foreignTypeError))throw Error("conversion exception realm")}
 const order=[];prototype.slice.call(blob,{valueOf(){order.push("start");return 1}},{valueOf(){order.push("end");return 3}},{toString(){order.push("type");return "TEXT/PLAIN"}});
 if(order.join(",")!=="start,end,type")throw Error("conversion order");
 let reads=0;const fake=Object.create(Blob.prototype),proxy=new Proxy(blob,{get(){reads++;throw Error("proxy trap")}});
 for(const value of [fake,proxy,{},null]){let error;try{prototype.stream.call(value)}catch(reason){error=reason}if(!(error instanceof foreignTypeError))throw Error("foreign receiver brand")}
 if(reads)throw Error("receiver brand observed author code");
 let conversions=0,error;try{prototype.slice.call(fake,{valueOf(){conversions++;throw marker}})}catch(reason){error=reason}
 if(conversions||!(error instanceof foreignTypeError))throw Error("brand must precede argument conversion");
 globalThis.borrowedBlobBrandErrors=[];
 for(const name of ["text","arrayBuffer","bytes"])prototype[name].call(fake).catch(reason=>borrowedBlobBrandErrors.push(reason));
 globalThis.borrowedBlobResults={};
 for(const name of ["text","arrayBuffer","bytes"]){const promise=prototype[name].call(sliced);if(!(promise instanceof Promise))throw Error("promise receiver realm");promise.then(value=>borrowedBlobResults[name]=value);}
 const stream=prototype.stream.call(sliced);if(!(stream instanceof ReadableStream))throw Error("stream receiver realm");
 stream.getReader().read().then(value=>borrowedBlobResults.stream=value);
 return Object.keys(borrowedBlobResults).length===0;
})()')! == 'true'
	cross_realm_blob_tasks()
	assert receiver.evaluate_host('Object.keys(borrowedBlobResults).length===4&&borrowedBlobResults.text==="oo"&&borrowedBlobResults.arrayBuffer instanceof ArrayBuffer&&borrowedBlobResults.bytes instanceof Uint8Array&&Array.from(borrowedBlobResults.bytes).join(",")==="111,111"&&borrowedBlobResults.stream.value instanceof Uint8Array&&!borrowedBlobResults.stream.done&&Array.from(borrowedBlobResults.stream.value).join(",")==="111,111"')! == 'true'
	assert receiver.evaluate_host('borrowedBlobBrandErrors.length===3&&borrowedBlobBrandErrors.every(reason=>reason instanceof foreignTypeError)')! == 'true'
}

fn test_blob_native_identity_and_constructor_parts_accept_genuine_foreign_blobs() {
	mut receiver, mut document := create_cross_realm_blob_runtime('https://blob-copy.example/')!
	mut foreign, mut foreign_document := create_cross_realm_blob_runtime('https://blob-source.example/')!
	defer { foreign.close(); receiver.close(); foreign_document.finalize(); document.finalize() }
	value := foreign.evaluate_host_value('globalThis.foreignBlob=new Blob(["foreign bytes"]);foreignBlob')!
	actual := foreign.native_blob(value)!
	assert voidptr(receiver.native_blob(value)!) == voidptr(actual)
	receiver.define_value_host_function('__foreignBlob', fn [value] (_ voidptr, _ []voidptr) !voidptr { return value })!
	assert receiver.evaluate_host('globalThis.foreignReference=__foreignBlob();globalThis.copiedBlob=new Blob(["prefix ",foreignReference]);globalThis.copiedText=null;copiedBlob.text().then(value=>copiedText=value);copiedBlob instanceof Blob&&copiedBlob.size===20')! == 'true'
	cross_realm_blob_tasks()
	assert receiver.evaluate_host('copiedText==="prefix foreign bytes"')! == 'true'
	foreign.close()
	if _ := receiver.native_blob(value) { assert false, 'closed realms must leave the shared Blob lookup' }
	assert receiver.evaluate_host('copiedBlob.size')! == '20'
	receiver.evaluate_host('copiedText=null;copiedBlob.text().then(value=>copiedText=value);undefined')!
	cross_realm_blob_tasks()
	assert receiver.evaluate_host('copiedText==="prefix foreign bytes"')! == 'true'
}
