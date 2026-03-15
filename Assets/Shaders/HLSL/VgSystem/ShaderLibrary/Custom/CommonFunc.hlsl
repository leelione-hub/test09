#ifndef M_COMMON_INCLUDED
#define M_COMMON_INCLUDED


float2 PolarCoordinates(float2 uv,float2 center = float2(0.5,0.5),float radialScale = 1,float lengthScale = 1)
{
    float2 centeredUV = uv - center;
    float x = length(centeredUV) * radialScale * 2;
    float y = atan2(centeredUV.x,centeredUV.y) * (1/TWO_PI) * lengthScale;

    return float2(x,y);
}

half3 unpackNormal(half r,half g,float scale)
{
    half __r = (r*2.0 + -1.0);
    half __g = (g*2.0 + -1.0);
    half2 __tempV2 = (half2(__r , __g));
    half3 final = half3(__tempV2 * scale , sqrt(saturate( 1.0 - (__r * __r + __g * __g ))));

    return final;
}


inline half2 ParallaxOffset(half h, half height, half3 viewDir)
{
    h = h * height - height/2.0;
    half3 v = normalize( viewDir );
    v.z += 0.42;
    return h* (v.xy / v.z);
}


half Fresnel(half3 normalWS,half3 normalizedViewDirWS ,half bias,half scale,half power)
{
    half fresnelNdotV36 = dot(normalWS, normalizedViewDirWS);
    half fresnelNode36 = ( bias + scale * pow( 1.0 - fresnelNdotV36, power ) );
    half temp_cast_0 = (fresnelNode36);
    return temp_cast_0;
}


float Remap(float inValue, float minold ,float maxOld, float minNew, float maxNew)
{
    return (minNew + (inValue - minold) * (maxNew - minNew) / (maxOld - minold));
}

half2 uvTillingOffset(half2 uv,half4 offset)
{
    return uv * offset.xy + offset.zw;
}



float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
float snoise( float2 v )
{
    const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
    float2 i = floor( v + dot( v, C.yy ) );
    float2 x0 = v - i + dot( i, C.xx );
    float2 i1;
    i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod2D289( i );
    float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
    float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
    m = m * m;
    m = m * m;
    float3 x = 2.0 * frac( p * C.www ) - 1.0;
    float3 h = abs( x ) - 0.5;
    float3 ox = floor( x + 0.5 );
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot( m, g );
}




float3 mod3D289( float3 x ) { return x - floor( x / 289.0 ) * 289.0; }
float4 mod3D289( float4 x ) { return x - floor( x / 289.0 ) * 289.0; }
float4 permute( float4 x ) { return mod3D289( ( x * 34.0 + 1.0 ) * x ); }
float4 taylorInvSqrt( float4 r ) { return 1.79284291400159 - r * 0.85373472095314; }
float snoise3D( float3 v )
{
    const float2 C = float2( 1.0 / 6.0, 1.0 / 3.0 );
    float3 i = floor( v + dot( v, C.yyy ) );
    float3 x0 = v - i + dot( i, C.xxx );
    float3 g = step( x0.yzx, x0.xyz );
    float3 l = 1.0 - g;
    float3 i1 = min( g.xyz, l.zxy );
    float3 i2 = max( g.xyz, l.zxy );
    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy;
    float3 x3 = x0 - 0.5;
    i = mod3D289( i);
    float4 p = permute( permute( permute( i.z + float4( 0.0, i1.z, i2.z, 1.0 ) ) + i.y + float4( 0.0, i1.y, i2.y, 1.0 ) ) + i.x + float4( 0.0, i1.x, i2.x, 1.0 ) );
    float4 j = p - 49.0 * floor( p / 49.0 );  // mod(p,7*7)
    float4 x_ = floor( j / 7.0 );
    float4 y_ = floor( j - 7.0 * x_ );  // mod(j,N)
    float4 x = ( x_ * 2.0 + 0.5 ) / 7.0 - 1.0;
    float4 y = ( y_ * 2.0 + 0.5 ) / 7.0 - 1.0;
    float4 h = 1.0 - abs( x ) - abs( y );
    float4 b0 = float4( x.xy, y.xy );
    float4 b1 = float4( x.zw, y.zw );
    float4 s0 = floor( b0 ) * 2.0 + 1.0;
    float4 s1 = floor( b1 ) * 2.0 + 1.0;
    float4 sh = -step( h, 0.0 );
    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    float3 g0 = float3( a0.xy, h.x );
    float3 g1 = float3( a0.zw, h.y );
    float3 g2 = float3( a1.xy, h.z );
    float3 g3 = float3( a1.zw, h.w );
    float4 norm = taylorInvSqrt( float4( dot( g0, g0 ), dot( g1, g1 ), dot( g2, g2 ), dot( g3, g3 ) ) );
    g0 *= norm.x;
    g1 *= norm.y;
    g2 *= norm.z;
    g3 *= norm.w;
    float4 m = max( 0.6 - float4( dot( x0, x0 ), dot( x1, x1 ), dot( x2, x2 ), dot( x3, x3 ) ), 0.0 );
    m = m* m;
    m = m* m;
    float4 px = float4( dot( x0, g0 ), dot( x1, g1 ), dot( x2, g2 ), dot( x3, g3 ) );
    return 42.0 * dot( m, px);
}



