
A collection of Powershell scripts that I use for creating private copies of my
DVDs and Blu-Ray discs.

The scripts assume that you have `ffmpeg` and `mkvmerge` installed and added
to the `PATH` environment variable.

## FFmpeg cheatsheets

How to do basic stuff with `ffmpeg`.

**Listing the streams**

```bash
ffmpeg -i video.mkv
```

**Selecting streams**

```bash
ffmpeg -i video.mkv -map 0:0 -map 0:1 -map 0:3 output.mkv
```

More: https://trac.ffmpeg.org/wiki/Map

**Cropping**

Detecting the crop:
```bash
ffmpeg -i video.mkv -vf cropdetect -f null -
```

Applying the crop:
```bash
ffmpeg -i video.mkv -vf crop=w:h:x:y output.mkv
```

**Trimming**

Use the `-ss` option before specifying the input files for fast skipping to a particular time.
Use the `-t` option to specify the duration that you want to encode.

Example:
```bash
ffmpeg -ss 00:10:00 -i video.mkv -t 15 output.mkv
```

**Convert to stereo**

Use `-ac 2` for an audio stream to stereo.

**Encoding formats**

- video: h265 (see [H.265/HEVC Video Encoding Guide](https://trac.ffmpeg.org/wiki/Encode/H.265))
- audio: libopus (see [Guidelines for high quality lossy audio encoding](https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio))

Example:
```bash
ffmpeg -i video.mkv -c:v libx265 -crf 26  -c:a libopus -ac 2 output.mkv
```

**Fast preset**

Control the speed of the encoding by changing from the default preset. 
This can be useful when testing various encoding formats for filesize / quality.

```bash
ffmpeg -i video -preset fast output.mkv
```

**Deinterlacing**

Several options, including:
- yadif video filter: `-vf yadif`.
- nnedi video filter: `-vf nnedi=weights='nnedi3_weights.bin'`.

More: https://video.stackexchange.com/questions/17396/how-to-deinterlacing-with-ffmpeg

**Sound normalization**

Several options, including:
- `loudnorm`, a two-pass filter;
- peak normalization with the `volume` filter;
- `dynaudnorm`.

**Sound normalization (loudnorm)**

First pass:

```bash
ffmpeg -i audio.mka -filter:a loudnorm=print_format=json -f null NULL
```

Output:
```
[Parsed_loudnorm_0 @ 000002a2bcfa8ec0]
{
    "input_i" : "-16.92",
    "input_tp" : "0.55",
    "input_lra" : "24.20",
    "input_thresh" : "-29.83",
    "output_i" : "-25.37",
    "output_tp" : "-2.00",
    "output_lra" : "16.20",
    "output_thresh" : "-36.52",
    "normalization_type" : "dynamic",
    "target_offset" : "1.37"
}
```

Second pass:

```bash
ffmpeg -i audio.mka -filter:a loudnorm=linear=true:measured_i=-16.92:measured_tp=0.55:measured_lra=24.20:measured_thresh=-29.83 -ar 48000 -c:a libopus -ac 2 output.mka
```

More: https://wiki.tnonline.net/w/Blog/Audio_normalization_with_FFmpeg

**Sound normalization (volume)**

First pass: measure the current peak

```bash
ffmpeg -i audio.mka -filter:a astats=measure_overall=Peak_level:measure_perchannel=0 -f null -
```

should output something like this:
```
[Parsed_astats_0 @ 000001812c7f8fc0] Peak level dB: -1.165583
```

Second pass:

```bash
ffmpeg -i audio.mka -filter:a volume=1.16dB output.mka
```

**Extracting frames**

Specify an output pattern with the `.png` extension.

```bash
ffmpeg -i myvideo.avi -vf fps=1/60 img%04d.png
```

The `fps` filter controls the number of frame extracted per second.

More: https://stackoverflow.com/questions/10957412/fastest-way-to-extract-frames-using-ffmpeg

## PowerShell commands

List all files in subdirectories with the "mkv" extension.

```ps
Get-ChildItem -Recurse -Filter "*.mkv"
```

Redirect the stderr stream to stdout and "grep" the output:

```ps
ffmpeg -i .\t00.mkv 2>&1 | Select-String -Pattern "Stream #0:*"
```
