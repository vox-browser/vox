module main

fn compact_html_language_bootstrap() string {
	return r'
Object.defineProperty(HTMLElement.prototype,"lang",{get:function(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml")throw new TypeError("Illegal HTMLElement receiver");
 return __compactNativeAttributes.read(state,"lang",true)||"";
},set:function(value){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml")throw new TypeError("Illegal HTMLElement receiver");
 if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 __compactNativeAttributes.write(state,"lang",String(value),true);
},enumerable:true,configurable:true});
'
}
