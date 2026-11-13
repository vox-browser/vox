module metal

pub struct FeedbackField {
pub:
    name string
    rows u32
    columns u32
    array_length u32
    scalar_type u32
    offset u32
    array_stride u32
    matrix_stride u32
}

pub struct VertexCapture {
pub:
    bytes []u8
    stride int
    fields []FeedbackField
}

pub fn (capture VertexCapture) close() {
    for field in capture.fields { unsafe { field.name.free() } }
    unsafe { capture.fields.free();capture.bytes.free() }
}

pub fn (program &ShaderProgram) feedback_fields() ![]FeedbackField {
    if program.handle==unsafe { nil } { return error('Metal program is closed') }
    mut result:=[]FeedbackField{}
    for i in u64(0)..C.vox_metal_feedback_count(program.handle) {
        mut field:=C.VoxMetalFeedbackField{}
        if C.vox_metal_feedback_field(program.handle,i,&field)!=1 { return error('Metal feedback reflection unavailable') }
        result<<FeedbackField{name:unsafe { cstring_to_vstring(field.name).clone() },rows:field.rows,columns:field.columns,array_length:field.array_length,scalar_type:field.base_type,offset:field.offset,array_stride:field.array_stride,matrix_stride:field.matrix_stride}
    }
    return result
}

pub fn (program &ShaderProgram) enable_feedback() ! {
    mut log:=[]u8{len:16384}
    defer { unsafe { log.free() } }
    if C.vox_metal_program_feedback(program.handle,&char(log.data),u64(log.len))!=1 { return error(unsafe { cstring_to_vstring(&char(log.data)).clone() }) }
}

// Capture the original vertex IDs and instance IDs into a reflected Metal
// structure. Primitive assembly and tightly packed GLES stream ownership stay
// with the V service. The capture pipeline disables rasterization entirely.
pub fn (mut target DrawingBuffer) capture_vertices(program &ShaderProgram,streams []VertexStream,first int,count int,instances int,options DrawOptions) !VertexCapture {
    program.enable_feedback()!
    if count==0 || instances==0 { return VertexCapture{} }
    capture_options:=DrawOptions{...options,feedback:true,indices:none,visibility:unsafe { nil }}
    target.draw_with_options(program,streams,.points,first,count,instances,capture_options)!
    stride:=C.vox_metal_feedback_stride(program.handle)
    if stride==0 || stride>4096 || u64(count)*u64(instances)>u64(max_int)/stride { return error('Metal feedback allocation exceeds supported range') }
    mut output:=GPUBuffer.create(target,int(stride*u64(count)*u64(instances)))!
    defer { output.close();unsafe { free(output) } }
    target.draw_with_options(program,streams,.points,first,count,instances,DrawOptions{...capture_options,feedback_buffer:output})!
    return VertexCapture{bytes:output.read(0,output.size())!,stride:int(stride),fields:program.feedback_fields()!}
}
