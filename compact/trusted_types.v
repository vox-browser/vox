module main

import trustedtypes
import x.json2

// The Trusted Types attribute and property type tables of the native
// factory, for TrustedTypePolicyFactory.getAttributeType() and
// getPropertyType().
fn compact_trusted_types_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid Trusted Types operation') }
	factory := trustedtypes.TrustedTypePolicyFactory.create()
	tag_name := json_string_property(request, 'tagName') or { '' }
	element_ns := json_string_property(request, 'elementNs')
	result := match op {
		'attribute' {
			factory.get_attribute_type(tag_name, json_string_property(request, 'attribute') or { '' },
				element_ns, json_string_property(request, 'attributeNs'))
		}
		'property' {
			factory.get_property_type(tag_name, json_string_property(request, 'property') or { '' },
				element_ns)
		}
		else {
			return error('Invalid Trusted Types operation')
		}
	}
	return if value := result { json2.encode(value) } else { 'null' }
}

// https://w3c.github.io/trusted-types/dist/spec/#trusted-type-policy-factory
fn compact_trusted_types_bootstrap() string {
	return r'
const __compactTrustedTypes=(function(){
 "use strict";
 const nativeCreatePolicy=globalThis.__ladybirdCreateTrustedTypePolicy;
 const nativeAttribute=globalThis.__ladybirdSetTrustedAttribute;
 delete globalThis.__ladybirdCreateTrustedTypePolicy;
 delete globalThis.__ladybirdSetTrustedAttribute;
 const data=new WeakMap(),policies=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set,has=WeakMap.prototype.has;
 const call=request=>__queryElements("","trustedTypes",JSON.stringify(request),true);
 const S=String;
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return S(value);};
 const nullableString=value=>value===null||value===undefined?null:string(value);
 const types={};
 function create(name,value){const object=Object.create(types[name].prototype);__elementApply(set,data,[object,{name,value}]);return object;}
 function record(receiver,name){const own=__elementApply(get,data,[receiver]);if(!own||own.name!==name)throw new TypeError("Illegal "+name+" receiver");return own;}
 for(const name of ["TrustedHTML","TrustedScript","TrustedScriptURL"]){
  const constructor=({[name]:function(){throw new TypeError("Illegal constructor");}})[name];
  types[name]=constructor;
  Object.defineProperty(constructor.prototype,"toString",{value:{toString(){return record(this,name).value;}}.toString,writable:true,enumerable:true,configurable:true});
  Object.defineProperty(constructor.prototype,"toJSON",{value:{toJSON(){return record(this,name).value;}}.toJSON,writable:true,enumerable:true,configurable:true});
  Object.defineProperty(constructor,"fromLiteral",{value:{fromLiteral(templateStringsArray){
   if(arguments.length===0)throw new TypeError("fromLiteral requires a template");
   if(!Array.isArray(templateStringsArray)||!Object.isFrozen(templateStringsArray)||!Array.isArray(templateStringsArray.raw)||templateStringsArray.length!==1)throw new TypeError("fromLiteral requires a template literal without substitutions");
   return create(name,String(templateStringsArray[0]));
  }}.fromLiteral,writable:true,enumerable:true,configurable:true});
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 function TrustedTypePolicy(){throw new TypeError("Illegal constructor");}
 function policyRecord(receiver){const own=__elementApply(get,policies,[receiver]);if(!own)throw new TypeError("Illegal TrustedTypePolicy receiver");return own;}
 // https://w3c.github.io/trusted-types/dist/spec/#create-a-trusted-type-algorithm
 function createTrusted(receiver,type,callbackName,input,rest){
  const own=policyRecord(receiver),callback=own.options[callbackName];
  const value=string(input);
  if(callback===undefined||callback===null)throw new TypeError("The policy has no "+callbackName+" callback");
  const result=__elementApply(callback,undefined,[value].concat(rest));
  return create(type,result===null||result===undefined?"":string(result));
 }
 for(const [method,type] of [["createHTML","TrustedHTML"],["createScript","TrustedScript"],["createScriptURL","TrustedScriptURL"]])
  Object.defineProperty(TrustedTypePolicy.prototype,method,{value:{[method](input,...rest){return createTrusted(this,type,method,input,rest);}}[method],writable:true,enumerable:true,configurable:true});
 Object.defineProperty(TrustedTypePolicy.prototype,"name",{get:function(){return policyRecord(this).name;},enumerable:true,configurable:true});
 function TrustedTypePolicyFactory(){throw new TypeError("Illegal constructor");}
 const factories=new WeakMap();
 function factoryRecord(receiver){const own=__elementApply(get,factories,[receiver]);if(!own)throw new TypeError("Illegal TrustedTypePolicyFactory receiver");return own;}
 const isType=name=>function(value){factoryRecord(this);const own=value!==null&&(typeof value==="object"||typeof value==="function")?__elementApply(get,data,[value]):undefined;return !!own&&own.name===name;};
 const factoryMembers={
  createPolicy(policyName,policyOptions){
   const own=factoryRecord(this);
   if(arguments.length===0)throw new TypeError("createPolicy requires a policy name");
   const name=string(policyName);
   const options={};
   if(policyOptions!==undefined&&policyOptions!==null){
    if(typeof policyOptions!=="object"&&typeof policyOptions!=="function")throw new TypeError("TrustedTypePolicyOptions must be an object");
    for(const member of ["createHTML","createScript","createScriptURL"]){
     const value=policyOptions[member];
     if(value!==undefined&&typeof value!=="function")throw new TypeError(member+" must be a function");
     options[member]=value;
    }
   }
   if(name==="default"&&own.defaultPolicy)throw new TypeError("A default policy already exists");
   if(typeof nativeCreatePolicy==="function")nativeCreatePolicy(name,options.createHTML,options.createScript,options.createScriptURL);
   const policy=Object.create(TrustedTypePolicy.prototype);
   __elementApply(set,policies,[policy,{name,options}]);
   own.names.push(name);
   if(name==="default")own.defaultPolicy=policy;
   return policy;
  },
  isHTML:isType("TrustedHTML"),isScript:isType("TrustedScript"),isScriptURL:isType("TrustedScriptURL"),
  getAttributeType(tagName,attribute,elementNs="",attrNs=""){
   factoryRecord(this);
   if(arguments.length<2)throw new TypeError("getAttributeType requires a tag name and an attribute");
   return call({op:"attribute",tagName:string(tagName),attribute:string(attribute),elementNs:nullableString(elementNs),attributeNs:nullableString(attrNs)});
  },
  getPropertyType(tagName,property,elementNs=""){
   factoryRecord(this);
   if(arguments.length<2)throw new TypeError("getPropertyType requires a tag name and a property");
   return call({op:"property",tagName:string(tagName),property:string(property),elementNs:nullableString(elementNs)});
  }
 };
 for(const [name,value] of Object.entries(factoryMembers)){
  if(typeof value==="function")Object.defineProperty(value,"name",{value:name});
  Object.defineProperty(TrustedTypePolicyFactory.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 }
 Object.defineProperty(TrustedTypePolicyFactory.prototype.getAttributeType,"length",{value:2});
 Object.defineProperty(TrustedTypePolicyFactory.prototype.getPropertyType,"length",{value:2});
 Object.defineProperty(TrustedTypePolicyFactory.prototype,"emptyHTML",{get:function(){factoryRecord(this);return create("TrustedHTML","");},enumerable:true,configurable:true});
 Object.defineProperty(TrustedTypePolicyFactory.prototype,"emptyScript",{get:function(){factoryRecord(this);return create("TrustedScript","");},enumerable:true,configurable:true});
 Object.defineProperty(TrustedTypePolicyFactory.prototype,"defaultPolicy",{get:function(){return factoryRecord(this).defaultPolicy||null;},enumerable:true,configurable:true});
 for(const [constructor,name] of [[TrustedTypePolicy,"TrustedTypePolicy"],[TrustedTypePolicyFactory,"TrustedTypePolicyFactory"]]){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 const factory=Object.create(TrustedTypePolicyFactory.prototype);
 __elementApply(set,factories,[factory,{names:[],defaultPolicy:null}]);
 Object.defineProperty(globalThis,"trustedTypes",{get:function(){return factory;},enumerable:true,configurable:true});
 let refresh;
 function input(value){const own=__elementApply(get,data,[value]);return own?{kind:own.name,value:own.value}:{kind:"",value:string(value)};}
 function elementState(receiver){
  let state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state){const local=__compactForeignNode(receiver);if(local)state=__elementApply(__elementRecordGet,__elementRecords,[local]);}
  if(!state)throw new TypeError("Illegal Element receiver");return state;
 }
 function setAttribute(receiver,namespace,name,value,namespaced){
  const state=elementState(receiver);
  namespace=namespace===null||namespace===undefined?null:string(namespace);name=string(name);const converted=input(value);
  if(typeof nativeAttribute!=="function"){
   if(name==="src")__setElementSource(state,converted.value);else if(name==="data")__setElementData(state,converted.value);else __setAttribute(state,name,converted.value);
   return;
  }
  const result=JSON.parse(nativeAttribute(state.bridgeKey,namespace,name,converted.kind,converted.value,namespaced,state.created?JSON.stringify(state):""));
  refresh(result);
  state.src=state.attributes.src||"";state.styleText=state.attributes.style||"";state.disabled=Object.prototype.hasOwnProperty.call(state.attributes,"disabled");
  if((namespace===null||namespace==="")&&state.tagName==="canvas"&&(name==="width"||name==="height")){state[name]=converted.value;__canvasResize(state);}
  __compactCustomElementFlush(state);
 }
 Object.defineProperty(Element.prototype,"setAttribute",{value:{setAttribute(name,value){
  elementState(this);if(arguments.length<2)throw new TypeError("setAttribute requires a name and value");setAttribute(this,null,name,value,false);
 }}.setAttribute,writable:true,enumerable:true,configurable:true});
 for(const state of Object.values(__state.elements)){const object=state.__object;if(object&&__elementApply(__elementRecordGet,__elementRecords,[object]))delete object.setAttribute;}
 return {nativeAttributes:typeof nativeAttribute==="function",input,setAttribute,setRefresh(value){refresh=value;}};
})();
'
}
