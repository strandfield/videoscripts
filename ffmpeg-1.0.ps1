
enum StreamType {
    Video
    Audio
    Subtitle
    Other
}

class Stream
{
    [ValidateNotNullOrEmpty()][int]$StreamNum
    [ValidateNotNullOrEmpty()][StreamType]$StreamType
    [string]$Lang = $null

    Stream($StreamNum, $StreamType) {
       $this.StreamType = $StreamType
       $this.StreamNum = $StreamNum
    }
}

$global:FFmpegLogFile = $null
# TODO: add a FFmpegExistingOutputFilePolicy : skip or overwrite
$global:FFmpegAudioNormalizationMethod = "peak"

$global:FFmpegPeakAudioNormalizationTarget = -0.1
$global:FFmpegPeakAudioNormalizationActivationThreshold = -0.3

# puts a filepath around quotes if it contains spaces
function FFmpeg-FilePath {
    param (
      [ValidateNotNullOrEmpty()][string]$arg
    )
    
    if ($arg.startsWith('"') -and $arg.endsWith('"')) {
      return $arg
    }
    
    if($arg -match ' ') {
        return '"' + $arg + '"'
    } else {
        return $arg 
    }
}

function Invoke-FFmpeg {
    param(
        $Command,
        $Output = $null,
        $HideBanner = $true,
        $NoStats = $true,
        $LogFile = $global:FFmpegLogFile
    )
    
    $fullcmd = "ffmpeg"
    if ($HideBanner) {
        $fullcmd += " -hide_banner "
    }
    if ($NoStats) {
        $fullcmd += " -nostats "
    }
    
    $fullcmd += " " + $Command
    
    if ($Output -ne $null) {
        if ($Output | Test-Path) {
            return
        }
        
        $Output = FFmpeg-FilePath $Output
        $fullcmd += " " + $Output
    }
    
    if ($LogFile -ne $null) {
        $pwd.ToString() + ("> " + $fullcmd) | Out-File -Encoding "utf8" -Append -FilePath $LogFile
        $fullcmd += " 2>>" + $LogFile
    }
    
    $fullcmd | Write-Output
    cmd.exe /c $fullcmd
    
    if ($LastExitCode -ne 0) {
        "Last exit code is nonzero: " + $LastExitCode | Write-Output
    }
}

