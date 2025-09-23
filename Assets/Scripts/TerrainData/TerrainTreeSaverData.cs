using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

[System.Serializable]
public class TreeInstanceData
{
    public Vector3 position;
    public Vector3 scale;
    public int prototypeIndex;
    public float rotation; // 只保存绕Y轴旋转

    public TreeInstanceData(TreeInstance treeInstance)
    {
        position = treeInstance.position;
        scale = new Vector3(treeInstance.widthScale, treeInstance.heightScale, treeInstance.widthScale);
        prototypeIndex = treeInstance.prototypeIndex;
        rotation = treeInstance.rotation;
    }

    public TreeInstance ToTreeInstance()
    {
        return new TreeInstance
        {
            position = position,
            widthScale = scale.x,
            heightScale = scale.y,
            prototypeIndex = prototypeIndex,
            rotation = rotation
        };
    }
}

[System.Serializable]
public class TerrainTreeData
{
    public List<string> prefabPath = new List<string>();
    public List<TreeInstanceData> trees = new List<TreeInstanceData>();
    // public List<TreePrototype> prototypes = new List<TreePrototype>();
}



#if UNITY_EDITOR
[CustomEditor(typeof(TerrainTreeSaver))]
public class TerrainTreeSaverEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        TerrainTreeSaver saver = (TerrainTreeSaver)target;
        
        if (GUILayout.Button("Save Trees"))
        {
            saver.SaveTrees();
        }
        
        if (GUILayout.Button("Load Trees"))
        {
            saver.LoadTrees();
        }
    }
}
#endif