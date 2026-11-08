module main

import dom
import platform
import x.json2

struct CompactTokenListRequest {
	op string
	attribute string
	tokens []string
	force ?bool
	value string
	state map[string]json2.Any
}

fn (mut binding CompactElementQueryBinding) token_list_query(key string, source string) !string {
	request := compact_decode_query[CompactTokenListRequest](source)!
	// Token-list writes are restricted to token-list attributes. They must not
	// provide an unchecked route to unrelated attribute injection sinks.
	if request.attribute !in ['class', 'part', 'rel', 'sandbox', 'for', 'sizes'] {
		return error('TypeError: Unsupported token-list attribute')
	}
	node := binding.equality_node(key, json2.Any(request.state))!
	mut element := node.as_element() or { return error('TypeError: Illegal Element receiver') }
	mut allocations := platform.RetainedArenaScope{}
	mut storage := element.document().native_storage()
	if storage != unsafe { nil } { allocations = storage.enter_nested() }
	defer { allocations.finish() }
	mut list := match request.attribute {
		'class' { element.class_list() }
		'part' { element.part_list() }
		else { dom.DOMTokenList.create(element, request.attribute.clone()) }
	}
	list.associated_attribute_changed(element.get_attribute_value(request.attribute))
	mut result := json2.Any(json2.Null{})
	match request.op {
		'snapshot' {}
		'add' { list.add(request.tokens.map(it.clone()))! }
		'remove' { list.remove(request.tokens.map(it.clone()))! }
		'toggle' {
			if request.tokens.len != 1 { return error('TypeError: toggle requires a token') }
			result = list.toggle(request.tokens[0].clone(), request.force)!
		}
		'replace' {
			if request.tokens.len != 2 { return error('TypeError: replace requires two tokens') }
			result = list.replace(request.tokens[0].clone(), request.tokens[1].clone())!
		}
		'supports' {
			if request.tokens.len != 1 { return error('TypeError: supports requires a token') }
			result = list.supports(request.tokens[0])!
		}
		'setValue' { list.set_value(request.value.clone()) }
		else { return error('TypeError: Unknown token-list operation') }
	}
	list.associated_attribute_changed(element.get_attribute_value(request.attribute))
	mut response := {
		'tokens': json2.Any(list.token_set.map(json2.Any(it)))
		'value': json2.Any(list.value())
		'result': result
	}
	if request.op !in ['snapshot', 'supports'] {
		response['refresh'] = binding.element_attribute_refresh(element)
	}
	return json2.encode(response)
}

