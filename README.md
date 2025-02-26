Aquí tienes las instrucciones en español:

### Configurar un script de PowerShell como servicio de Windows usando NSSM

1. Descarga NSSM (Non-Sucking Service Manager) de https://nssm.cc/download
   - Descarga la versión más reciente (probablemente nssm 2.24)
   - Extrae los archivos a una carpeta, por ejemplo `C:\tools\nssm`

2. Abre el símbolo del sistema (cmd) como administrador

3. Navega hasta la carpeta donde extrajiste NSSM:
   ```
   cd C:\tools\nssm\win64
   ```
   (o usa win32 si estás en un sistema de 32 bits)

4. Ejecuta el comando para instalar el servicio:
   ```
   nssm.exe install "NombreDeTuServicio"
   ```

5. En la interfaz gráfica que aparecerá:
   - En la pestaña "Application":
     - Path: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
     - Startup directory: `C:\Windows\System32\WindowsPowerShell\v1.0`
     - Arguments: `-ExecutionPolicy Bypass -NoProfile -File "C:\ruta\completa\a\tu\script.ps1"`

   - En la pestaña "Details":
     - Display name: Nombre descriptivo de tu servicio
     - Description: Descripción de lo que hace el servicio
     - Startup type: Automatic

   - En la pestaña "Log on":
     - Elige "Local System account" (para tener permisos elevados)

6. Haz clic en "Install service"

7. Para iniciar el servicio inmediatamente:
   ```
   nssm.exe start "NombreDeTuServicio"
   ```

Este método garantiza que tu script de PowerShell se ejecute como un servicio durante el arranque del sistema, independientemente de cualquier inicio de sesión de usuario. El servicio se ejecutará con la cuenta Local System, que tiene privilegios elevados para realizar tareas como montar unidades de red.

Si necesitas que el servicio tenga acceso a recursos de red específicos, puede ser necesario configurar la pestaña "Log on" para usar una cuenta de dominio con los permisos necesarios en lugar de Local System.


IMPORTANTE IMPORTANTE IMPORTANTE:

No te ouvides sacar el drive si ejecuta el script en la session del usuario!!!!!!

Get-PSDrive -PSProvider FileSystem | Where-Object {$_.DisplayRoot}

Remove-PSDrive -Name Z -Force