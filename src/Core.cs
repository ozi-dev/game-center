using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Web.Script.Serialization;

namespace SofaRelay {
 public static class Branding {
  public const string Name="SofaRelay",AppFile="SofaRelay.exe",InstallerFile="Installer.exe";
  public static string SettingsPath(string applicationRoot,string localData) {
   string own=Path.Combine(applicationRoot,"data","settings.json");if(File.Exists(own))return own;
   foreach(string folder in new[]{"SofaRelay","OyunMerkezi"}){string candidate=Path.Combine(localData,folder,"data","settings.json");if(File.Exists(candidate))return candidate;}
   return own;
  }
 }
 public class EmulatorConfig {
  public string Name="", Kind="Switch", Executable="", RomDirectory="", DataDirectory="", CorePath="", Platform="Nintendo Switch", Arguments="-f -g \"{ImagePath}\"", Extensions="nup,nsp,xci";
  public bool ImportHistory=true, ScanSubfolders=true;
  public Dictionary<string,string> TitleMappings=new Dictionary<string,string>();
 }
 public class CenterSettings {
  public int SchemaVersion=3;
  public bool RecoveryWatchdog=true,LANOnly=true,RemoveOwnedComponents=false;
  public string UILanguage="";
  public string InstallRoot="", PlaynitePath="", SunshineDirectory="", ClientKind="Shield", DeviceAddress="", DisplayId="", VddDirectory=@"C:\VirtualDisplayDriver";
  public bool AutoInstallStoreClients=true, MouseKeyboard=true, SyncPlaytime=true, AutomaticCovers=true, SteamAutoInstall=true, EpicDirectInstall=true, ShowDesktop=true, ShowLibrary=true, PreserveExistingApps=true, VirtualDisplay=true, TurnOffPhysicalMonitor=true, RestoreDisplay=true, AutomaticDisplayMode=true, HDR=false, Gamepad=true;
  public int Width=3840, Height=2160, RefreshRate=60, BitrateMbps=60;
  public string[] Libraries=new string[]{"Steam","Epic","EA","Ubisoft"};
  public List<EmulatorConfig> Emulators=new List<EmulatorConfig>();
 }
 public class IntegrationConfig { public string SettingsPath="", RuntimeRoot="", SettingsApp=""; }
 public class RecoveryCheckpoint { public bool Pending;public int IdleSamples; }
 public static class RecoveryPolicy {
  public static bool Advance(RecoveryCheckpoint state,bool enabled,string stream,bool physicalMissing) {
   if(!enabled){state.Pending=false;state.IdleSamples=0;return false;}
   if(stream=="SUNSHINE_SERVER_BUSY"){state.Pending=true;state.IdleSamples=0;return false;}
   if(stream!="SUNSHINE_SERVER_FREE"&&stream!="NOT_RUNNING"){state.IdleSamples=0;return false;}
   if(!state.Pending&&!physicalMissing){state.IdleSamples=0;return false;}
   state.Pending=true;state.IdleSamples++;
   return state.IdleSamples>=3;
  }
 }
 public class MergeState { public ulong SourceSeconds, UnifiedSeconds; }
 public static class Data {
  public static JavaScriptSerializer Serializer() { return new JavaScriptSerializer { MaxJsonLength=16*1024*1024, RecursionLimit=60 }; }
  public static T Read<T>(string path) where T:new() { if(!File.Exists(path))return new T();return Serializer().Deserialize<T>(File.ReadAllText(path,Encoding.UTF8).TrimStart('\ufeff')); }
  public static void Write(string path,object value) {
   Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path)));
   string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
   File.WriteAllText(temp,Serializer().Serialize(value),new UTF8Encoding(false));
   if(File.Exists(path)){for(int attempt=0;;attempt++){try{File.Replace(temp,path,null,true);break;}catch(IOException){if(attempt>=24)throw;System.Threading.Thread.Sleep(80);}}}else File.Move(temp,path);
  }
  public static string Expand(string path) { return Environment.ExpandEnvironmentVariables(path??""); }
 }
 public static class Playtime {
  public static ulong Merge(ulong current,ulong source,MergeState state) {
   if(state==null)return Math.Max(current,source);
   ulong p=current>state.UnifiedSeconds?current-state.UnifiedSeconds:0;
   ulong e=source>=state.SourceSeconds?source-state.SourceSeconds:0;
   ulong increment=Math.Max(p,e);
   if(ulong.MaxValue-state.UnifiedSeconds<increment)throw new InvalidDataException("Playtime overflow");
   return Math.Max(current,state.UnifiedSeconds+increment);
  }
  public static Dictionary<string,ulong> ReadSwitch(string file) {
   var result=new Dictionary<string,ulong>(StringComparer.OrdinalIgnoreCase);
   using(var f=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete)) using(var r=new BinaryReader(f)) {
    if(f.Length%16!=0 || f.Length>16*1024*1024)throw new InvalidDataException("Incomplete or invalid emulator playtime file");
    while(f.Position<f.Length) { ulong id=r.ReadUInt64(),seconds=r.ReadUInt64();if(id!=0 && seconds<3155760000UL)result[id.ToString("X16")]=seconds; }
   }
   return result;
  }
  public static string TitleId(string rom) {
   if(Path.GetExtension(rom).Equals(".nup",StringComparison.OrdinalIgnoreCase) && File.Exists(rom)) {
    using(var f=File.OpenRead(rom))using(var r=new BinaryReader(f)) {
     if(f.Length>=128 && r.ReadUInt32()==0x0150554e) {
      f.Position=8;ulong toc=r.ReadUInt64();
      if(toc<=(ulong)f.Length-112) { f.Position=(long)toc;if(r.ReadUInt32()==0x01434f54){uint count=r.ReadUInt32();if(count>0 && count<1024){f.Position=(long)toc+48;return r.ReadUInt64().ToString("X16");}} }
     }
    }
   }
   var m=Regex.Match(Path.GetFileNameWithoutExtension(rom),@"(?<![0-9a-f])([0-9a-f]{16})(?![0-9a-f])",RegexOptions.IgnoreCase);
   return m.Success?m.Groups[1].Value.ToUpperInvariant():null;
  }
  public static ulong RetroArch(string logs,string rom) {
   string name=Path.GetFileNameWithoutExtension(rom)+".lrtl";
   string aggregate=Path.Combine(logs,name);
   var files=Directory.Exists(logs)?Directory.GetFiles(logs,name,SearchOption.AllDirectories):new string[0];
   ulong total=0,combined=0;
   foreach(string file in files) {
    var json=Data.Read<Dictionary<string,object>>(file);object raw;
    if(!json.TryGetValue("runtime",out raw))continue;
    var pieces=Convert.ToString(raw).Split(':');ulong h,m,s;
    if(pieces.Length==3 && ulong.TryParse(pieces[0],out h) && ulong.TryParse(pieces[1],out m) && ulong.TryParse(pieces[2],out s) && m<60 && s<60 && h<876000){ulong seconds=h*3600+m*60+s;if(string.Equals(Path.GetFullPath(file),Path.GetFullPath(aggregate),StringComparison.OrdinalIgnoreCase))combined=seconds;else total+=seconds;}
   }
   return Math.Max(total,combined);
  }
 }
 public static class Validation {
  public static List<string> Settings(CenterSettings settings) {
   var errors=new List<string>();
   if(settings.Width<640 || settings.Width>7680 || settings.Height<360 || settings.Height>4320)errors.Add(I18n.L("Çözünürlük 640×360–7680×4320 aralığında olmalı."));
   if(settings.RefreshRate<24 || settings.RefreshRate>240)errors.Add(I18n.L("Yenileme hızı 24–240 Hz aralığında olmalı."));
   if(settings.BitrateMbps<5 || settings.BitrateMbps>300)errors.Add(I18n.L("Bit hızı 5–300 Mbps aralığında olmalı."));
   if(settings.ClientKind=="Shield" && (settings.Width>2560 || settings.Height>1440) && settings.RefreshRate>60)errors.Add(I18n.L("Shield TV'nin HDMI 2.0b çıkışı 4K'da 60 Hz ile sınırlı. 4K60 seçin; daha yüksek Hz için desteklenen daha düşük çözünürlüğü kullanın."));
   if(settings.TurnOffPhysicalMonitor && !settings.VirtualDisplay)errors.Add(I18n.L("Fiziksel monitörü kapatmak için sanal ekran açık olmalı."));
   if(!settings.ShowDesktop && !settings.ShowLibrary)errors.Add(I18n.L("Moonlight için en az bir uygulama kutusu açık olmalı."));
   foreach(var e in settings.Emulators) {
    if(string.IsNullOrWhiteSpace(e.Name))errors.Add(I18n.L("Emülatör adı boş olamaz."));
    if(!string.IsNullOrWhiteSpace(e.Arguments) && !e.Arguments.Contains("{ImagePath}"))errors.Add(e.Name+I18n.L(": oyun komutunda {ImagePath} bulunmalı."));
   }
   return errors;
  }
 }
}
