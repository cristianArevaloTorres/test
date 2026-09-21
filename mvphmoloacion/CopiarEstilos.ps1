# ============================================================
# CREA 010 - Copia automática de estilos MVP
# PowerShell
#
# Equivalente a:
#   EstilosMVP.CopiarEstilos(nuevaEmpresa.Id)
#   EstilosMVP.CopiarLoginCSS(nuevaEmpresa.IdCorporativo)
# ============================================================


# ============================================================
# CONFIGURACIÓN
# ============================================================

# ------------------------------------------------------------
# ORÍGENES
# ------------------------------------------------------------

$RutaMVP_OrigenGeneral = "\\lockmx-block3qa\public\Stilos\General\GenericMVP\"

$RutaMVP_OrigenMenus = "\\lockmx-block3qa\public\Stilos\Menus\GenericMVP\"

$RutaMVP_Login = "\\lockmx-block3qa\public\Stilos\Login\"


# ------------------------------------------------------------
# DESTINOS
# ------------------------------------------------------------

$RutaMVP_DestinoGeneral = "\\lockmx-block3qa\public\Stilos\General\"

$RutaMVP_DestinoMenus = "\\lockmx-block3qa\public\Stilos\Menus\"


# ------------------------------------------------------------
# DATOS DE LA EMPRESA
# ------------------------------------------------------------

$idEmpresa = 495

$idCorporativo = 495

$EmpresaMVP = 1


# ============================================================
# FUNCIÓN: Copiar archivo si existe
# ============================================================

