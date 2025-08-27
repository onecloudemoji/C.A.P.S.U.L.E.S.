<# =========================
 Invoke-PhantomWorkforce.ps1
 Local-only artifact generator for lab realism.
 No IIS. Uses .NET HttpListener + PowerShell only.
 Compatible with Windows PowerShell 5.x and PowerShell 7 on Windows.
========================= #>

param(
  [switch]$Run,
  [int]$DurationMinutes = 15,
  [string]$PersonaName
)

$ErrorActionPreference = 'Stop'

# --------- Root/Globals ----------
$PWRoot  = (Resolve-Path $MyInvocation.MyCommand.Path).Path | Split-Path -Parent
$Base    = Join-Path $PWRoot 'PhantomWorkforce'
$Site    = Join-Path $Base 'Content\Site'
$Docs    = Join-Path $Base 'Content\Docs'
$Logs    = Join-Path $Base 'Logs'
$Shares  = Join-Path $Base 'CorpShares'
$Personas= Join-Path $Base 'Personas'
$Port    = 8080
$BindUrl = "http://127.0.0.1:$Port/"
$StopFile= Join-Path $Base '.stop'

# --------- Utilities ----------
function Ensure-Dir { param($Path) if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }
function Write-Log { param($Msg) Ensure-Dir $Logs; $ts = Get-Date -Format o; Add-Content -Path (Join-Path $Logs 'orchestrator.log') -Value "[$ts] $Msg" }
function Get-Browser {
    $candidates = @(
        "$Env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$Env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
        "$Env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$Env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
        "$Env:ProgramFiles\Internet Explorer\iexplore.exe"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    return $null
}
function Invoke-RandomSleep { param([int]$Min=3,[int]$Max=15) Start-Sleep -Seconds (Get-Random -Minimum $Min -Maximum $Max) }

# --------- Content Seed ----------
function Initialize-Content {
    Ensure-Dir $Site; Ensure-Dir $Docs; Ensure-Dir $Logs; Ensure-Dir $Shares; Ensure-Dir $Personas

    $pages = @{
        'index.html' = @"
<!doctype html><html><head><title>Company Intranet</title></head><body>
<h1>Welcome to the Company Intranet</h1>
<ul>
 <li><a href="/hr/policies">HR Policies</a></li>
 <li><a href="/it/requests">IT Requests</a></li>
 <li><a href="/wiki/search?q=remote">Wiki Search</a></li>
 <li><a href="/downloads/report.zip">Latest Finance Pack</a></li>
</ul>
</body></html>
"@
        'hr\policies.html' = @"
<!doctype html><html><head><title>HR Policies</title></head><body>
<h2>HR Policies</h2>
<p>Annual leave, remote work, and payroll FAQs.</p>
<a href="/">Home</a>
</body></html>
"@
        'it\requests.html' = @"
<!doctype html><html><head><title>IT Requests</title></head><body>
<h2>Open a Ticket</h2>
<form method="POST" action="/it/requests">
 Name: <input name="name"><br/>
 Issue: <input name="issue"><br/>
 <button type="submit">Submit</button>
</form>
<a href="/">Home</a>
</body></html>
"@
        'wiki\search.html' = @"
<!doctype html><html><head><title>Wiki</title></head><body>
<h2>Wiki Search</h2>
<p>Showing results for <em>%QUERY%</em></p>
<ul><li>Remote access guide</li><li>Printer onboarding</li></ul>
<a href="/">Home</a>
</body></html>
"@
    }

    foreach ($kvp in $pages.GetEnumerator()) {
        $relPath = $kvp.Key
        $full    = Join-Path $Site $relPath
        Ensure-Dir (Split-Path $full -Parent)
        if (-not (Test-Path $full)) { $kvp.Value | Set-Content -Path $full -Encoding UTF8 }
    }

    $deptPaths = @('Finance','HR','IT','Sales') | ForEach-Object { Join-Path $Docs $_ }
    foreach ($d in $deptPaths) { Ensure-Dir $d }

    $seedTxt = "Lorem ipsum dolor sit amet. Generated: $(Get-Date -Format o)"
    foreach ($d in $deptPaths) {
        if (-not (Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue)) {
            $f = Join-Path $d ("Readme_{0}.txt" -f (Get-Random -Minimum 100 -Maximum 999))
            $seedTxt | Set-Content -Path $f
        }
    }

    $dlRoot = Join-Path $Site 'downloads'
    Ensure-Dir $dlRoot
    $zipSrc = Join-Path $Docs 'Finance'
    $zipOut = Join-Path $dlRoot 'report.zip'
    if (Test-Path $zipOut) { Remove-Item $zipOut -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($zipSrc, $zipOut)
}

# --------- Local HTTP Server (HttpListener) with friendly routing ----------
$script:ListenerJob = $null
function Start-LocalIntranet {
    param([int]$PortParam = $Port)
    if ($script:ListenerJob -and ($script:ListenerJob.State -eq 'Running')) { Write-Log "Server already running"; return }
    Initialize-Content
    $url = "http://127.0.0.1:$PortParam/"
    Write-Log "Starting local intranet at $url"

    $script:ListenerJob = Start-Job -Name "PW-Intranet-$PortParam" -ScriptBlock {
        param($SitePath, $UrlBase, $LogPath, $StopMarker)
        Add-Type -AssemblyName System.Net.HttpListener
        Add-Type -AssemblyName System.Web

        function Send-Bytes {
            param($res, [byte[]]$bytes, $contentType='application/octet-stream', [int]$code=200)
            $res.StatusCode = $code
            $res.ContentType = $contentType
            $res.OutputStream.Write($bytes,0,$bytes.Length)
            $res.Close()
        }
        function Guess-ContentType { param($ext)
            switch ($ext.ToLower()) {
                '.html' { 'text/html' }
                '.htm'  { 'text/html' }
                '.css'  { 'text/css' }
                '.js'   { 'application/javascript' }
                '.zip'  { 'application/zip' }
                default { 'application/octet-stream' }
            }
        }

        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($UrlBase)
        $listener.Start()
        try {
            while ($true) {
                if (Test-Path $StopMarker) { break }
                $ctx = $listener.GetContext()
                $req = $ctx.Request
                $res = $ctx.Response

                $ts  = [DateTime]::UtcNow.ToString('o')
                $line= "[$ts] $($req.RemoteEndPoint) $($req.HttpMethod) $($req.Url.AbsolutePath)"
                Add-Content -Path $LogPath -Value $line

                $path = $req.Url.AbsolutePath.TrimStart('/')
                if ([string]::IsNullOrWhiteSpace($path)) { $path = 'index.html' }

                if ($req.HttpMethod -eq 'GET') {
                    if ($path -like 'wiki/search*') {
                        $q = [System.Web.HttpUtility]::ParseQueryString($req.Url.Query).Get('q')
                        $tplPath = Join-Path $SitePath 'wiki\search.html'
                        $tpl = if (Test-Path $tplPath) { Get-Content -Raw $tplPath } else { "<html><body>Wiki</body></html>" }
                        $html = $tpl -replace '%QUERY%',[System.Web.HttpUtility]::HtmlEncode($q)
                        $bytes = [Text.Encoding]::UTF8.GetBytes($html)
                        Send-Bytes -res $res -bytes $bytes -contentType 'text/html; charset=utf-8'
                        continue
                    }

                    $full = Join-Path $SitePath $path
                    if (-not (Test-Path $full)) {
                        $ext = [IO.Path]::GetExtension($path)
                        if ([string]::IsNullOrEmpty($ext)) {
                            $candidate = Join-Path $SitePath ($path + '.html')
                            if (Test-Path $candidate) { $full = $candidate } else {
                                $dir = Join-Path $SitePath $path
                                $index = Join-Path $dir 'index.html'
                                if ((Test-Path $dir) -and (Test-Path $index)) { $full = $index }
                            }
                        }
                    }

                    if (Test-Path $full) {
                        $bytes = [IO.File]::ReadAllBytes($full)
                        $ct    = Guess-ContentType ([IO.Path]::GetExtension($full))
                        Send-Bytes -res $res -bytes $bytes -contentType $ct
                        continue
                    } else {
                        $bytes = [Text.Encoding]::UTF8.GetBytes("Not Found")
                        Send-Bytes -res $res -bytes $bytes -contentType 'text/plain' -code 404
                        continue
                    }
                }
                elseif ($req.HttpMethod -eq 'POST' -and $path -eq 'it/requests') {
                    $reader = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
                    $body   = $reader.ReadToEnd()
                    Add-Content -Path (Join-Path (Split-Path $LogPath -Parent) 'it-requests.log') -Value "$ts`t$body"
                    $html = "<html><body><h3>Ticket received</h3><a href=""/"">Home</a></body></html>"
                    $bytes = [Text.Encoding]::UTF8.GetBytes($html)
                    Send-Bytes -res $res -bytes $bytes -contentType 'text/html; charset=utf-8'
                    continue
                }
                else {
                    $bytes = [Text.Encoding]::UTF8.GetBytes("Method Not Allowed")
                    Send-Bytes -res $res -bytes $bytes -contentType 'text/plain' -code 405
                }
            }
        } finally {
            $listener.Stop()
            $listener.Close()
        }
    } -ArgumentList $Site, $url, (Join-Path $Logs 'intranet-access.log'), $StopFile
}

function Stop-LocalIntranet {
    New-Item -ItemType File -Path $StopFile -Force | Out-Null
    if ($script:ListenerJob) {
        Receive-Job -Job $script:ListenerJob -ErrorAction SilentlyContinue | Out-Null
        Stop-Job $script:ListenerJob -ErrorAction SilentlyContinue
        Remove-Job $script:ListenerJob -ErrorAction SilentlyContinue
        $script:ListenerJob = $null
    }
    Remove-Item $StopFile -ErrorAction SilentlyContinue
    Write-Log "Local intranet stopped"
}

# --------- Document Actions ----------
function New-DeptDoc {
    param(
        [ValidateSet('Finance','HR','IT','Sales')] [string]$Department,
        [string]$BaseName = ("Notes_{0}" -f (Get-Random -Minimum 1000 -Maximum 9999))
    )
    $deptDir = Join-Path $Docs $Department
    Ensure-Dir $deptDir
    $pathTxt = Join-Path $deptDir "$BaseName.txt"
    "Generated $(Get-Date -Format o)`r`n$Department notes`r`nLorem ipsum dolor sit amet." | Set-Content -Path $pathTxt
    Start-Process notepad.exe $pathTxt
    Start-Sleep -Seconds 2
    Stop-Process -Name notepad -ErrorAction SilentlyContinue
    return $pathTxt
}

function Touch-DocLifecycle {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }

    $dir = Split-Path $Path -Parent
    $nameNoExt = [IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [IO.Path]::GetExtension($Path)

    $v1 = $Path
    $v2 = Join-Path $dir ("{0}_v2{1}" -f $nameNoExt, $ext)
    Copy-Item $v1 $v2 -Force

    $final = Join-Path $dir ("{0}_FINAL{1}" -f $nameNoExt, $ext)
    if (Test-Path $final) {
        $final = Join-Path $dir ("{0}_FINAL_{1}{2}" -f $nameNoExt, (Get-Random -Minimum 100 -Maximum 999), $ext)
    }
    Rename-Item $v2 $final -Force

    foreach ($f in @($v1,$final)) {
        Start-Process notepad.exe $f
        Start-Sleep -Seconds 1
        Stop-Process -Name notepad -ErrorAction SilentlyContinue
    }
}

# --------- Explorer / Filesystem Actions ----------
function Invoke-ExplorerChurn {
    $root = Join-Path $Base 'UserHome'
    Ensure-Dir $root
    $folders = 'Desktop','Documents','Pictures','Downloads' | ForEach-Object { $p = Join-Path $root $_; Ensure-Dir $p; $p }
    $allDocs = Get-ChildItem -Path $Docs -Recurse -File -ErrorAction SilentlyContinue
    if ($allDocs.Count -gt 0) {
        ($allDocs | Get-Random -Count ([Math]::Min(3, $allDocs.Count))) | ForEach-Object {
            Copy-Item $_.FullName (Join-Path ($folders | Get-Random) $_.Name) -Force
        }
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $root ("Downloads\archive_{0}.zip" -f (Get-Random -Minimum 100 -Maximum 999))
    if (Test-Path $zip) { Remove-Item $zip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Docs, $zip)
    $unz = Join-Path $root ("Downloads\unz_{0}" -f (Get-Random -Minimum 100 -Maximum 999))
    Ensure-Dir $unz
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $unz)
    foreach ($f in $folders) { Start-Process explorer.exe $f; Start-Sleep -Seconds 1 }
}

# --------- Browsing Actions ----------
function Browse-Intranet {
    param([string[]]$Paths = @('/','/hr/policies','/it/requests','/wiki/search?q=remote','/downloads/report.zip'))
    $browser = Get-Browser
    if (-not $browser) { Write-Log "No browser found"; return }
    foreach ($p in $Paths) {
        Start-Process $browser "$($BindUrl.TrimEnd('/'))$p"
        Invoke-RandomSleep -Min 2 -Max 6
    }
}
function Submit-ITRequest {
    $name = @('Alex','Sam','Morgan','Taylor','Jordan') | Get-Random
    $issue= @('VPN not working','Printer offline','Password reset','New laptop request') | Get-Random
    $uri  = "$($BindUrl)it/requests"
    Invoke-WebRequest -Uri $uri -Method POST -Body @{ name=$name; issue=$issue } | Out-Null
}

# --------- Optional: SMB-like share ----------
function Enable-LocalShare {
    param([string]$ShareName='CorpShares')
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $isAdmin = $false }
    if (-not $isAdmin) { Write-Log "Skipping SMB share (admin required)"; return }
    Ensure-Dir $Shares
    try { New-SmbShare -Name $ShareName -Path $Shares -FullAccess "$env:UserDomain\$env:UserName" -ErrorAction Stop | Out-Null } catch {}
}

# ===== More Artifact-Rich Actions =====
function Open-CommonFolders {
    $targets = @(
        (Join-Path $Base 'UserHome\Desktop'),
        (Join-Path $Base 'UserHome\Documents'),
        (Join-Path $Base 'UserHome\Pictures'),
        (Join-Path $Base 'UserHome\Downloads'),
        $Docs,
        (Join-Path $Docs 'Finance'),
        (Join-Path $Docs 'HR'),
        (Join-Path $Docs 'IT'),
        (Join-Path $Docs 'Sales')
    )
    foreach ($t in $targets) { if (-not (Test-Path $t)) { New-Item -ItemType Directory -Path $t | Out-Null } }
    foreach ($p in ($targets | Get-Random -Count 4)) {
        Start-Process explorer.exe $p
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
    }
}
function Create-Archives {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $root = Join-Path $Base 'UserHome\Downloads'
    if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root | Out-Null }
    $n = Get-Random -Minimum 2 -Maximum 4
    1..$n | ForEach-Object {
        $zip = Join-Path $root ("pack_{0}.zip" -f (Get-Random -Minimum 100 -Maximum 999))
        if (Test-Path $zip) { Remove-Item $zip -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Docs, $zip)
        $unz = Join-Path $root ("unz_{0}" -f (Get-Random -Minimum 100 -Maximum 999))
        New-Item -ItemType Directory -Path $unz | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $unz)
    }
}
function Print-ToPDF {
    $printer = "Microsoft Print to PDF"
    $any = Get-ChildItem -Path $Docs -Recurse -Include *.txt -File -ErrorAction SilentlyContinue | Get-Random -Count 1 -ErrorAction SilentlyContinue
    if (-not $any) { return }
    try {
        $printers = Get-Printer -ErrorAction Stop
        if ($printers.Name -notcontains $printer) { Write-Log "Print-ToPDF: $printer not present"; return }
        $pdfOut = Join-Path $any.Directory.FullName (("{0}.pdf" -f [IO.Path]::GetFileNameWithoutExtension($any.Name)))
        Start-Process notepad.exe "/p `"$($any.FullName)`""
        Start-Sleep -Seconds 3
        if (-not (Test-Path $pdfOut)) {
            "Fake PDF placeholder for artifacting: $($any.FullName) $(Get-Date -Format o)" | Set-Content -Path $pdfOut
        }
        Write-Log "Printed $($any.FullName) to $pdfOut"
    } catch { Write-Log "Print-ToPDF error: $($_.Exception.Message)" }
}
function Defender-QuickScan {
    if (Get-Command -Name Start-MpScan -ErrorAction SilentlyContinue) {
        try { Start-MpScan -ScanType QuickScan -ErrorAction Stop; Write-Log "Defender quick scan started" }
        catch { Write-Log "Defender scan error: $($_.Exception.Message)" }
    } else { Write-Log "Defender cmdlets not present; skipping scan" }
}
function RDP-Noise {
    $rdpPath = Join-Path $env:USERPROFILE 'Documents\Default.rdp'
    "screen mode id:i:1`nuse multimon:i:0`nfull address:s:JUMP01`n" | Set-Content -Path $rdpPath -Encoding ASCII
    Start-Process mstsc.exe $rdpPath
    Start-Sleep -Seconds 2
    Stop-Process -Name mstsc -ErrorAction SilentlyContinue
}
function Notes-Habits {
    $docDir = Join-Path $Base 'UserHome\Documents'; Ensure-Dir $docDir
    $tmp = Join-Path $docDir ("jot_{0}.txt" -f (Get-Random -Minimum 1000 -Maximum 9999))
    if ((Get-Random -Minimum 0 -Maximum 10) -gt 4) {
        "Meeting notes $(Get-Date): random thought $([Guid]::NewGuid())" | Set-Content -Path $tmp
        Start-Process notepad.exe $tmp
    } else {
        Start-Process notepad.exe
    }
    Start-Sleep -Seconds 2
    Stop-Process -Name notepad -ErrorAction SilentlyContinue
}
function Fake-TeamsLogs {
    $logDir = Join-Path $env:APPDATA 'PhantomTeams\logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $entry = @{
        ts = (Get-Date).ToString("o")
        user = ($env:USERNAME)
        event = (Get-Random @('join','leave','message','file_open'))
        room = (Get-Random @('IT-Standup','Finance-QBR','HR-Policy','Sales-Weekly'))
    } | ConvertTo-Json -Compress
    Add-Content -Path (Join-Path $logDir "events.jsonl") -Value $entry
}

