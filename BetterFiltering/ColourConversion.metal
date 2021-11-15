//
//  ColourConversion.metal
//  BetterFiltering
//
//  Created by Eoin Roe on 15/11/2021.
//

#include <metal_stdlib>
using namespace metal;

constant float eps = 0.0000001;

float3 hsv2rgb(float3 c)
{
    float3 rgb = clamp( abs(fmod(c.x*6.0+float3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z * mix( float3(1.0), rgb, c.y);
}

float3 hsl2rgb(float3 c)
{
    float3 rgb = clamp( abs(fmod(c.x*6.0+float3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}

float3 rgb2hsv(float3 c)
{
    float4 k = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    float4 p = mix(float4(c.zy, k.wz), float4(c.yz, k.xy), (c.z<c.y) ? 1.0 : 0.0);
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), (p.x<c.x) ? 1.0 : 0.0);
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0*d+eps)), d / (q.x+eps), q.x);
}

float3 rgb2hsl(float3 c)
{
    float minc = min( c.r, min(c.g, c.b) );
    float maxc = max( c.r, max(c.g, c.b) );
    float3  mask = step(c.grr,c.rgb) * step(c.bbg, c.rgb);
    float3 h = mask * (float3(0.0,2.0,4.0) + (c.gbr - c.brg)/(maxc-minc + eps)) / 6.0;
    return float3( fract( 1.0 + h.x + h.y + h.z ),              // H
                 (maxc-minc)/(1.0-abs(minc+maxc-1.0) + eps),    // S
                 (minc+maxc)*0.5 );                             // L
}
