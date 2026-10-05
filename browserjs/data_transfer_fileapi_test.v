module browserjs

import dom
import fileapi
import html
import libjs

fn source_data_transfer_fileapi_runtime() (&Runtime, &dom.Document) {
	mut runtime := Runtime.create()
	document := dom.Document.create(dom.URL{value: 'https://source-drag-files.example.test/'})
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

fn test_source_actual_drag_file_producers_wrap_fresh_genuine_records_with_raw_utf16_and_owner_tasks() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_data_transfer_fileapi_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00])
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'), 'hello'.bytes(), name))
	mut transfer := html.DataTransfer.create(store)
	item := transfer.item(0)
	first := runtime.javascript_data_transfer_files(transfer)!
	second := runtime.javascript_data_transfer_files(transfer)!
	assert first != second
	first_owner := runtime.native_file_list(first)!
	second_owner := runtime.native_file_list(second)!
	assert voidptr(first_owner) != voidptr(second_owner)
	assert voidptr(first_owner.item(0)?) != voidptr(second_owner.item(0)?)
	file_value := runtime.javascript_data_transfer_item_file(item)!
	file_owner := runtime.native_file(file_value)!
	assert voidptr(file_owner) != voidptr(first_owner.item(0)?)
	assert file_owner.name_utf16().code_units() == name.code_units()
	assert voidptr(runtime.native_blob(file_value)!) == voidptr(&file_owner.Blob)
	runtime.define_value_host_function('__sourceDragFiles', fn [first] (_ voidptr, _ []voidptr) !voidptr {
		return first
	})!
	runtime.define_value_host_function('__sourceDragItemFile', fn [file_value] (_ voidptr, _ []voidptr) !voidptr {
		return file_value
	})!
	assert runtime.evaluate_host('const sourceDragList=__sourceDragFiles();sourceDragList instanceof FileList&&sourceDragList.length===1&&sourceDragList[0] instanceof File&&sourceDragList[0]!==__sourceDragItemFile()&&sourceDragList[0].name.charCodeAt(1)===0xd800&&sourceDragList[0].name.charCodeAt(2)===0&&sourceDragList[0].name.charCodeAt(3)===0xdc00&&sourceDragList[0].type==="text/plain"')! == 'true'
	runtime.evaluate_host('globalThis.sourceDragDone=false;globalThis.sourceDragPromise=__sourceDragItemFile().text();sourceDragPromise.then(text=>sourceDragDone=text==="hello");')!
	assert runtime.evaluate_host('sourceDragPromise instanceof Promise&&!sourceDragDone')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	})?
	assert task.document() == settings.responsible_document()
	task.execute()
	assert runtime.evaluate_host('sourceDragDone')! == 'true'
	store.set_mode(.protected)
	empty := runtime.javascript_data_transfer_files(transfer)!
	assert runtime.native_file_list(empty)!.length() == 0
	assert C.JSValueIsNull(runtime.context, runtime.javascript_data_transfer_item_file(item)!)
	assert runtime.native_file_list(first)!.length() == 1
	store.set_mode(.read_only)
	assert runtime.native_file_list(runtime.javascript_data_transfer_files(transfer)!)!.length() == 1
	assert !C.JSValueIsNull(runtime.context, runtime.javascript_data_transfer_item_file(item)!)
	transfer.disassociate_with_drag_data_store()
	assert runtime.native_file_list(runtime.javascript_data_transfer_files(transfer)!)!.length() == 0
	assert C.JSValueIsNull(runtime.context, runtime.javascript_data_transfer_item_file(item)!)
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_actual_drag_add_file_uses_native_brand_slots_before_mode_and_ignores_author_properties() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_data_transfer_fileapi_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut transfer := html.DataTransfer.construct()
	mut items := transfer.items()
	actual_file := fileapi.File.create_utf16('original'.bytes(),
		libjs.utf16_string_from_code_units([u16(0xdfff), 0]), libjs.utf16_string('TEXT/PLAIN'), -7)
	input := runtime.javascript_file(actual_file)!
	runtime.define_value_host_function('__sourceDragInputFile', fn [input] (_ voidptr, _ []voidptr) !voidptr {
		return input
	})!
	runtime.evaluate_host('const sourceDragPoison={};for(const key of ["name","type","lastModified","size"]){Object.defineProperty(__sourceDragInputFile(),key,{get(){throw sourceDragPoison}})}globalThis.Blob=function(){throw sourceDragPoison};globalThis.File=function(){throw sourceDragPoison};globalThis.FileList=function(){throw sourceDragPoison};0;')!
	added := runtime.add_javascript_data_transfer_file(mut items, input)!.item?
	stored := transfer.drag_data(0)
	assert stored.file_name_utf16().code_units() == [u16(0xdfff), 0]
	assert stored.type_utf16().str() == 'text/plain'
	assert stored.data == 'original'.bytes()
	output := runtime.javascript_data_transfer_item_file(added)!
	assert output != input
	assert voidptr(runtime.native_file(output)!) != voidptr(actual_file)
	assert runtime.native_file(output)!.name_utf16().code_units() == [u16(0xdfff), 0]
	assert runtime.native_file(output)!.last_modified() != -7
	store := transfer.drag_data(0)
	assert store.data == 'original'.bytes()
	mut protected_store := html.DragDataStore.create()
	mut protected_transfer := html.DataTransfer.create(protected_store)
	mut protected_items := protected_transfer.items()
	assert runtime.add_javascript_data_transfer_file(mut protected_items, input)!.item == none
	for source in ['null', 'undefined', '1', '({name:"fake",type:"text/plain"})',
		'Object.create(Object.getPrototypeOf(__sourceDragInputFile()))'] {
		fake := runtime.evaluate_host_value(source)!
		runtime.define_value_host_function('__sourceDragInvalidFile', fn [mut runtime, mut protected_items, fake] (_ voidptr, _ []voidptr) !voidptr {
			_ := runtime.add_javascript_data_transfer_file(mut protected_items, fake)!
			return unsafe { nil }
		})!
		assert runtime.evaluate_host('{try{__sourceDragInvalidFile();false}catch(reason){reason instanceof TypeError&&reason.message==="Not an object of type File"}}')! == 'true'
	}
	assert protected_transfer.length() == 0
	items.remove(0)!
	assert C.JSValueIsNull(runtime.context, runtime.javascript_data_transfer_item_file(added)!)
	assert !runtime.libjs_vm().has_running_execution_context()
}
