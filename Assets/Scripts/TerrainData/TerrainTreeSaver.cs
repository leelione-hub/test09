
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class TerrainTreeSaver : MonoBehaviour
{
    public Terrain terrain;
    public string savePath = "TerrainTrees.json";

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
                prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path),
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
}
