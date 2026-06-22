Shader "Vertigo/URP/Golden Wind Ribbon"
{
    Properties
    {
        _BaseColor       ("Base Color",         Color)         = (1, 0.72, 0.12, 1)
        _HotColor        ("Hot / Core Color",   Color)         = (1.0, 0.97, 0.72, 1)
        _EmissionIntensity ("Emission Intensity", Float)       = 5
        _MainTex         ("Noise / Streak Texture", 2D)        = "white" {}
        _FlowSpeed       ("Flow Speed",         Float)         = 1.2
        _FlowSpeed2      ("Flow Speed Layer 2", Float)         = 0.65
        _Tiling          ("Tiling Layer 1",     Vector)        = (3, 1, 0, 0)
        _Tiling2         ("Tiling Layer 2",     Vector)        = (1.5, 1.8, 0, 0)
        _Opacity         ("Opacity",            Range(0,1))    = 0.7
        _FresnelPower    ("Rim Glow Power",     Float)         = 1.8
        _FresnelStrength ("Rim Glow Strength",  Float)         = 0.6
        _AlphaCut        ("Alpha Soft Cut",     Range(0,1))    = 0.05
        _SparkleScale    ("Sparkle Scale",      Float)         = 6.0
        _SparkleSharpness("Sparkle Sharpness",  Float)         = 12.0
        _SparkleStrength ("Sparkle Strength",   Float)         = 2.5
        _EdgeFadeSoft    ("Edge Fade Softness", Range(0,0.5))  = 0.28
        _Pulse           ("Pulse Amplitude",    Range(0,1))    = 0.12
        _PulseSpeed      ("Pulse Speed",        Float)         = 2.0
        _RotationAngle   ("Rotation Angle (deg)", Float)        = 0.0
        _RotationSpeed   ("Rotation Speed (deg/s)", Float)      = 30.0
        [Space(8)]
        _Seed            ("Instance Seed",          Float)         = 0.0
        _TurbulenceStr   ("Turbulence Strength",    Range(0,0.3))  = 0.08
        _TurbulenceScale ("Turbulence Scale",       Float)         = 1.5
        _TurbulenceSpeed ("Turbulence Speed",       Float)         = 0.3
        _FlickerStrength ("Flicker Strength",       Range(0,1))    = 0.25
        _FlickerSpeed    ("Flicker Speed",          Float)         = 8.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Pass
        {
            Name "GoldenWindRibbon"

            Blend SrcAlpha One      // additive — ribbons brighten whatever is behind
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
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
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 viewDirWS   : TEXCOORD2;
                float  fadeMask    : TEXCOORD3;   // edgeFade * endFade, baked in vertex
                float4 color       : COLOR;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _HotColor;
                float4 _MainTex_ST;
                float4 _Tiling;
                float4 _Tiling2;
                float  _EmissionIntensity;
                float  _FlowSpeed;
                float  _FlowSpeed2;
                float  _Opacity;
                float  _FresnelPower;
                float  _FresnelStrength;
                float  _AlphaCut;
                float  _SparkleScale;
                float  _SparkleSharpness;
                float  _SparkleStrength;
                float  _EdgeFadeSoft;
                float  _Pulse;
                float  _PulseSpeed;
                float  _RotationAngle;
                float  _RotationSpeed;
                float  _Seed;
                float  _TurbulenceStr;
                float  _TurbulenceScale;
                float  _TurbulenceSpeed;
                float  _FlickerStrength;
                float  _FlickerSpeed;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs   = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   normalInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = posInputs.positionCS;
                // Skip normalize here — we re-normalize in fragment after interpolation anyway
                OUT.normalWS    = normalInputs.normalWS;
                OUT.viewDirWS   = GetWorldSpaceViewDir(posInputs.positionWS);
                OUT.uv          = IN.uv;
                OUT.color       = IN.color;

                // Bake UV-only fades in vertex: identical result, saves ~6 ALU ops per pixel
                float edgeFade  = smoothstep(0.0, _EdgeFadeSoft, IN.uv.y) *
                                  smoothstep(1.0, 1.0 - _EdgeFadeSoft, IN.uv.y);
                float endFade   = smoothstep(0.0, 0.10, IN.uv.x) *
                                  smoothstep(1.0, 0.90, IN.uv.x);
                OUT.fadeMask    = edgeFade * endFade;

                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // Pre-compute shared time offsets (uniform math, compiled to constants)
                float t1 = _Time.y * _FlowSpeed;
                float t2 = _Time.y * _FlowSpeed2;

                // ── UV rotation (around center 0.5,0.5) ──────────────────────────
                float  angle    = (_RotationAngle + _Time.y * _RotationSpeed) * (3.14159265h / 180.0h);
                float  cosA     = cos(angle);
                float  sinA     = sin(angle);
                float2 uvC      = IN.uv - 0.5;
                float2 uvRot    = float2(uvC.x * cosA - uvC.y * sinA,
                                         uvC.x * sinA + uvC.y * cosA) + 0.5;

                // ── Per-instance seed phase shift ─────────────────────────────────
                // Offset UVs by a unique value per material instance so ribbons
                // sharing the same texture never look identical.
                float2 seedOff  = float2(_Seed * 0.3731, _Seed * 0.1547);

                // ── UV turbulence (organic warp) ──────────────────────────────────
                // One extra sample at low scale bends the streaks so they twist and
                // wriggle rather than scroll in a straight line.
                float2 turbUV   = uvRot * _TurbulenceScale
                                + float2(t1 * _TurbulenceSpeed + seedOff.x, seedOff.y);
                half   tv       = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, turbUV).r;
                // Derive independent x/y warp from a single channel using a 2π phase shift
                float2 turbOff  = float2((half)tv - 0.5h,
                                         sin((half)tv * 6.28318h) * 0.5h) * _TurbulenceStr;
                // Final distorted UV: rotation + turbulence warp + seed region offset
                float2 uvD      = uvRot + turbOff + seedOff * 0.05;

                // ── Streak layer 1 ────────────────────────────────────────────────
                half streak1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                float2(uvD.x * _Tiling.x + t1,
                                       uvD.y * _Tiling.y)).r;

                // ── Streak layer 2 ────────────────────────────────────────────────
                half streak2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                float2(uvD.x * _Tiling2.x + t2,
                                       uvD.y * _Tiling2.y)).r;

                // Screen blend: bright in either layer → bright result.
                // Multiply (old) failed with hard BW textures because 0×anything=0,
                // making ~75% of the surface invisible. Screen never darkens below either input.
                half streaks = 1.0h - (1.0h - streak1) * (1.0h - streak2);
                streaks = saturate(streaks * 1.2h - 0.05h);

                // ── Fresnel / rim glow ────────────────────────────────────────────
                half NdotV   = saturate(dot(normalize(half3(IN.normalWS)),
                                           normalize(half3(IN.viewDirWS))));
                half fresnel = pow(1.0h - NdotV, (half)_FresnelPower) * (half)_FresnelStrength;

                // ── Sparkle glints (single sample, saves one texture fetch) ───────
                half sparkNoise = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                   float2(uvD.x * _SparkleScale + t1 * 1.4h,
                                          uvD.y * _SparkleScale)).r;
                half sparkle    = pow(sparkNoise, (half)_SparkleSharpness) *
                                  (half)_SparkleStrength * (half)IN.fadeMask;

                // ── Pulse ─────────────────────────────────────────────────────────
                half pulse = 1.0h + (half)_Pulse * (half)sin(_Time.y * _PulseSpeed);

                // ── Random flicker ────────────────────────────────────────────────
                // Hash on a quantised time step so flicker snaps rather than drifts;
                // seed shifts the hash domain so each instance flickers independently.
                half flicker = 1.0h - (half)_FlickerStrength *
                               (half)frac(sin((floor(_Time.y * _FlickerSpeed) + _Seed) * 127.1)
                                          * 43758.5453);

                // ── Color ramp : dark gold → base gold → hot white-gold ───────────
                half heat  = saturate(streaks + fresnel * 0.4h);
                half3 col  = lerp((half3)_BaseColor.rgb * 0.35h,
                                  (half3)_BaseColor.rgb, saturate(heat * 1.6h));
                col         = lerp(col, (half3)_HotColor.rgb,
                                   saturate(heat * heat * 2.5h - 0.4h));
                col        += (half3)_HotColor.rgb * sparkle;
                col        *= (half)_EmissionIntensity * pulse * flicker;

                // ── Alpha ─────────────────────────────────────────────────────────
                half alpha  = smoothstep((half)_AlphaCut, 1.0h,
                                         streaks + fresnel * 0.25h);
                alpha      *= (half)IN.fadeMask * (half)_Opacity * (half)IN.color.a;

                return half4(col, alpha);
            }
            ENDHLSL
        }
    }
}