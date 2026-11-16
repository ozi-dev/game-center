using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Collections.Generic;
using System.Threading;
using System.Runtime.InteropServices;
using Accessibility;

public static class SteamTvInstall {
 delegate bool EnumProc(IntPtr h,IntPtr l);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback,IntPtr l);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder text,int n);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("oleacc.dll")] static extern int AccessibleObjectFromWindow(IntPtr h,uint id,ref Guid guid,[MarshalAs(UnmanagedType.Interface)] out IAccessible obj);
 [DllImport("oleacc.dll")] static extern int AccessibleChildren(IAccessible p,int start,int n,[Out,MarshalAs(UnmanagedType.LPArray,SizeParamIndex=2)] object[] children,out int obtained);
 class Node { public IAccessible Parent; public object Child; public string Name; public int Role; public int State; }
 static void Walk(IAccessible parent,int depth,List<Node> result) {
  if(depth>25 || result.Count>1800)return;
  try {
   result.Add(new Node {Parent=parent,Child=0,Name=parent.get_accName(0)??"",Role=Convert.ToInt32(parent.get_accRole(0)),State=Convert.ToInt32(parent.get_accState(0))});
   var n=parent.accChildCount; if(n>1800)return;
   var children=new object[n];int got;AccessibleChildren(parent,0,n,children,out got);
   for(int i=0;i<got;i++) {
    var child=children[i] as IAccessible;
    if(child!=null)Walk(child,depth+1,result);
    else if(children[i] is int)result.Add(new Node {Parent=parent,Child=children[i],Name=parent.get_accName(children[i])??"",Role=Convert.ToInt32(parent.get_accRole(children[i])),State=Convert.ToInt32(parent.get_accState(children[i]))});
   }
  }catch(COMException){}catch(InvalidCastException){}
 }
 static bool InstallName(string name) {return name=="Yükle" || name=="Install" || name=="INSTALL" || name=="YÜKLE";}
 public static bool TryConfirm(string expected,bool dryRun) {
  bool matched=false;
  EnumWindows((h,l)=>{
   var title=new StringBuilder(1024);GetWindowText(h,title,1024);
   if(!InstallName(title.ToString()))return true;
   try {
    uint pid;GetWindowThreadProcessId(h,out pid);
    if(Process.GetProcessById((int)pid).ProcessName!="steamwebhelper")return true;
    var guid=new Guid("618736E0-3C3D-11CF-810C-00AA00389B71"); IAccessible accessible;
    if(AccessibleObjectFromWindow(h,0xfffffffc,ref guid,out accessible)!=0 || accessible==null)return true;
    var nodes=new List<Node>();Walk(accessible,0,nodes);
    if(!nodes.Exists(n=>n.Name.Trim().Equals(expected.Trim(),StringComparison.OrdinalIgnoreCase)))return true;
    if(!nodes.Exists(n=>n.Role==43 && (n.Name=="İptal" || n.Name=="Cancel" || n.Name=="CANCEL")))return true;
    var button=nodes.Find(n=>n.Role==43 && InstallName(n.Name) && (n.State & 0x8001)==0);
    if(button==null)return true;
    if(!dryRun) {
     foreach(var check in nodes.FindAll(n=>n.Role==44 && (n.State & 16)!=0 && (n.Name=="Masaüstü kısayolu oluştur" || n.Name=="Başlat menüsünde kısayol oluştur" || n.Name=="Create desktop shortcut" || n.Name=="Create start menu shortcut")))check.Parent.accDoDefaultAction(check.Child);
     button.Parent.accDoDefaultAction(button.Child);
    }
    matched=true;
   }catch(COMException){}catch(InvalidOperationException){}
   return !matched;
  },IntPtr.Zero);
  return matched;
 }
 [STAThread] public static int Main(string[] args) {
  if(args.Length!=3 && args.Length!=4)return 2;
  var root=Path.GetDirectoryName(Path.GetDirectoryName(typeof(SteamTvInstall).Assembly.Location));
  var logDirectory=Path.Combine(root,"raporlar");
  try{Directory.CreateDirectory(logDirectory);}catch{logDirectory=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"OyunMerkezi","logs");Directory.CreateDirectory(logDirectory);}
  var title=Encoding.UTF8.GetString(Convert.FromBase64String(args[2]));
  bool dryRun=args.Length==4 && args[3]=="--probe";
  var deadline=DateTime.UtcNow.AddSeconds(dryRun?3:120);
  do {
   if(TryConfirm(title,dryRun)) {
    File.AppendAllText(Path.Combine(logDirectory,"steam-tv-kurulum.log"),DateTime.Now.ToString("s")+" | "+args[0]+" | "+(dryRun?"MATCHED (no download)":"INSTALL CONFIRMED")+Environment.NewLine);
    if(!dryRun)foreach(var p in Process.GetProcessesByName("Playnite.FullscreenApp"))if(p.MainWindowHandle!=IntPtr.Zero)SetForegroundWindow(p.MainWindowHandle);
    return 0;
   }
   Thread.Sleep(500);
  }while(DateTime.UtcNow<deadline);
  File.AppendAllText(Path.Combine(logDirectory,"steam-tv-kurulum.log"),DateTime.Now.ToString("s")+" | "+args[0]+" | No matching install dialog; no input sent"+Environment.NewLine);
  return 1;
 }
}
