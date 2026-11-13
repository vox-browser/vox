module metal

import webgl.shader

#include "@DIR/translated_program_darwin.h"
fn C.vox_metal_translation_from_msl(&char,&char,&char,u64) voidptr
fn C.vox_metal_translation_resource(voidptr,&C.VoxMetalShaderResource) i32
fn C.vox_metal_translation_feedback(voidptr,&C.VoxMetalFeedbackField) i32
fn C.vox_metal_translation_destroy(voidptr)
fn C.vox_metal_program_build(voidptr,voidptr,&char,u64) voidptr

// Own a native copy of V-generated source and reflection before compilation.
fn translation_descriptor(vertex shader.Translation, fragment shader.Translation) !voidptr {
 shader.link(vertex,fragment)!
 translated := C.vox_metal_translation_from_msl(vertex.source.str,fragment.source.str,vertex.feedback_source.str,u64(vertex.feedback_stride))
 if translated == unsafe{nil} { return error('Metal translation allocation failed') }
 mut transferred := false
 defer { if !transferred { C.vox_metal_translation_destroy(translated) } }
 for stage,translation in [vertex,fragment] {
  if translation.uniform_buffer_size > 0 {
   field := C.VoxMetalShaderResource{name:if stage==0 {c'_webgl_native_vertex_uniforms'} else {c'_webgl_native_fragment_uniforms'},kind:1,stage:u32(stage),binding:0,byte_size:u64(translation.uniform_buffer_size)}
   append_translated_resource(translated,field)!
  }
  for block in translation.uniform_blocks {
   append_translated_resource(translated,C.VoxMetalShaderResource{name:block.name.str,kind:1,stage:u32(stage),binding:block.binding,byte_size:u64(block.byte_size)})!
  }
  for field in translation.uniforms {
   append_translated_resource(translated,C.VoxMetalShaderResource{name:field.name.str,kind:100,stage:u32(stage),binding:field.binding,offset:u32(field.offset),array_stride:u32(field.array_stride),matrix_stride:u32(field.matrix_stride),base_type:field.scalar_type,semantic_type:field.semantic_type,row_major:if field.row_major {u32(1)} else {u32(0)},rows:u32(field.rows),columns:u32(field.columns),array_length:u32(field.array_length),byte_size:u64(field.byte_size)})!
  }
  for field in translation.textures {
   append_translated_resource(translated,C.VoxMetalShaderResource{name:field.name.str,kind:7,stage:u32(stage),binding:u32(field.binding),secondary_binding:u32(field.sampler_binding),rows:1,columns:1,array_length:u32(field.array_length),array_stride:if field.is_array {u32(1)} else {u32(0)},base_type:13,image_depth:if field.image_depth {u32(1)} else {u32(0)},image_dimension:u32(field.image_dimension),image_arrayed:if field.image_arrayed {u32(1)} else {u32(0)},image_scalar_type:field.image_scalar_type})!
  }
 }
 for field in vertex.inputs {
  scalar := if field.typ == 'int' || field.typ.starts_with('ivec') {u32(7)} else if field.typ == 'uint' || field.typ.starts_with('uvec') {u32(8)} else {u32(13)}
  append_translated_resource(translated,C.VoxMetalShaderResource{name:field.name.str,kind:3,stage:0,location:u32(field.location),rows:u32(field.rows),columns:u32(field.columns),array_length:1,base_type:scalar})!
 }
 for field in vertex.feedback_fields {
  native := C.VoxMetalFeedbackField{name:field.name.str,rows:u32(field.rows),columns:u32(field.columns),array_length:1,base_type:field.scalar_type,offset:u32(field.offset),matrix_stride:u32(field.matrix_stride)}
  if C.vox_metal_translation_feedback(translated,&native)!=1 { return error('Metal feedback reflection allocation failed') }
 }
 transferred=true
 return translated
}

