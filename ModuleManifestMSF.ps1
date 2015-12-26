New-ModuleManifest -Path .\RestoreAutomation.psd1 -Author 'Michael S. Fal' `
 -CompanyName 'Creative Commons License - Attribution/Non-Commercial (https://creativecommons.org/licenses/by-nc/3.0/)' `
 -RequiredAssemblies @('Microsoft.SqlServer.SMO') `
 -FunctionsToExport @('New-Restore','Sync-DBUsers','Copy-Logins') `
 -RootModule 'RestoreAutomation.psm1'
