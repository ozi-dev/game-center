using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using Playnite.SDK;using Playnite.SDK.Models;
namespace SofaRelay { public static class Artwork {
public static void Fill(IPlayniteAPI api,Game game,string output){
 if(game.Roms==null||game.Roms.Count==0||!string.IsNullOrEmpty(game.CoverImage))return;
 string rom=game.Roms[0].Path;byte[] icon=null;
 foreach(string ext in new[]{".cover.png",".cover.jpg"}){var path=Path.ChangeExtension(rom,ext);if(File.Exists(path)){icon=File.ReadAllBytes(path);break;}}
 if(icon==null&&Path.GetExtension(rom).Equals(".nup",StringComparison.OrdinalIgnoreCase))icon=ReadNupIcon(rom);
 if(icon==null)return;Directory.CreateDirectory(output);string file=Path.Combine(output,game.Id+".png");
 using(var stream=new MemoryStream(icon))using(var art=Image.FromStream(stream))using(var bmp=new Bitmap(600,800))using(var g=Graphics.FromImage(bmp)){
 g.Clear(Color.FromArgb(18,27,39));g.InterpolationMode=System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;float scale=Math.Min(600f/art.Width,600f/art.Height);float w=art.Width*scale,h=art.Height*scale;g.DrawImage(art,(600-w)/2,(600-h)/2,w,h);
 using(var font=new Font("Segoe UI",26,FontStyle.Bold))using(var brush=new SolidBrush(Color.White))using(var format=new StringFormat {Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center,Trimming=StringTrimming.EllipsisWord})g.DrawString(game.Name,font,brush,new RectangleF(28,615,544,160),format);bmp.Save(file,ImageFormat.Png);}
 game.CoverImage=api.Database.AddFile(file,game.Id);api.Database.Games.Update(game);
}
  public static byte[] ReadNupIcon(string path) {
   using(var f=File.OpenRead(path)) using(var r=new BinaryReader(f)) {
    if(f.Length<128) return null;
    if(r.ReadUInt32()!=0x0150554e) return null;
    f.Position=8; var toc=r.ReadUInt64();
    if(toc>(ulong)f.Length-48) return null;
    f.Position=(long)toc; if(r.ReadUInt32()!=0x01434f54) return null;
    var count=r.ReadUInt32(); if(count>1024 || toc+48+count*64>(ulong)f.Length) return null;
    byte[] fallback=null;
    for(uint i=0;i<count;i++) {
     f.Position=(long)toc+48+i*64+32;
     var offset=r.ReadUInt64(); var size=r.ReadUInt32();
     if(offset==0 || size==0 || size>16*1024*1024 || offset>(ulong)f.Length || size>(ulong)f.Length-offset) continue;
     f.Position=(long)offset; var end=(long)offset+size;
     while(f.Position+8<=end) {
      var tag=r.ReadUInt16(); r.ReadUInt16(); var length=r.ReadUInt32();
      if(length>end-f.Position) break;
      if(tag==3 && length>0) return r.ReadBytes((int)length);
      if(tag==10) {
       var payload=r.ReadBytes((int)length);
       using(var bytes=new MemoryStream(payload)) using(var localized=new BinaryReader(bytes)) {
        while(bytes.Position<bytes.Length) {
         var languageLength=localized.ReadByte();
         if(languageLength>bytes.Length-bytes.Position-4)break;
         var language=System.Text.Encoding.UTF8.GetString(localized.ReadBytes(languageLength));
         var dataLength=localized.ReadUInt32();
         if(dataLength>bytes.Length-bytes.Position)break;
         var data=localized.ReadBytes((int)dataLength);
         if(fallback==null || language=="en-us")fallback=data;
        }
       }
       continue;
      }
      f.Position+=length;
     }
    }
    return fallback;
   }
  }
}}
