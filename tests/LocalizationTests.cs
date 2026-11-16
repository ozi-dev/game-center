using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using OyunMerkezi;
class LocalizationTests {
 static int checks;
 static void Assert(bool value,string message){checks++;if(!value)throw new Exception(message);}
 static string Tokens(string text){return string.Join(",",Regex.Matches(text,@"\{([a-zA-Z0-9]+)\}").Cast<Match>().Select(x=>x.Value).Distinct().OrderBy(x=>x));}
 static int Main(string[] args){
  string root=args.Length>0?args[0]:AppDomain.CurrentDomain.BaseDirectory;
  var source=Data.Read<Dictionary<string,string>>(Path.Combine(root,"locales","tr.json"));
  foreach(string language in I18n.Languages){
   var catalog=Data.Read<Dictionary<string,string>>(Path.Combine(root,"locales",language+".json"));
   Assert(catalog.Count==source.Count,language+" catalog size");
   foreach(var pair in source){Assert(catalog.ContainsKey(pair.Key)&&!string.IsNullOrWhiteSpace(catalog[pair.Key]),language+" missing "+pair.Key);Assert(Tokens(pair.Value)==Tokens(catalog[pair.Key]),language+" altered placeholders "+pair.Key);}
   I18n.Initialize(root,language);Assert(I18n.Language==language,"Selected language");
   Assert(I18n.F("{0} başlatıcısı denetleniyor.","Steam").Contains("Steam"),"Dynamic argument preserved");
   var invalid=new CenterSettings {Width=0};Assert(Validation.Settings(invalid).Count>0,"Translated validation still rejects invalid settings");
   if(language!="tr")Assert(I18n.L("Ayarları kaydet")!="Ayarları kaydet","Translated save button");
  }
  Assert(I18n.Resolve("fr-FR")=="fr"&&I18n.Resolve("es_ES")=="es"&&I18n.Resolve("xx")=="en","Language normalization");
  string file=Path.Combine(Path.GetTempPath(),"gamecenter-locale-"+Guid.NewGuid()+".json");try{var settings=new CenterSettings {UILanguage="es",InstallRoot=@"D:\Example",MouseKeyboard=false};Data.Write(file,settings);var loaded=Data.Read<CenterSettings>(file);Assert(loaded.UILanguage=="es"&&loaded.InstallRoot==settings.InstallRoot&&!loaded.MouseKeyboard,"Language persistence preserves preferences");}finally{File.Delete(file);}
  Console.WriteLine("PASS "+checks+" localization assertions");return 0;
 }
}
