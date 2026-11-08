module browserjs

import dom
import fileapi
import html
import libjs
import time

fn items_add_native_fixture(url string) (&Runtime, &dom.Document) {
	document := html.parse_document_with_url('<!doctype html><body>Native transfer add</body>',
		dom.URL{ value: url })
	_ = html.WindowModel.create_top_level(document, none, 'native-transfer-add') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, document
}

fn items_add_native_install_files(mut runtime Runtime, document &dom.Document) ! {
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
}

fn items_add_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn items_add_native_assert_vm(runtime &Runtime) {
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn items_add_native_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('typeof DataTransferItemList==="function"&&typeof DataTransferItemList.prototype.add==="function"')! == 'true'
}

fn test_native_data_transfer_items_add_metadata_overload_arbiter_and_receiver_brands() {
	$if !darwin { return }
	mut runtime, mut document := items_add_native_fixture('https://transfer-items-add-metadata.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_add_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=DataTransferItemList.prototype,d=Object.getOwnPropertyDescriptor(p,"add"),add=d.value,t=new DataTransfer(),list=t.items,marker={};let conversions=0,traps=0;
 check(d.writable&&d.enumerable&&d.configurable&&add.name==="add"&&add.length===1&&Function.prototype.toString.call(add).includes("[native code]")&&!Object.hasOwn(add,"prototype"),"native add metadata");let nonconstructable=false;try{Reflect.construct(function Empty(){},[],add)}catch(error){nonconstructable=error instanceof TypeError}check(nonconstructable,"operation is not constructable");
 const argument={[Symbol.toPrimitive](){conversions++;throw marker}},proxy=new Proxy(list,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 for(const receiver of [list,Object.create(p),proxy,{},null,undefined,1]){let rejected=false;try{add.call(receiver)}catch(error){rejected=error instanceof TypeError&&error.message==="Overload resolution failed"}check(rejected,"zero-argument overload arbiter precedes receiver brand")}
 for(const receiver of [Object.create(p),proxy,t,{},null,undefined,1])for(const args of [[argument],[argument,argument]]){let rejected=false;try{Reflect.apply(add,receiver,args)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransferItemList"}check(rejected,"selected overload brands receiver before its argument conversions")}
 for(const value of [undefined,null,1,true,"text",1n,Symbol("file"),argument,Object.create(null)]){let rejected=false;try{list.add(value)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type File"}check(rejected,"one argument selects native File without FileHost or string coercion")}
 check(conversions===0&&traps===0&&list.length===0,"overload and brand failures never invoke author code");const first=list.add("text without FileHost","TEXT/PLAIN",argument);check(first===list[0]&&first.kind==="string"&&first.type==="text/plain"&&t.getData("text")==="text without FileHost"&&conversions===0,"two arguments select string and ignore extras without FileHost");return true;
})()')! == 'true'
	items_add_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_add_raw_utf16_types_data_and_fresh_duplicate_exceptions() {
	$if !darwin { return }
	mut runtime, mut document := items_add_native_fixture('https://transfer-items-add-utf16.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_add_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=new DataTransfer(),list=t.items,data="\udc00\u0000\ud800\ud83d\ude00",type="X\u0000A\ud800\u00c9",duplicate="x\u0000A\ud800\u00c9",item=list.add(data,type),snapshot=t.types,NativeDOMException=DOMException;
 check(list===t.items&&item===list[0]&&item instanceof DataTransferItem&&item.kind==="string"&&item.type==="x\u0000a\ud800\u00c9"&&t.getData(type)===data&&snapshot[0]===item.type&&Object.isFrozen(snapshot),"raw UTF16 text and ASCII-only type lowering reach actual store");
 globalThis.itemsAddRawTransfer=t;globalThis.itemsAddRawItem=item;globalThis.itemsAddDuplicateErrors=[];globalThis.DOMException=function AuthorException(){throw 0};for(let i=0;i<2;i++){try{list.add("never",duplicate);throw new Error("duplicate accepted")}catch(error){check(error instanceof NativeDOMException&&error.name==="NotSupportedError"&&error.code===9&&error.message==="There is already a DataTransferItem with type "+duplicate,"typed source duplicate message preserves original UTF16");itemsAddDuplicateErrors.push(error)}}
 check(itemsAddDuplicateErrors[0]!==itemsAddDuplicateErrors[1]&&list.length===1&&list[0]===item&&t.types===snapshot&&t.getData(type)===data,"fresh errors leave identities, data, and type revision unchanged");const upper=list.add("upper","\u00c4"),lower=list.add("lower","\u00e4");check(upper!==lower&&upper.type==="\u00c4"&&lower.type==="\u00e4"&&t.getData("\u00c4")==="upper"&&t.getData("\u00e4")==="lower","nonASCII type case remains distinct");
 const alias=list.add("literal text type","TEXT");check(alias.type==="text"&&t.getData("text")===""&&list.add("normal text type","text/plain").type==="text/plain"&&t.getData("text")==="normal text type","add does not apply setData legacy format aliases");check(t.types!==snapshot&&snapshot.length===1&&snapshot[0]===item.type,"successful additions refresh types while preserving prior snapshots");list.remove(0);check(item.kind===""&&item.type===""&&item.getAsFile()===null&&list[0]===upper,"returned actual record disables and surviving wrappers reindex");return true;
})()')! == 'true'
	actual := runtime.native_data_transfer(runtime.evaluate_host_value('itemsAddRawTransfer')!)!
	assert actual.length() == 4
	removed := runtime.native_data_transfer_item(runtime.evaluate_host_value('itemsAddRawItem')!)!
	assert removed.mode() == none
	first := runtime.native_dom_exception(runtime.evaluate_host_value('itemsAddDuplicateErrors[0]')!)!.dom_exception_?
	second := runtime.native_dom_exception(runtime.evaluate_host_value('itemsAddDuplicateErrors[1]')!)!.dom_exception_?
	assert voidptr(first) != voidptr(second)
	mut expected_message := libjs.utf16_string('There is already a DataTransferItem with type ').code_units()
	expected_message << [u16(`x`), 0, u16(`A`), 0xd800, 0x00c9]
	assert first.message_utf16().code_units() == expected_message
	assert second.message_utf16().code_units() == expected_message
	assert first.name() == 'NotSupportedError' && first.code() == 9
	items_add_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_add_ordered_string_conversions_exact_throws_and_file_arity() {
	$if !darwin { return }
	mut runtime, mut document := items_add_native_fixture('https://transfer-items-add-conversions.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_add_native_guard(runtime)!
	items_add_native_install_files(mut runtime, document)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=new DataTransfer(),list=t.items,order=[],convert=(name,value)=>({[Symbol.toPrimitive](hint){order.push(name+":"+hint);return value}}),marker={};
 const first=list.add(convert("data","raw\u0000\udfff"),convert("type","X/TYPE"),{toString(){throw marker}});check(first===list[0]&&first.type==="x/type"&&t.getData("x/type")==="raw\u0000\udfff"&&order.join(",")==="data:string,type:string","left-to-right string-hint conversion and ignored extras");const before=t.types;
 for(const reason of [marker,undefined,0,Symbol("original")]){let later=0,same=false;try{list.add({toString(){throw reason}},{toString(){later++;return "never"}})}catch(error){same=error===reason}check(same&&later===0,"first conversion preserves exact thrown value and skips second");same=false;try{list.add("never",{toString(){throw reason}})}catch(error){same=error===reason}check(same,"second conversion preserves exact thrown value")}
 for(const invoke of [()=>list.add(Symbol("data"),"never"),()=>list.add("never",Symbol("type"))]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}check(rejected,"DOMString Symbol rejects")}
 check(list.length===1&&t.types===before,"conversion failures do not change the native store or type revision");check(list.add(null,undefined).type==="undefined"&&t.getData(undefined)==="null"&&list.add(undefined,null).type==="null"&&t.getData(null)==="undefined"&&list.add(12n,13n).type==="13"&&t.getData("13")==="12","null, undefined and BigInt use DOMString conversion");
 const file=new File(["file bytes"],"actual.txt",{type:"text/plain",lastModified:7});Object.defineProperty(file,Symbol.toPrimitive,{configurable:true,value(hint){order.push("file:"+hint);return "file converted to text"}});const stringItem=list.add(file,"X/FILE",marker);check(stringItem.kind==="string"&&stringItem.type==="x/file"&&t.getData("x/file")==="file converted to text"&&order[2]==="file:string","two arguments select DOMString for an actual File");const fileItem=list.add(file);check(fileItem.kind==="file"&&fileItem.type==="text/plain"&&order.length===3,"one argument selects native File and skips its coercion");
 let proxyReads=0;const proxy=new Proxy(file,{get(target,name,receiver){if(name===Symbol.toPrimitive){proxyReads++;return hint=>{check(hint==="string","proxy string hint");return "proxy converted"}}return Reflect.get(target,name,receiver)},getPrototypeOf(){proxyReads++;throw marker}});let rejected=false;try{list.add(proxy)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type File"}check(rejected&&proxyReads===0,"File Proxy is not a native File and does not run traps");const proxyText=list.add(proxy,"x/proxy");check(proxyText.kind==="string"&&t.getData("x/proxy")==="proxy converted"&&proxyReads===1,"two arguments convert a File Proxy as a string");
 for(const value of [new Blob(["blob"]),Object.create(File.prototype),{name:"fake",type:"text/plain"}]){let invalid=false;try{list.add(value)}catch(error){invalid=error instanceof TypeError&&error.message==="Not an object of type File"}check(invalid,"native File excludes Blob and prototype/shape spoofs")}globalThis.itemsAddConvertedTransfer=t;return true;
})()')! == 'true'
	actual := runtime.native_data_transfer(runtime.evaluate_host_value('itemsAddConvertedTransfer')!)!
	assert actual.drag_data(0).text_data_utf16().code_units() == [u16(`r`), u16(`a`), u16(`w`), 0, 0xdfff]
	assert actual.drag_data(4).kind == .text
	assert actual.drag_data(5).kind == .file
	assert actual.drag_data(5).data == 'file bytes'.bytes()
	items_add_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_add_real_file_snapshot_fresh_producers_and_owner_read_tasks() {
	$if !darwin { return }
	mut runtime, mut document := items_add_native_fixture('https://transfer-items-add-file.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_add_native_guard(runtime)!
	items_add_native_install_files(mut runtime, document)!
	mut transfer := html.DataTransfer.construct()
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00])
	mut input_file := fileapi.File.create_utf16([u8(0), 128, 255], name,
		libjs.utf16_string('TEXT/PLAIN'), -7)
	input := runtime.javascript_file(input_file)!
	items_add_native_export(mut runtime, '__itemsAddFileInput', input)!
	items_add_native_export(mut runtime, '__itemsAddFileTransfer', runtime.javascript_data_transfer(transfer)!)!
	before := time.now().unix_milli()
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=__itemsAddFileTransfer(),list=t.items,input=__itemsAddFileInput(),p=DataTransferItemList.prototype,add=p.add,NativeFile=File,NativeBlob=Blob,NativeFileList=FileList,NativeItem=DataTransferItem,marker={};let reads=0;
 for(const name of ["name","type","lastModified","size","constructor","valueOf","toString"])Object.defineProperty(input,name,{get(){reads++;throw marker},configurable:true});Object.defineProperty(input,Symbol.toPrimitive,{get(){reads++;throw marker},configurable:true});Object.setPrototypeOf(input,null);globalThis.File=function AuthorFile(){throw marker};globalThis.Blob=function AuthorBlob(){throw marker};globalThis.FileList=function AuthorFileList(){throw marker};globalThis.DataTransferItem=function AuthorItem(){throw marker};globalThis.DataTransferItemList=function AuthorList(){throw marker};
 const first=add.call(list,input),second=add.call(list,input);check(reads===0&&first!==second&&first===list[0]&&second===list[1]&&first instanceof NativeItem&&first.kind==="file"&&first.type==="text/plain"&&t.types.join(",")==="Files","native File slots and duplicate File kinds ignore all author state");const text=add.call(list,"separate text","TEXT/PLAIN");check(text.kind==="string"&&text.type==="text/plain"&&list.length===3&&t.types.join(",")==="text/plain,Files","File MIME does not block a text item of the same type");
 const one=first.getAsFile(),two=first.getAsFile(),files=t.files,other=t.files;check(one!==input&&one!==two&&one!==files[0]&&files===other&&files[0]===other[0]&&one instanceof NativeFile&&one instanceof NativeBlob&&files instanceof NativeFileList&&files.length===2&&one.name==="n\ud800\u0000\udc00"&&one.type==="text/plain"&&one.size===3&&one.lastModified!==-7&&reads===0,"native File producers and live SameObject FileList ignore author factories");globalThis.itemsAddFileItem=first;globalThis.itemsAddFileOutput=one;globalThis.itemsAddFileOther=two;globalThis.itemsAddFileList=files;globalThis.itemsAddFileDone=false;globalThis.itemsAddFilePromise=one.bytes();itemsAddFilePromise.then(bytes=>itemsAddFileDone=bytes instanceof Uint8Array&&bytes.length===3&&bytes[0]===0&&bytes[1]===128&&bytes[2]===255);return itemsAddFilePromise instanceof Promise&&!itemsAddFileDone;
})()')! == 'true'
	after := time.now().unix_milli()
	assert transfer.length() == 3
	assert transfer.drag_data(0).data == [u8(0), 128, 255]
	assert transfer.drag_data(0).file_name_utf16().code_units() == name.code_units()
	assert transfer.drag_data(0).type_utf16().str() == 'text/plain'
	item := runtime.native_data_transfer_item(runtime.evaluate_host_value('itemsAddFileItem')!)!
	assert voidptr(item) == voidptr(transfer.item(0))
	first_file := runtime.native_file(runtime.evaluate_host_value('itemsAddFileOutput')!)!
	second_file := runtime.native_file(runtime.evaluate_host_value('itemsAddFileOther')!)!
	assert voidptr(first_file) != voidptr(input_file) && voidptr(second_file) != voidptr(first_file)
	assert first_file.last_modified() >= before && first_file.last_modified() <= after
	assert first_file.raw_bytes() == [u8(0), 128, 255]
	assert first_file.name_utf16().code_units() == name.code_units()
	input_file.deserialization_steps_utf16(libjs.utf16_string('image/png'), [u8(9)],
		libjs.utf16_string('changed.png'), 99)
	assert transfer.drag_data(0).data == [u8(0), 128, 255]
	assert transfer.drag_data(1).data == [u8(0), 128, 255]
	assert transfer.drag_data(0).file_name_utf16().code_units() == name.code_units()
	assert runtime.evaluate_host(r'itemsAddFileItem.getAsFile().name==="n\ud800\u0000\udc00"&&itemsAddFileItem.getAsFile().size===3&&__itemsAddFileTransfer().files[1].type==="text/plain"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	})?
	assert task.document() == settings.responsible_document()
	task.execute()
	assert runtime.evaluate_host('itemsAddFileDone')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const t=__itemsAddFileTransfer(),list=t.items,old=list[0],survivor=list[1];list.remove(0);return old===itemsAddFileItem&&old.kind===""&&old.type===""&&old.getAsFile()===null&&list[0]===survivor&&list.length===2&&t.files.length===1&&itemsAddFileList.length===1&&itemsAddFileOutput.size===3})()')! == 'true'
	items_add_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_add_mode_gates_and_owner_local_file_registries() {
	$if !darwin { return }
	mut runtime, mut document := items_add_native_fixture('https://transfer-items-add-modes.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_add_native_guard(runtime)!
	items_add_native_install_files(mut runtime, document)!
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string('original')))
	mut transfer := html.DataTransfer.create(store)
	mut list := transfer.items()
	list_wrapper := runtime.javascript_data_transfer_item_list(list)!
	input_file := fileapi.File.create('owned'.bytes(), 'owned.txt', 'text/plain', -1)
	input := runtime.javascript_file(input_file)!
	items_add_native_export(mut runtime, '__itemsAddModeTransfer', runtime.javascript_data_transfer(transfer)!)!
	items_add_native_export(mut runtime, '__itemsAddModeFile', input)!
	assert runtime.evaluate_host('globalThis.itemsAddModeList=__itemsAddModeTransfer().items;globalThis.itemsAddModeOld=itemsAddModeList[0];globalThis.itemsAddModeTypes=__itemsAddModeTransfer().types;true')! == 'true'
	for mode in [html.DragDataStoreMode.protected, .read_only] {
		store.set_mode(mode)
		assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},list=itemsAddModeList,order=[],marker={};check(list.add({[Symbol.toPrimitive](hint){order.push("data:"+hint);return "blocked"}},{[Symbol.toPrimitive](hint){order.push("type:"+hint);return "TEXT/PLAIN"}})===null&&order.join(",")==="data:string,type:string"&&list.add(__itemsAddModeFile())===null,"mode gate follows selected overload conversions and suppresses duplicate checks");
 for(const reason of [marker,undefined,0]){let same=false;try{list.add("blocked",{toString(){throw reason}})}catch(error){same=error===reason}check(same,"non-writable mode still preserves original author conversion throw")}
 let reads=0;const fake={get name(){reads++;throw marker},toString(){reads++;throw marker}},proxy=new Proxy(__itemsAddModeFile(),{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}});for(const value of [null,undefined,fake,proxy,Object.create(File.prototype)]){let rejected=false;try{list.add(value)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type File"}check(rejected,"File conversion still brands before mode gate")}
 return reads===0&&list===__itemsAddModeTransfer().items&&list.length===1&&list[0]===itemsAddModeOld&&itemsAddModeOld.kind==="string"&&__itemsAddModeTransfer().types===itemsAddModeTypes;
})()')! == 'true'
	}
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('itemsAddModeList.add("blocked","TEXT/PLAIN")===null&&itemsAddModeList.add(__itemsAddModeFile())===null&&itemsAddModeList===__itemsAddModeTransfer().items&&itemsAddModeList.length===0&&itemsAddModeOld.kind===""')! == 'true'
	mut foreign, mut foreign_document := items_add_native_fixture('https://transfer-items-add-foreign.example/')
	defer {
		foreign.close()
		foreign_document.finalize()
	}
	assert items_add_native_guard(foreign)!
	items_add_native_install_files(mut foreign, foreign_document)!
	foreign_input := foreign.javascript_file(input_file)!
	foreign_list := foreign.javascript_data_transfer_item_list(list)!
	assert voidptr(foreign.native_file(foreign_input)!) == voidptr(input_file)
	if _ := runtime.native_file(foreign_input) { assert false }
	if _ := foreign.native_file(input) { assert false }
	// One-argument dispatch uses only the native registry, never a foreign JSC value read.
	if _ := runtime.data_transfer_items_binding_call('add', list_wrapper, [foreign_input]) { assert false }
	if _ := foreign.data_transfer_items_binding_call('add', foreign_list, [input]) { assert false }
	assert transfer.length() == 0
	items_add_native_assert_vm(runtime)
	items_add_native_assert_vm(foreign)
	runtime.close()
	assert runtime.closed
	if _ := runtime.native_data_transfer_item_list(list_wrapper) { assert false }
	if _ := runtime.native_file(input) { assert false }
	assert input_file.raw_bytes() == 'owned'.bytes()
	assert voidptr(foreign.native_file(foreign_input)!) == voidptr(input_file)
}
