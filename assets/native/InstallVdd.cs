using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

// Creates the same root-enumerated device as Device Manager's Add Legacy Hardware.
// Driver trust and package verification are performed by Windows SetupAPI.
public static class NativeVddInstall {
    [StructLayout(LayoutKind.Sequential)] struct DeviceInfo { public uint Size; public Guid ClassGuid; public uint DevInst; public IntPtr Reserved; }
    [DllImport("setupapi.dll",SetLastError=true)] static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid guid, IntPtr parent);
    [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiCreateDeviceInfo(IntPtr list,string name,ref Guid guid,string description,IntPtr parent,uint flags,ref DeviceInfo info);
    [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiSetDeviceRegistryProperty(IntPtr list,ref DeviceInfo info,uint property,byte[] data,uint size);
    [DllImport("setupapi.dll",SetLastError=true)] static extern bool SetupDiCallClassInstaller(uint function,IntPtr list,ref DeviceInfo info);
    [DllImport("setupapi.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SetupDiGetDeviceInstanceId(IntPtr list,ref DeviceInfo info,StringBuilder id,uint size,out uint needed);
    [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr list);
    [DllImport("newdev.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool UpdateDriverForPlugAndPlayDevices(IntPtr parent,string hardwareId,string inf,uint flags,out bool reboot);
    static void Check(bool success) { if(!success) throw new Win32Exception(Marshal.GetLastWin32Error()); }
    public static string Install(string inf) {
        Guid guid=new Guid("4d36e968-e325-11ce-bfc1-08002be10318");
        IntPtr list=SetupDiCreateDeviceInfoList(ref guid,IntPtr.Zero);
        if(list==new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
        DeviceInfo info=new DeviceInfo { Size=(uint)Marshal.SizeOf(typeof(DeviceInfo)) };
        bool registered=false;
        try {
            Check(SetupDiCreateDeviceInfo(list,"Display",ref guid,"Virtual Display Driver",IntPtr.Zero,1,ref info));
            byte[] id=Encoding.Unicode.GetBytes("Root\\MttVDD\0\0");
            Check(SetupDiSetDeviceRegistryProperty(list,ref info,1,id,(uint)id.Length));
            Check(SetupDiCallClassInstaller(0x19,list,ref info)); registered=true;
            bool reboot;
            Check(UpdateDriverForPlugAndPlayDevices(IntPtr.Zero,"Root\\MttVDD",inf,0,out reboot));
            StringBuilder instance=new StringBuilder(512); uint needed;
            Check(SetupDiGetDeviceInstanceId(list,ref info,instance,512,out needed));
            return instance.ToString()+"|RebootRequired="+reboot;
        } catch {
            if(registered) SetupDiCallClassInstaller(5,list,ref info);
            throw;
        } finally { SetupDiDestroyDeviceInfoList(list); }
    }
}
