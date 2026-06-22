Shader "Vertigo/URP/Top Scorer Golden Wisp"
{
    /*
        Top Scorer legendary golden energy wisps for spcl_effectcurves.fbx.

        UV.x = along strand (0 tip → 1 tip)
        UV.y = across ribbon width (0 edge → 1 edge)

        Visual model (matches CX Top Scorer reference):
          - Ridged multifractal filaments advected along the strand
          - Soft Gaussian falloff across ribbon width (ethereal ghost wisps)
          - Domain-warped flow for liquid golden motion
          - Four-point star sparkles in world space
          - View Fresnel softens edges into transparency
          - Optional noise texture enriches breakup (works fully procedural)

        No vertex deformation — mesh stays as authored.
        Additive transparent for bloom.
    */

    Properties
    {
        [Header(Colors)]
        _DeepGold           ("Deep Gold",                   Color) = (0.72, 0.42, 0.04, 1)
        _BodyGold           ("Body Gold",                   Color) = (1.0, 0.72, 0.10, 1)
        _HotGold            ("Hot Gold",                    Color) = (1.0, 0.94, 0.58, 1)
        _Intensity          ("Emission Intensity",          Float) = 3.2

        [Header(Wisp Flow)]
        _FlowSpeed          ("Flow Speed",                  Float) = 0.55
        _FlowScale          ("Flow Scale",                  Float) = 4.5
        _WispCount          ("Wisp Count Along Strand",     Float) = 5.0
        _WispSharpness      ("Wisp Sharpness",              Range(1, 8)) = 3.2
        _WispWidth          ("Wisp Width (across ribbon)",  Range(0.05, 1)) = 0.38
        _WarpStrength       ("Domain Warp",                 Range(0, 1)) = 0.42

        [Header(Optional Texture)]
        _DetailTex          ("Detail Noise (optional)",     2D) = "grey" {}
        _DetailStrength     ("Detail Strength",             Range(0, 1)) = 0.35
        _DetailScale        ("Detail Scale",                Float) = 3.0

        [Header(Sparkle Stars)]
        _StarDensity        ("Star Density",                Float) = 14.0
        _StarStrength       ("Star Strength",               Range(0, 4)) = 1.8
        _StarSpeed          ("Twinkle Speed",               Float) = 5.0

        [Header(Alpha and Rim)]
        _Opacity            ("Opacity",                     Range(0, 1)) = 0.58
        _TipFade            ("Tip Fade (UV.x)",             Range(0.01, 0.5)) = 0.14
        _EdgeFade           ("Edge Fade (UV.y)",            Range(0.01, 0.5)) = 0.24
        _FresnelPower       ("Edge Softness Power",         Range(0.5, 5)) = 2.6
        _FresnelStrength    ("Edge Softness Strength",      Range(0, 1)) = 0.55

        [Header(Life)]
        _BreathAmp          ("Breathing Pulse",             Range(0, 0.4)) = 0.08
        _BreathSpeed        ("Breath Speed",                Float) = 1.4
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
            Name "TopScorerGoldenWisp"
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

            TEXTURE2D(_DetailTex);
            SAMPLER(sampler_DetailTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _DeepGold;
                float4 _BodyGold;
                float4 _HotGold;
                float  _Intensity;

                float  _FlowSpeed;
                float  _FlowScale;
                float  _WispCount;
                float  _WispSharpness;
                float  _WispWidth;
                float  _WarpStrength;

                float4 _DetailTex_ST;
                float  _DetailStrength;
                float  _DetailScale;

                float  _StarDensity;
                float  _StarStrength;
                float  _StarSpeed;

                float  _Opacity;
                float  _TipFade;
                float  _EdgeFade;
                float  _FresnelPower;
                float  _FresnelStrength;

                float  _BreathAmp;
                float  _BreathSpeed;
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

            float Fbm(float2 p)
            {
                float v = 0.0;
                float a = 0.5;
                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    v += a * ValueNoise(p);
                    p = p * 2.04 + 13.7;
                    a *= 0.5;
                }
                return v;
            }

            float RidgedFbm(float2 p)
            {
                float v = 0.0;
                float a = 0.5;
                [unroll]
                for (int i = 0; i < 3; i++)
                {
                    float n = ValueNoise(p);
                    n = 1.0 - abs(n * 2.0 - 1.0);
                    v += n * n * a;
                    p = p * 2.08 + 7.3;
                    a *= 0.5;
                }
                return v;
            }

            float StrandMask(float x, float soft)
            {
                return smoothstep(0.0, soft, x) * smoothstep(1.0, 1.0 - soft, x);
            }

            float FourPointStar(float2 d, float size)
            {
                d = abs(d);
                float diag = (d.x + d.y) * 0.7071;
                float cross = max(d.x, d.y);
                float shape = lerp(cross, diag, 0.55);
                return exp(-shape * size);
            }

            float WorldStars(float3 posWS, float t)
            {
                float3 p = posWS * _StarDensity + _Seed * 0.173;
                float3 cell = floor(p);
                float3 f = frac(p);

                float h = Hash21(cell.xy + cell.z * 0.71);
                float gate = step(0.962, h);
                if (gate < 0.5)
                    return 0.0;

                float2 starPos = float2(Hash21(cell.xz + 2.3), Hash21(cell.yz + 5.9));
                float2 d = (f.xy - starPos) * 3.5;
                float twinkle = sin(t * _StarSpeed + h * 47.0) * 0.5 + 0.5;
                return FourPointStar(d, 22.0) * twinkle * gate;
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
                float t = _Time.y + _Seed * 2.83;

                float tipMask  = StrandMask(along, _TipFade);
                float edgeMask = StrandMask(across, _EdgeFade);

                // Soft Gaussian profile across ribbon width
                half widthDist = abs((half)across - 0.5h) * 2.0h;
                half widthProfile = exp(-widthDist * widthDist / max((half)_WispWidth, 0.01h));

                // Domain-warped advected flow along strand
                float2 flowUV = float2(along * _WispCount - t * _FlowSpeed, across * _FlowScale);
                float2 warp = float2(
                    Fbm(flowUV + float2(t * 0.11, _Seed)),
                    Fbm(flowUV + float2(5.2, t * 0.09 + _Seed * 0.5))
                );
                flowUV += (warp - 0.5) * _WarpStrength * 2.0;

                half wisps = (half)RidgedFbm(flowUV);
                wisps = pow(saturate(wisps), (half)_WispSharpness);

                // Secondary slower layer for depth
                half wisps2 = (half)RidgedFbm(flowUV * 1.7 + float2(_Seed, t * 0.04));
                wisps2 = pow(saturate(wisps2), (half)_WispSharpness * 0.8h);
                wisps = saturate(wisps * 0.72h + wisps2 * 0.38h);

                // Optional detail texture
                float2 detUV = uv * _DetailScale + float2(t * 0.08, -t * 0.05);
                half detail = SAMPLE_TEXTURE2D(_DetailTex, sampler_DetailTex, detUV).r;
                wisps = saturate(wisps * lerp(1.0h, detail * 1.4h + 0.3h, (half)_DetailStrength));

                // Combine wisp shape with width profile
                half energy = wisps * widthProfile;

                // View Fresnel — wisps fade softly at grazing angles
                half NdotV = saturate(dot(normalize((half3)IN.normalWS), normalize((half3)IN.viewDirWS)));
                half fresnel = pow(1.0h - NdotV, (half)_FresnelPower) * (half)_FresnelStrength;
                energy = saturate(energy + fresnel * wisps * 0.35h);

                // Four-point star sparkles
                half stars = (half)WorldStars(IN.posWS, t) * (half)_StarStrength;
                energy = saturate(energy + stars * widthProfile);

                // Gold color ramp: deep → body → hot
                half heat = saturate(wisps * 1.1h + stars * 0.5h);
                half3 col = lerp((half3)_DeepGold.rgb, (half3)_BodyGold.rgb, saturate(heat * 1.4h));
                col = lerp(col, (half3)_HotGold.rgb, saturate(heat * heat * 2.0h));
                col += (half3)_HotGold.rgb * stars * 0.6h;
                col += (half3)_HotGold.rgb * fresnel * wisps * 0.25h;

                half breath = 1.0h + (half)_BreathAmp * (half)sin(t * _BreathSpeed);
                col *= energy * (half)_Intensity * breath;

                half alpha = energy * (half)tipMask * (half)edgeMask * (half)_Opacity * (half)IN.color.a;
                alpha = saturate(alpha);

                return half4((float3)col, (float)alpha);
            }
            ENDHLSL
        }
    }
}
