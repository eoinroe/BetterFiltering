/*
 // The MIT License
 // Copyright © 2013 Inigo Quilez
 // https://www.youtube.com/c/InigoQuilez
 // https://iquilezles.org/
 // Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 // This is the implementation for my article "improved texture interpolation"
 //
 // http://www.iquilezles.org/www/articles/texture/texture.htm
 //
 // It shows how to get some smooth texture interpolation without resorting to the regular
 // bicubic filtering, which is pretty expensive because it needs 9 texels instead of the
 // 4 the hardware uses for bilinear interpolation.
 //
 // With this techinique here, you can get smooth interpolation while still using only
 // 4 texel fetches, by tricking the hardware. The idea is to get the fractional part
 // of the texel coordinates and apply a smooth curve to it such that the derivatives are
 // zero at the extremes. The regular cubic or quintic smoothstep functions are just
 // perfect for this task.

 void mainImage( out vec4 fragColor, in vec2 fragCoord )
 {
     vec2 p = fragCoord/iResolution.x;
     vec2 uv = p*0.1;
     
     //---------------------------------------------
     // regular texture map filtering
     //---------------------------------------------
     vec3 colA = texture( iChannel0, uv ).xyz;

     //---------------------------------------------
     // my own filtering
     //---------------------------------------------
     float textureResolution = iChannelResolution[0].x;
     uv = uv*textureResolution + 0.5;
     vec2 iuv = floor( uv );
     vec2 fuv = fract( uv );
     uv = iuv + fuv*fuv*(3.0-2.0*fuv); // fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);;
     uv = (uv - 0.5)/textureResolution;
     vec3 colB = texture( iChannel0, uv ).xyz;
     
     //---------------------------------------------
     // final color
     //---------------------------------------------
     float f = sin(3.1415927*p.x + 0.7*iTime);
     vec3 col = (f>=0.0) ? colA : colB;
     col *= smoothstep( 0.0, 0.01, abs(f-0.0) );
     
     fragColor = vec4( col, 1.0 );
 }
 */

#include <metal_stdlib>
using namespace metal;

kernel void better_filtering(texture2d<float, access::sample> rgba_noise       [[texture(0)]],
                             texture2d<float, access::write>  filtered_texture [[texture(1)]],
                             constant float2& resolution [[buffer(0)]],
                             constant float& time        [[buffer(1)]],
                             uint2 gid [[thread_position_in_grid]])
{
    float2 p = float2(gid) / resolution.x;
    
    // Zooms in on the texture
    float2 uv = p * 0.1;
    
    sampler s (filter::linear);
    
    //---------------------------------------------
    // regular texture map filtering
    //---------------------------------------------
    float3 colA = rgba_noise.sample(s, uv).rgb;
    
    //---------------------------------------------
    // my own filtering
    //---------------------------------------------
    float textureResolution = rgba_noise.get_width();
    uv = uv*textureResolution + 0.5;
    float2 iuv = floor( uv );
    float2 fuv = fract( uv );
    uv = iuv + fuv*fuv*(3.0-2.0*fuv); // fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);;
    // uv = iuv + fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);;
    uv = (uv - 0.5)/textureResolution;
    
    float3 colB = rgba_noise.sample(s, uv).rgb;
    
    /*
     The following member functions gather four samples for bilinear interpolation when sampling a
     2D texture array:
     Tv gather(sampler s, float2 coord, uint array, int2 offset = int2(0),
     component c = component::x) const
     */
    
    
    //---------------------------------------------
    // final color
    //---------------------------------------------
    float f = sin(3.1415927*p.x + 0.7*time);
    float3 col = (f>=0.0) ? colA : colB;
    col *= smoothstep( 0.0, 0.05, abs(f-0.0) );
    
    filtered_texture.write(float4(col, 1.0), gid);
}
