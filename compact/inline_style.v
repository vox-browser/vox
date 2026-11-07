module main

import browserjs
import css
import dom
import platform
import x.json2

struct CompactInlineStyleQuery {
	op       string
	name     string
	value    string
	priority string
	index    u32
}

// Inline style edits use the same declaration as style attributes and layout.
// In particular, a cssText replacement must not leave a second property cache.
fn compact_inline_style_query(root &dom.Node, source string, runtime &browserjs.Runtime) !string {
	element := root.as_element() or { return error('TypeError: Invalid inline style owner') }
	query := compact_decode_query[CompactInlineStyleQuery](source)!
	previous_style := element.get_attribute_value('style')
	had_style := element.has_attribute('style')
	mut storage := element.document().native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	mut declaration := css.element_style(element)
	mut result := json2.Any('')
	match query.op {
		'supported' {
			result = css.property_id_from_string(query.name) != none || query.name.starts_with('--')
		}
		'value' { result = declaration.get_property_value(query.name) }
		'priority' { result = declaration.get_property_priority(query.name) }
		'item' { result = declaration.item(uint(query.index)) }
		'text' { result = declaration.css_text() }
		'names' {
			mut names := []json2.Any{}
			mut index := uint(0)
			for {
				name := declaration.item(index)
				if name == '' { break }
				names << json2.Any(name)
				index++
			}
			result = names
		}
		// CSS parsing can retain token strings after the request is retired.
		'set' {
			declaration.set_property(query.name.clone(), query.value.clone(), query.priority.clone())!
		}
		'remove' { result = declaration.remove_property(query.name)! }
		'replace' { declaration.set_css_text(query.value.clone())! }
		else { return error('Invalid inline style operation') }
	}
	if runtime != unsafe { nil } && query.op in ['set', 'remove', 'replace']
		&& (previous_style != element.get_attribute_value('style') || had_style != element.has_attribute('style')) {
		mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
		mutable_runtime.mark_document_state_dirty()
		mutable_runtime.mark_document_replay_effects()
	}
	// Keep response buffers in the caller's temporary allocation scope.
	allocation_scope.finish()
	records, attributes := browserjs.compact_attribute_state(element)
	return json2.encode({
		'value':            result
		'styleText':        json2.Any(element.get_attribute_value('style'))
		'attributeRecords': json2.Any(records)
		'attributes':       json2.Any(attributes)
	})
}

fn compact_inline_style_bootstrap() string {
	return r'
const __inlineStyleOwners=new WeakMap();
const __inlineStyleProperties=new Map();
const __inlineStyleName=property=>property==="cssFloat"?"float":property.startsWith("--")?property:__styleName(property);
function __inlineStyleSupported(owner,property){
 if(!__inlineStyleProperties.has(property))__inlineStyleProperties.set(property,__inlineStyleQuery(owner,"supported",__inlineStyleName(property)));
 return __inlineStyleProperties.get(property);
}
const __inlineStyleString=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
const __inlineStyleOwner=receiver=>{
 const owner=__elementApply(__elementRecordGet,__inlineStyleOwners,[receiver]);
 if(!owner)throw new TypeError("Illegal CSSStyleDeclaration receiver");return owner;
};
function __inlineStyleQuery(owner,op,name="",value="",priority="",index=0){
 const result=__queryElements(owner.bridgeKey,"inlineStyle",JSON.stringify({op,name,value,priority,index}));
 owner.styleText=result.styleText;owner.attributes=result.attributes;owner.attributeRecords=result.attributeRecords;
 return result.value;
}
const __inlineStylePrototype={
 getPropertyValue(name){const owner=__inlineStyleOwner(this);if(!arguments.length)throw new TypeError("getPropertyValue requires a property");return __inlineStyleQuery(owner,"value",__inlineStyleString(name));},
 getPropertyPriority(name){const owner=__inlineStyleOwner(this);if(!arguments.length)throw new TypeError("getPropertyPriority requires a property");return __inlineStyleQuery(owner,"priority",__inlineStyleString(name));},
 setProperty(name,value,priority=""){const owner=__inlineStyleOwner(this);if(arguments.length<2)throw new TypeError("setProperty requires a property and value");name=__inlineStyleString(name);value=value===null?"":__inlineStyleString(value);priority=priority===null?"":__inlineStyleString(priority);__inlineStyleQuery(owner,"set",name,value,priority);},
 removeProperty(name){const owner=__inlineStyleOwner(this);if(!arguments.length)throw new TypeError("removeProperty requires a property");return __inlineStyleQuery(owner,"remove",__inlineStyleString(name));},
 item(index){const owner=__inlineStyleOwner(this);if(!arguments.length)throw new TypeError("item requires an index");return __inlineStyleQuery(owner,"item","","","",(+index)>>>0);},
 get length(){return __inlineStyleQuery(__inlineStyleOwner(this),"names").length;},
 get cssText(){return __inlineStyleQuery(__inlineStyleOwner(this),"text");},
 set cssText(value){__inlineStyleQuery(__inlineStyleOwner(this),"replace","",__inlineStyleString(value));},
 get parentRule(){__inlineStyleOwner(this);return null;},
 *[Symbol.iterator](){yield* __inlineStyleQuery(__inlineStyleOwner(this),"names");}
};
function __styleProxy(owner){
 const target=Object.create(__inlineStylePrototype);
 const proxy=new Proxy(target,{
  get(target,property,receiver){
   if(Reflect.has(target,property))return Reflect.get(target,property,receiver);
   if(typeof property!=="string")return undefined;
   if(/^(0|[1-9][0-9]*)$/.test(property)){const name=__inlineStyleQuery(owner,"item","","","",Number(property)>>>0);return name||undefined;}
   return __inlineStyleSupported(owner,property)?__inlineStyleQuery(owner,"value",__inlineStyleName(property)):undefined;
  },
  set(target,property,value,receiver){
   if(Reflect.has(target,property))return Reflect.set(target,property,value,receiver);
   if(typeof property!=="string")return Reflect.set(target,property,value,receiver);
   if(!__inlineStyleSupported(owner,property))return Reflect.set(target,property,value,receiver);
   __inlineStyleQuery(owner,"set",__inlineStyleName(property),value===null?"":__inlineStyleString(value));return true;
  },
  has(target,property){return Reflect.has(target,property)||typeof property==="string"&&(__inlineStyleSupported(owner,property)||/^(0|[1-9][0-9]*)$/.test(property)&&!!__inlineStyleQuery(owner,"item","","","",Number(property)>>>0));}
 });
 __elementApply(__elementRecordSet,__inlineStyleOwners,[target,owner]);
 __elementApply(__elementRecordSet,__inlineStyleOwners,[proxy,owner]);
 return proxy;
}
'
}
