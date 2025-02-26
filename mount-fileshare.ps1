# Script para montar Azure File Share usando diretamente o token da Managed Identity
# Variáveis - já preenchidas com seus valores específicos
$storageAccountName = "storagefilesharepoc"
$fileShareName = "fileshare-mount-poc"
$mountPoint = "Z:"
$clientId = "CLIENTID"  # Client ID da Managed Identity

# Obter o token de acesso diretamente para o Storage
try {
    Write-Output "Obtendo token para Azure Storage..."
    $response = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/&client_id=$clientId" -Method GET -Headers @{Metadata="true"} -ErrorAction Stop
    $storageToken = $response.access_token
    Write-Output "Token para Storage obtido com sucesso."
} catch {
    Write-Error "Falha ao obter token para Storage: $_"
    exit 1
}

# Limpar qualquer montagem prévia
if (Get-PSDrive -Name $mountPoint.TrimEnd(':') -ErrorAction SilentlyContinue) {
    Write-Output "Removendo montagem existente em $mountPoint..."
    net use $mountPoint /delete /y
}

# Limpar credenciais existentes
Write-Output "Removendo credenciais antigas, se existirem..."
cmdkey /delete:$storageAccountName.file.core.windows.net 2>&1 | Out-Null

# IMPORTANTE: Para montar com token OAuth/Azure AD, precisamos usar o usuário "OAuth" em vez de "Azure\storageAccountName"
Write-Output "Adicionando credenciais OAuth para o file share..."
$cmdResult = cmd.exe /c "cmdkey /add:$storageAccountName.file.core.windows.net /user:OAuth /pass:$storageToken" 2>&1
Write-Output "Resultado cmdkey: $cmdResult"

# Mapear o file share para a letra de drive
Write-Output "Mapeando file share para a letra de drive $mountPoint..."
$mapResult = cmd.exe /c "net use $mountPoint \\$storageAccountName.file.core.windows.net\$fileShareName /persistent:yes" 2>&1
Write-Output "Resultado net use: $mapResult"

# Verificar o mapeamento
if (Test-Path -Path $mountPoint) {
    Write-Output "Drive $mountPoint mapeado com sucesso!"
    Write-Output "Conteúdo do drive:"
    Get-ChildItem -Path $mountPoint
} else {
    Write-Error "Falha ao verificar o mapeamento do drive. Verifique os erros acima."
    Write-Output "NOTA: Para usar autenticação OAuth direta, verifique se:"
    Write-Output "1. A Storage Account está configurada para permitir autenticação via Azure AD"
    Write-Output "2. O Azure AD Kerberos está habilitado para essa Storage Account"
    Write-Output "3. A Managed Identity tem a função 'Storage File Data SMB Share Contributor' (diferente do 'Storage Account Key Operator')"
    exit 1
}