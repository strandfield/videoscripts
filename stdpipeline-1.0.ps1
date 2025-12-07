
Import-Module "$PSScriptRoot/ffmpeg-1.0.ps1"
Import-Module "$PSScriptRoot/mkvmerge-1.0.ps1"

$global:PipelineOriginalLanguage = $undefined
$global:PipelineSubFre = $undefined
$global:PipelineSubFreForced = $undefined
$global:PipelineSubEng = $undefined
$global:PipelineSubEngSDH = $undefined
$global:PipelineSubEngForced = $undefined
$global:PipelineSubBurn = $undefined

$global:PipelineCrop = $undefined
$global:PipelineDeinterlace = $undefined
$global:PipelineDenoise = $undefined
$global:PipelineScale = $undefined
$global:PipelineCRF = $undefined
$global:PipelinePreset = $undefined
$global:PipelineTune = $undefined
$global:PipelineAC = $undefined

$global:PipelineDeduceOuputFromTitle = $undefined

$global:PipelineKeepVideoChapters = $true

function Rename-Video-Files {
  Get-Item  *.mkv | where { $_.Name -match 't\d+' } | Rename-Item -NewName { $_.Name -replace '.+(t\d+)' , '$1' }
}

function Setup-SubtitleTrackNumbers {
    param (
        $SubFre = $null,
        $SubFreForced = $null,
        $SubEng = $null,
        $SubEngSDH = $null,
        $SubEngForced = $null,
        $SubBurn = $null
    )
    
    if ($SubFre -ne $null) {
        echo "French subtitle track number is $SubFre"
        $global:PipelineSubFre = $SubFre
    }
    
    if ($SubFreForced -ne $null) {
        echo "French (forced) subtitle track number is $SubFreForced"
        $global:PipelineSubFreForced = $SubFreForced
    }
    
    if ($SubEng -ne $null) {
        echo "English subtitle track number is $SubEng"
        $global:PipelineSubEng = $SubEng
    }
    
    if ($SubEngSDH -ne $null) {
        echo "English (SDH) subtitle track number is $SubEngSDH"
        $global:PipelineSubEngSDH = $SubEngSDH
    }
    
    if ($SubEngForced -ne $null) {
        echo "English (forced) subtitle track number is $SubEngForced"
        $global:PipelineSubEngForced = $SubEngForced
    }
    
    if ($SubBurn -ne $null) {
        echo "Burning subtitle track #$SubBurn"
        $global:PipelineSubBurn = $SubBurn
    }
}

function Set-SubtitleTrackNumbers {
    param (
        $SubFre = $null,
        $SubFreForced = $null,
        $SubEng = $null,
        $SubEngSDH = $null,
        $SubEngForced = $null,
        $SubBurn = $null
    )
    
    $global:PipelineSubFre = $undefined
    $global:PipelineSubFreForced = $undefined
    $global:PipelineSubEng = $undefined
    $global:PipelineSubEngSDH = $undefined
    $global:PipelineSubEngForced = $undefined
    $global:PipelineSubBurn = $undefined
    Setup-SubtitleTrackNumbers -SubFre $SubFre -SubFreForced $SubFreForced -SubEng $SubEng -SubEngSDH $SubEngSDH -SubEngForced $SubEngForced -SubBurn $SubBurn
}

function Setup-OriginalLanguage {
    param (
        $OriginalLanguage
    )
    
    if ($OriginalLanguage -ne $null) {
        echo "Original language is $OriginalLanguage"
        $global:PipelineOriginalLanguage = $OriginalLanguage
    }
}