# --------- Personas ----------
function Initialize-Personas {
@"
[
 { "name":"Finance",
   "actions":[ "Browse-Intranet", "New-DeptDoc Finance", "Touch-DocLifecycle", "Open-CommonFolders", "Create-Archives", "Print-ToPDF", "Fake-TeamsLogs" ],
   "intervalSec":[20,60]
 },
 { "name":"HR",
   "actions":[ "Browse-Intranet", "New-DeptDoc HR", "Touch-DocLifecycle", "Open-CommonFolders", "Fake-TeamsLogs", "Defender-QuickScan" ],
   "intervalSec":[25,70]
 },
 { "name":"IT",
   "actions":[ "Browse-Intranet", "New-DeptDoc IT", "Invoke-ExplorerChurn", "Open-CommonFolders", "Create-Archives", "Defender-QuickScan", "RDP-Noise", "Fake-TeamsLogs" ],
   "intervalSec":[15,50]
 },
 { "name":"Sales",
   "actions":[ "Browse-Intranet", "New-DeptDoc Sales", "Touch-DocLifecycle", "Open-CommonFolders", "Create-Archives", "Fake-TeamsLogs" ],
   "intervalSec":[20,60]
 }
]
"@ | Set-Content -Path (Join-Path $Personas 'personas.json') -Encoding UTF8
}

