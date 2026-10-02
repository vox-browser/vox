// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024, Luke Wilde <luke@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import webgl
import x.json2

// WebGLObject::label/set_label use the resource's actual owning V record and
// remain independent of GL handle validity or context generation.
fn (host &CanvasWebGLHost) label_object(value json2.Any) !&webgl.WebGLObject {
	handle := wg_handle(value)
	kind := host.resource_kinds[handle] or { return error('TypeError: Not an object of type WebGLObject') }
	return match kind {
		'buffer' {
			object := host.buffers[handle] or { return error('TypeError: invalid WebGLBuffer') }
			&object.object
		}
		'framebuffer' {
			object := host.framebuffers[handle] or { return error('TypeError: invalid WebGLFramebuffer') }
			&object.object
		}
		'renderbuffer' {
			object := host.renderbuffers[handle] or { return error('TypeError: invalid WebGLRenderbuffer') }
			&object.object
		}
		'texture' {
			object := host.textures[handle] or { return error('TypeError: invalid WebGLTexture') }
			&object.object
		}
		'shader' {
			object := host.shaders[handle] or { return error('TypeError: invalid WebGLShader') }
			&object.object
		}
		'program' {
			object := host.programs[handle] or { return error('TypeError: invalid WebGLProgram') }
			&object.object
		}
		'query' {
			object := host.queries[handle] or { return error('TypeError: invalid WebGLQuery') }
			&object.object
		}
		'sampler' {
			object := host.samplers[handle] or { return error('TypeError: invalid WebGLSampler') }
			&object.object
		}
		'sync' {
			object := host.syncs[handle] or { return error('TypeError: invalid WebGLSync') }
			&object.object
		}
		'transform_feedback' {
			object := host.transform_feedbacks[handle] or { return error('TypeError: invalid WebGLTransformFeedback') }
			&object.object
		}
		'vertex_array' {
			object := host.vertex_arrays[handle] or { return error('TypeError: invalid WebGLVertexArrayObject') }
			&object.object
		}
		'vertex_array_oes' {
			object := host.vertex_arrays_oes[handle] or { return error('TypeError: invalid WebGLVertexArrayObjectOES') }
			&object.object
		}
		else { return error('TypeError: Not an object of type WebGLObject') }
	}
}
