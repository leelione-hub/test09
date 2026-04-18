using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;

public static class TerrainTreeSerialization
{
    private const uint TreeDataMagic = 0x31475456;   // VTG1
    private const uint ChunkDataMagic = 0x32475456;  // VTG2
    private const int CurrentVersion = 1;

    public static bool IsBinaryExtension(string path)
    {
        if (string.IsNullOrEmpty(path))
        {
            return false;
        }

        string extension = Path.GetExtension(path).ToLowerInvariant();
        return extension == ".bytes" || extension == ".bin";
    }

    public static void SaveTreeDataBinary(string filePath, TerrainTreeData data)
    {
        EnsureParentDirectory(filePath);

        using (FileStream stream = new FileStream(filePath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
        using (BinaryWriter writer = new BinaryWriter(stream, Encoding.UTF8))
        {
            writer.Write(TreeDataMagic);
            writer.Write(CurrentVersion);

            WriteStringList(writer, data.prefabPath);

            int treeCount = data.trees != null ? data.trees.Count : 0;
            writer.Write(treeCount);
            for (int i = 0; i < treeCount; i++)
            {
                WriteTreeInstanceData(writer, data.trees[i]);
            }
        }
    }

    public static void SaveChunkDataBinary(string filePath, TerrainTreeDatas data)
    {
        EnsureParentDirectory(filePath);

        using (FileStream stream = new FileStream(filePath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
        using (BinaryWriter writer = new BinaryWriter(stream, Encoding.UTF8))
        {
            writer.Write(ChunkDataMagic);
            writer.Write(CurrentVersion);

            WriteStringList(writer, data.prefabPath);

            int chunkCount = data.chunkDatas != null ? data.chunkDatas.Count : 0;
            writer.Write(chunkCount);
            for (int i = 0; i < chunkCount; i++)
            {
                TerrainChunkData chunk = data.chunkDatas[i];
                WriteBounds(writer, chunk.aabb);

                int treeCount = chunk.trees != null ? chunk.trees.Count : 0;
                writer.Write(treeCount);
                for (int j = 0; j < treeCount; j++)
                {
                    WriteTreeInstanceData(writer, chunk.trees[j]);
                }
            }
        }
    }

    public static TerrainTreeData LoadTreeDataFromFile(string filePath)
    {
        if (!File.Exists(filePath))
        {
            return null;
        }

        if (LooksLikeBinary(filePath))
        {
            using (FileStream stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
            using (BinaryReader reader = new BinaryReader(stream, Encoding.UTF8))
            {
                return LoadTreeDataBinary(reader);
            }
        }

        string json = File.ReadAllText(filePath);
        return JsonUtility.FromJson<TerrainTreeData>(json);
    }

    public static TerrainTreeDatas LoadChunkDataFromTextAsset(TextAsset asset)
    {
        if (asset == null)
        {
            return null;
        }

        byte[] bytes = asset.bytes;
        if (LooksLikeBinary(bytes))
        {
            using (MemoryStream stream = new MemoryStream(bytes, false))
            using (BinaryReader reader = new BinaryReader(stream, Encoding.UTF8))
            {
                return LoadChunkDataBinary(reader);
            }
        }

        return JsonUtility.FromJson<TerrainTreeDatas>(asset.text);
    }

    public static TerrainTreeData LoadTreeDataFromTextAsset(TextAsset asset)
    {
        if (asset == null)
        {
            return null;
        }

        byte[] bytes = asset.bytes;
        if (LooksLikeBinary(bytes))
        {
            using (MemoryStream stream = new MemoryStream(bytes, false))
            using (BinaryReader reader = new BinaryReader(stream, Encoding.UTF8))
            {
                return LoadTreeDataBinary(reader);
            }
        }

        return JsonUtility.FromJson<TerrainTreeData>(asset.text);
    }

    private static TerrainTreeData LoadTreeDataBinary(BinaryReader reader)
    {
        ValidateHeader(reader, TreeDataMagic);

        TerrainTreeData data = new TerrainTreeData
        {
            prefabPath = ReadStringList(reader)
        };

        int treeCount = reader.ReadInt32();
        data.trees = new List<TreeInstanceData>(treeCount);
        for (int i = 0; i < treeCount; i++)
        {
            data.trees.Add(ReadTreeInstanceData(reader));
        }

        return data;
    }

    private static TerrainTreeDatas LoadChunkDataBinary(BinaryReader reader)
    {
        ValidateHeader(reader, ChunkDataMagic);

        TerrainTreeDatas data = new TerrainTreeDatas
        {
            prefabPath = ReadStringList(reader),
            chunkDatas = new List<TerrainChunkData>()
        };

        int chunkCount = reader.ReadInt32();
        data.chunkDatas = new List<TerrainChunkData>(chunkCount);
        for (int i = 0; i < chunkCount; i++)
        {
            TerrainChunkData chunk = new TerrainChunkData
            {
                aabb = ReadBounds(reader),
                trees = new List<TreeInstanceData>()
            };

            int treeCount = reader.ReadInt32();
            chunk.trees = new List<TreeInstanceData>(treeCount);
            for (int j = 0; j < treeCount; j++)
            {
                chunk.trees.Add(ReadTreeInstanceData(reader));
            }

            data.chunkDatas.Add(chunk);
        }

        return data;
    }

    private static void ValidateHeader(BinaryReader reader, uint expectedMagic)
    {
        uint magic = reader.ReadUInt32();
        if (magic != expectedMagic)
        {
            throw new InvalidDataException($"Unexpected terrain tree binary magic. Expected {expectedMagic}, got {magic}.");
        }

        int version = reader.ReadInt32();
        if (version != CurrentVersion)
        {
            throw new InvalidDataException($"Unsupported terrain tree binary version: {version}.");
        }
    }

    private static void WriteStringList(BinaryWriter writer, List<string> values)
    {
        int count = values != null ? values.Count : 0;
        writer.Write(count);
        for (int i = 0; i < count; i++)
        {
            writer.Write(values[i] ?? string.Empty);
        }
    }

    private static List<string> ReadStringList(BinaryReader reader)
    {
        int count = reader.ReadInt32();
        List<string> values = new List<string>(count);
        for (int i = 0; i < count; i++)
        {
            values.Add(reader.ReadString());
        }

        return values;
    }

    private static void WriteTreeInstanceData(BinaryWriter writer, TreeInstanceData data)
    {
        WriteVector3(writer, data.position);
        WriteVector3(writer, data.scale);
        writer.Write(data.prototypeIndex);
        writer.Write(data.rotation);
    }

    private static TreeInstanceData ReadTreeInstanceData(BinaryReader reader)
    {
        TreeInstanceData data = new TreeInstanceData();
        data.position = ReadVector3(reader);
        data.scale = ReadVector3(reader);
        data.prototypeIndex = reader.ReadInt32();
        data.rotation = reader.ReadSingle();
        return data;
    }

    private static void WriteBounds(BinaryWriter writer, Bounds bounds)
    {
        WriteVector3(writer, bounds.center);
        WriteVector3(writer, bounds.extents);
    }

    private static Bounds ReadBounds(BinaryReader reader)
    {
        Vector3 center = ReadVector3(reader);
        Vector3 extents = ReadVector3(reader);
        Bounds bounds = new Bounds(center, extents * 2f);
        return bounds;
    }

    private static void WriteVector3(BinaryWriter writer, Vector3 value)
    {
        writer.Write(value.x);
        writer.Write(value.y);
        writer.Write(value.z);
    }

    private static Vector3 ReadVector3(BinaryReader reader)
    {
        return new Vector3(reader.ReadSingle(), reader.ReadSingle(), reader.ReadSingle());
    }

    private static void EnsureParentDirectory(string filePath)
    {
        string directory = Path.GetDirectoryName(filePath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }
    }

    private static bool LooksLikeBinary(string filePath)
    {
        using (FileStream stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read))
        {
            if (stream.Length < sizeof(uint))
            {
                return false;
            }

            using (BinaryReader reader = new BinaryReader(stream, Encoding.UTF8, leaveOpen: true))
            {
                uint magic = reader.ReadUInt32();
                return magic == TreeDataMagic || magic == ChunkDataMagic;
            }
        }
    }

    private static bool LooksLikeBinary(byte[] bytes)
    {
        if (bytes == null || bytes.Length < sizeof(uint))
        {
            return false;
        }

        uint magic = BitConverter.ToUInt32(bytes, 0);
        return magic == TreeDataMagic || magic == ChunkDataMagic;
    }
}
