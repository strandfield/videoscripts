
# documentation for mkvmerge: https://mkvtoolnix.download/doc/mkvmerge.html

class MkvMergeAttachment
{
    [ValidateNotNullOrEmpty()][string]$FilePath
    [string]$Name = $null
    [string]$Description = $null
}

class MkvMergeTrack
{
    [ValidateNotNullOrEmpty()][int]$TrackID
    $TrackName = $null
    $Language = $null
    $DefaultTrack = $null
    $ForcedDisplay = $null
    $HearingImpaired = $null
    $OriginalLanguage = $null
}

class MkvMergeInput
{
    [ValidateNotNullOrEmpty()][string]$FilePath
    $VideoTracks = $null
    $AudioTracks = $null
    $SubtitleTracks = $null
    $TagsTracks = $null
    $Chapters = $null
    $GlobalTags = $null
}

class MkvMerge
{
    [string]$Title
    [string]$Output
    [ValidateNotNullOrEmpty()]$Inputs
    $Attachments = @()
}

function Get-Quoted {
    param (
      [ValidateNotNullOrEmpty()][string]$arg
    )
    
    if($arg -match ' ') {
        return '"' + $arg + '"'
    } else {
        return $arg 
    }
}

function Join-CliArgs {
    param (
        $cliargs
    )
    
    $result =  ($cliargs | % { Get-Quoted $_}) -Join " "  
    return $result
}

function GetCliArgs-MkvMergeAttachment {
    param(
        [ValidateNotNullOrEmpty()][MkvMergeAttachment]$Attachment
    )
    
    $result = @()
        
    if ($Attachment.Name -is [string]) {
        $result += "--attachment-name"
        $result += $Attachment.Name
    }
    
    if ($Attachment.Description -is [string]) {
        $result += "--attachment-description"
        $result += $Attachment.Description
    }
    
    $result += "--attach-file"
    $result += $Attachment.FilePath
    
    return $result
}

function Get-MkvMergeTrackCommandLineArgs {
    param(
        [ValidateNotNullOrEmpty()][MkvMergeTrack]$Track
    )
    
    $args = @()
    $tid = $Track.TrackID -as 'string'
    
    if ($Track.TrackName -ne $null) {
        $args += "--track-name"
        $args += ($tid + ":" + $Track.TrackName)
    }
    
    if ($Track.Language -ne $null) {
        $args += "--language"
        $args += ($tid + ":" + $Track.Language)
    }
    
    if ($Track.DefaultTrack -ne $null) {
        $args += "--default-track-flag"
        if ($Track.DefaultTrack -eq $false) {
            $args += ($tid + ":0")
        } else {
            $args += $tid
        }
    }
    
    if ($Track.ForcedDisplay -ne $null) {
        $args += "--forced-display-flag"
        if ($Track.ForcedDisplay -eq $false) {
            $args += ($tid + ":0")
        } else {
            $args += $tid
        }
    }
    
    if ($Track.HearingImpaired -ne $null) {
        $args += "--hearing-impaired-flag"
        if ($Track.HearingImpaired -eq $false) {
            $args += ($tid + ":0")
        } else {
            $args += $tid
        }
    }
    
    if ($Track.OriginalLanguage -ne $null) {
        $args += "--original-flag"
        if ($Track.OriginalLanguage -eq $false) {
            $args += ($tid + ":0")
        } else {
            $args += $tid
        }
    }
    
    return $args
}