pub fn ShaderProgram.from_translation(owner &DrawingBuffer, vertex shader.Translation, fragment shader.Translation) !&ShaderProgram {
 if owner.handle==unsafe{nil} {return error('Metal drawing buffer is closed')}
 translated:=translation_descriptor(vertex,fragment)!
 mut log := []u8{len:16384}
 defer { unsafe { log.free() } }
 // The native constructor owns the descriptor on both success and failure.
 handle := C.vox_metal_program_build(owner.handle,translated,&char(log.data),u64(log.len))
 if handle == unsafe{nil} { return error(unsafe { cstring_to_vstring(&char(log.data)).clone() }) }
 mut program := &ShaderProgram{handle:handle,owner:owner}
 program.initialize_uniforms() or { program.close();return err }
 return program
}

fn append_translated_resource(handle voidptr, field C.VoxMetalShaderResource) ! {
 if C.vox_metal_translation_resource(handle,&field)!=1 { return error('Metal resource reflection allocation failed') }
}

fn translate_sources(vertex string,fragment string,context_version int,bindings map[string]int) !(shader.Translation,shader.Translation) {
 if context_version !in [2,3] {return error('Invalid Metal WebGL context version')}
 v:=shader.translate_with_bindings(vertex,.vertex,bindings)!
 f:=shader.translate(fragment,.fragment)!
 if context_version==2 && (v.version!=100 || f.version!=100) {return error('ESSL300 requires WebGL2')}
 return v,f
}

fn C.vox_metal_shader_log(&char,u64,&char)
fn C.vox_metal_validate_msl(voidptr,&char,&char,u64) i32

pub fn validate_shader(owner &DrawingBuffer, source string, fragment bool, context_version int) ! {
 if owner.handle==unsafe{nil} {return error('Metal drawing buffer is closed')}
 if context_version !in [2,3] {return error('Invalid WebGL context version')}
 translated:=shader.translate(source,if fragment {shader.Stage.fragment} else {shader.Stage.vertex})!
 if context_version==2 && translated.version!=100 {return error('ESSL300 requires WebGL2')}
 mut log:=[]u8{len:16384}
 defer {unsafe{log.free()}}
 if C.vox_metal_validate_msl(owner.handle,translated.source.str,&char(log.data),u64(log.len))!=1 {return error(unsafe{cstring_to_vstring(&char(log.data)).clone()})}
}

// Native conformance fixtures call the same V compiler through this C ABI.
@[export: 'vox_v_program_create_bound']
fn program_create_bridge(target voidptr, vertex &char, vertex_length i32, fragment &char, fragment_length i32, version i32, native_bindings &C.VoxMetalAttributeBinding, binding_count u64, log &char, capacity u64) voidptr {
 C.vox_metal_shader_log(log,capacity,c'')
 if target==unsafe{nil} || vertex==unsafe{nil} || fragment==unsafe{nil} || vertex_length<0 || fragment_length<0 || binding_count>65536 || (binding_count>0 && native_bindings==unsafe{nil}) {
  C.vox_metal_shader_log(log,capacity,c'Invalid native shader arguments');return unsafe{nil}
 }
 mut bindings:=map[string]int{}
 for i in 0..int(binding_count) {
  field:=unsafe{native_bindings[i]}
  if field.name==unsafe{nil} {C.vox_metal_shader_log(log,capacity,c'Invalid attribute name');return unsafe{nil}}
  bindings[unsafe{cstring_to_vstring(field.name)}]=int(field.location)
 }
 v,f:=translate_sources(unsafe{tos(vertex,int(vertex_length))},unsafe{tos(fragment,int(fragment_length))},int(version),bindings) or {C.vox_metal_shader_log(log,capacity,err.msg().str);return unsafe{nil}}
 translated:=translation_descriptor(v,f) or {C.vox_metal_shader_log(log,capacity,err.msg().str);return unsafe{nil}}
 return C.vox_metal_program_build(target,translated,log,capacity)
}
