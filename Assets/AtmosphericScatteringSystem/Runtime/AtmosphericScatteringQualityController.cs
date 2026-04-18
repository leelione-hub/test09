using UnityEngine;
using UnityEngine.Rendering;

namespace AtmosphericScatteringSystem
{
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public sealed class AtmosphericScatteringQualityController : MonoBehaviour
    {
        [SerializeField] private Volume targetVolume;
        [SerializeField] private AtmosphereQualityMode quality = AtmosphereQualityMode.Auto;
        [SerializeField] private bool applyOnEnable = true;

        private void OnEnable()
        {
            if (applyOnEnable)
            {
                Apply();
            }
        }

        private void OnValidate()
        {
            if (applyOnEnable)
            {
                Apply();
            }
        }

        [ContextMenu("Apply Quality")]
        public void Apply()
        {
            if (targetVolume == null)
            {
                return;
            }

            VolumeProfile profile = targetVolume.profile != null ? targetVolume.profile : targetVolume.sharedProfile;
            if (profile == null)
            {
                return;
            }

            if (!profile.TryGet(out AtmosphericScatteringVolume component))
            {
                return;
            }

            component.quality.overrideState = true;
            component.quality.value = ResolveQuality();
        }

        private AtmosphereQualityMode ResolveQuality()
        {
            if (quality != AtmosphereQualityMode.Auto)
            {
                return quality;
            }

            return Application.isMobilePlatform ? AtmosphereQualityMode.Mobile : AtmosphereQualityMode.PC;
        }
    }
}
