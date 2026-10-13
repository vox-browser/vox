module browserjs

import dom
import html
import libjs

fn entry_native_document(url string) &dom.Document {
	document := html.parse_document_with_url('<!doctype html><body>Native transfer entries</body>',
		dom.URL{ value: url })
	_ = html.WindowModel.create_top_level(document, none, 'native-transfer-entry') or { panic(err) }
	return document
}

fn entry_native_fixture(url string) (&Runtime, &dom.Document) {
	document := entry_native_document(url)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, document
}

fn entry_native_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('typeof FileSystemEntry==="function"&&typeof DataTransferItem==="function"&&typeof DataTransferItem.prototype.webkitGetAsEntry==="function"')! == 'true'
}

fn entry_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn entry_native_install_files(mut runtime Runtime, document &dom.Document) ! {
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := FileHost.create(document)!
	files.install(mut runtime)!
	files.install_constructor()!
}

fn entry_native_assert_vm(runtime &Runtime) {
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_data_transfer_item_entry_metadata_illegal_constructor_and_exact_receiver_brands() {
	$if !darwin { return }
	mut runtime, mut document := entry_native_fixture('https://transfer-entry-metadata.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert entry_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},C=FileSystemEntry,p=C.prototype,ip=DataTransferItem.prototype,g=Object.getOwnPropertyDescriptor(globalThis,"FileSystemEntry"),cp=Object.getOwnPropertyDescriptor(C,"prototype"),constructor=Object.getOwnPropertyDescriptor(p,"constructor"),tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag),d=Object.getOwnPropertyDescriptor(ip,"webkitGetAsEntry"),method=d.value,marker={};let reads=0,conversions=0;
 check(C.name==="FileSystemEntry"&&C.length===0&&!Object.hasOwn(C,"caller")&&!Object.hasOwn(C,"arguments")&&Object.getPrototypeOf(C)===Function.prototype&&Object.getPrototypeOf(p)===Object.prototype&&g.writable&&g.configurable&&!g.enumerable&&!cp.writable&&!cp.configurable&&!cp.enumerable&&constructor.value===C&&constructor.writable&&constructor.configurable&&!constructor.enumerable&&tag.value==="FileSystemEntry"&&!tag.writable&&!tag.enumerable&&tag.configurable,"source interface descriptors");
 check(Object.getOwnPropertyNames(p).sort().join(",")==="constructor,isDirectory,isFile,name"&&!Object.hasOwn(p,"fullPath")&&!Object.hasOwn(p,"filesystem")&&!Object.hasOwn(p,"getParent")&&typeof FileSystemFileEntry==="undefined"&&typeof FileSystemDirectoryEntry==="undefined","bounded source members");
 const argument=new Proxy({[Symbol.toPrimitive](){conversions++;throw marker}},{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}}),target=new Proxy(function Target(){},{get(){reads++;throw marker}});
 for(const [invoke,message] of [[()=>C(argument),"FileSystemEntry constructor must be called with \u0027new\u0027"],[()=>new C(argument),"FileSystemEntry is not a constructor"],[()=>Reflect.construct(C,[argument],target),"FileSystemEntry is not a constructor"]]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError&&error.message===message}check(rejected,"source illegal-constructor error")}
 check(d.writable&&d.enumerable&&d.configurable&&method.name==="webkitGetAsEntry"&&method.length===0&&!Object.hasOwn(method,"prototype")&&Function.prototype.toString.call(method).includes("[native code]"),"native len-zero operation metadata");let nonconstructable=false;try{Reflect.construct(function Empty(){},[],method)}catch(error){nonconstructable=error instanceof TypeError}check(nonconstructable,"operation is not constructable");
 const t=new DataTransfer(),item=t.items.add("text","text/plain"),proxy=new Proxy(item,{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}});
 for(const receiver of [Object.create(ip),proxy,t,t.items,{},null,undefined,1])for(const args of [[],[argument]]){let rejected=false;try{Reflect.apply(method,receiver,args)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransferItem"}check(rejected,"item brand precedes ignored arguments and kind gate")}
 for(const name of ["isFile","isDirectory","name"]){const getter=Object.getOwnPropertyDescriptor(p,name);check(getter.set===undefined&&getter.enumerable&&getter.configurable&&getter.get.name==="get "+name&&getter.get.length===0&&Function.prototype.toString.call(getter.get).includes("[native code]"),"native readonly entry getter metadata");for(const receiver of [Object.create(p),new Proxy(Object.create(p),{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}}),item,t,{},null,undefined,1]){let rejected=false;try{getter.get.call(receiver,argument)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type FileSystemEntry"}check(rejected,"entry getters use the exact native registry brand")}}
 return item.webkitGetAsEntry(argument)===null&&reads===0&&conversions===0;
})()')! == 'true'
	entry_native_assert_vm(runtime)
}

fn test_native_data_transfer_item_entry_fresh_file_snapshots_and_all_nullable_gates() {
	$if !darwin { return }
	mut runtime, mut document := entry_native_fixture('https://transfer-entry-snapshots.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert entry_native_guard(runtime)!
	mut store := html.DragDataStore.create()
	store.set_mode(.protected)
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00, 0x6587,
		0xd83d, 0xde00, 0xdfff])
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		[u8(0), 128, 255], name))
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string('text is not an entry')))
	mut transfer := html.DataTransfer.create(store)
	entry_native_export(mut runtime, '__entrySnapshotTransfer', runtime.javascript_data_transfer(transfer)!)!
	assert runtime.evaluate_host('globalThis.entrySnapshotFile=__entrySnapshotTransfer().items[0];globalThis.entrySnapshotText=__entrySnapshotTransfer().items[1];entrySnapshotFile.webkitGetAsEntry({toString(){throw 0}})===null&&entrySnapshotText.webkitGetAsEntry()===null&&typeof File==="undefined"')! == 'true'
	store.set_mode(.read_write)
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},item=entrySnapshotFile,first=item.webkitGetAsEntry(),second=item.webkitGetAsEntry({[Symbol.toPrimitive](){throw 0}});globalThis.entrySnapshotFirst=first;globalThis.entrySnapshotSecond=second;
 check(first!==second&&first instanceof FileSystemEntry&&second instanceof FileSystemEntry&&Object.getPrototypeOf(first)===FileSystemEntry.prototype&&Object.getOwnPropertyNames(first).length===0&&Object.prototype.toString.call(first)==="[object FileSystemEntry]","fresh actual entry wrappers with inherited slots");check(first.isFile===true&&first.isDirectory===false&&first.name==="n\ud800\u0000\udc00\u6587\ud83d\ude00\udfff"&&second.name===first.name&&!Reflect.set(first,"name","replacement")&&!Reflect.set(first,"isFile",false)&&!Reflect.set(first,"isDirectory",true),"readonly name and kind snapshot without a File binding");return entrySnapshotText.webkitGetAsEntry()===null;
})()')! == 'true'
	store.set_mode(.read_only)
	assert runtime.evaluate_host('globalThis.entrySnapshotReadOnly=entrySnapshotFile.webkitGetAsEntry();entrySnapshotReadOnly!==entrySnapshotFirst&&entrySnapshotReadOnly!==entrySnapshotSecond&&entrySnapshotReadOnly.name===entrySnapshotFirst.name&&entrySnapshotReadOnly.isFile&&!entrySnapshotReadOnly.isDirectory&&entrySnapshotText.webkitGetAsEntry()===null')! == 'true'
	store.set_mode(.protected)
	assert runtime.evaluate_host('entrySnapshotFile.webkitGetAsEntry()===null&&entrySnapshotText.webkitGetAsEntry()===null&&entrySnapshotFirst.name===entrySnapshotReadOnly.name&&entrySnapshotFirst.isFile')! == 'true'
	store.set_mode(.read_write)
	assert runtime.evaluate_host('__entrySnapshotTransfer().items.remove(0)===undefined&&entrySnapshotFile.kind===""&&entrySnapshotFile.webkitGetAsEntry()===null&&__entrySnapshotTransfer().items[0]===entrySnapshotText&&entrySnapshotFirst.name===entrySnapshotSecond.name&&entrySnapshotSecond.isFile&&!entrySnapshotSecond.isDirectory')! == 'true'
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('__entrySnapshotTransfer().items.length===0&&entrySnapshotFile.webkitGetAsEntry()===null&&entrySnapshotText.webkitGetAsEntry()===null&&entrySnapshotReadOnly.name===entrySnapshotFirst.name&&entrySnapshotReadOnly.isFile')! == 'true'
	entry_native_assert_vm(runtime)
}

