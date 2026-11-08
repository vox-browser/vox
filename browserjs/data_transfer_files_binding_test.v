module browserjs

import dom
import html
import libjs
import time

fn files_native_document(url string) &dom.Document {
	document := html.parse_document_with_url('<!doctype html><body>Native transfer files</body>',
		dom.URL{ value: url })
	_ = html.WindowModel.create_top_level(document, none, 'native-transfer-files') or { panic(err) }
	return document
}

fn files_native_fixture(url string) (&Runtime, &dom.Document) {
	document := files_native_document(url)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, document
}

fn files_native_install(mut runtime Runtime, document &dom.Document) !&FileListHost {
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := FileHost.create(document)!
	files.install(mut runtime)!
	files.install_constructor()!
	mut lists := FileListHost.create(document)!
	lists.install(mut runtime)!
	lists.install_constructor()!
	return lists
}

fn files_native_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('typeof DataTransfer==="function"&&(()=>{const d=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"files");return !!d&&typeof d.get==="function"})()')! == 'true'
}

fn files_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn files_native_assert_vm(runtime &Runtime) {
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

// The public getter preserves its SameObject identity and live native files.
fn test_native_data_transfer_files_descriptor_and_receiver_brand_before_host_dependency() {
	$if !darwin { return }
	mut runtime, mut document := files_native_fixture('https://transfer-files-metadata.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert files_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=DataTransfer.prototype,d=Object.getOwnPropertyDescriptor(p,"files"),get=d.get,t=new DataTransfer(),marker={},extra={[Symbol.toPrimitive](){conversions++;throw marker}};let traps=0,conversions=0;
 check(d.set===undefined&&d.enumerable&&d.configurable&&get.name==="get files"&&get.length===0&&Function.prototype.toString.call(get).includes("[native code]")&&!Object.hasOwn(get,"prototype")&&!Object.hasOwn(t,"files")&&!Reflect.set(t,"files",[]),"native readonly descriptor");let nonconstructor=false;try{Reflect.construct(function Empty(){},[],get)}catch(error){nonconstructor=error instanceof TypeError}check(nonconstructor,"getter is not a constructor");
 const proxy=new Proxy(t,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker},has(){traps++;throw marker}});for(const receiver of [proxy,Object.create(p),{},[],new Event("event"),new DragEvent("drag"),null,undefined,1,true,"transfer",1n,Symbol("transfer")]){let rejected=false;try{get.call(receiver,extra)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransfer"}check(rejected,"native brand before unavailable FileAPI owner")}
 let missing=false;try{get.call(t,extra)}catch(error){missing=error.message==="FileList binding is unavailable"}check(missing&&traps===0&&conversions===0,"genuine receiver reaches dependency, getter ignores extras");globalThis.filesMetadataTransfer=t;globalThis.filesMetadataGetter=get;return true;
})()')! == 'true'
	host := files_native_install(mut runtime, document)!
	assert runtime.evaluate_host(r'(()=>{
 const t=filesMetadataTransfer,first=t.files,second=filesMetadataGetter.call(t,{toString(){throw 0}});class Child extends DataTransfer{}const child=new Child();
 return first===second&&first instanceof FileList&&second instanceof FileList&&Object.getPrototypeOf(first)===FileList.prototype&&first.length===0&&second.length===0&&first[0]===undefined&&first.item(0)===null&&Object.prototype.toString.call(first)==="[object FileList]"&&child.files instanceof FileList&&child.files===child.files&&Object.getOwnPropertyDescriptor(DataTransfer.prototype,"files").get===filesMetadataGetter;
})()')! == 'true'
	assert !host.closed && host.records.len >= 2
	assert runtime.native_file_list(runtime.evaluate_host_value('filesMetadataTransfer.files')!)!.length() == 0
	files_native_assert_vm(runtime)
}

