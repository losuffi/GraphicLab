using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotationUpdate : MonoBehaviour {

	[SerializeField]
	private float rotationSpeed;
	[SerializeField]
	private Vector3 Axis=Vector3.up;
	void Update () {
		transform.rotation*=Quaternion.AngleAxis(rotationSpeed*Time.deltaTime,Axis);
	}
}
