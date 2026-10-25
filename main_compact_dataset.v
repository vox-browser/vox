module main

import browserjs
import dom
import html
import x.json2

fn compact_dataset_query(root &dom.Node, input string) !string {
	element := root.as_element() or { return error('TypeError: Invalid dataset owner') }
	request := json2.decode[map[string]json2.Any](input)!
	op := json_string_property(request, 'op') or { 'read' }
	name := json_string_property(request, 'name') or { '' }
	mut string_map := html.DOMStringMap.create(element)
	if op == 'set' {
		value := json_string_property(request, 'value') or { return error('TypeError: Missing dataset value') }
		string_map.set_value_of_named_property(name, value) or {
			kind := if err.msg().contains("'-' followed") {
				'SyntaxError'
			} else {
				'InvalidCharacterError'
			}
			return error('${kind}: ${err.msg()}')
		}
	} else if op == 'delete' {
		string_map.delete_value(name)
	}
	// Refresh the compact attribute view after native writes and native-side
	// mutations. Later getAttribute()/setAttribute() calls share this state.
	records, attributes := browserjs.compact_attribute_state(element)
	return json2.encode({
		'pairs':            json2.Any(string_map.get_name_value_pairs().map(json2.Any([
			json2.Any(it.name),
			json2.Any(it.value),
		])))
		'attributeRecords': json2.Any(records)
		'attributes':       json2.Any(attributes)
	})
}

fn compact_dataset_bootstrap() string {
	return r'
function DOMStringMap(){throw new TypeError("Illegal DOMStringMap constructor");}
Object.defineProperty(globalThis,"DOMStringMap",{value:DOMStringMap,writable:true,configurable:true});
Object.defineProperty(DOMStringMap,"prototype",{writable:false});
Object.defineProperty(DOMStringMap.prototype,Symbol.toStringTag,{value:"DOMStringMap",configurable:true});
const __datasetMaps=new WeakMap();
function __compactElementDataset(object,state){
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml"&&state.namespaceURI!=="http://www.w3.org/2000/svg")return;
 Object.defineProperty(object,"dataset",{get:function(){
  const own=__elementApply(__elementRecordGet,__elementRecords,[this]);
  if(!own||(own.namespaceURI!=="http://www.w3.org/1999/xhtml"&&own.namespaceURI!=="http://www.w3.org/2000/svg"))throw new TypeError("Illegal dataset receiver");
  let map=__datasetMaps.get(this);if(map)return map;
  const request=function(op,name,value){
   let result;
   try{result=__queryElements(own.bridgeKey,"dataset",JSON.stringify({op,name,value}));}
   catch(error){const match=/^(SyntaxError|InvalidCharacterError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}
   own.attributeRecords=result.attributeRecords;own.attributes=result.attributes;
   return result.pairs;
  };
  const find=function(name){for(const pair of request("read"))if(pair[0]===name)return pair;};
  const write=function(name,value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");request("set",name,String(value));};
  const target=Object.create(DOMStringMap.prototype);
  map=new Proxy(target,{
   get(target,name,receiver){if(typeof name==="string"){const pair=find(name);if(pair)return pair[1];}return Reflect.get(target,name,receiver);},
   set(target,name,value){if(typeof name==="symbol")return Reflect.set(target,name,value);write(name,value);return true;},
   has(target,name){return typeof name==="string"&&!!find(name)||Reflect.has(target,name);},
   deleteProperty(target,name){if(typeof name==="symbol")return Reflect.deleteProperty(target,name);request("delete",name);return true;},
   ownKeys(target){return request("read").map(pair=>pair[0]).concat(Reflect.ownKeys(target).filter(name=>typeof name==="symbol"));},
   getOwnPropertyDescriptor(target,name){if(typeof name==="string"){const pair=find(name);if(pair)return{value:pair[1],writable:true,enumerable:true,configurable:true};}return Reflect.getOwnPropertyDescriptor(target,name);},
   defineProperty(target,name,descriptor){if(typeof name==="symbol")return Reflect.defineProperty(target,name,descriptor);if("get" in descriptor||"set" in descriptor||descriptor.configurable===false)return false;write(name,descriptor.value);return true;},
   preventExtensions(){return false;}
  });
  __datasetMaps.set(this,map);return map;
 },enumerable:true,configurable:true});
}
'
}
