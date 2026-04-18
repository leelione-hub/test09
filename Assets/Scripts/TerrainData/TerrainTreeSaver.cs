using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using Extension;
using UnityEngine;

public class TerrainTreeSaver : MonoBehaviour
{
    private struct ChunkCoord : IEquatable<ChunkCoord>
    {
        public int x;
        public int y;
        public int z;

        public bool Equals(ChunkCoord other)
        {
            return x == other.x && y == other.y && z == other.z;
        }

        public override bool Equals(object obj)
        {
            return obj is ChunkCoord other && Equals(other);
        }

        public override int GetHashCode()
        {
            unchecked
            {
                int hash = x;
                hash = (hash * 397) ^ y;
                hash = (hash * 397) ^ z;
                return hash;
            }
        }
    }

    private sealed class ChunkTempFile
    {
        public string path;
        public Bounds bounds;
        public int treeCount;
        public bool hasAnyTree;
        public StreamWriter writer;
    }

    public Terrain terrain;
    public string savePath = "TerrainTrees.bytes";
    public string saveChunkPath = "TerrainChunkDatas.bytes";
    public bool saveAsBinary = true;
    public Vector3 chunkSize = new Vector3(20, 10, 20);
    public TextAsset chunkJson;
    private string chunkFolder = "/Resources/Terrains/ChunkDatas";
    private TerrainTreeDatas _terrainTreeDatas;
    public bool DebugMode = true;

    [ContextMenu("Save Trees")]
    public void SaveTrees()
    {
        if (terrain == null)
        {
            Debug.LogError("No terrain assigned!");
            return;
        }

        TerrainData terrainData = terrain.terrainData;
        if (terrainData == null)
        {
            Debug.LogError("TerrainData is missing!");
            return;
        }
        
        string filePath = Path.Combine(Application.dataPath, savePath);
        TerrainTreeData data = BuildTerrainTreeData(terrainData);

        if (saveAsBinary || TerrainTreeSerialization.IsBinaryExtension(filePath))
        {
            if (!TerrainTreeSerialization.IsBinaryExtension(filePath))
            {
                Debug.LogWarning($"[TerrainTreeSaver] '{savePath}' is being written as binary but does not use a .bytes/.bin extension. Using .bytes is recommended.", this);
            }
            TerrainTreeSerialization.SaveTreeDataBinary(filePath, data);
            Debug.Log($"Saved {data.trees.Count} trees to {filePath} (binary)", this);
            return;
        }

        string json = JsonUtility.ToJson(data, true);
        Directory.CreateDirectory(Path.GetDirectoryName(filePath) ?? Application.dataPath);
        File.WriteAllText(filePath, json);
        Debug.Log($"Saved {data.trees.Count} trees to {filePath} (json)", this);
    }

    [ContextMenu("Save Chunks")]
    public void SaveChunks()
    {
        if (terrain == null)
        {
            Debug.LogError("No terrain assigned!");
            return;
        }

        TerrainData terrainData = terrain.terrainData;
        if (terrainData == null)
        {
            Debug.LogError("TerrainData is missing!");
            return;
        }

        string filePath = Path.Combine(Application.dataPath + chunkFolder, saveChunkPath);
        TerrainTreeDatas data = BuildTerrainChunkDatas(terrainData);

        if (saveAsBinary || TerrainTreeSerialization.IsBinaryExtension(filePath))
        {
            if (!TerrainTreeSerialization.IsBinaryExtension(filePath))
            {
                Debug.LogWarning($"[TerrainTreeSaver] '{saveChunkPath}' is being written as binary but does not use a .bytes/.bin extension. Using .bytes is recommended.", this);
            }
            TerrainTreeSerialization.SaveChunkDataBinary(filePath, data);
            Debug.Log($"Saved {data.chunkDatas.Count} chunks to {filePath} (binary)", this);
            return;
        }

        string json = JsonUtility.ToJson(data, true);
        Directory.CreateDirectory(Path.GetDirectoryName(filePath) ?? Application.dataPath);
        File.WriteAllText(filePath, json);
        Debug.Log($"Saved {data.chunkDatas.Count} chunks to {filePath} (json)", this);
    }

    [ContextMenu("Load Trees")]
    public void LoadTrees()
    {
        if (terrain == null)
        {
            Debug.LogError("No terrain assigned!");
            return;
        }

        string filePath = Path.Combine(Application.dataPath, savePath);
        if (!File.Exists(filePath))
        {
            Debug.LogError("No saved tree data found!");
            return;
        }

        TerrainTreeData data = TerrainTreeSerialization.LoadTreeDataFromFile(filePath);
        if (data == null)
        {
            Debug.LogError($"Failed to load terrain tree data from {filePath}");
            return;
        }

        List<TreePrototype> treePrototypes = new List<TreePrototype>();
#if UNITY_EDITOR
        foreach (var path in data.prefabPath)
        {
            TreePrototype treePrototype = new TreePrototype
            {
                prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path),
                bendFactor = 0f,
                navMeshLod = 0,
            };
            treePrototypes.Add(treePrototype);
        }
#endif
        terrain.terrainData.treePrototypes = treePrototypes.ToArray();

