﻿Shader "Decal/DecalShader Diffuse+Normals"
{
	Properties
	{
		_MainTex ("Diffuse", 2D) = "white" {}
		_BumpMap ("Normals", 2D) = "bump" {}
	}
	SubShader
	{
		Pass
		{
			Fog { Mode Off } // no fog in g-buffers pass
			ZWrite Off
			//Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#pragma exclude_renderers nomrt
			
			#include "UnityCG.cginc"

			struct v2f
			{
				float4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
				float4 screenUV : TEXCOORD1;
				float3 ray : TEXCOORD2;
				half3 orientation : TEXCOORD3;
				half3 orientationX : TEXCOORD4;
				half3 orientationZ : TEXCOORD5;
			};

			v2f vert (float3 v : POSITION)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (float4(v,1));
				o.uv = v.xz+0.5;
				o.screenUV = ComputeScreenPos (o.pos);
				o.ray = mul (UNITY_MATRIX_MV, float4(v,1)).xyz * float3(-1,-1,1);
				o.orientation = mul ((float3x3)unity_ObjectToWorld, float3(0,1,0));
				o.orientationX = mul ((float3x3)unity_ObjectToWorld, float3(1,0,0));
				o.orientationZ = mul ((float3x3)unity_ObjectToWorld, float3(0,0,1));
				return o;
			}

			CBUFFER_START(UnityPerCamera2)
			// float4x4 _CameraToWorld;
			CBUFFER_END

			sampler2D _MainTex;
			sampler2D _BumpMap;
			sampler2D_float _CameraDepthTexture;
			sampler2D _WorldNormals;

			void frag(v2f i, out half4 outDiffuse : COLOR0, out half4 outNormal : COLOR1)
			{
				// divide by far plane
				i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
				float2 uv = i.screenUV.xy / i.screenUV.w;
				// read depth and reconstruct world position
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
				depth = Linear01Depth (depth);
				//vieport pos
				float4 vpos = float4(i.ray * depth,1);
				// world pos
				float3 wpos = mul (unity_CameraToWorld, vpos).xyz;
				// local object pos
				float3 opos = mul (unity_WorldToObject, float4(wpos,1)).xyz;

				// discard parts that arent visible / projected
				clip (float3(0.5,0.5,0.5) - abs(opos.xyz));

				// multiply the non projection-direction components of vector
				i.uv = opos.xy+0.5;

				half3 normal = tex2D(_WorldNormals, uv).rgb;
				fixed3 wnormal = normal.rgb * 2.0 - 1.0;
				// orientation is Direction of projection, 0.3 is minimum scale / clipping value
				clip (dot(wnormal, i.orientationZ) - 0.3);
				// main color
				fixed4 col = tex2D (_MainTex, i.uv);
				clip (col.a - 0.2);
				outDiffuse = col;
				// normal stuff
				fixed3 nor = UnpackNormal(tex2D(_BumpMap, i.uv));
				half3x3 norMat = half3x3(i.orientationX, i.orientationZ, i.orientation);
				nor = mul (nor, norMat);
				outNormal = fixed4(nor * 0.5+0.5,1);

			}
			ENDCG
		}		

	}

	Fallback Off
}
