module canvas

$if sokol_d3d11 ? {
	import sokol.gfx

	// The CoverBounds and FixedCountWedges shaders below adapt the Graphite
	// formulas used by gg/canvas/shaders. Their license is reproduced below.
	const d3d11_canvas_output = r'
struct CanvasVertex {
    float4 position : SV_Position;
    nointerpolation float4 color : TEXCOORD0;
};
'

	// Sokol binds raw storage-buffer slot zero at t16 on D3D11.
	const d3d11_canvas_common = r'
cbuffer Intrinsics : register(b0) {
    float4 viewport;
    float4 dstReadBounds;
};
ByteAddressBuffer paintData : register(t16);
float4 clipPosition(float2 device, float depth, float w) {
    return float4(viewport.zw * device - sign(viewport.zw) * w, depth, w);
}
'

	const d3d11_canvas_cover_vertex = r'
struct CoverInstance {
    float4 bounds : TEXCOORD0;
    float depth : TEXCOORD1;
    uint paint : TEXCOORD2;
    float3 columnX : TEXCOORD3;
    float3 columnY : TEXCOORD4;
    float3 translation : TEXCOORD5;
};
CanvasVertex vertexMain(CoverInstance input, uint vertex : SV_VertexID) {
    float2 corner = float2(vertex >> 1, vertex & 1);
    float3 device;
    if (all(input.bounds.xy <= input.bounds.zw)) {
        float2 local = lerp(input.bounds.xy, input.bounds.zw, corner);
        device = local.x * input.columnX + local.y * input.columnY + input.translation;
    } else {
        // Inverse fills carry device bounds in reverse order. Only the
        // homogeneous row of the inverse matrix is needed for solid paint.
        float2 pixel = lerp(input.bounds.zw, input.bounds.xy, corner);
        float3 inverseRow = cross(input.columnX, input.columnY);
        float w = dot(inverseRow, input.translation) / dot(inverseRow, float3(pixel, 1));
        device = float3(pixel * w, w);
    }
    CanvasVertex result;
    result.position = clipPosition(device.xy, input.depth * device.z, device.z);
#ifdef SHADED
    result.color = asfloat(paintData.Load4(input.paint * 16u));
#else
    result.color = 0;
#endif
    return result;
}
'

	const d3d11_canvas_wedge_vertex = r'
struct WedgeInstance {
    float2 levelAndIndex : TEXCOORD0;
    float4 p01 : TEXCOORD1;
    float4 p23 : TEXCOORD2;
    float2 fan : TEXCOORD3;
    float depth : TEXCOORD4;
    uint paint : TEXCOORD5;
};

float conicSegmentsSquared(float2 a, float2 b, float2 c, float weight) {
    float2 center = (min(min(a, b), c) + max(max(a, b), c)) * 0.5;
    a -= center;
    b -= center;
    c -= center;
    float extent = sqrt(max(max(dot(a, a), dot(b, b)), dot(c, c)));
    float2 derivative = mad(-2.0 * weight, b, a) + c;
    return (4.0 * length(derivative) +
        max(0.0, mad(extent, 4.0, -1.0)) * abs(mad(-2.0, weight, 2.0))) /
        (4.0 * min(weight, 1.0));
}

float2 wedgePoint(WedgeInstance input, float2 transformX, float2 transformY) {
    float level = input.levelAndIndex.x;
    float index = input.levelAndIndex.y;
    if (level < 0.0) return input.fan;
    if (isinf(input.p23.z)) {
        return level != 0.0 ? input.p01.zw : (index != 0.0 ? input.p23.xy : input.p01.xy);
    }

    float2 a = input.p01.xy;
    float2 b = input.p01.zw;
    float2 c = input.p23.xy;
    float2 d = input.p23.zw;
    float weight = -1.0;
    float requiredLevel;
    if (isinf(d.y)) {
        weight = d.x;
        float segments = conicSegmentsSquared(a.x * transformX + a.y * transformY,
            b.x * transformX + b.y * transformY, c.x * transformX + c.y * transformY, weight);
        requiredLevel = ceil(log2(max(segments, 1.0)) * 0.5);
        b *= weight;
        d = c;
    } else {
        float2 derivative0 = mad(-2.0, b, c) + a;
        float2 derivative1 = mad(-2.0, c, d) + b;
        derivative0 = derivative0.x * transformX + derivative0.y * transformY;
        derivative1 = derivative1.x * transformX + derivative1.y * transformY;
        float extent = max(dot(derivative0, derivative0), dot(derivative1, derivative1));
        requiredLevel = ceil(log2(max(9.0 * extent, 1.0)) * 0.25);
    }
    // Collapse vertices from a denser template onto the grid for this curve.
    if (level > requiredLevel) {
        index = floor(ldexp(index, requiredLevel - level));
        level = requiredLevel;
    }
    float grid = floor(0.5 + ldexp(index, 5.0 - level));
    if (grid <= 0.0) return a;
    if (grid >= 32.0) return d;
    float t = grid * 0.03125;
    float2 ab = lerp(a, b, t);
    float2 bc = lerp(b, c, t);
    float2 abc = lerp(ab, bc, t);
    if (weight < 0.0) {
        return lerp(abc, lerp(bc, lerp(c, d, t), t), t);
    }
    float abWeight = lerp(1.0, weight, t);
    return abc / lerp(abWeight, (weight + 1.0) - abWeight, t);
}

CanvasVertex vertexMain(WedgeInstance input) {
    CanvasVertex result;
#ifdef SHADED
    uint base = input.paint * 80u;
    result.color = asfloat(paintData.Load4(base));
    base += 16u;
#else
    uint base = input.paint * 64u;
    result.color = 0;
#endif
    float4 columnX = asfloat(paintData.Load4(base));
    float4 columnY = asfloat(paintData.Load4(base + 16u));
    float4 translation = asfloat(paintData.Load4(base + 48u));
    float2 local = wedgePoint(input, columnX.xy, columnY.xy);
    float4 device = local.x * columnX + local.y * columnY + translation;
    result.position = clipPosition(device.xy, input.depth, device.w);
    return result;
}
'

	const d3d11_canvas_fragment = r'
float4 fragmentMain(CanvasVertex input) : SV_Target0 {
    return input.color;
}
'

	const d3d11_canvas_msaa_vertex = r'
float4 vertexMain(uint vertex : SV_VertexID) : SV_Position {
    return float4(2.0 * float2(vertex >> 1, vertex & 1) - 1.0, 0.0, 1.0);
}
'

	const d3d11_canvas_msaa_fragment = r'
Texture2D<float4> resolved : register(t0);
float4 fragmentMain(float4 position : SV_Position) : SV_Target0 {
    return resolved.Load(int3(int2(position.xy), 0));
}
'

	const d3d11_canvas_steps = [RenderStep.cover_bounds, .cover_fill, .cover_inverse_fill, .cover_clip,
		.cover_inverse_clip, .convex_wedges, .stencil_wedges_winding, .stencil_wedges_even_odd,
		.wedges_shaded]!

	fn d3d11_canvas_supports(step RenderStep, clipped bool, shading Shading) bool {
		return !clipped && shading == .solid && step in d3d11_canvas_steps
	}

	fn d3d11_canvas_shader_step(step RenderStep) RenderStep {
		return match step {
			.cover_fill, .cover_inverse_fill { .cover_bounds }
			.cover_inverse_clip { .cover_clip }
			.stencil_wedges_winding, .stencil_wedges_even_odd { .convex_wedges }
			else { step }
		}
	}

	fn (mut ctx GpuContext) precompile_d3d11_canvas() {
		ctx.pipeline(.cover_bounds, 1, false, false, .solid)
		ctx.pipeline(.cover_bounds, 1, true, false, .solid)
		for step in d3d11_canvas_steps {
			ctx.pipeline(step, 4, false, false, .solid)
			if writes_color(step) {
				ctx.pipeline(step, 4, true, false, .solid)
			}
		}
		ctx.load_msaa_pipeline()
	}

	fn d3d11_canvas_shader(step RenderStep, clipped bool, shading Shading) gfx.Shader {
		if !d3d11_canvas_supports(step, clipped, shading) {
			return gfx.Shader{}
		}
		prefix := if writes_color(step) { '#define SHADED\n' } else { '' }
		geometry := if is_wedge_step(step) {
			d3d11_canvas_wedge_vertex
		} else {
			d3d11_canvas_cover_vertex
		}
		vertex := prefix + d3d11_canvas_output + d3d11_canvas_common + geometry
		fragment := d3d11_canvas_output + d3d11_canvas_fragment
		mut desc := gfx.ShaderDesc{}
		desc.vs.source = &char(vertex.str)
		desc.vs.entry = c'vertexMain'
		desc.fs.source = &char(fragment.str)
		desc.fs.entry = c'fragmentMain'
		desc.vs.uniform_blocks[0].size = intrinsic_uniform_size
		if has_uniforms(step) {
			desc.vs.storage_buffers[0] = gfx.ShaderStorageBufferDesc{ used: true, readonly: true }
		}
		for index in 0 .. 6 {
			desc.attrs[index].sem_name = c'TEXCOORD'
			desc.attrs[index].sem_index = index
		}
		return gfx.make_shader(&desc)
	}
}

/*
Copyright (c) 2011 Google Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

  * Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