fn test_native_data_transfer_item_entry_late_window_identity_and_proxy_getter_rejection() {
	$if !darwin { return }
	mut probe, mut probe_document := entry_native_fixture('https://transfer-entry-late-probe.example/')
	defer {
		probe.close()
		probe_document.finalize()
	}
	assert entry_native_guard(probe)!
	mut runtime := Runtime.create()
	mut document := entry_native_document('http://transfer-entry-late.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_event_target_binding()!
	mut transfer := html.DataTransfer.construct()
	item := transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('image/png'),
		[u8(1)], libjs.utf16_string('late.png')))
	item_wrapper := runtime.javascript_data_transfer_item(item)!
	entry_native_export(mut runtime, '__entryLateItem', item_wrapper)!
	assert runtime.evaluate_host('typeof FileSystemEntry==="undefined"&&typeof DataTransferItem==="undefined"&&Object.prototype.toString.call(__entryLateItem())==="[object DataTransferItem]"')! == 'true'
	runtime.evaluate_host('globalThis.entryLateActualGlobal=globalThis;globalThis.entryLateTypeError=TypeError;globalThis.entryLateSavedItem=__entryLateItem();globalThis.TypeError=function AuthorTypeError(){throw 0};globalThis={};0')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_event_target_binding()!
	assert !settings.is_secure_context()
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},actual=entryLateActualGlobal,C=actual.FileSystemEntry,p=C.prototype,item=__entryLateItem();check(C===FileSystemEntry&&globalThis.FileSystemEntry===undefined&&item===entryLateSavedItem&&Object.getPrototypeOf(item)===DataTransferItem.prototype,"late Window exposes the real global and preserves native item identity");const entry=item.webkitGetAsEntry(),marker={};let reads=0;check(entry instanceof C&&entry.name==="late.png"&&entry.isFile&&!entry.isDirectory,"late Entry factory does not require a secure context");
 const proxy=new Proxy(entry,{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}}),spoof=Object.create(p,{isFile:{value:true},isDirectory:{value:false},name:{value:"late.png"}});for(const name of ["isFile","isDirectory","name"]){const getter=Object.getOwnPropertyDescriptor(p,name).get;for(const receiver of [proxy,Object.create(p),spoof]){let rejected=false;try{getter.call(receiver)}catch(error){rejected=error instanceof entryLateTypeError&&error.message==="Not an object of type FileSystemEntry"}check(rejected,"real-entry Proxy and prototype/shape spoofs do not borrow native slots")}}
 for(const invoke of [()=>new C(),()=>C()]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof entryLateTypeError}check(rejected,"late constructor retains original TypeError")};return reads===0;
})()')! == 'true'
	assert runtime.javascript_data_transfer_item(item)! == item_wrapper
	assert voidptr(runtime.native_data_transfer_item(item_wrapper)!) == voidptr(item)
	entry_native_assert_vm(runtime)
	entry_native_assert_vm(probe)
}

