module canvas

$if sokol_d3d11 ? {
	import sokol.gfx

	// The cover, wedge and stroke shaders below adapt the Graphite
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

	const d3d11_canvas_curve_math = r'
float2 transformVector(float2 value, float2 columnX, float2 columnY) {
    return value.x * columnX + value.y * columnY;
}

float cubicDerivativeExtent(float2 a, float2 b, float2 c, float2 d,
                            float2 columnX, float2 columnY) {
    float2 first = transformVector(mad(-2.0, b, c) + a, columnX, columnY);
    float2 second = transformVector(mad(-2.0, c, d) + b, columnX, columnY);
    return max(dot(first, first), dot(second, second));
}

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
        float segments = conicSegmentsSquared(transformVector(a, transformX, transformY),
            transformVector(b, transformX, transformY), transformVector(c, transformX, transformY), weight);
        requiredLevel = ceil(log2(max(segments, 1.0)) * 0.5);
        b *= weight;
        d = c;
    } else {
        float extent = cubicDerivativeExtent(a, b, c, d, transformX, transformY);
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

	const d3d11_canvas_stroke_vertex = r'
struct StrokeInstance {
    float4 p01 : TEXCOORD0;
    float4 p23 : TEXCOORD1;
    float2 previous : TEXCOORD2;
    float2 stroke : TEXCOORD3;
    float depth : TEXCOORD4;
    uint paint : TEXCOORD5;
};

float2 strokeDirection(float2 end, float2 start) {
    float2 delta = end - start;
    if (all(delta == 0.0)) return 0;
    return normalize(delta * (1.0 / max(abs(delta.x), abs(delta.y))));
}

float strokeCross(float2 a, float2 b) {
    return a.x * b.y - a.y * b.x;
}

float2 strokeMix(float2 a, float2 b, float t) {
    return mad(b - a, t, a);
}

CanvasVertex vertexMain(StrokeInstance input, uint vertex : SV_VertexID) {
    // Match stroke_uniforms: premultiplied color, 2x2 affine columns,
    // translation and maximum scale, padded to a 48-byte record.
    uint base = input.paint * 48u;
    float4 affine = asfloat(paintData.Load4(base + 16u));
    float2 translation = asfloat(paintData.Load2(base + 32u));
    float maxScale = asfloat(paintData.Load(base + 40u));
    float edgeID = float(vertex >> 1);
    if ((vertex & 1u) != 0) edgeID = -edgeID;

    float2 previous = input.previous;
    float2 a = input.p01.xy;
    float2 b = input.p01.zw;
    float2 c = input.p23.xy;
    float2 d = input.p23.zw;
    float weight = -1.0;
    if (isinf(d.x) || isinf(d.y)) {
        weight = d.x;
        d = c;
    }
    float parametricSegments = 1.0;
    if (weight < 0.0) {
        if (!all(a == b) || !all(c == d)) {
            float extent = cubicDerivativeExtent(a, b, c, d, affine.xy, affine.zw);
            parametricSegments = max(ceil(sqrt(3.0 * sqrt(extent))), 1.0);
        }
    } else if (!all(a == b) && !all(b == c)) {
        float segments = conicSegmentsSquared(transformVector(a, affine.xy, affine.zw),
            transformVector(b, affine.xy, affine.zw), transformVector(c, affine.xy, affine.zw), weight);
        parametricSegments = max(ceil(sqrt(segments)), 1.0);
    }

    float radius = input.stroke.x;
    float join = input.stroke.y;
    bool hairline = radius == 0.0;
    float radialPerRadian;
    if (hairline) {
        radialPerRadian = 0.477464825;
        radius = 0.5;
        a = transformVector(a, affine.xy, affine.zw);
        b = transformVector(b, affine.xy, affine.zw);
        c = transformVector(c, affine.xy, affine.zw);
        d = transformVector(d, affine.xy, affine.zw);
        previous = transformVector(previous, affine.xy, affine.zw);
    } else {
        radialPerRadian = 0.5 / acos(max(1.0 - 0.25 / (maxScale * radius), -1.0));
    }

    float2 startTangent = strokeDirection(all(a == b) ? (all(b == c) ? d : c) : b, a);
    float2 endTangent = strokeDirection(d, all(d == c) ? (all(c == b) ? a : b) : c);
    float2 previousTangent = strokeDirection(a, previous);
    if (all(startTangent == 0.0)) {
        // Degenerate patches represent cap or cusp circles and squares.
        join = 0.0;
        if (weight < 0.0) {
            startTangent = float2(1.0, 0.0);
            endTangent = -startTangent;
        } else {
            weight = -1.0;
            startTangent = previousTangent;
            endTangent = previousTangent;
            if (all(previousTangent == 0.0)) {
                d = c = a + radius * float2(1.0, 0.0);
                a = b = a - radius * float2(1.0, 0.0);
                previousTangent = startTangent = endTangent = float2(1.0, 0.0);
            } else {
                d = c = a + radius * previousTangent;
            }
        }
    }

    // FixedCountStrokes starts each strip with the join, then merges
    // parametric curve segments with the radial segments of the stroke.
    float joinEdges;
    if (join >= 0.0) {
        joinEdges = sign(join) + 3.0;
    } else {
        float angle = acos(clamp(dot(previousTangent, startTangent), -1.0, 1.0));
        joinEdges = min(max(ceil(angle * radialPerRadian), 1.0) + 2.0, 16381.0);
    }
    float turn = strokeCross(c - a, d - b);
    float edge = abs(edgeID) - joinEdges;
    if (edge < 0.0) {
        endTangent = startTangent;
        if (any(previous != a)) startTangent = previousTangent;
        turn = strokeCross(startTangent, endTangent);
    }
    float alignment = clamp(dot(startTangent, endTangent), -1.0, 1.0);
    float rotation = acos(alignment);
    if (turn < 0.0) rotation = -rotation;
    float radialSegments;
    float outset = sign(edgeID);
    if (edge < 0.0) {
        radialSegments = joinEdges - 2.0;
        parametricSegments = 1.0;
        d = c = b = a;
        edge += radialSegments + 1.0;
        if (edge < 0.0) {
            edge = 0.0;
        } else {
            bool nearlyStraight = abs(turn) * rsqrt(dot(startTangent, startTangent) * dot(endTangent, endTangent)) < 0.01;
            if (!nearlyStraight || dot(startTangent, endTangent) < 0.0) {
                outset = turn < 0.0 ? min(outset, 0.0) : max(outset, 0.0);
            }
        }
    } else {
        float remaining = 16382.0 - joinEdges;
        radialSegments = min(max(ceil(abs(rotation) * radialPerRadian), 1.0), remaining);
        parametricSegments = min(parametricSegments, remaining - radialSegments + 1.0);
    }
    float rotationPerSegment = rotation / radialSegments;
    float lastEdge = parametricSegments + radialSegments - 1.0;
    if (edge > lastEdge) outset = 0.0;
    if (abs(edgeID) == 2.0 && join > 0.0) {
        float cosHalfSquared = mad(alignment, 0.5, 0.5);
        outset *= (cosHalfSquared * join) * join >= 1.0 ? rsqrt(cosHalfSquared) : sqrt(cosHalfSquared);
    }

    float2 tangent;
    float2 center;
    if (edge != 0.0 && edge < lastEdge) {
        float2 derivativeA;
        float2 derivativeB;
        float2 derivativeC = b - a;
        float2 span = d - a;
        if (weight >= 0.0) {
            derivativeC *= weight;
            derivativeB = 0.5 * span - derivativeC;
            derivativeA = (weight - 1.0) * span;
            b *= weight;
        } else {
            float2 middle = c - b;
            derivativeB = middle - derivativeC;
            derivativeA = mad(-3.0, middle, span);
        }
        // Find the last parametric edge preceding this strip edge.
        float2 scaledB = derivativeB * (parametricSegments * 2.0);
        float2 scaledC = derivativeC * (parametricSegments * parametricSegments);
        float parametricID = 0.0;
        float maxParametricID = min(parametricSegments - 1.0, edge);
        float angleStep = -abs(rotationPerSegment);
        float initialAngle = (1.0 + edge) * abs(rotationPerSegment);
        for (float step = 32.0; step >= 1.0; step *= 0.5) {
            float candidate = parametricID + step;
            if (candidate <= maxParametricID) {
                float2 derivative = mad(candidate, mad(candidate, derivativeA, scaledB), scaledC);
                float allowedAngle = min(mad(candidate, angleStep, initialAngle), 3.14159274);
                if (dot(normalize(derivative), startTangent) >= cos(allowedAngle)) parametricID = candidate;
            }
        }
        float parametricT = parametricID / parametricSegments;
        float radialID = edge - parametricID;
        float startAngle = acos(clamp(startTangent.x, -1.0, 1.0));
        if (startTangent.y < 0.0) startAngle = -startAngle;
        float radialAngle = mad(radialID, rotationPerSegment, startAngle);
        tangent = float2(cos(radialAngle), sin(radialAngle));

        // Solve where the curve derivative reaches the radial tangent.
        float2 normal = float2(-tangent.y, tangent.x);
        float qa = dot(normal, derivativeA);
        float qb = dot(normal, derivativeB);
        float qc = dot(normal, derivativeC);
        float discriminant = sqrt(max(qb * qb - qa * qc, 0.0));
        float q = (qb > 0.0 ? -discriminant : discriminant) - qb;
        float midpoint = (-0.5 * q) * qa;
        float2 root = abs(mad(q, q, midpoint)) < abs(mad(qa, qc, midpoint)) ? float2(q, qa) : float2(qc, q);
        float radialT = radialID != 0.0 && root.y != 0.0 ? saturate(root.x / root.y) : 0.0;
        float t = max(parametricT, radialT);
        float2 ab = strokeMix(a, b, t);
        float2 bc = strokeMix(b, c, t);
        float2 cd = strokeMix(c, d, t);
        float2 abc = strokeMix(ab, bc, t);
        float2 bcd = strokeMix(bc, cd, t);
        float abWeight = mad(weight - 1.0, t, 1.0);
        float bcWeight = weight + 1.0 - abWeight;
        float abcWeight = mad(bcWeight - abWeight, t, abWeight);
        if (t != radialT) {
            tangent = weight >= 0.0 ? strokeDirection(bc * abWeight, ab * bcWeight) : strokeDirection(bcd, abc);
        }
        center = weight >= 0.0 ? abc / abcWeight : strokeMix(abc, bcd, t);
    } else {
        tangent = edge == 0.0 ? startTangent : endTangent;
        center = edge == 0.0 ? a : d;
    }
    center += float2(tangent.y, -tangent.x) * (radius * outset);
    float2 device = (hairline ? center : transformVector(center, affine.xy, affine.zw)) + translation;
    CanvasVertex result;
    result.position = clipPosition(device, input.depth, 1.0);
    result.color = asfloat(paintData.Load4(base));
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
		.wedges_shaded, .tessellate_strokes]!

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
		geometry := match true {
			step == .tessellate_strokes { d3d11_canvas_curve_math + d3d11_canvas_stroke_vertex }
			is_wedge_step(step) { d3d11_canvas_curve_math + d3d11_canvas_wedge_vertex }
			else { d3d11_canvas_cover_vertex }
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
