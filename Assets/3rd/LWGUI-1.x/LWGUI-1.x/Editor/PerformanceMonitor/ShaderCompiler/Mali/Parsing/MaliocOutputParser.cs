// Copyright (c) Jason Ma

using System;
using System.Linq;
using NUnit.Framework;
using Unity.Plastic.Newtonsoft.Json;

namespace LWGUI.PerformanceMonitor.ShaderCompiler.Mali
{
    public static class MaliocOutputParser
    {
        public static RuntimeMaliocShader Parse(string json)
        {
            if (json == null)
                return null;

            var jsonSerializerSettings = new JsonSerializerSettings
            {
                NullValueHandling = NullValueHandling.Ignore,
            };
            var jsonModel = JsonConvert.DeserializeObject<JsonMaliocOutput>(json, jsonSerializerSettings);
            
            Assert.IsNotNull(jsonModel);
            Assert.IsTrue(jsonModel.shaders.Length == 1);
            
            var shader = jsonModel.shaders[0];

            return new RuntimeMaliocShader
            {
                Properties = shader.properties.Select(ConvertProperty).ToList(),
                Variants = shader.variants.Select(variant =>
                    {
                        var pipelines = variant.performance.pipelines.Select(ParsePipelineType).ToList();
                        return new RuntimeMaliocShader.ShaderVariant
                        {
                            Name = variant.name,
                            Properties = variant.properties.Select(ConvertVariantProperty).ToList(),
                            Pipelines = pipelines,
                            LongestPathCycles =
                                ParseShaderPipelineCycles(variant.performance.longest_path_cycles),
                            ShortestPathCycles =
                                ParseShaderPipelineCycles(variant.performance.shortest_path_cycles),
                            TotalCycles = ParseShaderPipelineCycles(variant.performance.total_cycles),
                        };
                    }
                ).ToList(),
            };
        }

        private static RuntimeMaliocShader.ShaderProperty ConvertProperty(JsonMaliocOutput.ShaderProperty property) =>
            new() { Name = property.display_name, Value = new DynamicValue(property.value) };

        private static RuntimeMaliocShader.ShaderProperty
            ConvertVariantProperty(JsonMaliocOutput.ShaderProperty property) =>
            new()
            {
                Name = property.display_name, Value = new DynamicValue(property.value),
                ValueUnit = ParseValueUnit(property.name),
            };

        private static RuntimeMaliocShader.ShaderProperty.Unit ParseValueUnit(string name) =>
            name switch
            {
                "thread_occupancy" => RuntimeMaliocShader.ShaderProperty.Unit.Percent,
                "fp16_arithmetic" => RuntimeMaliocShader.ShaderProperty.Unit.Percent,
                var _ => RuntimeMaliocShader.ShaderProperty.Unit.None,
            };

        private static RuntimeMaliocShader.ShaderVariantPipelineType ParsePipelineType(string text) =>
            text switch
            {
                "arithmetic" => RuntimeMaliocShader.ShaderVariantPipelineType.Arithmetic,
                "load_store" => RuntimeMaliocShader.ShaderVariantPipelineType.LoadStore,
                "varying" => RuntimeMaliocShader.ShaderVariantPipelineType.Varying,
                "texture" => RuntimeMaliocShader.ShaderVariantPipelineType.Texture,
                null => RuntimeMaliocShader.ShaderVariantPipelineType.Null,
                var _ => throw new ArgumentOutOfRangeException(nameof(text), text, "Invalid pipeline type."),
            };

        private static RuntimeMaliocShader.ShaderPipelineCycles ParseShaderPipelineCycles(
            JsonMaliocOutput.ShaderVariantCycles cycles) =>
            new()
            {
                PipelineCycles = cycles.cycle_count.Select(f => f ?? 0).ToList(),
                BoundPipeline = ParsePipelineType(cycles.bound_pipelines.First()),
            };
    }
}