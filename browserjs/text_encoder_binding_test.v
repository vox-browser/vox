module browserjs

import platform

fn C.JSGarbageCollect(context voidptr)

fn test_text_encoder_native_utf8_and_usv_string_conversion() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_text_encoder_binding()!
	assert runtime.evaluate_host(r'{
 const encoder=new TextEncoder();
 const bytes=encoder.encode("A\0Я€😀\ud800X\udc00");
 bytes instanceof Uint8Array&&bytes.join() === "65,0,208,175,226,130,172,240,159,152,128,239,191,189,88,239,191,189"&&encoder.encoding === "utf-8"&&encoder.encode().length===0&&encoder.encode(undefined).length===0&&encoder.encode(null).join()==="110,117,108,108"&&encoder.encode()!==encoder.encode();
 }')! == 'true'
	assert runtime.evaluate_host(r'{
 let conversions=0;const original={};let preserved=false;
 const bytes=new TextEncoder().encode({toString(){conversions++;return "😀";}});
 try{new TextEncoder().encode({toString(){throw original;}})}catch(error){preserved=error===original;}
 let symbol=false;try{new TextEncoder().encode(Symbol());}catch(error){symbol=error instanceof TypeError;}
 conversions===1&&bytes.join()==="240,159,152,128"&&preserved&&symbol;
 }')! == 'true'
}

fn test_text_encoder_encode_into_whole_scalars_and_typed_array_offsets() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_text_encoder_binding()!
	assert runtime.evaluate_host(r'{
 const encoder=new TextEncoder(),backing=new Uint8Array(12).fill(99),destination=backing.subarray(2,9);
 for(const name of ["buffer","byteOffset","byteLength","length"])Object.defineProperty(destination,name,{get(){throw "author getter";}});
 const result=encoder.encodeInto("A😀€",destination);
 const empty=encoder.encodeInto("😀",new Uint8Array(3));
 const replacement=new Uint8Array(3),replaced=encoder.encodeInto("\ud800",replacement);
 result.read===3&&result.written===5&&Object.getPrototypeOf(result)===Object.prototype&&Object.keys(result).join()==="read,written"&&backing.join()==="99,99,65,240,159,152,128,99,99,99,99,99"&&empty.read===0&&empty.written===0&&replaced.read===1&&replaced.written===3&&replacement.join()==="239,191,189";
 }')! == 'true'
	assert runtime.evaluate_host(r'{
 const encoder=new TextEncoder();let errors=0,reads=0;const original={};let preserved=false;
 for(const destination of [null,{},[],new Uint8ClampedArray(8),new Int8Array(8),new DataView(new ArrayBuffer(8)),new Proxy(new Uint8Array(8),{})]){
  try{encoder.encodeInto({toString(){reads++;return "x";}},destination);}catch(error){if(error instanceof TypeError)errors++;}
 }
 try{encoder.encodeInto({toString(){throw original;}},null);}catch(error){preserved=error===original;}
 errors===7&&reads===7&&preserved;
 }')! == 'true'
	assert runtime.evaluate_host(r'{
 const encoder=new TextEncoder();let ok=true;
 if(typeof SharedArrayBuffer==="function"){
  const destination=new Uint8Array(new SharedArrayBuffer(8),2,4),result=encoder.encodeInto("😀X",destination);
  ok=ok&&result.read===2&&result.written===4&&destination.join()==="240,159,152,128";
 }
 if(typeof ArrayBuffer.prototype.resize==="function"){
  const buffer=new ArrayBuffer(8,{maxByteLength:16}),destination=new Uint8Array(buffer,2,4);
  let reads=0,rejected=false;try{encoder.encodeInto({toString(){reads++;buffer.resize(3);return "x";}},destination);}catch(error){rejected=error instanceof TypeError;}
  buffer.resize(8);let grownRejected=false;try{encoder.encodeInto("xy",destination);}catch(error){grownRejected=error instanceof TypeError;}
  ok=ok&&reads===1&&rejected&&grownRejected&&destination[0]===0;
 }
 if(typeof SharedArrayBuffer==="function"&&typeof SharedArrayBuffer.prototype.grow==="function"){
  const buffer=new SharedArrayBuffer(8,{maxByteLength:16}),destination=new Uint8Array(buffer);
  let rejected=false;try{encoder.encodeInto("x",destination);}catch(error){rejected=error instanceof TypeError;}
  ok=ok&&rejected&&destination[0]===0;
 }
 if(typeof ArrayBuffer.prototype.transfer==="function"){
  const buffer=new ArrayBuffer(8),destination=new Uint8Array(buffer);
  const result=encoder.encodeInto({toString(){buffer.transfer();return "x";}},destination);
  ok=ok&&result.read===0&&result.written===0;
 }
 ok;
 }')! == 'true'
}

fn test_text_encoder_webidl_brands_descriptors_and_realm_lifetime() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut caller := platform.begin_thread_scratch('TextEncoder installation')
	runtime.install_text_encoder_binding()!
	assert runtime.evaluate_host(r'{
 globalThis.encoder=new TextEncoder();globalThis.retainedBytes=encoder.encode("Пикабу😀");
 let errors=0,reads=0;const getter=Object.getOwnPropertyDescriptor(TextEncoder.prototype,"encoding").get;
 for(const operation of [()=>TextEncoder(),()=>getter.call({}),()=>TextEncoder.prototype.encode.call({}, {toString(){reads++;return "x";}}),()=>TextEncoder.prototype.encodeInto.call({},"x",new Uint8Array(1)),()=>encoder.encodeInto("x"),()=>new encoder.encode()]){try{operation();}catch(error){if(error instanceof TypeError)errors++;}}
 class Derived extends TextEncoder{}const derived=new Derived();
 const descriptor=Object.getOwnPropertyDescriptor(TextEncoder.prototype,"encode");
 const constructor=Object.getOwnPropertyDescriptor(globalThis,"TextEncoder");
 errors===6&&reads===0&&derived instanceof TextEncoder&&derived.encode("x")[0]===120&&Object.prototype.toString.call(encoder)==="[object TextEncoder]"&&TextEncoder.length===0&&encoder.encode.length===0&&encoder.encodeInto.length===2&&descriptor.enumerable&&descriptor.writable&&descriptor.configurable&&constructor.writable&&!constructor.enumerable&&constructor.configurable&&!Object.getOwnPropertyDescriptor(TextEncoder,"prototype").writable;
 }')! == 'true'
	caller.finish()
	gc_collect()
	C.JSGarbageCollect(runtime.context)
	assert runtime.evaluate_host('encoder.encoding === "utf-8"&&encoder.encode("Я").join()==="208,175"&&retainedBytes.join()==="208,159,208,184,208,186,208,176,208,177,209,131,240,159,152,128"')! == 'true'
	assert runtime.evaluate_host('globalThis.TextEncoder=17;true')! == 'true'
	runtime.install_text_encoder_binding()!
	assert runtime.evaluate_host('TextEncoder===17')! == 'true'
}
