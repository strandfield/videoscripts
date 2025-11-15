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
