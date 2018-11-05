using UnityEngine;
[RequireComponent(typeof(LineRenderer))]
public class RandomKeyPointLineRender : MonoBehaviour {
    private LineRenderer model;
    [SerializeField]
    private Vector3 InitOffset;
    [SerializeField]
    private Vector4[] fftSpectrum; 
    private Vector2[] hkt=null;
    private Vector2 Cmul(Vector2 lhs,Vector2 rhs)
    {
        return new Vector2(lhs.x*rhs.x-lhs.y*rhs.y,lhs.x*rhs.y+lhs.y*rhs.x);
    }
    private Vector2[] fft(Vector2[] one_fft_arr)
    {
        int N=one_fft_arr.Length;
        if(N<=1)
            return one_fft_arr;
        Vector2[] odd=new Vector2[N/2];
        Vector2[] even=new Vector2[N/2];
        int ori=0;
        for(int i=0;i<N/2;i++)
        {
            even[i]=one_fft_arr[ori];
            ori+=2;
        }
        ori=1;
        for(int i=0;i<N/2;i++)
        {
            odd[i]=one_fft_arr[ori];
            ori+=2;
        }
        Vector2[] fodd=fft(odd);
        Vector2[] feven=fft(even);
        Vector2[] T=new Vector2[fodd.Length];
        for(int i=0;i<fodd.Length;i++)
        {
            Vector2 W=new Vector2(Mathf.Cos(-2*Mathf.PI*i/N),Mathf.Sin(-2*Mathf.PI*i/N));
            T[i]=Cmul(fodd[i],W);
        }
        Vector2[] res=new Vector2[N];
        for(int i=0;i<N/2;i++)
        {
            res[i]=feven[i]+T[i];
            res[i+N/2]=feven[i]-T[i];
        }
        return res;
    }
    private void OnEnable() {
        model=GetComponent<LineRenderer>();
        hkt=new Vector2[fftSpectrum.Length];
        Debug.Log(hkt.Length);
        if(fftSpectrum.Length==0||(fftSpectrum.Length&(fftSpectrum.Length-1))!=0)
        {
            throw new System.Exception("保证频谱长度，为2的整数次幂！！！！！！！！！！");
        }
    }
    private void Update() {
        var r=HKT(Time.time);
        int l=model.positionCount;
        Vector3 s=model.GetPosition(0);
        Vector3 e=model.GetPosition(l-1);
        Vector3[] nPos=new Vector3[fftSpectrum.Length+2];
        for(int i=0;i<fftSpectrum.Length;i++)
        {
            nPos[i+1]=new Vector3(r[0,i].x,r[1,i].y,r[2,i].x);
        }
        nPos[0]=s;
        nPos[fftSpectrum.Length+1]=e;
        model.SetPositions(nPos);
    }
    private Vector2[,] HKT(float t)
    {
        Vector2[,] hkt=new Vector2[3,fftSpectrum.Length];
        for(int i=0;i<fftSpectrum.Length;i++)
        {
            float _a=Mathf.Cos(fftSpectrum[i].w*t*2*Mathf.PI);
            hkt[0,i]=new Vector2(fftSpectrum[i].x,0)*_a;
            hkt[1,i]=new Vector2(fftSpectrum[i].y,0)*_a;
            hkt[2,i]=new Vector2(fftSpectrum[i].z,0)*_a;
        }
        Vector2[] trans=new Vector2[fftSpectrum.Length];
        Vector2[,] oput=new Vector2[3,fftSpectrum.Length];
        for (int j=0;j<3;j++)
        {
            for(int i=0;i<trans.Length;i++)
            {
                trans[i]=new Vector2(hkt[j,i].x,-hkt[j,i].y);
            }
            var res= fft(trans);
            for(int i=0;i<res.Length;i++)
            {
                res[i]=new Vector2(res[i].x,-res[i].y)/res.Length;
                oput[j,i]=res[i];
            }
        }
        oput[0,0]+=new Vector2(InitOffset.x,0);
        oput[1,0]+=new Vector2(InitOffset.y,0);
        oput[2,0]+=new Vector2(InitOffset.z,0);
        return oput;
    }
}