module main

import compression
import encoding.base64
import x.json2

// https://compression.spec.whatwg.org/
// Scripts see CompressionStream and DecompressionStream as TransformStreams.
// Chunks are validated and copied as they are written; the translated codec
// then processes the complete input when the writable side closes.
fn compact_compression_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	kind := json_string_property(request, 'kind') or { '' }
	format := compression.parse_compression_format(json_string_property(request, 'format') or { '' })!
	data := base64.decode(json_string_property(request, 'data') or { '' })
	match kind {
		'checkCompress' {
			_ = compression.CompressionStream.construct_impl(format)!
			return 'null'
		}
		'checkDecompress' {
			_ = compression.DecompressionStream.construct_impl(format)!
			return 'null'
		}
		'compress' {
			mut stream := compression.CompressionStream.construct_impl(format)!
			mut writable := stream.writable()
			if data.len > 0 { writable.write(data)! }
			writable.close()!
			mut readable := stream.readable()
			return json2.encode(base64.encode(readable.read_all()))
		}
		'decompress' {
			mut stream := compression.DecompressionStream.construct_impl(format)!
			mut writable := stream.writable()
			if data.len > 0 {
				writable.write(data) or { return error('TypeError: ${err.msg().trim_string_left('TypeError: ')}') }
			}
			writable.close() or { return error('TypeError: ${err.msg().trim_string_left('TypeError: ')}') }
			mut readable := stream.readable()
			return json2.encode(base64.encode(readable.read_all()))
		}
		else {
			return error('Invalid compression operation')
		}
	}
}

fn compact_compression_streams_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set,toString=Object.prototype.toString;
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 function call(request){
  try{return __queryElements("","compressionTransform",JSON.stringify(request),true);}
  catch(error){const match=/^TypeError:\s*(.*)/.exec(String(error.message));throw new TypeError(match?match[1]:String(error.message));}
 }
 function bytes(chunk){
  if(ArrayBuffer.isView(chunk)){
   if(toString.call(chunk.buffer)!=="[object ArrayBuffer]")throw new TypeError("The chunk must not be backed by a SharedArrayBuffer");
   return new Uint8Array(chunk.buffer,chunk.byteOffset,chunk.byteLength).slice();
  }
  if(toString.call(chunk)==="[object ArrayBuffer]")return new Uint8Array(chunk).slice();
  throw new TypeError("The chunk must be a BufferSource");
 }
 function encode(chunks){
  let text="";
  for(const chunk of chunks)for(let index=0;index<chunk.length;index+=0x8000)text+=String.fromCharCode.apply(null,chunk.subarray(index,index+0x8000));
  return btoa(text);
 }
 function decode(text){const binary=atob(text),output=new Uint8Array(binary.length);for(let index=0;index<binary.length;index++)output[index]=binary.charCodeAt(index);return output;}
 function transform(kind,format){
  const chunks=[];
  return new TransformStream({
   transform(chunk){chunks.push(bytes(chunk));},
   flush(controller){const output=decode(call({kind,format,data:encode(chunks)}));chunks.length=0;if(output.length)controller.enqueue(output);}
  });
 }
 function record(receiver){const own=__elementApply(get,records,[receiver]);if(!own)throw new TypeError("Illegal compression stream receiver");return own;}
 for(const [name,kind] of [["CompressionStream","compress"],["DecompressionStream","decompress"]]){
  const constructor={[name]:function(format){
   if(!new.target)throw new TypeError(name+" constructor requires new");
   if(arguments.length<1)throw new TypeError(name+" requires a format");
   format=string(format);
   call({kind:kind==="compress"?"checkCompress":"checkDecompress",format});
   __elementApply(set,records,[this,transform(kind,format)]);
  }}[name];
  Object.defineProperty(constructor,"prototype",{writable:false});
  for(const side of ["readable","writable"])Object.defineProperty(constructor.prototype,side,{get:function(){return record(this)[side];},enumerable:true,configurable:true});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
})();
'
}
