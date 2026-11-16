using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Collections.Generic;
using System.IO.Compression;
using System.Web.Script.Serialization;
using SofaRelay.Security;

static class PrivilegedBroker {
 static readonly JavaScriptSerializer Json=new JavaScriptSerializer {MaxJsonLength=4*1024*1024};
 static string Hash(byte[] bytes){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
 static byte[] Resource(string name){using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream(name)){if(stream==null)throw new InvalidOperationException("Missing embedded broker resource.");using(var memory=new MemoryStream()){stream.CopyTo(memory);return memory.ToArray();}}}
 static string Quote(string value){return "\""+System.Text.RegularExpressions.Regex.Replace(System.Text.RegularExpressions.Regex.Replace(value,@"(\\*)""","$1$1\\\""),@"(\\+)$","$1$1")+"\"";}
 static Dictionary<string,string> Arguments(string[] args){var values=new Dictionary<string,string>();for(int i=0;i<args.Length;i+=2){if(i+1>=args.Length||!new[]{"--action","--request","--result"}.Contains(args[i])||values.ContainsKey(args[i]))throw new ArgumentException("Invalid broker arguments.");values.Add(args[i],args[i+1]);}if(values.Count!=3)throw new ArgumentException("Incomplete broker arguments.");return values;}
 static void VerifyEntry(string name){if(string.IsNullOrEmpty(name)||name.Contains(":")||name.Contains("..")||name.StartsWith("/")||name.StartsWith("\\"))throw new InvalidOperationException("Invalid embedded payload path.");}
 static int Main(string[] args) {
  string result=null;IDisposable runtimeLease=null;System.Threading.Mutex operationMutex=null;bool locked=false;
  try {
   byte[] bytes=Resource("SofaRelay.Broker.Payload");
   if(Hash(bytes)!=BrokerBuild.PayloadHash)throw new InvalidOperationException("Embedded broker payload integrity check failed.");
   using(var zip=new ZipArchive(new MemoryStream(bytes),ZipArchiveMode.Read))foreach(var entry in zip.Entries)VerifyEntry(entry.FullName);
   if(args.SequenceEqual(new[]{"--selftest"})){Console.WriteLine("PASS embedded broker payload and path checks");return 0;}
   if(!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator))throw new InvalidOperationException("The broker requires Windows administrator consent.");
   var options=Arguments(args);string action=options["--action"];
   if(!new[]{"ProtectedApply","ProtectedRestore","ProtectedUninstall"}.Contains(action))throw new InvalidOperationException("Unsupported privileged action.");
   string request=Path.GetFullPath(options["--request"]);BrokerPaths.NoLinks(request);
   if(new FileInfo(request).Length>1024*1024)throw new InvalidOperationException("The settings request is too large.");
   var settings=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(request));
   // Bind requests to the kernel-reported owner, including UAC flows where a
   // standard account supplies a different administrator's credentials.
   string sid=File.GetAccessControl(request).GetOwner(typeof(SecurityIdentifier)).Value;
   string runtime=BrokerPaths.UserRuntime(Convert.ToString(settings["InstallRoot"]),sid);
   runtimeLease=BrokerPaths.PinRuntime(runtime);
   result=BrokerPaths.ResultFile(runtime,options["--result"]);
   string vdd=Convert.ToString(settings["VddDirectory"]);
   if(!Path.GetFullPath(vdd).TrimEnd('\\').Equals(@"C:\VirtualDisplayDriver",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Privileged VDD configuration is restricted to C:\\VirtualDisplayDriver. Configure other driver locations manually.");
   BrokerPaths.NoLinks(vdd);
   foreach(string field in new[]{"DisplayId","PlaynitePath","SunshineDirectory"})if(settings.ContainsKey(field)&&Convert.ToString(settings[field]).Any(char.IsControl))throw new InvalidOperationException("Control characters are not allowed in settings paths or identifiers.");
   string protectedRoot=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"SofaRelay","Broker",BrokerBuild.Version);
   operationMutex=new System.Threading.Mutex(false,"Global\\SofaRelayBroker-"+Hash(System.Text.Encoding.UTF8.GetBytes(sid+runtime)).Substring(0,24));locked=operationMutex.WaitOne(0);if(!locked)throw new InvalidOperationException("Another privileged operation is still running for this installation.");
   BrokerPaths.ProtectDirectory(Path.GetDirectoryName(Path.GetDirectoryName(protectedRoot)));BrokerPaths.ProtectDirectory(Path.GetDirectoryName(protectedRoot));BrokerPaths.ProtectDirectory(protectedRoot);
   using(var zip=new ZipArchive(new MemoryStream(bytes),ZipArchiveMode.Read))foreach(var entry in zip.Entries){string target=BrokerPaths.ContainedFile(protectedRoot,Path.Combine(protectedRoot,entry.FullName));if(entry.FullName.EndsWith("/")){Directory.CreateDirectory(target);continue;}Directory.CreateDirectory(Path.GetDirectoryName(target));byte[] content;using(var input=entry.Open())using(var memory=new MemoryStream()){input.CopyTo(memory);content=memory.ToArray();}if(File.Exists(target)&&Hash(File.ReadAllBytes(target))==Hash(content))continue;File.WriteAllBytes(target,content);}
   string installedExe=Path.Combine(protectedRoot,"SofaRelay.Broker.exe");string own=Assembly.GetExecutingAssembly().Location;
   if(!Path.GetFullPath(own).Equals(installedExe,StringComparison.OrdinalIgnoreCase))File.Copy(own,installedExe,true);
   string key=Hash(System.Text.Encoding.UTF8.GetBytes(runtime.ToLowerInvariant())).Substring(0,24);
   string stateParent=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"SofaRelay");BrokerPaths.ProtectDirectory(stateParent);
   string state=Path.Combine(stateParent,sid+"-"+key);BrokerPaths.ProtectDirectory(state,sid);
   string identityFile=Path.Combine(state,"identity.json");
   if(File.Exists(identityFile)){var previous=Json.Deserialize<Dictionary<string,string>>(File.ReadAllText(identityFile));if(previous["RuntimeRoot"]!=runtime||previous["UserSid"]!=sid)throw new InvalidOperationException("Protected installation identity does not match.");}
   else File.WriteAllText(identityFile,Json.Serialize(new {RuntimeRoot=runtime,UserSid=sid}));
   string nonce=Guid.NewGuid().ToString("N"),requestCopy=Path.Combine(state,"request-"+nonce+".json"),privateResult=Path.Combine(state,"result-"+nonce+".json");
   File.WriteAllText(requestCopy,Json.Serialize(settings));
   string worker=Path.Combine(protectedRoot,"scripts","Worker.ps1");
   string[] parameters={"-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",worker,"-Action",action,"-SettingsPath",requestCopy,"-DataRoot",state,"-PackageRoot",protectedRoot,"-ResultPath",privateResult};
   var start=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe"),string.Join(" ",parameters.Select(Quote))){UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=protectedRoot};
   start.EnvironmentVariables["SOFARELAY_BROKER_ROOT"]=protectedRoot;start.EnvironmentVariables["SOFARELAY_USER_RUNTIME"]=runtime;start.EnvironmentVariables["SOFARELAY_REQUEST_USER_SID"]=sid;
   start.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\Modules")+";"+Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),@"WindowsPowerShell\Modules");
   start.EnvironmentVariables["PATH"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32");
   using(var process=Process.Start(start)){process.WaitForExit();byte[] report=File.Exists(privateResult)?File.ReadAllBytes(privateResult):System.Text.Encoding.UTF8.GetBytes(Json.Serialize(new {Success=false,Message="The protected worker did not return a result."}));BrokerPaths.NoLinks(Path.GetDirectoryName(result));Directory.CreateDirectory(Path.GetDirectoryName(result));using(var output=new FileStream(result,FileMode.CreateNew,FileAccess.Write,FileShare.None))output.Write(report,0,report.Length);return process.ExitCode;}
  }catch(Exception ex){Console.Error.WriteLine("SofaRelay broker: "+ex.Message);return 1;}
  finally{if(runtimeLease!=null)runtimeLease.Dispose();if(locked)operationMutex.ReleaseMutex();if(operationMutex!=null)operationMutex.Dispose();}
 }
}