fn test_native_data_transfer_item_entry_retained_native_factories_ignore_author_mutations() {
	$if !darwin { return }
	mut runtime, mut document := entry_native_fixture('https://transfer-entry-retained.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert entry_native_guard(runtime)!
	entry_native_install_files(mut runtime, document)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=new DataTransfer(),file=new File(["bytes"],"raw\u0000\ud800\udc00\udfff.png",{type:"image/png",lastModified:7}),item=t.items.add(file),NativeEntry=FileSystemEntry,p=NativeEntry.prototype,method=DataTransferItem.prototype.webkitGetAsEntry,getName=Object.getOwnPropertyDescriptor(p,"name").get,getFile=Object.getOwnPropertyDescriptor(p,"isFile").get,getDirectory=Object.getOwnPropertyDescriptor(p,"isDirectory").get,NativeTypeError=TypeError,apply=Reflect.apply,define=Object.defineProperty,setPrototype=Object.setPrototypeOf,marker={};let reads=0;
 const first=method.call(item);check(first.name==="raw\u0000\ud800\udc00\ufffd.png","public File USVString filename conversion reaches Entry snapshot");for(const name of ["name","isFile","isDirectory","constructor","valueOf","toString"])define(first,name,{get(){reads++;throw marker},configurable:true});for(const name of ["webkitGetAsEntry","kind","type","constructor","valueOf","toString"])define(item,name,{get(){reads++;throw marker},configurable:true});setPrototype(first,null);setPrototype(item,null);
 globalThis.FileSystemEntry=function AuthorEntry(){throw marker};globalThis.DataTransferItem=function AuthorItem(){throw marker};globalThis.File=function AuthorFile(){throw marker};globalThis.TypeError=function AuthorTypeError(){throw marker};Object.create=function AuthorCreate(){throw marker};Object.defineProperty=function AuthorDefine(){throw marker};globalThis.Proxy=function AuthorProxy(){throw marker};Reflect.apply=function AuthorApply(){throw marker};Array.prototype[Symbol.iterator]=function AuthorIterator(){reads++;throw marker};
 const second=apply(method,item,[{[Symbol.toPrimitive](){reads++;throw marker}}]);check(second!==first&&second instanceof NativeEntry&&Object.getPrototypeOf(second)===p&&apply(getName,second,[])==="raw\u0000\ud800\udc00\ufffd.png"&&apply(getFile,second,[])&&!apply(getDirectory,second,[])&&apply(getName,first,[])===apply(getName,second,[])&&apply(getFile,first,[])&&!apply(getDirectory,first,[]),"native entry creation and getters ignore author globals, properties, prototypes and iterators");let rejected=false;try{apply(getName,{},[])}catch(error){rejected=error instanceof NativeTypeError&&error.message==="Not an object of type FileSystemEntry"}check(rejected,"brand errors retain native TypeError");t.items.remove(0);check(apply(method,item,[])===null&&apply(getName,second,[])===apply(getName,first,[])&&apply(getFile,second,[]),"retained entry survives source item removal");globalThis.entryRetainedTransfer=t;return reads===0;
})()')! == 'true'
	transfer := runtime.native_data_transfer(runtime.evaluate_host_value('entryRetainedTransfer')!)!
	assert transfer.length() == 0
	entry_native_assert_vm(runtime)
}
