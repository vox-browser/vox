module webgl

import webgl.metal

struct MetalServiceUniformBlock {
    name string
mut:
    resources []metal.ShaderResource
    members []u32
    byte_size int
    binding u32
}

fn (mut object MetalServiceObject) clear_reflection() {
    for info in object.attributes { unsafe { info.name.free(); info.lookup.free(); info.values.free() } }
    for info in object.uniforms { unsafe { info.name.free(); info.lookup.free(); info.values.free() } }
    for block in object.blocks { unsafe { block.name.free(); block.resources.free(); block.members.free() } }
    object.attributes.clear()
    object.uniforms.clear()
    object.blocks.clear()
    object.locations.clear()
}

fn (mut object MetalServiceObject) reflect_program(program &metal.ShaderProgram) ! {
    resources := program.resources()!
    defer { for resource in resources { unsafe { resource.name.free() } }; unsafe { resources.free() } }
    object.clear_reflection()
    for resource in resources {
        if resource.kind != 1 || resource.name.starts_with('_webgl_native_') { continue }
        mut block_index := -1
        for index,block in object.blocks { if block.name==resource.name { block_index=index } }
        if block_index<0 {
            block_index=object.blocks.len
            object.blocks << MetalServiceUniformBlock{name:resource.name.clone(),byte_size:int(resource.byte_size)}
        }
        object.blocks[block_index].resources << metal.ShaderResource{...resource,name:''}
    }
    for resource in resources {
        if resource.kind==3 && resource.stage==.vertex {
            object.attributes << MetalServiceActiveInfo{name:resource.name.clone(),lookup:resource.name.clone(),type_:metal_service_gl_type(resource),size:int(resource.array_length),resource:metal.ShaderResource{...resource,name:''}}
        }
        if resource.kind !in [u32(100),7] { continue }
        mut block_index := -1
        for index,block in object.blocks {
            if block.resources.any(it.stage==resource.stage && it.binding==resource.binding) { block_index=index }
        }
        if object.uniforms.any(it.lookup==resource.name && it.block_index==block_index) { continue }
        name := if resource.array_length>1 || resource.array_stride>0 { resource.name+'[0]' } else { resource.name }
        index := object.uniforms.len
        object.uniforms << MetalServiceActiveInfo{name:name.clone(),lookup:resource.name.clone(),type_:metal_service_gl_type(resource),size:int(resource.array_length),resource:metal.ShaderResource{...resource,name:''},block_index:block_index,values:[]u8{len:if resource.kind==7 { int(resource.array_length)*4 } else { 0 }}}
        if block_index>=0 { object.blocks[block_index].members << u32(index) }
        else { for element in 0..int(resource.array_length) { object.locations << MetalServiceUniformLocation{uniform:index,element:element} } }
    }
}

fn (mut context MetalServiceContext) shader_parameter(name u32,pname u32) i32 {
    shader := context.object(name,9) or { return 0 }
    return match pname {
        0x8b80 { i32(shader.deleted) }
        0x8b81 { i32(shader.compiled) }
        0x8b4f { i32(shader.shader_type) }
        0x8b84 { if shader.log.len>0 { i32(shader.log.len+1) } else { i32(0) } }
        0x8b88 { if shader.source.len>0 { i32(shader.source.len+1) } else { i32(0) } }
        else { metal_service_error(invalid_enum); i32(0) }
    }
}

fn (mut context MetalServiceContext) program_parameter(name u32,pname u32) i32 {
    program := context.object(name,10) or { return 0 }
    return match pname {
        0x8b80 { i32(program.deleted) }
        0x8b82 { i32(program.linked) }
        0x8b83 { i32(program.validated) }
        0x8b84 { if program.log.len>0 { i32(program.log.len+1) } else { i32(0) } }
        0x8b85 { i32(program.attached.len) }
        0x8b86 { if program.linked { i32(program.uniforms.len) } else { i32(0) } }
        0x8b89 { if program.linked { i32(program.attributes.len) } else { i32(0) } }
        0x8b87 {
            mut longest:=0
            if program.linked { for info in program.uniforms { if info.name.len+1>longest { longest=info.name.len+1 } } }
            i32(longest)
        }
        0x8b8a {
            mut longest:=0
            if program.linked { for info in program.attributes { if info.name.len+1>longest { longest=info.name.len+1 } } }
            i32(longest)
        }
        0x8a36 { if program.linked { i32(program.blocks.len) } else { i32(0) } }
        0x8a35 {
            mut longest:=0
            if program.linked { for block in program.blocks { if block.name.len+1>longest { longest=block.name.len+1 } } }
            i32(longest)
        }
        else { metal_service_error(invalid_enum); i32(0) }
    }
}

fn (context &MetalServiceContext) linked_program(name u32) !&MetalServiceObject {
    program:=context.object(name,10)!
    if !program.linked { metal_service_error(invalid_operation); return error('Program is not linked') }
    return program
}

fn (program &MetalServiceObject) uniform_index(name string) int {
    for index,info in program.uniforms { if info.name==name || info.lookup==name { return index } }
    return -1
}
