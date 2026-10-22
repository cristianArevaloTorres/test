# Cherry-pick y publicación — Backend BeFlex 3

## 1. Pega aquí los valores

Modifica únicamente este bloque. Los commits deben ir del más antiguo al más
reciente.

```powershell
# PEGA AQUÍ la ruta completa del repositorio Backend.
$RepoBack = "PEGA_AQUI_LA_RUTA_DEL_REPOSITORIO_BACKEND"

# PEGA AQUÍ el nombre exacto del branch donde existen los commits.
$RamaOrigenBack = "PEGA_AQUI_EL_BRANCH_ORIGEN_BACKEND"

# PEGA AQUÍ el nombre exacto del branch que recibirá los commits.
$RamaDestinoBack = "PEGA_AQUI_EL_BRANCH_DESTINO_BACKEND"

# PEGA AQUÍ los hashes, del más antiguo al más reciente.
$CommitsBack = @(
    "PEGA_AQUI_EL_HASH_DEL_COMMIT_1",
    "PEGA_AQUI_EL_HASH_DEL_COMMIT_2"
)
```

Si solamente aplicarás un commit, elimina la segunda línea y la coma de la
primera:

```powershell
$CommitsBack = @(
    "PEGA_AQUI_EL_HASH_DEL_COMMIT"
)
```

## 2. Ejecuta el proceso

Ejecuta primero el bloque de valores anterior y después este bloque completo:

```powershell
$ValoresBack = @($RepoBack, $RamaOrigenBack, $RamaDestinoBack) + @($CommitsBack)
if (@($ValoresBack | Where-Object { $_ -match "PEGA_AQUI" }).Count -gt 0) {
    throw "Faltan valores de BACKEND. Reemplaza todos los textos PEGA_AQUI."
}

if ([string]::IsNullOrWhiteSpace($RepoBack) -or
    [string]::IsNullOrWhiteSpace($RamaOrigenBack) -or
    [string]::IsNullOrWhiteSpace($RamaDestinoBack) -or
    @($CommitsBack).Count -eq 0 -or
    @($CommitsBack | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw "La ruta, los branches y la lista de commits de BACKEND son obligatorios."
}

if (-not (Test-Path -LiteralPath $RepoBack -PathType Container)) {
    throw "No existe la ruta del repositorio BACKEND: $RepoBack"
}

Set-Location -LiteralPath $RepoBack -ErrorAction Stop

$EsRepoBack = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $EsRepoBack -ne "true") {
    throw "La ruta indicada para BACKEND no es un repositorio Git."
}

if (@(git status --porcelain).Count -gt 0) {
    throw "BACKEND tiene cambios pendientes. Guárdalos antes de continuar."
}

git fetch origin --prune
if ($LASTEXITCODE -ne 0) {
    throw "Falló git fetch en BACKEND."
}

git fetch origin "+refs/heads/${RamaOrigenBack}:refs/remotes/origin/${RamaOrigenBack}"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo descargar el branch origen: $RamaOrigenBack"
}

git fetch origin "+refs/heads/${RamaDestinoBack}:refs/remotes/origin/${RamaDestinoBack}"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo descargar el branch destino: $RamaDestinoBack"
}

git show-ref --verify --quiet "refs/heads/$RamaDestinoBack"
if ($LASTEXITCODE -eq 0) {
    git switch $RamaDestinoBack
} else {
    git switch --track -c $RamaDestinoBack "origin/$RamaDestinoBack"
}
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo cambiar al branch destino de BACKEND."
}

git pull --ff-only origin $RamaDestinoBack
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo actualizar el branch destino de BACKEND."
}

$BaseLocalBack = git rev-parse HEAD
$BaseRemotaBack = git rev-parse "origin/$RamaDestinoBack"
if ($BaseLocalBack -ne $BaseRemotaBack) {
    throw "El branch destino local contiene commits que no están en origin. Revísalos antes de continuar."
}

foreach ($Commit in $CommitsBack) {
    git cat-file -e "$Commit^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "No existe el commit $Commit en BACKEND."
    }

    git merge-base --is-ancestor $Commit "origin/$RamaOrigenBack"
    if ($LASTEXITCODE -ne 0) {
        throw "El commit $Commit no pertenece al branch origen $RamaOrigenBack."
    }

    $PartesCommit = (git rev-list --parents -n 1 $Commit) -split '\s+'
    if ($PartesCommit.Count -ne 2) {
        throw "El commit $Commit es inicial o merge. Un merge necesita tratamiento manual con -m."
    }

    $EstadoParche = @(git cherry HEAD $Commit "$Commit^")
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo comparar el cambio del commit $Commit."
    }

    if ($EstadoParche.Count -eq 0 -or $EstadoParche[0].StartsWith("-")) {
        Write-Host "El cambio de $Commit ya está aplicado; se omite." -ForegroundColor Yellow
        continue
    }

    git cherry-pick $Commit
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo aplicar $Commit. Revisa git status; resuelve y usa git cherry-pick --continue, o cancela con git cherry-pick --abort."
    }
}

git status
git log --oneline "origin/$RamaDestinoBack..HEAD"
git diff --stat "origin/$RamaDestinoBack..HEAD"

if (@(git status --porcelain).Count -gt 0) {
    throw "Existen cambios sin confirmar; no se realizará el push."
}

git push origin "HEAD:refs/heads/$RamaDestinoBack"
if ($LASTEXITCODE -ne 0) {
    throw "Falló el push del branch destino de BACKEND."
}

git fetch origin "+refs/heads/${RamaDestinoBack}:refs/remotes/origin/${RamaDestinoBack}"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo actualizar la referencia remota para validar el push."
}

$CommitLocalBack = git rev-parse HEAD
$CommitRemotoBack = git rev-parse "origin/$RamaDestinoBack"
if ($CommitLocalBack -ne $CommitRemotoBack) {
    throw "La validación final falló: local y remoto no apuntan al mismo commit."
}

Write-Host "BACKEND publicado correctamente: $RamaDestinoBack -> $CommitRemotoBack" -ForegroundColor Green
```

## 3. Si aparece un conflicto

```powershell
git status

# Corrige cada archivo y PEGA AQUÍ su ruta.
git add "PEGA_AQUI_LA_RUTA_DEL_ARCHIVO_CORREGIDO"

git cherry-pick --continue
```

Después aplica manualmente los hashes restantes y ejecuta la parte de revisión,
`push` y validación del bloque principal. Para cancelar:

```powershell
git cherry-pick --abort
```
