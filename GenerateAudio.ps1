# GenerateAudio.ps1 — Generates minimal WAV files for TowerTock SFX
# Uses PowerShell to write raw PCM WAV data without Python dependency.

param()

$SampleRate = 44100
$OutputDir  = Join-Path $PSScriptRoot "assets\audio"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Write-WavFile {
    param(
        [string]$Path,
        [int[]]$Samples,   # 16-bit signed samples
        [int]$SampleRate = 44100
    )
    $numSamples   = $Samples.Count
    $dataSize     = $numSamples * 2   # 16-bit = 2 bytes per sample
    $chunkSize    = 36 + $dataSize

    $ms = [System.IO.MemoryStream]::new()
    $bw = [System.IO.BinaryWriter]::new($ms)

    # RIFF header
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int32]$chunkSize)
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    # fmt chunk
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int32]16)           # chunk size
    $bw.Write([int16]1)            # PCM
    $bw.Write([int16]1)            # channels
    $bw.Write([int32]$SampleRate)  # sample rate
    $bw.Write([int32]($SampleRate * 2)) # byte rate
    $bw.Write([int16]2)            # block align
    $bw.Write([int16]16)           # bits per sample
    # data chunk
    $bw.Write([byte[]][System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int32]$dataSize)
    foreach ($s in $Samples) {
        $clamped = [Math]::Max(-32768, [Math]::Min(32767, $s))
        $bw.Write([int16]$clamped)
    }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    Write-Host "  Created: $Path"
}

function Make-Tone {
    param(
        [double]$Freq,
        [double]$Duration,
        [double]$Amplitude = 0.5,
        [int]$SampleRate = 44100
    )
    $n = [int]($SampleRate * $Duration)
    $samples = @()
    for ($i = 0; $i -lt $n; $i++) {
        $t   = $i / $SampleRate
        $env = 1.0
        $att = 0.01; $rel = 0.1
        if ($t -lt $att) { $env = $t / $att }
        elseif ($t -gt $Duration - $rel) { $env = ($Duration - $t) / $rel }
        $s = [Math]::Sin(2.0 * [Math]::PI * $Freq * $t) * $Amplitude * $env
        $samples += [int]($s * 32767)
    }
    return $samples
}

Write-Host "Generating TowerTock audio assets..."

# Button click — short high beep
$s = Make-Tone 880 0.08 0.5
Write-WavFile (Join-Path $OutputDir "sfx_button_click.wav") $s

# Release — descending whoosh
$s = @()
$n = [int]($SampleRate * 0.15)
for ($i = 0; $i -lt $n; $i++) {
    $t    = $i / $SampleRate
    $freq = 450.0 - 250.0 * ($t / 0.15)
    $env  = [Math]::Max(0.0, 1.0 - $t / 0.12)
    $val  = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * 0.4 * $env
    $s   += [int]($val * 32767)
}
Write-WavFile (Join-Path $OutputDir "sfx_release.wav") $s

# Land — thud
$s = @()
$n = [int]($SampleRate * 0.25)
for ($i = 0; $i -lt $n; $i++) {
    $t    = $i / $SampleRate
    $freq = [Math]::Max(40.0, 100.0 - 80.0 * ($t / 0.25))
    $env  = [Math]::Max(0.0, 1.0 - $t * 5.0)
    $val  = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * 0.6 * $env
    $s   += [int]($val * 32767)
}
Write-WavFile (Join-Path $OutputDir "sfx_land.wav") $s

# Perfect — bright chord C5 + E5 + G5
$s1 = Make-Tone 523.25 0.5 0.3
$s2 = Make-Tone 659.25 0.5 0.25
$s3 = Make-Tone 783.99 0.5 0.22
$mixed = @()
for ($i = 0; $i -lt $s1.Count; $i++) {
    $mixed += ($s1[$i] + $s2[$i] + $s3[$i])
}
Write-WavFile (Join-Path $OutputDir "sfx_perfect.wav") $mixed

# Combo — two rising notes
$s1 = Make-Tone 440.0  0.18 0.4
$s2 = Make-Tone 554.37 0.18 0.35
$combined = $s1 + $s2
Write-WavFile (Join-Path $OutputDir "sfx_combo.wav") $combined

# Miss — low descending
$s = @()
$n = [int]($SampleRate * 0.4)
for ($i = 0; $i -lt $n; $i++) {
    $t    = $i / $SampleRate
    $freq = [Math]::Max(60.0, 200.0 - 140.0 * ($t / 0.4))
    $env  = [Math]::Max(0.0, 1.0 - $t * 3.0)
    $val  = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * 0.55 * $env
    $s   += [int]($val * 32767)
}
Write-WavFile (Join-Path $OutputDir "sfx_miss.wav") $s

# Game over — descending minor arpeggio
$notes = @(392.0, 349.23, 311.13, 261.63)
$all = @()
foreach ($n in $notes) { $all += Make-Tone $n 0.35 0.4 }
Write-WavFile (Join-Path $OutputDir "sfx_game_over.wav") $all

# Revive — ascending triumphant
$notes = @(523.25, 659.25, 783.99, 1046.5)
$all = @()
foreach ($n in $notes) { $all += Make-Tone $n 0.2 0.4 }
Write-WavFile (Join-Path $OutputDir "sfx_revive.wav") $all

# Music placeholder — simple bass loop
$notes = @(
    @(261.63, 0.5), @(293.66, 0.25), @(329.63, 0.25),
    @(349.23, 0.5), @(392.00, 0.5),
    @(261.63, 0.25), @(329.63, 0.25), @(392.00, 0.5), @(440.00, 0.5)
)
$loop = @()
foreach ($nd in $notes) { $loop += Make-Tone $nd[0] $nd[1] 0.18 }
$all = $loop + $loop + $loop + $loop
Write-WavFile (Join-Path $OutputDir "music_main.wav") $all

Write-Host ""
Write-Host "Done! All audio files created in assets/audio/"
Write-Host "Import these into Godot. Update AudioManager SFX_PATHS extension from .ogg to .wav"
