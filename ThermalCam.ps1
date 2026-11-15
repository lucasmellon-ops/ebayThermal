# ThermalCam.ps1 - UART control for a "TIF384 / TIFS384" analog thermal camera module
# (sold as "Partizan 640"). Windows PowerShell 5.1 or later, no extra installs.
#
# Load it into your session:
#     Set-ExecutionPolicy -Scope Process Bypass
#     . .\ThermalCam.ps1
# or just paste the whole file into a PowerShell window.
#
# Then:  Cam-Info   Cam-Zoom 2.0   Cam-BlackHot   Cam-WhiteHot   Cam-Help
#
# Nothing in this file saves settings, restores defaults, calibrates,
# or touches firmware. See docs/protocol.md for what is deliberately left out.

if (-not $global:CamPort) { $global:CamPort = 'COM10' }
$global:CamBaud = 115200

function Cam-Ports {
    # Lists the serial ports Windows can see right now.
    [System.IO.Ports.SerialPort]::GetPortNames()
}

function Cam-Port([string]$Name) {
    # Show or change which COM port is used, e.g.  Cam-Port COM5
    if ($Name) { $global:CamPort = $Name }
    Write-Host "Using $global:CamPort at $global:CamBaud 8N1"
}

function Get-Crc16([byte[]]$bytes) {
    # CRC-16/XMODEM (poly 0x1021, init 0)
    $crc = 0
    foreach ($b in $bytes) {
        $crc = $crc -bxor ([int]$b -shl 8)
        for ($i = 0; $i -lt 8; $i++) {
            if ($crc -band 0x8000) { $crc = (($crc -shl 1) -bxor 0x1021) -band 0xFFFF }
            else { $crc = ($crc -shl 1) -band 0xFFFF }
        }
    }
    return $crc
}

function Cam-Send($Class, $Module, $Cmd, $Offsets = @{}, $Size = 0) {
    # Builds one 23-byte request, sends it, and returns the checked reply.
    #   body[0]=class  body[1]=module  body[2]=command
    #   $Offsets     = extra body bytes, e.g. @{4=1} or @{5=20}
    #   body[12]     = number of data bytes wanted back (0 for a write)
    [byte[]]$body = New-Object byte[] 16
    $body[0] = $Class; $body[1] = $Module; $body[2] = $Cmd
    foreach ($k in $Offsets.Keys) { $body[[int]$k] = [byte]$Offsets[$k] }
    $body[12] = $Size
    $crc = Get-Crc16 $body
    [byte[]]$query = @(0x55,0x43,0x49,0x12,0x00) + $body + @([byte]($crc -band 255),[byte]($crc -shr 8))

    $result = [pscustomobject]@{ Ok = $false; Status = -1; Data = @(); Reason = '' }
    $port = [System.IO.Ports.SerialPort]::new($global:CamPort,$global:CamBaud,'None',8,'One')
    $port.Handshake = 'None'; $port.ReadTimeout = 500; $port.WriteTimeout = 1000
    try {
        $port.Open()
        $port.DiscardInBuffer()
        $port.Write($query,0,$query.Length)
        $rx = [System.Collections.Generic.List[byte]]::new()
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $expected = 0
        while ($timer.ElapsedMilliseconds -lt 1500) {
            if ($port.BytesToRead -gt 0) {
                $rx.Add([byte]$port.ReadByte())
                if ($rx.Count -eq 4) { $expected = 8 + [int]$rx[2] + 256*[int]$rx[3] }
                if ($expected -ge 9 -and $rx.Count -ge $expected) { break }
            } else { Start-Sleep -Milliseconds 5 }
        }
        [byte[]]$r = $rx.ToArray(); $n = $r.Length
        if ($n -eq 0) { $result.Reason = 'no reply (check power, wiring, port)'; return $result }
        if ($n -lt 9) { $result.Reason = 'reply too short'; return $result }
        $len = [int]$r[2] + 256*[int]$r[3]
        if ($r[0] -ne 0xBE -or $r[1] -ne 0xAA -or $r[$n-2] -ne 0xEB -or $r[$n-1] -ne 0xAA -or $n -ne ($len+8)) {
            $result.Reason = 'unexpected packet'; return $result
        }
        $calc = Get-Crc16 ($r[0..($n-5)])
        if ($calc -ne ([int]$r[$n-4] + 256*[int]$r[$n-3])) { $result.Reason = 'checksum mismatch'; return $result }
        $result.Status = [int]$r[4]
        $result.Ok = ($r[4] -eq 0)
        if (-not $result.Ok) { $result.Reason = ('camera status {0:X2}' -f $r[4]) }
        if ($len -gt 1) { $result.Data = @($r[5..($len+3)]) }
    }
    catch { $result.Reason = $_.Exception.Message }
    finally { $port.Dispose() }
    return $result
}

# ---------------------------------------------------------------- reading

function Cam-Text($Arg, $Size) {
    $r = Cam-Send 0x01 0x01 0x81 @{4=$Arg} $Size
    if (-not $r.Ok) { return "($($r.Reason))" }
    [byte[]]$d = @($r.Data)
    return ([Text.Encoding]::ASCII.GetString($d) -split "`0",2)[0].Trim()
}