///////////////////////////////////////////////////////////////////////////////
//                               FAKE SSS                                    //
///////////////////////////////////////////////////////////////////////////////
///


half4 FakeSSS(float3 positionWS, float3 normalWS, half4 color,half mask, half SSSDistortion,half SSSPower ,half SSSScale,half4 SSSColor)
{
    half3 viewDir = GetWorldSpaceNormalizeViewDir(positionWS);
    float dotResult = dot(viewDir,-(_MainLightPosition.xyz + normalWS * SSSDistortion));
    float a = saturate(pow(max(dotResult * 0.5 + 0.5 , 0.0001),SSSPower) * SSSScale) * mask;

    return lerp(color, color * SSSColor,a);
}

///////////////////////////////////////////////////////////////////////////////
//                      Map Surface Data For Leaf/Shrub                      //
///////////////////////////////////////////////////////////////////////////////


struct MapSurfaceDataInput
{
    float2 UV;
    half4 BaseMapColor;
    half4 MixMapColor;
    half4 EmissionMapColor;
    half4 Tint;
    half Smoothness;
    half Metallic;
    half Opacity;
    half NormalIntensity;
    half NormalBackIntensity;
    half EmissionIntensity;
};
struct MapSurfaceDataOutput
{
    half3 BaseColor;
    float3 Normal;
    float3 NormalBack;
    half4 Emission;
    half Smoothness;
    half Metallic;
    half Alpha;
};


inline void func_MapSurfaceData(MapSurfaceDataInput input, out MapSurfaceDataOutput output)
{
    output.BaseColor = saturate(input.BaseMapColor.rgb * input.Tint.rgb);
    output.Alpha = lerp(input.Opacity,1,input.BaseMapColor.a);

    half4 appendNormal = half4(1.0,input.MixMapColor.g,0.0,input.MixMapColor.r);
    output.Normal = UnpackNormalScale(appendNormal,input.NormalIntensity);
    output.Normal.z = lerp( 1, output.Normal.z, saturate(input.NormalIntensity) );
    output.NormalBack = UnpackNormalScale(appendNormal,input.NormalBackIntensity);
    output.NormalBack.z = lerp( 1, output.NormalBack.z, saturate(input.NormalBackIntensity) );

    output.Smoothness = saturate(input.MixMapColor.b * input.Smoothness);
    output.Metallic = saturate(input.MixMapColor.a * input.Metallic);

    output.Emission = input.EmissionMapColor * input.EmissionIntensity;
}





