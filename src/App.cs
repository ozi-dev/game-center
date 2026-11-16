using System;
using System.IO;
using System.Linq;
using System.Drawing;
using System.Diagnostics;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Web.Script.Serialization;

namespace SofaRelay {
 static class Program {
  [System.Runtime.InteropServices.DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
  [STAThread] static int Main(string[] args) {
   if(args.Contains("--preview"))SetThreadDpiAwarenessContext(new IntPtr(-1));
   Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
   string root=AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
   string settingsPath=Branding.SettingsPath(root,Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData));
   for(int i=0;i<args.Length-1;i++)if(args[i]=="--config")settingsPath=Path.GetFullPath(args[i+1]);
   string uiLanguage=Data.Read<CenterSettings>(settingsPath).UILanguage;
   for(int i=0;i<args.Length-1;i++)if(args[i]=="--language")uiLanguage=args[i+1];
   I18n.Initialize(root,uiLanguage);
   if(args.Contains("--recover")) {
    try{var s=Data.Read<CenterSettings>(settingsPath);string data=Path.Combine(string.IsNullOrEmpty(s.InstallRoot)?root:s.InstallRoot,"data");var result=WorkerRunner.Run(root,settingsPath,data,"Recover",null);if(!result.Success)LocalizedMessage.Show(result.Message,I18n.L("Ekranı geri getir"),MessageBoxButtons.OK,MessageBoxIcon.Warning);return result.Success?0:1;}catch(Exception ex){LocalizedMessage.Show(ex.Message,I18n.L("Ekranı geri getir"));return 1;}
   }
   try { using(var form=new CenterForm(root,settingsPath,args.Contains("--preview"))){
    if(args.Contains("--preview")){string folder=Path.Combine(root,"preview");for(int i=0;i<args.Length-1;i++)if(args[i]=="--preview")folder=Path.GetFullPath(args[i+1]);form.Shown+=(s,e)=>{form.SavePreviews(folder);form.Close();};}
    if(args.Contains("--selftest")){form.CreateControl();form.RunSelfTest();return 0;}
    Application.Run(form);return 0;
   }}catch(Exception ex){LocalizedMessage.Show(I18n.L("Uygulama açılamadı: ")+ex.Message+I18n.L("\nZIP dosyasını tüm dosyalarıyla bir klasöre çıkarıp yeniden deneyin."),I18n.L("SofaRelay"),MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
  }
 }
 public class WorkerResult { public bool Success;public string Message="";public Dictionary<string,object> Data; }
 public static class WorkerRunner {
  public static string Quote(string text){return "\""+System.Text.RegularExpressions.Regex.Replace(System.Text.RegularExpressions.Regex.Replace(text,@"(\\*)""","$1$1\\\""),@"(\\+)$","$1$1")+"\"";}
  public static WorkerResult Run(string root,string settingsPath,string dataRoot,string action,Action<string> log,int fps=60) {
   Directory.CreateDirectory(dataRoot);
   string resultFile=Path.Combine(dataRoot,"operation-"+Guid.NewGuid().ToString("N")+".json");
   string script=Path.Combine(root,"scripts","Worker.ps1");
   string[] args={"-NoProfile","-ExecutionPolicy","Bypass","-File",script,"-Action",action,"-SettingsPath",settingsPath,"-DataRoot",dataRoot,"-PackageRoot",root,"-ResultPath",resultFile,"-FPS",fps.ToString()};
   var psi=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe"),string.Join(" ",args.Select(Quote))){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=System.Text.Encoding.UTF8,StandardErrorEncoding=System.Text.Encoding.UTF8};
   using(var process=new Process {StartInfo=psi}) {
    process.OutputDataReceived+=(s,e)=>{if(e.Data!=null && log!=null)log(e.Data);};
    process.ErrorDataReceived+=(s,e)=>{if(e.Data!=null && log!=null)log(e.Data);};
    process.Start();process.BeginOutputReadLine();process.BeginErrorReadLine();process.WaitForExit();
    if(!File.Exists(resultFile))return new WorkerResult {Success=false,Message=I18n.L("İşçi işlem sonuç üretemedi. Günlükteki hata ve paket dosyalarını kontrol edin.")};
    return Data.Read<WorkerResult>(resultFile);
   }
  }
 }
 public class CenterForm : Form {
  readonly string root;
  string settingsPath;
  CenterSettings settings;
  readonly Panel content=new Panel();
  readonly Label heading=new Label(),status=new Label();
  readonly ProgressBar progress=new ProgressBar();
  readonly TextBox log=new TextBox();
  readonly List<Control> pages=new List<Control>();
  readonly List<Button> nav=new List<Button>();
  readonly ToolTip tips=new ToolTip();
  TextBox install,playnite,sunshine,ip,vdd;
  ComboBox client,display;
  readonly ComboBox languagePicker=new ComboBox();
  readonly LocalizedControls localized=new LocalizedControls();
  Dictionary<string,object> deviceData;
  bool previewMode;
  NumericUpDown width,height,hz,bitrate;
  CheckBox autoClients,mouse,history,covers,steam,epic,gamepad,desktopTile,libraryTile,preserve,virtualDisplay,monitorOff,restore,automatic,hdr;
  readonly CheckedListBox libraries=new CheckedListBox();
  readonly DataGridView emulators=new DataGridView();
  Label diagnosisText,deviceText,review;
  bool busy,initializing;
  int page;
  Dictionary<string,object> diagnosis;
  readonly Color background=Color.FromArgb(15,22,34),panelColor=Color.FromArgb(24,34,49),accent=Color.FromArgb(104,191,255);
  public CenterForm(string appRoot,string config,bool quiet=false) {
   root=appRoot;settingsPath=config;settings=Data.Read<CenterSettings>(config);settings.UILanguage=I18n.Language;previewMode=quiet;
   if(string.IsNullOrEmpty(settings.InstallRoot))settings.InstallRoot=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"SofaRelay");
   AutoScaleDimensions=new SizeF(96,96);AutoScaleMode=AutoScaleMode.Dpi;
   Text=I18n.L("SofaRelay · Kurulum ve Ayarlar");Font=new Font("Segoe UI",10);BackColor=background;ForeColor=Color.White;
   Width=Math.Min(1140,Screen.PrimaryScreen.WorkingArea.Width-70);Height=Math.Min(850,Screen.PrimaryScreen.WorkingArea.Height-70);MinimumSize=new Size(860,620);StartPosition=FormStartPosition.CenterScreen;
   var sidebar=new Panel {Dock=DockStyle.Left,Width=205,BackColor=panelColor,Padding=new Padding(16)};
   var brand=new Label {Text=I18n.L("SOFA\nRELAY"),Font=new Font("Segoe UI Semibold",22),ForeColor=accent,Size=new Size(173,104),Margin=new Padding(0,0,0,8)};
   var navFlow=new FlowLayoutPanel {Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};sidebar.Controls.Add(navFlow);navFlow.Controls.Add(brand);
   string[] names={I18n.L("1  Başlangıç ve tanı"),I18n.L("2  Kitaplıklar ve giriş"),I18n.L("3  Emülatörler"),I18n.L("4  Yayın ve ekran"),I18n.L("5  Shield / TV bağlantısı"),I18n.L("6  Kurulum ve bakım"),I18n.L("7  Yardım ve geri alma")};
   for(int i=0;i<names.Length;i++){int n=i;var b=Button(names[i],()=>ShowPage(n));b.Width=173;b.Height=55;b.Font=new Font("Segoe UI",9);b.TextAlign=ContentAlignment.MiddleLeft;b.Margin=new Padding(0,0,0,7);nav.Add(b);navFlow.Controls.Add(b);}
   var header=new Panel {Dock=DockStyle.Top,Height=82,Padding=new Padding(28,18,28,10)};heading.Dock=DockStyle.Fill;heading.Font=new Font("Segoe UI Semibold",22);header.Controls.Add(heading);
   var languagePanel=new FlowLayoutPanel {Width=173,Height=70,FlowDirection=FlowDirection.TopDown,WrapContents=false,Margin=new Padding(0,0,0,10)};
   languagePanel.Controls.Add(new Label {Text=I18n.L("Arayüz dili"),AutoSize=true,Font=new Font("Segoe UI",9)});
   languagePicker.ForeColor=SystemColors.WindowText;languagePicker.BackColor=SystemColors.Window;languagePicker.DropDownStyle=ComboBoxStyle.DropDownList;languagePicker.Width=157;languagePicker.Items.AddRange(new object[]{"English","Türkçe","Français","Español"});languagePicker.SelectedIndex=Array.IndexOf(I18n.Languages,I18n.Language);languagePanel.Controls.Add(languagePicker);navFlow.Controls.Add(languagePanel);navFlow.Controls.SetChildIndex(languagePanel,1);
   var footer=new Panel {Dock=DockStyle.Bottom,Height=78,Padding=new Padding(24,8,24,8)};
   status.Dock=DockStyle.Top;status.Height=24;status.ForeColor=Color.LightSteelBlue;progress.Dock=DockStyle.Bottom;progress.Height=5;footer.Controls.Add(status);footer.Controls.Add(progress);
   var save=Button(I18n.L("Ayarları kaydet"),()=>SaveWithNotice());save.Dock=DockStyle.Right;save.Width=155;footer.Controls.Add(save);
   content.Dock=DockStyle.Fill;content.Padding=new Padding(26,8,26,8);
   Controls.Add(content);Controls.Add(header);Controls.Add(footer);Controls.Add(sidebar);
   initializing=true;BuildPages();LoadFields();initializing=false;ShowPage(0);
   localized.Remember(this,new Control[]{heading,status,review,diagnosisText,deviceText});foreach(var item in pages)localized.Remember(item,new Control[]{heading,status,review,diagnosisText,deviceText});localized.Apply();
   if(quiet)status.Text=I18n.L("Tanıtım önizlemesi: tanı veya kurulum işlemi çalışmıyor.");
   languagePicker.SelectedIndexChanged+=(s,e)=>{if(!initializing&&!busy)ChangeLanguage(I18n.Languages[languagePicker.SelectedIndex],true);};
   if(!quiet)Shown+=async(s,e)=>await Run("Diagnose",false);
   FormClosing+=(s,e)=>{if(busy){e.Cancel=true;LocalizedMessage.Show(this,I18n.L("İşlem devam ediyor. Tamamlanmasını bekleyin; pencereyi küçültebilirsiniz."),I18n.L("SofaRelay"));}};
  }
  Button Button(string text,Action action) {
   var b=new Button {Text=text,AutoSize=false,Size=new Size(240,38),FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(37,55,77),ForeColor=Color.White,Margin=new Padding(0,6,10,6),Cursor=Cursors.Hand,UseVisualStyleBackColor=false};
   b.Height=Math.Max(38,TextRenderer.MeasureText(text,Font,new Size(220,int.MaxValue),TextFormatFlags.WordBreak).Height+16);
   b.FlatAppearance.BorderColor=Color.FromArgb(63,92,120);b.Click+=(s,e)=>{if(!busy)action();};return b;
  }
  FlowLayoutPanel Page() {return new FlowLayoutPanel {Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true,BackColor=background};}
  Label Paragraph(string text,int max=760) {return new Label {Text=text,AutoSize=true,MaximumSize=new Size(max,0),ForeColor=Color.FromArgb(210,222,237),Margin=new Padding(0,8,8,12)};}
  Label Section(string text){var l=Paragraph(text);l.Font=new Font("Segoe UI Semibold",13);l.ForeColor=accent;return l;}
  CheckBox Check(string text){return new CheckBox {Text=text,AutoSize=true,MaximumSize=new Size(750,0),Margin=new Padding(0,5,8,6),ForeColor=Color.White};}
  TextBox PathField(FlowLayoutPanel p,string label,Action<string> changed,bool file=false) {
   string sourceLabel=I18n.Source(label);
   p.Controls.Add(Paragraph(label));var row=new FlowLayoutPanel {AutoSize=true,WrapContents=false,Margin=new Padding(0,0,0,8)};
   var text=new TextBox {Width=570,BackColor=panelColor,ForeColor=Color.White,BorderStyle=BorderStyle.FixedSingle,Margin=new Padding(0,8,8,0)};
   var b=Button(I18n.L("Seç…"),()=>{if(file){using(var d=new OpenFileDialog {Filter=I18n.L("Windows uygulaması (*.exe)|*.exe|Tüm dosyalar|*.*"),CheckFileExists=true})if(d.ShowDialog(this)==DialogResult.OK)text.Text=d.FileName;}else{using(var d=new FolderBrowserDialog {Description=I18n.L(sourceLabel),SelectedPath=Directory.Exists(text.Text)?text.Text:""})if(d.ShowDialog(this)==DialogResult.OK)text.Text=d.SelectedPath;}});b.Width=80;row.Controls.Add(text);row.Controls.Add(b);text.TextChanged+=(s,e)=>{if(!initializing)changed(text.Text);};p.Controls.Add(row);return text;
  }
  NumericUpDown Number(int min,int max,int value){return new NumericUpDown {Minimum=min,Maximum=max,Value=value,Width=105,BackColor=panelColor,ForeColor=Color.White,Margin=new Padding(0,6,15,6)};}
  void BuildPages() {
   var p=Page();p.Controls.Add(Paragraph(I18n.L("Tek kütüphane, kumanda veya klavye/fare, Moonlight üzerinden TV yayını. Bu uygulama kurulumu yapar; daha sonra aynı yerden ayarları değiştirebilirsiniz.")));
   install=PathField(p,I18n.L("SofaRelay kurulum klasörü"),v=>settings.InstallRoot=v);
   playnite=PathField(p,I18n.L("Mevcut Playnite klasörü (yoksa boş bırakın; otomatik kurulur)"),v=>settings.PlaynitePath=v);
   sunshine=PathField(p,I18n.L("Sunshine klasörü (var olan kurulum tanıyla bulunur)"),v=>settings.SunshineDirectory=v);
   diagnosisText=Paragraph(I18n.L("Bilgisayar kontrol ediliyor…"));p.Controls.Add(diagnosisText);p.Controls.Add(Button(I18n.L("Bilgisayarı yeniden denetle"),async()=>await Run("Diagnose",false)));
   p.Controls.Add(Paragraph(I18n.L("Var olan Sunshine, kütüphaneler ve oyunlar korunur. Sistem dosyaları için gerektiğinde Windows yönetici onayı çıkar. Mağaza hesapları ve Moonlight PIN eşleştirmesi kendi cihazınızda tamamlanır.")));pages.Add(p);
   p=Page();p.Controls.Add(Paragraph(I18n.L("Sahip olduğunuz oyunları görmek istediğiniz mağazaları seçin. Şifre veya doğrulama kodu bu uygulamada istenmez; giriş kendi mağaza/Playnite penceresinde yapılır.")));
   libraries.CheckOnClick=true;libraries.Items.AddRange(new object[]{"Steam","Epic","EA","Ubisoft","Xbox"});libraries.Height=130;libraries.Width=650;libraries.BackColor=panelColor;libraries.ForeColor=Color.White;libraries.BorderStyle=BorderStyle.FixedSingle;p.Controls.Add(libraries);
   steam=Check(I18n.L("Steam kurulum onayını seçilen oyun için otomatik geç"));epic=Check(I18n.L("Epic oyunlarını Legendary ile doğrudan indir ve kur"));p.Controls.Add(steam);p.Controls.Add(epic);
   autoClients=Check(I18n.L("Kurulumda seçili mağaza uygulamalarının eksiklerini otomatik kur"));p.Controls.Add(autoClients);
   p.Controls.Add(Button(I18n.L("Seçili mağaza uygulamalarını kur"),async()=>await Run("InstallClients",true)));
   p.Controls.Add(Button(I18n.L("Hesapları bağlamak için Playnite'ı aç"),()=>OpenPlaynite(false)));
   p.Controls.Add(Paragraph(I18n.L("Giriş yolu: Playnite masaüstünde F9 → Uzantı Ayarları → Kütüphaneler → ilgili mağaza → Hesabı bağla. Epic için Legendary (Epic Games) seçin. Steam hesabınızın oyun ayrıntıları gizliyse kendi hesabınızla giriş seçeneğini kullanın. Sonra F5 ile kitaplıkları yenileyin.\n\nEA/Ubisoft özel kurulum onaylarını kendi istemcilerinde gösterir. Shield'da Start/Menu tuşuna uzun basınca fare modu açılır; analog çubuk hareket ettirir, A tıklar.")));pages.Add(p);
   p=Page();p.Controls.Add(Paragraph(I18n.L("Emülatörün uygulamasını, ROM klasörünü ve veri klasörünü seçin. Mevcut oyunlar taşınmaz. Fritchii/Lichii türlerinde eski oynanma süreleri, RetroArch'ta çalışma günlükleri okunur; diğer emülatörlerde Playnite üzerinden başlayan yeni oturumlar sayılır.")));
   emulators.Width=740;emulators.Height=210;emulators.ReadOnly=true;emulators.AllowUserToAddRows=false;emulators.AllowUserToDeleteRows=false;emulators.SelectionMode=DataGridViewSelectionMode.FullRowSelect;emulators.MultiSelect=false;emulators.BackgroundColor=panelColor;emulators.AutoGenerateColumns=false;emulators.RowHeadersVisible=false;emulators.AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill;emulators.DefaultCellStyle.BackColor=panelColor;emulators.DefaultCellStyle.ForeColor=Color.White;emulators.DefaultCellStyle.SelectionBackColor=Color.FromArgb(45,87,123);emulators.ColumnHeadersDefaultCellStyle.BackColor=panelColor;emulators.EnableHeadersVisualStyles=false;
   emulators.Columns.Add("Name",I18n.L("Ad"));emulators.Columns.Add("Platform",I18n.L("Sistem"));emulators.Columns.Add("RomDirectory",I18n.L("Oyun klasörü"));p.Controls.Add(emulators);
   var row=new FlowLayoutPanel {AutoSize=true};row.Controls.Add(Button(I18n.L("Emülatör ekle"),()=>EditEmulator(-1)));row.Controls.Add(Button(I18n.L("Seçileni düzenle"),()=>{if(emulators.SelectedRows.Count>0)EditEmulator(emulators.SelectedRows[0].Index);}));row.Controls.Add(Button(I18n.L("Seçileni kaldır"),()=>{if(emulators.SelectedRows.Count>0){settings.Emulators.RemoveAt(emulators.SelectedRows[0].Index);RefreshEmulators();}}));p.Controls.Add(row);
   history=Check(I18n.L("Emülatör geçmiş sürelerini otomatik eşitle (çift saymadan)"));covers=Check(I18n.L("Eksik NUP/yan dosya kapaklarını otomatik tamamla"));p.Controls.Add(history);p.Controls.Add(covers);
   p.Controls.Add(Paragraph(I18n.L("RetroArch için her sistem/çekirdek ayrı satır olabilir. Veri klasörü, retroarch.cfg veya play_time klasörünün bulunduğu yerdir. Fritchii genelde %APPDATA%\\fritchii kullanır. ROM dosya adında başlık kimliği yoksa NUP içinden okunur; diğer biçimlerde ayrıntılı rehberdeki kimlik eşlemesi kullanılabilir. Emülatör, oyun, BIOS, firmware ve anahtarlar pakete dahil değildir.")));
   p.Controls.Add(Button(I18n.L("Eksikse RetroArch'ı kur"),async()=>await Run("InstallRetroArch",true)));p.Controls.Add(Button(I18n.L("Emülatör ve çekirdek rehberi"),()=>Open(GuidePath()+"#emulatorler")));
   var fpsRow=new FlowLayoutPanel {AutoSize=true};fpsRow.Controls.Add(Button(I18n.L("TOTK: 60 FPS profili"),async()=>await Run("TotkProfile",true,60)));fpsRow.Controls.Add(Button(I18n.L("TOTK: 90 FPS profili"),async()=>await Run("TotkProfile",true,90)));p.Controls.Add(fpsRow);p.Controls.Add(Paragraph(I18n.L("FPS düğmeleri yalnız uyumlu Dynamic FPS modu zaten kurulu Fritchii için çalışır; mod bulunmadan oyun hızını değiştirmez. Kurulum ve sürüm uyumluluğu Yardım sayfasında anlatılır.")));pages.Add(p);
   p=Page();mouse=Check(I18n.L("Klavye ve fareyle menü/yayın kontrolü açık"));gamepad=Check(I18n.L("Kumanda desteği açık"));desktopTile=Check(I18n.L("Moonlight'ta Masaüstü kutusunu göster"));libraryTile=Check(I18n.L("Moonlight'ta Oyun Kütüphanesi kutusunu göster"));preserve=Check(I18n.L("Diğer Sunshine uygulama kutularını koru"));p.Controls.Add(mouse);p.Controls.Add(gamepad);p.Controls.Add(desktopTile);p.Controls.Add(libraryTile);p.Controls.Add(preserve);
   p.Controls.Add(Paragraph(I18n.L("Klavye/fare seçeneği menü imlecini ve Sunshine girişini açar. Emülatör içindeki oyun tuşları kendi emülatör ayarlarından eşlenir.")));
   virtualDisplay=Check(I18n.L("Yayın için sanal ekran kullan"));monitorOff=Check(I18n.L("Yayın sırasında fiziksel monitörlerin sinyalini kapat"));restore=Check(I18n.L("Yayın bittiğinde önceki ekran düzenini geri getir"));automatic=Check(I18n.L("Çözünürlük ve Hz değerini Moonlight isteğine göre otomatik seç"));p.Controls.Add(virtualDisplay);p.Controls.Add(monitorOff);p.Controls.Add(restore);p.Controls.Add(automatic);
   virtualDisplay.CheckedChanged+=(s,e)=>{monitorOff.Enabled=virtualDisplay.Checked;if(!virtualDisplay.Checked)monitorOff.Checked=false;};
   p.Controls.Add(Paragraph(I18n.L("İstemci türü")));client=new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList,Width=650,BackColor=panelColor,ForeColor=Color.White};client.Items.AddRange(new object[]{"NVIDIA Shield","Android TV / Google TV",I18n.L("Windows / diğer")});p.Controls.Add(client);
   var modes=new FlowLayoutPanel {AutoSize=true};width=Number(640,7680,3840);height=Number(360,4320,2160);hz=Number(24,240,60);bitrate=Number(5,300,60);modes.Controls.Add(Paragraph(I18n.L("Genişlik")));modes.Controls.Add(width);modes.Controls.Add(Paragraph(I18n.L("Yükseklik")));modes.Controls.Add(height);modes.Controls.Add(Paragraph("Hz"));modes.Controls.Add(hz);modes.Controls.Add(Paragraph("Mbps"));modes.Controls.Add(bitrate);p.Controls.Add(modes);
   hdr=Check(I18n.L("İstemcide HDR kullanmak istiyorum (Moonlight'ta ayrıca açın)"));p.Controls.Add(hdr);
   p.Controls.Add(Paragraph(I18n.L("Shield TV/Pro: 4K çıkış 60 Hz ile sınırlıdır. TV panelinizin 120/144 Hz olması Shield'ın 4K120 verdiği anlamına gelmez. Daha yüksek Hz için cihazın gerçekten sunduğu daha düşük çözünürlüğü seçin; isteğe bağlı ADB kontrolü çıkış modlarını listeler. Mbps ve HDR Moonlight tarafında da aynı isteğe göre seçilir.")));
   p.Controls.Add(Paragraph(I18n.L("Sunshine ekranı")));display=new ComboBox {Width=700,DropDownStyle=ComboBoxStyle.DropDownList};p.Controls.Add(display);vdd=PathField(p,I18n.L("Sanal ekran sürücüsünün ayar klasörü"),v=>settings.VddDirectory=v);pages.Add(p);
   p=Page();p.Controls.Add(Paragraph(I18n.L("Normal Moonlight yayını için ADB gerekmez. Önce aşağıdaki adımlarla bağlanın; ADB yalnız cihaz tanısı veya Play Store yerine isteğe bağlı Moonlight kurulumu içindir.")));
   p.Controls.Add(Section(I18n.L("1. Aynı ağ ve Moonlight")));p.Controls.Add(Paragraph(I18n.L("Shield/TV ile PC'yi aynı ev ağına bağlayın. Tercihen Ethernet kullanın. Shield Play Store'da Moonlight Game Streaming uygulamasını açın/kurun.")));p.Controls.Add(Button(I18n.L("Moonlight Play Store sayfası"),()=>Open("https://play.google.com/store/apps/details?id=com.limelight")));
   p.Controls.Add(Section(I18n.L("2. Sunshine ve PIN")));p.Controls.Add(Paragraph(I18n.L("PC'de Sunshine web panelini açın, ilk kullanımda kendi yönetici hesabınızı oluşturun. Moonlight'ta PC'yi seçin; gösterilen PIN'i Sunshine panelinin PIN bölümüne girin. PC bulunmuyorsa Tanı sayfasındaki IPv4 adresini Moonlight'ın Bilgisayar ekle seçeneğine yazın.")));p.Controls.Add(Button(I18n.L("Sunshine web panelini aç"),()=>Open("https://localhost:47990")));
   p.Controls.Add(Section(I18n.L("3. Görüntü ve kontrol")));deviceText=Paragraph(I18n.L("Moonlight → Ayarlar → Video çözünürlüğü / FPS / bit hızı değerlerini Yayın sayfasıyla eşleştirin. Otomatik ekran geçişi için Oyun ayarlarını iyileştir açık olsun. USB/Bluetooth klavye, fare ve kumandayı Shield'a bağlayın. Yayından çıkıştan sonra PC monitörü geri gelmelidir."));p.Controls.Add(deviceText);
   ip=PathField(p,I18n.L("İsteğe bağlı: Shield/TV IP adresi (ör. 192.168.1.20)"),v=>settings.DeviceAddress=v);ip.Parent.Controls[ip.Parent.Controls.Count-1].Visible=false;
   p.Controls.Add(Paragraph(I18n.L("ADB kullanacaksanız Shield: Ayarlar → Cihaz tercihleri → Hakkında → Derleme üzerine 7 kez basın; Geliştirici seçeneklerinde Ağ hata ayıklama/USB hata ayıklama seçeneğini açın. PC bağlanırken Shield ekranında izin verin. İşiniz bittiğinde hata ayıklamayı kapatabilirsiniz. Android 11+ cihazınız yalnız kablosuz eşleştirme kodu veriyorsa Ayrıntılı Rehber'deki eşleştirme yolunu kullanın.")));
   var devrow=new FlowLayoutPanel {AutoSize=true};devrow.Controls.Add(Button(I18n.L("ADB ile bağlan ve modları oku"),async()=>await Run("ConnectDevice",true)));devrow.Controls.Add(Button(I18n.L("Moonlight'ı cihaza kur / aç"),async()=>await Run("InstallMoonlight",true)));p.Controls.Add(devrow);pages.Add(p);
   p=Page();review=Paragraph("");p.Controls.Add(review);p.Controls.Add(Paragraph(I18n.L("Ayarları önce gözden geçirin. Kurulum Playnite'ı ve seçtiğiniz eklentileri hazırlar, eksik Sunshine/sürücüleri kurar, iki Moonlight kutusunu ekler. Var olan hesaplar ve ROM'lar kopyalanmaz. Hesap girişini ve PIN eşleştirmesini Bağlantı sayfasından tamamlayın.")));
   var installButton=Button(I18n.L("Kur / eksikleri tamamla"),async()=>await Run("Install",true));installButton.BackColor=Color.FromArgb(28,105,153);installButton.Width=300;p.Controls.Add(installButton);
   p.Controls.Add(Button(I18n.L("Ayarları uygula / onar"),async()=>await Run("Apply",true)));p.Controls.Add(Button(I18n.L("Oyun kütüphanesini aç"),()=>OpenPlaynite(true)));p.Controls.Add(Button(I18n.L("Kimlik bilgisi içermeyen tanı raporu"),async()=>await Run("Diagnostics",false)));
   log.Multiline=true;log.ScrollBars=ScrollBars.Vertical;log.ReadOnly=true;log.BackColor=Color.FromArgb(9,16,26);log.ForeColor=Color.LightSteelBlue;log.Width=740;log.Height=220;log.Font=new Font("Consolas",9);p.Controls.Add(log);pages.Add(p);
   p=Page();p.Controls.Add(Paragraph(I18n.L("Bu araç kendi kurulumunuzun dosyalarını yedekler. İlk kullanıcıya ait ayarlar, hesaplar, ROM'lar, kayıtlar, PIN eşleşmeleri veya ekran kimlikleri dağıtımda bulunmaz. Eksik cihaz yetkisi ya da hesap girişi otomatik atlanmaz; gerekli adım uygulama içinde açıklanır.")));
   p.Controls.Add(Button(I18n.L("Ayrıntılı rehberi aç"),()=>Open(GuidePath())));p.Controls.Add(Button(I18n.L("Fiziksel ekranı şimdi geri getir"),async()=>await Run("Recover",false)));p.Controls.Add(Button(I18n.L("Yedeklenen ayarları geri al"),async()=>{if(LocalizedMessage.Show(this,I18n.L("Kurulumun yedeklediği ayarlar geri alınacak. Playnite'ı ve yayını kapatın. Sonradan değişen dosyaların üzerine yazılmaz; oyun ve sürücüler silinmez. Devam edilsin mi?"),I18n.L("Ayarları geri al"),MessageBoxButtons.YesNo,MessageBoxIcon.Question)==DialogResult.Yes)await Run("Restore",false);}));p.Controls.Add(Button(I18n.L("Yerel yedek ve günlük klasörünü aç"),()=>Open(DataRoot())));
   p.Controls.Add(Section(I18n.L("Yaygın sorunlar")));p.Controls.Add(Paragraph(I18n.L("PC görünmüyor: aynı ağda olun; Windows ağı Özel olsun ve Sunshine güvenlik duvarı iznini kontrol edin. Modemin portlarını internete açmanız gerekmez.\nSiyah ekran / monitör dönmüyor: Ctrl+Alt+F11 veya Ekranı geri getir. Yayını kapatıp Tanı'yı yenileyin.\nYüksek Hz yok: Shield çıkış modu, HDMI kablo/port ve Moonlight FPS ayarı birlikte desteklemeli.\nOyun listesi boş: ilgili hesabı Playnite F9'dan bağlayıp F5'e basın.\nEski emülatör süresi boş: doğru veri klasörü ve başlık kimliğini seçin; sıfır geçmiş için süre uydurulmaz.\nWindows imzalı uygulama değil uyarısı: bu proje özel kod imzalama sertifikasına sahip değil. Paketi güvendiğiniz kaynaktan alın; SHA-256 dosyasını kontrol edin veya kaynaklardan derleyin. Windows korumalarını kapatmanız gerekmez.")));
   var links=new FlowLayoutPanel {AutoSize=true};links.Controls.Add(Button("App Installer / WinGet",()=>Open("https://apps.microsoft.com/detail/9nblggh4nns1")));links.Controls.Add(Button(I18n.L("GPU sürücüleri / gereksinimler"),()=>Open(GuidePath()+"#gereksinimler")));p.Controls.Add(links);
   p.Controls.Add(Paragraph(I18n.L("SofaRelay 2.2.0 · Windows 10/11 x64 · .NET Framework 4.8\nOyun kurulumları Steam/Epic'te otomatik; EA/Ubisoft istemci akışı kullanılır. Emülatörler ve oyun dosyaları otomatik olarak internetten aranmaz.")));pages.Add(p);
  }
  void LoadFields() {
   install.Text=settings.InstallRoot;playnite.Text=settings.PlaynitePath;sunshine.Text=settings.SunshineDirectory;ip.Text=settings.DeviceAddress;vdd.Text=settings.VddDirectory;
   autoClients.Checked=settings.AutoInstallStoreClients;mouse.Checked=settings.MouseKeyboard;history.Checked=settings.SyncPlaytime;covers.Checked=settings.AutomaticCovers;steam.Checked=settings.SteamAutoInstall;epic.Checked=settings.EpicDirectInstall;gamepad.Checked=settings.Gamepad;
   desktopTile.Checked=settings.ShowDesktop;libraryTile.Checked=settings.ShowLibrary;preserve.Checked=settings.PreserveExistingApps;virtualDisplay.Checked=settings.VirtualDisplay;monitorOff.Checked=settings.TurnOffPhysicalMonitor;restore.Checked=settings.RestoreDisplay;automatic.Checked=settings.AutomaticDisplayMode;hdr.Checked=settings.HDR;
   client.SelectedIndex=settings.ClientKind=="Shield"?0:settings.ClientKind=="AndroidTV"?1:2;width.Value=Math.Max(width.Minimum,Math.Min(width.Maximum,settings.Width));height.Value=Math.Max(height.Minimum,Math.Min(height.Maximum,settings.Height));hz.Value=Math.Max(hz.Minimum,Math.Min(hz.Maximum,settings.RefreshRate));bitrate.Value=Math.Max(bitrate.Minimum,Math.Min(bitrate.Maximum,settings.BitrateMbps));
   for(int i=0;i<libraries.Items.Count;i++)libraries.SetItemChecked(i,settings.Libraries.Contains(libraries.Items[i].ToString()));RefreshEmulators();
  }
  void ReadFields() {
   settings.InstallRoot=install.Text.Trim();settings.PlaynitePath=playnite.Text.Trim();settings.SunshineDirectory=sunshine.Text.Trim();settings.DeviceAddress=ip.Text.Trim();settings.VddDirectory=vdd.Text.Trim();
   settings.AutoInstallStoreClients=autoClients.Checked;settings.MouseKeyboard=mouse.Checked;settings.SyncPlaytime=history.Checked;settings.AutomaticCovers=covers.Checked;settings.SteamAutoInstall=steam.Checked;settings.EpicDirectInstall=epic.Checked;settings.Gamepad=gamepad.Checked;
   settings.ShowDesktop=desktopTile.Checked;settings.ShowLibrary=libraryTile.Checked;settings.PreserveExistingApps=preserve.Checked;settings.VirtualDisplay=virtualDisplay.Checked;settings.TurnOffPhysicalMonitor=monitorOff.Checked;settings.RestoreDisplay=restore.Checked;settings.AutomaticDisplayMode=automatic.Checked;settings.HDR=hdr.Checked;
   settings.ClientKind=client.SelectedIndex==0?"Shield":client.SelectedIndex==1?"AndroidTV":"Other";settings.Width=(int)width.Value;settings.Height=(int)height.Value;settings.RefreshRate=(int)hz.Value;settings.BitrateMbps=(int)bitrate.Value;
   settings.Libraries=libraries.CheckedItems.Cast<object>().Select(x=>x.ToString()).ToArray();if(display.SelectedItem is DisplayChoice)settings.DisplayId=((DisplayChoice)display.SelectedItem).Id;
  }
  bool Save(bool validate) {
   ReadFields();var errors=Validation.Settings(settings);if(validate && errors.Count>0){LocalizedMessage.Show(this,string.Join("\n",errors),I18n.L("Ayarları kontrol edin"),MessageBoxButtons.OK,MessageBoxIcon.Information);return false;}
   try{Data.Write(settingsPath,settings);return true;}catch(Exception ex){LocalizedMessage.Show(this,ex.Message,"Ayarlar kaydedilemedi");return false;}
  }
  void SaveWithNotice(){if(Save(true))status.Text=I18n.L("Ayarlar kaydedildi. Sistem değişiklikleri için Kurulum sayfasında Uygula'ya basın.");}
  string DataRoot(){return Path.Combine(string.IsNullOrEmpty(settings.InstallRoot)?root:Data.Expand(settings.InstallRoot),"data");}
  void ShowPage(int index) {
   page=index;content.Controls.Clear();content.Controls.Add(pages[index]);heading.Text=nav[index].Text.Substring(3);
   for(int i=0;i<nav.Count;i++)nav[i].BackColor=i==index?Color.FromArgb(36,81,115):Color.FromArgb(37,55,77);
   if(index==5){ReadFields();review.Text=I18n.L("Kurulum: ")+settings.InstallRoot+I18n.L("\nİstemci: ")+client.Text+I18n.L(" · ")+settings.Width+I18n.L("×")+settings.Height+" / "+settings.RefreshRate+I18n.L(" Hz\nKitaplıklar: ")+string.Join(", ",settings.Libraries)+I18n.L("\nSanal ekran: ")+(settings.VirtualDisplay?I18n.L("Açık"):I18n.L("Kapalı"))+I18n.L(" · Fiziksel monitörü kapat: ")+(settings.TurnOffPhysicalMonitor?I18n.L("Evet"):I18n.L("Hayır"));}
  }
  void RefreshEmulators(){emulators.Rows.Clear();foreach(var e in settings.Emulators)emulators.Rows.Add(e.Name,e.Platform,e.RomDirectory);}
  void EditEmulator(int index){var config=index>=0?settings.Emulators[index]:new EmulatorConfig();using(var d=new EmulatorDialog(config)){if(d.ShowDialog(this)==DialogResult.OK){if(index>=0)settings.Emulators[index]=d.Value;else settings.Emulators.Add(d.Value);RefreshEmulators();}}}
  void Open(string path){try{int fragment=path.IndexOf('#');if(fragment>0 && File.Exists(path.Substring(0,fragment)))path=new Uri(path.Substring(0,fragment)).AbsoluteUri+path.Substring(fragment);Process.Start(new ProcessStartInfo(path){UseShellExecute=true});}catch(Exception ex){LocalizedMessage.Show(this,ex.Message,I18n.L("Açılamadı"));}}
  void OpenPlaynite(bool full){ReadFields();string folder=settings.PlaynitePath;if(string.IsNullOrEmpty(folder))folder=Path.Combine(settings.InstallRoot,"Playnite");string file=Path.Combine(folder,full?"Playnite.FullscreenApp.exe":"Playnite.DesktopApp.exe");if(!File.Exists(file)){LocalizedMessage.Show(this,I18n.L("Önce Kurulum sayfasından Playnite kurulumunu tamamlayın."),I18n.L("Playnite bulunamadı"));return;}Process.Start(new ProcessStartInfo(file,full?"--startfullscreen --hidesplashscreen":"--startdesktop --hidesplashscreen"){UseShellExecute=true});}
  void AppendLog(string text){if(IsDisposed)return;if(InvokeRequired){BeginInvoke(new Action<string>(AppendLog),text);return;}if(log.TextLength>60000)log.Clear();log.AppendText(text+Environment.NewLine);}
  async Task Run(string action,bool validate,int fps=60) {
   if(busy || !Save(validate))return;
   busy=true;progress.Style=ProgressBarStyle.Marquee;status.Text=action=="Diagnose"?I18n.L("Bilgisayar denetleniyor…"):I18n.L("İşlem sürüyor; gerekirse Windows yönetici onayını tamamlayın.");
   foreach(var b in nav)b.Enabled=false;languagePicker.Enabled=false;
   try {
    var result=await Task.Run(()=>WorkerRunner.Run(root,settingsPath,DataRoot(),action,AppendLog,fps));
    if(!result.Success){status.Text=I18n.L("İşlem tamamlanmadı; aşağıdaki adımı uygulayın.");LocalizedMessage.Show(this,result.Message,I18n.L("SofaRelay"),MessageBoxButtons.OK,MessageBoxIcon.Information);return;}
    if(action=="Diagnose")UpdateDiagnosis(result.Data);
    else if(action=="ConnectDevice")UpdateDevice(result.Data);
    else if(action=="Install" || action=="Apply") {
     var fresh=Data.Read<CenterSettings>(settingsPath);settings=fresh;
     string target=Path.Combine(settings.InstallRoot,"data","settings.json");if(File.Exists(target))settingsPath=target;
     initializing=true;LoadFields();initializing=false;
     status.Text=I18n.L("Kurulum/ayarlar tamamlandı. Kütüphaneyi açıp hesap girişlerini ve TV PIN eşleştirmesini tamamlayın.");
     var streaming=result.Data!=null && result.Data.ContainsKey("Streaming")?result.Data["Streaming"] as Dictionary<string,object>:null;bool reboot=streaming!=null && streaming.ContainsKey("RebootRequired") && Convert.ToBoolean(streaming["RebootRequired"]);
     LocalizedMessage.Show(this,I18n.L("Kurulum tamamlandı.")+(reboot?I18n.L("\nSürücü kurulumu Windows'u yeniden başlatmanızı istiyor. Yayını denemeden önce PC'yi yeniden başlatın."):"")+I18n.L("\n\n1. Kitaplıklar sayfasından Playnite'ı açıp kendi hesaplarınızı bağlayın.\n2. Shield / TV bağlantısı sayfasını izleyerek PIN eşleştirmesini yapın.\n3. Moonlight'ta Oyun Kütüphanesi kutusunu seçin.\n\nAyar uygulaması Windows Başlat menüsündeki SofaRelay klasörüne eklendi."),I18n.L("SofaRelay"),MessageBoxButtons.OK,MessageBoxIcon.Information);
    }else if(action=="Diagnostics" && result.Data!=null){string file=Convert.ToString(result.Data["File"]);status.Text=I18n.L("Kimlik bilgileri içermeyen rapor: ")+file;Open(Path.GetDirectoryName(file));}
    else if(action=="InstallRetroArch")LocalizedMessage.Show(this,Convert.ToString(result.Data["Next"]),I18n.L("RetroArch hazır"));
    else status.Text=I18n.L("İşlem tamamlandı.");
   }catch(Exception ex){status.Text=I18n.L("İşlem tamamlanmadı.");LocalizedMessage.Show(this,ex.Message,I18n.L("SofaRelay"),MessageBoxButtons.OK,MessageBoxIcon.Error);}
   finally{busy=false;progress.Style=ProgressBarStyle.Blocks;foreach(var b in nav)b.Enabled=true;languagePicker.Enabled=true;}
  }
  void UpdateDiagnosis(Dictionary<string,object> data) {
   diagnosis=data;if(data==null)return;
   string play=Convert.ToString(data["PlaynitePath"]),sun=Convert.ToString(data["SunshineDirectory"]);
   if(string.IsNullOrEmpty(playnite.Text)&&!string.IsNullOrEmpty(play))playnite.Text=play;if(string.IsNullOrEmpty(sunshine.Text)&&!string.IsNullOrEmpty(sun))sunshine.Text=sun;
   diagnosisText.Text="Windows: "+data["OS"]+"\nPlaynite: "+(!string.IsNullOrEmpty(play)?I18n.L("Bulundu"):I18n.L("Kurulacak"))+I18n.L(" · Sunshine: ")+(Convert.ToBoolean(data["SunshineInstalled"])?I18n.L("Bulundu"):I18n.L("Kurulacak"))+I18n.L("\nSanal ekran: ")+(Convert.ToBoolean(data["VirtualDisplayInstalled"])?I18n.L("Bulundu"):I18n.L("Seçilirse kurulacak"))+I18n.L(" · Kumanda sürücüsü: ")+(Convert.ToBoolean(data["GamepadDriverInstalled"])?I18n.L("Bulundu"):"Gerekirse kurulacak")+"\nWinGet: "+(Convert.ToBoolean(data["Winget"])?I18n.L("Hazır"):I18n.L("Yardım sayfasındaki App Installer gerekir"))+I18n.L("\nPC adı: ")+data["ComputerName"]+I18n.L(" · IP: ")+string.Join(", ",Objects(data["HostAddresses"]).Select(Convert.ToString));
   display.Items.Clear();display.Items.Add(new DisplayChoice {Id="",Name=I18n.L("Otomatik — tek sanal ekranı bul")});
   foreach(var raw in Objects(data["Displays"])) {var d=raw as Dictionary<string,object>;if(d!=null)display.Items.Add(new DisplayChoice {Id=Convert.ToString(d["device_id"]),Name=Convert.ToString(d["friendly_name"])+(System.Text.RegularExpressions.Regex.IsMatch(Convert.ToString(d["friendly_name"]),"VDD|Virtual",System.Text.RegularExpressions.RegexOptions.IgnoreCase)?" (sanal ekran)":I18n.L(" (monitör)"))});}
   display.SelectedIndex=0;for(int i=0;i<display.Items.Count;i++)if(((DisplayChoice)display.Items[i]).Id==settings.DisplayId)display.SelectedIndex=i;
   status.Text=I18n.L("Tanı tamamlandı. Adımları izleyip Kurulum sayfasından devam edin.");
  }
  static IEnumerable<object> Objects(object value){if(value==null)return new object[0];var array=value as IEnumerable;if(array==null || value is string)return new[]{value};return array.Cast<object>();}
  void UpdateDevice(Dictionary<string,object> data){deviceData=data;var modes=Objects(data["Modes"]).Select(x=>x as Dictionary<string,object>).Where(x=>x!=null).Select(x=>x["Width"]+I18n.L("×")+x["Height"]+" @ "+x["Hz"]+" Hz").ToArray();deviceText.Text=I18n.L("ADB bağlantısı hazır. Moonlight: ")+(Convert.ToBoolean(data["MoonlightInstalled"])?I18n.L("Kurulu"):I18n.L("Kur düğmesini veya Play Store'u kullanın"))+I18n.L("\nAlgılanan çıkış modları: ")+(modes.Length>0?string.Join("; ",modes):I18n.L("Bu cihaz metin çıktısında çözümlenemedi; Shield ekran ayarlarından kontrol edin."))+I18n.L("\nMoonlight çözünürlük/FPS/bit hızı ayarını cihaz üzerinde seçin; bu bağlantı özel uygulama verilerini değiştirmez.");status.Text=I18n.L("Cihaz kontrolü tamamlandı.");}
  public void ChangeLanguage(string language,bool persist) {
   ReadFields();settings.UILanguage=I18n.Resolve(language);I18n.Initialize(root,settings.UILanguage);localized.Apply();
   int selected=client.SelectedIndex;client.Items[2]=I18n.L("Windows / diğer");client.SelectedIndex=selected;
   if(diagnosis!=null)UpdateDiagnosis(diagnosis);else diagnosisText.Text=I18n.L("Bilgisayar kontrol ediliyor…");
   if(deviceData!=null)UpdateDevice(deviceData);else deviceText.Text=I18n.L("Moonlight → Ayarlar → Video çözünürlüğü / FPS / bit hızı değerlerini Yayın sayfasıyla eşleştirin. Otomatik ekran geçişi için Oyun ayarlarını iyileştir açık olsun. USB/Bluetooth klavye, fare ve kumandayı Shield'a bağlayın. Yayından çıkıştan sonra PC monitörü geri gelmelidir.");
   ShowPage(page);status.Text=I18n.L("Arayüz dili değiştirildi. Ayarlar korundu.");if(persist)Data.Write(settingsPath,settings);
  }
  string GuidePath(){string path=Path.Combine(root,"docs","guides",I18n.Language+".html");return File.Exists(path)?path:Path.Combine(root,"docs","guides","manual.tr.html");}
  public void RunSelfTest(){if(pages.Count!=7)throw new Exception("Missing wizard page");for(int i=0;i<pages.Count;i++){ShowPage(i);PerformLayout();}ReadFields();if(settings.Emulators==null)throw new Exception("Emulator collection missing");string before=install.Text;bool was=mouse.Checked;foreach(string language in I18n.Languages){ChangeLanguage(language,false);if(install.Text!=before||mouse.Checked!=was)throw new Exception("Language switch changed settings");if(!nav[0].Text.StartsWith("1  "))throw new Exception("Navigation localization failed");}Console.WriteLine("PASS wizard pages, settings binding and four-language switching");}
  static IEnumerable<ComboBox> PreviewCombos(Control parent){foreach(Control child in parent.Controls){var combo=child as ComboBox;if(combo!=null)yield return combo;foreach(var nested in PreviewCombos(child))yield return nested;}}
  public void SavePreviews(string folder){Directory.CreateDirectory(folder);for(int i=0;i<pages.Count;i++){ShowPage(i);PerformLayout();Application.DoEvents();using(var bitmap=new Bitmap(Width,Height)){
   DrawToBitmap(bitmap,new Rectangle(Point.Empty,Size));
   // Win32 combo edit text is omitted by WM_PRINT when a preview runs hidden.
   // Render the actual selected caption for those native controls.
   using(var graphics=Graphics.FromImage(bitmap))foreach(var combo in PreviewCombos(pages[i]).Concat(new[]{languagePicker})){
    string caption=combo.GetItemText(combo.SelectedItem);if(string.IsNullOrEmpty(caption))continue;Point point=PointToClient(combo.PointToScreen(new Point(4,0)));int border=(Width-ClientSize.Width)/2;point.Offset(border,Height-ClientSize.Height-border);
    var captionArea=new Rectangle(point,new Size(Math.Max(1,combo.Width-26),combo.Height));graphics.FillRectangle(SystemBrushes.Window,captionArea);TextRenderer.DrawText(graphics,caption,combo.Font,captionArea,SystemColors.WindowText,TextFormatFlags.VerticalCenter|TextFormatFlags.SingleLine|TextFormatFlags.EndEllipsis);
   }
   bitmap.Save(Path.Combine(folder,"page-"+(i+1)+".png"));}}}
  class DisplayChoice {public string Id,Name;public override string ToString(){return Name;}}
 }
 public class EmulatorDialog : Form {
  public EmulatorConfig Value;
  readonly TextBox name=new TextBox(),exe=new TextBox(),rom=new TextBox(),data=new TextBox(),core=new TextBox(),platform=new TextBox(),extensions=new TextBox(),arguments=new TextBox();
  readonly ComboBox kind=new ComboBox();readonly CheckBox history=new CheckBox();
  public EmulatorDialog(EmulatorConfig source) {
   Value=Data.Serializer().Deserialize<EmulatorConfig>(Data.Serializer().Serialize(source));Text=I18n.L("Emülatör ekle / düzenle");Font=new Font("Segoe UI",10);Width=820;Height=Math.Min(810,Screen.PrimaryScreen.WorkingArea.Height-60);MinimumSize=new Size(700,600);StartPosition=FormStartPosition.CenterParent;
   var p=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=3,AutoScroll=true,Padding=new Padding(18)};p.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,155));p.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));p.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,70));Controls.Add(p);
   int row=0;Action<string,Control,bool,bool> add=(label,c,browse,isFile)=>{p.RowStyles.Add(new RowStyle(SizeType.Absolute,45));p.Controls.Add(new Label {Text=label,AutoSize=true,Anchor=AnchorStyles.Left},0,row);c.Dock=DockStyle.Fill;c.Margin=new Padding(4,8,4,7);p.Controls.Add(c,1,row);if(browse){var b=new Button {Text=I18n.L("Seç…"),Dock=DockStyle.Fill};b.Click+=(s,e)=>{if(isFile){using(var d=new OpenFileDialog {Filter=I18n.L("Uygulama/çekirdek|*.exe;*.dll|Tüm dosyalar|*.*")})if(d.ShowDialog(this)==DialogResult.OK)c.Text=d.FileName;}else{using(var d=new FolderBrowserDialog())if(d.ShowDialog(this)==DialogResult.OK)c.Text=d.SelectedPath;}};p.Controls.Add(b,2,row);}row++;};
   kind.DropDownStyle=ComboBoxStyle.DropDownList;kind.Items.AddRange(new object[]{I18n.L("Fritchii / Lichii / Yuzu türevi"),"RetroArch",I18n.L("Diğer emülatör")});add(I18n.L("Tür"),kind,false,false);add(I18n.L("Görünen ad"),name,false,false);add(I18n.L("Emülatör EXE"),exe,true,true);add(I18n.L("Oyun klasörü"),rom,true,false);add(I18n.L("Veri klasörü"),data,true,false);add(I18n.L("Platform / sistem"),platform,false,false);add(I18n.L("Dosya uzantıları"),extensions,false,false);add(I18n.L("RetroArch çekirdeği"),core,true,true);add(I18n.L("Başlatma komutu"),arguments,false,false);
   history.Text=I18n.L("Mevcut oynanma sürelerini oku");history.AutoSize=true;p.Controls.Add(history,1,row++);
   var note=new Label {Text=I18n.L("Switch örneği: -f -g \"{ImagePath}\"\nRetroArch: -f --appendconfig \"{SofaRelayDir}\\assets\\retroarch-tv.cfg\" -L \"{CorePath}\" \"{ImagePath}\"\nDiğer türlerde emülatörün kendi komutunu ve {ImagePath} yer tutucusunu kullanın. Veri klasörünü seçmek kayıtları taşımak veya kopyalamak anlamına gelmez."),AutoSize=true,MaximumSize=new Size(560,0)};p.Controls.Add(note,1,row++);
   var buttons=new FlowLayoutPanel {AutoSize=true,Dock=DockStyle.Fill};var ok=new Button {Text=I18n.L("Kaydet"),Width=130,Height=36};var cancel=new Button {Text=I18n.L("Vazgeç"),Width=130,Height=36};buttons.Controls.Add(ok);buttons.Controls.Add(cancel);p.Controls.Add(buttons,1,row);AcceptButton=ok;CancelButton=cancel;cancel.Click+=(s,e)=>{DialogResult=DialogResult.Cancel;Close();};
   kind.SelectedIndex=source.Kind=="Switch"?0:source.Kind=="RetroArch"?1:2;name.Text=source.Name;exe.Text=source.Executable;rom.Text=source.RomDirectory;data.Text=source.DataDirectory;core.Text=source.CorePath;platform.Text=source.Platform;extensions.Text=source.Extensions;arguments.Text=source.Arguments;history.Checked=source.ImportHistory;
   kind.SelectedIndexChanged+=(s,e)=>{if(kind.SelectedIndex==1){if(string.IsNullOrEmpty(name.Text))name.Text="RetroArch";extensions.Text="n64,z64,v64";arguments.Text="-f --appendconfig \"{SofaRelayDir}\\assets\\retroarch-tv.cfg\" -L \"{CorePath}\" \"{ImagePath}\"";platform.Text="Nintendo 64";}else if(kind.SelectedIndex==0){extensions.Text="nup,nsp,xci";arguments.Text="-f -g \"{ImagePath}\"";platform.Text="Nintendo Switch";if(string.IsNullOrEmpty(data.Text))data.Text=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"fritchii");}};
   ok.Click+=(s,e)=>{
    if(string.IsNullOrWhiteSpace(name.Text)||!File.Exists(Environment.ExpandEnvironmentVariables(exe.Text))||!Directory.Exists(Environment.ExpandEnvironmentVariables(rom.Text))||!arguments.Text.Contains("{ImagePath}")){LocalizedMessage.Show(this,I18n.L("Ad, mevcut EXE/oyun klasörü ve {ImagePath} içeren başlatma komutunu kontrol edin."));return;}
    if(kind.SelectedIndex==1&&!File.Exists(core.Text)){LocalizedMessage.Show(this,I18n.L("RetroArch için uygun çekirdek DLL dosyasını seçin. Ayrıntılı rehberde çekirdek indirme yolu var."));return;}
    Value.Name=name.Text.Trim();Value.Kind=kind.SelectedIndex==0?"Switch":kind.SelectedIndex==1?"RetroArch":"Other";Value.Executable=exe.Text;Value.RomDirectory=rom.Text;Value.DataDirectory=data.Text;Value.CorePath=core.Text;Value.Platform=platform.Text;Value.Extensions=extensions.Text;Value.Arguments=arguments.Text;Value.ImportHistory=history.Checked;DialogResult=DialogResult.OK;Close();
   };
   var translated=new LocalizedControls();translated.Remember(this,new Control[0]);translated.Apply();
  }
 }
}
