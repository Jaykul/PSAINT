@{
    Name    = "PSAINT"
    Version = "1.5"
    Author  = "Joel Bennett"
    AuthorEmail  = "Jaykul@HuddledMasses.org"

    ModuleInfoUri       = "http://huddledmasses.org/arrange-act-assert-intuitive-testing/" 
    LicenseUri          = "http://www.apache.org/licenses/LICENSE-2.0"
    PackageManifestUri  = "http://poshcode.org/Modules/PSAINT.psd1" 
    DownloadUri         = "http://poshcode.org/Modules/PSAINT-1.4.psmx" 

    RequiredModules = @(
        @{ Name="Reflection"; PackageManifestUri="http://PoshCode.org/Modules/Reflection.psd1" }
    )
}