# --------- Orchestrator ----------
function Invoke-Action {
    param([string]$Action,[string[]]$Args)
    switch -Wildcard ($Action) {
        'Browse-Intranet'         { Browse-Intranet }
        'New-DeptDoc *'           { $dept = $Action.Split()[1]; $p = New-DeptDoc -Department $dept; Write-Log "Created $p" }
        'Touch-DocLifecycle'      {
            $any = Get-ChildItem -Path $Docs -Recurse -File -ErrorAction SilentlyContinue | Get-Random -Count 1 -ErrorAction SilentlyContinue
            if ($any) { Touch-DocLifecycle -Path $any.FullName }
        }
        'Invoke-ExplorerChurn'    { Invoke-ExplorerChurn }
        'Submit-ITRequest'        { Submit-ITRequest }
        'Open-CommonFolders'      { Open-CommonFolders }
        'Create-Archives'         { Create-Archives }
        'Print-ToPDF'             { Print-ToPDF }
        'Defender-QuickScan'      { Defender-QuickScan }
        'RDP-Noise'               { RDP-Noise }
        'Notes-Habits'            { Notes-Habits }
        'Fake-TeamsLogs'          { Fake-TeamsLogs }
        default                   { Write-Log "Unknown action: $Action" }
    }
}
function Invoke-PhantomWorkforce {
    param([int]$DurationMinutes = 15,[string]$PersonaName)
    Start-LocalIntranet
    Initialize-Content
    if (-not (Test-Path (Join-Path $Personas 'personas.json'))) { Initialize-Personas }

    $personas = Get-Content -Raw (Join-Path $Personas 'personas.json') | ConvertFrom-Json
    if ($PersonaName) { $personas = $personas | Where-Object { $_.name -eq $PersonaName } }
    if (-not $personas) { throw "No personas defined" }

    $end = (Get-Date).AddMinutes($DurationMinutes)
    Write-Log "Starting run until $end"
    while ((Get-Date) -lt $end) {
        $p = $personas | Get-Random
        $act = $p.actions | Get-Random
        Write-Log ("[{0}] {1}" -f $p.name, $act)
        Invoke-Action -Action $act
        $min = [int]$p.intervalSec[0]; $max=[int]$p.intervalSec[1]
        Invoke-RandomSleep -Min $min -Max $max
    }
    Write-Log "Run complete"
}

