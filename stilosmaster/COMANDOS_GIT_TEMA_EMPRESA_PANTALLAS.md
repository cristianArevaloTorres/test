# Comandos Git — tema empresarial en Carga Masiva y Defaulteo

El ZIP conserva las rutas a partir de `src/app`. Este bloque extrae y agrega únicamente los seis archivos del ajuste visual.

> Si el clon tiene otro nombre, cambie solamente `$RepoFront`.

```powershell
$RepoFront = 'C:\Proyectos_Lockton\QA\BeFlex3-EmpAdm'
$Zip = 'C:\REPOS\TEMA_EMPRESA_PANTALLAS.zip'

$FrontFiles = @(
    'src/app/services/empresa-theme.service.ts',
    'src/app/beflex/cargamasivaadm/cargamasivaadm.component.ts',
    'src/app/beflex/cargamasivaadm/cargamasivaadm.component.css',
    'src/app/beflex/administracion/titulares/defaulteo/defaulteo-titulares.component.ts',
    'src/app/beflex/administracion/titulares/defaulteo/defaulteo-titulares.component.css',
    'src/app/beflex/administracion/titulares/defaulteo/operacion-guiada/tabla-defaulteo-titulares.component.css'
)

if (-not (Test-Path -LiteralPath (Join-Path $RepoFront '.git'))) {
    throw "Esta carpeta no es un clon Git: $RepoFront"
}

if (-not (Test-Path -LiteralPath (Join-Path $RepoFront 'angular.json'))) {
    throw "La carpeta no parece ser el frontend Angular: $RepoFront"
}

if (-not (Test-Path -LiteralPath $Zip)) {
    throw "No se encontró el ZIP: $Zip"
}

Set-Location -LiteralPath $RepoFront

git remote -v
git branch --show-current
git status --short

# Evita reemplazar trabajo local que ya exista en alguno de los seis archivos.
$OverlappingChanges = @(git status --porcelain -- $FrontFiles)
if ($OverlappingChanges.Count -gt 0) {
    throw "Hay cambios locales en archivos de esta entrega. Resguárdelos antes de continuar:`n$($OverlappingChanges -join "`n")"
}

# Evita mezclar este commit con archivos que ya estuvieran preparados.
$PreviouslyStaged = @(git diff --cached --name-only)
if ($PreviouslyStaged.Count -gt 0) {
    throw "Hay archivos previamente preparados en Git:`n$($PreviouslyStaged -join "`n")"
}

# Verifica que el ZIP tenga exactamente las rutas esperadas.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)
try {
    $ZipFiles = @(
        $Archive.Entries |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
        ForEach-Object { $_.FullName.Replace('\', '/') }
    )
} finally {
    $Archive.Dispose()
}

$MissingInZip = @($FrontFiles | Where-Object { $_ -notin $ZipFiles })
$UnexpectedInZip = @($ZipFiles | Where-Object { $_ -notin $FrontFiles })
if ($MissingInZip.Count -gt 0 -or $UnexpectedInZip.Count -gt 0) {
    throw "El contenido del ZIP no coincide con la entrega.`nFaltantes: $($MissingInZip -join ', ')`nNo esperados: $($UnexpectedInZip -join ', ')"
}

# Copia sólo los seis archivos respetando las rutas src/app.
Expand-Archive -LiteralPath $Zip -DestinationPath $RepoFront -Force

$MissingAfterCopy = @($FrontFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RepoFront $_)) })
if ($MissingAfterCopy.Count -gt 0) {
    throw "Faltan archivos después de extraer el ZIP:`n$($MissingAfterCopy -join "`n")"
}

git status --short -- $FrontFiles

# Valida el proyecto antes de preparar el commit.
npm run build
if ($LASTEXITCODE -ne 0) {
    throw 'npm run build ha fallado. No se preparó ni se envió ningún cambio.'
}

git add -- $FrontFiles

git diff --cached --check
if ($LASTEXITCODE -ne 0) {
    throw 'Git detectó errores en los cambios preparados.'
}

$Staged = @(git diff --cached --name-only)
if ($Staged.Count -eq 0) {
    throw 'No hay cambios nuevos para confirmar.'
}

$UnexpectedStaged = @($Staged | Where-Object { $_ -notin $FrontFiles })
if ($UnexpectedStaged.Count -gt 0) {
    throw "Se detectaron archivos preparados que no pertenecen a esta entrega:`n$($UnexpectedStaged -join "`n")"
}

git diff --cached --name-status
git commit -m "Adapta carga masiva y defaulteo al tema empresarial"
if ($LASTEXITCODE -ne 0) {
    throw 'No fue posible crear el commit.'
}

$Branch = "$(git branch --show-current)".Trim()
if ([string]::IsNullOrWhiteSpace($Branch)) {
    throw 'No se pudo determinar la rama actual.'
}

git push -u origin $Branch

git status --short
git log -1 --oneline
git branch -vv
```

El script se detiene antes de extraer si alguno de los seis archivos tiene cambios locales o si ya existen archivos preparados en Git.
