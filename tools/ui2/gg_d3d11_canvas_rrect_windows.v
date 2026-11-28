module canvas

$if sokol_d3d11 ? {
	// Copyright (c) 2011 Google Inc. All rights reserved.
	// Adapted from the Graphite analytic RRect shaders in gg/canvas/shaders.
	// The license is reproduced in gg_d3d11_canvas_windows.v.
	const d3d11_canvas_rrect_math = r'
float2 applyInverseJacobian(float2 value, float4 jacobian) {
    return float2(dot(value, jacobian.xy), dot(value, jacobian.zw));
}
'

	const d3d11_canvas_rrect_vertex = r'
struct RRectVertex {
    uint corner : TEXCOORD0;
    float2 offset : TEXCOORD1;
    float2 normal : TEXCOORD2;
    float normalScale : TEXCOORD3;
    float centerWeight : TEXCOORD4;
    float4 xRadiiOrFlags : TEXCOORD5;
    float4 radiiOrQuadXs : TEXCOORD6;
    float4 boundsOrQuadYs : TEXCOORD7;
    float4 center : TEXCOORD8;
    float depth : TEXCOORD9;
    uint paint : TEXCOORD10;
    float3 columnX : TEXCOORD11;
    float3 columnY : TEXCOORD12;
    float3 translation : TEXCOORD13;
};

float2 perpendicular(float2 v) { return float2(-v.y, v.x); }

CanvasVertex vertexMain(RRectVertex input) {
    uint corner = input.corner;
    uint nextCorner = (corner + 1u) % 4u;
    bool hollow = input.center.z <= 0.0;
    bool quad = false;
    bool isLine = false;
    float4 x;
    float4 y;
    float4 xRadii;
    float4 yRadii;
    float4 aaEdges = 1.0;
    float2 stroke;
    float joinScale = 1.0;
    float4 flags = input.xRadiiOrFlags;
    float4 bounds = input.boundsOrQuadYs;
    if (flags.x < -1.0) {
        isLine = flags.y > 0.0;
        x = isLine ? bounds.xxzz : bounds.xzzx;
        y = bounds.yyww;
        if (flags.y < 0.0) {
            xRadii = -flags - 2.0;
            yRadii = input.radiiOrQuadXs;
            stroke = float2(0.0, 1.0);
        } else {
            xRadii = input.radiiOrQuadXs;
            yRadii = xRadii;
            stroke = flags.zw;
            joinScale = stroke.y < 0.0 ? 0.414213568 : sign(stroke.y);
        }
    } else if (any(flags > 0.0)) {
        x = bounds.xzzx;
        y = bounds.yyww;
        xRadii = flags;
        yRadii = input.radiiOrQuadXs;
        stroke = float2(0.0, -1.0);
    } else {
        x = input.radiiOrQuadXs;
        y = bounds;
        aaEdges = -flags;
        xRadii = 0.0;
        yRadii = 0.0;
        stroke = float2(0.0, 1.0);
        quad = true;
    }

    float2 radii = float2(xRadii[corner], yRadii[corner]);
    if ((corner & 1u) != 0u) radii = radii.yx;
    float2 normalWeights = 1.0;
    if (all(radii > 0.0)) {
        joinScale = 0.414213568;
        normalWeights = radii.yx;
    }

    float4 dx = x - x.wxyz;
    float4 dy = y - y.wxyz;
    // Normalize large edge vectors before computing their squared lengths.
    float4 edgeScale = rcp(max(max(abs(dx), abs(dy)), 1.0));
    dx *= edgeScale;
    dy *= edgeScale;
    float4 lengthSquared = dx * dx + dy * dy;
    float4 nonzeroEdges = sign(lengthSquared);
    float4 edgeOffset = 0.0;
    float2 cornerStroke = stroke.xx;
    if (all(nonzeroEdges == 0.0)) {
        dx = float4(0, 1, 0, -1);
        dy = float4(-1, 0, 1, 0);
        lengthSquared = 1.0;
    } else if (any(nonzeroEdges == 0.0)) {
        bool hasThreeEdges = dot(nonzeroEdges, 1.0) > 2.5;
        float4 replacementX = hasThreeEdges ? dx.yzwx : dy.yzwx;
        float4 replacementY = hasThreeEdges ? dy.yzwx : -dx.yzwx;
        dx = lerp(replacementX, dx, nonzeroEdges);
        dy = lerp(replacementY, dy, nonzeroEdges);
        lengthSquared = lerp(lengthSquared.yzwx, lengthSquared, nonzeroEdges);
        aaEdges = lerp(aaEdges.yzwx, aaEdges, nonzeroEdges);
        if (!hasThreeEdges && joinScale == 0.0) {
            cornerStroke *= float2(nonzeroEdges[corner], nonzeroEdges[nextCorner]);
            edgeOffset = (nonzeroEdges - 1.0) * stroke.x;
            stroke.y = 1.0;
            joinScale = 1.0;
        }
    }
    float4 inverseLength = rsqrt(lengthSquared);
    dx *= inverseLength;
    dy *= inverseLength;
    float2 nextEdge = -float2(dx[nextCorner], dy[nextCorner]);
    float2 previousEdge = float2(dx[corner], dy[corner]);

    float2 local;
    if (input.normalScale < 0.0 && (input.center.w < 0.0 || input.centerWeight * input.center.z != 0.0)) {
        local = input.center.xy;
    } else {
        float2 offset;
        if (input.normalScale < 0.0) {
            float inset = input.center.w;
            float2 innerRadii = radii + (hollow ? -cornerStroke : cornerStroke);
            offset = joinScale == 1.0 || any(innerRadii <= inset) ?
                innerRadii - inset : innerRadii * input.offset - inset * input.normal;
        } else {
            offset = (radii + cornerStroke) * (input.offset + joinScale * input.offset.yx);
        }
        offset -= radii;
        local = (float2(x[corner], y[corner]) + nextEdge * offset.x) + previousEdge * offset.y;
    }
    float4 distanceToEdges = (dy * (x - local.x) - dx * (y - local.y)) + edgeOffset;
    float3 device = local.x * input.columnX + local.y * input.columnY + input.translation;

    // The cross products are rows of the inverse, before division by its determinant.
    float3 rowX = cross(input.columnY, input.translation);
    float3 rowY = cross(input.translation, input.columnX);
    float3 rowW = cross(input.columnX, input.columnY);
    float inverseDet = rcp(dot(input.columnX, rowX));
    float3 inverseX = float3(rowX.x, rowY.x, rowW.x) * inverseDet;
    float3 inverseY = float3(rowX.y, rowY.y, rowW.y) * inverseDet;
    float4 jacobian = float4(inverseX.xy - inverseX.z * local, inverseY.xy - inverseY.z * local);
    float pixelControl = 0.0;
    if (quad) {
        float4 ux = -dy * (inverseX.x - inverseX.z * x) + dx * (inverseX.y - inverseX.z * y);
        float4 uy = -dy * (inverseY.x - inverseY.z * x) + dx * (inverseY.y - inverseY.z * y);
        distanceToEdges *= rsqrt(ux * ux + uy * uy);
        distanceToEdges += (1.0 - aaEdges) * abs(device.z);
        bool orthogonal = all(aaEdges == 1.0) && dot(abs(dx * dx.yzwx + dy * dy.yzwx), 1.0) < 0.00024;
        float2 span = distanceToEdges.xy + distanceToEdges.zw;
        pixelControl = 1.0 + (orthogonal ? min(min(span.x, span.y), abs(device.z)) : abs(device.z));
    }
    if (input.normalScale > 0.0 && device.z > 0.0) {
        float2 normal = float2(aaEdges[corner], aaEdges[nextCorner]) * input.normal;
        float2 a = applyInverseJacobian(normalWeights.x * normal.x * perpendicular(-previousEdge), jacobian);
        float2 b = applyInverseJacobian(normalWeights.y * normal.y * perpendicular(nextEdge), jacobian);
        if (joinScale == 1.0 && all(normal != 0.0)) {
            a = normalize(a);
            b = normalize(b);
            if (dot(a, b) < -0.8) {
                float orientation = sign(a.x * b.y - a.y * b.x);
                a = orientation * perpendicular(a);
                b = -orientation * perpendicular(b);
            }
        }
        device.xy += device.z * normalize(a + b);
        if (quad) distanceToEdges -= device.z;
        else pixelControl = -device.z;
    }
    if (isLine) {
        float2 axisX = float2(dy.x, -dy.y);
        float2 axisY = float2(-dx.x, dx.y);
        jacobian = float4(axisX * jacobian.x + axisY * jacobian.y,
            axisX * jacobian.z + axisY * jacobian.w);
    }
    CanvasVertex result = paintVertex(clipPosition(device.xy, device.z * input.depth, device.z),
        input.paint * PAINT_STRIDE, local);
    result.jacobian = jacobian;
    result.edgeDistances = distanceToEdges;
    result.xRadii = xRadii;
    result.yRadii = yRadii;
    result.strokeParams = stroke;
    result.perPixelControl = float2(input.centerWeight != 0.0 ? 1.0 : (hollow ? -1.0 : 0.0), pixelControl);
    return result;
}
'

	const d3d11_canvas_rrect_fragment = r'
float2 cornerCoverage(float2 limits, float4 jacobian, float2 stroke,
                      float2 edges, float2 direction, float2 radius) {
    float2 delta = radius - edges;
    if (!all(delta > 0.0)) return limits;
    if (all(radius > 0.0) || (stroke.x > 0.0 && stroke.y < 0.0)) {
        float2 d = delta * direction;
        float2 inverseRadiusSquared = rcp(radius * radius + stroke.x * stroke.x);
        float2 scaled = inverseRadiusSquared * d;
        float2 deviceGradient = applyInverseJacobian(scaled, jacobian);
        float inverseLength = rsqrt(dot(deviceGradient, deviceGradient));
        float distance = (0.5 * inverseLength) * (dot(d, scaled) - 1.0);
        float width = ((radius.x * stroke.x) * inverseRadiusSquared.x) * inverseLength;
        float2 bound = float2(width - distance, radius.x <= stroke.x ? 1.0 : -(width + distance));
        return min(limits, bound);
    }
    if (stroke.y == 0.0) {
        float2 deviceGradient = applyInverseJacobian(direction, jacobian);
        float distance = ((stroke.x - delta.x) - delta.y) * rsqrt(dot(deviceGradient, deviceGradient));
        limits.x = min(limits.x, distance);
    }
    return limits;
}

float rrectCoverage(CanvasVertex input) {
    float2 control = input.perPixelControl;
    if (control.x > 0.0) return 1.0;

    float4 edges = input.edgeDistances;
    float2 nearEdges = min(edges.xy, edges.zw);
    float inverseW = input.position.w;
    if (control.y > 1.0) {
        float distance = min(nearEdges.x, nearEdges.y) * inverseW;
        float scale = (control.y - 1.0) * inverseW;
        return saturate(scale * (distance + (1.0 - 0.5 * scale)));
    }

    float4 jacobian = input.jacobian / inverseW;
    float2 axisX = applyInverseJacobian(float2(1.0, 0.0), jacobian);
    float2 axisY = applyInverseJacobian(float2(0.0, 1.0), jacobian);
    float2 scale = rsqrt(float2(dot(axisX, axisX), dot(axisY, axisY)));
    float2 stroke = input.strokeParams;
    float2 outer = scale * (stroke.x + nearEdges);
    float2 limits = float2(min(outer.x, outer.y), -1.0);
    float coverageScale = 1.0;
    float bias = 1.0;
    if (control.x > -0.95) {
        float2 span = scale * (edges.xy + edges.zw + 2.0 * stroke.x);
        coverageScale = min(min(span.x, span.y), 1.0);
        bias = 1.0 - 0.5 * coverageScale;
    } else {
        float2 strokeWidth = (2.0 * stroke.x) * scale;
        float2 inner = strokeWidth - outer;
        limits.y = -max(inner.x, inner.y);
        if (stroke.x > 0.0) {
            float minWidth = min(strokeWidth.x, strokeWidth.y);
            float2 widths = float2(inner.x >= -0.5 ? strokeWidth.x : minWidth,
                inner.y >= -0.5 ? strokeWidth.y : minWidth);
            coverageScale = saturate(max(widths.x, widths.y));
            bias = 1.0 - 0.5 * coverageScale;
        }
    }
    limits = cornerCoverage(limits, jacobian, stroke, edges.xy, float2(-1, -1), float2(input.xRadii.x, input.yRadii.x));
    limits = cornerCoverage(limits, jacobian, stroke, edges.zy, float2(1, -1), float2(input.xRadii.y, input.yRadii.y));
    limits = cornerCoverage(limits, jacobian, stroke, edges.zw, float2(1, 1), float2(input.xRadii.z, input.yRadii.z));
    limits = cornerCoverage(limits, jacobian, stroke, edges.xw, float2(-1, 1), float2(input.xRadii.w, input.yRadii.w));
    float outset = min(control.y, 0.0) * inverseW;
    return saturate(coverageScale * (min(limits.x + outset, -limits.y) + bias));
}
'
}
