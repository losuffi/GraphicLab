using UnityEngine;
using System.Collections.Generic;
using UnityEngine.Rendering;
using System;

[RequireComponent(typeof(Camera)),DisallowMultipleComponent]
public class PostManager : MonoBehaviour {

    private RenderTexture currentPost;
    private RenderTexture initPost;
    private RenderTexture depthPost;
    private RenderTexture normalPost;
    private List<PostAgent> agentList;

    private static PostManager instantiete;
    public static PostManager Instantiete{get{return instantiete;}}
    private Camera cam;

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
            if(initPost==null)
            {
                CreateInitBuffer();
            }
            return initPost;
        }
    }
    public RenderTexture DepthPost
    {
        get
        {
            if(depthPost==null)
            {
                CreateDepthBuffer();
            }
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
        cam=GetComponent<Camera>();
    }


    private void CreateCurrentBuffer()
    {
        currentPost=new RenderTexture(Screen.width,Screen.height,0,RenderTextureFormat.ARGB32);
        depthPost.enableRandomWrite=true;
        currentPost.Create();
    }
    private void CreateInitBuffer()
    {
        initPost=new RenderTexture(Screen.width,Screen.height,0,RenderTextureFormat.ARGB32);
        initPost.enableRandomWrite=true;
        initPost.Create();
    }
    private void CreateDepthBuffer()
    {
        depthPost=new RenderTexture(Screen.width,Screen.height,24);
        depthPost.enableRandomWrite=true;
        depthPost.Create();
        CommandBuffer buf =new CommandBuffer();
        buf.name="buffer";
        cam.AddCommandBuffer(CameraEvent.AfterDepthTexture,buf);
        buf.Clear();
        buf.Blit(BuiltinRenderTextureType.Depth,depthPost);
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest) 
    {
        initPost=src;       
        if(currentPost==null)
        {
            Graphics.Blit(initPost,dest);
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