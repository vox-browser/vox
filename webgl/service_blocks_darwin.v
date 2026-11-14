module webgl

import webgl.metal

struct MetalServiceBufferRange {
    buffer u32
    offset int
    length int // Zero denotes a base binding, covering the current allocation.
}

fn (mut context MetalServiceContext) bind_indexed_buffer(target u32,index u32,name u32,offset i64,length i64,range bool) {
    if target !in [uniform_buffer,transform_feedback_buffer] { metal_service_error(invalid_enum);return }
    limit:=if target==uniform_buffer { u32(30) } else { u32(4) }
    if index>=limit { metal_service_error(invalid_value);return }
    alignment:=if target==uniform_buffer { i64(256) } else { i64(4) }
    if name!=0 && range && (offset<0 || length<=0 || offset%alignment!=0 || (target==transform_feedback_buffer && length%4!=0)) { metal_service_error(invalid_value);return }
    if target==transform_feedback_buffer && context.feedback().active { metal_service_error(invalid_operation);return }
    if name!=0 {
        mut object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=0 || object.deleted { metal_service_error(invalid_operation);return }
        object.created=true
    }
    context.buffers[target]=name
    key:=(u64(target)<<32)|index
    context.indexed_buffers[key]=MetalServiceBufferRange{buffer:name,offset:if name!=0 && range { int(offset) } else { 0 },length:if name!=0 && range { int(length) } else { 0 }}
    if target==transform_feedback_buffer {
        mut feedback:=context.feedback()
        feedback.bindings[int(index)]=context.indexed_buffers[key]
    }
    context.collect_buffers()
}

fn (context &MetalServiceContext) uniform_block_bindings(program &MetalServiceObject) ![]metal.UniformBlockBinding {
    mut result:=[]metal.UniformBlockBinding{}
    for block in program.blocks {
        binding:=context.indexed_buffers[(u64(uniform_buffer)<<32)|block.binding]
        object:=context.objects[binding.buffer] or { metal_service_error(invalid_operation);return error('No uniform buffer bound for '+block.name) }
        if object.gpu_buffer==unsafe { nil } || binding.offset>object.gpu_buffer.size() { metal_service_error(invalid_operation);return error('Uniform buffer is not allocated') }
        length:=if binding.length==0 { object.gpu_buffer.size()-binding.offset } else { binding.length }
        if length<block.byte_size || length>object.gpu_buffer.size()-binding.offset { metal_service_error(invalid_operation);return error('Uniform buffer range does not cover '+block.name) }
        for resource in block.resources {
            result<<metal.UniformBlockBinding{stage:resource.stage,binding:resource.binding,buffer:object.gpu_buffer,offset:binding.offset,length:length}
        }
    }
    return result
}

fn metal_service_uniform_indices(program_name u32,count i32,names voidptr,output &u32) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    if count<0 { metal_service_error(invalid_value);return }
    program:=context.linked_program(program_name) or { return }
    if count==0 || names==unsafe { nil } || output==unsafe { nil } { return }
    for i in 0..int(count) {
        name:=unsafe { (&charptr(names))[i] }
        index:=if name==unsafe { nil } { -1 } else { program.uniform_index(unsafe { cstring_to_vstring(name) }) }
        unsafe { output[i]=if index<0 { ~u32(0) } else { u32(index) } }
    }
}

fn metal_service_active_uniforms(program_name u32,count i32,indices &u32,pname u32,output &i32) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    if count<0 { metal_service_error(invalid_value);return }
    program:=context.linked_program(program_name) or { return }
    if pname !in [uniform_type,uniform_size,u32(0x8a39),uniform_block_index,uniform_offset,uniform_array_stride,uniform_matrix_stride,uniform_is_row_major] { metal_service_error(invalid_enum);return }
    if count==0 || indices==unsafe { nil } || output==unsafe { nil } { return }
    for i in 0..int(count) {
        index:=unsafe { indices[i] }
        if index>=u32(program.uniforms.len) { metal_service_error(invalid_value);return }
    }
    for i in 0..int(count) {
        info:=program.uniforms[int(unsafe { indices[i] })]
        value:=match pname {
            uniform_type { int(info.type_) } uniform_size { info.size } u32(0x8a39) { info.name.len+1 }
            uniform_block_index { info.block_index } uniform_offset { if info.block_index<0 { -1 } else { int(info.resource.offset) } }
            uniform_array_stride { if info.block_index<0 { -1 } else { int(info.resource.array_stride) } }
            uniform_matrix_stride { if info.block_index<0 { -1 } else { int(info.resource.matrix_stride) } }
            uniform_is_row_major { int(info.resource.row_major) }
            else { 0 }
        }
        unsafe { output[i]=i32(value) }
    }
}

fn metal_service_block_parameter(program_name u32,index u32,pname u32,capacity i32,output &i32) {
    context:=metal_service_current()
    if context==unsafe { nil } { return }
    if capacity<0 { metal_service_error(invalid_value);return }
    program:=context.linked_program(program_name) or { return }
    if index>=u32(program.blocks.len) { metal_service_error(invalid_value);return }
    block:=program.blocks[int(index)]
    if pname !in [uniform_block_binding,uniform_block_data_size,uniform_block_name_length,uniform_block_active_uniforms,uniform_block_active_uniform_indices,uniform_block_referenced_by_vertex_shader,uniform_block_referenced_by_fragment_shader] { metal_service_error(invalid_enum);return }
    required:=if pname==uniform_block_active_uniform_indices { block.members.len } else { 1 }
    if int(capacity)<required { metal_service_error(invalid_operation);return }
    if output==unsafe { nil } { return }
    if pname==uniform_block_active_uniform_indices { for i,value in block.members { unsafe { output[i]=i32(value) } };return }
    value:=match pname {
        uniform_block_binding { int(block.binding) } uniform_block_data_size { block.byte_size } uniform_block_name_length { block.name.len+1 }
        uniform_block_active_uniforms { block.members.len }
        uniform_block_referenced_by_vertex_shader { int(block.resources.any(it.stage==.vertex)) }
        else { int(block.resources.any(it.stage==.fragment)) }
    }
    unsafe { *output=i32(value) }
}
