module browserjs

import dom
import x.json2

// The compact facade's qualified-name view retains the first matching Attr;
// namespace/local-name identity and attribute order remain in the record list.
pub fn compact_attribute_state(element &dom.Element) ([]json2.Any, map[string]json2.Any) {
	mut records := []json2.Any{}
	mut attributes := map[string]json2.Any{}
	list := element.attribute_list() or { return records, attributes }
	for attribute in list.attrs {
		mut prefix := json2.Any(json2.Null{})
		if value := attribute.prefix() { prefix = json2.Any(value) }
		mut namespace_uri := json2.Any(json2.Null{})
		if value := attribute.namespace_uri() { namespace_uri = json2.Any(value) }
		records << json2.Any({
			'name': json2.Any(attribute.name())
			'localName': json2.Any(attribute.local_name())
			'prefix': prefix
			'namespaceURI': namespace_uri
			'value': json2.Any(attribute.value())
		})
		if attribute.name() !in attributes {
			attributes[attribute.name()] = json2.Any(attribute.value())
		}
	}
	return records, attributes
}

// Main owns the explicit public-mutation journal. Native reflection updates
// this facade state only, because the native setter writes the actual DOM.
pub fn compact_attribute_bootstrap() string {
	return r'const __compactAttributes=(function(create,define,remove,keys,push,splice,apply){
 "use strict";
 function copy(record){return {name:record.name,localName:record.localName,prefix:record.prefix,namespaceURI:record.namespaceURI,value:record.value};}
 function project(state){
  const attributes=state.attributes||create(null),names=keys(attributes),records=state.attributeRecords,seen=create(null);
  for(let i=0;i<names.length;i++)remove(attributes,names[i]);
  for(let i=0;i<records.length;i++){
   const record=records[i],name=record.name;
   if(seen[name]===true)continue;
   define(seen,name,{value:true,enumerable:true,configurable:true});
   define(attributes,name,{value:record.value,writable:true,enumerable:true,configurable:true});
  }
  define(state,"attributes",{value:attributes,writable:true,enumerable:true,configurable:true});
  define(state,"attributesDirty",{value:true,writable:true,enumerable:true,configurable:true});
 }
 function set(state,name,value){
  const records=state.attributeRecords;
  let record=null;
  for(let i=0;i<records.length;i++)if(records[i].name===name){record=records[i];break;}
  if(record===null){record={name:name,localName:name,prefix:null,namespaceURI:null,value:value};apply(push,records,[record]);}
  else record.value=value;
  project(state);return copy(record);
 }
 function removeFirst(state,name){
  const records=state.attributeRecords;
  let record=null;
  for(let i=0;i<records.length;i++)if(records[i].name===name){record=records[i];apply(splice,records,[i,1]);break;}
  project(state);return record===null?null:copy(record);
 }
 function reflect(state,name,value,qualifiedRemoval){
  const records=state.attributeRecords,present=typeof value==="string"||!!value;
  if(!present&&qualifiedRemoval===true){removeFirst(state,name);return;}
  let record=null,index=-1;
  for(let i=0;i<records.length;i++)if(records[i].namespaceURI===null&&records[i].localName===name){record=records[i];index=i;break;}
  if(present){
   if(record===null){record={name:name,localName:name,prefix:null,namespaceURI:null,value:typeof value==="string"?value:""};apply(push,records,[record]);}
   else record.value=typeof value==="string"?value:"";
  }else if(index!==-1)apply(splice,records,[index,1]);
  project(state);
 }
 return {set:set,remove:removeFirst,reflect:reflect};
})(Object.create,Object.defineProperty,Reflect.deleteProperty,Object.keys,Array.prototype.push,Array.prototype.splice,Reflect.apply);'
}
