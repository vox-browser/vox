module browserjs

import dom
import html
import highresolutiontime

fn transfer_native_settings(url string) &html.EnvironmentSettingsObject {
	document := html.parse_document_with_url('<!doctype html><body>Transfer store</body>', dom.URL{
		value: url
	})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time =
		highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-data-transfer') or { panic(err) }
	return unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
}

fn transfer_native_fixture(url string) (&Runtime, &html.EnvironmentSettingsObject) {
	settings := transfer_native_settings(url)
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn transfer_native_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn transfer_native_assert_vm_restored(runtime &Runtime) {
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_data_transfer_metadata_constructor_and_late_identity_upgrade() {
	$if !darwin { return }
	mut runtime, settings := transfer_native_fixture('https://native-transfer-metadata.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DataTransfer==="function"')! == 'true'
	constructor := runtime.evaluate_host_value('DataTransfer')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('DataTransfer')! == constructor
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},C=DataTransfer,p=C.prototype,global=Object.getOwnPropertyDescriptor(globalThis,"DataTransfer"),constructor=Object.getOwnPropertyDescriptor(p,"constructor");
 check(C.name==="DataTransfer"&&C.length===0&&Object.getPrototypeOf(C)===Function.prototype&&Object.getPrototypeOf(p)===Object.prototype&&global.writable&&global.configurable&&!global.enumerable&&!Object.getOwnPropertyDescriptor(C,"prototype").writable&&constructor.value===C&&constructor.writable&&constructor.configurable&&!constructor.enumerable,"constructor metadata");
 const tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag);check(tag.value==="DataTransfer"&&!tag.writable&&!tag.enumerable&&tag.configurable&&Object.getOwnPropertyNames(p).sort().join(",")==="clearData,constructor,dropEffect,effectAllowed,getData,setData,types","bounded own prototype members");
 for(const name of ["dropEffect","effectAllowed","types"]){const d=Object.getOwnPropertyDescriptor(p,name);check(d.enumerable&&d.configurable&&d.get.name==="get "+name&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]"),"native getter metadata");if(name==="types")check(d.set===undefined,"readonly types");else check(d.set.name==="set "+name&&d.set.length===1&&Function.prototype.toString.call(d.set).includes("[native code]"),"native setter metadata");for(const f of [d.get,d.set].filter(Boolean)){let rejected=false;try{Reflect.construct(function Empty(){},[],f)}catch(error){rejected=error instanceof TypeError}check(rejected,"accessor is not constructor")}}
 for(const [name,length] of [["getData",1],["setData",2],["clearData",0]]){const d=Object.getOwnPropertyDescriptor(p,name);check(d.writable&&d.enumerable&&d.configurable&&d.value.name===name&&d.value.length===length&&Function.prototype.toString.call(d.value).includes("[native code]"),"native operation metadata");let rejected=false;try{Reflect.construct(function Empty(){},[],d.value)}catch(error){rejected=error instanceof TypeError}check(rejected,"operation is not constructor")}
 let ignored=0;const extra=new Proxy({},{get(){ignored++;throw 0},getPrototypeOf(){ignored++;throw 0}}),value=new C(extra,Symbol("ignored")),other=new C();class Child extends C{}const child=new Child(extra);
 check(value!==other&&value instanceof C&&child instanceof Child&&child instanceof C&&Object.getPrototypeOf(child)===Child.prototype&&Object.prototype.toString.call(value)==="[object DataTransfer]"&&Object.getOwnPropertyNames(value).length===0&&value.dropEffect==="none"&&value.effectAllowed==="none"&&value.types.length===0&&value.getData("text")===""&&!Reflect.set(value,"types",[])&&ignored===0,"fresh native defaults and ignored arguments");
 let callRejected=false;try{C()}catch(error){callRejected=error instanceof TypeError}check(callRejected,"constructor requires new");
 const Alternative=function Alternative(){};for(const prototype of [null,1,undefined]){Alternative.prototype=prototype;check(Object.getPrototypeOf(Reflect.construct(C,[extra],Alternative))===p,"primitive prototype fallback")}const callablePrototype=function CallablePrototype(){};Alternative.prototype=callablePrototype;const callable=Reflect.construct(C,[extra],Alternative);check(Object.getPrototypeOf(callable)===callablePrototype&&p.getData.call(callable,"text")==="","callable requested prototype");
 let reads=0;const custom=Object.create(p),next=new Proxy(function Next(){},{get(target,name,receiver){if(name==="prototype"){reads++;return custom}return Reflect.get(target,name,receiver)}}),made=Reflect.construct(C,[extra],next);check(reads===1&&Object.getPrototypeOf(made)===custom&&made.getData("text")===""&&ignored===0,"single newTarget prototype Get");
 const marker={},throwing=new Proxy(function Throwing(){},{get(target,name,receiver){if(name==="prototype"){reads++;throw marker}return Reflect.get(target,name,receiver)}});let same=false;try{Reflect.construct(C,[extra],throwing)}catch(error){same=error===marker}check(same&&reads===2&&ignored===0,"original prototype exception before ignored arguments");globalThis.nativeConstructedTransfer=value;return true;
})()')! == 'true'
	actual := runtime.native_data_transfer(runtime.evaluate_host_value('nativeConstructedTransfer')!)!
	assert actual.mode()? == .read_write && actual.length() == 0
	assert actual.drop_effect() == 'none' && actual.effect_allowed() == 'none'
	mut late := Runtime.create()
	defer { late.close() }
	late.install_event_target_binding()!
	assert late.evaluate_host('typeof DataTransfer==="undefined"')! == 'true'
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text/plain', 'wrapped before Window attachment')
	wrapper := late.javascript_data_transfer(transfer)!
	transfer_native_export(mut late, '__lateNativeTransfer', wrapper)!
	assert late.evaluate_host('globalThis.retainedTransferGlobal=globalThis;globalThis.latePrivateTransfer=__lateNativeTransfer();globalThis.latePrivatePrototype=Object.getPrototypeOf(latePrivateTransfer);Object.getOwnPropertyNames(latePrivatePrototype).length===0&&Object.prototype.toString.call(latePrivateTransfer)==="[object DataTransfer]"')! == 'true'
	assert late.libjs_vm().execution_context_stack().len == 1
	assert voidptr(late.libjs_vm().running_execution_context()) == voidptr(late.realm_context)
	late.evaluate_host('DataTransfer=function BeforeWindowReplacement(){};globalThis={};0')!
	late_settings := transfer_native_settings('http://late-transfer-metadata.example/')
	late.bind_scripting_environment(late_settings)!
	late.install_event_target_binding()!
	assert !late_settings.is_secure_context()
	assert late.javascript_data_transfer(transfer)! == wrapper
	assert late.native_data_transfer(wrapper)! == transfer
	assert late.evaluate_host('typeof DataTransfer==="function"&&retainedTransferGlobal.DataTransfer===DataTransfer&&globalThis.DataTransfer===undefined&&latePrivateTransfer===__lateNativeTransfer()&&Object.getPrototypeOf(latePrivateTransfer)===DataTransfer.prototype&&latePrivateTransfer instanceof DataTransfer&&latePrivateTransfer.getData("text")==="wrapped before Window attachment"&&new DataTransfer().types.length===0')! == 'true'
	late_constructor := late.evaluate_host_value('DataTransfer')!
	late.install_event_target_binding()!
	assert late.evaluate_host_value('DataTransfer')! == late_constructor
	assert settings.realm().reported_exceptions.len == 0
	assert late_settings.realm().reported_exceptions.len == 0
	transfer_native_assert_vm_restored(runtime)
	transfer_native_assert_vm_restored(late)
}

