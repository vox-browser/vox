module browserjs

import dom
import time

fn source_file_constructor_runtime() (&Runtime, &dom.Document) {
	mut runtime := Runtime.create()
	url := dom.URL{value: 'https://source-file-constructor.example.test/'}
	document := dom.Document.create(url)
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	files.install_constructor() or { panic(err) }
	return runtime, document
}

fn test_source_file_constructor_preserves_sequence_name_inherited_dictionary_order_and_copy_time() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_file_constructor_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	actual := runtime.evaluate_host_value(r'
globalThis.sourceFileConstructorOrder=[];
const buffer=new Uint8Array([1,2]);
const bits={*[Symbol.iterator](){sourceFileConstructorOrder.push("iterator");yield {toString(){sourceFileConstructorOrder.push("part");return String.fromCharCode(0xd800)}};yield buffer}};
const name={toString(){sourceFileConstructorOrder.push("name");buffer[0]=7;return "a/"+String.fromCharCode(0xd800)}};
const options={get endings(){sourceFileConstructorOrder.push("endings");return "native"},get type(){sourceFileConstructorOrder.push("type");buffer[0]=9;return "TeXT/PLAIN"},get lastModified(){sourceFileConstructorOrder.push("lastModified");return {valueOf(){sourceFileConstructorOrder.push("number");buffer[1]=10;return 45.9}}}};
globalThis.sourceConstructedFile=new File(bits,name,options);sourceConstructedFile
')!
	file := runtime.native_file(actual)!
	assert file.raw_bytes() == [u8(0xef), 0xbf, 0xbd, 9, 10]
	assert file.name() == 'a/�'
	assert file.type_() == 'text/plain'
	assert file.last_modified() == 45
	assert runtime.evaluate_host('sourceFileConstructorOrder.join(",")==="iterator,part,name,endings,type,lastModified,number"&&sourceConstructedFile instanceof File&&sourceConstructedFile instanceof Blob')! == 'true'
	detached := runtime.evaluate_host_value('const detachedBuffer=new ArrayBuffer(2);new Uint8Array(detachedBuffer).set([7,8]);new File([detachedBuffer],{toString(){detachedBuffer.transfer();return "detached"}},{lastModified:0})')!
	assert runtime.native_file(detached)!.raw_bytes().len == 0
	nested := runtime.evaluate_host_value('new File([sourceConstructedFile],undefined,{lastModified:0})')!
	assert runtime.native_file(nested)!.raw_bytes() == file.raw_bytes()
	assert runtime.native_file(nested)!.name() == 'undefined'
	assert runtime.evaluate_host('new File([],"name",{type:"text/plain;v=é",lastModified:0}).type===""')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_constructor_preserves_defaults_source_numeric_conversion_and_metadata() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_file_constructor_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	before := time.now().unix_milli()
	default_file := runtime.native_file(runtime.evaluate_host_value('Date.now=function(){throw "author date"};new File([],"default",null)')!)!
	after := time.now().unix_milli()
	assert default_file.last_modified() >= before
	assert default_file.last_modified() <= after
	assert runtime.evaluate_host('[NaN,Infinity,-Infinity,-0,-7,18446744073709551616].every(lastModified=>new File([],"number",{lastModified}).lastModified===0)&&new File([],"number",{lastModified:123.9}).lastModified===123')! == 'true'
	assert runtime.evaluate_host('globalThis.sourceFileNumericMarker={};let numericFailure=false;try{new File([],"name",{lastModified:{valueOf(){throw sourceFileNumericMarker}}})}catch(reason){numericFailure=reason===sourceFileNumericMarker}let bigint=false;try{new File([],"name",{lastModified:1n})}catch(reason){bigint=reason instanceof TypeError}numericFailure&&bigint')! == 'true'
	assert runtime.evaluate_host('const get=Object.getOwnPropertyDescriptor,global=get(globalThis,"File"),prototype=get(File,"prototype"),name=get(File,"name"),length=get(File,"length"),constructor=get(File.prototype,"constructor");Object.getPrototypeOf(File)===Blob&&Object.getPrototypeOf(File.prototype)===Blob.prototype&&global.value===File&&global.writable&&!global.enumerable&&global.configurable&&prototype.value===File.prototype&&!prototype.writable&&!prototype.enumerable&&!prototype.configurable&&name.value==="File"&&!name.writable&&!name.enumerable&&name.configurable&&length.value===2&&!length.writable&&!length.enumerable&&length.configurable&&constructor.value===File&&constructor.writable&&!constructor.enumerable&&constructor.configurable&&Reflect.ownKeys(File).length===3')! == 'true'
	assert runtime.evaluate_host('class ChildFile extends File{};const child=new ChildFile([],"name");function FileTarget(){}FileTarget.prototype=null;const fallback=Reflect.construct(File,[[],"name"],FileTarget);child instanceof ChildFile&&child instanceof File&&child instanceof Blob&&Object.getPrototypeOf(fallback)===File.prototype')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_constructor_preserves_required_argument_prototype_and_original_errors() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_file_constructor_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host('let withoutNew;try{File()}catch(reason){withoutNew=reason}let missing;try{new File([])}catch(reason){missing=reason}withoutNew instanceof TypeError&&withoutNew.message==="File constructor must be called with \'new\'"&&missing instanceof TypeError&&missing.message==="File() needs 2 arguments"')! == 'true'
	assert runtime.evaluate_host('globalThis.sourceFilePrototypeOrder=[];const target=new Proxy(function(){},{get(object,name){sourceFilePrototypeOrder.push(name);if(name==="prototype")return File.prototype;return Reflect.get(object,name)}});const bits={get [Symbol.iterator](){sourceFilePrototypeOrder.push("iterator");return function*(){}}};Reflect.construct(File,[bits,{toString(){sourceFilePrototypeOrder.push("name");return "name"}}],target);sourceFilePrototypeOrder.join(",")==="prototype,iterator,name"')! == 'true'
	assert runtime.evaluate_host('globalThis.sourceFileConstructorMarker={};globalThis.sourceFileIteratorClosed=false;const iterator={ [Symbol.iterator](){return this},next(){return {done:false,value:Symbol()}},return(){sourceFileIteratorClosed=true;return {done:true}}};let unionFailure=false;try{new File(iterator,"name")}catch(reason){unionFailure=reason instanceof TypeError}const calls=[()=>Reflect.construct(File,[[],"name"],new Proxy(function(){},{get(){throw sourceFileConstructorMarker}})),()=>new File(new Proxy({},{get(){throw sourceFileConstructorMarker}}),"name"),()=>new File([],{toString(){throw sourceFileConstructorMarker}}),()=>new File([],"name",{get endings(){throw sourceFileConstructorMarker}}),()=>new File([],"name",{get type(){throw sourceFileConstructorMarker}}),()=>new File([],"name",{get lastModified(){throw sourceFileConstructorMarker}})];unionFailure&&!sourceFileIteratorClosed&&calls.every(call=>{try{call();return false}catch(reason){return reason===sourceFileConstructorMarker}})')! == 'true'
	assert runtime.evaluate_host('[()=>new File(undefined,"name"),()=>new File(null,"name"),()=>new File([],Symbol()),()=>new File([],"name",1),()=>new File([],"name",{endings:"invalid"}),()=>new File([new Uint8Array(new ArrayBuffer(2,{maxByteLength:4}))],"name")].every(call=>{try{call();return false}catch(reason){return reason instanceof TypeError}})')! == 'true'
	assert runtime.evaluate_host(r'const invalidEnding=String.fromCharCode(0xd800,0,0xdc00);let endingFailure;try{new File([],"name",{endings:invalidEnding})}catch(reason){endingFailure=reason}endingFailure instanceof TypeError&&endingFailure.message==="Invalid value \u0027"+invalidEnding+"\u0027 for enumeration type \u0027EndingType\u0027"')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_constructor_installs_on_actual_global_and_inherits_retained_blob_constructor() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	mut document := dom.Document.create(dom.URL{value: 'https://source-file-global.example.test/'})
	defer {
		runtime.close()
		document.finalize()
	}
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := FileHost.create(document)!
	files.install(mut runtime)!
	runtime.evaluate_host('globalThis.sourceActualFileGlobal=globalThis;globalThis.sourceActualBlobConstructor=Blob;globalThis.Blob=function ForgedBlob(){};globalThis=new Proxy({},{defineProperty(){throw "author globalThis write"},get(){throw "author globalThis read"}});undefined')!
	files.install_constructor()!
	assert runtime.evaluate_host('sourceActualFileGlobal.File===File&&Object.getPrototypeOf(File)===sourceActualBlobConstructor&&new File(["source"],"name").size===6')! == 'true'
}
