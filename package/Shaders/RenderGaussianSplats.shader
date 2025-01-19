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
StructuredBuffer<uint> _VisibleIndexes;

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
	uint visibleIndice = _VisibleIndexes[instId];
	instId = _OrderBuffer[visibleIndice];
	SplatViewData view = _SplatViewData[instId];
#endif
	
	SplatData splat = LoadSplatData(instId);
	float4 centerWorldPos = mul(UNITY_MATRIX_M, float4(splat.pos, 1));
	float4 centerClipPos = mul(UNITY_MATRIX_VP, centerWorldPos);
	
	bool behindCam = centerClipPos.w <= 0;
	if (behindCam)
	{
		o.vertex = asfloat(0x7fc00000); // NaN discards the primitive
	}
	else
	{
		o.col.r = f16tof32(view.color.x >> 16);
		o.col.g = f16tof32(view.color.x);
		o.col.b = f16tof32(view.color.y >> 16);
		o.col.a = f16tof32(view.color.y);

		uint idx = v.vtxID;
		float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0;
		
		quadPos *= 2;
		float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy;
		
		o.pos = quadPos;
		o.vertex = centerClipPos;
		o.vertex.xy += deltaScreenPos * centerClipPos.w;

		// is this splat selected?
		if (_SplatBitsValid)
		{
			uint wordIdx = v.vtxID / 32;
			uint bitIdx = v.vtxID & 31;
			uint selVal = _SplatSelectedBits.Load(wordIdx * 4);
			if (selVal & (1 << bitIdx))
			{
				o.col.a = -1;				
			}
		}
	}
    return o;
}

half4 frag (v2f i) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
	float power = -dot(i.pos, i.pos);
	half alpha = exp(power);
	if (i.col.a >= 0)
	{
		alpha = saturate(alpha * i.col.a);
	}
	else
	{
		// "selected" splat: magenta outline, increase opacity, magenta tint
		half3 selectedColor = half3(1,0,1);
		if (alpha > 7.0/255.0)
		{
			if (alpha < 10.0/255.0)
			{
				alpha = 1;
				i.col.rgb = selectedColor;
			}
			alpha = saturate(alpha + 0.3);
		}
		i.col.rgb = lerp(i.col.rgb, selectedColor, 0.5);
	}
	
    if (alpha < 1.0/255.0)
        discard;

    half4 res = half4(i.col.rgb * alpha, alpha);
    return res;
}
ENDHLSL
        }
    }
}
