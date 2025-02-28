// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Render Splats"
{
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            ZWrite Off
            Blend OneMinusDstAlpha One
            Cull Off
            
HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "GaussianSplatting.hlsl"

StructuredBuffer<uint> _OrderBuffer;

struct appdata
{
	uint vtxID : SV_VertexID;
	uint instID : SV_InstanceID;
	UNITY_VERTEX_INPUT_INSTANCE_ID //Insert
};

struct v2f
{
    float4 col : COLOR0;
    float2 pos : TEXCOORD0;
    float4 vertex : SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID //Insert
	UNITY_VERTEX_OUTPUT_STEREO //Insert
};

StructuredBuffer<SplatViewData> _SplatViewData;
ByteAddressBuffer _SplatSelectedBits;
uint _SplatBitsValid;

v2f vert (appdata v)
{
	UNITY_SETUP_INSTANCE_ID(v); //Insert
    v2f o = (v2f)0;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); //Insert

	uint instId = v.instID;
#ifdef STEREO_INSTANCING_ON	
	instId = _OrderBuffer[floor(instId / 2)];
	SplatViewData view = _SplatViewData[instId * 2 + unity_StereoEyeIndex];
#else
	instId = _OrderBuffer[instId];
	SplatViewData view = _SplatViewData[instId];
#endif

	SplatData splat = LoadSplatData(instId);
	float4 centerWorldPos = mul(UNITY_MATRIX_M, float4(splat.pos, 1));
	float4 centerClipPos = mul(UNITY_MATRIX_VP, centerWorldPos);

	o.col.r = f16tof32(view.color.x >> 16);
	o.col.g = f16tof32(view.color.x);
	o.col.b = f16tof32(view.color.y >> 16);
	o.col.a = f16tof32(view.color.y);

	uint idx = v.vtxID;
	float2 quadPos = float2(idx & 1, (idx >> 1) & 1) * 2.0 - 1.0;

	quadPos *= 1.5f;
	float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy;

	o.pos = quadPos;
	o.vertex = centerClipPos;
	o.vertex.xy += deltaScreenPos * centerClipPos.w;
	
	// o.col.a = f16tof32(view.color.y);
	// if (o.col.a < 0.1)
	// {
	// 	o.vertex = asfloat(0x7fc00000); // NaN discards the primitive
	// }
	// else
	// {
	// 	o.col.r = f16tof32(view.color.x >> 16);
	// 	o.col.g = f16tof32(view.color.x);
	// 	o.col.b = f16tof32(view.color.y >> 16);
	// 	
	//
	// 	uint idx = v.vtxID;
	// 	float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0;
	// 	
	// 	quadPos *= 1.5;
	// 	float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy;
	// 	
	// 	o.pos = quadPos;
	// 	o.vertex = centerClipPos;
	// 	o.vertex.xy += deltaScreenPos * centerClipPos.w;
	//
	// 	// is this splat selected?
	// 	// if (_SplatBitsValid)
	// 	// {
	// 	// 	uint wordIdx = v.vtxID / 32;
	// 	// 	uint bitIdx = v.vtxID & 31;
	// 	// 	uint selVal = _SplatSelectedBits.Load(wordIdx * 4);
	// 	// 	if (selVal & (1 << bitIdx))
	// 	// 	{
	// 	// 		o.col.a = -1;				
	// 	// 	}
	// 	// }
	// }

	return o;
}

half4 frag (v2f i) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
	float power = -dot(i.pos, i.pos);
	float alpha = exp2(power);
	alpha = saturate(alpha * i.col.a);
    half4 res = half4(i.col.rgb * alpha, alpha);
    return res;
}
ENDHLSL
        }
    }
}
