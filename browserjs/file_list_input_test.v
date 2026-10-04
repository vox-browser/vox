module browserjs

import dom
import fileapi
import html

fn source_input_file_list_runtime() (&Runtime, &dom.Document) {
	mut runtime := Runtime.create()
	document := dom.Document.create(dom.URL{'https://source-input-file-list.example.test/'})
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	files.install_constructor() or { panic(err) }
	mut lists := FileListHost.create(document) or { panic(err) }
	lists.install(mut runtime) or { panic(err) }
	lists.install_constructor() or { panic(err) }
	return runtime, document
}

fn test_source_actual_input_file_list_producer_preserves_live_native_owner_picker_identity_and_reset() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_input_file_list_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	element.set_attribute_value('type', 'file')
	element.set_attribute_value('multiple', '')
	input := unsafe { &dom.HTMLInputElement(element) }
	mut model := html.HTMLInputElementModel.create(input)
	empty := runtime.javascript_input_files(input)!
	assert empty == runtime.javascript_input_files(input)!
	assert voidptr(runtime.native_file_list(empty)!) == voidptr(model.file_list()?)
	assert runtime.native_file_list(empty)!.length() == 0
	model.did_select_files([html.SelectedFile.from_contents('one.txt', 'hello'.bytes())], .replace)
	first := runtime.javascript_input_files(input)!
	assert first != empty
	assert first == runtime.javascript_input_files(input)!
	actual_list := model.file_list()?
	assert voidptr(runtime.native_file_list(first)!) == voidptr(actual_list)
	file := actual_list.item(0)?
	runtime.define_value_host_function('__sourceInputFiles', fn [first] (_ voidptr, _ []voidptr) !voidptr {
		return first
	})!
	assert runtime.evaluate_host('__sourceInputFiles() instanceof FileList&&__sourceInputFiles().length===1&&__sourceInputFiles()[0] instanceof File&&__sourceInputFiles()[0].name==="one.txt"&&__sourceInputFiles()[0].type==="text/plain"')! == 'true'
	assert voidptr(runtime.native_file(runtime.evaluate_host_value('__sourceInputFiles()[0]')!)!) == voidptr(file)
	model.did_select_files([html.SelectedFile.from_contents('two.txt', 'second'.bytes())], .append)
	assert runtime.javascript_input_files(input)! == first
	assert runtime.evaluate_host('__sourceInputFiles().length===2&&__sourceInputFiles()[1].name==="two.txt"')! == 'true'
	assert voidptr(actual_list.item(0)?) == voidptr(file)
	model.did_select_files([], .replace)
	assert runtime.javascript_input_files(input)! == first
	assert model.event_count('cancel') == 1
	runtime.evaluate_host('globalThis.sourceInputTextPending=__sourceInputFiles()[0].text();globalThis.sourceInputTextDone=false;sourceInputTextPending.then(text=>sourceInputTextDone=text==="hello");')!
	assert runtime.evaluate_host('sourceInputTextPending instanceof Promise&&!sourceInputTextDone')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	})?
	assert task.document() == settings.responsible_document()
	task.execute()
	assert runtime.evaluate_host('sourceInputTextDone')! == 'true'
	model.reset()
	after_reset := runtime.javascript_input_files(input)!
	assert after_reset != first
	assert runtime.native_file_list(after_reset)!.length() == 0
	assert runtime.native_file_list(first)!.length() == 2
	model.set_type('text')
	null_value := runtime.javascript_input_files(input)!
	assert C.JSValueIsNull(runtime.context, null_value)
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_actual_input_nullable_file_list_conversion_uses_native_brand_before_model_applicability() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_input_file_list_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	element.set_attribute_value('type', 'file')
	input := unsafe { &dom.HTMLInputElement(element) }
	mut model := html.HTMLInputElementModel.create(input)
	mut list := fileapi.FileList.create()
	file := fileapi.File.create([u8(9)], 'actual.bin', 'application/octet-stream', -7)
	list.add_file(file)
	actual := runtime.javascript_file_list(list)!
	runtime.set_javascript_input_files(input, actual)!
	assert runtime.javascript_input_files(input)! == actual
	assert voidptr(model.file_list()?) == voidptr(list)
	for source in ['null', 'undefined'] {
		runtime.set_javascript_input_files(input, runtime.evaluate_host_value(source)!)!
		assert runtime.javascript_input_files(input)! == actual
	}
	assert model.event_count('input') == 0
	assert model.event_count('change') == 0
	for source in ['0', 'false', '"file"', 'new File(["x"],"fake")', 'Object.create(FileList.prototype)',
		'({length:1,0:new File(["x"],"fake")})'] {
		fake := runtime.evaluate_host_value(source)!
		runtime.define_value_host_function('__sourceInputFilesInvalid', fn [mut runtime, input, fake] (_ voidptr, _ []voidptr) !voidptr {
			runtime.set_javascript_input_files(input, fake)!
			return unsafe { nil }
		})!
		assert runtime.evaluate_host('{try{__sourceInputFilesInvalid();false}catch(reason){reason instanceof TypeError&&reason.message==="Not an object of type FileList"}}')! == 'true'
		assert runtime.javascript_input_files(input)! == actual
	}
	model.set_type('text')
	runtime.set_javascript_input_files(input, actual)!
	assert C.JSValueIsNull(runtime.context, runtime.javascript_input_files(input)!)
	fake := runtime.evaluate_host_value('Object.create(FileList.prototype)')!
	runtime.define_value_host_function('__sourceInputTextInvalidFiles', fn [mut runtime, input, fake] (_ voidptr, _ []voidptr) !voidptr {
		runtime.set_javascript_input_files(input, fake)!
		return unsafe { nil }
	})!
	assert runtime.evaluate_host('{try{__sourceInputTextInvalidFiles();false}catch(reason){reason instanceof TypeError&&reason.message==="Not an object of type FileList"}}')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}
