module main

import browserjs
import dom
import html

fn test_native_document_file_bindings_preserve_actual_blob_base_pending_reads_clone_and_dom_replay() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<div id="result">pending</div>', dom.URL{value: 'https://native-document-file.example.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_script_sources(document, document.url.serialize(), [browserjs.ScriptSource{
		code: r'
globalThis.nativeDocumentFile=new File(["A",new Uint8Array([66])],"source/"+String.fromCharCode(0xd800)+".txt",{type:"TEXT/PLAIN",lastModified:3});
globalThis.nativeFileDone=false;globalThis.nativeFileErrors=[];
const text=nativeDocumentFile.text(),bytes=nativeDocumentFile.bytes(),buffer=nativeDocumentFile.arrayBuffer();
globalThis.nativeFilePending=text instanceof Promise&&bytes instanceof Promise&&buffer instanceof Promise&&text!==bytes&&bytes!==buffer;
Promise.all([text,bytes,buffer]).then(values=>{
 globalThis.nativeFileResults=values;
 document.getElementById("result").textContent=values[0]==="AB"&&values[1] instanceof Uint8Array&&values[2] instanceof ArrayBuffer&&values[1][1]===66&&new Uint8Array(values[2])[0]===65?"source File":"wrong File";
 nativeFileDone=true;
},reason=>nativeFileErrors.push(reason));
'
	}], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('nativeFilePending&&!nativeFileDone&&nativeDocumentFile instanceof File&&nativeDocumentFile instanceof Blob&&nativeDocumentFile.type==="text/plain"&&nativeDocumentFile.lastModified===3&&nativeDocumentFile.name==="source/�.txt"')! == 'true'
	assert document.get_element_by_id('result')?.text_content()? == 'pending'
	actual := runtime.evaluate_host_value('nativeDocumentFile')!
	file := runtime.native_file(actual)!
	assert file.raw_bytes() == [u8(65), 66]
	assert file.name() == 'source/�.txt'
	assert voidptr(runtime.native_blob(actual)!) == voidptr(&file.Blob)
	bridge := browserjs.StructuredCloneBridge.create(runtime)!
	cloned := bridge.clone(actual)!
	assert voidptr(runtime.native_file(cloned)!) != voidptr(file)
	assert runtime.native_file(cloned)!.raw_bytes() == file.raw_bytes()
	assert runtime.native_file(cloned)!.name() == file.name()
	runtime.define_value_host_function('__nativeDocumentFileClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
		return cloned
	})!
	assert runtime.evaluate_host('__nativeDocumentFileClone() instanceof File&&__nativeDocumentFileClone() instanceof Blob&&__nativeDocumentFileClone().lastModified===3')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	mut tasks := 0
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		assert task.document() == settings.responsible_document()
		task.execute()
		tasks++
	}
	assert tasks == 3
	assert runtime.evaluate_host('nativeFileDone&&nativeFileErrors.length===0&&nativeFileResults[1].buffer!==nativeFileResults[2]')! == 'true'
	mut app := BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.poll_javascript_tasks()
	assert app.js_messages == []
	assert document.get_element_by_id('result')?.text_content()? == 'source File'
	assert !runtime.libjs_vm().has_running_execution_context()
}
