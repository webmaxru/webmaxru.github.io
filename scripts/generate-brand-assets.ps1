param(
  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\src\assets\brand"),
  [string]$SourcePhoto = (Join-Path $PSScriptRoot "assets\maxim-salnikov.2024.jpg")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$SourcePhoto = [System.IO.Path]::GetFullPath($SourcePhoto)

if (-not (Test-Path -LiteralPath $SourcePhoto -PathType Leaf)) {
  throw "Portrait source not found: $SourcePhoto"
}

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

$background = [System.Drawing.ColorTranslator]::FromHtml("#efebe4")
$text = [System.Drawing.ColorTranslator]::FromHtml("#242424")
$muted = [System.Drawing.ColorTranslator]::FromHtml("#5c5c5c")
$accent = [System.Drawing.ColorTranslator]::FromHtml("#b11f4b")
$transparent = [System.Drawing.Color]::Transparent

function Set-GraphicsQuality {
  param([System.Drawing.Graphics]$Graphics)

  $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $Graphics.InterpolationMode =
    [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $Graphics.PixelOffsetMode =
    [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $Graphics.CompositingQuality =
    [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $Graphics.TextRenderingHint =
    [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
}

function Get-PortraitCrop {
  param([System.Drawing.Image]$Source)

  $cropSize = [Math]::Min(
    [float]($Source.Width * 0.753),
    [float]($Source.Height * 0.753)
  )
  $cropX = [float]($Source.Width * 0.168)
  $cropY = [float]($Source.Height * 0.029)

  if ($cropX + $cropSize -gt $Source.Width) {
    $cropX = $Source.Width - $cropSize
  }
  if ($cropY + $cropSize -gt $Source.Height) {
    $cropY = $Source.Height - $cropSize
  }

  return [System.Drawing.RectangleF]::new(
    $cropX,
    $cropY,
    $cropSize,
    $cropSize
  )
}

function New-PortraitBitmap {
  param(
    [System.Drawing.Image]$Source,
    [int]$Size,
    [System.Drawing.Color]$CanvasColor,
    [double]$PaddingRatio,
    [System.Drawing.Color]$RingColor,
    [double]$RingRatio
  )

  $bitmap = [System.Drawing.Bitmap]::new(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

  try {
    Set-GraphicsQuality $graphics
    $graphics.Clear($CanvasColor)

    $padding = [float]($Size * $PaddingRatio)
    $outerSize = [float]($Size - (2 * $padding))
    $ringWidth = [float][Math]::Max(1, $Size * $RingRatio)
    $outerRectangle = [System.Drawing.RectangleF]::new(
      $padding,
      $padding,
      $outerSize,
      $outerSize
    )
    $ringBrush = [System.Drawing.SolidBrush]::new($RingColor)

    try {
      $graphics.FillEllipse($ringBrush, $outerRectangle)
    }
    finally {
      $ringBrush.Dispose()
    }

    $innerRectangle = [System.Drawing.RectangleF]::new(
      $outerRectangle.X + $ringWidth,
      $outerRectangle.Y + $ringWidth,
      $outerRectangle.Width - (2 * $ringWidth),
      $outerRectangle.Height - (2 * $ringWidth)
    )
    $clipPath = [System.Drawing.Drawing2D.GraphicsPath]::new()

    try {
      $clipPath.AddEllipse($innerRectangle)
      $graphics.SetClip($clipPath)
      $graphics.DrawImage(
        $Source,
        $innerRectangle,
        (Get-PortraitCrop $Source),
        [System.Drawing.GraphicsUnit]::Pixel
      )
      $graphics.ResetClip()
    }
    finally {
      $clipPath.Dispose()
    }
  }
  finally {
    $graphics.Dispose()
  }

  return $bitmap
}

function Save-PortraitPng {
  param(
    [System.Drawing.Image]$Source,
    [string]$Path,
    [int]$Size,
    [System.Drawing.Color]$CanvasColor,
    [double]$PaddingRatio,
    [System.Drawing.Color]$RingColor,
    [double]$RingRatio
  )

  $bitmap = New-PortraitBitmap `
    $Source `
    $Size `
    $CanvasColor `
    $PaddingRatio `
    $RingColor `
    $RingRatio

  try {
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $bitmap.Dispose()
  }
}

function Get-PortraitPngBytes {
  param(
    [System.Drawing.Image]$Source,
    [int]$Size
  )

  $bitmap = New-PortraitBitmap `
    $Source `
    $Size `
    $transparent `
    0 `
    $accent `
    0.024
  $stream = [System.IO.MemoryStream]::new()

  try {
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    return ,$stream.ToArray()
  }
  finally {
    $stream.Dispose()
    $bitmap.Dispose()
  }
}

function Save-FaviconIco {
  param(
    [System.Drawing.Image]$Source,
    [string]$Path
  )

  $entries = foreach ($size in 16, 32, 48) {
    [PSCustomObject]@{
      Size = $size
      Bytes = [byte[]](Get-PortraitPngBytes $Source $size)
    }
  }

  $stream = [System.IO.MemoryStream]::new()
  $writer = [System.IO.BinaryWriter]::new($stream)

  try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$entries.Count)

    $offset = 6 + (16 * $entries.Count)
    foreach ($entry in $entries) {
      $writer.Write([byte]$entry.Size)
      $writer.Write([byte]$entry.Size)
      $writer.Write([byte]0)
      $writer.Write([byte]0)
      $writer.Write([uint16]1)
      $writer.Write([uint16]32)
      $writer.Write([uint32]$entry.Bytes.Length)
      $writer.Write([uint32]$offset)
      $offset += $entry.Bytes.Length
    }

    foreach ($entry in $entries) {
      $writer.Write([byte[]]$entry.Bytes)
    }

    $writer.Flush()
    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
  }
  finally {
    $writer.Dispose()
    $stream.Dispose()
  }
}

function Save-FaviconSvg {
  param(
    [System.Drawing.Image]$Source,
    [string]$Path
  )

  $previewBytes = Get-PortraitPngBytes $Source 96
  $base64 = [System.Convert]::ToBase64String($previewBytes)
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <image width="96" height="96" href="data:image/png;base64,$base64"/>
</svg>
"@

  Set-Content $Path $svg -Encoding utf8 -NoNewline
}

function Save-SocialCard {
  param(
    [System.Drawing.Image]$Source,
    [string]$Path
  )

  $bitmap = [System.Drawing.Bitmap]::new(
    1200,
    630,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

  try {
    Set-GraphicsQuality $graphics
    $graphics.Clear($background)

    $accentBrush = [System.Drawing.SolidBrush]::new($accent)
    $textBrush = [System.Drawing.SolidBrush]::new($text)
    $mutedBrush = [System.Drawing.SolidBrush]::new($muted)
    $smallFont = [System.Drawing.Font]::new(
      "Consolas",
      24,
      [System.Drawing.FontStyle]::Bold,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $titleFont = [System.Drawing.Font]::new(
      "Segoe UI",
      92,
      [System.Drawing.FontStyle]::Bold,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $ledeFont = [System.Drawing.Font]::new(
      "Segoe UI",
      32,
      [System.Drawing.FontStyle]::Regular,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $urlFont = [System.Drawing.Font]::new(
      "Consolas",
      22,
      [System.Drawing.FontStyle]::Regular,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $portrait = New-PortraitBitmap `
      $Source `
      330 `
      $transparent `
      0 `
      $accent `
      0.024

    try {
      $graphics.FillRectangle($accentBrush, 0, 0, 18, 630)
      $graphics.DrawString("MAXIM SALNIKOV", $smallFont, $accentBrush, 72, 64)

      $title = "Maxim builds"
      $graphics.DrawString($title, $titleFont, $textBrush, 66, 184)
      $titleSize = $graphics.MeasureString($title, $titleFont)
      $graphics.DrawString(
        ".",
        $titleFont,
        $accentBrush,
        66 + $titleSize.Width - 14,
        184
      )

      $graphics.DrawString(
        "Projects, tools, and experiments",
        $ledeFont,
        $mutedBrush,
        72,
        330
      )

      $rulePen = [System.Drawing.Pen]::new(
        [System.Drawing.Color]::FromArgb(70, $muted),
        2
      )
      try {
        $graphics.DrawLine($rulePen, 72, 480, 1128, 480)
      }
      finally {
        $rulePen.Dispose()
      }

      $graphics.DrawString(
        "WEBMAXRU.GITHUB.IO",
        $urlFont,
        $mutedBrush,
        72,
        520
      )
      $graphics.DrawImage($portrait, 810, 78, 330, 330)
    }
    finally {
      $portrait.Dispose()
      $urlFont.Dispose()
      $ledeFont.Dispose()
      $titleFont.Dispose()
      $smallFont.Dispose()
      $mutedBrush.Dispose()
      $textBrush.Dispose()
      $accentBrush.Dispose()
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

$source = [System.Drawing.Image]::FromFile($SourcePhoto)

try {
  Save-PortraitPng `
    $source `
    (Join-Path $OutputDirectory "portrait-512.png") `
    512 `
    $transparent `
    0 `
    $accent `
    0.024
  Save-FaviconSvg $source (Join-Path $OutputDirectory "favicon.svg")
  Save-FaviconIco $source (Join-Path $OutputDirectory "favicon.ico")
  Save-PortraitPng `
    $source `
    (Join-Path $OutputDirectory "apple-touch-icon.png") `
    180 `
    $background `
    0.08 `
    $accent `
    0.024
  Save-PortraitPng `
    $source `
    (Join-Path $OutputDirectory "icon-192.png") `
    192 `
    $background `
    0.08 `
    $accent `
    0.024
  Save-PortraitPng `
    $source `
    (Join-Path $OutputDirectory "icon-512.png") `
    512 `
    $background `
    0.08 `
    $accent `
    0.024
  Save-PortraitPng `
    $source `
    (Join-Path $OutputDirectory "icon-maskable-512.png") `
    512 `
    $accent `
    0.18 `
    $background `
    0.018
  Save-SocialCard $source (Join-Path $OutputDirectory "social-card.png")
}
finally {
  $source.Dispose()
}

Write-Host "Generated portrait brand assets in $OutputDirectory"
