using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AtmosphericScatteringSystem
{
    public enum AtmosphereQualityMode
    {
        Auto,
        PC,
        Mobile
    }

    [Serializable]
    public sealed class AtmosphereQualityModeParameter : VolumeParameter<AtmosphereQualityMode>
    {
        public AtmosphereQualityModeParameter(AtmosphereQualityMode value, bool overrideState = false)
            : base(value, overrideState)
        {
        }
    }

    [Serializable]
    [VolumeComponentMenuForRenderPipeline("Custom/Atmospheric Scattering", typeof(UniversalRenderPipeline))]
    public sealed class AtmosphericScatteringVolume : VolumeComponent, IPostProcessComponent
    {
        [Header("General")]
        public BoolParameter enableEffect = new BoolParameter(false);
        public AtmosphereQualityModeParameter quality = new AtmosphereQualityModeParameter(AtmosphereQualityMode.Auto);
        public ClampedFloatParameter effectBlend = new ClampedFloatParameter(1f, 0f, 1f);

        [Header("Atmosphere")]
        public ColorParameter skyTint = new ColorParameter(new Color(0.33f, 0.50f, 0.78f, 1f), true, false, true);
        public ColorParameter horizonTint = new ColorParameter(new Color(0.95f, 0.62f, 0.42f, 1f), true, false, true);
        public ColorParameter fogTint = new ColorParameter(new Color(0.62f, 0.73f, 0.80f, 1f), true, false, true);
        public ClampedFloatParameter density = new ClampedFloatParameter(0.045f, 0.001f, 0.25f);
        public ClampedFloatParameter heightFalloff = new ClampedFloatParameter(0.045f, 0.001f, 0.2f);
        public FloatParameter heightOffset = new FloatParameter(0f);
        public FloatParameter fogStartDistance = new FloatParameter(0f);
        public ClampedFloatParameter maxDistance = new ClampedFloatParameter(350f, 25f, 2000f);
        public ClampedFloatParameter anisotropy = new ClampedFloatParameter(0.65f, 0f, 0.95f);
        public ClampedFloatParameter aerialPerspective = new ClampedFloatParameter(1f, 0f, 4f);

        [Header("Volumetric Light")]
        public ClampedFloatParameter shaftIntensity = new ClampedFloatParameter(1.25f, 0f, 5f);
        public ClampedFloatParameter shaftDecay = new ClampedFloatParameter(0.95f, 0.6f, 0.999f);
        public ClampedFloatParameter shaftJitter = new ClampedFloatParameter(0.35f, 0f, 1f);
        public ClampedFloatParameter shaftDistanceFade = new ClampedFloatParameter(1f, 0f, 4f);
        public ClampedFloatParameter sunHaloSize = new ClampedFloatParameter(0.18f, 0.01f, 0.6f);
        public ClampedFloatParameter sunHaloIntensity = new ClampedFloatParameter(0.65f, 0f, 5f);

        [Header("PC Quality")]
        public ClampedIntParameter pcRaymarchSteps = new ClampedIntParameter(48, 8, 128);
        public ClampedIntParameter pcShaftSamples = new ClampedIntParameter(20, 4, 64);
        public ClampedFloatParameter pcDownsample = new ClampedFloatParameter(1f, 0.5f, 1f);

        [Header("Mobile Quality")]
        public ClampedIntParameter mobileRaymarchSteps = new ClampedIntParameter(16, 4, 48);
        public ClampedIntParameter mobileShaftSamples = new ClampedIntParameter(8, 4, 24);
        public ClampedFloatParameter mobileDownsample = new ClampedFloatParameter(0.5f, 0.25f, 1f);

        public bool IsActive()
        {
            return enableEffect.value && effectBlend.value > 0f;
        }

        public bool IsTileCompatible()
        {
            return false;
        }

        public AtmosphereQualityMode GetResolvedQuality()
        {
            if (quality.value != AtmosphereQualityMode.Auto)
            {
                return quality.value;
            }

            return Application.isMobilePlatform ? AtmosphereQualityMode.Mobile : AtmosphereQualityMode.PC;
        }
    }
}
