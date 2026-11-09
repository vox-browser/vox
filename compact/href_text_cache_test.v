module main

import browserjs

fn href_text_cache_fixture(script string) !string {
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	return runtime.evaluate_host(r'(function(){
const __elementApply=Reflect.apply,document={},__state={location:"https://base.test/a/"};
const __compactNativeAttributes={
 read(state,name){return Object.prototype.hasOwnProperty.call(state.attributes,name)?state.attributes[name]:null;},
 contains(state,name){return Object.prototype.hasOwnProperty.call(state.attributes,name);},
 write(state,name,value){state.attributes[name]=value;}
};
let owner=document,ownerReads=0,nativeReads=0,constructorReads=0,reports=0,failed=false;
function NativeURL(value,base){this.value=value;this.base=base;}
const getter=function(){return "fallback:"+this.base+"|"+this.value;};
Object.defineProperty(NativeURL.prototype,"href",{get:getter,configurable:true});
globalThis.URL=NativeURL;
globalThis.__ladybirdSerializeURLText=function(value,base){nativeReads++;return failed||typeof value!=="string"||typeof base!=="string"?null:base+"|"+value;};
Object.defineProperties(__ladybirdSerializeURLText,{nativeConstructor:{value:NativeURL},nativePrototype:{value:NativeURL.prototype},nativeHrefGetter:{value:getter},reportCacheHit:{value:()=>{reports++;}}});
function __compactOwnerDocument(){ownerReads++;return owner;}
function __queryElements(){return "foreign";}
' + compact_href_text_bootstrap() + r'
const state={bridgeKey:"anchor",namespaceURI:"http://www.w3.org/1999/xhtml",tagName:"a",attributes:{href:"child"}},object={};
Object.defineProperty(object,"href",{get(){return "original";},set(value){state.attributes.href=value;},configurable:true});
__compactHrefTextBindings(object,state);
' + script + '})()')
}

fn test_href_text_cache_reuses_only_matching_raw_inputs_and_preserves_owner_constructor_reads() {
	assert href_text_cache_fixture(r'
Object.defineProperty(globalThis,"URL",{get(){constructorReads++;return NativeURL;},configurable:true});
for(let i=0;i<1000;i++)if(object.href!=="https://base.test/a/|child")throw 1;
if(reports!==(__hrefTextCacheEnabled?1:0))throw new Error("report count");
if(ownerReads!==1000||constructorReads!==1000||nativeReads!==(' + if retain_uncached_href_text {
		'1000'
	} else {
		'1'
	} + r'))throw new Error("read counts");
state.attributes.href="other";if(object.href!=="https://base.test/a/|other")throw 2;
__state.location="https://changed.test/";if(object.href!=="https://changed.test/|other")throw 3;
owner={};if(object.href!=="foreign")throw 4;owner=document;
delete state.attributes.href;if(object.href!=="")throw 5;
return "exact";
')! == 'exact'
}

fn test_href_text_cache_retains_constructor_and_getter_authentication_and_does_not_cache_failure() {
	assert href_text_cache_fixture(r'
if(object.href!=="https://base.test/a/|child")throw 1;
globalThis.URL=function(){this.href="custom";};if(object.href!=="custom")throw 2;
globalThis.URL=NativeURL;
Object.defineProperty(NativeURL.prototype,"href",{get(){return "custom getter";},configurable:true});if(object.href!=="custom getter")throw 3;
Object.defineProperty(NativeURL.prototype,"href",{value:"custom value",configurable:true});if(object.href!=="custom value")throw 4;
Object.defineProperty(NativeURL.prototype,"href",{get:getter,configurable:true});
failed=true;state.attributes.href="invalid";const before=nativeReads;
for(let i=0;i<3;i++)if(object.href!=="fallback:https://base.test/a/|invalid")throw 5;
if(nativeReads!==before+3)throw 6;
return "exact";
')! == 'exact'
}

fn test_href_text_cache_admission_bounds_entries_and_logical_code_units() {
	assert href_text_cache_fixture(r'
for(let i=0;i<600;i++){state.attributes.href="entry-"+i;if(object.href!==__state.location+"|entry-"+i)throw 1;}
if(__hrefTextCacheEntries>256||__hrefTextCacheUnits>262144)throw 2;
let before=nativeReads;state.attributes.href="entry-0";object.href;if(nativeReads!==before+(__hrefTextCacheEnabled?0:1))throw 3;
for(let i=0;i<256;i++){state.attributes.href="entry-"+i;__state.location="x".repeat(1800);object.href;}
if(__hrefTextCacheEntries>256||__hrefTextCacheUnits>262144)throw 4;
state.attributes.href="x".repeat(2049);before=nativeReads;object.href;object.href;if(nativeReads!==before+2)throw 5;
state.attributes.href="short";__state.location="x".repeat(2049);before=nativeReads;object.href;object.href;if(nativeReads!==before+2)throw 6;
state.attributes.href="x".repeat(2048);__state.location="y".repeat(2048);before=nativeReads;object.href;object.href;if(nativeReads!==before+2)throw 7;
return "exact";
')! == 'exact'
}

fn test_href_text_cache_captures_map_intrinsics_and_preserves_string_conversion_hooks() {
	assert href_text_cache_fixture(r'
const boom=()=>{throw new Error("replaced intrinsic")};
Map.prototype.get=boom;Map.prototype.set=boom;Map.prototype.delete=boom;Map.prototype.keys=boom;
Object.getPrototypeOf(new Map()[Symbol.iterator]()).next=boom;
for(let i=0;i<600;i++){state.attributes.href="key-"+i;object.href;object.href;}
const originalString=String;let conversions=0;
globalThis.String=function(input){conversions++;return originalString(input);};
state.attributes.href="repeated";object.href;object.href;if(conversions!==2)throw 1;
globalThis.String=()=>({get length(){throw new Error("unexpected length access")},toString(){return "converted";}});
if(object.href!=="fallback:https://base.test/a/|converted")throw 2;
return "exact";
')! == 'exact'
}
