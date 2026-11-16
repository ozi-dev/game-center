using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Web.Script.Serialization;
using System.Linq;

namespace SofaRelay {
 static class RuntimeIntegrity {
  static Dictionary<string,string> ExpectedFiles(){using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("SofaRelay.RuntimeHashes"))using(var reader=new StreamReader(stream)){return new JavaScriptSerializer().Deserialize<Dictionary<string,string>>(reader.ReadToEnd());}}
  public static string Expected(string name){return ExpectedFiles()[name];}
  sealed class HeldFiles:IDisposable {public readonly List<FileStream> Files=new List<FileStream>();public void Dispose(){foreach(var file in Files)file.Dispose();}}
  public static IDisposable LockVerified(string root){
   var expected=ExpectedFiles();var held=new HeldFiles();
   try{
    foreach(string path in Directory.GetFiles(Path.Combine(root,"scripts"),"*",SearchOption.AllDirectories)){
     string name=path.Substring(root.TrimEnd('\\').Length+1).Replace('\\','/');
     if(!name.StartsWith("scripts/maintainer/",StringComparison.OrdinalIgnoreCase)&&(path.EndsWith(".ps1",StringComparison.OrdinalIgnoreCase)||path.EndsWith(".psm1",StringComparison.OrdinalIgnoreCase))&&!expected.ContainsKey(name))throw new InvalidOperationException("An unexpected runtime script was found. Re-extract the official package.");
    }
    foreach(var item in expected){var file=new FileStream(Path.Combine(root,item.Key.Replace('/',Path.DirectorySeparatorChar)),FileMode.Open,FileAccess.Read,FileShare.Read);held.Files.Add(file);using(var sha=SHA256.Create())if(BitConverter.ToString(sha.ComputeHash(file)).Replace("-","").ToLowerInvariant()!=item.Value)throw new InvalidOperationException("Runtime integrity check failed: "+item.Key);}
    return held;
   }catch{held.Dispose();throw;}
  }
  public static void Verify(string root){foreach(var item in ExpectedFiles()){
   string path=Path.Combine(root,item.Key.Replace('/',Path.DirectorySeparatorChar));
   if(!File.Exists(path))throw new InvalidOperationException("A required SofaRelay file is missing: "+item.Key+". Extract or reinstall the complete official package.");
   using(var file=File.OpenRead(path))using(var sha=SHA256.Create()){string actual=BitConverter.ToString(sha.ComputeHash(file)).Replace("-","").ToLowerInvariant();if(actual!=item.Value)throw new InvalidOperationException("SofaRelay file verification failed: "+item.Key+". No setup action was started.");}
  }}
 }
}
