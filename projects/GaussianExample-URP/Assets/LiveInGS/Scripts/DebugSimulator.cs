using UnityEngine;

public class DebugSimulator : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
#if UNITY_EDITOR || PLATFORM_STANDALONE_OSX  
        transform.position = Vector3.up;
#endif
    }

    // Update is called once per frame
    void Update()
    {
#if UNITY_EDITOR
        KeyboardControl();
#endif
    }

    void KeyboardControl()
    {
        // 示例：使用键盘输入来平移
        float hor = Input.GetAxis("Horizontal"); // 左右
        float ver = Input.GetAxis("Vertical");     // 前后
        if (hor != 0 || ver != 0)
            Move(new Vector2(hor, ver));
        
        // 使用 Q/E 键来旋转
        if (Input.GetKey(KeyCode.Q))
            Rotate(-1f); // Q 键向左转（绕 Y 轴负方向旋转）
        if (Input.GetKey(KeyCode.E))
            Rotate(1f); 
    }

    void Move(Vector2 direction)
    {
        direction /= 20.0f;
        // direction.y 用来控制前后方向，direction.x 控制左右方向
        Vector3 movement = transform.forward * direction.y + transform.right * direction.x;
        transform.position += movement;
    }
    
    // 实现旋转功能，direction 为正表示向右转，为负表示向左转
    void Rotate(float direction)
    {
        // 旋转速度为每秒 100 度，根据 Time.deltaTime 平滑旋转
        float rotationSpeed = 100f * Time.deltaTime;
        transform.Rotate(0f, direction * rotationSpeed, 0f);
    }
}
