// Copyright (c) Jason Ma

using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using LWGUI.PerformanceMonitor;
using UnityEditor;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace LWGUI
{
    public static class IOHelper
    {
        #region Paths

        private static string _cachedProjectPath;

        // D:/Unity/ProjectName/
        public static string ProjectPath
        {
            get
            {
                if (string.IsNullOrEmpty(_cachedProjectPath))
                    _cachedProjectPath = Application.dataPath[..^6];
                return _cachedProjectPath;
            }
        }

        public static string GetAbsPath(string unityProjectRelativePath) => Path.Combine(ProjectPath, unityProjectRelativePath);
        
        public static string GetRelativePath(string absPath) => Path.GetFullPath(absPath).Replace(Path.GetFullPath(ProjectPath), string.Empty);

        private static string _cachedCompiledShaderCachePath;

        public static string CompiledShaderCacheRootPath
        {
            get
            {
                if (string.IsNullOrEmpty(_cachedCompiledShaderCachePath))
                    _cachedCompiledShaderCachePath = Path.Combine(ProjectPath, "Library", "LWGUI", "ShaderPerfCache");
                return _cachedCompiledShaderCachePath;
            }
        }

        public static string GetValidFileName(string text)
        {
            StringBuilder str = new StringBuilder();
            var invalidFileNameChars = Path.GetInvalidFileNameChars();
            foreach (var c in text)
            {
                if (!invalidFileNameChars.Contains(c))
                {
                    str.Append(c);
                }
            }

            return str.ToString();
        }

        #endregion

        #region File

        public static bool ExistAndNotEmpty(string filePath) => File.Exists(filePath) && new FileInfo(filePath).Length > 1;

        public static void WriteBinaryFile(string filePath, byte[] bytes)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(filePath) ?? string.Empty);
                File.WriteAllBytes(filePath, bytes ?? Array.Empty<byte>());
            }
            catch (Exception e)
            {
                Debug.LogError(e.Message);
            }
        }

        public static void WriteTextFile(string filePath, string text)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(filePath) ?? string.Empty);
                File.WriteAllText(filePath, text ?? string.Empty, Encoding.UTF8);
            }
            catch (Exception e)
            {
                Debug.LogError(e.Message);
            }
        }

        public static string ReadTextFile(string filePath)
        {
            try
            {
                return File.ReadAllText(filePath, Encoding.UTF8);
            }
            catch (Exception e)
            {
                Debug.LogError(e.Message);
                return null;
            }
        }

        #endregion

        #region Process

        public static bool RunProcess(string     file, string args,
                                      out string output)
        {
            output = string.Empty;

            var p = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = file,
                    Arguments = args,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                }
            };

            var stdout = new StringBuilder();
            var stderr = new StringBuilder();

            p.OutputDataReceived += (_, e) => stdout.AppendLine(e.Data);
            p.ErrorDataReceived += (_,  e) => stderr.AppendLine(e.Data);

            p.Start();
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();
            p.WaitForExit();

            output = stdout.ToString();

            if (p.ExitCode != 0)
            {
                Debug.LogError($"LWGUI: Process Exit Code {p.ExitCode}: {stderr}" +
                               $"File: {file}\n" +
                               $"Args: {args}");
                output = stderr.ToString();
                return false;
            }

            if (string.IsNullOrWhiteSpace(output))
            {
                output = stderr.ToString();
                return false;
            }

            return true;
        }

        public static bool RunCMD(string     args,
                                  out string output)
        {
            return RunProcess("cmd.exe", $"/C {args}",
                out output);
        }

        public static void OpenFile(string filePath)
        {
            Process.Start(filePath);
        }

        #endregion

        #region Performance Monitor

        public static string GetCompiledShaderCacheRootDirectory(Shader shader)
        {
            var shaderPath = AssetDatabase.Contains(shader) ? AssetDatabase.GetAssetPath(shader) : null;
            var shaderCachePath = shaderPath != null
                // Assets/Shaders/Lit.shader => Shaders/Lit
                ? Path.Combine(Path.GetDirectoryName(shaderPath[7..]) ?? string.Empty, Path.GetFileNameWithoutExtension(shaderPath))
                : GetValidFileName(shader.name.Replace('/', '_').Replace('\\', '_'));

            return Path.Combine(CompiledShaderCacheRootPath, shaderCachePath);
        }

        public static string GetCompiledShaderVariantCacheDirectory(Shader shader, ShaderPerfData shaderPerfData)
        {
            return Path.Combine(
                GetCompiledShaderCacheRootDirectory(shader),
                shaderPerfData.subshaderIndex.ToString(),
                shaderPerfData.passName,
                shaderPerfData.hash);
        }

        public static void ClearShaderPerfCache(Shader shader)
        {
            try
            {
                var shaderDir = GetCompiledShaderCacheRootDirectory(shader);
                if (Directory.Exists(shaderDir))
                    Directory.Delete(shaderDir, true);
            }
            catch (Exception e)
            {
                Debug.LogWarning($"LWGUI: Cleaning the Shader({shader.name}) cache failed: {e.Message}");
            }
        }

        #endregion
    }
}