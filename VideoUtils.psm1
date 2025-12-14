
function Get-VideoRuntime {
    param (
        [Parameter(Mandatory=$true)][string]$filepath
    )

    $line = (ffmpeg -i $filepath 2>&1) | Select-String -Pattern "Duration: " | Select-Object -First 1
    $ok = $line -match 'Duration: (\d+):(\d+):(\d+).(\d+)'
    if ($ok -eq $False) {
        throw "could not parse video duration" 
    }
    $hours =  $Matches[1] -as 'int'
    $minutes =  $Matches[2] -as 'int'
    $seconds =  $Matches[3] -as 'int'
    return $hours * 3600 + $minutes * 60 + $seconds
}

function Detect-Crop {
    param(
        [Parameter(Mandatory=$true)][string]$filepath,
        [int]$N = 15
    )

    $duration = Get-VideoRuntime $filepath

    $samples = @()
    for ($i = 1; $i -le $N; $i++) {
        $t = $i * $duration / ($N+1)
        $value = ((ffmpeg -ss $t -i $filepath -t 10 -vf cropdetect -f null - 2>&1) | Select-String "Parsed_cropdetect_" | Select -Last 1)
        if ($value -match "crop=(\d+):(\d+):(\d+):(\d+)") {
            $samples += $Matches[0]
        }
    }

    $samples | Group
}

function Detect-Subtitles {
    param (
        [Parameter(Mandatory=$true)][string]$filepath
    )

    Write-Output $filepath

    $lines = (ffmpeg -i $filepath 2>&1)

    $i = 0
    while (($i -lt $lines.length) -and ($lines[$i] -notmatch 'Stream #0:0')) {
        $i = $i+1
    }

    while (($i -lt $lines.length)) {
        $line = $lines[$i]
        $lang = $null
        if ($line -match '#0:(\d+)\((\w+)\):') {
            $lang = $Matches[2] -as 'string'
        }

        if ($line -notmatch '#0:(\d+).* Subtitle:') {
            $i = $i+1
            continue
        }
        $tracknum = $Matches[1] -as 'int'
        $i = $i+1

        $nbframes = -1

        while (($i -lt $lines.length)) {
            $line = $lines[$i]
            if ($line -match 'Stream #0:(\d+)') {
                break
            }

            if ($line -match 'NUMBER_OF_FRAMES.*: (\d+)') {
                $nbframes = $Matches[1] -as 'int'
            }

            $i = $i+1
        }

        Write-Output "$tracknum lang=$lang frames=$nbframes"
    }
}

function Print-StreamList {
    param (
        $FileName,
        $Outfile = $null
    )
        
    $lines = (ffmpeg -i $FileName 2>&1) | Select-String -Pattern "Stream #0:" | ForEach-Object { $_.ToString().Trim() }

    if ($Outfile -eq $null) {
        Write-Output $lines
    } else {
        $lines | Out-File -Encoding utf8 $Outfile
    }
    
}


Export-ModuleMember -Function Detect-Crop
Export-ModuleMember -Function Detect-Subtitles
Export-ModuleMember -Function Print-StreamList
