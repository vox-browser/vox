// Corner alignment adapted from Chromium, Copyright 2025 The Chromium Authors.
// BSD license: layout/resources/chromium/LICENSE
// https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/platform/geometry/contoured_rect.cc
#pragma once

#include "include/core/SkPathBuilder.h"
#include "include/core/SkRRect.h"
#include "include/pathops/SkPathOps.h"
#include <algorithm>
#include <array>
#include <cmath>

// The fitted half-corner coefficients follow Chromium's BSD-licensed geometry:
// https://chromium.googlesource.com/chromium/src/+/56f91169afcf3eb958b6aa2db9b213b63ed00ce0/third_party/blink/renderer/platform/geometry/path_builder.cc
// CSS superellipse(k) uses curvature 2^k, with k=1 retaining an exact conic.
inline SkPath vox_chromium_superellipse_path(SkRRect const& rect,
    std::array<float, 4> const& parameters, SkRRect const* origin = nullptr)
{
    auto bounds = rect.rect();
    SkPathBuilder path;
    SkPoint last_end;
    auto corner = [&](int index, bool move) {
        auto radius = rect.radii(static_cast<SkRRect::Corner>(index));
        float sx = index == 0 || index == 3 ? -1 : 1;
        float sy = index < 2 ? -1 : 1;
        SkPoint outside {sx < 0 ? bounds.left() : bounds.right(),
            sy < 0 ? bounds.top() : bounds.bottom()};
        SkPoint center {outside.x() - sx * radius.x(), outside.y() - sy * radius.y()};
        SkPoint start = index == 0 || index == 2
            ? SkPoint{outside.x(), center.y()} : SkPoint{center.x(), outside.y()};
        SkPoint end = index == 0 || index == 2
            ? SkPoint{center.x(), outside.y()} : SkPoint{outside.x(), center.y()};
        float curvature = std::isnan(parameters[index]) ? 2.f : std::exp2(parameters[index]);
        if (origin && *origin != rect) {
            auto original_radius = origin->radii(static_cast<SkRRect::Corner>(index));
            if (original_radius.x() > 0 && original_radius.y() > 0) {
                auto original_bounds = origin->rect();
                SkPoint outer {sx < 0 ? original_bounds.left() : original_bounds.right(),
                    sy < 0 ? original_bounds.top() : original_bounds.bottom()};
                SkPoint middle {outer.x()-sx*original_radius.x(),outer.y()-sy*original_radius.y()};
                SkPoint first = index == 0 || index == 2 ? SkPoint{outer.x(),middle.y()}
                    : SkPoint{middle.x(),outer.y()};
                SkPoint last = index == 0 || index == 2 ? SkPoint{middle.x(),outer.y()}
                    : SkPoint{outer.x(),middle.y()};
                float inset[] {bounds.top()-original_bounds.top(), original_bounds.right()-bounds.right(),
                    original_bounds.bottom()-bounds.bottom(), bounds.left()-original_bounds.left()};
                auto normalized=[](SkVector v) {
                    float length=std::sqrt(v.x()*v.x()+v.y()*v.y());
                    return length>0 ? SkVector{v.x()/length,v.y()/length} : SkVector{};
                };
                auto scale=[](SkVector v,float amount) {return SkVector{v.x()*amount,v.y()*amount};};
                auto v2=last-outer,v3=middle-last;
                float start_radius=std::sqrt(v2.x()*v2.x()+v2.y()*v2.y());
                float end_radius=std::sqrt(v3.x()*v3.x()+v3.y()*v3.y());
                auto target_v2=end-outside,target_v3=center-end;
                float target_start=std::sqrt(target_v2.x()*target_v2.x()+target_v2.y()*target_v2.y());
                float target_end=std::sqrt(target_v3.x()*target_v3.x()+target_v3.y()*target_v3.y());
                float t1=inset[(index+3)%4]>=0 && target_start==0 ? inset[(index+3)%4] : start_radius-target_start;
                float t2=inset[index]>=0 && target_end==0 ? inset[index] : end_radius-target_end;
                // Align the inset to the original superellipse's endpoint normals.
                // Chromium contoured_rect.cc, Corner::AlignedToOrigin (2026).
                float parameter=std::log2(curvature);
                float half=std::pow(.5f,1.f/std::exp2(std::abs(parameter)));
                if(parameter<0)half=1-half;
                float root2=std::sqrt(2.f);
                float control=std::clamp(half/(root2-1.f)-1.f/root2,0.f,1.f);
                float difference=std::clamp(t2-t1,-start_radius,end_radius);
                float start_control=control,end_control=control;
                if(difference!=0) {
                    float delta=std::sqrt(start_radius*start_radius+end_radius*end_radius-difference*difference);
                    float nx=end_radius*difference+start_radius*delta;
                    float ny=-start_radius*difference+end_radius*delta;
                    float bevel=start_radius*ny/(start_radius*ny+end_radius*nx);
                    start_control=parameter<0 ? bevel*(2.f*control) : 1.f-(1.f-bevel)*(2.f*(1.f-control));
                    end_control=2.f*control-start_control;
                }
                auto first_normal=normalized({(1.f-start_control)*start_radius,start_control*end_radius});
                auto last_normal=normalized({end_control*start_radius,(1.f-end_control)*end_radius});
                auto axis2=normalized(v2),axis3=normalized(v3);
                auto start_normal=scale(axis3,first_normal.x())+scale(axis2,first_normal.y());
                auto end_normal=scale(axis3,last_normal.x())+scale(axis2,last_normal.y());
                auto original_outside=outside-scale(axis3,t2)-scale(axis2,t1);
                start=original_outside+scale(axis3,end_radius)+scale(start_normal,t1);
                end=original_outside+scale(axis2,start_radius)+scale(end_normal,t2);
                float adjusted_height=(end.x()-start.x())*axis2.x()+(end.y()-start.y())*axis2.y();
                outside=end-scale(axis2,adjusted_height);center=start+scale(axis2,adjusted_height);
            }
        }
        last_end=end;
        if (move) path.moveTo(start);
        path.lineTo(start);
        if (curvature < 1) {
            std::swap(center, outside);
            curvature = 1 / std::max(curvature, .001f);
        }
        if (radius.x() <= 0 || radius.y() <= 0 || curvature >= 1000) {
            path.lineTo(outside).lineTo(end);
        } else if (curvature == 1) {
            path.lineTo(end);
        } else if (curvature == 2) {
            path.conicTo(outside, end, std::sqrt(.5f));
        } else {
            constexpr double fit[] {1.2430920942724248, 2.010479023614843,
                .32922901179443753, .2823023142212073, 1.3473704261055421,
                2.9149468637949814, .9106507102917086};
            float power = std::log2(curvature);
            float slope = fit[0] + (fit[6] - fit[0]) * .5
                * (1 + std::tanh(fit[5] * (power - fit[1])));
            float base = 1 / (1 + std::exp(-slope * (0 - fit[1])));
            float logistic = 1 / (1 + std::exp(-slope * (power - fit[1])));
            float tangent = (logistic - base) / (1 - base);
            float offset = fit[2] * std::exp(-fit[3] * std::pow(power, fit[4]));
            float middle = std::pow(.5, 1 / curvature);
            SkVector first = outside - start, second = start - center;
            auto map = [&](float u, float v) {
                return center + SkVector{first.x() * u, first.y() * u}
                    + SkVector{second.x() * v, second.y() * v};
            };
            path.cubicTo(map(tangent, 1), map(middle - offset, middle + offset),
                map(middle, middle));
            path.cubicTo(map(middle + offset, middle - offset), map(1, tangent), end);
        }
    };
    if (origin && *origin != rect) {
        // CSS Borders 4 border-aligned corner clip-outs. Use finite corner
        // wedges so path arithmetic retains the target's coordinate precision.
        SkPath result=SkPath::Rect(bounds);
        bool resolved=true;
        for (int index : {1,2,3,0}) {
            auto radius=origin->radii(static_cast<SkRRect::Corner>(index));
            if (radius.x()<=0 || radius.y()<=0 || parameters[index]>=10)continue;
            path.reset();corner(index,true);
            SkPoint outside {index==0||index==3?bounds.left():bounds.right(),
                index<2?bounds.top():bounds.bottom()};
            path.lineTo(last_end).lineTo(outside).close();
            auto clipped=Op(result,path.detach(),kDifference_SkPathOp);
            if(!clipped){resolved=false;break;}
            result=std::move(*clipped);
        }
        if(resolved)return result;
        path.reset();
    }
    for (int index : {1, 2, 3, 0}) corner(index,index==1);
    path.close();
    return path.detach();
}
