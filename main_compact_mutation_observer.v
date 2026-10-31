module main

import browserjs
import dom
import x.json2

fn install_compact_mutation_observer_binding(mut binding CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	runtime.install_mutation_observer_binding(fn [mut binding] (source string) !&dom.Node {
		state := json2.decode[map[string]json2.Any](source)!
		key := json_string_property(state, 'bridgeKey') or { return error('TypeError: Expected a Node') }
		if key == '' { return binding.document.as_node() }
		return binding.node_for_key(key) or { binding.materialize_shadow_host(key, json2.Any(state))! }
	}, fn [mut binding] (records []&dom.MutationRecord) !string {
		mut result := []json2.Any{}
		for record in records {
			mut added := []json2.Any{}
			mut removed := []json2.Any{}
			for node in record.added_nodes { added << binding.node_state(node) }
			for node in record.removed_nodes { removed << binding.node_state(node) }
			mut current_attributes := json2.Any(json2.Null{})
			if record.type_ == .attributes {
				if element := record.target.as_element() {
					attribute_records, attributes := browserjs.compact_attribute_state(element)
					current_attributes = json2.Any({
						'records': json2.Any(attribute_records)
						'values':  json2.Any(attributes)
					})
				}
			}
			result << json2.Any({
				'type':               json2.Any(record.type_())
				'target':             binding.node_state(record.target)
				'addedNodes':         json2.Any(added)
				'removedNodes':       json2.Any(removed)
				'previousSibling':    if node := record.previous_sibling_() {
					binding.node_state(node)
				} else {
					json2.Any(json2.Null{})
				}
				'nextSibling':        if node := record.next_sibling_() {
					binding.node_state(node)
				} else {
					json2.Any(json2.Null{})
				}
				'attributeName':      if value := record.attribute_name {
					json2.Any(value)
				} else {
					json2.Any(json2.Null{})
				}
				'attributeNamespace': if value := record.attribute_namespace {
					json2.Any(value)
				} else {
					json2.Any(json2.Null{})
				}
				'oldValue':           if value := record.old_value {
					json2.Any(value)
				} else {
					json2.Any(json2.Null{})
				}
				'currentAttributes':  current_attributes
				'hasChildren':        json2.Any(record.target.has_children())
			})
		}
		return json2.encode(result)
	})!
}

