// CSS.idl's replaceable CSSOM View attributes on Window.
module browserjs

fn window_viewport_binding_factory() string {
	return r'(function(read,window){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor;
 for(const name of ["innerWidth","innerHeight","devicePixelRatio"]){
  const accessors={
   get [name](){return read(this,name);},
   set [name](value){read(this,name);define(this,name,{value,writable:true,enumerable:true,configurable:true});}
  };
  define(window,name,descriptor(accessors,name));
 }
})'
}
