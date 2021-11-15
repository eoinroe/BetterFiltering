//
//  Shaders.metal
//  ComputeNormals
//
//  Created by Eoin Roe on 11/02/2021.

#include <metal_stdlib>
using namespace metal;

#include "ColourConversion.h"

// Screen filling quad in normalized device coordinates.
constant float2 quadVertices[] = {
    float2(-1, -1),
    float2(-1,  1),
    float2( 1,  1),
    float2(-1, -1),
    float2( 1,  1),
    float2( 1, -1)
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Simple vertex shader which passes through NDC quad positions.
vertex VertexOut base_vertex(unsigned short vid [[vertex_id]]) {
    float2 position = quadVertices[vid];
    
    VertexOut out {
        .position = float4(position, 0, 1),
        .uv = position * 0.5f + 0.5f
    };
    
    return out;
}

typedef VertexOut FragmentIn;

// Simple fragment shader which copies a texture.
fragment float4 base_fragment(FragmentIn in [[stage_in]],
                              constant float& time [[buffer(1)]],
                              texture2d<float, access::sample> tex0)
{
    // constexpr sampler s(min_filter::nearest, mag_filter::nearest, mip_filter::none);
    // float3 color = tex0.sample(s, in.uv).xyz;
    
    float2 uv = in.uv;
    
    float3 hsv = float3( uv.x, 0.5+0.5*sin(time), uv.y );
    float3 rgb = hsv2rgb(hsv);
    float3 hsl = rgb2hsl(rgb);
    
    rgb = hsl2rgb(hsl);
    
    return float4(rgb, 1.0);
}
