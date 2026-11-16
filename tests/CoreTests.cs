using System;
using System.IO;
using OyunMerkezi;
class CoreTests {
 static int count;
 static void Eq(ulong a,ulong b,string name){count++;if(a!=b)throw new Exception(name+": "+a+" != "+b);}
 static void True(bool value,string name){count++;if(!value)throw new Exception(name);}
 static int Main(){
  Eq(Playtime.Merge(0,55829,null),55829,"initial history");
  Eq(Playtime.Merge(70000,55829,null),70000,"existing higher total");
  var state=new MergeState {SourceSeconds=100,UnifiedSeconds=150};
  Eq(Playtime.Merge(210,160,state),210,"overlapping session counted once");
  Eq(Playtime.Merge(150,160,state),210,"direct emulator session");
  Eq(Playtime.Merge(210,220,state),270,"direct plus launcher sessions");
  Eq(Playtime.Merge(150,100,state),150,"idempotent sync");
  Eq(Playtime.Merge(150,0,state),150,"source reset preserves history");
  var path=Path.Combine(Path.GetTempPath(),"gamecenter-test-"+Guid.NewGuid()+".bin");
  try{using(var f=File.Create(path))using(var w=new BinaryWriter(f)){w.Write(0x0100F2C0115B6000UL);w.Write(1020UL);}Eq(Playtime.ReadSwitch(path)["0100F2C0115B6000"],1020,"binary seconds");File.AppendAllText(path,"x");bool failed=false;try{Playtime.ReadSwitch(path);}catch(InvalidDataException){failed=true;}True(failed,"partial writes rejected");}finally{File.Delete(path);}
  True(Playtime.TitleId("TOTK [0100F2C0115B6000][v0].xci")=="0100F2C0115B6000","title filename");
  True(Playtime.TitleId("OOT [04004860224DEC000].nsp")==null,"invalid 17 digit id rejected");
  string logs=Path.Combine(Path.GetTempPath(),"gamecenter-runtime-"+Guid.NewGuid());Directory.CreateDirectory(Path.Combine(logs,"core"));
  try{File.WriteAllText(Path.Combine(logs,"core","test.lrtl"),"{\"runtime\":\"0:02:00\"}");File.WriteAllText(Path.Combine(logs,"test.lrtl"),"{\"runtime\":\"0:01:00\"}");Eq(Playtime.RetroArch(logs,"test.n64"),120,"new aggregate preserves old core time");File.WriteAllText(Path.Combine(logs,"test.lrtl"),"{\"runtime\":\"0:03:00\"}");Eq(Playtime.RetroArch(logs,"test.n64"),180,"aggregate and cores never double counted");}finally{Directory.Delete(logs,true);}
  var settings=new CenterSettings();settings.RefreshRate=120;True(Validation.Settings(settings).Count>0,"Shield cannot 4K120");settings.Width=1920;settings.Height=1080;True(Validation.Settings(settings).Count==0,"Shield lower resolution high refresh");
  Console.WriteLine("PASS "+count+" core assertions");return 0;
 }
}
