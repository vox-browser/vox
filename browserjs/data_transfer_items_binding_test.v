module browserjs

import dom
import html
import libjs
import time

fn items_native_document(url string) &dom.Document {
	document := html.parse_document_with_url('<!doctype html><body>Native transfer items</body>',
		dom.URL{ value: url })
	_ = html.WindowModel.create_top_level(document, none, 'native-transfer-items') or { panic(err) }
	return document
}

fn items_native_fixture(url string) (&Runtime, &dom.Document) {
	document := items_native_document(url)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, document
}

fn items_native_install_files(mut runtime Runtime, document &dom.Document) !&FileListHost {
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

fn items_native_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('typeof DataTransferItem==="function"&&typeof DataTransferItemList==="function"&&(()=>{const d=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"items");return !!d&&typeof d.get==="function"})()')! == 'true'
}

fn items_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn items_native_assert_vm(runtime &Runtime) {
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_data_transfer_items_metadata_illegal_constructors_and_late_identity_upgrade() {
	$if !darwin { return }
	mut runtime, mut document := items_native_fixture('https://transfer-items-metadata.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},d=Object.getOwnPropertyDescriptor(DataTransfer.prototype,"items"),list=new DataTransfer().items,p=DataTransferItemList.prototype,ip=DataTransferItem.prototype;
 check(d.set===undefined&&d.enumerable&&d.configurable&&d.get.name==="get items"&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]"),"items getter metadata");
 for(const [C,name] of [[DataTransferItem,"DataTransferItem"],[DataTransferItemList,"DataTransferItemList"]]){const g=Object.getOwnPropertyDescriptor(globalThis,name),cp=Object.getOwnPropertyDescriptor(C,"prototype"),c=Object.getOwnPropertyDescriptor(C.prototype,"constructor"),tag=Object.getOwnPropertyDescriptor(C.prototype,Symbol.toStringTag);check(C.name===name&&C.length===0&&!Object.hasOwn(C,"caller")&&!Object.hasOwn(C,"arguments")&&Object.getPrototypeOf(C)===Function.prototype&&Object.getPrototypeOf(C.prototype)===Object.prototype&&g.writable&&g.configurable&&!g.enumerable&&!cp.writable&&!cp.configurable&&!cp.enumerable&&c.value===C&&c.writable&&c.configurable&&!c.enumerable&&tag.value===name&&!tag.writable&&!tag.enumerable&&tag.configurable,"interface metadata");let reads=0;const target=new Proxy(function Target(){},{get(){reads++;throw 0}});for(const [invoke,message] of [[()=>C(),name+" constructor must be called with \u0027new\u0027"],[()=>new C(),name+" is not a constructor"],[()=>Reflect.construct(C,[{toString(){reads++;throw 0}}],target),name+" is not a constructor"]]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError&&error.message===message}check(rejected,"source constructor error")}check(reads===0,"illegal construction never reads prototype/arguments")}
 check(Object.getOwnPropertyNames(p).sort().join(",")==="add,clear,constructor,length,remove"&&Object.getOwnPropertyNames(ip).sort().join(",")==="constructor,getAsFile,kind,type"&&!Object.hasOwn(p,"item")&&!Object.hasOwn(p,"keys")&&!Object.hasOwn(p,"values")&&!Object.hasOwn(p,"entries")&&!Object.hasOwn(p,"forEach")&&!Object.hasOwn(ip,"getAsString")&&!Object.hasOwn(ip,"webkitGetAsEntry"),"bounded source members");
 for(const [prototype,names] of [[p,["length"]],[ip,["kind","type"]]])for(const name of names){const g=Object.getOwnPropertyDescriptor(prototype,name);check(g.set===undefined&&g.enumerable&&g.configurable&&g.get.name==="get "+name&&g.get.length===0&&Function.prototype.toString.call(g.get).includes("[native code]"),"native readonly getter metadata")}
 for(const [prototype,name,length] of [[p,"remove",1],[p,"clear",0],[ip,"getAsFile",0]]){const op=Object.getOwnPropertyDescriptor(prototype,name);check(op.writable&&op.enumerable&&op.configurable&&op.value.name===name&&op.value.length===length&&Function.prototype.toString.call(op.value).includes("[native code]"),"native operation metadata");let rejected=false;try{Reflect.construct(function Empty(){},[],op.value)}catch(error){rejected=error instanceof TypeError}check(rejected,"operation nonconstructable")}
 const iterator=Object.getOwnPropertyDescriptor(p,Symbol.iterator);check(iterator.value===Array.prototype.values&&iterator.writable&&iterator.configurable&&!iterator.enumerable&&list instanceof DataTransferItemList&&list.length===0&&Object.prototype.toString.call(list)==="[object DataTransferItemList]"&&!Array.isArray(list),"source automatic array iterator");const transfer=new DataTransfer();check(transfer.items===transfer.items&&!Reflect.set(transfer,"items",[])&&!Reflect.set(transfer.items,"length",9),"stable readonly native list");return true;
})()')! == 'true'
	mut late := Runtime.create()
	mut late_document := items_native_document('http://transfer-items-late.example/')
	defer {
		late.close()
		late_document.finalize()
	}
	late.install_event_target_binding()!
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text/plain', 'late item')
	mut list := transfer.items()
	item := list.item(0)?
	transfer_wrapper := late.javascript_data_transfer(transfer)!
	list_wrapper := late.javascript_data_transfer_item_list(list)!
	item_wrapper := late.javascript_data_transfer_item(item)!
	items_native_export(mut late, '__itemsLateTransfer', transfer_wrapper)!
	items_native_export(mut late, '__itemsLateList', list_wrapper)!
	items_native_export(mut late, '__itemsLateItem', item_wrapper)!
	assert late.evaluate_host('typeof DataTransferItem==="undefined"&&typeof DataTransferItemList==="undefined"&&Object.prototype.toString.call(__itemsLateList())==="[object DataTransferItemList]"&&Object.prototype.toString.call(__itemsLateItem())==="[object DataTransferItem]"')! == 'true'
	assert late.libjs_vm().execution_context_stack().len == 1
	late.evaluate_host('globalThis.itemsLateActualGlobal=globalThis;globalThis.itemsLateTypeError=TypeError;globalThis.TypeError=function AuthorTypeError(){throw 0};globalThis.itemsLateSavedList=__itemsLateList();globalThis.itemsLateSavedItem=__itemsLateItem();globalThis={};0')!
	settings := unsafe { &html.EnvironmentSettingsObject(late_document.relevant_settings_object()) }
	late.bind_scripting_environment(settings)!
	late.install_event_target_binding()!
	assert !settings.is_secure_context()
	assert late.evaluate_host('itemsLateActualGlobal.DataTransferItemList===DataTransferItemList&&globalThis.DataTransferItemList===undefined&&__itemsLateTransfer().items===itemsLateSavedList&&__itemsLateTransfer().items[0]===itemsLateSavedItem&&Object.getPrototypeOf(itemsLateSavedList)===DataTransferItemList.prototype&&Object.getPrototypeOf(itemsLateSavedItem)===DataTransferItem.prototype&&itemsLateSavedItem.kind==="string"&&itemsLateSavedItem.type==="text/plain"&&itemsLateSavedItem.getAsFile()===null')! == 'true'
	assert late.evaluate_host('(()=>{for(const C of [DataTransferItem,DataTransferItemList]){try{new C();return false}catch(error){if(!(error instanceof itemsLateTypeError))return false}}return true})()')! == 'true'
	assert late.javascript_data_transfer_item_list(list)! == list_wrapper
	assert late.javascript_data_transfer_item(item)! == item_wrapper
	assert late.native_data_transfer_item_list(list_wrapper)! == list
	assert late.native_data_transfer_item(item_wrapper)! == item
	items_native_assert_vm(runtime)
	items_native_assert_vm(late)
}