function Get-StreamList {
    param (
        $FileName
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    $streams = @()
    $lines = (ffmpeg -i $FileName 2>&1) | Select-String -Pattern "Stream #0:" 
    
    foreach ($line in $lines) {
        $lang = $null;
        if ($line -match '#0:(\d+)\((\w+)\):') {
          $lang = $Matches[2] -as 'string'
        }
        
        if ($line -match '#0:(\d+).* Video:') {
          $stream = [Stream]::new(($Matches[1] -as 'int'), [StreamType]::Video)
          $stream.Lang = $lang
          $streams += $stream
        } elseif ($line -match '#0:(\d+).* Audio:') {
          $stream = [Stream]::new(($Matches[1] -as 'int'), [StreamType]::Audio)
          $stream.Lang = $lang
          $streams += $stream
        } elseif ($line -match '#0:(\d+).* Subtitle:') {
          $stream = [Stream]::new(($Matches[1] -as 'int'), [StreamType]::Subtitle)
          $stream.Lang = $lang
          $streams += $stream
        }
    }

    return $streams
}

function ExtractAudioStream {
    param (
        $FileName,
        $StreamNum,
        $AC = 2,
        $OutName = $null
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    if ($OutName -eq $null) {
        $OutName = ($StreamNum -as [string]) + ".wav"
    }
    
    "Extracting audio stream $StreamNum" | Write-Output
    $command = "-i $FileName -map 0:$StreamNum -ac $AC"
    Invoke-FFmpeg $command $OutName
}

function Get-LoudnormParams {
    param (
        $FileName
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    $ans = (ffmpeg -hide_banner -nostats -i $FileName -filter:a loudnorm=print_format=json -f null -  2>&1) | Select-String -Pattern "Parsed_loudnorm"  -Context 0,12
    $json = $ans.Context.DisplayPostContext | Select-Object -Last 12 | ConvertFrom-Json
    #$json.input_i | Write-Output
    #if (($json.input_i -as 'int') -lt -24) {
    #    "needs normalization"| Write-Output
    #}
    #$json | ConvertTo-Json -Depth 4 | Write-Output
    return $json
}

function NormalizeAudio {
    param (
        $FileName,
        $OutName = $null,
        $Method = $null,
        $PeakTarget = $null,
        $PeakActivationThreshold = $null
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    if ($OutName -eq $null) {
        $OutName = (Get-Item $FileName).Basename + ".mka"
    }
    
    if ($Method -eq $null) {
        $Method = $global:FFmpegAudioNormalizationMethod
    }

    if ($null -eq $PeakTarget) {
        $PeakTarget = $global:FFmpegPeakAudioNormalizationTarget
    }

    if ($null -eq $PeakActivationThreshold) {
        $PeakActivationThreshold = $global:FFmpegPeakAudioNormalizationActivationThreshold
    }
    
    if ($Method -eq "peak") {
        $targetLevel = $PeakTarget
        $activationLevel = $PeakActivationThreshold
        $ans = (ffmpeg -hide_banner -nostats -i $FileName -filter:a astats=measure_overall=Peak_level:measure_perchannel=0 -f null -  2>&1) | Select-String -Pattern "Peak level dB:"
        if ($ans -match "Peak level dB: ([\-\d\.]+)") {
            echo $Matches[1]
            $level = [double]$Matches[1]
            echo $level
            if ($level -lt $activationLevel) {
                $level = -1 * $level
                $level = $level + $targetLevel
                $volumeFilter = "volume=" + $level + "dB"
                $command = "-i $FileName -filter:a $volumeFilter -c:a libopus"
                Invoke-FFmpeg $command $OutName
            } else {
                echo "No normalization needed"
                $command = "-i $FileName -c:a libopus"
                Invoke-FFmpeg $command $OutName
            }
        } else {
            throw "badaboom"
        }
    } elseif ($Method -eq "dynaudnorm") {
        $command = "-i $FileName -filter:a dynaudnorm -c:a libopus"
        Invoke-FFmpeg $command $OutName
    } else {
        $loudnorm = Get-LoudnormParams $FileName
        $loudnorm | ConvertTo-Json -Depth 4 | Write-Output
        $input_i = $loudnorm.input_i
        $input_tp = $loudnorm.input_tp
        $input_lra = $loudnorm.input_lra 
        $input_thresh = $loudnorm.input_thresh
        $loudnormfilter = "loudnorm=linear=true:measured_I=" + $input_i + ":measured_tp=" + $input_tp + ":measured_LRA=" + $input_lra + ":measured_thresh=" + $input_thresh + ":print_format=summary"
        $command = "-i $FileName -filter:a $loudnormfilter -ar 48000 -c:a libopus"
        Invoke-FFmpeg $command $OutName
    }
}

function ConvertAudioStream {
    param (
        $FileName,
        $StreamNum,
        $AC = 2,
        $Normalize = $true,
        $OutName = $null
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    if($Normalize) {
        # TODO: check if normalization is actually needed ?
        
        if ($OutName -eq $null) {
            throw "ConvertAudioStream needs an ouptut name"
        } elseif ($OutName | Test-Path) {
            return
        }
        
        $wavfile = ($StreamNum -as 'string') + ".wav"
        ExtractAudioStream $FileName $StreamNum -AC $AC -OutName $wavfile
        echo "Extracting completed, running audio normalization..."
        NormalizeAudio $wavfile $OutName
        echo "Normalization completed!"
        echo "Removing wav file."
        Remove-Item $wavfile
    } else {
        if ($OutName -eq $null) {
            $OutName = ($StreamNum -as [string]) + ".mka"
        }
        
        $command = "-i $FileName -map 0:$StreamNum -c:a libopus -ac $AC"
        Invoke-FFmpeg $command $OutName
    }
}

function Get-VideoDuration {
    param (
        $FileName
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    $line = (ffmpeg -i $FileName 2>&1) | Select-String -Pattern "Duration: " | Select-Object -First 1
    $ok = $line -match 'Duration: (\d+):(\d+):(\d+).(\d+)'
    if ($ok -eq $False) {
        throw "could not parse video duration" 
    }
    $hours =  $Matches[1] -as 'int'
    $minutes =  $Matches[2] -as 'int'
    $seconds =  $Matches[3] -as 'int'
    return $hours * 3600 + $minutes * 60 + $seconds
}

function Get-CropDetectAt {
    param (
        $FileName,
        $Timestamp
    )
    
    $FileName = FFmpeg-FilePath $FileName
    
    $line = (ffmpeg -hide_banner -nostats -ss $Timestamp -i $FileName -t 2 -vf cropdetect -f null - 2>&1) | Select-String -Pattern "Parsed_cropdetect" | Select-Object -Last 1
    $ok = $line -match 'crop=(\d+):(\d+):(\d+):(\d+)'
    if ($ok -eq $False) {
        throw "cropdetect failed"
    }
    return $Matches[0]
}

function Get-CropDetect {
    param (
        $FileName
    )
    
    $length = Get-VideoDuration $FileName
    $fastforward = ($length / 2) -as 'int'
    $crop = Get-CropDetectAt $FileName $fastforward
    $fastforward = ($length / 3) -as 'int'
    $crop2 = Get-CropDetectAt $FileName $fastforward
    $fastforward = (2 * $length / 3) -as 'int'
    $crop3 = Get-CropDetectAt $FileName $fastforward
    if (($crop -eq $crop2) -and ($crop -eq $crop3)) {
        return $crop
    } else {
        $crop | Write-Host
        $crop2 | Write-Host
        $crop3 | Write-Host
        throw "cropdetect detected different crop values"
    }
}

function Get-CropDetectAll {
    param (
        $Pattern = "*.mkv"
    )
    
  Get-Item $Pattern | % { $file = $_; try { Write-Host ($file.Name + ":" + (Get-CropDetect $file))} catch { Write-Host ($file.Name + " failed")} }
}

function ConvertVideoStream {
    param (
        $FileName,
        $StreamNum,
        $OutName = $null,
        $Crop = "detect",
        $Deinterlace = $false,
        $Denoise = $false,
        $BurnSubtitle = $null,
        $Scale = $null,
        $CRF = 24,
        $Preset = "medium",
        $Tune = $null
    )
    
    if ($OutName -eq $null) {
        $OutName = ($StreamNum -as [string]) + ".mkv"
    }
    
    if ($BurnSubtitle -ne $null) {
      BurnSubtitles -FileName $FileName -VideoStreamNum $StreamNum -SubtitleTrackNum $BurnSubtitle -OutName $OutName `
        -Crop $Crop -Deinterlace $Deinterlace -Denoise $Denoise -Scale $Scale -CRF $CRF -Preset $Preset -Tune $Tune
      return
    }
    
    $videofilters = @()
    
    if(($Crop -eq "detect") -or ($Crop -eq $true)) {
        $Crop = Get-CropDetect $FileName
    } elseif (($Crop -eq "none") -or ($Crop -eq $false)) {
        $Crop = $null
    } elseif ($Crop -is [string]) {
        if ($Crop -match '(\d+):(\d+):(\d+):(\d+)') {
            $Crop = "crop=" + $Matches[0]
            ("Using filter " + $Crop) | Write-Host
        } else {
            throw ("invalid crop spec: " + $Crop)
        }
    }
    
    if ($Crop -is [string]) {
      $videofilters += $Crop
    }
        
    if($Deinterlace) {
        $nnweights = $PSScriptRoot + "/nnedi3_weights.bin"
        $nnweights = Resolve-Path -relative $nnweights
        $nnweights = $nnweights.replace('\', '/')
        $videofilters += ("nnedi=weights=" + $nnweights)
    }
    
    if($Denoise) {
        $videofilters += "hqdn3d"
    }
    
    if (($Scale -eq "none") -or ($Scale -eq $false)) {
        $Scale = $null
    } elseif ($Scale -is [string]) {
        if ($Scale -match "(-?\d+):(-?\d+)") {
            $Scale = "scale=" + $Matches[0]
            ("Using filter " + $Scale) | Write-Host
        } else {
            throw ("invalid scale spec: " + $Scale)
        }
    }
    
    if ($Scale -is [string]) {
      $videofilters += $Scale
    }
    
    if ($videofilters.length -ne 0) {
      $videofilters = "-vf " + ($videofilters -Join ",")
    }
    
    $tuneopts = ""
    if ($Tune -ne $null) {
        $tuneopts = "-tune " + $Tune
    }
    
    $FileName = FFmpeg-FilePath $FileName
    $command = "-i $FileName -map 0:$StreamNum $videofilters -c:v libx265 -preset $Preset $tuneopts -crf $CRF -tag:v hvc1"
    $command = $command.replace("  ", " ")
    Invoke-FFmpeg $command $OutName
}

function BurnSubtitles {
    param (
        $FileName,
        $VideoStreamNum,
        $SubtitleTrackNum,
        $OutName,
        $Crop = $false,
        $Deinterlace = $false,
        $Denoise = $false,
        $Scale = $null,
        $CRF = 24,
        $Preset = "medium",
        $Tune = $null
    )
    
    $videofilters = @()
    
    if (($Crop -eq "none") -or ($Crop -eq $false)) {
        $Crop = $null
    } elseif ($Crop -is [string]) {
        if ($Crop -match '(\d+):(\d+):(\d+):(\d+)') {
            $Crop = "crop=" + $Matches[0]
            ("Using filter " + $Crop) | Write-Host
        } else {
            throw ("invalid crop spec: " + $Crop)
        }
    }
    
    if ($Crop -is [string]) {
      $videofilters += $Crop
    }
        
    if($Deinterlace) {
        $nnweights = $PSScriptRoot + "/nnedi3_weights.bin"
        $nnweights = Resolve-Path -relative $nnweights
        $nnweights = $nnweights.replace('\', '/')
        $videofilters += ("nnedi=weights=" + $nnweights)
    }
    
    if($Denoise) {
        $videofilters += "hqdn3d"
    }
    
    if (($Scale -eq "none") -or ($Scale -eq $false)) {
        $Scale = $null
    } elseif ($Scale -is [string]) {
        if ($Scale -match "(-?\d+):(-?\d+)") {
            $Scale = "scale=" + $Matches[0]
            ("Using filter " + $Scale) | Write-Host
        } else {
            throw ("invalid scale spec: " + $Scale)
        }
    }
    
    if ($Scale -is [string]) {
      $videofilters += $Scale
    }
    
    $filtercomplex = "`"[0:$VideoStreamNum][0:$SubtitleTrackNum]overlay"
    if ($videofilters.length -ne 0) {
      $filtercomplex += "[tmp];[tmp]" + ($videofilters -Join ",") + "[v]`""
    } else {
      $filtercomplex += "[v]`""
    }

    $tuneopts = ""
    if ($Tune -ne $null) {
        $tuneopts = "-tune " + $Tune
    }
    
    $FileName = FFmpeg-FilePath $FileName
    #ffmpeg -y  -i "Inglourious Basterds_t00.mkv" -filter_complex "[0:v][0:7]overlay[tmp];[tmp]crop=1920:800:0:140[v]" -map "[v]" -c:v libx265 -preset medium -crf 24 -tag:v hvc1 "temp/Inglourious Basterds_t00.video.mkv"
    $command = "-i $FileName -filter_complex $filtercomplex -map `"[v]`" -c:v libx265 -preset $Preset $tuneopts -crf $CRF -tag:v hvc1"
    $command = $command.replace("  ", " ")
    Invoke-FFmpeg $command $OutName
}

function ExtractAllAudioStreams {
    param (
        $FileName,
        $OutName = $null
    )
    
    if ($OutName -eq $null) {
        $OutName = (Get-Item $FileName).Basename + ".mka"
    }
    
    $FileName = FFmpeg-FilePath $FileName
    $OutName = FFmpeg-FilePath $OutName
    
    $command = "-i $FileName "
    
    $streams = Get-StreamList $FileName
    
    foreach ($stream in $streams) {
        if ($stream.StreamType -eq [StreamType]::Audio) {
            $command += "-map 0:" + ($stream.StreamNum -as 'string') + " "
        } 
    }
    
    $command += "-c:a copy"
    Invoke-FFmpeg $command $OutName -LogFile $null
}

function ExtractAllSubtitleStreams {
    param (
        $FileName,
        $OutName = $null
    )
    
    if ($OutName -eq $null) {
        $OutName = (Get-Item $FileName).Basename + ".mkv" # ffmpeg does not support mks output
    }
    
    $FileName = FFmpeg-FilePath $FileName
    $OutName = FFmpeg-FilePath $OutName 
    
    $command = "-i $FileName "
    
    $streams = Get-StreamList $FileName
    $n = 0
    
    foreach ($stream in $streams) {
        if ($stream.StreamType -eq [StreamType]::Subtitle) {
            $n += 1
            $command += "-map 0:" + ($stream.StreamNum -as 'string') + " "
        } 
    }
    
    if ($n -eq 0) {
        echo "There are no subtitles in this file"
        return $null
    }
    
    $command += "-c:a none -c:v none -c:s copy"
    Invoke-FFmpeg $command $OutName -LogFile $null
}

