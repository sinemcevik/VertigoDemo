Shader "Vertigo/URP/Wispy Wind Mobile"
{
    /*
        Mobile-first windy wispy ribbon shader for spcl_effectcurves.fbx.

        UV.x = along strand   |   UV.y = across width

        Mobile choices:
          - Zero texture samples
          - Fades baked in vertex
          - 2 interference sin layers only (no FBM / loops)
          - half math, low varyings, single pass
          - No vertex displacement

        Look: soft airy wisps flowing along the strand with feathered alpha.
    */

    Properties
    {
        [Header(Colors)]
        _TintColor          ("Wisp Tint",                   Color) = (1.0, 0.82, 0.38, 1)
        _HotColor           ("Hot Wisp",                    Color) = (1.0, 0.97, 0.78, 1)
        _Intensity          ("Intensity",                   Range(0, 4)) = 1.6

        [Header(Wind Flow)]
        _FlowSpeed          ("Flow Speed",                  Range(0, 3)) = 0.9
        _FlowFreq           ("Flow Frequency",              Range(1, 24)) = 7.0
        _CrossFreq          ("Cross Frequency",             Range(1, 24)) = 11.0
        _Turbulence         ("Turbulence Mix",              Range(0, 1)) = 0.45

        [Header(Wisp Shape)]
        _WispSharpness      ("Wisp Sharpness",              Range(0.5, 6)) = 2.2
        _CoreSoftness       ("Core Softness",               Range(0, 1)) = 0.55
        _Opacity            ("Opacity",                     Range(0, 1)) = 0.62

        [Header(Strand Fade)]
        _TipSoft            ("Tip Softness",                Range(0.02, 0.5)) = 0.12
        _EdgeSoft           ("Edge Softness",               Range(0.02, 0.5)) = 0.22
        _RimStrength        ("View Rim",                    Range(0, 1)) = 0.28

        [Header(Variation)]
        _Seed               ("Instance Seed",               Float) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Transparent"
            "RenderType"     = "Transparent"
        }

        LOD 200

        Pass
        {
            Name "WispyWindMobile"
            Blend SrcAlpha One
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0
            #pragma prefer_hlslcc gles
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
                half4  color      : COLOR;
            };

            struct Varyings
            {
                float4 posCS    : SV_POSITION;
                half2  uv       : TEXCOORD0;
                half   flowPhase: TEXCOORD1;
                half   crossPhase: TEXCOORD2;
                half   fadeMask : TEXCOORD3;
                half3  normalWS : TEXCOORD4;
                half3  viewDirWS: TEXCOORD5;
                half4  color    : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _TintColor;
                half4 _HotColor;
                half  _Intensity;
                half  _FlowSpeed;
                half  _FlowFreq;
                half  _CrossFreq;
                half  _Turbulence;
                half  _WispSharpness;
                half  _CoreSoftness;
                half  _Opacity;
                half  _TipSoft;
                half  _EdgeSoft;
                half  _RimStrength;
                half  _Seed;
            CBUFFER_END

            half StrandFade(half x, half soft)
            {
                return smoothstep(0.0h, soft, x) * smoothstep(1.0h, 1.0h - soft, x);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vpi = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   vni = GetVertexNormalInputs(IN.normalOS);

                half seed = (half)_Seed;
                half t = (half)_Time.y;

                OUT.posCS      = vpi.positionCS;
                OUT.uv         = (half2)IN.uv;
                OUT.flowPhase  = IN.uv.x * _FlowFreq - t * _FlowSpeed + seed;
                OUT.crossPhase = IN.uv.y * _CrossFreq + seed * 0.37h;
                OUT.fadeMask   = StrandFade((half)IN.uv.x, (half)_TipSoft)
                               * StrandFade((half)IN.uv.y, (half)_EdgeSoft);
                OUT.normalWS   = (half3)normalize(vni.normalWS);
                OUT.viewDirWS  = (half3)normalize(GetWorldSpaceViewDir(vpi.positionWS));
                OUT.color      = IN.color;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Two cheap interference layers — wispy breakup without textures
                half f = IN.flowPhase;
                half c = IN.crossPhase;

                half layerA = sin(f * 6.28318h) * sin(c * 6.28318h + f * 1.7h);
                half layerB = sin(f * 4.1h + c * 0.6h + 2.0h) * sin(c * 5.3h - f * 0.9h);
                layerA = layerA * 0.5h + 0.5h;
                layerB = layerB * 0.5h + 0.5h;

                half wisps = layerA * layerB;
                wisps = lerp(wisps, layerA, (half)_Turbulence);
                wisps = pow(saturate(wisps), (half)_WispSharpness);

                // Soft airy core — dim centre, keep wispy filaments
                half across = abs(IN.uv.y - 0.5h) * 2.0h;
                half core = lerp(1.0h, 1.0h - across, (half)_CoreSoftness);
                wisps *= core;

                // Cheap rim (no pow) for mobile
                half NdotV = saturate(dot(IN.normalWS, IN.viewDirWS));
                half rim = (1.0h - NdotV) * (1.0h - NdotV) * (half)_RimStrength;

                half energy = saturate(wisps + rim);
                half3 col = lerp((half3)_TintColor.rgb, (half3)_HotColor.rgb, wisps);
                col *= energy * (half)_Intensity;

                half alpha = energy * IN.fadeMask * (half)_Opacity * (half)IN.color.a;

                return half4(col, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