function Setup-Pipeline {
    param (
        [ValidateNotNullOrEmpty()][int]$AC,
        $Crop = $null,
        $Deinterlace = $null,
        $Denoise = $null,
        $Scale = $null,
        [ValidateNotNullOrEmpty()][int]$CRF,
        $Preset = $null,
        $Tune = $null,
        $SubFre = $null,
        $SubFreForced = $null,
        $SubEng = $null,
        $SubEngSDH = $null,
        $SubEngForced = $null,
        $SubBurn = $null,
        $OriginalLanguage = $null,
        $DeduceOuputFromTitle = $null,
        $KeepVideoChapters = $null
    )
    
    if ((Test-Path "temp") -eq $false) { 
        echo "Creating temp directory"
        New-Item -ItemType Directory -Name "temp"
    }
    
    if ($Preset -ne $null) {
        echo "Setting video preset to $Preset"
        $global:PipelinePreset = $Preset
    } else {
        echo "Preset is set to 'medium'"
        $global:PipelinePreset = 'medium'
    }
    
    if ($Tune -ne $null) {
        echo "Setting video tune to $Tune"
        $global:PipelineTune = $Tune
    } else {
        $global:PipelineTune = $null
    }
    
    if ($Crop -ne $null) {
        echo "Using crop settings: $Crop"
        $global:PipelineCrop = $Crop
    } else {
        echo "Crop is set to 'detect'"
        $global:PipelineCrop = 'detect'
    }
    
    if ($Deinterlace -eq $true) {
        echo "Enabling video deinterlacing"
        $global:PipelineDeinterlace = $true
    } else {
        $global:PipelineDeinterlace = $false
    }
    
    if ($Denoise -eq $true) {
        echo "Enabling grain reduction filter"
        $global:PipelineDenoise = $true
    } else {
        $global:PipelineDenoise = $false
    }
    
    if ($Scale -ne $null) {
        echo "Using user-specified scale parameter: $Scale"
        $global:PipelineScale = $Scale
    } else {
        echo "Scale is set to false"
        $global:PipelineScale = $false
    }
    
    echo "Setting CRF to $CRF"
    $global:PipelineCRF = $CRF
    
    if ($AC -eq 2) {
        echo "Audio output is set to Stereo"
    } elseif ($AC -eq 1) {
        echo "Audio output is set to Mono"
    } else {
        echo "Setting audio channels to $AC"
    }
    
    $global:PipelineAC = $AC
    
    $global:PipelineDeduceOuputFromTitle = $DeduceOuputFromTitle
    if ($DeduceOuputFromTitle -eq $true) {
        echo "Output file name will be deduce from title"
        
        if ((Test-Path "output") -eq $false) { 
            echo "Creating output directory"
            New-Item -ItemType Directory -Name "output"
        }
    }
    
    Setup-SubtitleTrackNumbers -SubFre $SubFre -SubFreForced $SubFreForced -SubEng $SubEng -SubEngSDH $SubEngSDH -SubEngForced $SubEngForced -SubBurn $SubBurn
    Setup-OriginalLanguage -OriginalLanguage $OriginalLanguage
    
    if ($KeepVideoChapters -ne $null) {
        echo "keep video chapters is $KeepVideoChapters"
        $global:PipelineKeepVideoChapters = $KeepVideoChapters
    }
}

function Setup-PipelineAnimeDVD {
    param (
        $AC = 1,
        $Crop = 'detect',
        $Denoise = $null,
        $Scale = $null,
        $CRF = 23,
        $Preset = 'medium',
        $SubFre = $null,
        $SubFreForced = $null,
        $SubEng = $null,
        $SubEngSDH = $null,
        $SubEngForced = $null,
        $OriginalLanguage = $null,
        $DeduceOuputFromTitle = $null,
        $KeepVideoChapters = $null
    )
    
    echo "Setting up anime pipeline (DVD)"
    
    Setup-Pipeline -Deinterlace $true -Denoise $Denoise -Tune 'animation' -Preset $Preset -Crop $Crop -Scale $Scale -CRF $CRF -AC $AC `
      -SubFre $SubFre -SubFreForced $SubFreForced -SubEng $SubEng -SubEngSDH $SubEngSDH -SubEngForced $SubEngForced `
      -OriginalLanguage $OriginalLanguage `
      -DeduceOuputFromTitle $DeduceOuputFromTitle `
      -KeepVideoChapters $KeepVideoChapters
}

