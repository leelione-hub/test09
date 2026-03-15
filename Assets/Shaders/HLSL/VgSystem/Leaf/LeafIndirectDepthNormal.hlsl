#ifndef LEAFINDIRECT_DEPTHNORMAL_INCLUDE
#define LEAFINDIRECT_DEPTHNORMAL_INCLUDE
struct Attributes
{
    float3 positionOS : POSITION;
    float3 normal     : NORMAL;
    float2 uv         : TEXCOORD0;
    float4 color      : COLOR;
    uint instanceID : SV_InstanceID;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv         : TEXCOORD0;
};

Varyings vert (Attributes IN)
{
    WindStruct wind_data;
    wind_data.windSpeed = _WindSpeed;
    wind_data.vertexColor = IN.color;
    wind_data.leafStrength = _LeafStrength;
    wind_data.normalOS = IN.normal;
    wind_data.positionOS = IN.positionOS.xyz;
    wind_data.bendStrength = _BendStrength;
    wind_data.bendSpeed = _BendSpeed;
    wind_data.bendWait = _BendWait;
    wind_data.windDirection = _WindDirection.xy;
    wind_data.instanceID = IN.instanceID;
                
    half3 wind = PlantWind(wind_data);    

    IN.positionOS.xyz += wind;
    float3 worldPos = GetInstanceWorldPosition(IN.positionOS,IN.instanceID);
    Varyings OUT;
    OUT.positionCS = TransformWorldToHClip(worldPos);
    OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
    return OUT;
}

half4 frag (Varyings input) : SV_Target
{
    real4 finalColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
    clip(finalColor.a - _Cutoff);
    
}
#endif