fn test_native_data_transfer_string_conversions_effect_validation_and_utf16_store() {
	$if !darwin { return }
	mut runtime, settings := transfer_native_fixture('https://native-transfer-strings.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DataTransfer==="function"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=new DataTransfer(),order=[],marker={},convert=(name,value)=>({[Symbol.toPrimitive](hint){order.push(name+":"+hint);return value}});
 check(t.setData(convert("format","TeXt"),convert("data","λ\u0000\ud800\udc00\udfff"))===undefined&&order.join(",")==="format:string,data:string"&&t.getData(convert("lookup","TEXT"))==="λ\u0000\ud800\udc00\udfff"&&order.join(",")==="format:string,data:string,lookup:string"&&t.types.join(",")==="text/plain","ordered DOMString conversions and raw UTF16 text");
 t.setData("X\u0000A\ud800","first");t.setData("x\u0000a\ud800","second");check(t.types[1]==="X\u0000A\ud800"&&t.types[2]==="x\u0000a\ud800"&&t.getData("x\u0000A\ud800")==="first","storage preserves case and lookup folds ASCII only");t.setData("X\u0000A\ud800","replacement");check(t.types[1]==="x\u0000a\ud800"&&t.types[2]==="X\u0000A\ud800"&&t.getData("X\u0000a\ud800")==="second","exact-case replacement removes then appends");t.clearData("x\u0000A\ud800");check(t.types.length===1,"clear removes every ASCII-case match");
 t.setData("Ä","upper");t.setData("ä","lower");check(t.getData("Ä")==="upper"&&t.getData("ä")==="lower","Unicode case remains distinct");t.clearData("Ä");check(t.getData("Ä")===""&&t.getData("ä")==="lower","nonASCII clear is exact");
 const uri="# comment\r\nhttps://first.example/\r\nhttps://second.example/";t.setData("UrL",uri);check(t.types.includes("text/uri-list")&&t.getData("URL")===uri&&t.getData("TEXT/URI-LIST")===uri,"upstream URI-list parsing FIXME preserves whole text");
 t.setData(null,undefined);t.setData(undefined,null);check(t.getData("null")==="undefined"&&t.getData(undefined)==="null","null and explicit undefined DOMStrings");t.clearData(null);check(t.getData("null")===""&&t.getData("undefined")==="null","optional null format is converted");
 const before=t.types;let firstSame=false,secondSame=false,later=0;try{t.setData({toString(){throw marker}},{toString(){later++;return "never"}})}catch(error){firstSame=error===marker}try{t.setData("not-added",{toString(){throw marker}})}catch(error){secondSame=error===marker}check(firstSame&&secondSame&&later===0&&t.getData("not-added")===""&&t.types===before,"conversion exceptions are original and atomic");
 for(const invoke of [()=>t.getData(Symbol("format")),()=>t.setData(Symbol("format"),"never"),()=>t.setData("never",Symbol("data")),()=>t.clearData(Symbol("format"))]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}check(rejected,"Symbol DOMString rejects")}check(t.types===before,"failed conversions retain type cache");
 for(const value of ["none","copy","link","move"]){t.dropEffect=convert("drop",value);check(t.dropEffect===value,"valid drop effect")}for(const value of ["COPY","copy\u0000","λ",null,undefined,1]){t.dropEffect=value;check(t.dropEffect==="move","invalid drop ignored")}
 for(const value of ["none","copy","copyLink","copyMove","link","linkMove","move","all","uninitialized"]){t.effectAllowed=convert("allowed",value);check(t.effectAllowed===value,"valid allowed effect")}for(const value of ["COPY","copylink","all\u0000",null,undefined,1]){t.effectAllowed=value;check(t.effectAllowed==="uninitialized","invalid allowed ignored")}
 for(const name of ["dropEffect","effectAllowed"]){const d=Object.getOwnPropertyDescriptor(DataTransfer.prototype,name);let same=false;try{d.set.call(t,{toString(){throw marker}})}catch(error){same=error===marker}check(same,"original effect setter error");let rejected=false;try{d.set.call(t,Symbol(name))}catch(error){rejected=error instanceof TypeError}check(rejected,"effect setter Symbol rejects")}
 check(t.types===before&&order.every(value=>value.endsWith(":string")),"effects do not revise types and conversions use string hint");t.clearData(undefined);check(t.types.length===0,"optional undefined behaves as missing");t.setData("text","after clear");check(t.getData("TEXT")==="after clear"&&t.clearData()===undefined&&t.types.length===0,"clear without arguments");globalThis.nativeStringTransfer=t;return true;
})()')! == 'true'
	actual := runtime.native_data_transfer(runtime.evaluate_host_value('nativeStringTransfer')!)!
	assert actual.mode()? == .read_write && actual.length() == 0
	assert actual.drop_effect() == 'move' && actual.effect_allowed() == 'uninitialized'
	assert settings.realm().reported_exceptions.len == 0
	transfer_native_assert_vm_restored(runtime)
}