fn test_native_data_transfer_items_live_order_indices_and_retained_item_records() {
	$if !darwin { return }
	mut runtime, mut document := items_native_fixture('https://transfer-items-live.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_native_guard(runtime)!
	mut transfer := html.DataTransfer.construct()
	first := transfer.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('TeXt/First'),
		libjs.utf16_string('first')))
	second := transfer.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('image/png'),
		[u8(1)], libjs.utf16_string('middle.png')))
	third_type := libjs.utf16_string_from_code_units([u16(`X`), 0, 0xd800, 0xdc00, 0xdfff])
	third := transfer.add_item(html.DragDataStoreItem.text_utf16(third_type,
		libjs.utf16_string('third')))
	mut list := transfer.items()
	list_wrapper := runtime.javascript_data_transfer_item_list(list)!
	items_native_export(mut runtime, '__itemsLiveTransfer', runtime.javascript_data_transfer(transfer)!)!
	items_native_export(mut runtime, '__itemsLiveList', list_wrapper)!
	items_native_export(mut runtime, '__itemsLiveFirst', runtime.javascript_data_transfer_item(first)!)!
	items_native_export(mut runtime, '__itemsLiveSecond', runtime.javascript_data_transfer_item(second)!)!
	items_native_export(mut runtime, '__itemsLiveThird', runtime.javascript_data_transfer_item(third)!)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=__itemsLiveTransfer(),list=t.items,a=list[0],b=list[1],c=list[2],iterator=list[Symbol.iterator]();
 check(list===__itemsLiveList()&&list===t.items&&list.length===3&&a===__itemsLiveFirst()&&b===__itemsLiveSecond()&&c===__itemsLiveThird()&&list[3]===undefined&&Reflect.ownKeys(list).join(",")==="0,1,2","actual stable list and ordered native item identities");check(a.kind==="string"&&a.type==="TeXt/First"&&b.kind==="file"&&b.type==="image/png"&&c.type==="X\u0000\ud800\udc00\udfff"&&Object.prototype.toString.call(c)==="[object DataTransferItem]","native kinds and raw UTF16 type");
 check(iterator.next().value===a,"iterator starts at live index");list.remove(0);check(list.length===2&&list[0]===b&&list[1]===c&&Reflect.ownKeys(list).join(",")==="0,1"&&a.kind===""&&a.type===""&&a.getAsFile()===null&&b.kind==="file"&&c.kind==="string","removal disables only old record and reindexes survivors");check(iterator.next().value===c&&iterator.next().done,"intrinsic iterator follows live reindexed list");globalThis.itemsLiveRemoved=a;globalThis.itemsLiveSurvivor=b;globalThis.itemsLiveTail=c;return true;
})()')! == 'true'
	assert first.mode() == none && list.length() == 2
	assert list.item(0)? == second && list.item(1)? == third
	assert runtime.native_data_transfer_item(runtime.evaluate_host_value('itemsLiveSurvivor')!)! == second
	assert runtime.native_data_transfer_item(runtime.evaluate_host_value('itemsLiveRemoved')!)! == first
	fourth := transfer.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('new'),
		libjs.utf16_string('appended natively')))
	assert runtime.evaluate_host('__itemsLiveList().length===3&&__itemsLiveList()[0]===itemsLiveSurvivor&&__itemsLiveList()[1]===itemsLiveTail&&__itemsLiveList()[2].type==="new"')! == 'true'
	assert runtime.native_data_transfer_item(runtime.evaluate_host_value('__itemsLiveList()[2]')!)! == fourth
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('__itemsLiveTransfer().items===__itemsLiveList()&&__itemsLiveList().length===0&&Reflect.ownKeys(__itemsLiveList()).length===0&&itemsLiveSurvivor.kind===""&&itemsLiveTail.type===""&&itemsLiveSurvivor.getAsFile()===null')! == 'true'
	items_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_indexed_platform_properties_and_ordinary_receivers() {
	$if !darwin { return }
	mut runtime, mut document := items_native_fixture('https://transfer-items-indexed.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},transfer=new DataTransfer();transfer.setData("text","one");const list=transfer.items,first=list[0],d=Object.getOwnPropertyDescriptor(list,"0"),symbol=Symbol("ordinary");
 check(d.value===first&&!d.writable&&d.enumerable&&d.configurable&&("0" in list)&&!("1" in list)&&list[1]===undefined,"indexed descriptors and membership");check(!Reflect.set(list,"0",null)&&!Reflect.set(list,"1",null)&&!Reflect.defineProperty(list,"0",{value:first})&&!Reflect.defineProperty(list,"1",{value:null})&&!Reflect.defineProperty(list,"2",{get(){return 0}})&&!Reflect.deleteProperty(list,"0")&&Reflect.deleteProperty(list,"1")&&!Reflect.preventExtensions(list)&&Object.isExtensible(list),"exact no-setter indexed branches");let frozen=false,strict=false;try{Object.freeze(list)}catch(error){frozen=error instanceof TypeError}try{(()=>{"use strict";list[0]=null})()}catch(error){strict=error instanceof TypeError}check(frozen&&strict&&list[0]===first,"freeze/strict assignment failures");
 list.z=3;Object.defineProperty(list,"00",{value:4,configurable:true,enumerable:true});Object.defineProperty(list,"-0",{value:5,configurable:true,enumerable:true});list["4294967295"]=6;list[symbol]=7;check(Reflect.ownKeys(list).map(key=>typeof key==="symbol"?"symbol":key).join(",")==="0,z,00,-0,4294967295,symbol"&&list["00"]===4&&list["-0"]===5&&list["4294967295"]===6&&list[symbol]===7&&Reflect.deleteProperty(list,"z"),"ordinary non-index keys and order");
 const child=Object.create(list);check(!Reflect.set(list,"0",9,child)&&Reflect.set(list,"1",8,child)&&child[1]===8&&!Object.hasOwn(list,"1")&&Reflect.set(list,"ordinary",10,child)&&child.ordinary===10&&!Object.hasOwn(list,"ordinary"),"distinct ordinary receiver uses engine define semantics");
 const original=Object.getPrototypeOf(list),prototype=Object.create(original);let received;Object.defineProperty(prototype,"5",{set(value){received=[this,value]},get(){return "inherited"},configurable:true});Object.defineProperty(prototype,"1",{get(){return "unsupported inherited"},configurable:true});Object.setPrototypeOf(list,prototype);check(Reflect.set(list,"5",12)&&received[0]===list&&received[1]===12&&!Object.hasOwn(list,"5")&&list[5]==="inherited"&&list[1]==="unsupported inherited"&&Object.getOwnPropertyDescriptor(list,"1")===undefined,"unsupported index preserves prototype setter/getter");
 transfer.setData("new","two");check(list[1] instanceof DataTransferItem&&list[1].type==="new"&&Object.hasOwn(list,"1")&&Reflect.ownKeys(list)[1]==="1","live supported index supersedes prototype fallback");return true;
})()')! == 'true'
	items_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_native_brands_unsigned_remove_errors_and_clear_modes() {
	$if !darwin { return }
	mut runtime, mut document := items_native_fixture('https://transfer-items-remove.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_native_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=new DataTransfer();t.setData("text","one");const list=t.items,item=list[0],p=DataTransferItemList.prototype,ip=DataTransferItem.prototype,marker={};let traps=0,conversions=0;const arg={[Symbol.toPrimitive](){conversions++;throw marker}},listProxy=new Proxy(list,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}}),itemProxy=new Proxy(item,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}});
 for(const receiver of [Object.create(p),listProxy,item,{},null,undefined,1]){for(const invoke of [()=>Object.getOwnPropertyDescriptor(p,"length").get.call(receiver,arg),()=>p.remove.call(receiver),()=>p.remove.call(receiver,arg),()=>p.clear.call(receiver,arg)]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}check(rejected,"list brand before arity/coercion")}}
 for(const receiver of [Object.create(ip),itemProxy,list,{},null,undefined,1]){for(const invoke of [()=>Object.getOwnPropertyDescriptor(ip,"kind").get.call(receiver,arg),()=>Object.getOwnPropertyDescriptor(ip,"type").get.call(receiver,arg),()=>ip.getAsFile.call(receiver,arg)]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}check(rejected,"item brand before ignored arguments/File dependency")}}
 check(traps===0&&conversions===0,"brands never inspect Proxy or coerce extras");let missing=false,same=false;try{list.remove()}catch(error){missing=error instanceof TypeError}try{list.remove(arg)}catch(error){same=error===marker}check(missing&&same&&conversions===1&&list.length===1,"arity before conversion and original author error");for(const index of [1n,Symbol("index")]){let rejected=false;try{list.remove(index)}catch(error){rejected=error instanceof TypeError}check(rejected,"unsigned-long rejects BigInt/Symbol")}
 for(const index of [-1,4294967295,1.8]){check(list.remove(index)===undefined&&list.length===1,"out-of-range modulo unsigned index")}
 for(const index of [undefined,NaN,Infinity,-Infinity,4294967296,0.9]){const value=new DataTransfer();value.setData("text","zero");value.setData("tail","one");const old=value.items[0];value.items.remove(index);check(value.items.length===1&&value.items[0].type==="tail"&&old.kind==="","unsigned-long wrapping/nonfinite conversion")}
 const conversion=[];list.remove({[Symbol.toPrimitive](hint){conversion.push(hint);return 0}});check(conversion.join(",")==="number"&&list.length===0&&item.kind==="","single number-hint conversion");return true;
})()')! == 'true'
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	store.add_item(html.DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'),
		libjs.utf16_string('text')))
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('image/png'),
		[u8(1)], libjs.utf16_string('survives.png')))
	transfer := html.DataTransfer.create(store)
	items_native_export(mut runtime, '__itemsModeTransfer', runtime.javascript_data_transfer(transfer)!)!
	assert runtime.evaluate_host('globalThis.itemsModeList=__itemsModeTransfer().items;globalThis.itemsModeText=itemsModeList[0];globalThis.itemsModeFile=itemsModeList[1];itemsModeList.clear({toString(){throw 0}})===undefined&&itemsModeList.length===1&&itemsModeList[0]===itemsModeFile&&itemsModeText.kind===""&&itemsModeText.type===""&&__itemsModeTransfer().types.join(",")==="Files"')! == 'true'
	for mode in [html.DragDataStoreMode.protected, .read_only] {
		store.set_mode(mode)
		assert runtime.evaluate_host(r'(()=>{
 const list=itemsModeList,marker={};let converted=0,same=false;try{list.remove({valueOf(){converted++;throw marker}})}catch(error){same=error===marker}if(!same||converted!==1)return false;
 const errors=[];for(let i=0;i<2;i++)try{list.remove(4294967295)}catch(error){errors.push(error)}globalThis.itemsModeException=errors[0];return errors.length===2&&errors[0]!==errors[1]&&errors.every(error=>error instanceof DOMException&&error.name==="InvalidStateError"&&error.code===11&&error.message==="DataTransferItemList is not in read/write mode")&&list.clear()===undefined&&list.length===1&&itemsModeFile.kind==="file"&&itemsModeFile.type==="image/png";
})()')! == 'true'
		actual_error := runtime.native_dom_exception(runtime.evaluate_host_value('itemsModeException')!)!
		assert actual_error.dom_exception_ != none
	}
	mut mutable_transfer := unsafe { &html.DataTransfer(transfer) }
	mutable_transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('(()=>{try{itemsModeList.remove(0);return false}catch(error){return error instanceof DOMException&&error.name==="InvalidStateError"&&itemsModeList.clear()===undefined&&itemsModeList.length===0&&itemsModeFile.kind===""&&itemsModeFile.type===""&&itemsModeFile.getAsFile()===null}})()')! == 'true'
	items_native_assert_vm(runtime)
}

