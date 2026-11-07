module main

// HTMLIFrameElement reflects its content attributes as IDL properties,
// including the obsolete presentational ones. 4chan's ad loader creates its
// frames with `frame.frameBorder = 0` and `frame.scrolling = "no"`; without
// the reflection the attribute never reaches the DOM and the frame keeps its
// default 2px inset border.
fn compact_iframe_reflection_bootstrap() string {
	return r'
function __compactIFrameState(receiver){
 const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
 if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||String(state.tagName).split(":").pop()!=="iframe")throw new TypeError("Illegal HTMLIFrameElement receiver");
 return state;
}
function __compactIFrameString(value,nullToEmpty){
 if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol value to a string");
 return nullToEmpty&&value===null?"":String(value);
}
for(const [property,attribute,nullToEmpty] of [["frameBorder","frameborder",false],["marginHeight","marginheight",true],["marginWidth","marginwidth",true],["scrolling","scrolling",false],["allow","allow",false],["align","align",false]])Object.defineProperty(HTMLIFrameElement.prototype,property,{get:function(){
 const state=__compactIFrameState(this);return Object.prototype.hasOwnProperty.call(state.attributes,attribute)?String(state.attributes[attribute]):"";
},set:function(value){
 const state=__compactIFrameState(this);__setAttribute(state,attribute,__compactIFrameString(value,nullToEmpty));
},enumerable:true,configurable:true});
Object.defineProperty(HTMLIFrameElement.prototype,"allowFullscreen",{get:function(){
 return Object.prototype.hasOwnProperty.call(__compactIFrameState(this).attributes,"allowfullscreen");
},set:function(value){
 const state=__compactIFrameState(this);if(value)__setAttribute(state,"allowfullscreen","");else __removeAttribute(state,"allowfullscreen");
},enumerable:true,configurable:true});
// Enumerated attributes limited to known values: loading (missing and
// invalid values default to eager) and referrerpolicy (default empty).
for(const [property,attribute,values,fallback] of [["loading","loading",["lazy","eager"],"eager"],["referrerPolicy","referrerpolicy",["","no-referrer","no-referrer-when-downgrade","same-origin","origin","strict-origin","origin-when-cross-origin","strict-origin-when-cross-origin","unsafe-url"],""]])Object.defineProperty(HTMLIFrameElement.prototype,property,{get:function(){
 const state=__compactIFrameState(this);
 if(!Object.prototype.hasOwnProperty.call(state.attributes,attribute))return fallback;
 const value=String(state.attributes[attribute]).replace(/[A-Z]/g,function(c){return String.fromCharCode(c.charCodeAt(0)+32);});return values.includes(value)?value:fallback;
},set:function(value){
 const state=__compactIFrameState(this);__setAttribute(state,attribute,__compactIFrameString(value,false));
},enumerable:true,configurable:true});
'
}