function Copiar-ArchivoSiExiste {

    param (
        [string]$Origen,
        [string]$Destino
    )

    if (Test-Path -LiteralPath $Origen) {

        if (-not (Test-Path -LiteralPath $Destino)) {

            $destinoDir = Split-Path $Destino -Parent

            if (-not (Test-Path -LiteralPath $destinoDir)) {

                New-Item `
                    -ItemType Directory `
                    -Path $destinoDir `
                    -Force |
                    Out-Null
            }

            Copy-Item `
                -LiteralPath $Origen `
                -Destination $Destino `
                -Force

            Write-Host "Copiado:"
            Write-Host "  ORIGEN : $Origen"
            Write-Host "  DESTINO: $Destino"
        }
        else {

            Write-Host "Ya existe:"
            Write-Host "  $Destino"
        }
    }
    else {

        Write-Warning "No existe el archivo origen:"
        Write-Warning "  $Origen"
    }
}


# ============================================================
# FUNCIÓN: Leer CSS y renombrar Logo
#
# Equivalente EXACTO a:
#
# private static string LeerCssRenombrado(
#     string srcCss,
#     int idEmpresa)
# {
#     if (!File.Exists(srcCss))
#         return string.Empty;
#
#     string css = File.ReadAllText(srcCss);
#
#     return _reIdHardcoded.Replace(
#         css,
#         idEmpresa + "_Logo.png");
# }
#
# Regex C#:
#
# \b(382|GenericMVP)_Logo\.png\b
#
# Reemplaza:
#
# 382_Logo.png
# GenericMVP_Logo.png
#
# por:
#
# <idEmpresa>_Logo.png
# ============================================================

function Leer-CssRenombrado {

    param (
        [string]$SrcCss,
        [int]$IdEmpresa
    )

    if (-not (Test-Path -LiteralPath $SrcCss)) {

        Write-Warning "No existe CSS:"
        Write-Warning "  $SrcCss"

        return ""
    }

    try {

        $css = Get-Content `
            -LiteralPath $SrcCss `
            -Raw

        # Equivalente al Regex de C#
        $regex = '\b(382|GenericMVP)_Logo\.png\b'

        # Equivalente a:
        # _reIdHardcoded.Replace(css, idEmpresa + "_Logo.png")
        $css = $css -replace `
            $regex, `
            "${IdEmpresa}_Logo.png"

        return $css
    }
    catch {

        Write-Warning "Error leyendo CSS:"
        Write-Warning "  $SrcCss"

        Write-Warning $_.Exception.Message

        return ""
    }
}


# ============================================================
# FUNCIÓN: Copiar estilos
#
# Equivalente a:
#
# EstilosMVP.CopiarEstilos(nuevaEmpresa.Id);
# ============================================================

function Copiar-Estilos {

    param (
        [int]$IdEmpresa
    )

    try {

        # ------------------------------------------------------
        # VALIDAR ID
        # ------------------------------------------------------

        if ($IdEmpresa -le 0) {

            Write-Warning "ID de empresa inválido: $IdEmpresa"

            return
        }


        Write-Host ""
        Write-Host "========================================="
        Write-Host "COPIANDO ESTILOS MVP"
        Write-Host "Empresa: $IdEmpresa"
        Write-Host "========================================="


        # ------------------------------------------------------
        # VALIDAR ORÍGENES
        # ------------------------------------------------------

        if (-not (Test-Path -LiteralPath $RutaMVP_OrigenGeneral)) {

            Write-Warning "Origen General no existe:"
            Write-Warning "  $RutaMVP_OrigenGeneral"

            return
        }


        if (-not (Test-Path -LiteralPath $RutaMVP_OrigenMenus)) {

            Write-Warning "Origen Menus no existe:"
            Write-Warning "  $RutaMVP_OrigenMenus"

            return
        }


        # ======================================================
        # 1. GENERAL\<ID>
        # ======================================================

        $dstGen = Join-Path `
            $RutaMVP_DestinoGeneral `
            $IdEmpresa.ToString()


        Write-Host ""
        Write-Host "--- GENERAL ---"
        Write-Host "Destino: $dstGen"


        # Crear carpeta
        if (-not (Test-Path -LiteralPath $dstGen)) {

            New-Item `
                -ItemType Directory `
                -Path $dstGen `
                -Force |
                Out-Null

            Write-Host "Carpeta creada."
        }
        else {

            Write-Host "La carpeta ya existe."
        }


        # ------------------------------------------------------
        # Lockton Logo
        # ------------------------------------------------------

        Copiar-ArchivoSiExiste `
            (Join-Path $RutaMVP_OrigenGeneral "Lockton_Logo.png") `
            (Join-Path $dstGen "Lockton_Logo.png")


        # ------------------------------------------------------
        # GenericMVP Logo
        #
        # GenericMVP_Logo.png
        #
        # se convierte en:
        #
        # <idEmpresa>_Logo.png
        # ------------------------------------------------------

        Copiar-ArchivoSiExiste `
            (Join-Path $RutaMVP_OrigenGeneral "GenericMVP_Logo.png") `
            (Join-Path $dstGen "${IdEmpresa}_Logo.png")


        # ======================================================
        # 2. CSS GENERAL
        # ======================================================

        Write-Host ""
        Write-Host "--- CSS GENERAL ---"


        # ------------------------------------------------------
        # IMPORTANTE:
        #
        # RutaMVP_OrigenGeneral:
        #
        # \\servidor\...\General\GenericMVP\
        #
        # CSS raíz:
        #
        # \\servidor\...\General\ClaGenericMVP.css
        #
        # CSS sub:
        #
        # \\servidor\...\General\GenericMVP\ClaGenericMVP.css
        # ------------------------------------------------------

        $srcGenTrim = $RutaMVP_OrigenGeneral.TrimEnd('\', '/')

        $parentGen = Split-Path `
            $srcGenTrim `
            -Parent


        $srcCssRaiz = Join-Path `
            $parentGen `
            "ClaGenericMVP.css"


        $srcCssSub = Join-Path `
            $RutaMVP_OrigenGeneral `
            "ClaGenericMVP.css"


        Write-Host "CSS raíz:"
        Write-Host "  $srcCssRaiz"

        Write-Host "CSS sub:"
        Write-Host "  $srcCssSub"


        # ------------------------------------------------------
        # Leer CSS raíz
        # ------------------------------------------------------

        $cssRaiz = Leer-CssRenombrado `
            -SrcCss $srcCssRaiz `
            -IdEmpresa $IdEmpresa


        # ------------------------------------------------------
        # Leer CSS subcarpeta
        # ------------------------------------------------------

        $cssSub = Leer-CssRenombrado `
            -SrcCss $srcCssSub `
            -IdEmpresa $IdEmpresa


        # ------------------------------------------------------
        # Unificar ambos CSS
        #
        # Equivalente a:
        #
        # string cssUnificado =
        #     (LeerCssRenombrado(srcCssRaiz, idEmpresa)
        #      + Environment.NewLine +
        #      LeerCssRenombrado(srcCssSub, idEmpresa))
        #      .Trim();
        # ------------------------------------------------------

        $cssUnificado = (
            $cssRaiz +
            [Environment]::NewLine +
            $cssSub
        ).Trim()


        # ======================================================
        # 3. Cla<ID>.css EN General\<ID>\
        # ======================================================

        $dstCssEmpresa = Join-Path `
            $dstGen `
            "Cla$IdEmpresa.css"


        Write-Host ""
        Write-Host "CSS empresa:"
        Write-Host "  $dstCssEmpresa"


        if (-not (Test-Path -LiteralPath $dstCssEmpresa)) {

            Set-Content `
                -LiteralPath $dstCssEmpresa `
                -Value $cssUnificado `
                -Encoding UTF8

            Write-Host "CSS creado."
        }
        else {

            Write-Host "CSS ya existe. No se modifica."
        }


        # ======================================================
        # 4. Cla<ID>.css EN RAÍZ DE General
        # ======================================================

        $dstCssRaiz = Join-Path `
            $RutaMVP_DestinoGeneral `
            "Cla$IdEmpresa.css"


        Write-Host ""
        Write-Host "CSS fallback:"
        Write-Host "  $dstCssRaiz"


        if (-not (Test-Path -LiteralPath $dstCssRaiz)) {

            Set-Content `
                -LiteralPath $dstCssRaiz `
                -Value $cssUnificado `
                -Encoding UTF8

            Write-Host "CSS fallback creado."
        }
        else {

            Write-Host "CSS fallback ya existe. No se modifica."
        }


        # ======================================================
        # 5. MENUS\<ID>
        # ======================================================

        $dstMen = Join-Path `
            $RutaMVP_DestinoMenus `
            $IdEmpresa.ToString()


        Write-Host ""
        Write-Host "--- MENUS ---"
        Write-Host "Destino: $dstMen"


        if (-not (Test-Path -LiteralPath $dstMen)) {

            New-Item `
                -ItemType Directory `
                -Path $dstMen `
                -Force |
                Out-Null

            Write-Host "Carpeta de menús creada."


            # --------------------------------------------------
            # Copiar todos los archivos manteniendo estructura
            # --------------------------------------------------

            $srcMenTrim = $RutaMVP_OrigenMenus.TrimEnd('\', '/')

            Get-ChildItem `
                -LiteralPath $srcMenTrim `
                -Recurse `
                -File |
            ForEach-Object {

                $relativePath = $_.FullName.Substring(
                    $srcMenTrim.Length
                ).TrimStart('\', '/')


                $destination = Join-Path `
                    $dstMen `
                    $relativePath


                $destinationDir = Split-Path `
                    $destination `
                    -Parent


                if (-not (Test-Path -LiteralPath $destinationDir)) {

                    New-Item `
                        -ItemType Directory `
                        -Path $destinationDir `
                        -Force |
                        Out-Null
                }


                if (-not (Test-Path -LiteralPath $destination)) {

                    Copy-Item `
                        -LiteralPath $_.FullName `
                        -Destination $destination `
                        -Force

                    Write-Host "Menú copiado:"
                    Write-Host "  $relativePath"
                }
                else {

                    Write-Host "Menú ya existe:"
                    Write-Host "  $relativePath"
                }
            }
        }
        else {

            Write-Host "La carpeta de menús ya existe."
            Write-Host "No se vuelve a copiar su contenido."
        }


        # ======================================================
        # FIN
        # ======================================================

        Write-Host ""
        Write-Host "========================================="
        Write-Host "COPIA DE ESTILOS FINALIZADA"
        Write-Host "Empresa: $IdEmpresa"
        Write-Host "========================================="
        Write-Host ""

    }
    catch {

        Write-Warning ""
        Write-Warning "Excepción en Copiar-Estilos:"
        Write-Warning $_.Exception.Message
        Write-Warning ""
    }
}


# ============================================================
# FUNCIÓN: Copiar CSS de Login
#
# Equivalente a:
#
# EstilosMVP.CopiarLoginCSS(nuevaEmpresa.IdCorporativo);
# ============================================================

function Copiar-LoginCSS {

    param (
        [int]$IdCorporativo
    )

    try {

        if ($IdCorporativo -le 0) {

            Write-Warning "ID corporativo inválido: $IdCorporativo"

            return
        }


        Write-Host ""
        Write-Host "========================================="
        Write-Host "COPIANDO CSS LOGIN"
        Write-Host "Corporativo: $IdCorporativo"
        Write-Host "========================================="


        # ------------------------------------------------------
        # Validar carpeta Login
        # ------------------------------------------------------

        if (-not (Test-Path -LiteralPath $RutaMVP_Login)) {

            Write-Warning "Carpeta Login no existe:"
            Write-Warning "  $RutaMVP_Login"

            return
        }


        # ------------------------------------------------------
        # Origen
        # ------------------------------------------------------

        $srcCss = Join-Path `
            $RutaMVP_Login `
            "ClaLogin.css"


        # ------------------------------------------------------
        # Destino
        #
        # ClaLogin.css
        #
        # ->
        #
        # ClaLogin<IDCorporativo>.css
        # ------------------------------------------------------

        $dstCss = Join-Path `
            $RutaMVP_Login `
            "ClaLogin$IdCorporativo.css"


        Write-Host "Origen:"
        Write-Host "  $srcCss"

        Write-Host "Destino:"
        Write-Host "  $dstCss"


        # ------------------------------------------------------
        # Validar origen
        # ------------------------------------------------------

        if (-not (Test-Path -LiteralPath $srcCss)) {

            Write-Warning "No existe CSS genérico:"
            Write-Warning "  $srcCss"

            return
        }


        # ------------------------------------------------------
        # Copiar únicamente si no existe
        #
        # Equivalente a:
        #
        # if (!File.Exists(dstCss))
        # {
        #     File.Copy(srcCss, dstCss, false);
        # }
        # ------------------------------------------------------

        if (-not (Test-Path -LiteralPath $dstCss)) {

            Copy-Item `
                -LiteralPath $srcCss `
                -Destination $dstCss

            Write-Host "CSS Login creado:"
            Write-Host "  $dstCss"
        }
        else {

            Write-Host "CSS Login ya existe:"
            Write-Host "  $dstCss"

            Write-Host "No se modifica."
        }


        Write-Host ""
        Write-Host "Copia de Login finalizada."
        Write-Host ""

    }
    catch {

        Write-Warning ""
        Write-Warning "Excepción en Copiar-LoginCSS:"
        Write-Warning $_.Exception.Message
        Write-Warning ""
    }
}


# ============================================================
# EJECUCIÓN PRINCIPAL
# ============================================================

Write-Host ""
Write-Host "#########################################"
Write-Host "# CREA 010 - ESTILOS MVP"
Write-Host "#########################################"
Write-Host ""

Write-Host "EmpresaMVP   : $EmpresaMVP"
Write-Host "IdEmpresa    : $idEmpresa"
Write-Host "IdCorporativo: $idCorporativo"
Write-Host ""


# ============================================================
# Solo ejecutar si EmpresaMVP == 1
#
# Equivalente a:
#
# if (model.EmpresaMVP == 1)
# ============================================================

if ($EmpresaMVP -eq 1) {

    try {

        # ------------------------------------------------------
        # 1. Estilos generales + menús
        #
        # Se utiliza el ID de la EMPRESA HIJA
        # ------------------------------------------------------

        Copiar-Estilos `
            -IdEmpresa $idEmpresa


        # ------------------------------------------------------
        # 2. CSS Login
        #
        # IMPORTANTE:
        # Se utiliza el ID del CORPORATIVO
        # ------------------------------------------------------

        Copiar-LoginCSS `
            -IdCorporativo $idCorporativo


        Write-Host ""
        Write-Host "#########################################"
        Write-Host "# CREA 010 COMPLETADO"
        Write-Host "#########################################"
        Write-Host ""

    }
    catch {

        Write-Warning ""
        Write-Warning "Error general:"
        Write-Warning $_.Exception.Message
        Write-Warning ""
    }

}
else {

    Write-Host "EmpresaMVP != 1."
    Write-Host "No se realiza ninguna copia."
}

