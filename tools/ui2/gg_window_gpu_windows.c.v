module canvas

import dl

type CanvasGetGLInteger = fn (u32, &i32)

fn windows_gpu_has_storage_buffers() bool {
	// Query the OpenGL driver already loaded by the Sokol window.
	library := dl.open('opengl32.dll', dl.rtld_now)
	if library == unsafe { nil } {
		return false
	}
	defer {
		dl.close(library)
	}
	address := dl.sym(library, 'glGetIntegerv')
	if address == unsafe { nil } {
		return false
	}
	query := unsafe { CanvasGetGLInteger(address) }
	mut vertex_blocks := i32(0)
	mut fragment_blocks := i32(0)
	mut bindings := i32(0)
	query(0x90d6, &vertex_blocks) // GL_MAX_VERTEX_SHADER_STORAGE_BLOCKS
	query(0x90da, &fragment_blocks) // GL_MAX_FRAGMENT_SHADER_STORAGE_BLOCKS
	query(0x90dd, &bindings) // GL_MAX_SHADER_STORAGE_BUFFER_BINDINGS
	// Sokol assigns eight slots to each of the vertex and fragment stages.
	return vertex_blocks > 0 && fragment_blocks > 0 && bindings >= 16
}
