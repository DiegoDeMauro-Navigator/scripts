# Script para montar Azure File Share usando directamente el token de la Managed Identity
# Variables - ya llenadas con sus valores específicos
$storageAccountName = "storagefilesharepoc"
$fileShareName = "fileshare-mount-poc"
$mountPoint = "Z:"
$clientId = "CLIENTID"  # Client ID de la Managed Identity

# Obtener el token de acceso directamente para el Storage
try {
    Write-Output "Obteniendo token para Azure Storage..."
    $response = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/&client_id=$clientId" -Method GET -Headers @{Metadata="true"} -ErrorAction Stop
    $storageToken = $response.access_token
    Write-Output "Token para Storage obtenido con éxito."
} catch {
    Write-Error "Fallo al obtener token para Storage: $_"
    exit 1
}

# Limpiar cualquier montaje previo
if (Get-PSDrive -Name $mountPoint.TrimEnd(':') -ErrorAction SilentlyContinue) {
    Write-Output "Eliminando montaje existente en $mountPoint..."
    net use $mountPoint /delete /y
}

# Limpiar credenciales existentes
Write-Output "Eliminando credenciales antiguas, si existen..."
cmdkey /delete:$storageAccountName.file.core.windows.net 2>&1 | Out-Null

# IMPORTANTE: Para montar con token OAuth/Azure AD, necesitamos usar el usuario "OAuth" en lugar de "Azure\storageAccountName"
Write-Output "Añadiendo credenciales OAuth para el file share..."
$cmdResult = cmd.exe /c "cmdkey /add:$storageAccountName.file.core.windows.net /user:OAuth /pass:$storageToken" 2>&1
Write-Output "Resultado cmdkey: $cmdResult"

# Mapear el file share a la letra de unidad
Write-Output "Mapeando file share a la letra de unidad $mountPoint..."
$mapResult = cmd.exe /c "net use $mountPoint \\$storageAccountName.file.core.windows.net\$fileShareName /persistent:yes" 2>&1
Write-Output "Resultado net use: $mapResult"

# Verificar el mapeo
if (Test-Path -Path $mountPoint) {
    Write-Output "Unidad $mountPoint mapeada con éxito!"
    Write-Output "Contenido de la unidad:"
    Get-ChildItem -Path $mountPoint
} else {
    Write-Error "Fallo al verificar el mapeo de la unidad. Verifique los errores anteriores."
    Write-Output "NOTA: Para usar autenticación OAuth directa, verifique que:"
    Write-Output "1. La cuenta de almacenamiento esté configurada para permitir autenticación vía Azure AD"
    Write-Output "2. Azure AD Kerberos esté habilitado para esta cuenta de almacenamiento"
    Write-Output "3. La Managed Identity tenga el rol 'Storage File Data SMB Share Contributor' (diferente de 'Storage Account Key Operator')"
    exit 1
}