module browserjs

import platform

fn C.JSGarbageCollect(context voidptr)

fn test_text_decoder_native_encodings_views_and_bom_options() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_text_decoder_binding()!
	assert runtime.evaluate_host(r'{
 const decoder=new TextDecoder(),bytes=new Uint8Array([99,208,175,0,240,159,152,128,99]),view=new DataView(bytes.buffer,1,7);
 for(const name of ["buffer","byteOffset","byteLength"])Object.defineProperty(view,name,{get(){throw "author getter";}});
 decoder.decode(view)==="Я\0😀"&&decoder.decode(bytes.subarray(1,8))==="Я\0😀"&&decoder.decode(new Uint8Array([65]).buffer)==="A"&&decoder.decode()===""&&decoder.decode(undefined)===""&&decoder.encoding==="utf-8"&&!decoder.fatal&&!decoder.ignoreBOM&&new TextDecoder("  UTF8\t").encoding==="utf-8"&&decoder.decode(new Uint8Array([239,187,191,65]))==="A"&&new TextDecoder("utf-8",{ignoreBOM:true}).decode(new Uint8Array([239,187,191,65]))==="\ufeffA";
 }')! == 'true'
	assert runtime.evaluate_host(r'{
 new TextDecoder("windows-1251").decode(new Uint8Array([207,232,234,224,225,243]))==="Пикабу"&&new TextDecoder("latin1").encoding==="windows-1252"&&new TextDecoder("latin1").decode(new Uint8Array([128]))==="€"&&new TextDecoder("utf-16be").decode(new Uint8Array([254,255,0,65,216,61,222,0]))==="A😀"&&new TextDecoder("shift_jis").decode(new Uint8Array([130,160]))==="あ";
 }')! == 'true'
}

fn test_text_decoder_streaming_flush_fatal_reuse_and_split_bom() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_text_decoder_binding()!
	assert runtime.evaluate_host(r'{
 const decoder=new TextDecoder(),fatal=new TextDecoder("utf-8",{fatal:true});let threw=false;
 const a=decoder.decode(new Uint8Array([239]),{stream:true}),b=decoder.decode(new Uint8Array([187,191,240,159]),{stream:true}),c=decoder.decode(new Uint8Array([152,128]));
 const d=decoder.decode(new Uint8Array([226]),{stream:true}),e=decoder.decode(),f=decoder.decode(new Uint8Array([239,187,191,65]));
 fatal.decode(new Uint8Array([226]),{stream:true});try{fatal.decode();}catch(error){threw=error instanceof TypeError;}
 a===""&&b===""&&c==="😀"&&d===""&&e==="�"&&f==="A"&&threw&&fatal.decode(new Uint8Array([239,187,191,66]))==="B"&&decoder.decode(new Uint8Array([192,175]))==="��";
 }')! == 'true'
}

fn test_text_decoder_webidl_conversion_order_and_original_exceptions() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_text_decoder_binding()!
	assert runtime.evaluate_host(r'{
 const order=[],decoder=new TextDecoder({toString(){order.push("label");return "UTF8";}},{get fatal(){order.push("fatal");return 1;},get ignoreBOM(){order.push("ignoreBOM");return 0;}});
 const bytes=new Uint8Array([65]);const text=decoder.decode(bytes,{get stream(){order.push("stream");bytes[0]=66;return false;}});
 let reads=0,errors=0;for(const input of [null,{},[],"A",new Proxy(bytes,{})]){try{decoder.decode(input,{get stream(){reads++;return false;}});}catch(error){if(error instanceof TypeError)errors++;}}
 const original={};let preserved=0;for(const operation of [()=>new TextDecoder({toString(){throw original;}}),()=>new TextDecoder("utf-8",{get fatal(){throw original;}}),()=>decoder.decode(bytes,{get stream(){throw original;}})]){try{operation();}catch(error){if(error===original)preserved++;}}
 let range=0;for(const label of ["replacement","bad-encoding",null]){try{new TextDecoder(label);}catch(error){if(error instanceof RangeError)range++;}}
 let symbol=false;try{new TextDecoder(Symbol());}catch(error){symbol=error instanceof TypeError;}
 order.join()==="label,fatal,ignoreBOM,stream"&&decoder.fatal&&!decoder.ignoreBOM&&text==="B"&&reads===0&&errors===5&&preserved===3&&range===3&&symbol;
 }')! == 'true'
	assert runtime.evaluate_host(r'{
 let errors=0;for(const options of [true,1,"",Symbol()])for(const operation of [()=>new TextDecoder("utf-8",options),()=>new TextDecoder().decode(undefined,options)]){try{operation();}catch(error){if(error instanceof TypeError)errors++;}}
 const order=[];try{new TextDecoder("bad-encoding",{get fatal(){order.push("fatal");return false;},get ignoreBOM(){order.push("ignoreBOM");return false;}});}catch(error){order.push(error instanceof RangeError);}
 errors===8&&order.join()==="fatal,ignoreBOM,true"&&new TextDecoder(undefined,null).decode(undefined,null)==="";
 }')! == 'true'
}