function Setup-PipelineDVD {
    param (
        $AC = 2,
        $Crop = 'detect',
        $Denoise = $null,
        $Scale = $null,
        $CRF = 24,
        $Preset = 'medium',
        $SubFre = $null,
        $SubFreForced = $null,
        $SubEng = $null,
        $SubEngSDH = $null,
        $SubEngForced = $null,
        $OriginalLanguage = $null,
        $DeduceOuputFromTitle = $null
    )
    
    echo "Setting up DVD pipeline"
    
    Setup-Pipeline -Deinterlace $true -Denoise $Denoise -Preset $Preset -Crop $Crop -Scale $Scale -CRF $CRF -AC $AC `
      -SubFre $SubFre -SubFreForced $SubFreForced -SubEng $SubEng -SubEngSDH $SubEngSDH -SubEngForced $SubEngForced `
      -OriginalLanguage $OriginalLanguage `
      -DeduceOuputFromTitle $DeduceOuputFromTitle
}

function Setup-PipelineBluRay {
    param (
        $AC = 2,
        $Crop = 'detect',
        $Scale = $null,
        $Denoise = $null,
        $CRF = 24,
        $Preset = 'medium',
        $Tune = $null,
        $SubFre = $null,
        $SubFreForced = $null,
        $SubEng = $null,
        $SubEngSDH = $null,
        $SubEngForced = $null,
        $SubBurn = $null,
        $OriginalLanguage = $null,
        $DeduceOuputFromTitle = $null
    )
    
    echo "Setting up blu-ray pipeline"
    
    Setup-Pipeline -Preset $Preset -Tune $Tune -Deinterlace $false -Denoise $Denoise -Crop $Crop -Scale $Scale -CRF $CRF -AC $AC `
      -SubFre $SubFre -SubFreForced $SubFreForced -SubEng $SubEng -SubEngSDH $SubEngSDH -SubEngForced $SubEngForced -SubBurn $SubBurn `
      -OriginalLanguage $OriginalLanguage `
      -DeduceOuputFromTitle $DeduceOuputFromTitle
}