fn test_native_data_transfer_files_stable_actual_file_owners_utf16_payload_and_read_tasks() {
	$if !darwin { return }
	mut runtime, mut document := files_native_fixture('https://transfer-files-payload.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert files_native_guard(runtime)!
	_ = files_native_install(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string('not a file')))
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00])
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		[u8(0), 128, 255], name))
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string_from_code_units([
		u16(`x`), 0xd800,
	]), 'second payload'.bytes(), libjs.utf16_string('second.bin')))
	transfer := html.DataTransfer.create(store)
	wrapper := runtime.javascript_data_transfer(transfer)!
	files_native_export(mut runtime, '__filesPayloadTransfer', wrapper)!
	before := time.now().unix_milli()
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=__filesPayloadTransfer(),first=t.files,second=t.files,one=first[0],two=first[1];
 check(first===second&&first.length===2&&second.length===2&&first.item(0)===one&&first.item(1)===two&&first[2]===undefined&&first.item(2)===null&&one===second[0]&&two===second[1]&&one instanceof File&&one instanceof Blob&&Object.getPrototypeOf(one)===File.prototype&&Object.getPrototypeOf(File.prototype)===Blob.prototype,"stable native list/file owners and inherited Blob");
 check(one.name==="n\ud800\u0000\udc00😀"&&one.type==="text/plain"&&one.size===3&&two.name==="second.bin"&&two.type===""&&two.size===14&&Number.isInteger(one.lastModified)&&[...first][0]===one&&[...first][1]===two&&Reflect.ownKeys(first).join(",")==="0,1","raw UTF16 name, source MIME normalization and legacy indices");
 globalThis.filesPayloadFirst=first;globalThis.filesPayloadSecond=second;globalThis.filesPayloadBytesDone=false;globalThis.filesPayloadPromise=one.bytes();filesPayloadPromise.then(view=>filesPayloadBytesDone=view instanceof Uint8Array&&view.length===3&&view[0]===0&&view[1]===128&&view[2]===255);return filesPayloadPromise instanceof Promise&&!filesPayloadBytesDone;
})()')! == 'true'
	after := time.now().unix_milli()
	first_value := runtime.evaluate_host_value('filesPayloadFirst')!
	second_value := runtime.evaluate_host_value('filesPayloadSecond')!
	first := runtime.native_file_list(first_value)!
	second := runtime.native_file_list(second_value)!
	assert voidptr(first) == voidptr(second) && first.length() == 2
	one := first.item(0)?
	assert voidptr(one) == voidptr(second.item(0)?)
	assert one.raw_bytes() == [u8(0), 128, 255] && one.name_utf16().code_units() == name.code_units()
	assert one.type_() == 'text/plain' && first.item(1)?.type_() == ''
	assert one.last_modified() >= before && one.last_modified() <= after
	one_wrapper := runtime.evaluate_host_value('filesPayloadFirst[0]')!
	assert voidptr(runtime.native_file(one_wrapper)!) == voidptr(one)
	assert voidptr(runtime.native_blob(one_wrapper)!) == voidptr(&one.Blob)
	assert runtime.javascript_file(one)! == one_wrapper
	assert runtime.javascript_file_list(first)! == first_value
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	})?
	assert task.document() == settings.responsible_document()
	task.execute()
	assert runtime.evaluate_host('filesPayloadBytesDone')! == 'true'
	assert voidptr(runtime.native_data_transfer(wrapper)!) == voidptr(transfer)
	files_native_assert_vm(runtime)
}

fn test_native_data_transfer_files_reads_follow_native_modes_and_preserve_saved_file_objects() {
	$if !darwin { return }
	mut runtime, mut document := files_native_fixture('https://transfer-files-modes.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert files_native_guard(runtime)!
	_ = files_native_install(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('application/octet-stream'),
		[u8(1), 2], libjs.utf16_string('original.bin')))
	mut transfer := html.DataTransfer.create(store)
	files_native_export(mut runtime, '__filesModeTransfer', runtime.javascript_data_transfer(transfer)!)!
	assert runtime.evaluate_host('globalThis.filesModeOld=__filesModeTransfer().files;globalThis.filesModeOriginal=filesModeOld[0];filesModeOld.length===1&&filesModeOriginal.name==="original.bin"&&filesModeOriginal.size===2')! == 'true'
	store.item_list[0] = html.DragDataStoreItem{
		...store.item_list[0]
		data:      [u8(9)]
		file_name: 'changed.bin'
	}
	transfer.set_data('text/plain', 'text remains independent')
	transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('image/png'),
		[u8(3), 4, 5], libjs.utf16_string('added.png')))
	assert runtime.evaluate_host('globalThis.filesModeChanged=__filesModeTransfer().files;filesModeChanged===filesModeOld&&filesModeChanged.length===2&&filesModeChanged[0].name==="changed.bin"&&filesModeChanged[0].size===1&&filesModeChanged[1].name==="added.png"&&filesModeOld.length===2&&filesModeOriginal.name==="original.bin"&&filesModeOriginal.size===2')! == 'true'
	store.set_mode(.protected)
	assert runtime.evaluate_host('(()=>{const t=__filesModeTransfer(),first=t.files,second=t.files;globalThis.filesModeProtected=first;return first===second&&first.length===0&&second.length===0&&t.types.join(",")==="text/plain,Files"&&t.getData("text")===""&&filesModeChanged.length===0&&filesModeOriginal.name==="original.bin"})()')! == 'true'
	store.set_mode(.read_only)
	assert runtime.evaluate_host('(()=>{const t=__filesModeTransfer(),next=t.files;t.setData("text","blocked");t.clearData();return next.length===2&&next===filesModeChanged&&next[0]===filesModeChanged[0]&&next[0].name==="changed.bin"&&t.getData("text")==="text remains independent"&&filesModeProtected.length===2})()')! == 'true'
	store.set_mode(.read_write)
	transfer.remove_item(0)
	assert runtime.evaluate_host('__filesModeTransfer().files.length===1&&__filesModeTransfer().files[0].name==="added.png"&&filesModeChanged.length===1&&filesModeChanged[0].name==="added.png"')! == 'true'
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('(()=>{const t=__filesModeTransfer(),one=t.files,two=t.files;return one===two&&one.length===0&&two.length===0&&t.types.length===0&&filesModeOriginal.name==="original.bin"&&filesModeOld.length===0&&filesModeChanged.length===0})()')! == 'true'
	old_file := runtime.native_file(runtime.evaluate_host_value('filesModeOriginal')!)!
	assert old_file.raw_bytes() == [u8(1), 2]
	assert transfer.mode() == none && transfer.length() == 0
	files_native_assert_vm(runtime)
}

