using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Diagnostics;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Playnite.SDK;
using Playnite.SDK.Models;
using Playnite.SDK.Plugins;
using Playnite.SDK.Events;

namespace OyunMerkezi {
 [LoadPlugin]
 public class CenterPlugin : GenericPlugin {
  public override Guid Id { get { return new Guid("15378b45-7634-47ed-8570-69ad2d7a9067"); } }
  readonly string pluginDirectory;
  readonly string stateFile;
  IntegrationConfig integration;
  CenterSettings settings;
  Dictionary<string,MergeState> states;
  DispatcherTimer timer;
  readonly HashSet<Guid> launchedHelpers=new HashSet<Guid>();
  public CenterPlugin(IPlayniteAPI api):base(api) {
   Properties=new GenericPluginProperties { HasSettings=true };
   pluginDirectory=Path.GetDirectoryName(typeof(CenterPlugin).Assembly.Location);
   stateFile=Path.Combine(GetPluginUserDataPath(),"playtime-state.json");
   Reload();
   states=Data.Read<Dictionary<string,MergeState>>(stateFile);
   api.Database.Games.ItemUpdated+=(s,e)=>{
    foreach(var item in e.UpdatedItems) {
     var game=item.NewData;
     if(settings.SteamAutoInstall && game.PluginId==new Guid("cb91dfc9-b977-43bf-8e70-55f46e410fab") && game.IsInstalling && !item.OldData.IsInstalling && System.Text.RegularExpressions.Regex.IsMatch(game.GameId??"","^[0-9]+$"))StartSteamHelper(game);
    }
   };
  }
  void Reload() {
   integration=Data.Read<IntegrationConfig>(Path.Combine(pluginDirectory,"center-integration.json"));
   settings=Data.Read<CenterSettings>(Data.Expand(integration.SettingsPath));
   I18n.Initialize(integration.RuntimeRoot,settings.UILanguage);
  }
  void StartSteamHelper(Game game) {
   if(!launchedHelpers.Add(game.Id))return;
   try {
    if(Process.GetProcessesByName("steam").Length==0){var exe=Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Valve\Steam","SteamExe",null) as string;if(File.Exists(exe))Process.Start(new ProcessStartInfo(exe,"-silent -cef-force-accessibility"){UseShellExecute=false,CreateNoWindow=true});}
    string helper=Path.Combine(integration.RuntimeRoot,"araclar","SteamTvInstall.exe");
    if(!File.Exists(helper))helper=Path.Combine(pluginDirectory,"SteamTvInstall.exe");
    string title=Convert.ToBase64String(Encoding.UTF8.GetBytes(game.Name));
    var p=Process.Start(new ProcessStartInfo(helper,game.GameId+" "+game.Id+" "+title){UseShellExecute=false,CreateNoWindow=true});
    Task.Run(()=>{p.WaitForExit();Dispatch(()=>launchedHelpers.Remove(game.Id));});
   }catch(Exception ex){launchedHelpers.Remove(game.Id);LogManager.GetLogger().Error(ex,"Oyun Merkezi Steam helper");}
  }
  void Dispatch(Action action){var app=Application.Current;if(app!=null && !app.Dispatcher.HasShutdownStarted){if(app.Dispatcher.CheckAccess())action();else app.Dispatcher.BeginInvoke(action);}}
  public override void OnApplicationStarted(OnApplicationStartedEventArgs args) {
   Sync();
   timer=new DispatcherTimer {Interval=TimeSpan.FromSeconds(60)};timer.Tick+=(s,e)=>Sync();timer.Start();
  }
  public override void OnLibraryUpdated(OnLibraryUpdatedEventArgs args){Dispatch(Sync);}
  public override async void OnGameStopped(OnGameStoppedEventArgs args){await Task.Delay(1800);Dispatch(Sync);}
  public override void OnApplicationStopped(OnApplicationStoppedEventArgs args){if(timer!=null)timer.Stop();Sync();}
  public override IEnumerable<MainMenuItem> GetMainMenuItems(GetMainMenuItemsArgs args) {
   yield return new MainMenuItem {MenuSection=I18n.L("Oyun Merkezi"),Description="Ayarlar ve kurulum",Action=a=>OpenSettings()};
   yield return new MainMenuItem {MenuSection=I18n.L("Oyun Merkezi"),Description=I18n.L("Emülatör sürelerini eşitle"),Action=a=>Sync()};
  }
  void OpenSettings(){try{if(File.Exists(integration.SettingsApp))Process.Start(new ProcessStartInfo(integration.SettingsApp,"--settings --config \""+integration.SettingsPath+"\""){UseShellExecute=true});else PlayniteApi.Dialogs.ShowMessage(I18n.L("Oyun Merkezi kurulum klasöründeki OyunMerkezi.exe dosyasını açın."));}catch(Exception ex){PlayniteApi.Dialogs.ShowErrorMessage(ex.Message,I18n.L("Oyun Merkezi"));}}
  public override UserControl GetSettingsView(bool firstRunSettings) {
   var panel=new StackPanel {Margin=new Thickness(20)};
   panel.Children.Add(new TextBlock {Text=I18n.L("Oyun Merkezi ayarları"),FontSize=22,Margin=new Thickness(0,0,0,12)});
   var button=new Button {Content=I18n.L("Ayarları aç"),Padding=new Thickness(15,8,15,8),HorizontalAlignment=HorizontalAlignment.Left};button.Click+=(s,e)=>OpenSettings();panel.Children.Add(button);
   var sync=new Button {Content=I18n.L("Süreleri şimdi eşitle"),Margin=new Thickness(0,12,0,0),Padding=new Thickness(15,8,15,8),HorizontalAlignment=HorizontalAlignment.Left};sync.Click+=(s,e)=>Sync();panel.Children.Add(sync);
   return new UserControl {Content=panel};
  }
  public override ISettings GetSettings(bool firstRunSettings){return new PluginSettings();}
  class PluginSettings:ISettings {
   public void BeginEdit(){} public void EndEdit(){} public void CancelEdit(){}
   public bool VerifySettings(out List<string> errors){errors=new List<string>();return true;}
  }
  EmulatorConfig SourceFor(Game game) {
   foreach(var source in settings.Emulators) {
    if(!source.ImportHistory)continue;
    if(game.Source!=null && string.Equals(game.Source.Name,source.Name,StringComparison.OrdinalIgnoreCase))return source;
    if(game.GameActions==null)continue;
    foreach(var action in game.GameActions)if(action.Type==GameActionType.Emulator){var emu=PlayniteApi.Database.Emulators.Get(action.EmulatorId);if(emu!=null && string.Equals(emu.Name,source.Name,StringComparison.OrdinalIgnoreCase))return source;}
   }
   return null;
  }
  public void Sync() {
   try {
    Reload();
    var report=new List<object>();
    foreach(var game in PlayniteApi.Database.Games.ToList()) {
     if(game.Roms==null || game.Roms.Count==0)continue;
     try {
      if(settings.AutomaticCovers)Artwork.Fill(PlayniteApi,game,Path.Combine(GetPluginUserDataPath(),"covers"));
      if(!settings.SyncPlaytime || game.IsRunning || game.IsLaunching)continue;
      var source=SourceFor(game);if(source==null)continue;
      string rom=game.Roms.First().Path,data=Data.Expand(source.DataDirectory),key=game.Id.ToString();ulong seconds=0;
      if(source.Kind=="RetroArch") {
       string logs=Path.Combine(data,"playlists","logs");
       string cfg=Path.Combine(data,"retroarch.cfg");
       if(File.Exists(cfg))foreach(string line in File.ReadLines(cfg)){var m=System.Text.RegularExpressions.Regex.Match(line,"^runtime_log_directory\\s*=\\s*\"([^\"]+)\"");if(m.Success && m.Groups[1].Value!="default"){string folder=m.Groups[1].Value;logs=folder.StartsWith(":\\")?Path.Combine(data,folder.Substring(2)):Data.Expand(folder);}}
       seconds=Playtime.RetroArch(logs,rom);
      } else if(source.Kind=="Switch") {
       string id; if(!source.TitleMappings.TryGetValue(rom,out id))id=Playtime.TitleId(rom);
       string file=Path.Combine(data,"play_time","playtime.bin");
       if(string.IsNullOrEmpty(id) || !File.Exists(file))continue;
       var times=Playtime.ReadSwitch(file);if(!times.TryGetValue(id,out seconds))continue;
      }else continue;
      MergeState state;states.TryGetValue(key,out state);
      ulong before=game.Playtime,after=Playtime.Merge(before,seconds,state);
      if(after!=before){game.Playtime=after;PlayniteApi.Database.Games.Update(game);}
      states[key]=new MergeState {SourceSeconds=seconds,UnifiedSeconds=after};
      report.Add(new {Game=game.Name,Id=key,Source=source.Name,Before=before,SourceSeconds=seconds,TotalSeconds=after});
     }catch(Exception ex){LogManager.GetLogger().Warn(ex,"Oyun Merkezi could not read emulated history for "+game.Id);}
    }
    Data.Write(stateFile,states);
    Data.Write(Path.Combine(GetPluginUserDataPath(),"last-sync.json"),new {Time=DateTime.UtcNow,Games=report});
   }catch(Exception ex){LogManager.GetLogger().Error(ex,"Oyun Merkezi synchronization");}
  }
 }
}
