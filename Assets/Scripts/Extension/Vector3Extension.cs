using System;
using Unity.Mathematics;
using UnityEngine;

namespace Extension
{
    public static class Vector3Extension
    {
        public static Vector3 Multiply(this Vector3 value1, Vector3 value2)
        {
            return new Vector3(value1.x * value2.x, value1.y * value2.y, value1.z * value2.z);
        }

        public static float SelfPow(this Vector3 value)
        {
            return value.x * value.y * value.z;
        }

        public static Vector3 Division(this Vector3 value1, Vector3 value2)
        {
            if (value2.SelfPow() == 0)
            {
                throw new Exception("value2中包含0,除0是不合法的！！！！");
            }
            return new Vector3(value1.x / value2.x, value1.y / value2.y, value1.z / value2.z);
        }

        public static Vector3 MathRound(this Vector3 value, int digits)
        {
            return new Vector3((float)Math.Round(value.x, digits, MidpointRounding.AwayFromZero),
                (float)Math.Round(value.y, digits, MidpointRounding.AwayFromZero),
                (float)Math.Round(value.z, digits, MidpointRounding.AwayFromZero));
        }
    }
}