fn test_native_data_transfer_receiver_brand_precedes_arity_and_author_conversion() {
	$if !darwin { return }
	mut runtime, settings := transfer_native_fixture('https://native-transfer-brands.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DataTransfer==="function"')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},p=DataTransfer.prototype,t=new DataTransfer(),marker={},coercible={[Symbol.toPrimitive](){conversions++;throw marker}};let conversions=0,traps=0;
 const proxy=new Proxy(t,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker},has(){traps++;throw marker}}),receivers=[Object.create(p),proxy,{},[],new Event("event"),new DragEvent("drag"),null,undefined,1,true,"transfer",1n,Symbol("transfer")];
 for(const receiver of receivers){for(const name of ["dropEffect","effectAllowed","types"]){const d=Object.getOwnPropertyDescriptor(p,name);let rejected=false;try{d.get.call(receiver,coercible)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransfer"}check(rejected,"getter receiver brand");if(d.set){rejected=false;try{d.set.call(receiver,coercible)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransfer"}check(rejected,"setter receiver brand")}}for(const name of ["getData","setData","clearData"]){for(const args of [[],[coercible,coercible]]){let rejected=false;try{Reflect.apply(p[name],receiver,args)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransfer"}check(rejected,"operation brand before arity and conversions")}}}
 check(traps===0&&conversions===0,"receiver checks never inspect Proxy or author slots");let missing=0;for(const invoke of [()=>t.getData(),()=>t.setData(),()=>t.setData(coercible)])try{invoke()}catch(error){if(error instanceof TypeError)missing++}check(missing===3&&conversions===0,"required argument count before conversions");
 for(const name of ["dropEffect","effectAllowed"]){const d=Object.getOwnPropertyDescriptor(p,name),before=d.get.call(t);check(d.set.call(t)===undefined&&d.get.call(t)===before,"missing setter value becomes undefined");check(d.get.call(t,coercible)===before,"getter ignores extras")}
 check(t.getData(undefined)===""&&t.setData(undefined,undefined)===undefined&&t.getData("undefined")==="undefined","explicit undefined required arguments convert");check(t.clearData(undefined,coercible)===undefined&&t.types.length===0&&conversions===0,"optional missing format and ignored extras");t.setData("text","retained",coercible);check(t.getData("text",coercible)==="retained"&&conversions===0,"method extras ignored");
 let same=false;try{t.getData(coercible)}catch(error){same=error===marker}check(same&&conversions===1,"genuine receiver reaches original author conversion");return true;
})()')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	transfer_native_assert_vm_restored(runtime)
}