fn compact_native_token_list_bootstrap() string {
	return r'
const __compactTokenLists=(function(){
 "use strict";
 const records=new WeakMap(),cache=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const apply=__elementApply,S=String,T=TypeError,D=DOMException,define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor;
 const stringify=JSON.stringify,refresh=globalThis.__compactApplyMutationRefresh;
 const assign=Object.assign,objectEntries=Object.entries,create=Object.create;
 const getProperty=Reflect.get,hasProperty=Reflect.has,ownKeys=Reflect.ownKeys,getDescriptor=Reflect.getOwnPropertyDescriptor,setProperty=Reflect.set,defineProperty=Reflect.defineProperty,deleteProperty=Reflect.deleteProperty;
 const values=Array.prototype.values,keys=Array.prototype.keys,entries=Array.prototype.entries,forEach=Array.prototype.forEach;
 const string=value=>{if(typeof value==="symbol")throw new T("Cannot convert a Symbol to a string");return S(value);};
 const owner=receiver=>{const own=apply(get,records,[receiver]);if(!own)throw new T("Illegal DOMTokenList receiver");return own;};
 function call(receiver,op,fields){
  const own=owner(receiver),state=own.state,request=assign({op,attribute:own.attribute,state:state.created?state:undefined},fields);
  let result;
  try{result=__queryElements(state.bridgeKey,"tokenList",stringify(request),true);}
  catch(error){const match=/^(SyntaxError|InvalidCharacterError):\s*(.*)/.exec(error&&error.message);if(match)throw new D(match[2],match[1]);if(/^TypeError:/.test(error&&error.message))throw new T(error.message.slice(10).trimStart());throw error;}
  refresh(result);if(result.refresh)__compactCustomElementFlush(state);return result;
 }
 function DOMTokenList(){throw new T("Illegal constructor");}
 const prototype=DOMTokenList.prototype;
 define(DOMTokenList,"prototype",{writable:false});define(prototype,Symbol.toStringTag,{value:"DOMTokenList",configurable:true});
 define(globalThis,"DOMTokenList",{value:DOMTokenList,writable:true,configurable:true});
 const methods={
  item(index){owner(this);if(arguments.length===0)throw new T("item requires an index");const converted=(+index)>>>0;return call(this,"snapshot").tokens[converted]??null;},
  contains(token){owner(this);if(arguments.length===0)throw new T("contains requires a token");const converted=string(token);return call(this,"snapshot").tokens.includes(converted);},
  add(...tokens){owner(this);return void call(this,"add",{tokens:tokens.map(string)});},
  remove(...tokens){owner(this);return void call(this,"remove",{tokens:tokens.map(string)});},
  toggle(token,force=undefined){owner(this);if(arguments.length===0)throw new T("toggle requires a token");return call(this,"toggle",{tokens:[string(token)],force:force===undefined?undefined:!!force}).result;},
  replace(token,newToken){owner(this);if(arguments.length<2)throw new T("replace requires two tokens");return call(this,"replace",{tokens:[string(token),string(newToken)]}).result;},
  supports(token){owner(this);if(arguments.length===0)throw new T("supports requires a token");return call(this,"supports",{tokens:[string(token)]}).result;},
  toString(){return call(this,"snapshot").value;},
  // Indexed value iterables use Array intrinsics. forEach captures the
  // initial length and accepts generic receivers.
  values,keys,entries,forEach
 };
 for(const [name,value] of objectEntries(methods))define(prototype,name,{value,writable:true,enumerable:true,configurable:true});
 define(prototype,Symbol.iterator,{value:methods.values,writable:true,configurable:true});
 const attributes={get length(){return call(this,"snapshot").tokens.length;},get value(){return call(this,"snapshot").value;},set value(value){owner(this);call(this,"setValue",{value:string(value)});}};
 for(const name of ["length","value"])define(prototype,name,descriptor(attributes,name));
 const isIndex=key=>typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)&&Number(key)<4294967295;
 function list(state,attribute){
  let lists=apply(get,cache,[state]);if(!lists){lists=create(null);apply(set,cache,[state,lists]);}if(lists[attribute])return lists[attribute];
  const target=create(prototype),proxy=new Proxy(target,{
   get(target,key,receiver){if(isIndex(key)){const value=call(proxy,"snapshot").tokens[Number(key)];if(value!==undefined)return value;}return getProperty(target,key,receiver);},
   has(target,key){return isIndex(key)?Number(key)<call(proxy,"snapshot").tokens.length||hasProperty(target,key):hasProperty(target,key);},
   ownKeys(target){const tokens=call(proxy,"snapshot").tokens;return tokens.map((_,index)=>S(index)).concat(ownKeys(target));},
   getOwnPropertyDescriptor(target,key){if(isIndex(key)){const value=call(proxy,"snapshot").tokens[Number(key)];if(value!==undefined)return {value,writable:false,enumerable:true,configurable:true};}return getDescriptor(target,key);},
   set(target,key,value,receiver){return isIndex(key)?false:setProperty(target,key,value,receiver);},
   defineProperty(target,key,value){return isIndex(key)?false:defineProperty(target,key,value);},
   deleteProperty(target,key){return isIndex(key)?Number(key)>=call(proxy,"snapshot").tokens.length:deleteProperty(target,key);},
   preventExtensions(){return false;}
  });
  apply(set,records,[proxy,{state,attribute}]);lists[attribute]=proxy;return proxy;
 }
 function state(receiver){let own=apply(__elementRecordGet,__elementRecords,[receiver]);if(!own){const local=__compactForeignNode(receiver);if(local)own=apply(__elementRecordGet,__elementRecords,[local]);}if(!own)throw new T("Illegal Element receiver");return own;}
 // PutForwards reads the public getter and assigns the original value,
 // allowing custom getters/setters and ignoring a false [[Set]] result.
 function forward(receiver,property,value){const target=getProperty(receiver,property);if(target===null||typeof target!=="object"&&typeof target!=="function")throw new T("Forwarded token list must be an object");setProperty(target,"value",value);}
 const classList=descriptor({get classList(){return list(state(this),"class");},set classList(value){state(this);forward(this,"classList",value);}},"classList");
 define(Element.prototype,"classList",classList);
 function reflected(prototype,property,attribute,namespace,tags){
  function own(receiver){const value=state(receiver);if(namespace&&value.namespaceURI!==namespace||tags&&!tags.includes(S(value.tagName).split(":").pop()))throw new T("Illegal token-list attribute receiver");return value;}
  define(prototype,property,descriptor({get [property](){return list(own(this),attribute);},set [property](value){own(this);forward(this,property,value);}},property));
 }
 reflected(Element.prototype,"part","part",null,null);
 const html="http://www.w3.org/1999/xhtml";
 for(const [constructor,tag] of [[HTMLAnchorElement,"a"],[HTMLAreaElement,"area"],[HTMLLinkElement,"link"],[HTMLFormElement,"form"]])reflected(constructor.prototype,"relList","rel",html,[tag]);
 reflected(HTMLIFrameElement.prototype,"sandbox","sandbox",html,["iframe"]);
 reflected(HTMLOutputElement.prototype,"htmlFor","for",html,["output"]);
 reflected(HTMLLinkElement.prototype,"sizes","sizes",html,["link"]);
 reflected(SVGAElement.prototype,"relList","rel","http://www.w3.org/2000/svg",["a"]);
 for(const own of Object.values(__state.elements)){const object=own.__object;if(object&&apply(__elementRecordGet,__elementRecords,[object]))delete object.classList;}
 const legacy=__classList;
 __classList=function(state){return state.tagName[0]==="#"?legacy(state):list(state,"class");};
 return {list,state};
})();
'
}