fn test_native_data_transfer_items_file_gate_real_payload_retained_factories_and_close() {
	$if !darwin { return }
	mut runtime, mut document := items_native_fixture('https://transfer-items-files.example/')
	defer {
		runtime.close()
		document.finalize()
	}
	assert items_native_guard(runtime)!
	mut store := html.DragDataStore.create()
	store.set_mode(.protected)
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00])
	store.add_item(html.DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'),
		[u8(0), 128, 255], name))
	mut transfer := html.DataTransfer.create(store)
	mut list := transfer.items()
	item := list.item(0)?
	list_wrapper := runtime.javascript_data_transfer_item_list(list)!
	item_wrapper := runtime.javascript_data_transfer_item(item)!
	items_native_export(mut runtime, '__itemsFileTransfer', runtime.javascript_data_transfer(transfer)!)!
	items_native_export(mut runtime, '__itemsFileList', list_wrapper)!
	items_native_export(mut runtime, '__itemsFileItem', item_wrapper)!
	assert runtime.evaluate_host('__itemsFileItem().kind==="file"&&__itemsFileItem().type==="TEXT/PLAIN"&&__itemsFileItem().getAsFile({toString(){throw 0}})===null&&__itemsFileList().length===1')! == 'true'
	store.set_mode(.read_write)
	assert runtime.evaluate_host('(()=>{try{__itemsFileItem().getAsFile();return false}catch(error){return error.message==="File binding is unavailable"}})()')! == 'true'
	_ = items_native_install_files(mut runtime, document)!
	before := time.now().unix_milli()
	assert runtime.evaluate_host(r'(()=>{
 const item=__itemsFileItem(),first=item.getAsFile(),second=item.getAsFile(),third=__itemsFileTransfer().files[0];globalThis.itemsFileFirst=first;globalThis.itemsFileSecond=second;globalThis.itemsFileBytesDone=false;globalThis.itemsFilePromise=first.bytes();itemsFilePromise.then(bytes=>itemsFileBytesDone=bytes instanceof Uint8Array&&bytes.length===3&&bytes[0]===0&&bytes[1]===128&&bytes[2]===255);
 return first!==second&&first!==third&&second!==third&&first instanceof File&&first instanceof Blob&&first.name==="n\ud800\u0000\udc00"&&first.type==="text/plain"&&first.size===3&&itemsFilePromise instanceof Promise&&!itemsFileBytesDone;
})()')! == 'true'
	after := time.now().unix_milli()
	first_value := runtime.evaluate_host_value('itemsFileFirst')!
	first_file := runtime.native_file(first_value)!
	assert first_file.raw_bytes() == [u8(0), 128, 255]
	assert first_file.name_utf16().code_units() == name.code_units()
	assert first_file.last_modified() >= before && first_file.last_modified() <= after
	assert voidptr(runtime.native_blob(first_value)!) == voidptr(&first_file.Blob)
	assert voidptr(runtime.native_file(runtime.evaluate_host_value('itemsFileSecond')!)!) != voidptr(first_file)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	})?
	assert task.document() == settings.responsible_document()
	task.execute()
	assert runtime.evaluate_host('itemsFileBytesDone')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const list=__itemsFileList(),item=__itemsFileItem(),listPrototype=DataTransferItemList.prototype,itemPrototype=DataTransferItem.prototype,iterator=Array.prototype.values,getKind=Object.getOwnPropertyDescriptor(itemPrototype,"kind").get,getType=Object.getOwnPropertyDescriptor(itemPrototype,"type").get,getFile=itemPrototype.getAsFile,marker={};let gets=0;
 for(const name of ["kind","type","getAsFile","constructor","valueOf","toString"])Object.defineProperty(item,name,{get(){gets++;throw marker},configurable:true});for(const name of ["length","remove","clear","constructor"])Object.defineProperty(list,name,{get(){gets++;throw marker},configurable:true});Object.setPrototypeOf(item,null);
 globalThis.DataTransferItem=function ReplacementItem(){throw marker};globalThis.DataTransferItemList=function ReplacementList(){throw marker};globalThis.File=function ReplacementFile(){throw marker};globalThis.FileList=function ReplacementFileList(){throw marker};globalThis.Blob=function ReplacementBlob(){throw marker};Object.create=function ReplacementCreate(){throw marker};Object.defineProperty=function ReplacementDefine(){throw marker};globalThis.Proxy=function ReplacementProxy(){throw marker};Array.prototype.values=function ReplacementValues(){throw marker};
 const current=getFile.call(item);globalThis.itemsFileSavedGetter=getFile;Array.prototype[Symbol.iterator]=function AuthorIterator(){gets++;throw marker};const own=Reflect.ownKeys(list).join(",");return own==="0,length,remove,clear,constructor"&&__itemsFileTransfer().items===list&&list[0]===item&&getKind.call(item)==="file"&&getType.call(item)==="TEXT/PLAIN"&&current.name===itemsFileFirst.name&&Object.getPrototypeOf(list)===listPrototype&&listPrototype[Symbol.iterator]===iterator&&gets===0;
})()')! == 'true'
	mut foreign, mut foreign_document := items_native_fixture('https://transfer-items-foreign.example/')
	defer {
		foreign.close()
		foreign_document.finalize()
	}
	foreign_list := foreign.javascript_data_transfer_item_list(list)!
	foreign_item := foreign.javascript_data_transfer_item(item)!
	assert foreign.native_data_transfer_item_list(foreign_list)! == list
	assert foreign.native_data_transfer_item(foreign_item)! == item
	// Registry lookup never passes foreign JSC values into a C engine operation.
	if _ := runtime.native_data_transfer_item_list(foreign_list) { assert false }
	if _ := foreign.native_data_transfer_item_list(list_wrapper) { assert false }
	if _ := runtime.native_data_transfer_item(foreign_item) { assert false }
	if _ := foreign.native_data_transfer_item(item_wrapper) { assert false }
	items_native_assert_vm(runtime)
	items_native_assert_vm(foreign)
	runtime.close()
	assert runtime.closed
	if _ := runtime.native_data_transfer_item_list(list_wrapper) { assert false }
	if _ := runtime.native_data_transfer_item(item_wrapper) { assert false }
	if _ := runtime.javascript_data_transfer_item_list(list) { assert false }
	if _ := runtime.javascript_data_transfer_item(item) { assert false }
	assert first_file.raw_bytes() == [u8(0), 128, 255] && item.kind() == 'file'
	assert foreign.native_data_transfer_item(foreign_item)! == item
	runtime.close()
}
