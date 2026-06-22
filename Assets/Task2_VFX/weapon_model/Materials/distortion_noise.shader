Shader "Vertigo/URP/Distortion Noise"
{
    /*
        Noise-driven mesh + UV distortion for ribbon / VFX meshes.

        spcl_effectcurves.fbx convention:
          UV.x = along strand, UV.y = across width

        Distortion pipeline:
          1. Vertex  — procedural noise pushes vertices along normals (no tex fetch)
          2. Fragment — _DistortTex RG warps UVs before pattern evaluation

        Vertex stage avoids texture samples for Metal / mobile compatibility.
    */

    Properties
    {
        [Header(Colors)]
        _Color              ("Base Color",                  Color) = (1.0, 0.74, 0.18, 1)
        _HighlightColor     ("Highlight",                   Color) = (1.0, 0.96, 0.72, 1)
        _Intensity          ("Emission Intensity",          Range(0, 4)) = 1.8

        [Header(Noise Distortion)]
        _DistortTex         ("Distortion Noise (RG=XY)",    2D) = "grey" {}
        _DistortScale       ("Noise Scale",                 Float) = 3.0
        _DistortSpeed       ("Noise Scroll Speed",          Float) = 0.55
        _UVDistort          ("UV Distort Strength",         Range(0, 0.5)) = 0.12
        _VertexDistort      ("Vertex Distort Strength",     Range(0, 0.15)) = 0.025
        _DistortLayers      ("Distort Layers",              Range(1, 3)) = 2

        [Header(Pattern)]
        _PatternScale       ("Pattern Scale",               Float) = 6.0
        _PatternSpeed       ("Pattern Flow Speed",          Float) = 0.8
        _PatternContrast    ("Pattern Contrast",            Range(0.5, 4)) = 2.0

        [Header(Alpha)]
        _Opacity            ("Opacity",                     Range(0, 1)) = 0.68
        _TipSoft            ("Tip Fade (UV.x)",             Range(0.02, 0.5)) = 0.11
        _EdgeSoft           ("Edge Fade (UV.y)",            Range(0.02, 0.5)) = 0.20
        _RimStrength        ("View Rim",                    Range(0, 1)) = 0.35

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

        Pass
        {
            Name "DistortionNoise"
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
                float4 posCS     : SV_POSITION;
                half2  uv        : TEXCOORD0;
                half2  noiseUV   : TEXCOORD1;
                half   fadeMask  : TEXCOORD2;
                half3  normalWS  : TEXCOORD3;
                half3  viewDirWS : TEXCOORD4;
                half4  color     : COLOR;
            };

            TEXTURE2D(_DistortTex);
            SAMPLER(sampler_DistortTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _HighlightColor;
                half  _Intensity;

                float4 _DistortTex_ST;
                half  _DistortScale;
                half  _DistortSpeed;
                half  _UVDistort;
                half  _VertexDistort;
                half  _DistortLayers;

                half  _PatternScale;
                half  _PatternSpeed;
                half  _PatternContrast;

                half  _Opacity;
                half  _TipSoft;
                half  _EdgeSoft;
                half  _RimStrength;

                half  _Seed;
            CBUFFER_END

            half Hash21(half2 p)
            {
                p = frac(p * half2(127.1h, 311.7h));
                p += dot(p, p + 45.32h);
                return frac(p.x * p.y);
            }

            half ProcNoise(half2 p)
            {
                half2 i = floor(p);
                half2 f = frac(p);
                f = f * f * (3.0h - 2.0h * f);

                half a = Hash21(i);
                half b = Hash21(i + half2(1.0h, 0.0h));
                half c = Hash21(i + half2(0.0h, 1.0h));
                half d = Hash21(i + half2(1.0h, 1.0h));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            half2 ProcDistortField(half2 uv)
            {
                half n0 = ProcNoise(uv * 1.7h);
                half n1 = ProcNoise(uv * 1.7h + half2(4.3h, 1.9h));
                return half2(n0, n1) - 0.5h;
            }

            half2 SampleDistortField(half2 uv)
            {
                half4 n = SAMPLE_TEXTURE2D(_DistortTex, sampler_DistortTex, uv);
                half2 field = n.rg - 0.5h;

                half2 procField = ProcDistortField(uv);
                half blend = saturate(abs(field.x) + abs(field.y)) * 4.0h;
                return lerp(procField, field, blend);
            }

            half StrandFade(half x, half soft)
            {
                return smoothstep(0.0h, soft, x) * smoothstep(1.0h, 1.0h - soft, x);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                half seed = (half)_Seed;
                half t = (half)_Time.y;
                half2 noiseUV = (half2)IN.uv * (half)_DistortScale + half2(t * _DistortSpeed + seed, seed * 0.31h);

                half2 d0 = ProcDistortField(noiseUV);
                half2 d1 = ProcDistortField(noiseUV * 1.9h + half2(2.7h, 0.0h));
                half push = (d0.x + d0.y + d1.x) * (1.0h / 3.0h);

                float3 posOS = IN.positionOS.xyz
                             + IN.normalOS * (float)(push * _VertexDistort);

                VertexPositionInputs vpi = GetVertexPositionInputs(posOS);
                VertexNormalInputs   vni = GetVertexNormalInputs(IN.normalOS);

                OUT.posCS     = vpi.positionCS;
                OUT.uv        = (half2)IN.uv;
                OUT.noiseUV   = noiseUV;
                OUT.fadeMask  = StrandFade((half)IN.uv.x, (half)_TipSoft)
                              * StrandFade((half)IN.uv.y, (half)_EdgeSoft);
                OUT.normalWS  = (half3)normalize(vni.normalWS);
                OUT.viewDirWS = (half3)normalize(GetWorldSpaceViewDir(vpi.positionWS));
                OUT.color     = IN.color;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half2 uv = IN.uv;
                half t = (half)_Time.y;

                // Layered UV distortion — unrolled for Metal / mobile
                half2 warp = half2(0.0h, 0.0h);
                half2 coord = IN.noiseUV;
                half layers = saturate(_DistortLayers);

                half2 layer0 = SampleDistortField(coord);
                warp += layer0 * (half)_UVDistort * 0.55h;
                coord += layer0 * 0.35h;

                half2 layer1 = SampleDistortField(coord + warp);
                warp += layer1 * (half)_UVDistort * 1.1h * step(1.5h, layers);
                coord += layer1 * 0.35h * step(1.5h, layers);

                half2 layer2 = SampleDistortField(coord + warp);
                warp += layer2 * (half)_UVDistort * 1.65h * step(2.5h, layers);

                half2 warpedUV = uv + warp;

                // Pattern read through the distorted UV field
                half2 patUV = warpedUV * (half)_PatternScale + half2(t * _PatternSpeed, -t * _PatternSpeed * 0.6h);
                half patA = ProcNoise(patUV);
                half patB = ProcNoise(patUV * 1.8h + 3.1h);
                half pattern = pow(saturate(patA * patB), (half)_PatternContrast);

                // Distortion magnitude boosts hot spots
                half distortMag = saturate(length(warp) * 8.0h);
                half energy = saturate(pattern * 0.75h + distortMag * 0.55h);

                half NdotV = saturate(dot(IN.normalWS, IN.viewDirWS));
                half rim = (1.0h - NdotV) * (1.0h - NdotV) * (half)_RimStrength;
                energy = saturate(energy + rim);

                half3 col = lerp((half3)_Color.rgb, (half3)_HighlightColor.rgb, saturate(pattern + distortMag * 0.5h));
                col *= energy * (half)_Intensity;

                half alpha = energy * IN.fadeMask * (half)_Opacity * (half)IN.color.a;
                return half4(col, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
