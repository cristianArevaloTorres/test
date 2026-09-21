<#
  Copia simple de recursos físicos MVP para todo el lote.

  Ejecutar desde una computadora con acceso a:
  \\lockmx-block3qa\public\Stilos

  Crea las carpetas y copia solo los archivos que faltan. Si se indica
  -Sobrescribir, reemplaza archivos con el mismo nombre. No elimina archivos.
#>

param(
    [string]$RaizEstilos = '\\lockmx-block3qa\public\Stilos',
    [switch]$Sobrescribir
)

$ErrorActionPreference = 'Stop'

$empresas = @(
    496, 532, 659, 699, 719, 720, 722, 724, 726, 728, 744, 753,
    757, 759, 761, 763, 791, 798, 800, 807, 813, 815, 2679
)

$corporativos = @(
    495, 531, 658, 698, 718, 721, 723, 725, 727, 752,
    756, 758, 760, 762, 790, 797, 799, 806, 812, 814
)

$general = Join-Path $RaizEstilos 'General'
$menus = Join-Path $RaizEstilos 'Menus'
$login = Join-Path $RaizEstilos 'Login'
$banner = Join-Path $RaizEstilos 'banner'

$generalGenerico = Join-Path $general 'GenericMVP'
$menusGenerico = Join-Path $menus 'GenericMVP'

$cssRaizGenerico = Join-Path $general 'ClaGenericMVP.css'
$cssCarpetaGenerico = Join-Path $generalGenerico 'ClaGenericMVP.css'
$logoGenerico = Join-Path $generalGenerico 'GenericMVP_Logo.png'
$logoLockton = Join-Path $generalGenerico 'Lockton_Logo.png'
$loginGenerico = Join-Path $login 'ClaLogin.css'

$fuentesNecesarias = @($cssRaizGenerico, $cssCarpetaGenerico, $loginGenerico, $menusGenerico)
$faltantes = @($fuentesNecesarias | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($faltantes.Count -gt 0) {
    throw "Faltan las plantillas GenericMVP: $($faltantes -join ', ')"
}

$cssBase = ([System.IO.File]::ReadAllText($cssRaizGenerico) +
            [Environment]::NewLine +
            [System.IO.File]::ReadAllText($cssCarpetaGenerico)).Trim()

$utf8SinBom = New-Object System.Text.UTF8Encoding($false)

foreach ($idEmpresa in $empresas) {
    $carpetaGeneralEmpresa = Join-Path $general ([string]$idEmpresa)
    $carpetaMenusEmpresa = Join-Path $menus ([string]$idEmpresa)
    $carpetaBannerEmpresa = Join-Path $banner ([string]$idEmpresa)

    New-Item -ItemType Directory -Path $carpetaGeneralEmpresa -Force | Out-Null
    New-Item -ItemType Directory -Path $carpetaMenusEmpresa -Force | Out-Null
    New-Item -ItemType Directory -Path $carpetaBannerEmpresa -Force | Out-Null

    $cssEmpresa = [regex]::Replace(
        $cssBase,
        '\b(382|GenericMVP)_Logo\.png\b',
        ("{0}_Logo.png" -f $idEmpresa)
    )

    $cssDestinos = @(
        (Join-Path $carpetaGeneralEmpresa ("Cla{0}.css" -f $idEmpresa)),
        (Join-Path $general ("Cla{0}.css" -f $idEmpresa))
    )
    foreach ($cssDestino in $cssDestinos) {
        if ($Sobrescribir -or -not (Test-Path -LiteralPath $cssDestino -PathType Leaf)) {
            [System.IO.File]::WriteAllText($cssDestino, $cssEmpresa, $utf8SinBom)
        }
    }

    $logoDestino = Join-Path $carpetaGeneralEmpresa ("{0}_Logo.png" -f $idEmpresa)
    if ((Test-Path -LiteralPath $logoGenerico -PathType Leaf) -and
        ($Sobrescribir -or -not (Test-Path -LiteralPath $logoDestino -PathType Leaf))) {
        Copy-Item -LiteralPath $logoGenerico -Destination $logoDestino -Force
    }

    if (Test-Path -LiteralPath $logoLockton -PathType Leaf) {
        $logoLocktonDestino = Join-Path $carpetaGeneralEmpresa 'Lockton_Logo.png'
        if ($Sobrescribir -or -not (Test-Path -LiteralPath $logoLocktonDestino -PathType Leaf)) {
            Copy-Item -LiteralPath $logoLockton -Destination $logoLocktonDestino -Force
        }
    }

    foreach ($icono in (Get-ChildItem -LiteralPath $menusGenerico -File -Recurse)) {
        $rutaRelativa = $icono.FullName.Substring($menusGenerico.Length).TrimStart('\', '/')
        $iconoDestino = Join-Path $carpetaMenusEmpresa $rutaRelativa
        if ($Sobrescribir -or -not (Test-Path -LiteralPath $iconoDestino -PathType Leaf)) {
            $directorioIcono = Split-Path -Path $iconoDestino -Parent
            New-Item -ItemType Directory -Path $directorioIcono -Force | Out-Null
            Copy-Item -LiteralPath $icono.FullName -Destination $iconoDestino -Force
        }
    }

    Write-Host "Empresa ${idEmpresa}: General, Menus y banner preparados."
}

foreach ($idCorporativo in $corporativos) {
    $loginDestino = Join-Path $login ("ClaLogin{0}.css" -f $idCorporativo)
    if ($Sobrescribir -or -not (Test-Path -LiteralPath $loginDestino -PathType Leaf)) {
        Copy-Item -LiteralPath $loginGenerico -Destination $loginDestino -Force
    }

    Write-Host "Corporativo ${idCorporativo}: CSS de login preparado."
}

Write-Host ''
Write-Host 'Proceso terminado.'
Write-Host ("Empresas procesadas: {0}" -f $empresas.Count)
Write-Host ("Corporativos procesados: {0}" -f $corporativos.Count)