fn compact_mutation_observer_bootstrap() string {
	return r'
// Active observers require mutations to reach the native DOM before another
// Promise job can be queued. The existing query boundary replays compact edits.
var __compactMutationObserverCount=0,__compactMutationFlushing=false;
function __compactMutationFlush(force){
 if((!force&&!__compactMutationObserverCount)||__compactMutationFlushing)return;
 __compactMutationFlushing=true;
 try{__queryElements("","documentValue","readyState");}finally{__compactMutationFlushing=false;}
}
const __mutationOperate=globalThis.__ladybirdMutationObserver,__mutationParse=JSON.parse,__mutationStringify=JSON.stringify;
delete globalThis.__ladybirdMutationObserver;
const __mutationStates=new WeakMap(),__mutationRecordStates=new WeakMap(),__mutationCreate=Object.create;
function __mutationState(receiver){const state=__elementApply(__compactNodeGet,__mutationStates,[receiver]);if(!state)throw new TypeError("Illegal MutationObserver receiver");return state;}
function MutationRecord(){throw new TypeError("Illegal MutationRecord constructor");}
for(const name of ["type","target","addedNodes","removedNodes","previousSibling","nextSibling","attributeName","attributeNamespace","oldValue"]){
 Object.defineProperty(MutationRecord.prototype,name,{get:function(){const state=__elementApply(__compactNodeGet,__mutationRecordStates,[this]);if(!state)throw new TypeError("Illegal MutationRecord receiver");return state[name];},enumerable:true,configurable:true});
}
function __mutationRecords(source){return __mutationParse(source).map(state=>{
 state.target=__queryElement(state.target);state.previousSibling=__queryElement(state.previousSibling);state.nextSibling=__queryElement(state.nextSibling);
 const own=__compactNodeState(state.target);
 if(state.currentAttributes){
  own.attributes=state.currentAttributes.values;own.attributeRecords=state.currentAttributes.records;
  own.id=own.attributes.id||"";own.className=own.attributes.class||"";own.styleText=own.attributes.style||"";own.src=own.attributes.src||"";
  own.disabled=Object.prototype.hasOwnProperty.call(own.attributes,"disabled");own.attributesDirty=false;
 }
 if(state.type==="childList"){__compactInvalidateContent(own);own.hasChildren=state.hasChildren;}
 const added=state.addedNodes.map(__queryElement),removed=state.removedNodes.map(__queryElement);
 state.addedNodes=__compactNodeList(()=>added);state.removedNodes=__compactNodeList(()=>removed);
 const record=__mutationCreate(MutationRecord.prototype);__elementApply(__elementRecordSet,__mutationRecordStates,[record,state]);return record;
});}
__mutationOperate("records",__mutationRecords);
const MutationObserver=new Proxy(function MutationObserver(callback){throw new TypeError("MutationObserver requires new");},{construct(target,args,newTarget){
 if(typeof args[0]!=="function")throw new TypeError("MutationObserver requires a callback function");
 const requested=newTarget.prototype,receiver=__mutationCreate(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:MutationObserver.prototype);
 __mutationOperate("construct",receiver,args[0]);__elementApply(__elementRecordSet,__mutationStates,[receiver,{active:false}]);return receiver;
}});
function __mutationOptions(value){
 if(value!=null&&typeof value!=="object"&&typeof value!=="function")throw new TypeError("MutationObserverInit must be a dictionary");
 const source=value==null?{}:value,result={};
 for(const name of ["attributeFilter","attributeOldValue","attributes","characterData","characterDataOldValue","childList","subtree"]){
  const member=source[name];if(member===undefined)continue;
  if(name==="attributeFilter"){
   if(member===null||(typeof member!=="object"&&typeof member!=="function"))throw new TypeError("attributeFilter must be a sequence");
   result[name]=[];for(const value of member){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");result[name].push(String(value));}
  }else result[name]=!!member;
 }
 return result;
}
Object.defineProperty(MutationObserver.prototype,"constructor",{value:MutationObserver,writable:true,configurable:true});
const __mutationMethods={
 observe(target,options){"use strict";const state=__mutationState(this);if(arguments.length<2)throw new TypeError("observe requires a target and options");const node=__compactNodeState(target),converted=__mutationOptions(options);__compactMutationFlush(true);__mutationOperate("observe",this,__mutationStringify(node),__mutationStringify(converted));if(!state.active){state.active=true;__compactMutationObserverCount++;}},
 disconnect(){"use strict";const state=__mutationState(this);__compactMutationFlush(true);__mutationOperate("disconnect",this);if(state.active){state.active=false;__compactMutationObserverCount--;}},
 takeRecords(){"use strict";__mutationState(this);__compactMutationFlush(true);return __mutationRecords(__mutationOperate("takeRecords",this));}
};
for(const name of ["observe","disconnect","takeRecords"])Object.defineProperty(MutationObserver.prototype,name,{value:__mutationMethods[name],writable:true,enumerable:true,configurable:true});
for(const constructor of [MutationObserver,MutationRecord]){
 Object.defineProperty(constructor,"prototype",{writable:false});Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});
 Object.defineProperty(globalThis,constructor.name,{value:constructor,writable:true,configurable:true});
}
const __mutationSetAttribute=__setAttribute,__mutationRemoveAttribute=__removeAttribute;
__setAttribute=function(){const result=__elementApply(__mutationSetAttribute,undefined,arguments);__compactMutationFlush(false);return result;};
__removeAttribute=function(){const result=__elementApply(__mutationRemoveAttribute,undefined,arguments);__compactMutationFlush(false);return result;};
'
}
