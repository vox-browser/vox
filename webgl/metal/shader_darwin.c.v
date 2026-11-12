module metal

$if arm64 {
	#flag -I/opt/homebrew/opt/glslang/include
	#flag -I/opt/homebrew/opt/spirv-cross/include/spirv_cross
	#flag -L/opt/homebrew/opt/spirv-cross/lib
	#flag /opt/homebrew/opt/glslang/lib/libglslang.dylib
	#flag /opt/homebrew/opt/glslang/lib/libglslang-default-resource-limits.dylib
	#flag -Wl,-rpath,/opt/homebrew/opt/glslang/lib
} $else {
	#flag -I/usr/local/opt/glslang/include
	#flag -I/usr/local/opt/spirv-cross/include/spirv_cross
	#flag -L/usr/local/opt/spirv-cross/lib
	#flag /usr/local/opt/glslang/lib/libglslang.dylib
	#flag /usr/local/opt/glslang/lib/libglslang-default-resource-limits.dylib
	#flag -Wl,-rpath,/usr/local/opt/glslang/lib
}
#flag -lspirv-cross-c -lspirv-cross-msl -lspirv-cross-cpp -lspirv-cross-hlsl -lspirv-cross-reflect -lspirv-cross-glsl -lspirv-cross-core -lc++
#include "@DIR/shader_program_darwin.h"

@[typedef]
struct C.VoxMetalShaderResource {
	name &char
	kind u32
	stage u32
	location u32
	binding u32
	secondary_binding u32
	offset u32
	array_stride u32
	matrix_stride u32
	base_type u32
	rows u32
	columns u32
	array_length u32
	byte_size u64
    image_dimension u32
    image_arrayed u32
    image_depth u32
    image_scalar_type u32
    semantic_type u32
}

fn C.vox_metal_program_create(voidptr, &char, i32, &char, i32, i32, &char, u64) voidptr

@[typedef]
struct C.VoxMetalAttributeBinding {
	name &char
	location u32
}

fn C.vox_metal_program_create_bound(voidptr, &char, i32, &char, i32, i32, &C.VoxMetalAttributeBinding, u64, &char, u64) voidptr
fn C.vox_metal_program_destroy(voidptr)
fn C.vox_metal_program_source(voidptr, i32) &char
fn C.vox_metal_program_resource_count(voidptr) u64
fn C.vox_metal_program_resource(voidptr, u64, &C.VoxMetalShaderResource) i32

@[typedef]
struct C.VoxMetalFeedbackField {
    name &char
    metal_name &char
    rows u32
    columns u32
    array_length u32
    base_type u32
    offset u32
    array_stride u32
    matrix_stride u32
}
fn C.vox_metal_program_feedback(voidptr,&char,u64) i32
fn C.vox_metal_feedback_stride(voidptr) u64
fn C.vox_metal_feedback_count(voidptr) u64
fn C.vox_metal_feedback_field(voidptr,u64,&C.VoxMetalFeedbackField) i32
