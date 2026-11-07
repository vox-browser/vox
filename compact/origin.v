module main

import dom
import url as liburl
import x.json2

// The Origin interface. Script holds an origin as its self-contained
// serialization, which keeps the nonce of an opaque origin, so comparisons
// need no retained native state.
// https://html.spec.whatwg.org/multipage/browsers.html#the-origin-interface
fn compact_origin_result(origin dom.Origin) string {
	return json2.encode({
		'token':  json2.Any(origin.serialize_for_ipc())
		'opaque': json2.Any(origin.is_opaque())
	})
}

fn compact_origin_of_url(input string, base ?&liburl.URL) ?dom.Origin {
	parsed := liburl.basic_parse(input, base) or { return none }
	return dom.origin_from_liburl(parsed.origin())
}

fn (mut binding CompactElementQueryBinding) origin_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid origin operation') }
	match op {
		// https://html.spec.whatwg.org/multipage/browsers.html#dom-origin-constructor
		'opaque' {
			return compact_origin_result(dom.origin_create_opaque())
		}
		// Step 2 of Origin.from(): a string is basic URL parsed.
		'url' {
			input := json_string_property(request, 'url') or { '' }
			origin := compact_origin_of_url(input, none) or { return '{}' }
			return compact_origin_result(origin)
		}
		// A Window's extract an origin steps return its relevant settings
		// object's origin when that is same origin-domain with the entry one.
		'document' {
			key := json_string_property(request, 'document') or { '' }
			document := if key == '' { binding.document } else { binding.documents[key] or { return '{}' } }
			if !document.origin().is_same_origin_domain(binding.document.origin()) {
				return '{}'
			}
			return compact_origin_result(document.origin())
		}
		// HTMLHyperlinkElementUtils: the origin of the element's url, if any.
		'element' {
			key := json_string_property(request, 'element') or { '' }
			node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
			element := node.as_element() or { return '{}' }
			href := element.get_attribute('href') or { return '{}' }
			base := liburl.parse(element.document().base_url().serialize()) or { return '{}' }
			origin := compact_origin_of_url(href, &base) or { return '{}' }
			return compact_origin_result(origin)
		}
		'compare' {
			first := dom.origin_from_ipc(json_string_property(request, 'a') or { '' })
			second := dom.origin_from_ipc(json_string_property(request, 'b') or { '' })
			same := if json_bool_property(request, 'site') {
				first.is_same_site(second)
			} else {
				first.is_same_origin(second)
			}
			return json2.encode(same)
		}
		else {
			return error('Invalid origin operation')
		}
	}
}

fn compact_origin_bootstrap() string {
	return r'
(function(){
 const tokens=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 function call(request){return __queryElements("","origin",JSON.stringify(request),true);}
 function record(receiver){const own=__elementApply(get,tokens,[receiver]);if(!own)throw new TypeError("Illegal Origin receiver");return own;}
 function create(result){
  if(!result||result.token===undefined)return null;
  const object=Object.create(Origin.prototype);__elementApply(set,tokens,[object,result]);return object;
 }
 function Origin(){
  if(new.target===undefined)throw new TypeError("Constructor Origin requires new");
  const object=Object.create(new.target.prototype);__elementApply(set,tokens,[object,call({op:"opaque"})]);return object;
 }
 // https://html.spec.whatwg.org/multipage/browsers.html#extract-an-origin
 function extract(value){
  if(value===null||(typeof value!=="object"&&typeof value!=="function"))return undefined;
  if(__elementApply(get,tokens,[value]))return create(record(value));
  if(value===globalThis||value===globalThis.window)return create(call({op:"document",document:""}));
  if(typeof URL==="function"&&value instanceof URL)return create(call({op:"url",url:value.href}));
  const element=__elementApply(__elementRecordGet,__elementRecords,[value]);
  if(element){
   const name=String(element.tagName).toLowerCase();
   if(element.namespaceURI==="http://www.w3.org/1999/xhtml"&&(name==="a"||name==="area"))return create(call({op:"element",element:element.bridgeKey,state:element.created?element:undefined}));
   return undefined;
  }
  if(typeof value.postMessage==="function"&&typeof value.document==="object"){
   let document=null;try{document=value.document;}catch(error){return null;}
   if(!document)return null;
   let state=null;try{state=__compactDocumentState(document);}catch(error){return null;}
   return state?create(call({op:"document",document:state.bridgeKey||""})):null;
  }
  return undefined;
 }
 Object.defineProperty(Origin,"from",{value:function from(value){
  const extracted=extract(value);
  if(extracted)return extracted;
  if(extracted===undefined&&typeof value==="string"){const parsed=create(call({op:"url",url:value}));if(parsed)return parsed;}
  throw new TypeError("Value is not a valid Origin");
 },writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Origin.prototype,"opaque",{get:function(){return record(this).opaque;},enumerable:true,configurable:true});
 for(const [name,site] of [["isSameOrigin",false],["isSameSite",true]])Object.defineProperty(Origin.prototype,name,{value:{[name](other){
  const own=record(this);if(arguments.length<1)throw new TypeError(name+" requires an argument");
  return call({op:"compare",a:own.token,b:record(other).token,site});
 }}[name],writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Origin.prototype,Symbol.toStringTag,{value:"Origin",configurable:true});
 Object.defineProperty(Origin,"prototype",{writable:false,enumerable:false,configurable:false});
 Object.defineProperty(globalThis,"Origin",{value:Origin,writable:true,enumerable:false,configurable:true});
})();
'
}
