//Properties
sampler2D _DensityLUT;
sampler2D _ScatteringLUT;
float _SampleRadiusScale;
float4 _DensityLUTSize;
float4 _ScatteringLUTSize;
float _ParticleDensity;
float _AttenuationCoff;
float _EarthRadius;
float2 _LightAttenuation;
float2 _CloudAmbientParams;

//---------------------------------
//Define
#define PI 3.141592653
#define PI2 6.283185306
#define PIHalf 1.5707963265

#define NUM_INTEGRATION_STEPS 20
#define NUM_ZENITH_STEPS 20
#define NUM_AZIMUTH_STEPS 20
//---------------------------------

inline float Atan2Abs(float fy,float fx)
{
    float oR = atan2(fy,fx);
    oR = oR * step(0, oR) + step(oR, 0) * (PI2 + oR);
    return oR;
}

inline int GetRaySphereIntersection(float3 f3ro, float3 f3rd, float3 f3center, float fRadius, out float2 f2RayIsecs)
{
    float3 f3BiDir= f3ro - f3center;
    float A = dot(f3rd,f3rd);
    float B = dot(f3BiDir,f3rd) * 2;
    float C = dot(f3BiDir,f3BiDir) - fRadius * fRadius;
    float D = B * B - 4 * A * C;

    if(D < 0)
    {
        return 0;
    }
    else
    {
        D = sqrt(D);
        f2RayIsecs = float2(-B - D , -B + D) / (2 * A);
        return 1;
    }
}

inline float2 F4ToF2(float4 coord, uint4 size)
{
    float2 res;
    res.x = coord.x + size.x * coord.y;
    res.y = coord.z + size.z * coord.w;
    return res/float2(size.x * size.y, size.z * size.w);
}

inline void WorldToOpitcalLUTParams(float3 f3StartPosUSSpace, float3 f3ViewDirUSSpace ,out float4 f4Coord)
{
    f4Coord = float4(0,0,0,0);
    f4Coord.y = acos(f3StartPosUSSpace.y);
    f4Coord.x = Atan2Abs(f3StartPosUSSpace.z, f3StartPosUSSpace.x);
    f4Coord.w = acos(f3ViewDirUSSpace.y);
    f4Coord.z = Atan2Abs(f3ViewDirUSSpace.z, f3ViewDirUSSpace.x);
    f4Coord /= float4(PI2,PI,PI2,PI);
    f4Coord *= _DensityLUTSize;
}

inline void WorldToSctrLUTParams(float3 f3StartPosUSSpace, float3 f3ViewDirUSSpace ,out float4 f4Coord)
{
    f4Coord = float4(0,0,0,0);
    f4Coord.w = length(f3StartPosUSSpace.xz);
    f4Coord.x = Atan2Abs(f3StartPosUSSpace.z, f3StartPosUSSpace.x);
    f4Coord.x = (PI2 - f4Coord.x) * step(PI, f4Coord.x) + step(f4Coord.x, PI) * f4Coord.x;
    f4Coord.y = acos(f3ViewDirUSSpace.y);
    f4Coord.z = Atan2Abs(f3ViewDirUSSpace.x, f3ViewDirUSSpace.z);
    f4Coord /= float4(PI, PI, PI2, 1);
    f4Coord *= _ScatteringLUTSize;
}

inline void SampleDensity(float3 f3SampleEntryUSSpace, float3 f3ViewDirUSSpace, out float fNormalDensity)
{
    fNormalDensity = 1.f;
    f3SampleEntryUSSpace /= _SampleRadiusScale;
    float4 f4Coord;
    WorldToOpitcalLUTParams(f3SampleEntryUSSpace, f3ViewDirUSSpace, f4Coord);
    float2 uv =F4ToF2(f4Coord, _DensityLUTSize);
    fNormalDensity = tex2Dlod(_DensityLUT, float4(uv,0,0)).r;
    //return step(,f3SampleEntryUSSpace.y);
}

inline void SampleSctr(float3 f3SampleEntryUSSpace, float3 f3ViewDirUSSpace, out float fMultiScattering)
{
    fMultiScattering = 1.f;
    f3SampleEntryUSSpace /= _SampleRadiusScale;
    float4 f4Coord;
    WorldToSctrLUTParams(f3SampleEntryUSSpace, f3ViewDirUSSpace, f4Coord);
    fMultiScattering = tex2Dlod(_ScatteringLUT, half4(F4ToF2(f4Coord, _ScatteringLUTSize),0,0)).r;
}

inline float HGPhase(float dotTheta, float g)
{
    float fTopPart  = 1 - g * g;
    float fBottomPart = 2 * PI2 * pow(abs(1 + g * g - 2 * g * dotTheta), 1.5);
    return fTopPart / fBottomPart;
}

fixed4 BlendParticalRender(float fNormalDensity, float fMultiSctr, float fRayLenth, float fDotWithLight, float3 lightCol, float3 AmbientCol, float3 f3SampleEntryUSSpace)
{
    float fCloudMass = fNormalDensity * fRayLenth;
    fCloudMass *= _ParticleDensity;

    float fTransparency = exp( -fCloudMass * _AttenuationCoff);

    float phaseFunc = HGPhase(fDotWithLight , 0.8);
    float3 f3SingleScattering = fTransparency * lightCol * _LightAttenuation.x * phaseFunc;

    float3 f3MultiScattering =  (1 - fTransparency) * fMultiSctr * _LightAttenuation.y * lightCol;

    //Compute ambient light 
    float3 f3EarthCentre = float3(0, -_EarthRadius, 0);
    float fEntryPointAltitude = length(f3SampleEntryUSSpace - f3EarthCentre);
    float fCloudBottomBoundary = _EarthRadius + _CloudAmbientParams.x - _CloudAmbientParams.y / 2.0;
    float fAmbientStrength = (fEntryPointAltitude - fCloudBottomBoundary) / _CloudAmbientParams.y;
    fAmbientStrength =clamp(fAmbientStrength , 0.3 , 1);
    float3 f3Ambient = (1 - fTransparency) * fAmbientStrength * AmbientCol;
    return fixed4(f3SingleScattering + f3MultiScattering + f3Ambient , 1-fTransparency);
}