function GetCliArgs-MkvMergeInput {
    param(
        [ValidateNotNullOrEmpty()][MkvMergeInput]$MergeInput
    )
    
    $result = @()
    
    if($MergeInput.VideoTracks -eq "none") {
        $result += "--no-video"
    } elseif ($MergeInput.VideoTracks -is [string]) {
        $result += $MergeInput.VideoTracks
    } elseif($MergeInput.VideoTracks -is [MkvMergeTrack]) {
        $track = $MergeInput.VideoTracks
        $r = Get-MkvMergeTrackCommandLineArgs $track
        $result += $r
        $result += "-d"
        $result += ($track.TrackID -as 'string')
    } elseif($MergeInput.VideoTracks -is [array]) {
        $ids = @()
        foreach ($track in $MergeInput.VideoTracks) {
            $ids += ($track.TrackID -as 'string')
            $r = Get-MkvMergeTrackCommandLineArgs $track
            $result += $r
        }
        $result += "--video-tracks"
        $result += ($ids -join ',')
    }
    
    if($MergeInput.AudioTracks -eq "none") {
        $result += "--no-audio"
    } elseif ($MergeInput.AudioTracks -is [string]) {
        $result += $MergeInput.AudioTracks
    } elseif($MergeInput.AudioTracks -is [MkvMergeTrack]) {
        $track = $MergeInput.AudioTracks
        $r = Get-MkvMergeTrackCommandLineArgs $track
        $result += $r
        $result += "-a"
        $result += ($track.TrackID -as 'string')
    } elseif($MergeInput.AudioTracks -is [array]) {
        $ids = @()
        foreach ($track in $MergeInput.AudioTracks) {
            $ids += ($track.TrackID -as 'string')
            $r = Get-MkvMergeTrackCommandLineArgs $track
            $result += $r
        }
        $result += "--audio-tracks"
        $result += ($ids -join ',')
    }
    
    if ($MergeInput.SubtitleTracks -eq "none") {
        $result += "--no-subtitles"
    } elseif ($MergeInput.SubtitleTracks -is [string]) {
        $result += $MergeInput.SubtitleTracks
    } elseif($MergeInput.SubtitleTracks -is [MkvMergeTrack]) {
        $track = $MergeInput.SubtitleTracks
        $r = Get-MkvMergeTrackCommandLineArgs $track
        $result += $r
        $result += "-s"
        $result += ($track.TrackID -as 'string')
    } elseif($MergeInput.SubtitleTracks -is [array]) {
        $ids = @()
        foreach ($track in $MergeInput.SubtitleTracks) {
            $ids += ($track.TrackID -as 'string')
            $r = Get-MkvMergeTrackCommandLineArgs $track
            $result += $r
        }
        $result += "--subtitle-tracks"
        $result += ($ids -join ',')
    }
    
    if ($MergeInput.TagsTracks -eq "none") {
        $result += "--no-track-tags"
    }
    
    if ($MergeInput.Chapters -ne $null) {
        if ($MergeInput.Chapters -eq $false) {
            $result += "--no-chapters"
        }
    }
    
    if ($MergeInput.GlobalTags -ne $null) {
        if ($MergeInput.GlobalTags -eq $false) {
            $result += "--no-global-tags"
        }
    }
    
    $result += $MergeInput.FilePath
    
    return $result
}


function GetCliArgs-MkvMerge {
    param(
        [ValidateNotNullOrEmpty()][MkvMerge]$MergeParams
    )
    
    $result = @("-o", $MergeParams.Output)
    
    if ($MergeParams.Title -is [string]) {
        $result += "--title"
        $result += $MergeParams.Title
    }
    
    if ($MergeParams.Attachments -is [array]) {
        foreach ($attachment in $MergeParams.Attachments) {
            $result += GetCliArgs-MkvMergeAttachment $attachment
        }    
    } elseif ($MergeParams.Attachments -is [MkvMergeAttachment]) {
        $attachment = $MergeParams.Attachments
        $result += GetCliArgs-MkvMergeAttachment $attachment
    }
    
    foreach ($inputfile in $MergeParams.Inputs) {
        $result += GetCliArgs-MkvMergeInput $inputfile
    }
        
    return $result
}

function GetCliArgsJoined-MkvMerge {
    param(
        [ValidateNotNullOrEmpty()][MkvMerge]$MergeParams
    )
    
    return Join-CliArgs (GetCliArgs-MkvMerge $MergeParams)
}

function Run-MkvMerge {
    param(
        [ValidateNotNullOrEmpty()][MkvMerge]$MergeParams
    )
    
    $fullcmd = "mkvmerge "
    $fullcmd += GetCliArgsJoined-MkvMerge $MergeParams
    $fullcmd | Write-Output
    cmd.exe /c $fullcmd
}