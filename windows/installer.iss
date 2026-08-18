; windows/installer.iss
;
; 📦 سكريبت التنصيب — بيلمّ نسخة الويندوز كلها في **ملف واحد**
; اسمه «تنصيب برنامج الخطوط.exe» تبعته لأي حد يدوس عليه ويخلص.
;
; ليه محتاجينه: نسخة الويندوز مش ملف واحد — هي فولدر فيه الـ exe وجنبه
; ملفات dll وفولدر data اللي فيه البرنامج نفسه. لو بعتّ الـ exe لوحده
; مايفتحش. الملف ده بيحطهم كلهم جوّه ملف واحد بيفك نفسه على جهاز الشخص.
;
; بيتبني بالأمر:
;   & "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" windows\installer.iss
;
; ⚠️ الملف الناتج **مش موقّع رقمياً**، فويندوز هيطلّع تحذير أول مرة
; («Windows protected your PC» → More info → Run anyway). ده طبيعي لأي
; برنامج من غير شهادة توقيع، ومالوش علاقة بإن فيه حاجة غلط في البرنامج.

#define AppName "باقات الاتصالات"
#define AppVersion "6.0.0"
#define AppPublisher "عمر"
#define AppExe "telecom_app.exe"

[Setup]
AppId={{8F3A2C71-5B4D-4E6A-9C21-telecomapp6000}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\TelecomApp
DefaultGroupName={#AppName}
; المستخدم العادي مش محتاج يشوف صفحة اختيار المسار — بس نسيبها متاحة
DisableProgramGroupPage=yes
; التنصيب لليوزر الحالي = مش هيطلب صلاحيات المدير، فأسهل على اللي هتبعتله.
;
; ⚠️ من غير PrivilegesRequiredOverridesAllowed عن قصد: لما تتحط، Inno
; بيطلّع شاشة «Select install mode» بالإنجليزي تسأل «لك انت ولا لكل
; المستخدمين؟» — سؤال تقني اللي هتبعتله البرنامج مش هيفهمه، وبيطلع قبل
; اختيار اللغة فبيفضل إنجليزي مهما عملنا. شيلناها فالتنصيب بقى دوسة واحدة.
PrivilegesRequired=lowest
OutputDir=..\build\windows\installer
OutputBaseFilename=تنصيب برنامج الخطوط
SetupIconFile=runner\resources\app_icon.ico
; ضغط عالي — الملف بيطلع أصغر بكتير وده مهم عشان تبعته على واتساب/ميل
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}

; عربي بس ومن غير شاشة اختيار لغة — اللي هتبعتله البرنامج عربي، ومفيش
; داعي يتسأل سؤال زيادة قبل ما يبدأ.
[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; الفولدر كله: الـ exe والـ dll وفولدر data — لازم يروحوا مع بعض
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent
