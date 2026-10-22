# Cherry-pick y publicación — Frontend BeFlex 3

## 1. Pega aquí los valores

Modifica únicamente este bloque. Los commits deben ir del más antiguo al más
reciente.

```powershell
# PEGA AQUÍ la ruta completa del repositorio Frontend.
$RepoFront = "PEGA_AQUI_LA_RUTA_DEL_REPOSITORIO_FRONTEND"

# PEGA AQUÍ el nombre exacto del branch donde existen los commits.
$RamaOrigenFront = "PEGA_AQUI_EL_BRANCH_ORIGEN_FRONTEND"

# PEGA AQUÍ el nombre exacto del branch que recibirá los commits.
$RamaDestinoFront = "PEGA_AQUI_EL_BRANCH_DESTINO_FRONTEND"

# PEGA AQUÍ los hashes, del más antiguo al más reciente.
$CommitsFront = @(
    "PEGA_AQUI_EL_HASH_DEL_COMMIT_1",
    "PEGA_AQUI_EL_HASH_DEL_COMMIT_2"
)
```

Si solamente aplicarás un commit, elimina la segunda línea y la coma de la
primera:

```powershell
$CommitsFront = @(
    "PEGA_AQUI_EL_HASH_DEL_COMMIT"
)
```

## 2. Ejecuta el proceso

Ejecuta primero el bloque de valores anterior y después este bloque completo:

```powershell
$ValoresFront = @($RepoFront, $RamaOrigenFront, $RamaDestinoFront) + @($CommitsFront)
if (@($ValoresFront | Where-Object { $_ -match "PEGA_AQUI" }).Count -gt 0) {
    throw "Faltan valores de FRONTEND. Reemplaza todos los textos PEGA_AQUI."
}

if ([string]::IsNullOrWhiteSpace($RepoFront) -or
    [string]::IsNullOrWhiteSpace($RamaOrigenFront) -or
    [string]::IsNullOrWhiteSpace($RamaDestinoFront) -or
    @($CommitsFront).Count -eq 0 -or
    @($CommitsFront | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw "La ruta, los branches y la lista de commits de FRONTEND son obligatorios."
}

if (-not (Test-Path -LiteralPath $RepoFront -PathType Container)) {
    throw "No existe la ruta del repositorio FRONTEND: $RepoFront"
}

Set-Location -LiteralPath $RepoFront -ErrorAction Stop

$EsRepoFront = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $EsRepoFront -ne "true") {
    throw "La ruta indicada para FRONTEND no es un repositorio Git."
}

if (@(git status --porcelain).Count -gt 0) {
    throw "FRONTEND tiene cambios pendientes. Guárdalos antes de continuar."
}

git fetch origin --prune
if ($LASTEXITCODE -ne 0) {
    throw "Falló git fetch en FRONTEND."
}

git fetch origin "+refs/heads/${RamaOrigenFront}:refs/remotes/origin/${RamaOrigenFront}"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo descargar el branch origen: $RamaOrigenFront"
}

git fetch origin "+refs/heads/${RamaDestinoFront}:refs/remotes/origin/${RamaDestinoFront}"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo descargar el branch destino: $RamaDestinoFront"
}

git show-ref --verify --quiet "refs/heads/$RamaDestinoFront"
if ($LASTEXITCODE -eq 0) {
    git switch $RamaDestinoFront
} else {
    git switch --track -c $RamaDestinoFront "origin/$RamaDestinoFront"
}
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo cambiar al branch destino de FRONTEND."
}

git pull --ff-only origin $RamaDestinoFront
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo actualizar el branch destino de FRONTEND."
}

$BaseLocalFront = git rev-parse HEAD
$BaseRemotaFront = git rev-parse "origin/$RamaDestinoFront"
if ($BaseLocalFront -ne $BaseRemotaFront) {
    throw "El branch destino local contiene commits que no están en origin. Revísalos antes de continuar."
}

foreach ($Commit in $CommitsFront) {
    git cat-file -e "$Commit^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "No existe el commit $Commit en FRONTEND."
    }

    git merge-base --is-ancestor $Commit "origin/$RamaOrigenFront"
    if ($LASTEXITCODE -ne 0) {
        throw "El commit $Commit no pertenece al branch origen $RamaOrigenFront."
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
git log --oneline "origin/$RamaDestinoFront..HEAD"
git diff --stat "origin/$RamaDestinoFront..HEAD"

if (@(git status --porcelain).Count -gt 0) {
    throw "Existen cambios sin confirmar; no se realizará el push."
}

git push origin "HEAD:refs/heads/$RamaDestinoFront"
if ($LASTEXITCODE -ne 0) {
    throw "Falló el push del branch destino de FRONTEND."
}

git fetch origin "+refs/heads/${RamaDestinoFront}:refs/remotes/origin/${RamaDestinoFront}"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo actualizar la referencia remota para validar el push."
}

$CommitLocalFront = git rev-parse HEAD
$CommitRemotoFront = git rev-parse "origin/$RamaDestinoFront"
if ($CommitLocalFront -ne $CommitRemotoFront) {
    throw "La validación final falló: local y remoto no apuntan al mismo commit."
}

Write-Host "FRONTEND publicado correctamente: $RamaDestinoFront -> $CommitRemotoFront" -ForegroundColor Green
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
