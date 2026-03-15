#ifndef M_INPUT_SURFACE_EXT_INCLUDED
#define M_INPUT_SURFACE_EXT_INCLUDED

struct SurfaceDataExt
{
    half backBrightness;
    half shadowStrength;
};


struct BRDFDataExt
{
    half backBrightness;
    half shadowStrength;
};


struct SurfaceDataChar
{
    half4 charEnvColor;
    half3 scatterAmount;

    half shadowStrength;
    half giIntensityInShadow;
    half backBrightness;

    half tonemapping;
    half curvature;
    half ambientBrightness;

    #ifdef _MATCAP_ON
        half4 matCapColor;
        half matCapMask;
    #endif

    half envMultiplier;
};

struct BRDFDataChar
{
    half4 charEnvColor;
    half3 scatterAmount;
    half envMultiplier;
    half shadowStrength;
    half giIntensityInShadow;
    half backBrightness;

    half tonemapping;
    half curvature;
    half ambientBrightness;
};

void InitBRDFDataChar(in SurfaceDataChar surfaceData, out BRDFDataChar brdfData)
{
    brdfData.shadowStrength         = surfaceData.shadowStrength;
    brdfData.giIntensityInShadow    = surfaceData.giIntensityInShadow;
    brdfData.backBrightness         = surfaceData.backBrightness;
    brdfData.scatterAmount          = surfaceData.scatterAmount;
    brdfData.tonemapping            = surfaceData.tonemapping;
    brdfData.curvature              = surfaceData.curvature;
    brdfData.ambientBrightness      = surfaceData.ambientBrightness;
    brdfData.envMultiplier          = surfaceData.envMultiplier;
    brdfData.charEnvColor          = surfaceData.charEnvColor;
}
#endif