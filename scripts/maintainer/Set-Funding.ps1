param([Parameter(Mandatory)][uri]$PublicUrl)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if($PublicUrl.Scheme -ne 'https' -or $PublicUrl.Host -notin @('buymeacoffee.com','www.buymeacoffee.com') -or $PublicUrl.Query -or $PublicUrl.Fragment){throw 'Use the actual HTTPS public Buy Me a Coffee profile URL, without query parameters.'}
$handle=$PublicUrl.AbsolutePath.Trim('/')
if($handle -notmatch '^[A-Za-z0-9_-]+$' -or $handle -in @('signup','login','dashboard','settings','YOUR-ACTUAL-HANDLE')){throw 'Use your active public profile handle, not a sign-in/dashboard or placeholder URL.'}
$url='https://buymeacoffee.com/'+$handle
$sections=@{
    'README.md'="If this project saves you setup time, you can [buy me a coffee]($url). Contributions, translations and support for the upstream projects are welcome too. Donations are optional; the software remains free and open source."
    'docs\readme\tr.md'="Bu proje kurulumda zaman kazandırdıysa [bir kahve ısmarlayabilirsin]($url). Koda, çevirilere ve temel projelere katkıların da değerli. Destek isteğe bağlıdır; yazılım ücretsiz ve açık kaynak kalır."
    'docs\readme\fr.md'="Si ce projet vous fait gagner du temps, vous pouvez [m’offrir un café]($url). Les contributions, traductions et le soutien aux projets en amont sont aussi les bienvenus. Le don est facultatif ; le logiciel reste libre et gratuit."
    'docs\readme\es.md'="Si este proyecto te ahorra tiempo, puedes [invitarme a un café]($url). También agradecemos las contribuciones, traducciones y el apoyo a los proyectos originales. Donar es opcional; el programa sigue siendo gratuito y de código abierto."
    'docs\SUPPORT.md'="You can [buy the maintainer a coffee]($url). Donations are optional, provide no special entitlement and do not change the project's free/open-source status. Please support the upstream maintainers too."
}
$visuals=@{
    'README.md'=@('en','docs/media/support','Support Ozi on Buy Me a Coffee')
    'docs\readme\tr.md'=@('tr','../media/support',"Ozi’ye bir kahve ısmarla")
    'docs\readme\fr.md'=@('fr','../media/support','Offrir un café à Ozi')
    'docs\readme\es.md'=@('es','../media/support','Invita a Ozi a un café')
}
$pattern='(?s)<!-- SUPPORT-LINK:START -->.*?<!-- SUPPORT-LINK:END -->'
$topPattern='(?s)<!-- SUPPORT-TOP:START -->.*?<!-- SUPPORT-TOP:END -->'
foreach($name in $sections.Keys){
    $path=Join-Path $root $name
    $text=[IO.File]::ReadAllText($path)
    if(![regex]::IsMatch($text,$pattern)){throw "Support section missing: $name"}
    $content=$sections[$name]
    if($name -eq 'docs\SUPPORT.md'){
        $content="<a href=`"$url`"><img src=`"media/support/support-en.svg`" alt=`"Buy Ozi a coffee — help with fixes, testing and guides`" width=`"100%`"></a>`n`n"+$content
    }
    if($visuals.ContainsKey($name)){
        $language,$media,$alt=$visuals[$name]
        $content="<a href=`"$url`"><img src=`"$media/support-$language.svg`" alt=`"$alt`" width=`"100%`"></a>`n`n"+$content
        $top="<!-- SUPPORT-TOP:START -->`n<p align=`"center`"><a href=`"$url`"><img src=`"$media/buy-me-a-coffee.png`" alt=`"$alt`" width=`"218`" height=`"61`"></a></p>`n<!-- SUPPORT-TOP:END -->"
        if([regex]::IsMatch($text,$topPattern)){
            $text=[regex]::Replace($text,$topPattern,[Text.RegularExpressions.MatchEvaluator]{param($match)$top})
        }else{
            # Place support after the badges, preserving the beta notice and primary download links.
            $badgeStart=$text.IndexOf('badge.svg')
            if($badgeStart -lt 0){throw "Badge block missing: $name"}
            $badgeEnd=$text.IndexOf('</p>',$badgeStart)
            if($badgeEnd -lt 0){throw "Badge block missing: $name"}
            $text=$text.Insert($badgeEnd+4,"`n`n"+$top)
        }
    }
    $replacement="<!-- SUPPORT-LINK:START -->`n"+$content+"`n<!-- SUPPORT-LINK:END -->"
    $text=[regex]::Replace($text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match)$replacement})
    [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))
}
[IO.File]::WriteAllText((Join-Path $root '.github\FUNDING.yml'),('buy_me_a_coffee: '+$handle+"`n"),[Text.UTF8Encoding]::new($false))
Write-Host "Support links and artwork configured for $url. Review the public page and commit the changes."