fn test_native_data_transfer_types_revision_modes_and_live_native_mutations() {
	$if !darwin { return }
	mut runtime, settings := transfer_native_fixture('https://native-transfer-types.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DataTransfer==="function"')! == 'true'
	mut store := html.DragDataStore.create()
	store.set_mode(.read_write)
	mut transfer := html.DataTransfer.create(store)
	transfer.set_data('TeXt/Plain', 'native first')
	transfer.add_item(html.DragDataStoreItem{ kind: .file, type_string: 'image/png',
		data: [u8(1), 2], file_name: 'first.png' })
	transfer.add_item(html.DragDataStoreItem{ kind: .file, type_string: 'image/png',
		data: [u8(3)], file_name: 'second.png' })
	wrapper := runtime.javascript_data_transfer(transfer)!
	transfer_native_export(mut runtime, '__nativeTypesTransfer', wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=__nativeTypesTransfer(),snapshot=t.types;check(Array.isArray(snapshot)&&Object.getPrototypeOf(snapshot)===Array.prototype&&Object.isFrozen(snapshot)&&snapshot===t.types&&snapshot.join(",")==="TeXt/Plain,Files"&&Object.getOwnPropertyDescriptor(snapshot,"0").writable===false&&!Reflect.set(snapshot,"0","changed")&&!Reflect.deleteProperty(snapshot,"0"),"frozen ordered cached native types");
 let rejected=false;try{snapshot.push("never")}catch(error){rejected=error instanceof TypeError}check(rejected&&snapshot.join(",")==="TeXt/Plain,Files","frozen array mutation fails");t.dropEffect="copy";t.effectAllowed="all";t.clearData("missing");check(t.types===snapshot,"no-op and effect changes retain revision");globalThis.nativeTypesInitial=snapshot;return true;
})()')! == 'true'
	transfer.set_data('text/html', '<b>added natively</b>')
	assert runtime.evaluate_host('(()=>{const t=__nativeTypesTransfer(),next=t.types;globalThis.nativeTypesAdded=next;return next!==nativeTypesInitial&&next===t.types&&Object.isFrozen(next)&&next.join(",")==="TeXt/Plain,text/html,Files"&&nativeTypesInitial.join(",")==="TeXt/Plain,Files"&&t.getData("TEXT/PLAIN")==="native first"})()')! == 'true'
	transfer.set_data('text/html', '<b>added natively</b>')
	assert runtime.evaluate_host('(()=>{const t=__nativeTypesTransfer();globalThis.nativeTypesReplaced=t.types;return nativeTypesReplaced!==nativeTypesAdded&&nativeTypesReplaced.join(",")===nativeTypesAdded.join(",")})()')! == 'true'
	store.set_mode(.protected)
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},t=__nativeTypesTransfer(),before=t.types,order=[];check(before===nativeTypesReplaced&&t.getData("text")==="","protected data hidden, types visible");t.setData({toString(){order.push("format");return "new"}},{toString(){order.push("data");return "blocked"}});t.clearData({toString(){order.push("clear");return "text"}});t.effectAllowed={toString(){order.push("allowed");return "move"}};t.dropEffect={toString(){order.push("drop");return "link"}};check(order.join(",")==="format,data,clear,allowed,drop"&&t.types===before&&t.effectAllowed==="all"&&t.dropEffect==="link","conversions precede protected no-op and drop remains writable");return true;
})()')! == 'true'
	assert transfer.get_data('text/html') == '' && transfer.length() == 4
	store.set_mode(.read_only)
	assert runtime.evaluate_host('(()=>{const t=__nativeTypesTransfer(),before=t.types;const readable=t.getData("TEXT/HTML");t.setData("text/html","blocked");t.clearData();t.effectAllowed="none";return readable==="<b>added natively</b>"&&t.getData("text/html")===readable&&t.types===before&&t.effectAllowed==="all"})()')! == 'true'
	store.set_mode(.read_write)
	assert runtime.evaluate_host('(()=>{const t=__nativeTypesTransfer();t.clearData();globalThis.nativeTypesFiles=t.types;return t.types!==nativeTypesReplaced&&t.types.join(",")==="Files"&&Object.isFrozen(t.types)})()')! == 'true'
	assert transfer.length() == 2
	transfer.remove_item(0)
	assert runtime.evaluate_host('(()=>{const t=__nativeTypesTransfer();globalThis.nativeTypesOneFile=t.types;return t.types!==nativeTypesFiles&&t.types.join(",")==="Files"&&nativeTypesFiles.join(",")==="Files"})()')! == 'true'
	transfer.disassociate_with_drag_data_store()
	assert runtime.evaluate_host('(()=>{const t=__nativeTypesTransfer(),before=t.types;t.setData("text","blocked");t.clearData();t.effectAllowed="none";t.dropEffect="move";return before!==nativeTypesOneFile&&before===t.types&&Object.isFrozen(before)&&before.length===0&&t.getData("text")===""&&t.effectAllowed==="all"&&t.dropEffect==="move"&&nativeTypesInitial.join(",")==="TeXt/Plain,Files"})()')! == 'true'
	assert transfer.mode() == none && transfer.length() == 0
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	assert settings.realm().reported_exceptions.len == 0
	transfer_native_assert_vm_restored(runtime)
}

