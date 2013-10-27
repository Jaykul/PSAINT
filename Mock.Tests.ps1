
# if(!(Get-Module ScopeContainer)) {
# 
#    New-Module ScopeContainer {
# 
#       function Get-Text {
#          [CmdletBinding()]
#          param($Path)
#          Get-Content $Path
#       }
#       function Get-File {
#          [CmdletBinding()]
#          param($Path)
#          Get-Item $Path
#       }
# 
#    } | Import-Module -Force -DisableNameChecking
# 
# }

if(!(Get-Module ModuleScopeContainer)) {

   New-Module ModuleScopeContainer {
      New-Module NestedScopeContainer {

         function Get-Text {
            [CmdletBinding()]
            param($Path)
            Get-Content $Path
         }
         function Get-File {
            [CmdletBinding()]
            param($Path)
            Get-Item $Path
         }

      } | Import-Module -Force -DisableNameChecking
   } | Import-Module -Force -DisableNameChecking

}


# These tests should be FIXED by mocks is what I'm going to fix:
Write-Host "The EXPECTED results here are False, False, True, True, False, False:" -fore Yellow

# This test succeeds only if .\Profile.psd1 exists...
$Content = Get-Text .\Profile.psd1 -ErrorAction SilentlyContinue
# This test succeeds only if .\Profile.psd1 has the right contents:
$Content -eq '@{Greeting="Hello World"}'
# This test succeeds only if .\Profile.psd1 exists...
$Item = Get-File .\Profile.psd1 -ErrorAction SilentlyContinue
# This test succeeds only if the right user runs it, omg.
$Item.FullName -eq "C:\Users\Jaykul\Documents\WindowsPowerShell\Profile.psd1"


New-MockCmdlet  Get-Content { '@{Greeting="Hello World"}' } -Module ModuleScopeContainer, NestedScopeContainer
New-MockCmdlet  Get-Item  { [IO.FileInfo]"C:\Users\Jaykul\Documents\WindowsPowerShell\Profile.psd1" } -Module ModuleScopeContainer, NestedScopeContainer


# These four tests should be FIXED by mocks is what I'm going to fix:

# This test succeeds only if .\Profile.psd1 exists...
$Content = Get-Text .\Profile.psd1
# This test succeeds only if .\Profile.psd1 has the right contents:
$Content -eq '@{Greeting="Hello World"}'
# This test succeeds only if .\Profile.psd1 exists...
$Item = Get-File .\Profile.psd1
# This test succeeds only if the right user runs it, omg.
$Item.FullName -eq "C:\Users\Jaykul\Documents\WindowsPowerShell\Profile.psd1"

Remove-MockCmdlet ModuleScopeContainer, NestedScopeContainer

# These four tests should be FIXED by mocks is what I'm going to fix:

# This test succeeds only if .\Profile.psd1 exists...
$Content = Get-Text .\Profile.psd1 -ErrorAction SilentlyContinue
# This test succeeds only if .\Profile.psd1 has the right contents:
$Content -eq '@{Greeting="Hello World"}'
# This test succeeds only if .\Profile.psd1 exists...
$Item = Get-File .\Profile.psd1 -ErrorAction SilentlyContinue
# This test succeeds only if the right user runs it, omg.
$Item.FullName -eq "C:\Users\Jaykul\Documents\WindowsPowerShell\Profile.psd1"

