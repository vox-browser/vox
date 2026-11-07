// XMLHttpRequest.idl JavaScriptCore transport. Native V records own behavior.
module browserjs

pub fn xhr_bootstrap() string {
	return r'
const __xhrObjects=new Map(),__xhrNodes=new Map(),__xhrEvents=new Map();
let __xhrNextCallback=0;
const __xhrConstructionToken={};
const __xhrBlobNative=__ladybirdXHRBlob;
function __xhrThrow(error){
 const match=/^([A-Za-z]+Error):\s*(.*)/.exec(error&&error.message);
 const name=match?match[1]:error&&error.name,message=match?match[2]:error&&error.message;
 // XMLHttpRequest reports everything but conversion failures as DOMExceptions.
 if(typeof name==="string"&&/.Error$/.test(name)&&name!=="TypeError"&&name!=="RangeError"&&typeof DOMException==="function")throw new DOMException(message,name);
 if(match){error.name=name;error.message=message;}
 throw error;
}
// https://webidl.spec.whatwg.org/#es-ByteString
function __xhrByteString(value){const string=String(value);for(let index=0;index<string.length;index++)if(string.charCodeAt(index)>255)throw new TypeError("Value is not a valid ByteString");return string;}
function __xhrCall(key,method,args,extra){
 try{return JSON.parse(__ladybirdXHR(JSON.stringify(Object.assign({key:key,method:method,args:args||[]},extra||{}))));}
 catch(error){__xhrThrow(error);}
}
function __xhrBlobCall(action,key,value){try{return action==="send"?__xhrBlobNative(action,key,value):__xhrBlobNative(action,key);}catch(error){__xhrThrow(error);}}
function __xhrNode(value){
 if(value===null)return null;
 const identity=value.kind+value.key;if(__xhrNodes.has(identity))return __xhrNodes.get(identity);
 const object={};if(value.kind==="document")Object.defineProperty(object,"__xhrDocumentKey",{value:value.key});__xhrNodes.set(identity,object);
 function call(action,args){return __xhrCall(value.key,value.kind,args,{action:action});}
 const properties=value.kind==="document"?["URL","title","contentType","documentElement","textContent"]:["tagName","textContent"];
 for(const property of properties)Object.defineProperty(object,property,{enumerable:true,get:function(){const result=call(property);return result&&result.kind?__xhrNode(result):result;}});
 if(value.kind==="document")object.getElementById=function(id){return __xhrNode(call("getElementById",[String(id)]));};
 else object.getAttribute=function(name){return call("getAttribute",[String(name)]);};
 object.querySelector=function(selector){return __xhrNode(call("querySelector",[String(selector)]));};
 object.querySelectorAll=function(selector){return call("querySelectorAll",[String(selector)]).map(__xhrNode);};
 return object;
}
function __xhrResponse(value,key){
 if(!value||!value.kind)return value;
 if(value.kind==="document")return __xhrNode(value);
 if(value.kind==="arraybuffer")return new Uint8Array(value.bytes).buffer;
 if(value.kind==="blob")return __xhrBlobCall("response",key);
 return value;
}
function __xhrEvent(payload,target){
 let event=__xhrEvents.get(payload.key);
 if(!event){
  event={};for(const name of Object.keys(payload))if(name!=="key")Object.defineProperty(event,name,{value:payload[name],enumerable:true});
  Object.defineProperty(event,"target",{value:target,enumerable:true});
  Object.defineProperty(event,"currentTarget",{get:function(){return event.__currentTarget||null;},enumerable:true});
  Object.defineProperty(event,"defaultPrevented",{get:function(){return __xhrCall(0,"event",[],{event:payload.key,action:"defaultPrevented"});},enumerable:true});
  for(const action of ["preventDefault","stopPropagation","stopImmediatePropagation"])event[action]=function(){__xhrCall(0,"event",[],{event:payload.key,action:action});};
  __xhrEvents.set(payload.key,event);
 }
 return event;
}
globalThis.__ladybirdXHRInvoke=function(key,upload,token,payload){
 const owner=__xhrObjects.get(key),target=upload?owner.upload:owner,callback=target.__callbacks.get(token);
 if(!callback)return;
 const event=__xhrEvent(payload,target);event.__currentTarget=target;
 try{return typeof callback==="function"?callback.call(target,event):callback.handleEvent(event);}
 finally{event.__currentTarget=null;}
};
function __xhrInitializeTarget(target,key,upload){
 Object.defineProperties(target,{__key:{value:key},__upload:{value:upload},__callbacks:{value:new Map()},__tokens:{value:new WeakMap()},__handlers:{value:Object.create(null)}});
 for(const name of ["loadstart","progress","abort","error","load","timeout","loadend"].concat(upload?[]:["readystatechange"])){
  Object.defineProperty(target,"on"+name,{enumerable:true,configurable:true,get:function(){return target.__handlers[name]||null;},set:function(callback){
   if(typeof callback!=="function")callback=null;target.__handlers[name]=callback;
   let token=0;if(callback){token=++__xhrNextCallback;target.__callbacks.set(token,callback);}
   __xhrCall(key,"listen",[],{upload:upload,name:name,action:"handler",token:token});
  }});
 }
}
function __xhrToken(target,callback){let token=target.__tokens.get(callback);if(!token){token=++__xhrNextCallback;target.__tokens.set(callback,token);target.__callbacks.set(token,callback);}return token;}
class XMLHttpRequestEventTarget {
 constructor(token){if(token!==__xhrConstructionToken)throw new TypeError("Illegal constructor");}
 addEventListener(name,callback,options){
  if(arguments.length<2)throw new TypeError("addEventListener requires two arguments");
  if(callback==null)return;if(typeof callback!=="function"&&typeof callback!=="object")throw new TypeError("Expected an event listener");
  const token=__xhrToken(this,callback),dictionary=options&&typeof options==="object"?options:{capture:!!options};
  __xhrCall(this.__key,"listen",[],{upload:this.__upload,name:String(name),token:token,action:"add",capture:!!dictionary.capture,once:!!dictionary.once,passive:dictionary.passive===undefined?null:!!dictionary.passive});
 }
 removeEventListener(name,callback,options){
  if(arguments.length<2)throw new TypeError("removeEventListener requires two arguments");
  if(callback==null)return;const token=this.__tokens.get(callback);if(!token)return;
  __xhrCall(this.__key,"listen",[],{upload:this.__upload,name:String(name),token:token,action:"remove",capture:options&&typeof options==="object"?!!options.capture:!!options});
 }
}
class XMLHttpRequestUpload extends XMLHttpRequestEventTarget{constructor(token){super(token);}}
class XMLHttpRequest extends XMLHttpRequestEventTarget {
 constructor(){super(__xhrConstructionToken);const key=__xhrCall(0,"create");__xhrInitializeTarget(this,key,false);const upload=new XMLHttpRequestUpload(__xhrConstructionToken);__xhrInitializeTarget(upload,key,true);Object.defineProperty(this,"upload",{value:upload,enumerable:true});this.__responseCache=undefined;__xhrObjects.set(key,this);}
 open(method,url,async,username,password){if(arguments.length<2)throw new TypeError("open requires two arguments");this.__responseCache=undefined;__xhrCall(this.__key,"open",[String(method),String(url),arguments.length<3?true:!!async,username==null?null:String(username),password==null?null:String(password)]);}
 setRequestHeader(name,value){if(arguments.length<2)throw new TypeError("setRequestHeader requires two arguments");__xhrCall(this.__key,"setRequestHeader",[__xhrByteString(name),__xhrByteString(value)]);}
 send(body){
  if(body==null)return __xhrCall(this.__key,"send");
  if(__xhrBlobCall("send",this.__key,body))return;
  if(body.__xhrDocumentKey||(typeof document!=="undefined"&&body===document))return __xhrCall(this.__key,"send",[],{document:body.__xhrDocumentKey||"owner"});
  if(body instanceof ArrayBuffer)return __xhrCall(this.__key,"send",[Array.from(new Uint8Array(body))]);
  if(ArrayBuffer.isView(body))return __xhrCall(this.__key,"send",[Array.from(new Uint8Array(body.buffer,body.byteOffset,body.byteLength))]);
  return __xhrCall(this.__key,"send",[String(body)]);
 }
 abort(){__xhrCall(this.__key,"abort");}
 getResponseHeader(name){if(arguments.length<1)throw new TypeError("getResponseHeader requires a name");return __xhrCall(this.__key,"getResponseHeader",[String(name)]);}
 getAllResponseHeaders(){return __xhrCall(this.__key,"getAllResponseHeaders");}
 overrideMimeType(type){if(arguments.length<1)throw new TypeError("overrideMimeType requires a type");__xhrCall(this.__key,"overrideMimeType",[String(type)]);}
}
for(const name of ["readyState","responseURL","status","statusText","responseText","responseXML","response"]){
 Object.defineProperty(XMLHttpRequest.prototype,name,{enumerable:true,configurable:true,get:function(){
  if(name==="response"&&this.responseType!==""&&this.responseType!=="text"&&this.__responseCache!==undefined)return this.__responseCache;
  const value=__xhrCall(this.__key,"get",[],{property:name}),result=__xhrResponse(value,this.__key);
  if(name==="response"&&result!==null&&this.responseType!==""&&this.responseType!=="text")this.__responseCache=result;
  return result;
 }});
}
for(const name of ["timeout","withCredentials","responseType"])Object.defineProperty(XMLHttpRequest.prototype,name,{enumerable:true,configurable:true,get:function(){return __xhrCall(this.__key,"get",[],{property:name});},set:function(value){if(name==="timeout")value=Number(value)>>>0;else if(name==="withCredentials")value=!!value;else value=String(value);__xhrCall(this.__key,"set",[value],{property:name});if(name==="responseType")this.__responseCache=undefined;}});
for(const [name,value] of [["UNSENT",0],["OPENED",1],["HEADERS_RECEIVED",2],["LOADING",3],["DONE",4]]){Object.defineProperty(XMLHttpRequest,name,{value:value,enumerable:true});Object.defineProperty(XMLHttpRequest.prototype,name,{value:value,enumerable:true});}
globalThis.XMLHttpRequest=XMLHttpRequest;
globalThis.XMLHttpRequestEventTarget=XMLHttpRequestEventTarget;
globalThis.XMLHttpRequestUpload=XMLHttpRequestUpload;
'
}
