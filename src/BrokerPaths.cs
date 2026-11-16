using System;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace SofaRelay.Security {
 public static class BrokerPaths {
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string name,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
  public static IDisposable PinRuntime(string runtime){
   NoLinks(runtime);string data=Path.Combine(runtime,"data");NoLinks(data);
   var handles=new System.Collections.Generic.List<SafeFileHandle>();
   try{foreach(string path in new[]{runtime,data}){var handle=CreateFile(path,0x80000000,1,IntPtr.Zero,3,0x02200000,IntPtr.Zero);if(handle.IsInvalid){handle.Dispose();throw new Win32Exception(Marshal.GetLastWin32Error());}handles.Add(handle);}NoLinks(data);return new DirectoryLease(handles);}catch{foreach(var handle in handles)handle.Dispose();throw;}
  }
  sealed class DirectoryLease:IDisposable {readonly System.Collections.Generic.List<SafeFileHandle> handles;public DirectoryLease(System.Collections.Generic.List<SafeFileHandle> value){handles=value;}public void Dispose(){foreach(var handle in handles)handle.Dispose();}}
  public static string ContainedFile(string root,string path) {
   string boundary=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
   string target=Path.GetFullPath(path);
   if(!target.StartsWith(boundary,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Path leaves its allowed directory.");
   NoLinks(target);
   return target;
  }
  public static void NoLinks(string path) {
   for(string part=Path.GetFullPath(path);!string.IsNullOrEmpty(part);part=Path.GetDirectoryName(part)) {
    try{if((File.GetAttributes(part)&FileAttributes.ReparsePoint)!=0)throw new InvalidOperationException("Reparse points are not accepted for privileged operations.");}catch(FileNotFoundException){}catch(DirectoryNotFoundException){}
    if(part==Path.GetPathRoot(part))break;
   }
  }
  public static string UserRuntime(string path,string sid) {
   if(string.IsNullOrWhiteSpace(path)||!Path.IsPathRooted(path)||path.StartsWith(@"\\"))throw new InvalidOperationException("Use an absolute local installation directory.");
   string root=Path.GetFullPath(path).TrimEnd('\\');
   if(root==Path.GetPathRoot(root).TrimEnd('\\')||!Directory.Exists(root))throw new InvalidOperationException("The user installation directory must already exist.");
   foreach(string blocked in new[]{Environment.GetFolderPath(Environment.SpecialFolder.Windows),Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData)}) {
    if(!string.IsNullOrEmpty(blocked)&&(root.Equals(blocked,StringComparison.OrdinalIgnoreCase)||root.StartsWith(blocked.TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException("A protected system directory cannot be used as user runtime storage.");
   }
   NoLinks(root);
   string owner=Directory.GetAccessControl(root).GetOwner(typeof(SecurityIdentifier)).Value;
   if(owner!=sid)throw new InvalidOperationException("The installation directory must be owned by the requesting Windows account.");
   return root;
  }
  public static string ResultFile(string runtime,string path) {
   string target=ContainedFile(Path.Combine(runtime,"data"),path);
   string name=Path.GetFileName(target);
   if(!System.Text.RegularExpressions.Regex.IsMatch(name,@"^broker-result-[a-fA-F0-9]{32}\.json$")||File.Exists(target))throw new InvalidOperationException("The result must be a new broker result file.");
   return target;
  }
  public static void ProtectDirectory(string path,string readerSid=null) {
   NoLinks(path);
   if(Directory.Exists(path)){
    string owner=Directory.GetAccessControl(path).GetOwner(typeof(SecurityIdentifier)).Value;
    if(owner!="S-1-5-32-544"&&owner!="S-1-5-18")throw new InvalidOperationException("A pre-existing broker/state directory is not administrator-owned. It was not taken over.");
    RequireAdminDirectory(path);
   }
   var acl=new DirectorySecurity();acl.SetAccessRuleProtection(true,false);
   var admins=new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null);
   acl.SetOwner(admins);
   foreach(var sid in new[]{admins,new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null)})acl.AddAccessRule(new FileSystemAccessRule(sid,FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
   var reader=readerSid==null?new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid,null):new SecurityIdentifier(readerSid);
   acl.AddAccessRule(new FileSystemAccessRule(reader,FileSystemRights.ReadAndExecute,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
   // Apply the restricted descriptor at creation, not after a writable interval.
   Directory.CreateDirectory(path,acl);NoLinks(path);
   string actualOwner=Directory.GetAccessControl(path).GetOwner(typeof(SecurityIdentifier)).Value;
   if(actualOwner!="S-1-5-32-544"&&actualOwner!="S-1-5-18")throw new InvalidOperationException("Protected directory ownership changed during creation.");
   Directory.SetAccessControl(path,acl);
  }
  public static void RequireAdminDirectory(string path) {
   NoLinks(path);
   if(!Directory.Exists(path))throw new InvalidOperationException("A protected component directory is missing.");
   var acl=Directory.GetAccessControl(path);
   string owner=acl.GetOwner(typeof(SecurityIdentifier)).Value;
   if(owner!="S-1-5-32-544"&&owner!="S-1-5-18")throw new InvalidOperationException("A component directory is not administrator-owned. Review its installation and permissions manually.");
   const FileSystemRights writes=FileSystemRights.Write|FileSystemRights.Delete|FileSystemRights.DeleteSubdirectoriesAndFiles|FileSystemRights.ChangePermissions|FileSystemRights.TakeOwnership;
   foreach(FileSystemAccessRule rule in acl.GetAccessRules(true,true,typeof(SecurityIdentifier)))if(rule.AccessControlType==AccessControlType.Allow&&(rule.FileSystemRights&writes)!=0&&rule.IdentityReference.Value!="S-1-5-32-544"&&rule.IdentityReference.Value!="S-1-5-18")throw new InvalidOperationException("A component directory grants write access outside administrators/SYSTEM. Fix its permissions manually before applying privileged configuration.");
  }
 }
}
