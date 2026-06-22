Shader "Vertigo/URP/Vertical Stream"
{
    /*
        Vertical energy stream for spcl_effectcurves.fbx ribbon meshes.

        UV.x = 0..1 along strand length (tip fade)
        UV.y = 0..1 across ribbon width — primary scroll axis (vertical motion on mesh)

        Motion:
          - Streaks and bands scroll upward along UV.y
          - Optional world-Y drift keeps flow feeling "rising"
          - Along-strand variation breaks up repetition

        No vertex deformation. Additive transparent.
    */

    Properties
    {
        [Header(Colors)]
        _BaseColor          ("Base Gold",                   Color) = (1.0, 0.68, 0.10, 1)
        _StreamColor        ("Stream Hot",                  Color) = (1.0, 0.95, 0.65, 1)
        _Intensity          ("Emission Intensity",          Float) = 2.2

        [Header(Vertical Motion)]
        _VerticalSpeed      ("Scroll Speed (UV.y)",         Float) = 0.85
        _WorldUpSpeed       ("World Up Drift Speed",        Float) = 0.25
        _WorldUpScale       ("World Up Scale",              Float) = 1.2
        [Toggle] _ReverseFlow ("Reverse Direction",         Float) = 0

        [Header(Streams)]
        _StreamCount        ("Stream Count (across width)", Float) = 6.0
        _StreamWidth        ("Stream Width",                Range(0.02, 0.5)) = 0.12
        _StreamSoftness     ("Stream Softness",             Range(0.01, 0.5)) = 0.08
        _BandCount          ("Band Count (vertical bands)", Float) = 4.0
        _BandStrength       ("Band Strength",               Range(0, 2)) = 0.75

        [Header(Strand Shape)]
        _Opacity            ("Opacity",                     Range(0, 1)) = 0.7
        _TipFade            ("Tip Fade (UV.x)",             Range(0.01, 0.5)) = 0.10
        _EdgeFade           ("Edge Fade (UV.y)",            Range(0.01, 0.5)) = 0.18
        _EdgeGlow           ("Long-Edge Glow",              Range(0, 2)) = 1.0

        [Header(Variation)]
        _AlongWarp          ("Along-Strand Warp",           Range(0, 1)) = 0.35
        _Shimmer            ("Shimmer Strength",            Range(0, 1)) = 0.4
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

        Pass
        {
            Name "VerticalStream"
            Blend SrcAlpha One
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
                float4 color      : COLOR;
            };

            struct Varyings
            {
                float4 posCS     : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 posWS     : TEXCOORD1;
                float3 normalWS  : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float4 color     : COLOR;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _StreamColor;
                float  _Intensity;

                float  _VerticalSpeed;
                float  _WorldUpSpeed;
                float  _WorldUpScale;
                float  _ReverseFlow;

                float  _StreamCount;
                float  _StreamWidth;
                float  _StreamSoftness;
                float  _BandCount;
                float  _BandStrength;

                float  _Opacity;
                float  _TipFade;
                float  _EdgeFade;
                float  _EdgeGlow;

                float  _AlongWarp;
                float  _Shimmer;
                float  _Seed;
            CBUFFER_END

            float Hash21(float2 p)
            {
                p = frac(p * float2(127.1, 311.7));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = Hash21(i);
                float b = Hash21(i + float2(1.0, 0.0));
                float c = Hash21(i + float2(0.0, 1.0));
                float d = Hash21(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float StrandMask(float x, float soft)
            {
                return smoothstep(0.0, soft, x) * smoothstep(1.0, 1.0 - soft, x);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vpi = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   vni = GetVertexNormalInputs(IN.normalOS);

                OUT.posCS     = vpi.positionCS;
                OUT.posWS     = vpi.positionWS;
                OUT.normalWS  = vni.normalWS;
                OUT.viewDirWS = GetWorldSpaceViewDir(vpi.positionWS);
                OUT.uv        = IN.uv;
                OUT.color     = IN.color;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;
                float along = uv.x;
                float across = uv.y;

                float dir = _ReverseFlow > 0.5 ? -1.0 : 1.0;
                float t = _Time.y + _Seed * 2.71;

                float tipMask = StrandMask(along, _TipFade);
                float edgeMask = StrandMask(across, _EdgeFade);

                // Long-edge glow: brighter near ribbon side edges (across ≈ 0 or 1)
                half edgeDist = abs(across - 0.5) * 2.0;
                half longEdge = pow(edgeDist, 1.6) * (half)_EdgeGlow;

                // Vertical scroll coordinate — primary motion along mesh V
                float worldLift = IN.posWS.y * _WorldUpScale * 0.15;
                float vFlow = across * dir + t * _VerticalSpeed + worldLift + t * _WorldUpSpeed * dir;

                // Along-strand warp offsets each column differently
                float warp = ValueNoise(float2(along * 4.0 + _Seed, floor(t * 0.35))) * _AlongWarp;
                vFlow += warp;

                // Vertical light streams (thin columns moving up UV.y)
                float streamPhase = vFlow * _StreamCount;
                float streamFrac = frac(streamPhase);
                float streamCenter = abs(streamFrac - 0.5);
                half streams = 1.0h - smoothstep((half)_StreamWidth, (half)(_StreamWidth + _StreamSoftness), (half)streamCenter);

                // Broader vertical bands
                float bandPhase = frac(vFlow * _BandCount);
                half bands = 1.0h - abs(bandPhase - 0.5h) * 2.0h;
                bands = pow(saturate(bands), 2.5h) * (half)_BandStrength;

                // Shimmer tied to vertical position
                half shimmer = (half)sin(vFlow * 18.0 + along * 9.0 + t * 3.0) * 0.5h + 0.5h;
                shimmer = lerp(1.0h, shimmer, (half)_Shimmer);

                // Subtle view rim
                half NdotV = saturate(dot(normalize((half3)IN.normalWS), normalize((half3)IN.viewDirWS)));
                half rim = pow(1.0h - NdotV, 2.0h) * 0.35h;

                half energy = saturate(streams * 0.85h + bands * 0.45h + longEdge * 0.35h + rim);
                energy *= shimmer;

                half3 col = lerp((half3)_BaseColor.rgb, (half3)_StreamColor.rgb, saturate(streams + bands * 0.5h));
                col += (half3)_StreamColor.rgb * longEdge * 0.25h;
                col *= energy * (half)_Intensity;

                half alpha = energy * (half)tipMask * (half)edgeMask * (half)_Opacity * (half)IN.color.a;

                return half4((float3)col, (float)saturate(alpha));
            }
            ENDHLSL
        }
    }
}
