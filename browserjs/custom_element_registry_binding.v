module browserjs

// The registry owns definitions in html.CustomElementRegistry. This factory
// performs observable WebIDL/getter/iterator operations in the actual realm;
// constructors and captured lifecycle callbacks remain real engine values.
fn custom_element_registry_binding_factory() string {
	return r'(function(operate,global){
 "use strict";
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,apply=Reflect.apply,T=TypeError,iteratorKey=Symbol.iterator;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function text(receiver,value){return operate("string",receiver,value)}
 function sequence(receiver,value){
  if(!object(value))throw new T("Expected a sequence object");
  const method=value[iteratorKey];if(typeof method!=="function")throw new T("Sequence is not iterable");
  const iterator=apply(method,value,[]);if(!object(iterator))throw new T("Iterator is not an object");
  const next=iterator.next,result=[];
  while(true){const item=apply(next,iterator,[]);if(!object(item))throw new T("Iterator result is not an object");if(item.done)return result;result[result.length]=text(receiver,item.value)}
 }
 function metadata(receiver,constructor){
  const prototype=constructor.prototype;if(!object(prototype))throw new T("Custom element prototype is not an object");
  const names=[],callbacks=[];
  function read(name){const callback=prototype[name];if(callback!==undefined){operate("callback",receiver,callback);names[names.length]=name;callbacks[callbacks.length]=callback;return true}return false}
  const normal=["connectedCallback","disconnectedCallback","connectedMoveCallback","adoptedCallback"];
  for(let i=0;i<normal.length;i++)read(normal[i]);
  let observed=[];if(read("attributeChangedCallback")){const value=constructor.observedAttributes;if(value!==undefined)observed=sequence(receiver,value)}
  const disabledValue=constructor.disabledFeatures,disabled=disabledValue===undefined?[]:sequence(receiver,disabledValue),form=!!constructor.formAssociated;
  if(form){const extra=["formAssociatedCallback","formResetCallback","formDisabledCallback","formStateRestoreCallback"];for(let i=0;i<extra.length;i++)read(extra[i])}
  return [names,observed,disabled,form,prototype,callbacks];
 }
 const prototype={};
 const CustomElementRegistry=new Proxy(function CustomElementRegistry(){throw new T("CustomElementRegistry requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototype);operate("construct",receiver);return receiver;
 }});
 define(CustomElementRegistry,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:CustomElementRegistry,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"CustomElementRegistry",configurable:true});
 const methods={
  define(name,constructor){
   operate("brand",this);if(arguments.length<2)throw new T("define requires two arguments");
   name=text(this,name);operate("callback",this,constructor);
   let options=arguments[2];if(options!=null&&!object(options))throw new T("ElementDefinitionOptions must be a dictionary");
   const raw=options==null?undefined:options.extends,extended=raw===undefined?undefined:text(this,raw);
   return operate("define",this,name,constructor,extended);
  },
  get(name){operate("brand",this);if(arguments.length===0)throw new T("get requires a name");return operate("get",this,text(this,name))},
  getName(constructor){operate("brand",this);if(arguments.length===0)throw new T("getName requires a callback");operate("callback",this,constructor);return operate("getName",this,constructor)},
  whenDefined(name){
   try{operate("brand",this);if(arguments.length===0)throw new T("whenDefined requires a name");return operate("whenDefined",this,text(this,name))}
   catch(error){return operate("rejected",null,error)}
  },
  upgrade(root){operate("brand",this);if(arguments.length===0)throw new T("upgrade requires a Node");return operate("upgrade",this,root)},
  initialize(root){operate("brand",this);if(arguments.length===0)throw new T("initialize requires a Node");return operate("initialize",this,root)}
 };
 for(const name of Object.keys(methods))define(prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 const registry=create(prototype);operate("global",registry);
 define(global,"customElements",descriptor({get customElements(){operate("windowBrand",this==null?global:this);return registry}},"customElements"));
 define(global,"CustomElementRegistry",{value:CustomElementRegistry,writable:true,configurable:true});
 return metadata;
})'
}
