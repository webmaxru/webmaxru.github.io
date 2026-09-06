param(
  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\src\assets\brand")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

$background = [System.Drawing.ColorTranslator]::FromHtml("#efebe4")
$text = [System.Drawing.ColorTranslator]::FromHtml("#242424")
$muted = [System.Drawing.ColorTranslator]::FromHtml("#5c5c5c")
$accent = [System.Drawing.ColorTranslator]::FromHtml("#b11f4b")
$white = [System.Drawing.Color]::White

function Set-GraphicsQuality {
  param([System.Drawing.Graphics]$Graphics)

  $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $Graphics.InterpolationMode =
    [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $Graphics.PixelOffsetMode =
    [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $Graphics.TextRenderingHint =
    [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
}

function Draw-BrandMark {
  param(
    [System.Drawing.Graphics]$Graphics,
    [float]$X,
    [float]$Y,
    [float]$Size,
    [System.Drawing.Color]$Color
  )

  $strokeWidth = [Math]::Max(2, $Size * 0.105)
  $pen = [System.Drawing.Pen]::new($Color, $strokeWidth)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

  $points = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new($X + ($Size * 0.2), $Y + ($Size * 0.74)),
    [System.Drawing.PointF]::new($X + ($Size * 0.2), $Y + ($Size * 0.26)),
    [System.Drawing.PointF]::new($X + ($Size * 0.5), $Y + ($Size * 0.58)),
    [System.Drawing.PointF]::new($X + ($Size * 0.8), $Y + ($Size * 0.26)),
    [System.Drawing.PointF]::new($X + ($Size * 0.8), $Y + ($Size * 0.74))
  )

  $Graphics.DrawLines($pen, $points)

  $dotBrush = [System.Drawing.SolidBrush]::new($Color)
  $dotSize = $Size * 0.11
  $Graphics.FillEllipse(
    $dotBrush,
    $X + ($Size * 0.74),
    $Y + ($Size * 0.8),
    $dotSize,
    $dotSize
  )

  $dotBrush.Dispose()
  $pen.Dispose()
}

function New-IconBitmap {
  param(
    [int]$Size,
    [double]$MarkScale = 0.9
  )

  $bitmap = [System.Drawing.Bitmap]::new(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

  try {
    Set-GraphicsQuality $graphics
    $graphics.Clear($accent)

    $markSize = [float]($Size * $MarkScale)
    $offset = [float](($Size - $markSize) / 2)
    Draw-BrandMark $graphics $offset $offset $markSize $white
  }
  finally {
    $graphics.Dispose()
  }

  return $bitmap
}

function Save-IconPng {
  param(
    [string]$Path,
    [int]$Size,
    [double]$MarkScale = 0.9
  )

  $bitmap = New-IconBitmap $Size $MarkScale
  try {
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $bitmap.Dispose()
  }
}

function Get-IconPngBytes {
  param([int]$Size)

  $bitmap = New-IconBitmap $Size
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
  param([string]$Path)

  $entries = foreach ($size in 16, 32, 48) {
    [PSCustomObject]@{
      Size = $size
      Bytes = [byte[]](Get-IconPngBytes $size)
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

function Save-SocialCard {
  param([string]$Path)

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
      112,
      [System.Drawing.FontStyle]::Bold,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $ledeFont = [System.Drawing.Font]::new(
      "Segoe UI",
      34,
      [System.Drawing.FontStyle]::Regular,
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $urlFont = [System.Drawing.Font]::new(
      "Consolas",
      22,
      [System.Drawing.FontStyle]::Regular,
      [System.Drawing.GraphicsUnit]::Pixel
    )

    try {
      $graphics.FillRectangle($accentBrush, 0, 0, 18, 630)
      $graphics.DrawString("MAXIM SALNIKOV", $smallFont, $accentBrush, 72, 64)

      $title = "Maxim builds"
      $graphics.DrawString($title, $titleFont, $textBrush, 66, 174)
      $titleSize = $graphics.MeasureString($title, $titleFont)
      $graphics.DrawString(
        ".",
        $titleFont,
        $accentBrush,
        66 + $titleSize.Width - 18,
        174
      )

      $graphics.DrawString(
        "Projects, tools, and experiments",
        $ledeFont,
        $mutedBrush,
        72,
        340
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

      Draw-BrandMark $graphics 915 70 220 $accent
    }
    finally {
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

$faviconSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="12" fill="#b11f4b"/>
  <path d="M14 46V18l18 19 18-19v28" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="49" cy="52" r="4" fill="#fff"/>
</svg>
"@

Set-Content (
  Join-Path $OutputDirectory "favicon.svg"
) $faviconSvg -Encoding utf8 -NoNewline
Save-FaviconIco (Join-Path $OutputDirectory "favicon.ico")
Save-IconPng (Join-Path $OutputDirectory "apple-touch-icon.png") 180
Save-IconPng (Join-Path $OutputDirectory "icon-192.png") 192
Save-IconPng (Join-Path $OutputDirectory "icon-512.png") 512
Save-IconPng (Join-Path $OutputDirectory "icon-maskable-512.png") 512 0.66
Save-SocialCard (Join-Path $OutputDirectory "social-card.png")

Write-Host "Generated brand assets in $OutputDirectory"