function Cam-Hex($Arg, $Size) {
    $r = Cam-Send 0x01 0x01 0x81 @{4=$Arg} $Size
    if (-not $r.Ok) { return "($($r.Reason))" }
    return (@($r.Data) | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
}

function Cam-Num($Class, $Module, $Cmd, $Offsets = @{}, $Size = 1) {
    # Returns a number, or $null if the camera did not give a good answer.
    $r = Cam-Send $Class $Module $Cmd $Offsets $Size
    $global:CamLastReason = $r.Reason
    if (-not $r.Ok) { return $null }
    [byte[]]$d = @($r.Data)
    if ($d.Length -lt $Size) { $global:CamLastReason = 'short data'; return $null }
    $v = [int]$d[0]
    if ($Size -eq 2) { $v += 256*[int]$d[1] }
    return $v
}

function Cam-Show($Label, $Value) {
    if ($null -eq $Value) { $Value = "($global:CamLastReason)" }
    Write-Host ('{0,-16}{1}' -f $Label, $Value)
}

function Cam-Info {
    Write-Host ''
    Cam-Show 'Device name'   (Cam-Text 1  0x1E)
    Cam-Show 'Part number'   (Cam-Text 6  0x40)
    Cam-Show 'Firmware'      (Cam-Text 2  0x0C)
    Cam-Show 'Serial number' (Cam-Text 7  0x40)
    Cam-Show 'Sensor type'   (Cam-Text 14 0x40)
    Cam-Show 'Sensor ID'     (Cam-Hex  15 0x40)
    $w = Cam-Num 0x10 0x03 0x81 @{4=2} 2
    $h = Cam-Num 0x10 0x03 0x81 @{4=3} 2
    if ($null -ne $w -and $null -ne $h) { Cam-Show 'Preview' "$w x $h" } else { Cam-Show 'Preview' $null }
    $z = Cam-Num 0x01 0x31 0x82
    if ($null -ne $z) { Cam-Show 'Zoom' ('{0:0.0}x' -f ($z/10.0)) } else { Cam-Show 'Zoom' $null }
    $p = Cam-Num 0x10 0x03 0x85
    $pname = switch ($p) { 0 {' (white hot)'} 10 {' (black hot)'} default {''} }
    if ($null -ne $p) { Cam-Show 'Palette' "$p$pname" } else { Cam-Show 'Palette' $null }
    Cam-Show 'Brightness'    (Cam-Num 0x10 0x04 0x87 @{4=1})
    Cam-Show 'Contrast'      (Cam-Num 0x10 0x04 0x88 @{4=1})
    Cam-Show 'Mirror/flip'   (Cam-Num 0x10 0x10 0x83)
    Write-Host ''
}

# --------------------------------------------------------------- changing
# Every setter reads the value first. If the read fails, nothing is written.
# Success is judged by reading the value back, not by the reply status:
# on the tested camera, palette writes answer status 01 and still take effect.

function Cam-Set($Name, $Get, $Write) {
    $before = & $Get
    if ($null -eq $before) {
        Write-Host "$Name not changed: could not read it first ($global:CamLastReason)."
        return
    }
    $w = & $Write
    Start-Sleep -Milliseconds 200
    Write-Host ("{0}: {1} -> {2}   (reply status {3:X2})" -f $Name, $before, (& $Get), $w.Status)
}

function Cam-Zoom([double]$Scale) {
    if ($Scale -lt 1.0 -or $Scale -gt 8.0) { Write-Host 'Zoom must be 1.0 to 8.0'; return }
    $b = [int][math]::Floor(($Scale + 0.05) * 10)
    Cam-Set 'Zoom' { $x = Cam-Num 0x01 0x31 0x82; if ($null -ne $x) { '{0:0.0}x' -f ($x/10.0) } } { Cam-Send 0x01 0x31 0x42 @{5=$b} }
}

function Cam-Palette([int]$Index) {
    if ($Index -lt 0 -or $Index -gt 11) { Write-Host 'Palette must be 0 to 11 (0 = white hot, 10 = black hot)'; return }
    Cam-Set 'Palette' { Cam-Num 0x10 0x03 0x85 } { Cam-Send 0x10 0x03 0x45 @{5=$Index} }
}
function Cam-WhiteHot { Cam-Palette 0 }
function Cam-BlackHot { Cam-Palette 10 }

function Cam-Brightness([int]$Level) {
    if ($Level -lt 0 -or $Level -gt 100) { Write-Host 'Brightness must be 0 to 100'; return }
    Cam-Set 'Brightness' { Cam-Num 0x10 0x04 0x87 @{4=1} } { Cam-Send 0x10 0x04 0x47 @{4=$Level} }
}

function Cam-Contrast([int]$Level) {
    if ($Level -lt 0 -or $Level -gt 100) { Write-Host 'Contrast must be 0 to 100'; return }
    Cam-Set 'Contrast' { Cam-Num 0x10 0x04 0x88 @{4=1} } { Cam-Send 0x10 0x04 0x48 @{4=$Level} }
}

function Cam-Mirror([int]$Mode) {
    if ($Mode -lt 0 -or $Mode -gt 3) { Write-Host 'Mirror must be 0 to 3 (0 none, 1 mirror, 2 flip, 3 both)'; return }
    Cam-Set 'Mirror/flip' { Cam-Num 0x10 0x10 0x83 } { Cam-Send 0x10 0x10 0x43 @{4=$Mode} }
}

function Cam-Help {
    Write-Host @'

  Cam-Ports            list serial ports
  Cam-Port COM5        choose the port (default COM10)
  Cam-Info             read and print everything
  Cam-Zoom 2.0         digital zoom, 1.0 to 8.0
  Cam-WhiteHot         palette 0
  Cam-BlackHot         palette 10
  Cam-Palette 0        palette by number
  Cam-Brightness 50    0 to 100
  Cam-Contrast 50      0 to 100
  Cam-Mirror 0         0 none, 1 mirror, 2 flip, 3 both

'@
}

Write-Host "ThermalCam loaded. Port: $global:CamPort. Type Cam-Help for commands."