fn test_native_data_transfer_files_late_window_identity_and_fileapi_installation() {
	$if !darwin { return }
	mut runtime, mut document := files_native_fixture('http://transfer-files-late-guard.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert files_native_guard(runtime)!
	mut late := Runtime.create()
	mut late_document := files_native_document('http://transfer-files-late-owner.example/')
	defer {
		late.close()
		late_document.finalize()
	}
	late.install_event_target_binding()!
	mut transfer := html.DataTransfer.construct()
	transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		'late payload'.bytes(), libjs.utf16_string('late.txt')))
	wrapper := late.javascript_data_transfer(transfer)!
	files_native_export(mut late, '__filesLateTransfer', wrapper)!
	assert late.evaluate_host('typeof DataTransfer==="undefined"&&typeof FileList==="undefined"&&__filesLateTransfer().files===undefined')! == 'true'
	assert late.libjs_vm().execution_context_stack().len == 1
	assert voidptr(late.libjs_vm().running_execution_context()) == voidptr(late.realm_context)
	late.evaluate_host('globalThis.filesLateActualGlobal=globalThis;globalThis.filesLateSavedTransfer=__filesLateTransfer();globalThis={};0')!
	settings := unsafe { &html.EnvironmentSettingsObject(late_document.relevant_settings_object()) }
	late.bind_scripting_environment(settings)!
	late.install_event_target_binding()!
	assert !settings.is_secure_context() && files_native_guard(late)!
	assert late.javascript_data_transfer(transfer)! == wrapper
	assert voidptr(late.native_data_transfer(wrapper)!) == voidptr(transfer)
	assert late.evaluate_host('(()=>{const t=__filesLateTransfer();filesLateActualGlobal.filesLateGetter=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"files").get;let missing=false;try{filesLateGetter.call(t)}catch(error){missing=error.message==="FileList binding is unavailable"}return missing&&t===filesLateSavedTransfer&&Object.getPrototypeOf(t)===DataTransfer.prototype&&t instanceof DataTransfer&&filesLateActualGlobal.DataTransfer===DataTransfer&&globalThis.DataTransfer===undefined})()')! == 'true'
	host := files_native_install(mut late, late_document)!
	late.install_event_target_binding()!
	assert late.evaluate_host('(()=>{const t=__filesLateTransfer(),one=t.files,two=t.files;return one===two&&one.length===1&&one[0].name==="late.txt"&&one[0].size===12&&one[0].type==="text/plain"&&one instanceof FileList&&one[0] instanceof File&&filesLateActualGlobal.FileList===FileList&&globalThis.FileList===undefined&&Object.getOwnPropertyDescriptor(DataTransfer.prototype,"files").get===filesLateGetter&&t===filesLateSavedTransfer})()')! == 'true'
	assert !host.closed
	assert late.native_file(late.evaluate_host_value('__filesLateTransfer().files[0]')!)!.raw_bytes() == 'late payload'.bytes()
	files_native_assert_vm(runtime)
	files_native_assert_vm(late)
}

