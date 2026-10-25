// Window.idl's replaceable self attribute, backed by Window::self().
module browserjs

fn window_self_binding_factory() string {
	return r'(function(){
 const native=__ladybirdWindowSelf,define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor;
 return function(window){
  const accessors={
   get self(){return native(this);},
   set self(value){native(this);define(this,"self",{value,writable:true,enumerable:true,configurable:true});}
  };
  define(window,"self",descriptor(accessors,"self"));
 };
})()'
}
