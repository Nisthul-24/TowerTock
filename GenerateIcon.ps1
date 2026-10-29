# GenerateIcon.ps1 — Creates a simple TowerTock app icon as a PNG-like BMP
# Output: assets/interface/icon.png (saved as BMP, rename works for Godot import)

$OutputDir = Join-Path $PSScriptRoot "assets\interface"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Create a 128x128 icon as BMP
$width  = 128
$height = 128
$path   = Join-Path $OutputDir "icon.bmp"

function Write-BmpFile {
    param([string]$FilePath, [int]$W, [int]$H, [byte[]]$Pixels)
    # pixels: BGRA row-by-row, bottom-up
    $ms = [System.IO.MemoryStream]::new()
    $bw = [System.IO.BinaryWriter]::new($ms)

    $rowSize    = [int](($W * 3 + 3) / 4) * 4
    $pixelData  = $rowSize * $H
    $fileSize   = 54 + $pixelData

    # BMP file header
    $bw.Write([byte]0x42); $bw.Write([byte]0x4D)  # 'BM'
    $bw.Write([int32]$fileSize)
    $bw.Write([int32]0)
    $bw.Write([int32]54)

    # DIB header
    $bw.Write([int32]40)
    $bw.Write([int32]$W)
    $bw.Write([int32]$H)
    $bw.Write([int16]1)   # planes
    $bw.Write([int16]24)  # bpp
    $bw.Write([int32]0)   # compression
    $bw.Write([int32]$pixelData)
    $bw.Write([int32]2835)
    $bw.Write([int32]2835)
    $bw.Write([int32]0)
    $bw.Write([int32]0)

    # Pixels — BMP is bottom-up
    for ($y = $H - 1; $y -ge 0; $y--) {
        $rowBytes = 0
        for ($x = 0; $x -lt $W; $x++) {
            $idx = ($y * $W + $x) * 3
            $bw.Write($Pixels[$idx + 2])  # B
            $bw.Write($Pixels[$idx + 1])  # G
            $bw.Write($Pixels[$idx + 0])  # R
            $rowBytes += 3
        }
        while ($rowBytes % 4 -ne 0) { $bw.Write([byte]0); $rowBytes++ }
    }

    $bw.Flush()
    [System.IO.File]::WriteAllBytes($FilePath, $ms.ToArray())
}

$pixels = New-Object byte[] ($width * $height * 3)

for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $idx = ($y * $width + $x) * 3

        # Background: dark navy gradient
        $t   = $y / $height
        $r   = [byte]([int](20  + $t * 40))
        $g   = [byte]([int](30  + $t * 50))
        $b   = [byte]([int](70  + $t * 80))

        # Centre circle highlight
        $cx  = $x - $width  / 2
        $cy  = $y - $height / 2
        $dist = [Math]::Sqrt($cx * $cx + $cy * $cy)

        if ($dist -lt 50) {
            # Gold tower block
            $r = [byte]255; $g = [byte]200; $b = [byte]50
        }
        if ($dist -ge 48 -and $dist -lt 50) {
            # Border
            $r = [byte]180; $g = [byte]140; $b = [byte]30
        }

        # Simple 'T' letter in centre
        $lx = $x - 52; $ly = $y - 40
        if ($ly -ge 0 -and $ly -le 10 -and $lx -ge 0 -and $lx -le 24) {
            $r = [byte]15; $g = [byte]15; $b = [byte]30
        }
        if ($lx -ge 9 -and $lx -le 15 -and $ly -ge 0 -and $ly -le 36) {
            $r = [byte]15; $g = [byte]15; $b = [byte]30
        }

        $pixels[$idx]     = $r
        $pixels[$idx + 1] = $g
        $pixels[$idx + 2] = $b
    }
}

Write-BmpFile $path $width $height $pixels
Write-Host "Icon created: $path"
Write-Host "Rename to icon.png or import as BMP in Godot."

# Also copy as PNG name (Godot can import BMP as texture)
$pngPath = Join-Path $OutputDir "icon.png"
Copy-Item $path $pngPath -Force
Write-Host "Copied to: $pngPath"
