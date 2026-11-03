module main

import browserjs
import css
import dom
import html

fn adopted_binding_test_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://adopted.test/'}
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn test_compact_adopted_stylesheets_are_live_native_arrays_in_document_and_shadow_scopes() {
	mut document := adopted_binding_test_document('<!doctype html><div id="target">text</div><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 const list=document.adoptedStyleSheets;
 if(!Array.isArray(list)||list!==document.adoptedStyleSheets||list.length||[...list].length)throw Error("empty native observable array");
 const first=new CSSStyleSheet(),second=new CSSStyleSheet();
 first.replaceSync("#target {color: red} .inside {color: green}");second.replaceSync("#target {color: blue}");
 document.adoptedStyleSheets=[first];
 if(list!==document.adoptedStyleSheets||list[0]!==first||getComputedStyle(target).color!=="rgb(255, 0, 0)")throw Error("adopted document cascade");
 if(list.push(second)!==2||getComputedStyle(target).color!=="rgb(0, 0, 255)")throw Error("push cascade/order");
 if(list.pop()!==second||list.length!==1||getComputedStyle(target).color!=="rgb(255, 0, 0)")throw Error("pop cascade");
 list[0]=second;
 if(list[0]!==second||getComputedStyle(target).color!=="rgb(0, 0, 255)")throw Error("indexed replacement");
 const shadow=host.attachShadow({mode:"open"});shadow.innerHTML="<span class=inside>shadow</span>";
 const shadowList=shadow.adoptedStyleSheets;
 if(shadowList===list||shadowList!==shadow.adoptedStyleSheets||shadowList.length)throw Error("root-local list identity");
 shadowList.push(first);
 if(getComputedStyle(shadow.firstChild).color!=="rgb(0, 128, 0)"||getComputedStyle(target).color!=="rgb(0, 0, 255)")throw Error("scoped adoption");
 first.replaceSync("#target {color: red} .inside {color: purple}");
 if(getComputedStyle(shadow.firstChild).color!=="rgb(128, 0, 128)")throw Error("adopted sheet edit invalidation");
 list.length=0;
 if(list.length||getComputedStyle(target).color==="rgb(0, 0, 255)")throw Error("length removal");
 shadow.adoptedStyleSheets=[];
 if(shadowList.length||getComputedStyle(shadow.firstChild).color==="rgb(128, 0, 128)")throw Error("shadow removal");
 globalThis.retainedAdopted=first;globalThis.rootList=list;
 document.adoptedStyleSheets=[first,first];list.pop();
 first.replaceSync("#target {color: teal}");
 if(list.length!==1||getComputedStyle(target).color!=="rgb(0, 128, 128)")throw Error("duplicate owner survives removal");
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
	mut list := css.create_adopted_style_sheets_list(document.as_node())
	assert list.length() == 1
	mut sheet := list.item(0)?
	assert sheet.owning_documents_or_shadow_roots.len == 1
	sheet.replace_sync('#target { color: maroon }')!
	assert runtime.evaluate_host('rootList===document.adoptedStyleSheets&&rootList[0]===retainedAdopted&&getComputedStyle(target).color==="rgb(128, 0, 0)"')! == 'true'
	list.clear()
	assert runtime.evaluate_host('rootList.length===0&&rootList[0]===undefined&&!(0 in rootList)')! == 'true'
}

fn test_compact_adopted_stylesheets_validate_arrays_receivers_and_partial_iterable_replacement() {
	mut document := adopted_binding_test_document('<!doctype html><style id="inline">div {color: red}</style><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 function expect(name,call){let caught=false;try{call()}catch(error){caught=error.name===name;if(name==="NotAllowedError")caught=caught&&error instanceof DOMException}if(!caught)throw Error("Expected "+name);}
 const descriptor=Object.getOwnPropertyDescriptor(Document.prototype,"adoptedStyleSheets"),shadowDescriptor=Object.getOwnPropertyDescriptor(ShadowRoot.prototype,"adoptedStyleSheets");
 if(!descriptor.enumerable||!descriptor.configurable||!descriptor.get||!descriptor.set)throw Error("attribute descriptors");
 let converted=false;const iterable={[Symbol.iterator](){converted=true;throw Error("must not run")}};
 expect("TypeError",()=>descriptor.get.call({}));expect("TypeError",()=>descriptor.set.call({},iterable));expect("TypeError",()=>shadowDescriptor.get.call(document));
 if(converted)throw Error("conversion before receiver brand");
 const sheet=new CSSStyleSheet(),other=new CSSStyleSheet();document.adoptedStyleSheets=[sheet,other];const list=document.adoptedStyleSheets;
 const index=Object.getOwnPropertyDescriptor(list,"0"),length=Object.getOwnPropertyDescriptor(list,"length");
 if(!index.configurable||!index.enumerable||!index.writable||index.value!==sheet||length.configurable||length.enumerable||!length.writable||length.value!==2||Object.keys(list).join(",")!=="0,1")throw Error("observable property descriptors");
 if(Reflect.set(list,"4",{})||Reflect.set(list,"length",3)||Reflect.deleteProperty(list,"0")||Reflect.deleteProperty(list,"length")||Reflect.preventExtensions(list))throw Error("observable invariants");
 if(Reflect.defineProperty(list,"0",{writable:false})||Reflect.defineProperty(list,"length",{writable:false})||Reflect.defineProperty(list,"1",{get(){return sheet}}))throw Error("descriptor restrictions");
 expect("RangeError",()=>{list.length=1.5});expect("TypeError",()=>{list.length=1n});expect("TypeError",()=>{list[0]={}});
 expect("NotAllowedError",()=>{list.push(inline.sheet)});
 if(list.length!==2||list[0]!==sheet||list[1]!==other)throw Error("failed conversion changed backing values");
 if(!Reflect.defineProperty(list,"0",{value:other})||list[0]!==other||!Reflect.deleteProperty(list,"1")||list.length!==1)throw Error("valid descriptor or delete");
 list.extra="ordinary";if(list.extra!=="ordinary"||!Reflect.ownKeys(list).includes("extra"))throw Error("ordinary properties");
 const detached=document.implementation.createHTMLDocument("other document");
 expect("NotAllowedError",()=>{detached.adoptedStyleSheets=[sheet]});
 if(detached.adoptedStyleSheets.length)throw Error("cross-document adoption");
 const marker={};let closed=false;
 const partial={[Symbol.iterator](){let i=0;return {next(){if(i++===0)return {value:sheet,done:false};throw marker},return(){closed=true;return {done:true}}}}};
 let same=false;try{document.adoptedStyleSheets=partial}catch(error){same=error===marker}
 if(!same||closed||list.length!==1||list[0]!==sheet)throw Error("upstream partial iterable semantics");
 expect("TypeError",()=>{document.adoptedStyleSheets=[sheet,{}]});
 if(list.length!==1||list[0]!==sheet)throw Error("partial converted sequence");
 expect("TypeError",()=>{document.adoptedStyleSheets=null});
 if(list.length)throw Error("upstream clear precedes GetIterator");
 const shadow=host.attachShadow({mode:"open"}),OriginalProxy=globalThis.Proxy,OriginalTypeError=globalThis.TypeError,OriginalRangeError=globalThis.RangeError;
 try{
  globalThis.Proxy=globalThis.TypeError=globalThis.RangeError=function(){throw marker};
  shadow.adoptedStyleSheets=[sheet];const captured=shadow.adoptedStyleSheets;
  if(!Array.isArray(captured)||captured[0]!==sheet)throw Error("captured array constructor");
  expect("TypeError",()=>{captured[0]={}});expect("RangeError",()=>{captured.length=1.5});
 }finally{globalThis.Proxy=OriginalProxy;globalThis.TypeError=OriginalTypeError;globalThis.RangeError=OriginalRangeError;}
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
}
