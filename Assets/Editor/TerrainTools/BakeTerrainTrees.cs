using UnityEditor;
using UnityEngine;

namespace Editor.TerrainTools
{
    public class BakeTerrainTrees : EditorWindow
    {
        private static BakeTerrainTrees ins;
        private void CreateGUI()
        {
            ins = CreateInstance<BakeTerrainTrees>();
            ins.Show();
        }

        private Terrain terrain;
        private void OnGUI()
        {
            if(GUILayout.Button("获取Terrain"))
            {
                terrain = GameObject.FindObjectOfType<Terrain>();
                if (terrain == null)
                {
                    EditorUtility.DisplayDialog("Terrain Not Find!!!", "场景中没有找到任何Terrain", "关闭");
                }
            }

            if (terrain != null)
            {
                if (GUILayout.Button("烘焙TreeData"))
                {
                    
                }
            }
        }
        
        
        void SaveTreeData()
        {
            if (terrain == null) return;
            
        }
        
    }
}