module browserjs

import dom
import fileapi
import html
import libjs

fn execute_native_blob_owner_tasks(settings &html.EnvironmentSettingsObject) {
	mut queue := settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		task.execute()
	}
}

fn test_native_blob_wrapper_owns_actual_record_raw_attributes_and_source_read_methods() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://native-blob-source.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut host := BlobHost.create(document)!
	host.install(mut runtime)!
	blob := fileapi.Blob.create_utf16([u8(0xFF), 0xFE, 0x61, 0], libjs.utf16_string_from_code_units([
		u16(0xD800),
		0,
		0xDC00,
	]))
	actual := runtime.javascript_blob(blob)!
	assert voidptr(runtime.native_blob(actual)!) == voidptr(blob)
	assert runtime.javascript_blob(blob)! == actual
	runtime.define_value_host_function('__actualBlob', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('const blob=__actualBlob();globalThis.sourceBlob=blob;blob.size===4&&blob.type===String.fromCharCode(0xd800,0,0xdc00)&&Object.prototype.toString.call(blob)==="[object Blob]"')! == 'true'
	assert runtime.evaluate_host('globalThis.blobPending=[];globalThis.blobResults=[];for(const method of ["text","arrayBuffer","bytes"]){const first=sourceBlob[method](),second=sourceBlob[method]();blobPending.push(first instanceof Promise&&second instanceof Promise&&first!==second);first.then(value=>blobResults.push([method,value]))};globalThis.blobStream=sourceBlob.stream();globalThis.blobReader=blobStream.getReader();globalThis.blobChunks=[];blobReader.read().then(chunk=>blobChunks.push(chunk));blobPending.every(Boolean)&&blobResults.length===0&&blobChunks.length===0')! == 'true'
	execute_native_blob_owner_tasks(host.settings)
	assert runtime.evaluate_host('blobResults.length===3&&blobResults[0][1]===String.fromCharCode(0xfffd,0xfffd,97,0)&&blobResults[1][1] instanceof ArrayBuffer&&blobResults[2][1] instanceof Uint8Array&&Array.from(blobResults[2][1]).join(",")==="255,254,97,0"&&blobChunks.length===1&&blobChunks[0].value instanceof Uint8Array&&blobChunks[0].done===false')! == 'true'
	assert runtime.evaluate_host('sourceBlob.slice(-2.5,Infinity,"TeXT/PLAIN").size===2&&sourceBlob.slice(-2.5,Infinity,"TeXT/PLAIN").type==="text/plain"&&sourceBlob.slice(undefined,undefined,String.fromCharCode(0xd800)).type===""')! == 'true'
	assert runtime.evaluate_host('globalThis.blobReceiverErrors=[];const p=Object.getPrototypeOf(sourceBlob);for(const method of ["text","arrayBuffer","bytes"])p[method].call(Object.create(p)).catch(reason=>blobReceiverErrors.push(reason));let streamThrows=false;try{p.stream.call({})}catch(reason){streamThrows=reason instanceof TypeError};streamThrows')! == 'true'
	assert runtime.evaluate_host('blobReceiverErrors.length===3&&blobReceiverErrors.every(reason=>reason instanceof TypeError)')! == 'true'
	if _ := runtime.native_blob(runtime.evaluate_host_value('({__xhrBlobKey:1,size:4,type:"text/plain"})')!) {
		assert false
	}
}
