// SPDX-License-Identifier: MIT
Shader "Hidden/Gaussian Splatting/Composite"
{
    SubShader
    {
        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha

            
HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"

struct Attributes
{
    uint vertexID : SV_VertexID;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings vert(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float2 quadPos = float2(input.vertexID&1, (input.vertexID>>1)&1) * 4.0 - 1.0;
    
    output.positionCS = float4(quadPos, 0, 1);
    
    return output;
}

TEXTURE2D_X(_GaussianSplatRT);
SAMPLER(sampler_GaussianSplatRT);

half4 frag (Varyings i) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
    float2 foveatedUV = FoveatedRemapNonUniformToLinear(i.positionCS.xy / _ScreenParams.xy);
    half4 col = SAMPLE_TEXTURE2D_X(_GaussianSplatRT, sampler_GaussianSplatRT, foveatedUV);
    col.rgb = Gamma22ToLinear(col.xyz);
    col.a = saturate(col.a * 1.5);
    return col;
}

ENDHLSL
        }
    }
}
