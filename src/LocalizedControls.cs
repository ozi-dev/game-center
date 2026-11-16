using System;
using System.Linq;
using System.Drawing;
using System.Collections.Generic;
using System.Windows.Forms;

namespace OyunMerkezi {
 public class LocalizedControls {
  readonly Dictionary<Control,string> originals=new Dictionary<Control,string>();
  readonly Dictionary<DataGridViewColumn,string> columns=new Dictionary<DataGridViewColumn,string>();
  public void Remember(Control control,IEnumerable<Control> exclude) {
   if(!exclude.Contains(control)&&(control is Form||control is Label||control is ButtonBase))originals[control]=I18n.Source(control.Text);
   var grid=control as DataGridView;if(grid!=null)foreach(DataGridViewColumn column in grid.Columns)columns[column]=I18n.Source(column.HeaderText);
   foreach(Control child in control.Controls)Remember(child,exclude);
  }
  public void Apply(){
   foreach(var pair in originals){if(pair.Key.IsDisposed)continue;pair.Key.Text=I18n.L(pair.Value);
    var button=pair.Key as Button;if(button!=null&&button.Dock==DockStyle.None){int available=Math.Max(60,button.Width-20);button.Height=Math.Max(38,TextRenderer.MeasureText(button.Text,button.Font,new Size(available,int.MaxValue),TextFormatFlags.WordBreak).Height+16);}
   }
   foreach(var pair in columns)pair.Key.HeaderText=I18n.L(pair.Value);
  }
 }
 public static class LocalizedMessage {
  public static DialogResult Show(string text,string caption="Game Center",MessageBoxButtons buttons=MessageBoxButtons.OK,MessageBoxIcon icon=MessageBoxIcon.None){return Show(null,text,caption,buttons,icon);}
  public static DialogResult Show(IWin32Window owner,string text,string caption="Game Center",MessageBoxButtons buttons=MessageBoxButtons.OK,MessageBoxIcon icon=MessageBoxIcon.None){
   using(var form=new Form {Text=caption,Font=new Font("Segoe UI",10),StartPosition=owner==null?FormStartPosition.CenterScreen:FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,MinimizeBox=false,MaximizeBox=false,ShowInTaskbar=false,BackColor=Color.FromArgb(24,34,49),ForeColor=Color.White,Width=720}){
    var label=new Label {Text=text,AutoSize=true,MaximumSize=new Size(650,0),Location=new Point(24,20)};form.Controls.Add(label);int contentHeight=Math.Min(550,label.GetPreferredSize(new Size(650,0)).Height);label.AutoSize=false;label.Size=new Size(650,contentHeight);form.ClientSize=new Size(700,contentHeight+100);
    var flow=new FlowLayoutPanel {Dock=DockStyle.Bottom,Height=62,FlowDirection=FlowDirection.RightToLeft,Padding=new Padding(12)};form.Controls.Add(flow);
    string[] labels=buttons==MessageBoxButtons.YesNo?new[]{I18n.L("Hayır"),I18n.L("Evet")}:new[]{I18n.L("Tamam")};
    for(int i=0;i<labels.Length;i++){var button=new Button {Text=labels[i],Width=125,Height=36,BackColor=Color.FromArgb(37,55,77),ForeColor=Color.White,FlatStyle=FlatStyle.Flat};button.DialogResult=buttons==MessageBoxButtons.YesNo?(i==0?DialogResult.No:DialogResult.Yes):DialogResult.OK;flow.Controls.Add(button);if(i==0)form.CancelButton=button;if(i==labels.Length-1)form.AcceptButton=button;}
    return owner==null?form.ShowDialog():form.ShowDialog(owner);
   }
  }
 }
}
