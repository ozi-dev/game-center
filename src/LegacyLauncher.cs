using System;
using System.IO;
using System.Diagnostics;
using System.Linq;
using System.Text.RegularExpressions;
using System.Windows.Forms;
static class LegacyLauncher {
 static string Quote(string value){return "\""+Regex.Replace(Regex.Replace(value,@"(\\*)""","$1$1\\\""),@"(\\+)$","$1$1")+"\"";}
 [STAThread] static int Main(string[] args){
  string target=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"SofaRelay.exe");
  if(!File.Exists(target)){MessageBox.Show("SofaRelay.exe is missing. Extract the complete SofaRelay package or open Installer.exe to repair the installation.","SofaRelay");return 1;}
  try{using(var process=Process.Start(new ProcessStartInfo(target,string.Join(" ",args.Select(Quote))){UseShellExecute=false,WorkingDirectory=AppDomain.CurrentDomain.BaseDirectory})){process.WaitForExit();return process.ExitCode;}}catch(Exception ex){MessageBox.Show(ex.Message,"SofaRelay");return 1;}
 }
}
