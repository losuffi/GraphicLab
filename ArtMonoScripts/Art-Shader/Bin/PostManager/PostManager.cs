using UnityEngine;
using System.Collections.Generic;
[RequireComponent(typeof(Camera)),DisallowMultipleComponent]
public class PostManager : MonoBehaviour {

    private RenderTexture currentPost;
    private RenderTexture initPost;
    private RenderTexture depthPost;
    private RenderTexture normalPost;
    private List<PostAgent> agentList;

    private static PostManager instantiete;
    public static PostManager Instantiete{get{return instantiete;}}
    
    public class PostAgent
    {
        public int Priority;
        public delegate void TriggerFunc();
        public TriggerFunc Trigger;
    }
    public RenderTexture CurrentBuffer
    {
        get
        {
            if(currentPost==null)
            {
                CreateCurrentBuffer();
            }
            return currentPost;
        }
    }
    public RenderTexture InitPost
    {
        get
        {
            return initPost;
        }
    }
    public RenderTexture DepthPost
    {
        get
        {
            return depthPost;
        }
    }
    public RenderTexture NormalPost
    {
        get
        {
            return normalPost;
        }
    }
    public void ReleaseAllBuffer()
    {
        currentPost.Release();
        currentPost=null;
        initPost.Release();
        initPost=null;
        depthPost.Release();
        depthPost=null;
        normalPost.Release();
        normalPost=null;
    }

    public void PushInPostStack(PostAgent agent)   
    {
        if(agentList==null)
        {
            agentList=new List<PostAgent>(10);
        }
        for(int i=0;i<agentList.Count;i++)
        {
            if(agentList[i].Priority<agent.Priority)
            {
                agentList.Insert(i,agent);
                break;
            }
        }
    }
    private void OnEnable() 
    {
        if(instantiete==null)
            instantiete=this;       
    }


    private void CreateCurrentBuffer()
    {
        currentPost=new RenderTexture(Screen.width,Screen.height,0,RenderTextureFormat.ARGB32);
    }
    private void CreateInitBuffer()
    {
        initPost=new RenderTexture(Screen.width,Screen.height,0,RenderTextureFormat.ARGB32);
    }
    
    private void OnRenderImage(RenderTexture src, RenderTexture dest) 
    {
        initPost=src;       
        if(currentPost==null)
        {
            return;
        }
        Graphics.Blit(initPost,currentPost);
        for(int i=0;i<agentList.Count;i++)
        {
            agentList[i].Trigger();
        }
        Graphics.Blit(currentPost,dest);
    }
}