fn test_native_data_transfer_files_retained_factories_foreign_registry_and_close() {
	$if !darwin { return }
	mut runtime, mut document := files_native_fixture('https://transfer-files-owner.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert files_native_guard(runtime)!
	host := files_native_install(mut runtime, document)!
	mut transfer := html.DataTransfer.construct()
	transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		'owner payload'.bytes(), libjs.utf16_string('owner.txt')))
	wrapper := runtime.javascript_data_transfer(transfer)!
	files_native_export(mut runtime, '__filesOwnedTransfer', wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=__filesOwnedTransfer(),get=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"files").get,listPrototype=FileList.prototype,filePrototype=File.prototype,blobPrototype=Blob.prototype,marker={};let authorGets=0;
 const drag=new DragEvent("drop",{dataTransfer:t});for(const name of ["constructor","files","items","types","getData","valueOf","toString"])Object.defineProperty(t,name,{get(){authorGets++;throw marker},configurable:true});Object.defineProperty(t,Symbol.toPrimitive,{get(){authorGets++;throw marker},configurable:true});Object.setPrototypeOf(t,null);
 globalThis.FileList=function ReplacementFileList(){throw marker};globalThis.File=function ReplacementFile(){throw marker};globalThis.Blob=function ReplacementBlob(){throw marker};globalThis.DataTransfer=function ReplacementTransfer(){throw marker};Object.create=function ReplacementCreate(){throw marker};Object.defineProperty=function ReplacementDefine(){throw marker};globalThis.Proxy=function ReplacementProxy(){throw marker};
 const first=get.call(t),second=get.call(t);check(first===second&&first.length===1&&first[0]===second[0]&&first[0].name==="owner.txt"&&first[0].size===13&&Object.getPrototypeOf(first)===listPrototype&&Object.getPrototypeOf(first[0])===filePrototype&&Object.getPrototypeOf(filePrototype)===blobPrototype&&drag.dataTransfer===t&&__filesOwnedTransfer()===t&&authorGets===0,"native retained factories ignore public replacements and poisoned receiver");globalThis.filesOwnedGetter=get;globalThis.filesOwnedFirst=first;globalThis.filesOwnedSecond=second;return true;
})()')! == 'true'
	first_value := runtime.evaluate_host_value('filesOwnedFirst')!
	one_value := runtime.evaluate_host_value('filesOwnedFirst[0]')!
	first := runtime.native_file_list(first_value)!
	one := runtime.native_file(one_value)!
	assert voidptr(first.item(0)?) == voidptr(one) && one.raw_bytes() == 'owner payload'.bytes()
	assert voidptr(runtime.native_blob(one_value)!) == voidptr(&one.Blob)
	mut foreign, mut foreign_document := files_native_fixture('https://transfer-files-foreign.example/')
	defer {
		foreign.close()
		foreign_document.finalize()
	}
	_ = files_native_install(mut foreign, foreign_document)!
	foreign_transfer := foreign.javascript_data_transfer(transfer)!
	files_native_export(mut foreign, '__filesForeignTransfer', foreign_transfer)!
	foreign_list := foreign.evaluate_host_value('__filesForeignTransfer().files')!
	files_native_export(mut foreign, '__filesForeignList', foreign_list)!
	foreign_file := foreign.evaluate_host_value('__filesForeignList()[0]')!
	assert voidptr(foreign.native_data_transfer(foreign_transfer)!) == voidptr(transfer)
	assert foreign.native_file(foreign_file)!.raw_bytes() == one.raw_bytes()
	// Opaque foreign JSC values enter only native registry lookup, never a C call.
	if _ := runtime.native_data_transfer(foreign_transfer) { assert false }
	if _ := foreign.native_data_transfer(wrapper) { assert false }
	if _ := runtime.native_file_list(foreign_list) { assert false }
	if _ := foreign.native_file_list(first_value) { assert false }
	if _ := runtime.native_file(foreign_file) { assert false }
	if _ := foreign.native_file(one_value) { assert false }
	if _ := runtime.native_blob(foreign_file) { assert false }
	if _ := foreign.native_blob(one_value) { assert false }
	assert foreign.evaluate_host('__filesForeignList().length===1&&__filesForeignList()[0].name==="owner.txt"&&__filesForeignTransfer().files===__filesForeignList()')! == 'true'
	files_native_assert_vm(runtime)
	files_native_assert_vm(foreign)
	files := host.files
	blobs := files.blobs
	assert host.records.len == 1 && files.records.len >= 1 && blobs.records.len >= 1
	runtime.close()
	assert host.closed && host.records.len == 0 && host.by_wrapper.len == 0
	assert files.closed && files.records.len == 0 && files.by_wrapper.len == 0
	assert blobs.closed && blobs.records.len == 0 && blobs.by_wrapper.len == 0
	if _ := runtime.native_file_list(first_value) { assert false }
	if _ := runtime.native_file(one_value) { assert false }
	assert first.item(0)?.raw_bytes() == 'owner payload'.bytes()
	assert transfer.file_list().item(0)?.raw_bytes() == 'owner payload'.bytes()
	assert foreign.evaluate_host('__filesForeignTransfer().files[0].name==="owner.txt"')! == 'true'
	runtime.close()
	assert host.closed && host.records.len == 0
}
