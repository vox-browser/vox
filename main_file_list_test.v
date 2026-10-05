module main

import browserjs
import dom
import html

fn test_native_document_file_list_interface_exposure_actual_input_producer_clone_and_owner_read() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<input id="upload" type="file" multiple><div id="result">pending</div>', dom.URL{value: 'https://native-document-file-list.example.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	input := unsafe { &dom.HTMLInputElement(document.get_element_by_id('upload')?) }
	mut model := html.HTMLInputElementModel.create(input)
	model.did_select_files([html.SelectedFile.from_contents('one.txt', 'hello'.bytes())], .replace)
	list := model.file_list()?
	file := list.item(0)?
	mut messages := []string{}
	run_document_script_sources(document, document.url.serialize(), [browserjs.ScriptSource{
		code: r'
globalThis.nativeFileListOriginal=FileList;
globalThis.nativeFileListInterfaceReady=typeof FileList==="function"&&FileList.name==="FileList"&&FileList.length===0&&FileList.prototype[Symbol.iterator]===Array.prototype.values;
try{new FileList();nativeFileListInterfaceReady=false}catch(reason){nativeFileListInterfaceReady=nativeFileListInterfaceReady&&reason instanceof TypeError&&reason.message==="FileList is not a constructor"}
'
	}], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('nativeFileListInterfaceReady')! == 'true'
	actual := runtime.javascript_input_files(input)!
	assert voidptr(runtime.native_file_list(actual)!) == voidptr(list)
	runtime.define_value_host_function('__nativeActualInputFiles', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.run_document_scripts_collect_errors([browserjs.ScriptSource{
		code: r'
globalThis.nativeDocumentInputFiles=__nativeActualInputFiles();
globalThis.nativeInputFileFirst=nativeDocumentInputFiles[0];
globalThis.nativeFileListTextDone=false;globalThis.nativeFileListTextErrors=[];
const sourceText=nativeInputFileFirst.text();
globalThis.nativeFileListTextPending=sourceText instanceof Promise;
sourceText.then(text=>{document.getElementById("result").textContent=text;nativeFileListTextDone=true},reason=>nativeFileListTextErrors.push(reason));
'
	}]) == []
	assert runtime.evaluate_host('nativeDocumentInputFiles instanceof nativeFileListOriginal&&nativeDocumentInputFiles.length===1&&nativeInputFileFirst instanceof File&&nativeInputFileFirst instanceof Blob&&nativeInputFileFirst.name==="one.txt"&&nativeInputFileFirst.type==="text/plain"&&nativeFileListTextPending&&!nativeFileListTextDone')! == 'true'
	assert voidptr(runtime.native_file(runtime.evaluate_host_value('nativeInputFileFirst')!)!) == voidptr(file)
	assert voidptr(runtime.native_blob(runtime.evaluate_host_value('nativeInputFileFirst')!)!) == voidptr(&file.Blob)
	model.did_select_files([html.SelectedFile.from_contents('two.txt', 'second'.bytes())], .append)
	assert runtime.javascript_input_files(input)! == actual
	assert runtime.evaluate_host('nativeDocumentInputFiles.length===2&&nativeDocumentInputFiles[0]===nativeInputFileFirst&&nativeDocumentInputFiles[1].name==="two.txt"')! == 'true'
	bridge := browserjs.StructuredCloneBridge.create(runtime)!
	cloned := bridge.clone(actual)!
	cloned_list := runtime.native_file_list(cloned)!
	assert voidptr(cloned_list) != voidptr(list)
	assert cloned_list.length() == 2
	assert voidptr(cloned_list.item(0)?) != voidptr(file)
	assert cloned_list.item(0)?.raw_bytes() == file.raw_bytes()
	runtime.define_value_host_function('__nativeInputFilesClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
		return cloned
	})!
	assert runtime.evaluate_host('__nativeInputFilesClone() instanceof nativeFileListOriginal&&__nativeInputFilesClone().length===2&&__nativeInputFilesClone()[0] instanceof File&&__nativeInputFilesClone()[0].name==="one.txt"')! == 'true'
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
	assert tasks == 1
	assert runtime.evaluate_host('nativeFileListTextDone&&nativeFileListTextErrors.length===0')! == 'true'
	mut app := BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.poll_javascript_tasks()
	assert app.js_messages == []
	assert document.get_element_by_id('result')?.text_content()? == 'hello'
	assert !runtime.libjs_vm().has_running_execution_context()
}