fn test_native_data_transfer_retained_wrappers_drag_identity_foreign_owners_and_close() {
	$if !darwin { return }
	mut runtime, settings := transfer_native_fixture('https://native-transfer-owners.example/')
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof DataTransfer==="function"')! == 'true'
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text/plain', 'one actual native store')
	wrapper := runtime.javascript_data_transfer(transfer)!
	transfer_native_export(mut runtime, '__nativeOwnedTransfer', wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const check=(condition,label)=>{if(!condition)throw new Error(label)},C=DataTransfer,p=C.prototype,t=__nativeOwnedTransfer(),get=Object.getOwnPropertyDescriptor(p,"types").get,read=p.getData,write=p.setData,first=new DragEvent("first",{dataTransfer:t}),second=new DragEvent("second",{dataTransfer:t}),oldTypes=get.call(t),arrayPrototype=Array.prototype,marker={};let authorGets=0;
 for(const name of ["constructor","dropEffect","effectAllowed","types","getData","setData","clearData","items","files","valueOf","toString"])Object.defineProperty(t,name,{get(){authorGets++;throw marker},configurable:true});Object.defineProperty(t,Symbol.toPrimitive,{get(){authorGets++;throw marker},configurable:true});t.__implementationId="forged author id";Object.setPrototypeOf(t,null);
 globalThis.DataTransfer=function ReplacementDataTransfer(){throw marker};globalThis.Array=function ReplacementArray(){throw marker};Object.freeze=function ReplacementFreeze(){throw marker};Object.create=function ReplacementCreate(){throw marker};Object.defineProperty=function ReplacementDefine(){throw marker};
 write.call(t,"text/html","retained write");const next=get.call(t),fresh=new C();check(first.dataTransfer===t&&second.dataTransfer===t&&__nativeOwnedTransfer()===t&&read.call(t,"text")==="one actual native store"&&read.call(t,"TEXT/HTML")==="retained write"&&next!==oldTypes&&Object.isFrozen(next)&&Object.getPrototypeOf(next)===arrayPrototype&&Object.getPrototypeOf(fresh)===p&&fresh.getData("text")===""&&authorGets===0,"retained factories and brand records ignore replaced public globals and author slots");globalThis.nativeOwnedTypes=next;globalThis.nativeOwnedGetter=get;globalThis.nativeOwnedRead=read;globalThis.nativeOwnedDrag=first;return true;
})()')! == 'true'
	assert runtime.native_data_transfer(wrapper)! == transfer
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	actual_drag := runtime.native_event(runtime.evaluate_host_value('nativeOwnedDrag')!)!
	drag := unsafe { &html.DragEvent(actual_drag) }
	assert drag.data_transfer() or { panic('missing native transfer on DragEvent') } == transfer
	mut foreign, foreign_settings := transfer_native_fixture('https://foreign-transfer-owner.example/')
	defer { foreign.close() }
	foreign_wrapper := foreign.javascript_data_transfer(transfer)!
	assert foreign_wrapper != wrapper
	assert foreign.native_data_transfer(foreign_wrapper)! == transfer
	if _ := runtime.native_data_transfer(foreign_wrapper) {
		assert false, 'accepted a foreign Runtime DataTransfer wrapper'
	}
	if _ := foreign.native_data_transfer(wrapper) {
		assert false, 'foreign Runtime accepted the original owner wrapper'
	}
	transfer_native_export(mut foreign, '__foreignActualTransfer', foreign_wrapper)!
	first_array := runtime.evaluate_host_value('nativeOwnedGetter.call(__nativeOwnedTransfer())')!
	foreign_array := foreign.evaluate_host_value('__foreignActualTransfer().types')!
	assert first_array != foreign_array
	assert foreign.evaluate_host('__foreignActualTransfer().types===__foreignActualTransfer().types&&Object.isFrozen(__foreignActualTransfer().types)&&__foreignActualTransfer().getData("text/html")==="retained write"&&Object.getPrototypeOf(__foreignActualTransfer())===DataTransfer.prototype')! == 'true'
	transfer.set_data('application/native', 'mutated through original V record')
	assert runtime.evaluate_host('nativeOwnedGetter.call(__nativeOwnedTransfer())!==nativeOwnedTypes&&nativeOwnedGetter.call(__nativeOwnedTransfer()).join(",")==="text/plain,text/html,application/native"&&nativeOwnedRead.call(__nativeOwnedTransfer(),"APPLICATION/NATIVE")==="mutated through original V record"&&nativeOwnedDrag.dataTransfer===__nativeOwnedTransfer()')! == 'true'
	assert foreign.evaluate_host('__foreignActualTransfer().types.join(",")==="text/plain,text/html,application/native"&&__foreignActualTransfer().getData("APPLICATION/NATIVE")==="mutated through original V record"')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert foreign_settings.realm().reported_exceptions.len == 0
	transfer_native_assert_vm_restored(runtime)
	transfer_native_assert_vm_restored(foreign)
	binding := runtime.event_binding()!
	assert binding.data_transfers.len >= 1 && binding.data_transfer_wrappers.len >= 1
	runtime.close()
	assert binding.closed && binding.data_transfers.len == 0 && binding.data_transfer_wrappers.len == 0
	if _ := runtime.native_data_transfer(wrapper) {
		assert false, 'closed Runtime retained DataTransfer receiver brand'
	}
	if _ := runtime.javascript_data_transfer(transfer) {
		assert false, 'closed Runtime created DataTransfer wrapper'
	}
	assert transfer.get_data('application/native') == 'mutated through original V record'
	assert foreign.evaluate_host('__foreignActualTransfer().getData("application/native")==="mutated through original V record"')! == 'true'
	runtime.close()
	assert binding.closed && binding.data_transfers.len == 0 && binding.data_transfer_wrappers.len == 0
}
