module browserjs

import dom

fn test_native_stream_interface_tags_inherit_source_prototypes_and_original_getter_exceptions() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://native-stream-tag.example.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut writable := WritableStreamHost.create(document)!
	writable.install(mut runtime)!
	mut transform := TransformStreamHost.create(document)!
	transform.install(mut runtime)!
	assert runtime.evaluate_host(r'{let readableController,writableController,transformController;const readable=new ReadableStream({start(controller){readableController=controller}});const reader=readable.getReader();const writable=new WritableStream({start(controller){writableController=controller}});const writer=writable.getWriter();const transform=new TransformStream({start(controller){transformController=controller}});const entries=[[readable,"ReadableStream"],[reader,"ReadableStreamDefaultReader"],[readableController,"ReadableStreamDefaultController"],[writable,"WritableStream"],[writer,"WritableStreamDefaultWriter"],[writableController,"WritableStreamDefaultController"],[transform,"TransformStream"],[transformController,"TransformStreamDefaultController"]];entries.every(([value,name])=>Object.prototype.toString.call(value)==="[object "+name+"]"&&Object.getOwnPropertyDescriptor(value,Symbol.toStringTag)===undefined&&Object.getPrototypeOf(value)[Symbol.toStringTag]===name)}')! == 'true'
	assert runtime.evaluate_host(r'{const stream=new ReadableStream();const reason=Symbol("actual tag getter");Object.defineProperty(stream,Symbol.toStringTag,{get(){throw reason},configurable:true});let original=false;try{Object.prototype.toString.call(stream)}catch(error){original=error===reason}delete stream[Symbol.toStringTag];Object.setPrototypeOf(stream,{[Symbol.toStringTag]:"Custom"});original&&Object.prototype.toString.call(stream)==="[object Custom]"}')! == 'true'
	assert runtime.evaluate_host(r'{let brands=0;for(const [Constructor,name] of [[ReadableStream,"locked"],[WritableStream,"locked"],[TransformStream,"readable"]]){const forged=Object.create(Constructor.prototype);const getter=Object.getOwnPropertyDescriptor(Constructor.prototype,name).get;try{getter.call(forged)}catch(error){if(error instanceof TypeError)brands++}}brands===3}')! == 'true'
	actual := runtime.evaluate_host_value('new ReadableStream()')!
	assert runtime.native_stream_wrapper_record(actual) != unsafe { nil }
	assert runtime.native_stream_wrapper_records_.len > 0
	runtime.close()
	assert runtime.native_stream_wrapper_records_.len == 0
	assert runtime.native_stream_wrapper_record(actual) == unsafe { nil }
	if _ := runtime.make_native_stream_wrapper(unsafe { nil }) { assert false } else {
		assert err.msg().contains('closed')
	}
}
