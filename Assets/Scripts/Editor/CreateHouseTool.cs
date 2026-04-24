using UnityEngine;
using UnityEditor;

public class CreateHouseTool : EditorWindow
{
    [MenuItem("Tools/Create House")]
    static void CreateHouse()
    {
        // 创建房子父对象
        GameObject house = new GameObject("House");
        house.transform.position = Vector3.zero;

        // 地板 (地基)
        GameObject floor = GameObject.CreatePrimitive(PrimitiveType.Cube);
        floor.name = "Floor";
        floor.transform.SetParent(house.transform);
        floor.transform.localScale = new Vector3(4, 0.2f, 4);
        floor.transform.position = new Vector3(0, 0.1f, 0);
        floor.GetComponent<Renderer>().material.color = new Color(0.4f, 0.3f, 0.2f);

        // 四面墙
        GameObject wall1 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        wall1.name = "Wall_Front";
        wall1.transform.SetParent(house.transform);
        wall1.transform.localScale = new Vector3(4, 2.5f, 0.2f);
        wall1.transform.position = new Vector3(0, 1.35f, 1.9f);
        wall1.GetComponent<Renderer>().material.color = new Color(0.9f, 0.85f, 0.7f);

        GameObject wall2 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        wall2.name = "Wall_Back";
        wall2.transform.SetParent(house.transform);
        wall2.transform.localScale = new Vector3(4, 2.5f, 0.2f);
        wall2.transform.position = new Vector3(0, 1.35f, -1.9f);
        wall2.GetComponent<Renderer>().material.color = new Color(0.9f, 0.85f, 0.7f);

        GameObject wall3 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        wall3.name = "Wall_Left";
        wall3.transform.SetParent(house.transform);
        wall3.transform.localScale = new Vector3(0.2f, 2.5f, 3.6f);
        wall3.transform.position = new Vector3(-1.9f, 1.35f, 0);
        wall3.GetComponent<Renderer>().material.color = new Color(0.9f, 0.85f, 0.7f);

        GameObject wall4 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        wall4.name = "Wall_Right";
        wall4.transform.SetParent(house.transform);
        wall4.transform.localScale = new Vector3(0.2f, 2.5f, 3.6f);
        wall4.transform.position = new Vector3(1.9f, 1.35f, 0);
        wall4.GetComponent<Renderer>().material.color = new Color(0.9f, 0.85f, 0.7f);

        // 门
        GameObject door = GameObject.CreatePrimitive(PrimitiveType.Cube);
        door.name = "Door";
        door.transform.SetParent(house.transform);
        door.transform.localScale = new Vector3(1, 2, 0.1f);
        door.transform.position = new Vector3(0, 1.1f, 1.95f);
        door.GetComponent<Renderer>().material.color = new Color(0.5f, 0.25f, 0.1f);

        // 窗户
        GameObject window1 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        window1.name = "Window_Left";
        window1.transform.SetParent(house.transform);
        window1.transform.localScale = new Vector3(0.1f, 1, 1.5f);
        window1.transform.position = new Vector3(-1.95f, 1.5f, 0);
        window1.GetComponent<Renderer>().material.color = new Color(0.6f, 0.8f, 0.9f);

        GameObject window2 = GameObject.CreatePrimitive(PrimitiveType.Cube);
        window2.name = "Window_Right";
        window2.transform.SetParent(house.transform);
        window2.transform.localScale = new Vector3(0.1f, 1, 1.5f);
        window2.transform.position = new Vector3(1.95f, 1.5f, 0);
        window2.GetComponent<Renderer>().material.color = new Color(0.6f, 0.8f, 0.9f);

        // 屋顶 (四面体)
        GameObject roof = GameObject.CreatePrimitive(PrimitiveType.Cube);
        roof.name = "Roof";
        roof.transform.SetParent(house.transform);
        roof.transform.localScale = new Vector3(4.5f, 0.2f, 4.5f);
        roof.transform.position = new Vector3(0, 2.8f, 0);
        roof.transform.rotation = Quaternion.Euler(0, 45, 0);
        roof.GetComponent<Renderer>().material.color = new Color(0.6f, 0.2f, 0.15f);

        // 屋顶上层
        GameObject roofTop = GameObject.CreatePrimitive(PrimitiveType.Cube);
        roofTop.name = "RoofTop";
        roofTop.transform.SetParent(house.transform);
        roofTop.transform.localScale = new Vector3(3.5f, 0.2f, 3.5f);
        roofTop.transform.position = new Vector3(0, 3.2f, 0);
        roofTop.transform.rotation = Quaternion.Euler(0, 45, 0);
        roofTop.GetComponent<Renderer>().material.color = new Color(0.6f, 0.2f, 0.15f);

        // 烟囱
        GameObject chimney = GameObject.CreatePrimitive(PrimitiveType.Cube);
        chimney.name = "Chimney";
        chimney.transform.SetParent(house.transform);
        chimney.transform.localScale = new Vector3(0.6f, 1.5f, 0.6f);
        chimney.transform.position = new Vector3(1, 3.5f, -1);
        chimney.GetComponent<Renderer>().material.color = new Color(0.4f, 0.2f, 0.15f);

        Debug.Log("小房子已创建！位置: (0, 0, 0)");
        Selection.activeGameObject = house;
    }

    [MenuItem("Tools/Create Red Cube")]
    static void CreateRedCube()
    {
        // 创建红色 Cube
        GameObject redCube = GameObject.CreatePrimitive(PrimitiveType.Cube);
        redCube.name = "RedCube";
        redCube.transform.position = Vector3.zero;

        // 设置红色材质
        Renderer renderer = redCube.GetComponent<Renderer>();
        renderer.material.color = Color.red;

        // 添加一个简单的旋转脚本（可选）
        // redCube.AddComponent<RotateObject>();

        Debug.Log("红色 Cube 已创建！位置: (0, 0, 0)");
        Selection.activeGameObject = redCube;
    }
}