fn test_text_decoder_fixed_shared_buffers_and_detach_during_options() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_text_decoder_binding()!
	assert runtime.evaluate_host(r'{
 const decoder=new TextDecoder();let ok=true;
 if(typeof SharedArrayBuffer==="function"){
  const buffer=new SharedArrayBuffer(4);new Uint8Array(buffer).set([99,208,175,99]);
  ok=ok&&decoder.decode(new DataView(buffer,1,2))==="Я"&&decoder.decode(new Uint8Array(buffer,1,2))==="Я"&&decoder.decode(buffer)==="cЯc";
 }
 if(typeof ArrayBuffer.prototype.resize==="function"){
  const buffer=new ArrayBuffer(8,{maxByteLength:16});let rejected=0,reads=0;
  for(const input of [buffer,new Uint8Array(buffer),new DataView(buffer)])try{decoder.decode(input,{get stream(){reads++;return false;}});}catch(error){if(error instanceof TypeError)rejected++;}
  ok=ok&&rejected===3&&reads===0;
 }
 if(typeof SharedArrayBuffer==="function"&&typeof SharedArrayBuffer.prototype.grow==="function"){
  const buffer=new SharedArrayBuffer(8,{maxByteLength:16});let rejected=0;
  for(const input of [buffer,new Uint8Array(buffer),new DataView(buffer)])try{decoder.decode(input);}catch(error){if(error instanceof TypeError)rejected++;}
  ok=ok&&rejected===3;
 }
 if(typeof ArrayBuffer.prototype.transfer==="function"){
  const buffer=new ArrayBuffer(8),view=new Uint8Array(buffer);view[0]=65;
  ok=ok&&decoder.decode(view,{get stream(){buffer.transfer();return false;}})===""&&decoder.decode(buffer)===""&&decoder.decode(view)==="";
 }
 ok;
 }')! == 'true'
}

fn test_text_decoder_brands_descriptors_and_streaming_realm_lifetime() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut caller := platform.begin_thread_scratch('TextDecoder installation and stream')
	runtime.install_text_decoder_binding()!
	assert runtime.evaluate_host(r'{
 globalThis.decoder=new TextDecoder();decoder.decode(new Uint8Array([240,159]),{stream:true});
 let errors=0,reads=0;const getter=Object.getOwnPropertyDescriptor(TextDecoder.prototype,"encoding").get;
 for(const operation of [()=>TextDecoder(),()=>getter.call({}),()=>TextDecoder.prototype.decode.call({},undefined,{get stream(){reads++;}}),()=>new decoder.decode()])try{operation();}catch(error){if(error instanceof TypeError)errors++;}
 class Derived extends TextDecoder{}const derived=new Derived(),method=Object.getOwnPropertyDescriptor(TextDecoder.prototype,"decode"),constructor=Object.getOwnPropertyDescriptor(globalThis,"TextDecoder");
 errors===4&&reads===0&&derived instanceof TextDecoder&&derived.decode(new Uint8Array([65]))==="A"&&Object.prototype.toString.call(decoder)==="[object TextDecoder]"&&TextDecoder.length===0&&decoder.decode.length===0&&method.writable&&method.enumerable&&method.configurable&&constructor.writable&&!constructor.enumerable&&constructor.configurable&&!Object.getOwnPropertyDescriptor(TextDecoder,"prototype").writable;
 }')! == 'true'
	caller.finish()
	gc_collect()
	C.JSGarbageCollect(runtime.context)
	assert runtime.evaluate_host('decoder.decode(new Uint8Array([152,128]))==="😀"&&decoder.encoding==="utf-8"')! == 'true'
	runtime.evaluate_host('globalThis.TextDecoder=17')!
	runtime.install_text_decoder_binding()!
	assert runtime.evaluate_host('TextDecoder===17')! == 'true'
}