///////////////////////////////////////////////////////////////////////////////
//                      Material Property Helpers                            //
///////////////////////////////////////////////////////////////////////////////
half Alpha(half albedoAlpha, half4 color, half cutoff)
{
#if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) && !defined(_GLOSSINESS_FROM_BASE_ALPHA)
    half alpha = albedoAlpha * color.a;
#else
    half alpha = color.a;
#endif

    alpha = AlphaDiscard(alpha, cutoff);

    return alpha;
}

half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
{
    return half4(SAMPLE_TEXTURE2D(albedoAlphaMap, sampler_albedoAlphaMap, uv));
}

half3 SampleNormal(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = half(1.0))
{
#ifdef _NORMALMAP
    half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(n);
    #else
        return UnpackNormalScale(n, scale);
    #endif
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half3 SampleEmission(float2 uv, half3 emissionColor, TEXTURE2D_PARAM(emissionMap, sampler_emissionMap))
{
    float3 _emission = SAMPLE_TEXTURE2D(emissionMap, sampler_emissionMap, uv).rgb * emissionColor;
    return _emission;
}





half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
        half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        return LerpWhiteTo(occ, _OcclusionStrength);
    #else
        return half(1.0);
    #endif
}


// Returns clear coat parameters
// .x/.r == mask
// .y/.g == smoothness
half2 SampleClearCoat(float2 uv)
{
#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half2 clearCoatMaskSmoothness = half2(_ClearCoatMask, _ClearCoatSmoothness);

#if defined(_CLEARCOATMAP)
    clearCoatMaskSmoothness *= SAMPLE_TEXTURE2D(_ClearCoatMap, sampler_ClearCoatMap, uv).rg;
#endif

    return clearCoatMaskSmoothness;
#else
    return half2(0.0, 1.0);
#endif  // _CLEARCOAT
}






// Used for scaling detail albedo. Main features:
// - Depending if detailAlbedo brightens or darkens, scale magnifies effect.
// - No effect is applied if detailAlbedo is 0.5.
half3 ScaleDetailAlbedo(half3 detailAlbedo, half scale)
{
    // detailAlbedo = detailAlbedo * 2.0h - 1.0h;
    // detailAlbedo *= _DetailAlbedoMapScale;
    // detailAlbedo = detailAlbedo * 0.5h + 0.5h;
    // return detailAlbedo * 2.0f;

    // A bit more optimized
    return half(2.0) * detailAlbedo * scale - scale + half(1.0);
}

half3 ApplyDetailAlbedo(float2 detailUv, half3 albedo, half detailMask)
{
#if defined(_DETAIL)
    half3 detailAlbedo = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUv).rgb;

    // In order to have same performance as builtin, we do scaling only if scale is not 1.0 (Scaled version has 6 additional instructions)
#if defined(_DETAIL_SCALED)
    detailAlbedo = ScaleDetailAlbedo(detailAlbedo, _DetailAlbedoMapScale);
#else
    detailAlbedo = half(2.0) * detailAlbedo;
#endif

    return albedo * LerpWhiteTo(detailAlbedo, detailMask);
#else
    return albedo;
#endif
}

half3 ApplyDetailNormal(float2 detailUv, half3 normalTS, half detailMask)
{
#if defined(_DETAIL)
#if BUMP_SCALE_NOT_SUPPORTED
    half3 detailNormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUv));
#else
    half3 detailNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUv), _DetailNormalMapScale);
#endif

    // With UNITY_NO_DXT5nm unpacked vector is not normalized for BlendNormalRNM
    // For visual consistancy we going to do in all cases
    detailNormalTS = normalize(detailNormalTS);

    return lerp(normalTS, BlendNormalRNM(normalTS, detailNormalTS), detailMask); // todo: detailMask should lerp the angle of the quaternion rotation, not the normals
#else
    return normalTS;
#endif
}


#endif