        List<TreeInstance> treeInstances = new List<TreeInstance>(data.trees.Count);
        foreach (TreeInstanceData treeData in data.trees)
        {
            treeInstances.Add(treeData.ToTreeInstance());
        }
        terrain.terrainData.treeInstances = treeInstances.ToArray();

        Debug.Log($"Loaded {data.trees.Count} trees from {savePath}");
    }

    public void LoadChunks()
    {
        if (chunkJson == null)
        {
            _terrainTreeDatas = null;
            return;
        }

        _terrainTreeDatas = TerrainTreeSerialization.LoadChunkDataFromTextAsset(chunkJson);
    }

    private void OnDrawGizmos()
    {
        if (!DebugMode)
        {
            return;
        }

        if (_terrainTreeDatas != null)
        {
            foreach (var chunk in _terrainTreeDatas.chunkDatas)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawWireCube(chunk.aabb.center, chunk.aabb.size);
            }
        }
    }

    public Bounds GetChunkBounds(Vector3 pos)
    {
        ChunkCoord coord = GetChunkCoord(pos);
        return GetChunkBoundsFromCoord(coord);
    }

    private TerrainTreeData BuildTerrainTreeData(TerrainData terrainData)
    {
        TerrainTreeData data = new TerrainTreeData();

#if UNITY_EDITOR
        foreach (TreePrototype treePrototype in terrainData.treePrototypes)
        {
            data.prefabPath.Add(UnityEditor.AssetDatabase.GetAssetPath(treePrototype.prefab));
        }
#endif

        TreeInstance[] treeInstances = terrainData.treeInstances;
        data.trees = new List<TreeInstanceData>(treeInstances.Length);
        for (int i = 0; i < treeInstances.Length; i++)
        {
            data.trees.Add(new TreeInstanceData(treeInstances[i]));
        }

        return data;
    }

    private TerrainTreeDatas BuildTerrainChunkDatas(TerrainData terrainData)
    {
        TerrainTreeDatas data = new TerrainTreeDatas
        {
            prefabPath = new List<string>(),
            chunkDatas = new List<TerrainChunkData>()
        };

#if UNITY_EDITOR
        foreach (TreePrototype treePrototype in terrainData.treePrototypes)
        {
            data.prefabPath.Add(UnityEditor.AssetDatabase.GetAssetPath(treePrototype.prefab));
        }
#endif

        Dictionary<ChunkCoord, TerrainChunkData> chunkMap = new Dictionary<ChunkCoord, TerrainChunkData>(1024);
        TreeInstance[] treeInstances = terrainData.treeInstances;
        int treeCount = treeInstances.Length;

        for (int i = 0; i < treeCount; i++)
        {
#if UNITY_EDITOR
            if ((i & 8191) == 0)
            {
                bool canceled = UnityEditor.EditorUtility.DisplayCancelableProgressBar(
                    "Build Terrain Chunk Data",
                    $"Bucketing tree {i}/{treeCount}",
                    treeCount > 0 ? i / (float)treeCount : 1f);
                if (canceled)
                {
                    throw new OperationCanceledException("SaveChunks canceled by user.");
                }
            }
#endif
            TreeInstance tree = treeInstances[i];
            TreeInstanceData treeData = new TreeInstanceData(tree, terrain);
            ChunkCoord coord = GetChunkCoord(treeData.position);
            if (!chunkMap.TryGetValue(coord, out TerrainChunkData chunkData))
            {
                chunkData = new TerrainChunkData
                {
                    aabb = GetChunkBoundsFromCoord(coord),
                    trees = new List<TreeInstanceData>()
                };
                chunkMap.Add(coord, chunkData);
                data.chunkDatas.Add(chunkData);
            }

            chunkData.trees.Add(treeData);
        }

#if UNITY_EDITOR
        UnityEditor.EditorUtility.ClearProgressBar();
#endif
        return data;
    }

    private ChunkCoord GetChunkCoord(Vector3 pos)
    {
        pos -= chunkSize / 2f;
        Vector3 size = pos.Division(chunkSize);
        return new ChunkCoord
        {
            x = Mathf.CeilToInt(size.x),
            y = Mathf.CeilToInt(size.y),
            z = Mathf.CeilToInt(size.z),
        };
    }

    private Bounds GetChunkBoundsFromCoord(ChunkCoord coord)
    {
        Vector3 center = new Vector3(coord.x, coord.y, coord.z).Multiply(chunkSize);
        return new Bounds(center, chunkSize);
    }

    private static Vector3 GetTreeWorldPosition(TreeInstance tree, Terrain terrainRef)
    {
        Vector3 localPos = Vector3.Scale(tree.position, terrainRef.terrainData.size);
        return terrainRef.transform.TransformPoint(localPos);
    }

    private static void WriteTreeInstanceJson(StreamWriter writer, TreeInstance tree, bool includeIndent, Terrain terrainRef)
    {
        Vector3 position = terrainRef != null ? GetTreeWorldPosition(tree, terrainRef) : tree.position;
        Vector3 scale = new Vector3(tree.widthScale, tree.heightScale, tree.widthScale);
        string indent0 = includeIndent ? "        " : string.Empty;
        string indent1 = includeIndent ? "            " : string.Empty;
        string indent2 = includeIndent ? "                " : string.Empty;

        writer.Write(indent0);
        writer.WriteLine("{");
        writer.Write(indent1);
        writer.WriteLine("\"position\": {");
        writer.Write(indent2);
        writer.Write("\"x\": ");
        writer.Write(FormatFloat(position.x));
        writer.WriteLine(",");
        writer.Write(indent2);
        writer.Write("\"y\": ");
        writer.Write(FormatFloat(position.y));
        writer.WriteLine(",");
        writer.Write(indent2);
        writer.Write("\"z\": ");
        writer.Write(FormatFloat(position.z));
        writer.WriteLine();
        writer.Write(indent1);
        writer.WriteLine("},");
        writer.Write(indent1);
        writer.WriteLine("\"scale\": {");
        writer.Write(indent2);
        writer.Write("\"x\": ");
        writer.Write(FormatFloat(scale.x));
        writer.WriteLine(",");
        writer.Write(indent2);
        writer.Write("\"y\": ");
        writer.Write(FormatFloat(scale.y));
        writer.WriteLine(",");
        writer.Write(indent2);
        writer.Write("\"z\": ");
        writer.Write(FormatFloat(scale.z));
        writer.WriteLine();
        writer.Write(indent1);
        writer.WriteLine("},");
        writer.Write(indent1);
        writer.Write("\"prototypeIndex\": ");
        writer.Write(tree.prototypeIndex);
        writer.WriteLine(",");
        writer.Write(indent1);
        writer.Write("\"rotation\": ");
        writer.Write(FormatFloat(tree.rotation));
        writer.WriteLine();
        writer.Write(indent0);
        writer.Write("}");
    }

    private static void WriteBoundsJson(StreamWriter writer, Bounds bounds)
    {
        writer.WriteLine("{");
        writer.WriteLine("                \"m_Center\": {");
        writer.Write("                    \"x\": ");
        writer.Write(FormatFloat(bounds.center.x));
        writer.WriteLine(",");
        writer.Write("                    \"y\": ");
        writer.Write(FormatFloat(bounds.center.y));
        writer.WriteLine(",");
        writer.Write("                    \"z\": ");
        writer.Write(FormatFloat(bounds.center.z));
        writer.WriteLine();
        writer.WriteLine("                },");
        writer.WriteLine("                \"m_Extent\": {");
        writer.Write("                    \"x\": ");
        writer.Write(FormatFloat(bounds.extents.x));
        writer.WriteLine(",");
        writer.Write("                    \"y\": ");
        writer.Write(FormatFloat(bounds.extents.y));
        writer.WriteLine(",");
        writer.Write("                    \"z\": ");
        writer.Write(FormatFloat(bounds.extents.z));
        writer.WriteLine();
        writer.Write("                }");
        writer.WriteLine();
        writer.Write("            }");
    }

    private static string FormatFloat(float value)
    {
        return value.ToString("R", CultureInfo.InvariantCulture);
    }

    private static void WriteJsonString(StreamWriter writer, string value)
    {
        writer.Write('"');
        if (!string.IsNullOrEmpty(value))
        {
            for (int i = 0; i < value.Length; i++)
            {
                char c = value[i];
                switch (c)
                {
                    case '\\':
                        writer.Write("\\\\");
                        break;
                    case '"':
                        writer.Write("\\\"");
                        break;
                    case '\n':
                        writer.Write("\\n");
                        break;
                    case '\r':
                        writer.Write("\\r");
                        break;
                    case '\t':
                        writer.Write("\\t");
                        break;
                    default:
                        writer.Write(c);
                        break;
                }
            }
        }
        writer.Write('"');
    }
}
