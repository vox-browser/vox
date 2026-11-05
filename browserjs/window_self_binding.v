// Window.idl's replaceable self attribute, backed by Window::self().
module browserjs

// The factory also installs the Window.idl interface object. JavaScriptCore
// gives the global object an immutable prototype, so the brand check
// recognizes the actual global as well as ordinary Window.prototype
// inheritance. wasm-bindgen's web_sys::window() tests `globalThis instanceof
// Window`; Discord's Rust core panicked without it.
fn window_self_binding_factory() string {
	return r'(function(){
 const native=__ladybirdWindowSelf,define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor;
 return function(window){
  const accessors={
   get self(){return native(this);},
   set self(value){native(this);define(this,"self",{value,writable:true,enumerable:true,configurable:true});}
  };
  define(window,"self",descriptor(accessors,"self"));
  if(typeof window.Window!=="function"){
   function Window(){throw new TypeError("Illegal constructor")}
   const base=typeof window.EventTarget==="function"?window.EventTarget.prototype:Object.prototype;
   const prototype=Object.create(base);
   define(prototype,"constructor",{value:Window,writable:true,configurable:true});
   define(prototype,Symbol.toStringTag,{value:"Window",configurable:true});
   define(Window,"prototype",{value:prototype,writable:false,enumerable:false,configurable:false});
   const ordinary=Function.prototype[Symbol.hasInstance];
   define(Window,Symbol.hasInstance,{value:function(value){return value===window||ordinary.call(this,value)},configurable:true});
   define(window,"Window",{value:Window,writable:true,configurable:true});
   define(window,Symbol.toStringTag,{value:"Window",configurable:true});
  }
 };
})()'
}
