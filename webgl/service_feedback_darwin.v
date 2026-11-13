module webgl

import webgl.metal

@[heap]
struct MetalServiceFeedback {
mut:
    bindings [4]MetalServiceBufferRange
    cursors [4]int
    active bool
    paused bool
    mode u32
    program u32
}

struct MetalServiceFeedbackVarying {
    name string
    field string
    first u32
    count u32
    rows u32
    columns u32
}

fn (context &MetalServiceContext) feedback_program_active(name u32) bool {
    for _,feedback in context.feedbacks { if feedback.active && feedback.program==name { return true } }
    return false
}

fn (mut context MetalServiceContext) feedback() &MetalServiceFeedback {
    if feedback:=context.feedbacks[context.current_feedback] { return feedback }
    feedback:=&MetalServiceFeedback{}
    context.feedbacks[context.current_feedback]=feedback
    return feedback
}

fn (mut context MetalServiceContext) bind_feedback(target u32,name u32) {
    if target!=transform_feedback { metal_service_error(invalid_enum);return }
    current:=context.feedback()
    if current.active && !current.paused { metal_service_error(invalid_operation);return }
    if name!=0 {
        mut object:=context.objects[name] or { metal_service_error(invalid_operation);return }
        if object.kind!=8 || object.deleted { metal_service_error(invalid_operation);return }
        object.created=true
    }
    context.current_feedback=name
    feedback:=context.feedback()
    for index,binding in feedback.bindings { context.indexed_buffers[(u64(transform_feedback_buffer)<<32)|u32(index)]=binding }
    context.collect_buffers()
}

fn metal_service_feedback_varyings(name u32,count i32,names voidptr,mode u32) {
    mut context:=metal_service_current()
    if count<0 { metal_service_error(invalid_value);return }
    if mode !in [u32(0x8c8c),0x8c8d] { metal_service_error(invalid_enum);return }
    if mode==0x8c8d && count>4 { metal_service_error(invalid_value);return }
    mut program:=context.object(name,10) or { return }
    if count>0 && names==unsafe { nil } { metal_service_error(invalid_value);return }
    mut values:=[]string{cap:int(count)}
    for index in 0..int(count) {
        pointer:=unsafe { (&charptr(names))[index] }
        values<<if pointer==unsafe { nil } { '' } else { unsafe { cstring_to_vstring(pointer).clone() } }
    }
    unsafe { program.feedback_names.free() }
    program.feedback_names=values;program.feedback_mode=mode
}

fn (mut program MetalServiceObject) link_feedback(compiled &metal.ShaderProgram) ! {
    fields:=compiled.feedback_fields()!
    defer { for field in fields { unsafe { field.name.free() } };unsafe { fields.free() } }
    mut selected:=[]MetalServiceFeedbackVarying{}
    mut success:=false
    defer { if !success { for value in selected { unsafe { value.name.free();value.field.free() } };unsafe { selected.free() } } }
    mut components:=u32(0)
    for name in program.feedback_names {
        mut base:=name;mut first:=u32(0);mut indexed:=false
        if name.ends_with(']') {
            left:=name.last_index('[') or { return error('Invalid transform feedback varying '+name) }
            digits:=name[left+1..name.len-1]
            if digits.len==0 || !digits.bytes().all(it>=`0` && it<=`9`) { return error('Invalid transform feedback array index') }
            value:=digits.u64()
            if value>0xffffffff { return error('Transform feedback array index overflows') }
            base=name[..left];first=u32(value);indexed=true
        }
        matches:=fields.filter(it.name==base)
        defer { unsafe { matches.free() } }
        if matches.len!=1 { return error('Unknown transform feedback varying '+name) }
        field:=matches[0]
        if first>=field.array_length || field.scalar_type !in [u32(7),8,13] { return error('Invalid transform feedback varying type or array index') }
        count:=if indexed { u32(1) } else { field.array_length }
        size:=field.rows*field.columns*count
        if program.feedback_mode==0x8c8d && size>4 { return error('Separate transform feedback varying exceeds four components') }
        for prior in selected { if prior.field==base && first<prior.first+prior.count && prior.first<first+count { return error('Duplicate transform feedback varying '+name) } }
        components+=size
        if components>64 && program.feedback_mode==0x8c8c { return error('Interleaved transform feedback exceeds component limit') }
        selected<<MetalServiceFeedbackVarying{name:name.clone(),field:base.clone(),first:first,count:count,rows:field.rows,columns:field.columns}
    }
    if selected.len>0 { compiled.enable_feedback()! }
    for value in program.linked_feedback { unsafe { value.name.free();value.field.free() } };unsafe { program.linked_feedback.free() }
    program.linked_feedback=selected;program.linked_feedback_mode=program.feedback_mode;success=true
}

fn (mut context MetalServiceContext) begin_feedback(mode u32) {
    if mode !in [u32(0),1,4] { metal_service_error(invalid_enum);return }
    mut feedback:=context.feedback()
    if feedback.active { metal_service_error(invalid_operation);return }
    if context.current_program==0 { metal_service_error(invalid_operation);return }
    program:=context.linked_program(context.current_program) or { return }
    if program.linked_feedback.len==0 { metal_service_error(invalid_operation);return }
    slots:=if program.linked_feedback_mode==0x8c8c { 1 } else { program.linked_feedback.len }
    for index in 0..slots {
        binding:=feedback.bindings[index]
        object:=context.objects[binding.buffer] or { metal_service_error(invalid_operation);return }
        if object.gpu_buffer==unsafe { nil } || binding.offset>=object.gpu_buffer.size() { metal_service_error(invalid_operation);return }
    }
    feedback.active=true;feedback.paused=false;feedback.mode=mode;feedback.program=context.current_program;feedback.cursors=[4]int{}
}

fn (mut context MetalServiceContext) feedback_command(command int) {
    mut feedback:=context.feedback()
    if !feedback.active || (command==1 && feedback.paused) || (command==2 && (!feedback.paused || feedback.program!=context.current_program)) { metal_service_error(invalid_operation);return }
    if command==0 { feedback.active=false;feedback.paused=false;feedback.program=0;context.collect_programs() }
    else { feedback.paused=command==1 }
}

fn (mut context MetalServiceContext) capture_feedback(program &MetalServiceObject,streams []metal.VertexStream,mode u32,first int,count int,instances int,options metal.DrawOptions) ! {
    mut feedback:=context.feedback()
    if !feedback.active || feedback.paused { return }
    if feedback.program!=context.current_program || mode!=feedback.mode { metal_service_error(invalid_operation);return error('Transform feedback draw mode or program mismatch') }
    primitive_size:=if mode==0 { 1 } else if mode==1 { 2 } else { 3 }
    vertices:=(count/primitive_size)*primitive_size
    if vertices==0 || instances==0 { return }
    mut strides:=[4]int{}
    for index,varying in program.linked_feedback { strides[if program.linked_feedback_mode==0x8c8c { 0 } else { index }]+=int(varying.rows*varying.columns*varying.count)*4 }
    // Check every destination before executing or writing any output.
    for slot,stride in strides {
        if stride==0 { continue }
        binding:=feedback.bindings[slot]
        object:=context.objects[binding.buffer] or { metal_service_error(invalid_operation);return error('Missing transform feedback buffer') }
        if object.gpu_buffer==unsafe { nil } || binding.offset>object.gpu_buffer.size() { metal_service_error(invalid_operation);return error('Unallocated transform feedback buffer') }
        available:=if binding.length==0 { object.gpu_buffer.size()-binding.offset } else { binding.length }
        bytes:=u64(vertices)*u64(instances)*u64(stride)
        if available>object.gpu_buffer.size()-binding.offset || feedback.cursors[slot]>available || bytes>u64(available-feedback.cursors[slot]) { metal_service_error(invalid_operation);return error('Transform feedback buffer range is too short') }
        if streams.any(voidptr(it.buffer)==voidptr(object.gpu_buffer)) || options.uniform_blocks.any(voidptr(it.buffer)==voidptr(object.gpu_buffer)) { metal_service_error(invalid_operation);return error('Transform feedback buffer is also a shader input') }
        for previous in 0..slot { if strides[previous]>0 && feedback.bindings[previous].buffer==binding.buffer { metal_service_error(invalid_operation);return error('Transform feedback output bindings alias') } }
    }
    capture:=context.target.capture_vertices(program.program,streams,first,count,instances,options)!
    defer { capture.close() }
    mut destinations:=[4][]u8{}
    defer { for bytes in destinations { unsafe { bytes.free() } } }
    for slot,stride in strides { destinations[slot]=[]u8{len:vertices*instances*stride} }
    mut offsets:=[4]int{}
    for index,varying in program.linked_feedback {
        matches:=capture.fields.filter(it.name==varying.field)
        defer { unsafe { matches.free() } }
        if matches.len!=1 || matches[0].offset==~u32(0) { metal_service_error(invalid_operation);return error('Metal feedback field was not reflected') }
        field:=matches[0];slot:=if program.linked_feedback_mode==0x8c8c { 0 } else { index }
        width:=int(field.rows)*4
        for instance in 0..instances { for vertex in 0..vertices {
            mut output:=(instance*vertices+vertex)*strides[slot]+offsets[slot]
            for element in varying.first..varying.first+varying.count { for column in u32(0)..field.columns {
                input:=(instance*count+vertex)*capture.stride+int(field.offset)+int(element*field.array_stride)+int(column*field.matrix_stride)
                if input<0 || input+width>capture.bytes.len { metal_service_error(invalid_operation);return error('Metal feedback field exceeds output storage') }
                for byte in 0..width { destinations[slot][output+byte]=capture.bytes[input+byte] }
                output+=width
            } }
        } }
        offsets[slot]+=int(varying.rows*varying.columns*varying.count)*4
    }
    for slot,bytes in destinations {
        if bytes.len==0 { continue }
        binding:=feedback.bindings[slot];mut object:=context.objects[binding.buffer] or { return error('Feedback destination vanished') }
        object.gpu_buffer.write(binding.offset+feedback.cursors[slot],bytes)!
        feedback.cursors[slot]+=bytes.len
    }
    if mut query:=context.objects[context.active_queries[transform_feedback_primitives_written]] { query.query_result+=u64(vertices/primitive_size)*u64(instances) }
}
