//
//  MTPixelViewer.metal
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 9/21/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

#include <metal_stdlib>
#include <metal_texture>


using namespace metal;

float4 YpCbCr_to_RGB(float4 YpCbCrValues, constant float4x4& rgbConversionMatrix, constant float4 &YpCbCrOffsets);

constant float2 texCoords[] = {
        {0.0, 0.0},       // bottomLeft
        {1.0, 0.0},       // bottomRight
        {0.0, 1.0},       // topLeft
        {1.0, 1.0},       // topRight
    };

struct VertexOut
{
    float4 position [[position]];
    float2 texCoord [[user(texturecoord)]];
};

vertex VertexOut vertex_passthrough(device float4 *vertices [[buffer(0)]],
                                    uint vertexId [[vertex_id]])
{
    VertexOut out;

    out.position = vertices[vertexId];
    out.texCoord = texCoords[vertexId];
    
    return out;
}

fragment half4 rgba_fragment(VertexOut interpolated [[stage_in]],
                               texture2d<half>  tex2D     [[ texture(0) ]],
                              constant uchar4& permuteTable [[ buffer(0) ]])
{
    constexpr sampler s(coord::normalized,
                        address::clamp_to_edge,
                        filter::linear);
    constexpr sampler defaultSampler;

    half4 final = tex2D.sample(s, interpolated.texCoord);
        
    return half4(final[permuteTable[0]], final[permuteTable[1]], final[permuteTable[2]], final[permuteTable[3]]);
}

fragment half4 rgb24_fragment(VertexOut interpolated [[stage_in]],
                             texture2d<half>  tex2D     [[ texture(0) ]],
                             constant uchar4& permuteTable [[ buffer(0) ]])
{
    constexpr sampler s(coord::pixel,
                        address::clamp_to_edge,
                        filter::linear);
    constexpr sampler defaultSampler;
    
    uint width = tex2D.get_width();
    uint height = tex2D.get_height();
    
    float2 rCoord = float2((interpolated.texCoord.x * (float) width), (interpolated.texCoord.y * (float) height));
    float2 gCoord = float2((interpolated.texCoord.x * (float) width) + 1.0, (interpolated.texCoord.y * (float) height));
    float2 bCoord = float2((interpolated.texCoord.x * (float) width) + 2.0, (interpolated.texCoord.y * (float) height));
    
    half4 final = half4(tex2D.sample(s, rCoord).r,
                        tex2D.sample(s, gCoord).r,
                        tex2D.sample(s, bCoord).r,
                        1.0);
                        
    
    return final;
}


float4 YpCbCr_to_RGB(float4 YpCbCrValues, constant float4x4& rgbConversionMatrix, constant float4 &YpCbCrOffsets)
{
    YpCbCrValues -= YpCbCrOffsets;
    
    return YpCbCrValues * rgbConversionMatrix;
}

fragment float4 YpCbCr_2P_fragment(VertexOut interpolated [[stage_in]],
                                        texture2d<half>  YpTexture [[ texture(0) ]],
                                        texture2d<half>  CbCrTexture [[ texture(1) ]],
                                        constant float4x4& rgbConversionMatrix [[ buffer(1) ]],
                                         constant float4 &YpCbCrOffsets [[ buffer(2)]] )
{
    constexpr sampler s(coord::normalized,
                        address::clamp_to_edge,
                        filter::linear);
    constexpr sampler defaultSampler;
    
    float4 YpCbCrValues = float4(YpTexture.sample(s, interpolated.texCoord).r, CbCrTexture.sample(s, interpolated.texCoord).r, CbCrTexture.sample(s, interpolated.texCoord).g, 1);
    
    return YpCbCr_to_RGB(YpCbCrValues, rgbConversionMatrix, YpCbCrOffsets);
}


fragment float4 YpCbCr_3P_fragment(VertexOut interpolated [[stage_in]],
                                         texture2d<half>  YpTexture [[ texture(0) ]],
                                         texture2d<half>  CbTexture [[ texture(1) ]],
                                         texture2d<half>  CrTexture [[ texture(2) ]],
                                         constant float4x4& rgbConversionMatrix [[ buffer(1) ]],
                                         constant float4 &YpCbCrOffsets [[ buffer(2)]] )
{
    constexpr sampler s(coord::normalized,
                        address::clamp_to_edge,
                        filter::linear);
    constexpr sampler defaultSampler;
    
    float4 YpCbCrValues = float4(YpTexture.sample(s, interpolated.texCoord).r, CbTexture.sample(s, interpolated.texCoord).r, CrTexture.sample(s, interpolated.texCoord).r, 1);
    
    return YpCbCr_to_RGB(YpCbCrValues, rgbConversionMatrix, YpCbCrOffsets);
}

fragment float4 YpCbCr_1P_fragment(VertexOut interpolated [[stage_in]],
                                   texture2d<half>  YpCbCrTexture [[ texture(0) ]],
                                   constant float4x4& rgbConversionMatrix [[ buffer(1) ]],
                                   constant float4 &YpCbCrOffsets [[ buffer(2)]] )
{
    constexpr sampler s(coord::normalized,
                        address::clamp_to_edge,
                        filter::linear);
    constexpr sampler defaultSampler;
    
    float4 YpCbCrValues = float4(YpCbCrTexture.sample(s, interpolated.texCoord).g, YpCbCrTexture.sample(s, interpolated.texCoord).b, YpCbCrTexture.sample(s, interpolated.texCoord).r, 1);

    return YpCbCr_to_RGB(YpCbCrValues, rgbConversionMatrix, YpCbCrOffsets);
}
