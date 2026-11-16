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
}
