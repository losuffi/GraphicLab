using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TimmerToShowOrHidden : MonoBehaviour {
	[SerializeField]
	private GameObject Target;
	[SerializeField]
	private float DelayTime;
	[SerializeField]
	private bool IsShow;
	
	private float lastTime=0;
	private void OnEnable() 
	{
		lastTime=Time.time;
	}
	private void Update() {
		if(Target==null)
		{
			OnEnable();
			return;
		}
		if(Time.time-lastTime>DelayTime)	
		{
			DelayTime=Time.time;
			Target.SetActive(IsShow);
		}
	}
}
