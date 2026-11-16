using System;
using System.IO;
using System.Diagnostics;
using System.Security.Cryptography;

namespace SofaRelay {
 static class BrokerLauncher {
  public static int Run(string root,string action,string request,string result) {
   string requestDirectory=Path.GetDirectoryName(Path.GetFullPath(result));
   Directory.CreateDirectory(requestDirectory);
   string snapshot=Path.Combine(requestDirectory,"broker-request-"+Guid.NewGuid().ToString("N")+".json");
   using(var output=new FileStream(snapshot,FileMode.CreateNew,FileAccess.Write,FileShare.None))using(var writer=new StreamWriter(output)){writer.Write(File.ReadAllText(request));}
   try {
   string installed=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"SofaRelay","Broker",I18n.Version,"SofaRelay.Broker.exe");
   string executable=File.Exists(installed)?installed:Path.Combine(root,"SofaRelay.Broker.exe");
   // Hold a read-only share until process creation has finished: prevent replacing
   // the verified helper during the UAC consent interval.
   using(var config=new FileStream(executable+".config",FileMode.Open,FileAccess.Read,FileShare.Read))
   using(var file=new FileStream(executable,FileMode.Open,FileAccess.Read,FileShare.Read)){
    string actual;using(var sha=SHA256.Create())actual=BitConverter.ToString(sha.ComputeHash(file)).Replace("-","").ToLowerInvariant();
    if(actual!=RuntimeIntegrity.Expected("SofaRelay.Broker.exe"))throw new InvalidOperationException("The privileged helper does not match this application build. Download and verify the complete official release.");
    using(var sha=SHA256.Create())if(BitConverter.ToString(sha.ComputeHash(config)).Replace("-","").ToLowerInvariant()!=RuntimeIntegrity.Expected("SofaRelay.Broker.exe.config"))throw new InvalidOperationException("The broker startup configuration failed verification.");
    var start=new ProcessStartInfo(executable,"--action "+WorkerRunner.Quote(action)+" --request "+WorkerRunner.Quote(snapshot)+" --result "+WorkerRunner.Quote(result)){UseShellExecute=true,Verb="runas",WindowStyle=ProcessWindowStyle.Hidden};
    using(var process=Process.Start(start)){process.WaitForExit();return process.ExitCode;}
   }
   }finally{File.Delete(snapshot);}
  }
 }
}
