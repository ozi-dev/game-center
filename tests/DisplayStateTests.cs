using System;
using System.ComponentModel;

class DisplayStateTests {
    static int checks;
    static void Assert(bool condition,string message){checks++;if(!condition)throw new Exception(message);}
    static void Put(byte[] data,int offset,uint value){Array.Copy(BitConverter.GetBytes(value),0,data,offset,4);}
    static uint U(byte[] data,int offset){return BitConverter.ToUInt32(data,offset);}
    static SavedDisplayState Saved(){
        var paths=new byte[72];var modes=new byte[128];
        Put(paths,0,110);Put(paths,8,0);Put(paths,12,0);Put(paths,20,110);Put(paths,28,7);Put(paths,32,1);
        Put(paths,40,1);Put(paths,44,1);Put(paths,48,180);Put(paths,52,1);Put(paths,60,1);Put(paths,68,1);
        Put(modes,0,1);Put(modes,4,0);Put(modes,8,110);Put(modes,16,3440);Put(modes,20,1440);Put(modes,24,4);
        Put(modes,64,2);Put(modes,68,7);Put(modes,72,110);Put(modes,80,123456);
        var state=new SavedDisplayState {PathCount=1,ModeCount=2,PathsBase64=Convert.ToBase64String(paths),ModesBase64=Convert.ToBase64String(modes)};
        state.Displays.Add(new ScreenPath {Name="Test monitor",DevicePath="MONITOR-TEST-A",Active=true,Available=true,Primary=true,Width=3440,Height=1440,RefreshNumerator=180,RefreshDenominator=1});
        return state;
    }
    static SavedDisplayState Available(bool connected){
        var paths=new byte[144];
        for(int n=0;n<2;n++){int p=n*72;Put(paths,p,9009);Put(paths,p+8,(uint)(n+2));Put(paths,p+20,9009);Put(paths,p+28,(uint)(n+69));Put(paths,p+60,1);}
        var state=new SavedDisplayState {PathCount=2,ModeCount=0,PathsBase64=Convert.ToBase64String(paths),ModesBase64=""};
        state.Displays.Add(new ScreenPath {DevicePath="MONITOR-TEST-B",Available=true});
        state.Displays.Add(new ScreenPath {DevicePath="MONITOR-TEST-A",DisplayName="CURRENT-DISPLAY",Available=connected,TargetId=70});
        return state;
    }
    static int Main(){
        var old=Saved();string originalPaths=old.PathsBase64,originalModes=old.ModesBase64;
        var fixedState=NativeDisplayState.Rebind(old,Available(true));
        var p=Convert.FromBase64String(fixedState.PathsBase64);var m=Convert.FromBase64String(fixedState.ModesBase64);
        Assert(U(p,0)==9009&&U(p,20)==9009,"pre-reboot adapter identities replaced");
        Assert(U(p,8)==3&&U(p,28)==70,"current source and target IDs selected by device path");
        Assert(U(m,8)==9009&&U(m,72)==9009,"source and target mode adapters rebound");
        Assert(U(m,4)==3&&U(m,68)==70,"mode IDs match their new route");
        Assert(U(m,16)==3440&&U(m,20)==1440&&U(p,48)==180,"saved dimensions and refresh rate preserved");
        Assert(U(m,80)==123456,"saved signal timing preserved");
        Assert(fixedState.Displays[0].DisplayName=="CURRENT-DISPLAY"&&fixedState.Displays[0].Primary,"stable display identity and primary layout preserved");
        Assert(old.PathsBase64==originalPaths&&old.ModesBase64==originalModes,"original backup is immutable");
        bool missing=false;try{NativeDisplayState.Rebind(old,Available(false));}catch(Win32Exception ex){missing=ex.NativeErrorCode==1167;}
        Assert(missing,"disconnected physical display rejected instead of using another display");
        var invalid=Saved();var bytes=Convert.FromBase64String(invalid.PathsBase64);Put(bytes,12,500);invalid.PathsBase64=Convert.ToBase64String(bytes);
        bool malformed=false;try{NativeDisplayState.Rebind(invalid,Available(true));}catch(ArgumentException){malformed=true;}
        Assert(malformed,"invalid saved mode references rejected");
        old.Displays[0].DevicePath="";bool unnamed=false;try{NativeDisplayState.Rebind(old,Available(true));}catch(ArgumentException){unnamed=true;}
        Assert(unnamed,"a stable monitor identity is required");
        Console.WriteLine("PASS "+checks+" display identity/reboot recovery assertions; no display changes performed");return 0;
    }
}
