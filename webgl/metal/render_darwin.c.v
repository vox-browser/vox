module metal

#include "@DIR/render_darwin.h"

@[typedef]
struct C.VoxMetalVertexStream {
	buffer voidptr
	offset u64
	stride u64
	location u32
	components u32
	divisor u32
	format u32
	normalized u32
	constant u32
}

@[typedef]
struct C.VoxMetalUniformBinding {
	buffer voidptr
	stage u32
	binding u32
	offset u64
}

fn C.vox_metal_draw(voidptr, voidptr, &C.VoxMetalVertexStream, u32, &C.VoxMetalUniformBinding, u32, u32, u32, u32, u32, &char, u64) i32

@[typedef]
struct C.VoxMetalTextureBinding {
	texture voidptr
	stage u32
	binding u32
	sampler_binding u32
	sampled u32
    sampler voidptr
}

fn C.vox_metal_draw_textured(voidptr, voidptr, &C.VoxMetalVertexStream, u32, &C.VoxMetalUniformBinding, u32, &C.VoxMetalTextureBinding, u32, u32, u32, u32, u32, &char, u64) i32
fn C.vox_metal_draw_configured(voidptr, voidptr, &C.VoxMetalVertexStream, u32, &C.VoxMetalUniformBinding, u32, &C.VoxMetalTextureBinding, u32, &C.VoxMetalRenderState, voidptr, u64, u32, u32, u32, u32, u32, &char, u64) i32
