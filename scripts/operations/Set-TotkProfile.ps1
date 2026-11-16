function Set-TotkProfile {
    $emulator=$Settings.Emulators | Where-Object {$_.Kind -eq 'Switch'} | Select-Object -First 1
    if(!$emulator){throw (L 'Önce Switch emülatörünüzü Emülatörler sayfasına ekleyin.')}
    $data=[Environment]::ExpandEnvironmentVariables($emulator.DataDirectory)
    $load=Join-Path $data 'load\0100F2C0115B6000'
    $mods=@(Get-ChildItem -LiteralPath $load -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '(Dynamic.?FPS|dFPS).*1\.5\.5' -and (Test-Path (Join-Path $_.FullName 'romfs\dfps'))})
    if($mods.Count -ne 1){throw (L 'Tek bir uyumlu Dynamic FPS 1.5.5 mod klasörü bulunamadı. Yardım → Oyuna özel FPS bölümünü izleyin; mod olmadan yalnız hız sınırı değiştirilmedi.')}
    $profiles=@(Get-ChildItem (Join-Path $mods[0].FullName 'romfs\dfps') -Filter zzz*.ini -File)
    $mod=if($profiles.Count -eq 1){$profiles[0].FullName}else{Join-Path $mods[0].FullName 'romfs\dfps\zzzz-gamecenter.ini'}
    if(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($emulator.Executable)) -ErrorAction SilentlyContinue){throw (L 'Önce emülatörü tamamen kapatın.')}
    $config=Join-Path $data 'config\custom\0100F2C0115B6000.ini';[void](Backup-File $config $DataRoot);[void](Backup-File $mod $DataRoot)
    $pairs=@{'[Core]'=@{'use_speed_limit\use_global'='false';use_speed_limit=$(if($FPS -eq 60){'true'}else{'false'});'speed_limit\use_global'='false';speed_limit='100'};'[Renderer]'=@{'frame_pacing_mode\use_global'='false';frame_pacing_mode=$(if($FPS -eq 60){'2'}else{'3'});'frame_gen\use_global'='false';frame_gen='false'}}
    $text=[IO.File]::ReadAllText($config)
    foreach($section in $pairs.Keys){$pattern='(?ms)^'+[regex]::Escape($section)+'\s*\r?\n(?<body>.*?)(?=^\[|\z)';$m=[regex]::Match($text,$pattern);if(!$m.Success){throw (L 'Oyun ayar bölümü bulunamadı; değişiklik uygulanmadı.')};$body=$m.Groups['body'].Value;foreach($key in $pairs[$section].Keys){$linePattern='(?m)^'+[regex]::Escape($key)+'=.*\r?$';$line=$key+'='+$pairs[$section][$key];if([regex]::IsMatch($body,$linePattern)){$body=[regex]::Replace($body,$linePattern,[Text.RegularExpressions.MatchEvaluator]{param($m)$line})}else{$body+=$line+"`r`n"}};$text=$text.Substring(0,$m.Index)+$section+"`r`n"+$body+$text.Substring($m.Index+$m.Length)}
    $modText=if(Test-Path $mod){[IO.File]::ReadAllText($mod)}else{"[dFPS]`r`n"};$modText=[regex]::Replace($modText,'(?m)^\s*MaxFramerate\s*=.*\r?$','');$modText=$modText.TrimEnd()+"`r`nMaxFramerate = $FPS`r`n"
    [IO.File]::WriteAllText($config,$text,[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($mod,$modText,[Text.UTF8Encoding]::new($false));Mark-Applied $config $DataRoot;Mark-Applied $mod $DataRoot
    return @{FPS=$FPS;FrameGeneration=$false}
}