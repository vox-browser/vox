module webgl

import webgl.metal

fn metal_service_valid_query(target u32) bool {
    return target in [any_samples_passed,any_samples_passed_conservative,transform_feedback_primitives_written]
}

fn (mut context MetalServiceContext) begin_query(target u32,name u32) {
    if !metal_service_valid_query(target) { metal_service_error(invalid_enum);return }
    mut object:=context.objects[name] or { metal_service_error(invalid_operation);return }
    if object.kind!=4 || object.deleted || (object.query_target!=0 && object.query_target!=target) || context.active_queries[target]!=0 { metal_service_error(invalid_operation);return }
    if target in [any_samples_passed,any_samples_passed_conservative] && (context.active_queries[any_samples_passed]!=0 || context.active_queries[any_samples_passed_conservative]!=0) { metal_service_error(invalid_operation);return }
    object.created=true;object.query_target=target;object.query_result=0;object.query_available=false
    context.active_queries[target]=name
}

fn (mut context MetalServiceContext) end_query(target u32) {
    if !metal_service_valid_query(target) { metal_service_error(invalid_enum);return }
    name:=context.active_queries[target]
    if name==0 { metal_service_error(invalid_operation);return }
    context.active_queries.delete(target)
    if mut object:=context.objects[name] { object.query_available=true }
}

fn (context &MetalServiceContext) query_parameter(name u32,pname u32) u32 {
    if pname !in [query_result,query_result_available] { metal_service_error(invalid_enum);return 0 }
    object:=context.objects[name] or { metal_service_error(invalid_operation);return 0 }
    if object.kind!=4 || object.deleted || !object.created { metal_service_error(invalid_operation);return 0 }
    for _,active in context.active_queries {
        if active==name { metal_service_error(invalid_operation);return 0 }
    }
    return if pname==query_result_available { u32(object.query_available) } else { u32(object.query_result) }
}

fn (context &MetalServiceContext) visibility_buffer() !&metal.GPUBuffer {
    if context.active_queries[any_samples_passed]==0 && context.active_queries[any_samples_passed_conservative]==0 { return unsafe { nil } }
    return metal.GPUBuffer.create(context.target,8)
}

fn (mut context MetalServiceContext) record_visibility(buffer &metal.GPUBuffer) ! {
    if buffer==unsafe { nil } { return }
    bytes:=buffer.read(0,8)!
    defer { unsafe { bytes.free() } }
    if !bytes.any(it!=0) { return }
    for target in [any_samples_passed,any_samples_passed_conservative] {
        if mut object:=context.objects[context.active_queries[target]] { object.query_result=1 }
    }
}