# --------- Optional hostnames (admin) ----------
function Set-LocalIntranetHostnames {
    param([string[]]$Names = @('intranet','hr','wiki'))
    $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $isAdmin = $false }
    if (-not $isAdmin) { Write-Log "Skipping hosts modification (admin required)"; return }
    foreach ($n in $Names) {
        $entry = "127.0.0.1`t$n"
        if (-not (Select-String -Path $hosts -Pattern "^\s*127\.0\.0\.1\s+$n\s*$" -Quiet)) {
            Add-Content -Path $hosts -Value $entry
        }
    }
    Write-Log "Hosts entries added: $($Names -join ', ')"
}

# --------- One-shot entry point ----------
if ($Run) { Invoke-PhantomWorkforce -DurationMinutes $DurationMinutes -PersonaName $PersonaName; return }

# --------- Usage (if executed directly without -Run or dot-sourcing) ----------
if ($MyInvocation.InvocationName -ne '.') {
@"
Usage:

  # One-shot (no dot-sourcing)
  powershell -ExecutionPolicy Bypass -NoProfile -File .\Invoke-PhantomWorkforce.ps1 -Run -DurationMinutes 30 -PersonaName Finance

  # Interactive
  . .\Invoke-PhantomWorkforce.ps1
  Start-LocalIntranet
  Invoke-PhantomWorkforce -DurationMinutes 30 -PersonaName Finance
"@ | Write-Host
}
