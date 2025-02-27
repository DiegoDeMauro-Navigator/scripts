
$storageAccountName = "azjispstfsjauregui02"
$fileShareName = "jauregui"
$mountPoint = "Z:"
$clientId = "b4662711-3326-4ad1-b966-679a5ce4c0dc"
$subscriptionId = "9c4754a0-823e-468c-bc57-c6afee00b902"
$resourceGroupName = "az-jis-p-rg-jauregui-01"

# 1. Obter token para Azure Resource Manager
Write-Output "Obtendo token para Azure Resource Manager..."
$armToken = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/&client_id=$clientId" -Method GET -Headers @{Metadata="true"}
$armAccessToken = $armToken.access_token

# 2. Obter chave da Storage Account
Write-Output "Obtendo chave da Storage Account..."
$url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName/listKeys?api-version=2019-06-01"
$headers = @{
    Authorization = "Bearer $armAccessToken"
    "Content-Type" = "application/json"
}
$keysResponse = Invoke-RestMethod -Uri $url -Headers $headers -Method POST
$storageKey = $keysResponse.keys[0].value
Write-Output "Chave obtida com sucesso"

# 3. Verificar se a porta SMB (445) está acessível
$testConnection = Test-NetConnection -ComputerName "$storageAccountName.file.core.windows.net" -Port 445 -InformationLevel Quiet
if (-not $testConnection) {
    Write-Error "A porta 445 está bloqueada. Verifique as regras de firewall."
    exit 1
}

# 4. Limpar qualquer montagem anterior
if (Get-PSDrive -Name $mountPoint.TrimEnd(':') -ErrorAction SilentlyContinue) {
    Write-Output "Removendo montagem existente em $mountPoint..."
    net use $mountPoint /delete /y
}

# 5. Configurar as credenciais no Windows Credential Manager
Write-Output "Configurando credenciais..."
cmdkey /delete:$storageAccountName.file.core.windows.net 2>&1 | Out-Null
cmdkey /add:$storageAccountName.file.core.windows.net /user:Azure\$storageAccountName /pass:$storageKey

# 6. Montar o File Share
Write-Output "Montando o File Share..."
net use $mountPoint "\\$storageAccountName.file.core.windows.net\$fileShareName" /persistent:yes

# 7. Verificar se a montagem foi bem-sucedida
if (Test-Path -Path $mountPoint) {
    Write-Output "File Share montado com sucesso como $mountPoint"
    # Listar os primeiros 5 itens
    Get-ChildItem -Path $mountPoint | Select-Object -First 5
} else {
    Write-Error "Falha ao montar o File Share. Verifique a conta e as permissões."
    exit 1
}