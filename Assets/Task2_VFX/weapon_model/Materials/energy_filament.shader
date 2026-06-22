Shader "Vertigo/URP/Energy Filament"
{
    /*
        Procedural golden energy filament shader — no textures, no vertex deformation.

        Designed for spcl_effectcurves.fbx ribbon meshes:
          UV.x = distance along strand (0 tip → 1 tip)
          UV.y = across ribbon width (0 edge → 1 edge)

        Visual model (different from wind_effect* shaders):
          - Hollow/edge-bright ribbon: soft centre, hot glowing edges
          - World-space plasma veins that drift through the mesh
          - Traveling light pulses along each strand
          - Hexagonal micro-facet shimmer (soccer motif)
          - Procedural star twinkles in world space
          - View-dependent aura shell
    */

    Properties
    {
        [Header(Colors)]
        _FilamentColor      ("Filament Body",               Color) = (1.0, 0.62, 0.08, 1)
        _EdgeHotColor       ("Edge Hot",                    Color) = (1.0, 0.92, 0.55, 1)
        _AuraColor          ("Aura Tint",                   Color) = (1.0, 0.78, 0.22, 1)
        _Intensity          ("Emission Intensity",          Float) = 2.5

        [Header(Strand Shape)]
        _Opacity            ("Opacity",                     Range(0, 1))    = 0.65
        _EdgePower          ("Edge Brightness Power",       Range(0.5, 4))  = 1.8
        _CenterDim          ("Centre Dim",                  Range(0, 1))    = 0.55
        _TipFade            ("Tip Fade Softness",           Range(0.01, 0.5)) = 0.12
        _WidthFade          ("Width Fade Softness",         Range(0.01, 0.5)) = 0.22

        [Header(Plasma Veins)]
        _WorldScale         ("World Vein Scale",            Float) = 1.6
        _StrandFreq         ("Strand Vein Frequency",       Float) = 5.0
        _FlowSpeed          ("Flow Speed",                  Float) = 0.45
        _VeinSharpness      ("Vein Sharpness",              Range(1, 12)) = 4.5
        _VeinStrength       ("Vein Strength",               Range(0, 2))  = 1.1

        [Header(Traveling Pulse)]
        _PulseFreq          ("Pulse Count Along Strand",    Float) = 3.5
        _PulseTravel        ("Pulse Travel Speed",          Float) = 2.2
        _PulseSharpness     ("Pulse Sharpness",             Range(1, 8))  = 3.0
        _PulseStrength      ("Pulse Strength",              Range(0, 2))  = 0.85

        [Header(Hex Shimmer)]
        _HexScale           ("Hex Cell Scale",              Float) = 18.0
        _HexStrength        ("Hex Shimmer Strength",        Range(0, 1)) = 0.22
        _HexSpeed           ("Hex Shimmer Speed",           Float) = 0.6

        [Header(Star Twinkle)]
        _StarDensity        ("Star Density",                Float) = 12.0
        _StarStrength       ("Star Strength",               Range(0, 3)) = 1.4
        _StarSpeed          ("Twinkle Speed",               Float) = 4.0

        [Header(View Aura)]
        _AuraPower          ("Aura Fresnel Power",          Range(0.5, 6)) = 2.4
        _AuraStrength       ("Aura Strength",               Range(0, 2))  = 0.9

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
            Name "EnergyFilament"
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
                float4 _FilamentColor;
                float4 _EdgeHotColor;
                float4 _AuraColor;
                float  _Intensity;

                float  _Opacity;
                float  _EdgePower;
                float  _CenterDim;
                float  _TipFade;
                float  _WidthFade;

                float  _WorldScale;
                float  _StrandFreq;
                float  _FlowSpeed;
                float  _VeinSharpness;
                float  _VeinStrength;

                float  _PulseFreq;
                float  _PulseTravel;
                float  _PulseSharpness;
                float  _PulseStrength;

                float  _HexScale;
                float  _HexStrength;
                float  _HexSpeed;

                float  _StarDensity;
                float  _StarStrength;
                float  _StarSpeed;

                float  _AuraPower;
                float  _AuraStrength;

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
                float value = 0.0;
                float amp = 0.5;
                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    value += amp * ValueNoise(p);
                    p = p * 2.03 + 17.0;
                    amp *= 0.5;
                }
                return value;
            }

            float StrandFade(float x, float soft)
            {
                return smoothstep(0.0, soft, x) * smoothstep(1.0, 1.0 - soft, x);
            }

            float HexShimmer(float2 uv, float t)
            {
                float2 p = uv * _HexScale;
                float2 hex = float2(p.x + floor(p.y) * 0.57735027, p.y * 1.1547005);
                float2 cell = floor(hex);
                float2 f = frac(hex);

                float2 r1 = float2(Hash21(cell), Hash21(cell + 19.7));
                float2 r2 = float2(Hash21(cell + 47.3), Hash21(cell + 91.1));
                float d1 = length(f - r1);
                float d2 = length(f - r2 + 0.5);

                float cellId = Hash21(cell + _Seed);
                float blink = sin(t * _HexSpeed + cellId * 12.9898) * 0.5 + 0.5;
                float hexLine = exp(-min(d1, d2) * 9.0);
                return hexLine * blink * step(0.55, cellId);
            }

            float StarTwinkle(float3 posWS, float t)
            {
                float3 p = posWS * _StarDensity + _Seed * 0.137;
                float3 cell = floor(p);
                float3 f = frac(p);

                float h = Hash21(cell.xy + cell.z);
                float2 starPos = float2(Hash21(cell.xz + 3.1), Hash21(cell.yz + 7.7));
                float dist = length(f.xy - starPos);

                float gate = step(0.965, h);
                float twinkle = sin(t * _StarSpeed + h * 40.0) * 0.5 + 0.5;
                float star = exp(-dist * 28.0) * twinkle * gate;
                return star;
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
                float across = abs(uv.y - 0.5) * 2.0;          // 0 centre, 1 edges

                float tipMask = StrandFade(along, _TipFade);
                float widthMask = StrandFade(uv.y, _WidthFade);

                // Edge-bright hollow ribbon (opposite of hot-centre wind shaders)
                half edgeGlow = pow(saturate(across), (half)_EdgePower);
                half centreSoft = 1.0h - (half)_CenterDim * (1.0h - edgeGlow);
                half strandShape = saturate(centreSoft * 0.35h + edgeGlow * 0.85h);

                // World-space plasma veins
                float t = _Time.y + _Seed * 3.17;
                float2 worldSlice = float2(
                    dot(IN.posWS.xz, float2(0.71, 0.42)),
                    dot(IN.posWS.yx, float2(0.33, 0.88))
                ) * _WorldScale;
                float2 veinUV = float2(along * _StrandFreq + t * _FlowSpeed, worldSlice.y + worldSlice.x * 0.35);
                half veinField = (half)Fbm(veinUV);
                half veins = pow(1.0h - abs(veinField - 0.5h) * 2.0h, (half)_VeinSharpness);
                veins *= (half)_VeinStrength;

                // Pulses travelling along the strand
                half pulse = pow(
                    (half)sin(along * _PulseFreq * 6.28318 - t * _PulseTravel) * 0.5h + 0.5h,
                    (half)_PulseSharpness
                );
                pulse *= (half)_PulseStrength;

                // Hex soccer shimmer + world stars
                half hex = (half)HexShimmer(uv + float2(t * 0.03, 0.0), t) * (half)_HexStrength;
                half stars = (half)StarTwinkle(IN.posWS, t) * (half)_StarStrength;

                // View aura shell
                half NdotV = saturate(dot(normalize((half3)IN.normalWS), normalize((half3)IN.viewDirWS)));
                half aura = pow(1.0h - NdotV, (half)_AuraPower) * (half)_AuraStrength;

                half energy = saturate(strandShape + veins * 0.55h + pulse * edgeGlow * 0.7h + aura * 0.45h);
                half3 col = lerp((half3)_FilamentColor.rgb, (half3)_EdgeHotColor.rgb, edgeGlow);
                col = lerp(col, (half3)_AuraColor.rgb, saturate(veins * 0.4h + pulse * 0.25h));
                col += (half3)_EdgeHotColor.rgb * (hex + stars) * edgeGlow;
                col += (half3)_AuraColor.rgb * aura * 0.35h;
                col *= energy * (half)_Intensity;

                half alpha = energy * (half)tipMask * (half)widthMask * (half)_Opacity * (half)IN.color.a;
                alpha = saturate(alpha);

                return half4((float3)col, (float)alpha);
            }
            ENDHLSL
        }
    }
}