function Run-Pipeline {
    param (
        [ValidateNotNullOrEmpty()][string]$InputFilePath,
        [string]$Output,
        $Title = $null,
        $VideoStreamNum = "detect",
        $AudioFrStreamNum = "detect",
        $AudioEnStreamNum = "detect",
        $Crop = $null
    )
    
    $AC = $global:PipelineAC
    $Deinterlace = $global:PipelineDeinterlace
    $Denoise = $global:PipelineDenoise
    $Scale = $global:PipelineScale
    $CRF = $global:PipelineCRF
    $Preset = $global:PipelinePreset
    $Tune = $global:PipelineTune
    $SubFre = $global:PipelineSubFre
    $SubFreForced = $global:PipelineSubFreForced
    $SubEng = $global:PipelineSubEng
    $SubEngSDH = $global:PipelineSubEngSDH
    $SubEngForced = $global:PipelineSubEngForced
    $SubBurn = $global:PipelineSubBurn
    $OriginalLanguage = $global:PipelineOriginalLanguage
    $KeepVideoChapters = $global:PipelineKeepVideoChapters
    
    if ($Crop -ne $null) {
        echo "Settings custom crop to '$Crop'"
        $global:PipelineCrop = $Crop
    } else {
        $Crop = $global:PipelineCrop
    }

    echo "Starting pipeline..."
    
    if (($Output -eq $null) -or ($Output -eq "")) {
        if (($global:PipelineDeduceOuputFromTitle -eq $true) -and ($Title -ne $null)) {
            $Output = $Title + ".mkv"
            $Output = $Output -replace " ", "." -replace "[,:!\?\*]", "." -replace "(\.)+", "."
            $Output = "output/" + $Output
            echo "Deduced output file name: $Output"
        } else {
            throw "Output file name must be specified"
        }
    }
        
    $AllStreams = Get-StreamList $InputFilePath
    "Found " + ($AllStreams.count -as [string]) + " streams" | Write-Output
        
    foreach ($stream in $AllStreams) {
        if ($stream.StreamType -eq [StreamType]::Video) {
            if ($VideoStreamNum -eq "detect") {
                $VideoStreamNum = $stream.StreamNum
                echo "Video stream detected: $VideoStreamNum"
            }
        } elseif ($stream.StreamType -eq [StreamType]::Audio) {
            if(($stream.Lang -eq "fre") -or ($stream.Lang -eq "fra") -or ($stream.Lang -eq "fr")) {
                if ($AudioFrStreamNum -eq "detect") {
                    $AudioFrStreamNum = $stream.StreamNum
                    echo "Audio (fre) stream detected: $AudioFrStreamNum"
                }
            } elseif($stream.Lang -eq "eng") {
                if ($AudioEnStreamNum -eq "detect") {
                    $AudioEnStreamNum = $stream.StreamNum
                    echo "Audio (eng) stream detected: $AudioEnStreamNum"
                }
            }
        }
    }
    
    if ($VideoStreamNum -isnot [int]) {
        $VideoStreamNum = $null
    }
    if ($AudioFrStreamNum -isnot [int]) {
        $AudioFrStreamNum = $null
    }
    if ($AudioEnStreamNum -isnot [int]) {
        $AudioEnStreamNum = $null
    }
    
    if ($VideoStreamNum -eq $null) {
        throw "No video stream"
    }
    
    if (($AudioFrStreamNum -eq $null) -and ($AudioEnStreamNum -eq $null)) {
        throw "No audio stream"
    }
    
    if ($Output -eq $null) {
        $global:FFmpegLogFile = "encoding.log"
    } else {
        $global:FFmpegLogFile =  $Output + ".log"
    }
    
    # Compute a prefix that will be used for all intermediary files
    #$fileprefix = "z" + (Get-Item $InputFilePath).Basename + "."
    $fileprefix = "temp/" + (Get-Item $InputFilePath).Basename + "."
    
    echo "Converting video stream"
    $videooutput = $fileprefix + "video.mkv"
    ConvertVideoStream $InputFilePath $VideoStreamNum -Deinterlace $Deinterlace -Denoise $Denoise -BurnSubtitle $SubBurn -Crop $Crop -Scale $Scale -CRF $CRF -Preset $Preset -Tune $Tune -OutName $videooutput
    
    $audiofroutput = $null
    $audioenoutput = $null
    
    if ($AudioFrStreamNum -ne $null) {
        echo "Converting french audio"
        $audiofroutput = $fileprefix + "fre.mka"
        ConvertAudioStream  $InputFilePath $AudioFrStreamNum -AC $AC -OutName $audiofroutput
    }
    
    if ($AudioEnStreamNum -ne $null) {
        echo "Converting english audio"
        $audioenoutput = $fileprefix + "eng.mka"
        ConvertAudioStream  $InputFilePath $AudioEnStreamNum -AC $AC -OutName $audioenoutput
    }
    
    echo "Preparing merge..."
    
    if ($Output -eq $null) {
        if ($Title -eq $null) {
            throw "no output file specified"
        } else {
            $Output = $Title + ".mkv"
        }
    }
    
    $mkvinputs = @()
    
    $mkvvideo = [MkvMergeInput]@{
        FilePath = $videooutput 
        VideoTracks = [MkvMergeTrack]@{
            TrackID = 0
            TrackName = "Video"
            DefaultTrack = $true
            Language = $OriginalLanguage
        }
        AudioTracks = "none"
        SubtitleTracks = "none"
        Chapters = $KeepVideoChapters
    }
    
    $mkvinputs += $mkvvideo
    
    $OriginalLanguageIsFR = ($OriginalLanguage -eq 'fre') -or ($OriginalLanguage -eq 'fr')
    $OriginalLanguageIsEN = ($OriginalLanguage -eq 'eng') -or ($OriginalLanguage -eq 'en')
    
    
    $audiotrackbasename = "Mono"
    if ($AC -eq 2) {
        $audiotrackbasename = "Stereo"
    }
    
    if ($audiofroutput -ne $null) {
        $mkvaudiofr = [MkvMergeInput]@{
            FilePath = $audiofroutput
            AudioTracks = [MkvMergeTrack]@{
                TrackID = 0
                TrackName = $audiotrackbasename + " - FR"
                DefaultTrack = $true
                Language = "fre"
                OriginalLanguage = $OriginalLanguageIsFR
            }
        }
        
        $mkvinputs += $mkvaudiofr
    }
    
    if ($audioenoutput -ne $null) {
        $isdefaulttrack = ($audiofroutput -eq $null)
        $mkvaudioen = [MkvMergeInput]@{
            FilePath = $audioenoutput
            AudioTracks = [MkvMergeTrack]@{
                TrackID = 0
                TrackName = $audiotrackbasename + " - EN"
                Language = "eng"
                OriginalLanguage = $OriginalLanguageIsEN
                DefaultTrack = $isdefaulttrack
            }
        }
        
        $mkvinputs += $mkvaudioen
    }
    
    $subtracks = @($SubFre, $SubFreForced, $SubEng, $SubEngSDH, $SubEngForced)
    $subtracks = $subtracks | Where-Object { $_ -ne $null }
    if ($subtracks.count -gt 0) {
        $subtracks = @()
        
        if (($SubFre -is [int]) -and ($SubFre -ge 0)) {
            $subtrack = [MkvMergeTrack]@{
                TrackID = $SubFre
                TrackName = "FR"
                Language = "fre"
                DefaultTrack = $false
                OriginalLanguage = $OriginalLanguageIsFR
            }
            $subtracks += $subtrack
        }
        
        if (($SubFreForced -is [int]) -and ($SubFreForced -ge 0)) {
            $subtrack = [MkvMergeTrack]@{
                TrackID = $SubFreForced
                TrackName = "FR [Forced]"
                Language = "fre"
                OriginalLanguage = $OriginalLanguageIsFR
                DefaultTrack = $true
                ForcedDisplay = $true
            }
            $subtracks += $subtrack
        }
        
        if (($SubEng -is [int]) -and ($SubEng -ge 0)) {
            $subtrack = [MkvMergeTrack]@{
                TrackID = $SubEng
                TrackName = "EN"
                Language = "eng"
                OriginalLanguage = $OriginalLanguageIsEN
                DefaultTrack = $false
            }
            $subtracks += $subtrack
        }
        
        if (($SubEngSDH -is [int]) -and ($SubEngSDH -ge 0)) {
            $subtrack = [MkvMergeTrack]@{
                TrackID = $SubEngSDH
                TrackName = "EN [SDH]"
                Language = "eng"
                OriginalLanguage = $OriginalLanguageIsEN
                DefaultTrack = $false
                HearingImpaired = $true
            }
            $subtracks += $subtrack
        }
        
        if (($SubEngForced -is [int]) -and ($SubEngForced -ge 0)) {
            $subtrack = [MkvMergeTrack]@{
                TrackID = $SubEngForced
                TrackName = "EN [Forced]"
                Language = "eng"
                OriginalLanguage = $OriginalLanguageIsEN
                DefaultTrack = $false
                ForcedDisplay = $true
            }
            $subtracks += $subtrack
        }
        
        $mkvsubtitles = [MkvMergeInput]@{
            FilePath = $InputFilePath
            AudioTracks = 'none'
            VideoTracks = 'none'
            SubtitleTracks = $subtracks
            Chapters = $false
            GlobalTags = $false
        }
        
        $mkvinputs += $mkvsubtitles
    }
    
    $themerge = [MkvMerge]@{
        Title = $Title
        Output = $Output
        Inputs = $mkvinputs
    }
    
    echo "Merging..."
    Run-MkvMerge $themerge
}
