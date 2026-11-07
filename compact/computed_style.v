module main

import css
import dom
import html
import json2

struct CompactComputedStyleQuery {
	op     string
	name   string
	pseudo ?string
	index  u32
}

// Read through the owning Window's CSSOM declaration. The query boundary has
// already replayed pending script mutations and retained the native receiver.
// No computed values are cached in the compact JavaScript object.
fn compact_computed_style_query(root &dom.Node, source string) !string {
	element := root.as_element() or { return error('TypeError: getComputedStyle requires an Element') }
	document := element.document()
	if document.get_window() == none {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	window_pointer := document.get_window() or { return error('getComputedStyle requires its owning Window') }
	window := unsafe { &html.WindowModel(window_pointer) }
	query := compact_decode_query[CompactComputedStyleQuery](source)!
	declaration := window.get_computed_style(element, query.pseudo)
	match query.op {
		'access' { return 'true' }
		'value' { return json2.encode(declaration.get_property_value(query.name), escape_unicode: true) }
		'named' {
			if css.property_id_from_string(query.name) == none && !query.name.starts_with('--') {
				return 'null'
			}
			return json2.encode(declaration.get_property_value(query.name), escape_unicode: true)
		}
		'priority' { return json2.encode(declaration.get_property_priority(query.name), escape_unicode: true) }
		'item' { return json2.encode(declaration.item(uint(query.index)), escape_unicode: true) }
		'names' {
			mut names := []string{}
			for index in 0 .. css.number_of_longhand_properties {
				name := declaration.item(uint(index))
				if name == '' { break }
				names << name
			}
			return json2.encode(names, escape_unicode: true)
		}
		else { return error('Invalid computed style operation') }
	}
}

// This executes inside the compact document closure after Window is installed,
// sharing its receiver brands and mutation-flushing native query boundary.
fn compact_computed_style_bootstrap() string {
	return r'
const __computedStyleOwners=new WeakMap();
const __computedStyleOwner=receiver=>{
 const owner=__elementApply(__elementRecordGet,__computedStyleOwners,[receiver]);
 if(!owner)throw new TypeError("Illegal CSSStyleDeclaration receiver");
 return owner;
};
const __computedStyleString=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
const __computedStyleRead=(owner,op,name="",index=0)=>__queryElements(owner.key,"computedStyle",JSON.stringify({op,name,index,pseudo:owner.pseudo}));
const __computedStyleReadonly=receiver=>{__computedStyleOwner(receiver);throw new DOMException("Computed style is read-only","NoModificationAllowedError");};
class CSSStyleDeclaration {
 constructor(){throw new TypeError("Illegal CSSStyleDeclaration constructor");}
 getPropertyValue(name){const owner=__computedStyleOwner(this);if(arguments.length===0)throw new TypeError("getPropertyValue requires a property");return __computedStyleRead(owner,"value",__computedStyleString(name));}
 getPropertyPriority(name){const owner=__computedStyleOwner(this);if(arguments.length===0)throw new TypeError("getPropertyPriority requires a property");return __computedStyleRead(owner,"priority",__computedStyleString(name));}
 item(index){const owner=__computedStyleOwner(this);if(arguments.length===0)throw new TypeError("item requires an index");return __computedStyleRead(owner,"item","",Number(index)>>>0);}
 setProperty(){__computedStyleReadonly(this);}
 removeProperty(){__computedStyleReadonly(this);}
 get length(){return __computedStyleRead(__computedStyleOwner(this),"names").length;}
 get cssText(){__computedStyleOwner(this);return "";}
 set cssText(value){__computedStyleReadonly(this);}
 get parentRule(){__computedStyleOwner(this);return null;}
 *[Symbol.iterator](){const owner=__computedStyleOwner(this);yield* __computedStyleRead(owner,"names");}
}
class CSSStyleProperties extends CSSStyleDeclaration {}
Object.defineProperty(CSSStyleDeclaration.prototype,Symbol.toStringTag,{value:"CSSStyleDeclaration",configurable:true});
Object.defineProperty(CSSStyleProperties.prototype,Symbol.toStringTag,{value:"CSSStyleProperties",configurable:true});
Object.defineProperties(globalThis,{CSSStyleDeclaration:{value:CSSStyleDeclaration,writable:true,configurable:true},CSSStyleProperties:{value:CSSStyleProperties,writable:true,configurable:true}});
Object.defineProperty(globalThis,"getComputedStyle",{writable:true,configurable:true,enumerable:true,value:function getComputedStyle(element,pseudoElement){
 "use strict";
 if(this!==undefined&&this!==null&&this!==globalThis)throw new TypeError("Illegal Window receiver");
 const state=__elementApply(__elementRecordGet,__elementRecords,[element]);
 if(!state)throw new TypeError("getComputedStyle requires an Element");
 const owner={key:state.bridgeKey,pseudo:pseudoElement==null?null:__computedStyleString(pseudoElement)};
 __computedStyleRead(owner,"access");
 const target=Object.create(CSSStyleProperties.prototype);
 const proxy=new Proxy(target,{
  get(target,property,receiver){
   if(Reflect.has(target,property))return Reflect.get(target,property,receiver);
   if(typeof property!=="string")return undefined;
   if(/^(0|[1-9][0-9]*)$/.test(property)){const name=__computedStyleRead(owner,"item","",Number(property)>>>0);return name||undefined;}
   const name=property==="cssFloat"?"float":__styleName(property);
   const value=__computedStyleRead(owner,"named",name);return value===null?undefined:value;
  },
  set(){__computedStyleReadonly(proxy);},
  deleteProperty(){__computedStyleReadonly(proxy);},
  defineProperty(){__computedStyleReadonly(proxy);}
 });
 __elementApply(__elementRecordSet,__computedStyleOwners,[target,owner]);
 __elementApply(__elementRecordSet,__computedStyleOwners,[proxy,owner]);
 return proxy;
}});
'
}
