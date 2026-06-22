Shader "Vertigo/URP/Top Scorer Emissive Core"
{
    /*
        Central glowing soccer-ball core for CX Top Scorer weapon skin.

        Designed for a sphere mesh at the weapon centre:
          - Radial white-yellow → orange gradient
          - Strong emissive bloom output
          - Subtle inner fire pulse
          - Hexagonal wireframe shimmer (soccer motif)
          - View Fresnel halo shell
          - Hot core centre shifts inside the sphere along a selectable axis
          - Inner fire and hex scroll on an independent flow axis
          - Mesh stays fixed — only the inner glow moves

        Opaque additive-style glow on transparent queue for bloom pickup.
    */

    Properties
    {
        [Header(Colors)]
        _CoreWhite          ("Core White",                  Color) = (1.0, 0.98, 0.82, 1)
        _CoreYellow         ("Core Yellow",                 Color) = (1.0, 0.88, 0.18, 1)
        _CoreOrange         ("Core Orange Edge",            Color) = (1.0, 0.55, 0.05, 1)
        _HaloColor          ("Outer Halo",                  Color) = (1.0, 0.75, 0.15, 1)
        _Intensity          ("Emission Intensity",          Float) = 8.0

        [Header(Shape)]
        _CoreTightness      ("Core Tightness",              Range(0.5, 4)) = 1.8
        _HaloPower          ("Halo Fresnel Power",          Range(0.5, 6)) = 2.2
        _HaloStrength       ("Halo Strength",               Range(0, 2)) = 1.1

        [Header(Hex Soccer Pattern)]
        _HexScale           ("Hex Scale",                   Float) = 12.0
        _HexStrength        ("Hex Line Strength",           Range(0, 1)) = 0.28
        _HexSpeed           ("Hex Shimmer Speed",           Float) = 0.8

        [Header(Core Motion)]
        [Enum(Object X, 0, Object Y, 1, Object Z, 2, World X, 3, World Y, 4, World Z, 5)]
                            _MoveAxis           ("Core Move Axis",              Float) = 1
        _MoveSpeed          ("Core Move Speed",             Float) = 1.2
        _MoveAmount         ("Core Travel",                 Range(0, 0.45)) = 0.12

        [Header(Inner Flow)]
        [Enum(Object X, 0, Object Y, 1, Object Z, 2, World X, 3, World Y, 4, World Z, 5)]
                            _FlowAxis           ("Flow Axis",                   Float) = 1
        _FlowSpeed          ("Flow Speed",                  Float) = 0.6

        [Header(Life)]
        _PulseAmp           ("Pulse Amplitude",             Range(0, 0.5)) = 0.12
        _PulseSpeed         ("Pulse Speed",                 Float) = 2.0
        _InnerFire          ("Inner Fire Strength",         Range(0, 1)) = 0.35
        _Seed               ("Seed",                        Float) = 0.0
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
            Name "TopScorerEmissiveCore"
            Blend SrcAlpha One
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 posCS     : SV_POSITION;
                float3 normalWS  : TEXCOORD0;
                float3 viewDirWS : TEXCOORD1;
                float3 posWS     : TEXCOORD2;
                float3 posOS     : TEXCOORD3;
                float2 uv        : TEXCOORD4;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _CoreWhite;
                float4 _CoreYellow;
                float4 _CoreOrange;
                float4 _HaloColor;
                float  _Intensity;

                float  _CoreTightness;
                float  _HaloPower;
                float  _HaloStrength;

                float  _HexScale;
                float  _HexStrength;
                float  _HexSpeed;

                float  _MoveAxis;
                float  _MoveSpeed;
                float  _MoveAmount;

                float  _FlowAxis;
                float  _FlowSpeed;

                float  _PulseAmp;
                float  _PulseSpeed;
                float  _InnerFire;
                float  _Seed;
            CBUFFER_END

            float3 MoveAxisVector(float axis)
            {
                int a = (int)axis;
                if (a == 0) return float3(1.0, 0.0, 0.0);
                if (a == 1) return float3(0.0, 1.0, 0.0);
                if (a == 2) return float3(0.0, 0.0, 1.0);
                if (a == 3) return float3(1.0, 0.0, 0.0);
                if (a == 4) return float3(0.0, 1.0, 0.0);
                return float3(0.0, 0.0, 1.0);
            }

            bool IsWorldAxis(float axis)
            {
                return axis >= 2.5;
            }

            float3 CoreOffsetOS(float axis, float phase, float amount)
            {
                float3 dir = MoveAxisVector(axis);
                float3 offset = dir * sin(phase) * amount;
                if (IsWorldAxis(axis))
                    offset = mul((float3x3)GetWorldToObjectMatrix(), offset);
                return offset;
            }

            float3 AxisDirOS(float axis)
            {
                float3 dir = MoveAxisVector(axis);
                if (IsWorldAxis(axis))
                    dir = mul((float3x3)GetWorldToObjectMatrix(), dir);
                return dir;
            }

            float AxisCoord(float3 posOS, float3 posWS, float axis)
            {
                if (IsWorldAxis(axis))
                    return dot(posWS, MoveAxisVector(axis));
                return dot(posOS, MoveAxisVector(axis));
            }

            float Hash21(float2 p)
            {
                p = frac(p * float2(127.1, 311.7));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float HexLines(float2 uv, float t)
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
                float hexLine = exp(-min(d1, d2) * 10.0);
                return hexLine * blink;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vpi = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   vni = GetVertexNormalInputs(IN.normalOS);

                OUT.posCS     = vpi.positionCS;
                OUT.normalWS  = vni.normalWS;
                OUT.viewDirWS = GetWorldSpaceViewDir(vpi.positionWS);
                OUT.posWS     = vpi.positionWS;
                OUT.posOS     = IN.positionOS.xyz;
                OUT.uv        = IN.uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float t = _Time.y + _Seed;
                float phase = t * _MoveSpeed;

                float3 coreCenter = CoreOffsetOS(_MoveAxis, phase, _MoveAmount);
                float distToCore = length(IN.posOS - coreCenter);

                // Hot core — radial falloff from the animated inner centre (object space)
                half coreRadial = pow(saturate(1.0h - distToCore * 2.15h), (half)_CoreTightness);

                half NdotV = saturate(dot(normalize((half3)IN.normalWS), normalize((half3)IN.viewDirWS)));

                // Inner fire flicker — scrolls along its own selectable axis
                float3 flowDirOS = AxisDirOS(_FlowAxis);
                float flowCoord = AxisCoord(IN.posOS, IN.posWS, _FlowAxis) - t * _FlowSpeed;
                half fire = (half)sin(flowCoord * 8.0 + t * 3.5) * 0.5h + 0.5h;
                fire *= (half)sin(flowCoord * 5.5 - t * 2.8 + _Seed) * 0.5h + 0.5h;
                coreRadial = saturate(coreRadial + fire * (half)_InnerFire * (1.0h - distToCore * 1.5h));

                // Fresnel halo shell — stays on the sphere surface
                half halo = pow(1.0h - NdotV, (half)_HaloPower) * (half)_HaloStrength;

                // Hex soccer wireframe shimmer — scrolls along flow axis
                float2 hexUV = IN.uv + flowDirOS.xy * flowCoord * 0.08 + flowDirOS.yz * flowCoord * 0.05;
                half hex = (half)HexLines(hexUV, t) * (half)_HexStrength;

                // Color ramp: orange edge → yellow → white hot centre
                half3 col = lerp((half3)_CoreOrange.rgb, (half3)_CoreYellow.rgb, saturate(coreRadial * 1.6h));
                col = lerp(col, (half3)_CoreWhite.rgb, saturate(coreRadial * coreRadial * 2.5h));
                col = lerp(col, (half3)_HaloColor.rgb, saturate(halo * 0.65h));
                col += (half3)_CoreWhite.rgb * hex * coreRadial;

                half pulse = 1.0h + (half)_PulseAmp * (half)sin(t * _PulseSpeed);
                half energy = saturate(coreRadial + halo * 0.7h + hex * 0.4h);
                col *= energy * (half)_Intensity * pulse;

                half alpha = saturate(energy * 0.85h + halo * 0.35h);

                return half4((float3)col, (float)alpha);
            }
            ENDHLSL
        }
    }
}
