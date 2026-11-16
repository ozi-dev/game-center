using System;
using System.IO;
using System.Linq;
using System.Globalization;
using System.Collections.Generic;
using System.Web.Script.Serialization;

namespace SofaRelay {
 public static class I18n {
  public const string Version=BuildVersion.Value;
  public static readonly string[] Languages={"en","tr","fr","es"};
  static Dictionary<string,string> translations=new Dictionary<string,string>(StringComparer.Ordinal);
  static Dictionary<string,string> reverse=new Dictionary<string,string>(StringComparer.Ordinal);
  public static string Language="tr";
  public static string Resolve(string language) {
   string value=string.IsNullOrWhiteSpace(language)?"en":language.Split('-','_')[0].ToLowerInvariant();
   return Languages.Contains(value)?value:"en";
  }
  public static void Initialize(string root,string language) {
   Language=Resolve(language);var source=Read(Path.Combine(root,"locales","tr.json"));
   var english=Read(Path.Combine(root,"locales","en.json"));var selected=Read(Path.Combine(root,"locales",Language+".json"));
   var next=new Dictionary<string,string>(StringComparer.Ordinal);var back=new Dictionary<string,string>(StringComparer.Ordinal);
   foreach(var pair in source){string value;if(!selected.TryGetValue(pair.Key,out value)&&!english.TryGetValue(pair.Key,out value))value=pair.Value;next[pair.Value]=value;back[value]=pair.Value;}
   translations=next;reverse=back;
   var culture=new CultureInfo(PlayniteLanguage(Language).Replace('_','-'));
   CultureInfo.CurrentUICulture=culture;CultureInfo.CurrentCulture=culture;
  }
  static Dictionary<string,string> Read(string path){return File.Exists(path)?new JavaScriptSerializer().Deserialize<Dictionary<string,string>>(File.ReadAllText(path,System.Text.Encoding.UTF8).TrimStart('\ufeff')):new Dictionary<string,string>();}
  public static string L(string source){string value;return source!=null&&translations.TryGetValue(source,out value)?value:source;}
  public static string Source(string translated){string value;return translated!=null&&reverse.TryGetValue(translated,out value)?value:translated;}
  public static string F(string source,params object[] args){return args==null||args.Length==0?L(source):string.Format(CultureInfo.CurrentCulture,L(source),args);}
  public static string PlayniteLanguage(string language){switch(Resolve(language)){case "tr":return "tr_TR";case "fr":return "fr_FR";case "es":return "es_ES";default:return "en_US";}}
 }
}
