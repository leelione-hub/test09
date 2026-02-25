using System;
using System.Collections.Generic;
using System.IO;
using Extension;
using UnityEngine;

public class TerrainTreeSaver : MonoBehaviour
{
    public  Terrain          terrain;
    public  string           savePath      = "TerrainTrees.json";
    public  string           saveChunkPath = "TerrainChunkDatas.json";
    public  Vector3          chunkSize     = new Vector3(20, 10, 20);
    public  TextAsset        chunkJson;
    private string           chunkFolder = "/Resources/Terrains/ChunkDatas";
    private TerrainTreeDatas _terrainTreeDatas;
    public  bool             DebugMode = true;

    [ContextMenu("Save Trees")]
    public void SaveTrees()
    {
        if (terrain == null)
        {
            Debug.LogError("No terrain assigned!");
            return;
        }

        TerrainTreeData data = new TerrainTreeData();
        //data.prototypes.AddRange(terrain.terrainData.treePrototypes);

        #if UNITY_EDITOR
        foreach (var treePrototype in terrain.terrainData.treePrototypes)
        {
            data.prefabPath.Add( UnityEditor.AssetDatabase.GetAssetPath(treePrototype.prefab));
        }
        #endif
        
        foreach (TreeInstance tree in terrain.terrainData.treeInstances)
        {
            data.trees.Add(new TreeInstanceData(tree));
        }

        string json = JsonUtility.ToJson(data, true);
        File.WriteAllText(Path.Combine(Application.dataPath, savePath), json);
        
        Debug.Log($"Saved {data.trees.Count} trees to {savePath}");
    }

    [ContextMenu("Save Chunks")]
    public void SaveChunks()
    {
        if (terrain == null)
        {
            Debug.LogError("No terrain assigned!");
            return;
        }

        TerrainTreeDatas data = new TerrainTreeDatas();
        data.prefabPath = new List<string>();
        data.chunkDatas = new List<TerrainChunkData>();
        
        var terrainSize = terrain.terrainData.bounds.size;

#if UNITY_EDITOR
        foreach (var treePrototype in terrain.terrainData.treePrototypes)
        {
            data.prefabPath.Add( UnityEditor.AssetDatabase.GetAssetPath(treePrototype.prefab));
        }
#endif
        Dictionary<Bounds, List<TreeInstanceData>> chunkDic = new Dictionary<Bounds, List<TreeInstanceData>>();

        int index              = 0;
        int treeInstancesCount = terrain.terrainData.treeInstances.Length;
        foreach (TreeInstance tree in terrain.terrainData.treeInstances)
        {
#if UNITY_EDITOR
            UnityEditor.EditorUtility.DisplayProgressBar("保存 Terrain Chunk中", $"进度{index}/{treeInstancesCount}",
                (float)index / treeInstancesCount);
#endif
            var tempTreeData = new TreeInstanceData(tree,terrain);
            
            var bounds       = GetChunkBounds(tempTreeData.position);
            if (chunkDic.ContainsKey(bounds))
            {
                chunkDic[bounds].Add(tempTreeData);
            }
            else
            {
                chunkDic.Add(bounds, new List<TreeInstanceData>() { tempTreeData });
            }

            index++;
        }
#if UNITY_EDITOR
        UnityEditor.EditorUtility.ClearProgressBar();
        
#endif

        foreach (var chunk in chunkDic)
        {
            
            TerrainChunkData terrainChunkData = new TerrainChunkData();
            terrainChunkData.aabb  = chunk.Key;
            terrainChunkData.trees = chunk.Value;
            data.chunkDatas.Add(terrainChunkData);
        }

        string json          = JsonUtility.ToJson(data, true);
        string realChunkPath = Path.Combine(Application.dataPath + chunkFolder, saveChunkPath);
        File.WriteAllText(realChunkPath, json);
        
        Debug.Log($"Saved {data.chunkDatas.Count} chunks to {realChunkPath}");
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

        string json = File.ReadAllText(filePath);
        TerrainTreeData data = JsonUtility.FromJson<TerrainTreeData>(json);

        // 更新地形原型
        // terrain.terrainData.treePrototypes = data.prototypes.ToArray();
        List<TreePrototype> treePrototypes = new List<TreePrototype>();
#if UNITY_EDITOR
        foreach (var path in data.prefabPath)
        {
            TreePrototype treePrototype = new TreePrototype()
            {
                prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path),
                bendFactor = 0f,
                navMeshLod = 0,
            };
            treePrototypes.Add(treePrototype);
        }
#endif
        terrain.terrainData.treePrototypes = treePrototypes.ToArray();

        // 更新树木实例
        List<TreeInstance> treeInstances = new List<TreeInstance>();
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
        string           json  = chunkJson.text;
        _terrainTreeDatas = JsonUtility.FromJson<TerrainTreeDatas>(json);
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
        pos -= chunkSize / 2;
        var size = pos.Division(chunkSize);
        var center =
            new Vector3(Mathf.CeilToInt(size.x), Mathf.CeilToInt(size.y), Mathf.CeilToInt(size.z)).Multiply(chunkSize);
        return new Bounds(center, chunkSize);
    }
}
