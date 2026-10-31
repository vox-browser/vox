// Script and link completion use ordinary native DOM EventTarget operations.
module browserjs

fn script_element_event_binding_factory() string {
	return r'(function(){
 "use strict";
 const native=__ladybirdScriptElementHandler,async=__ladybirdScriptElementAsync,define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor;
 const methods=EventTarget.prototype,add=methods.addEventListener,remove=methods.removeEventListener,dispatch=methods.dispatchEvent;
 define(globalThis,"__ladybirdScriptElementBind",{configurable:true,value:function(element){
  const accessors={
   get onload(){return native("get",this,"load");},
   set onload(value){native("set",this,"load",value);},
   get onerror(){return native("get",this,"error");},
   set onerror(value){native("set",this,"error",value);}
  };
  for(const name of ["onload","onerror"])define(element,name,descriptor(accessors,name));
  if(element.localName==="script")define(element,"async",{enumerable:true,configurable:true,
   get(){return async(this);},set(value){value=!!value;async(this,value);if(value)this.setAttribute("async","");else this.removeAttribute("async");}});
  for(const [name,value] of [["addEventListener",add],["removeEventListener",remove],["dispatchEvent",dispatch]])
   define(element,name,{value,writable:true,enumerable:true,configurable:true});
 }});
})()'
}
