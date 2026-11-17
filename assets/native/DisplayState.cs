using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public class ScreenPath {
    public string Name, DevicePath, DisplayName;
    public bool Active, Available, Primary;
    public uint TargetId, Width, Height, RefreshNumerator, RefreshDenominator;
    public int X, Y;
}
public class SavedDisplayState {
    public uint PathCount, ModeCount;
    public string PathsBase64, ModesBase64;
    public List<ScreenPath> Displays = new List<ScreenPath>();
}
public static class NativeDisplayState {
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
    [DllImport("shcore.dll")] static extern int GetScaleFactorForMonitor(IntPtr monitor, out int scale);
    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint paths, out uint modes);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint paths, IntPtr pathData, ref uint modes, IntPtr modeData, IntPtr topology);
    [DllImport("user32.dll")] static extern int DisplayConfigGetDeviceInfo(IntPtr request);
    [DllImport("user32.dll")] static extern int SetDisplayConfig(uint paths, byte[] pathData, uint modes, byte[] modeData, uint flags);
    static uint U(byte[] data, int offset) { return BitConverter.ToUInt32(data, offset); }
    static int I(byte[] data, int offset) { return BitConverter.ToInt32(data, offset); }
    public static int PrimaryScale() {
        int scale;
        int rc=GetScaleFactorForMonitor(MonitorFromWindow(IntPtr.Zero,1),out scale);
        if(rc!=0) Marshal.ThrowExceptionForHR(rc);
        return scale;
    }
    static string DeviceName(byte[] path, int offset, uint id, bool target) {
        int size = target ? 420 : 84;
        byte[] req = new byte[size];
        Array.Copy(BitConverter.GetBytes(target ? 2u : 1u), 0, req, 0, 4);
        Array.Copy(BitConverter.GetBytes(size), 0, req, 4, 4);
        Array.Copy(path, offset, req, 8, 8);
        Array.Copy(BitConverter.GetBytes(id), 0, req, 16, 4);
        IntPtr mem = Marshal.AllocHGlobal(size);
        try {
            Marshal.Copy(req, 0, mem, size);
            int rc = DisplayConfigGetDeviceInfo(mem);
            if (rc != 0) return "";
            Marshal.Copy(mem, req, 0, size);
            if (!target) return Encoding.Unicode.GetString(req, 20, 64).TrimEnd('\0');
            return Encoding.Unicode.GetString(req, 36, 128).TrimEnd('\0') + "\n" + Encoding.Unicode.GetString(req, 164, 256).TrimEnd('\0');
        } finally { Marshal.FreeHGlobal(mem); }
    }
    public static SavedDisplayState Capture(bool onlyActive) {
        uint flags = onlyActive ? 2u : 1u;
        for (int attempt = 0; attempt < 5; attempt++) {
            uint pc, mc;
            int rc = GetDisplayConfigBufferSizes(flags, out pc, out mc);
            if (rc != 0) throw new Win32Exception(rc);
            IntPtr pp = Marshal.AllocHGlobal((int)pc * 72), mp = Marshal.AllocHGlobal((int)mc * 64);
            try {
                rc = QueryDisplayConfig(flags, ref pc, pp, ref mc, mp, IntPtr.Zero);
                if (rc == 122) continue;
                if (rc != 0) throw new Win32Exception(rc);
                byte[] paths = new byte[pc * 72], modes = new byte[mc * 64];
                Marshal.Copy(pp, paths, 0, paths.Length);
                Marshal.Copy(mp, modes, 0, modes.Length);
                SavedDisplayState state = new SavedDisplayState { PathCount=pc, ModeCount=mc, PathsBase64=Convert.ToBase64String(paths), ModesBase64=Convert.ToBase64String(modes) };
                for (int n=0; n<pc; n++) {
                    int p=n*72;
                    string[] target = DeviceName(paths, p+20, U(paths,p+28), true).Split('\n');
                    ScreenPath s = new ScreenPath { Name=target[0], DevicePath=target.Length>1 ? target[1] : "", DisplayName=DeviceName(paths,p,U(paths,p+8),false), Active=(U(paths,p+68)&1)!=0, Available=U(paths,p+60)!=0, TargetId=U(paths,p+28), RefreshNumerator=U(paths,p+48), RefreshDenominator=U(paths,p+52) };
                    uint mode=U(paths,p+12);
                    if (mode < mc && U(modes,(int)mode*64)==1) {
                        int m=(int)mode*64;
                        s.Width=U(modes,m+16); s.Height=U(modes,m+20); s.X=I(modes,m+28); s.Y=I(modes,m+32); s.Primary=s.Active && s.X==0 && s.Y==0;
                    }
                    state.Displays.Add(s);
                }
                return state;
            } finally { Marshal.FreeHGlobal(pp); Marshal.FreeHGlobal(mp); }
        }
        throw new Exception("Display topology changed repeatedly during capture");
    }
    public static int Apply(uint paths, string pathData, uint modes, string modeData, bool validateOnly, bool allowChanges) {
        byte[] p=Convert.FromBase64String(pathData), m=Convert.FromBase64String(modeData);
        if (p.Length!=paths*72 || m.Length!=modes*64 || paths==0) throw new ArgumentException("Invalid display snapshot");
        uint flags=validateOnly ? 0x60u : 0x2a0u;
        if (allowChanges) flags |= 0x400u;
        return SetDisplayConfig(paths,p,modes,m,flags);
    }

    // Adapter LUIDs and source IDs are session identities. Rebind a saved layout
    // to the currently enumerated paths instead of replaying pre-reboot bytes.
    // This method is pure so hotplug/reboot behavior can be tested without a GPU.
    public static SavedDisplayState Rebind(SavedDisplayState saved, SavedDisplayState available) {
        if(saved==null||available==null||saved.Displays==null||available.Displays==null||saved.PathCount==0||saved.Displays.Count!=saved.PathCount||available.Displays.Count!=available.PathCount)
            throw new ArgumentException("Invalid display snapshot metadata");
        byte[] paths=Convert.FromBase64String(saved.PathsBase64),modes=Convert.FromBase64String(saved.ModesBase64),fresh=Convert.FromBase64String(available.PathsBase64);
        if(paths.LongLength!=saved.PathCount*72L||modes.LongLength!=saved.ModeCount*64L||fresh.LongLength!=available.PathCount*72L)
            throw new ArgumentException("Invalid display snapshot length");
        var assigned=new Dictionary<string,string>();
        var used=new HashSet<string>();
        var screens=new List<ScreenPath>();
        for(int n=0;n<saved.Displays.Count;n++) {
            var screen=saved.Displays[n];
            if(screen==null||string.IsNullOrWhiteSpace(screen.DevicePath))throw new ArgumentException("A saved display has no stable device path");
            int path=n*72,selected=-1;
            string original=SourceKey(paths,path),required;
            assigned.TryGetValue(original,out required);
            // Prefer an already active route, then another valid unused source.
            for(int pass=0;pass<2&&selected<0;pass++)for(int j=0;j<available.Displays.Count;j++) {
                var candidate=available.Displays[j];
                if(!candidate.Available||!screen.DevicePath.Equals(candidate.DevicePath,StringComparison.OrdinalIgnoreCase)||(pass==0&&!candidate.Active))continue;
                string key=SourceKey(fresh,j*72);
                if(required!=null?key!=required:used.Contains(key))continue;
                selected=j*72;break;
            }
            if(selected<0)throw new Win32Exception(1167,"A saved display is disconnected or has no compatible current route");
            string chosen=SourceKey(fresh,selected);
            assigned[original]=chosen;used.Add(chosen);
            Array.Copy(fresh,selected,paths,path,12);
            Array.Copy(fresh,selected+20,paths,path+20,12);
            WriteU(paths,path+60,1);WriteU(paths,path+68,U(paths,path+68)|1);
            RebindMode(modes,saved.ModeCount,U(paths,path+12),1,paths,path,U(paths,path+8));
            RebindMode(modes,saved.ModeCount,U(paths,path+32),2,paths,path+20,U(paths,path+28));
            screens.Add(new ScreenPath {Name=screen.Name,DevicePath=screen.DevicePath,DisplayName=available.Displays[selected/72].DisplayName,Active=true,Available=true,Primary=screen.Primary,TargetId=U(paths,path+28),Width=screen.Width,Height=screen.Height,RefreshNumerator=screen.RefreshNumerator,RefreshDenominator=screen.RefreshDenominator,X=screen.X,Y=screen.Y});
        }
        return new SavedDisplayState {PathCount=saved.PathCount,ModeCount=saved.ModeCount,PathsBase64=Convert.ToBase64String(paths),ModesBase64=Convert.ToBase64String(modes),Displays=screens};
    }
    static string SourceKey(byte[] data,int offset) {return U(data,offset)+":"+U(data,offset+4)+":"+U(data,offset+8);}
    static void WriteU(byte[] data,int offset,uint value) {Array.Copy(BitConverter.GetBytes(value),0,data,offset,4);}
    static void RebindMode(byte[] modes,uint count,uint index,uint kind,byte[] paths,int adapter,uint id) {
        if(index>=count||U(modes,(int)index*64)!=kind)throw new ArgumentException("Invalid saved display mode reference");
        int offset=(int)index*64;
        WriteU(modes,offset+4,id);Array.Copy(paths,adapter,modes,offset+8,8);
    }
    public static int Restore(SavedDisplayState saved,bool validateOnly) {
        SavedDisplayState current;
        try {current=Rebind(saved,Capture(false));}catch(Win32Exception ex){return ex.NativeErrorCode;}
        // Force a real driver mode set and persist the repaired layout. Missing
        // monitors are rejected before this call, never replaced by another output.
        return SetDisplayConfig(current.PathCount,Convert.FromBase64String(current.PathsBase64),current.ModeCount,Convert.FromBase64String(current.ModesBase64),validateOnly?0x460u:0x7a0u);
    }
}
