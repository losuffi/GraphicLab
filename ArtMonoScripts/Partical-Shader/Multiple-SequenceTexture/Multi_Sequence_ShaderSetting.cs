using UnityEngine;
[RequireComponent(typeof(ParticleSystem))]
[ExecuteInEditMode]
public class Multi_Sequence_ShaderSetting : MonoBehaviour {

    [System.Serializable]
    public class SettingDes
    {
        public float _T;
        public float _Count;
        public Vector2 _AdjOfs;
        public Vector2 _Scale=new Vector2(1,1);
    };

    [SerializeField]
    private Material rend;
    [Header("Description")]
    [SerializeField]
    private SettingDes[] des;
    [SerializeField]
    private bool PlayRandom=true;
    [SerializeField]
    private int PlayIndex=0;
    private float startTime;
    private int playingIndex=-1;

    private void OnWillRenderObject() {
        if(des==null||des.Length<1)
        {
            return;
        }
        if(playingIndex==-1)
        {
            if(PlayRandom)
                playingIndex=Random.Range(0,des.Length);
            else
                playingIndex=PlayIndex;
        }
        if(Time.time-startTime>des[playingIndex]._T)
        {
            startTime=Time.time;
            rend.SetFloat("_StartTime",startTime);
            if(PlayRandom)
                playingIndex=Random.Range(0,des.Length);
            else
                playingIndex=PlayIndex;
            rend.SetVector("_AdjOffs",des[playingIndex]._AdjOfs);
            rend.SetVector("_AdjScale",des[playingIndex]._Scale);
        }
        rend.SetFloat("_Size",des.Length);
        rend.SetInt("_Index",playingIndex);
        rend.SetFloat("_SequenceSize",des[playingIndex]._Count);
        rend.SetFloat("_T",des[playingIndex]._T);
    }
}