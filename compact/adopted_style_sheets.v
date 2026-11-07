module main

import browserjs
import css
import x.json2

fn (mut binding CompactElementQueryBinding) adopted_style_sheets_query(request CompactSheetRequest) !string {
	root := if request.root_key == '' { binding.document.as_node() } else {
		binding.node_for_key(request.root_key) or { return error('TypeError: Invalid stylesheet owner') }
	}
	if root.as_document() == none && root.as_shadow_root() == none {
		return error('TypeError: Expected a Document or ShadowRoot')
	}
	mut list := css.create_adopted_style_sheets_list(root)
	mut result := json2.Any(json2.Null{})
	mutating := request.op in ['adoptedSet', 'adoptedDelete', 'adoptedClear']
	defer {
		// A rejected replacement can already have run the native delete
		// callback. Publish its invalidation even on the exceptional path.
		if mutating {
			mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
			runtime.mark_document_state_dirty()
			runtime.mark_document_replay_effects()
		}
	}
	match request.op {
		'adoptedLength' { result = list.length() }
		'adoptedItem' {
			if sheet := list.item(int(request.index)) { result = binding.sheet_key(sheet) }
		}
		'adoptedSet' {
			sheet := binding.style_sheets[request.id] or { return error('TypeError: Expected a CSSStyleSheet') }
			list.set(int(request.index), sheet)!
		}
		'adoptedDelete' { list.delete(int(request.index)) }
		'adoptedClear' { list.clear() }
		else { return error('Unknown adopted stylesheet operation') }
	}
	return json2.encode(result)
}

fn compact_adopted_style_sheets_bootstrap() string {
	return r'
const __adoptedArrays=new WeakMap();
const __adoptedProxy=Proxy,__adoptedTypeError=TypeError,__adoptedRangeError=RangeError;
const __adoptedGet=Reflect.get,__adoptedSet=Reflect.set,__adoptedDefine=Reflect.defineProperty,__adoptedDelete=Reflect.deleteProperty,__adoptedDescriptor=Reflect.getOwnPropertyDescriptor,__adoptedHas=Reflect.has,__adoptedKeys=Reflect.ownKeys;
const __adoptedNumber=Number,__adoptedString=String,__adoptedInteger=Number.isInteger,__adoptedIterator=Symbol.iterator;
function __adoptedIndex(key){if(typeof key!=="string")return false;const n=__adoptedNumber(key);return __adoptedInteger(n)&&n>=0&&n<4294967295&&__adoptedString(n)===key;}
function __adoptedCall(state,op,fields={}){fields.root_key=state.bridgeKey;return __cssCall("",op,fields);}
function __adoptedSheetId(value){const id=__elementApply(__elementRecordGet,__cssSheetRecords,[value]);if(!id)throw new __adoptedTypeError("Expected a CSSStyleSheet");return id;}
function __adoptedArray(state){
 let array=__elementApply(__compactNodeGet,__adoptedArrays,[state]);if(array)return array;
 const length=()=>__adoptedCall(state,"adoptedLength"),item=index=>__cssSheet(__adoptedCall(state,"adoptedItem",{index}));
 function setLength(value){const uint32=(+value)>>>0,number=+value;if(uint32!==number)throw new __adoptedRangeError("Invalid observable array length");const old=length();if(uint32>old)return false;for(let i=old-1;i>=uint32;i--)__adoptedCall(state,"adoptedDelete",{index:i});return true;}
 function setIndex(key,value){const index=__adoptedNumber(key);if(index>length())return false;const id=__adoptedSheetId(value);__adoptedCall(state,"adoptedSet",{id,index});return true;}
 array=new __adoptedProxy([],{
  get(target,key,receiver){if(key==="length")return length();if(__adoptedIndex(key))return __adoptedNumber(key)<length()?item(__adoptedNumber(key)):undefined;return __adoptedGet(target,key,receiver);},
  set(target,key,value,receiver){if(key==="length")return setLength(value);if(__adoptedIndex(key))return setIndex(key,value);return __adoptedSet(target,key,value,receiver);},
  defineProperty(target,key,desc){
   if(key==="length"){if("get" in desc||"set" in desc||desc.configurable===true||desc.enumerable===true||desc.writable===false)return false;return "value" in desc?setLength(desc.value):true;}
   if(__adoptedIndex(key)){if("get" in desc||"set" in desc||desc.configurable===false||desc.enumerable===false||desc.writable===false)return false;return "value" in desc?setIndex(key,desc.value):true;}
   return __adoptedDefine(target,key,desc);
  },
  deleteProperty(target,key){if(key==="length")return false;if(__adoptedIndex(key)){const index=__adoptedNumber(key);if(index!==length()-1)return false;__adoptedCall(state,"adoptedDelete",{index});return true;}return __adoptedDelete(target,key);},
  getOwnPropertyDescriptor(target,key){if(key==="length")return {value:length(),writable:true,enumerable:false,configurable:false};if(__adoptedIndex(key))return __adoptedNumber(key)<length()?{value:item(__adoptedNumber(key)),writable:true,enumerable:true,configurable:true}:undefined;return __adoptedDescriptor(target,key);},
  has(target,key){if(key==="length")return true;if(__adoptedIndex(key))return __adoptedNumber(key)<length();return __adoptedHas(target,key);},
  ownKeys(target){const keys=[],size=length();for(let i=0;i<size;i++)keys[keys.length]=__adoptedString(i);const ordinary=__adoptedKeys(target);for(let i=0;i<ordinary.length;i++)keys[keys.length]=ordinary[i];return keys;},
  preventExtensions(){return false;}
 });
 __elementApply(__elementRecordSet,__adoptedArrays,[state,array]);return array;
}
function __setAdoptedSheets(state,value){
 // Upstream Document/ShadowRoot binding glue clears before GetIterator and
 // appends one value at a time. Preserve its partial and exceptional effects.
 __adoptedCall(state,"adoptedClear");
 if(value==null)throw new __adoptedTypeError("Expected an iterable of stylesheets");
 const method=value[__adoptedIterator];if(typeof method!=="function")throw new __adoptedTypeError("Stylesheets are not iterable");
 const iterator=__elementApply(method,value,[]);if(iterator===null||(typeof iterator!=="object"&&typeof iterator!=="function"))throw new __adoptedTypeError("Iterator is not an object");
 const next=iterator.next;
 while(true){const entry=__elementApply(next,iterator,[]);if(entry===null||(typeof entry!=="object"&&typeof entry!=="function"))throw new __adoptedTypeError("Iterator result is not an object");if(entry.done)return;const id=__adoptedSheetId(entry.value);__adoptedCall(state,"adoptedSet",{id,index:__adoptedCall(state,"adoptedLength")});}
}
Object.defineProperty(Document.prototype,"adoptedStyleSheets",{get:function(){return __adoptedArray(__compactDocumentState(this));},set:function(value){__setAdoptedSheets(__compactDocumentState(this),value);},enumerable:true,configurable:true});
Object.defineProperty(ShadowRoot.prototype,"adoptedStyleSheets",{get:function(){return __adoptedArray(__compactShadowState(this));},set:function(value){__setAdoptedSheets(__compactShadowState(this),value);},enumerable:true,configurable:true});
'
}
