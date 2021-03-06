Shader "Hidden/Internal-DeferredShading" {
Properties {
    _LightTexture0 ("", any) = "" {}
    _LightTextureB0 ("", 2D) = "" {}
    _ShadowMapTexture ("", any) = "" {}
    _SrcBlend ("", Float) = 1
    _DstBlend ("", Float) = 1

}
SubShader {

// Pass 1: Lighting pass
//  LDR case - Lighting encoded into a subtractive ARGB8 buffer
//  HDR case - Lighting additively blended into floating point buffer
Pass {
    ZWrite Off
    Blend [_SrcBlend] [_DstBlend]

CGPROGRAM

#define UNITY_BRDF_PBS BRDF_CUSTOM_Unity_PBS

#pragma multi_compile FANCY_STUFF_OFF FANCY_STUFF_ON
#pragma target 3.0
#pragma vertex vert_deferred
#pragma fragment frag
#pragma multi_compile_lightpass
#pragma multi_compile ___ UNITY_HDR_ON

#pragma exclude_renderers nomrt

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
//#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityStandardBRDFCustom.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

uniform int _TTerrainXP;
uniform half _LightingMultiplier;
uniform fixed4 _SunColor;
uniform fixed4 _SunAmbience;
uniform fixed4 _ShadowColor;
uniform fixed4 _SpecularColor;

half4 CalculateLight (unity_v2f_deferred i)
{
    float3 wpos;
    float2 uv;
    float atten, fadeDist;
    UnityLight light;
    UNITY_INITIALIZE_OUTPUT(UnityLight, light);
    UnityDeferredCalculateLightParams (i, wpos, uv, light.dir, atten, fadeDist);

    light.color = _LightColor.rgb * atten;



    // unpack Gbuffer
    half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv);
    half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv);
    half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv);
    UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

    data.diffuseColor.rgb   = gbuffer0.rgb;

    float3 eyeVec = normalize(wpos-_WorldSpaceCameraPos);
    half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);

    UnityIndirect ind;
    UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
    ind.diffuse = 0;
    ind.specular = 0;

   // if (light.ndotl <= 0.0) 
   //  light.ndotl = 0;
   // else 
   //  light.ndotl = 1;

    //half4 res = UNITY_BRDF_PBS (data.diffuseColor, data.specularColor, oneMinusReflectivity, data.smoothness, data.normalWorld, -eyeVec, light, ind);
	 float4 c;
	 float3 spec = float3(0,0,0);
	 float AlbedoAlpha = gbuffer1.a;
	 fixed3 SunColor = _SunColor.rgb * 2;
	 fixed3 SunAmbience = _SunAmbience.rgb * 2;
	 fixed3 ShadowFillColor = _ShadowColor.rgb * 2;
	 fixed4 SpecularColor = _SpecularColor.rgba * 2;

	if(_TTerrainXP <= 0){ // Normal lighting
		float NdotL = dot (light.dir, data.normalWorld);

		float3 R = light.dir - 2.0f * NdotL * data.normalWorld;
		float specular = pow( saturate( dot(R, eyeVec) ), 8) * SpecularColor.r * AlbedoAlpha * 2;
		float3 lighting = SunColor * saturate(NdotL) * atten + SunAmbience + specular;
		lighting = _LightingMultiplier * lighting + ShadowFillColor * (1 - lighting);
		c.rgb = (data.diffuseColor + spec) * lighting;
		c.a = 1;
	}
	else{ // XP lighting

		float NdotL = dot (light.dir, data.normalWorld);

		float3 r = reflect(eyeVec, data.normalWorld);

		float3 specular = (pow(saturate(dot(r, light.dir)), 80) * AlbedoAlpha * SpecularColor.a) * SpecularColor.rgb;

		float dotSunNormal = dot(light.dir, data.normalWorld);

		//float shadow = tex2D(ShadowSampler, pixel.mShadow.xy).g;
		float3 light = SunColor * saturate(dotSunNormal) * atten + SunAmbience;
		light = _LightingMultiplier * light + ShadowFillColor * (1 - light);
		c.rgb = light * (data.diffuseColor + specular.rgb);

		//float waterDepth = tex2Dproj(UtilitySamplerC, pixel.mTexWT*TerrainScale).g;
		//float4 water = tex1D(WaterRampSampler, waterDepth);
		//c.rgb = lerp(albedo.rgb, water.rgb, water.a);

	}


	//half4 res = data.diffuseColor;

    return c;
}

#ifdef UNITY_HDR_ON
half4
#else
fixed4
#endif
frag (unity_v2f_deferred i) : SV_Target
{
    half4 c = CalculateLight(i);
    #ifdef UNITY_HDR_ON
    return c;
    #else
    return exp2(-c);
    #endif
}

ENDCG
}


// Pass 2: Final decode pass.
// Used only with HDR off, to decode the logarithmic buffer into the main RT
Pass {
    ZTest Always Cull Off ZWrite Off
    Stencil {
        ref [_StencilNonBackground]
        readmask [_StencilNonBackground]
        // Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
        compback equal
        compfront equal
    }

CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma exclude_renderers nomrt

#include "UnityCG.cginc"

sampler2D _LightBuffer;
struct v2f {
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.texcoord = texcoord.xy;
#ifdef UNITY_SINGLE_PASS_STEREO
    o.texcoord = TransformStereoScreenSpaceTex(o.texcoord, 1.0f);
#endif
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    return -log2(tex2D(_LightBuffer, i.texcoord));
}
ENDCG 
}

}
Fallback Off
}