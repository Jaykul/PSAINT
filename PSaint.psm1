########################################################################
## Copyright (c) Joel Bennett, 2010
## Free for use under the Apache License 2.9
##
## NOTE: license changed 10-26-2013 to allow copying to and from Pester, 
##  the only other open source PowerShell testing framework I'm aware of
########################################################################
## See ReadMe.md

Add-Type -Path $PSScriptRoot\Libraries\Rhino.Mocks.dll

function New-RhinoMock {
   <#
      .Synopsis
         Generates a new mock object using RhinoMocks (must be present)
      .Description
         Generate mock objects with a few basic options (this function needs expanding to offer all the options)
      .Parameter Type
         The type to mock
      .CallInfo
         An array of hashtables containing information about what you want to mock. Each hashtable should contain a Method (the name of the method to call), WhenArguments (example parameter array), and Return (what the mock should output).  
   #>
   [CmdletBinding()]
   param(
      [Parameter(Position=0)]
      [Type]$Type,

      [Parameter(Position=1,ValueFromPipeline=$true)]
      [Hashtable[]]$CallInfo
   )
   begin {
      $repo = New-Object Rhino.Mocks.MockRepository
      $mock = $repo.CreateMock( $Type )
   }
   process {
      foreach($method in $CallInfo) {
         Write-Verbose "Calling $($method.Method) on $mock with $($method.WhenArguments)"
         ## let it know which VIRTUAL (or interface) method we're going to use.
         $mock.($method.Method).Invoke( $method.WhenArguments ) | Out-Null
         # Tell it what to return:
         [Rhino.Mocks.LastCall]::On( $mock ).Return( $method.Return ) | Out-Null
      }
   }
   end {
      Write-Output $mock
      $repo.ReplayAll()
   }
}


function New-MockCmdlet {
   <#
      .Synopsis
         Creates functions which mock out a function or cmdlet in a specific module (or global) scope
      .Description
         Creates a __mocks__ module in the appropriate module scope and defines mock functions there.
         Note that mocks can be overwrriten, but can only be removed whole-sale (all mocks in a module scope)
      .Example

         # Given a module definition like this ...

         New-Module ScopeContainer {

            function Get-Text {
               param($Path)
               Get-Content $Path
            }
            function Get-File {
               param($Path)
               Get-Item $Path
            }

         } | Import-Module -Force -DisableNameChecking

         # For testing purposes, you will want to mock out the functions which are called internally:         
         New-MockFunction Get-Content { '@{Greeting="Hello World"}' } -Module ScopeContainer
         New-MockFunction Get-Item  { [IO.FileInfo]"C:\Users\Jaykul\Documents\WindowsPowerShell\Profile.psd1" } -Module ScopeContainer

   #>
   [CmdletBinding()]
   param(
      # The name of the cmdlet or function to mock
      [String]$Name,
      # The Definition of the mock cmdlet.
      #
      # You must avoid using local-scoped variables in your mock definitions. Global variables are ok, but it's best to avoid variables and encode a constant result
      # 
      # Successive definitions of the same mock cmdlet in the same ModuleName (scope) will overwrite each other, but you can have different mocks for the same cmdlet in different scopes
      [ScriptBlock]$Method,
      # The Name of the module where you need the mock cmdlet
      # This should be the module where the mocked funtion will be CALLED FROM
      # Where the original is defined doesn't matter
      [string[]]$ModuleName,
      # Do not pass this parameter
      $Index = 0
   )
   if($ModuleName) {
      if( $Index -gt 0 ) {
         # Because New-MockCmdlet is defined in a module, we need to dot Invoke at every level
         $ReferenceModule = Get-Module $ModuleName[$Index-1]

         $Module = .$ReferenceModule {
            param($ModuleName)
            Get-Module $ModuleName
         } $ModuleName[$Index]
      } else {
         # For the top-level module, try import if it's not already
         if(!($Module = Get-Module $ModuleName[0])) {
            $Module = Import-Module $ModuleName[0] -Passthru -ErrorAction Stop
         }
      }


      if($Module) {
         if((++$Index) -lt $ModuleName.Count) {
            # Recursively dig into module scopes to define our mocks where they need to be.
            .$Module {
               param($Name, $Method, $ModuleName, $Index)
               New-MockCmdlet $Name $Method $ModuleName $Index
            } $Name $Method $ModuleName $Index
         } else {
            .$Module {
               param($Name, $Method)

               # Mocks are incrementally added to the __mocks__ module
               $Existing = Get-Module __mocks__  | % { $_.Definition -replace 'Export-ModuleMember -Function \* -Alias \*' }
               $__add = [ScriptBlock]::Create("${Existing}`n`nfunction ${Name}Mock {`n  $Method`n}`nSet-Alias ${Name} __mocks__\${Name}Mock`nExport-ModuleMember -Function * -Alias *")

               # But if one already exists, we need to remove it before we recreate it
               if($Existing) { Remove-Module __mocks__ -ErrorAction Silently }
               New-Module __mocks__ $__add | Import-Module -Force -DisableNameChecking
              
            } $Name $Method
         }
      } else {
         throw "Could not find Module $ModuleName"
      }
   } else {
      # Mocks are incrementally added to the __mocks__ module
      $Existing = Get-Module __mocks__  | % { $_.Definition -replace 'Export-ModuleMember -Function \* -Alias \*' }
      $__add = [ScriptBlock]::Create("${Existing}`n`nfunction ${Name}Mock {`n  $Method`n}`nSet-Alias ${Name} __mocks__\${Name}Mock`nExport-ModuleMember -Function * -Alias *")

      # But if one already exists, we need to remove it before we recreate it
      if($Existing) { Remove-Module __mocks__ -ErrorAction Silently }
      New-Module __mocks__ $__add | Import-Module -Force -DisableNameChecking
   }   
}


function Remove-MockCmdlet {
   #.Synopsis
   #  Remove all mocks from a give module scope
   #.Description
   #  TODO: Support removing just one (by deleting the alias definition lines)
   param(
      # The chain of nested modules where you want to remove the mock cmdlet
      # This should match list passed to New-MockCmdlet
      [string[]]$ModuleName,

      [switch]$Recurse,
      # Do not pass this parameter
      $Index = 0
   )

   if($ModuleName) {
      if( $Index -gt 0 ) {
         # Because New-MockCmdlet is defined in a module, we need to dot Invoke at every level
         $ReferenceModule = Get-Module $ModuleName[$Index-1]

         $Module = .$ReferenceModule {
            param($ModuleName)
            Get-Module $ModuleName
         } $ModuleName[$Index]
      } else {
         # For the top-level module, try import if it's not already
         if(!($Module = Get-Module $ModuleName[0])) {
            $Module = Import-Module $ModuleName[0] -Passthru -ErrorAction Stop
         }
      }


      if($Module) {
         if((++$Index) -lt $ModuleName.Count) {
            # Recursively dig into module scopes to define our mocks where they need to be.
            .$Module {
               param($ModuleName, $Index)
               Remove-MockCmdlet $ModuleName $Index
               # If -Recurse, then we check for and remove mocks at each level
               if($Recurse -and (Get-Module __mocks__)) {
                  Remove-Module __mocks__ 
               }               
            } $ModuleName $Index
         } else {
            .$Module {
               if(Get-Module __mocks__) {
                  Remove-Module __mocks__ 
               }
            }
         }
      }
   }
}



function Test-Code {
   [CmdletBinding()]
   param(
      [String]$name,

      [ScriptBlock]$script,

      [String[]]$Category,

      [Parameter(ValueFromRemainingArguments = $true, ValueFromPipeline = $true)]
      $arguments
   )
   begin {
      $skipTest = $false
      if(   ## Check filters ...
         !((  
            (
               @(foreach($filter in $PSaintCategoryFilter) {
                  [bool]($Category -like $filter)
               }) -contains $true
            ) -or (
               @(foreach($filter in $PSaintNameFilter) {
                  [bool]($Name -like $filter)
               }) -contains $true
            )
         ) -and (
            (
               @(foreach($filter in $PSaintExcludeCategoryFilter) {
                  [bool]($Category -like $filter)
               }) -notcontains $true
            ) -and (
               @(foreach($filter in $PSaintExcludeNameFilter) {
                  [bool]($Name -like $filter)
               }) -notcontains $true
            )
         ))
      ) {
         $skipTest = $true
         return ( New-Object PSObject -Property @{ Result = 'Skipped'; Name = $name; Category = $Category; FailMessage = "Skipped because of filters" } | ForEach-Object { $_.PSTypeNames.Insert(0,"PSaint.TestResult"); $_ } )
      }

      try {
         $ErrorCache = $Global:Error.Clone()
         $Global:Error.Clear()
         
         $results = &$PSaintTestSetupScript
         $results = ($results -eq $null) -or (@($results)[0] -is [bool] -and (@($results) -notcontains $false))
         
         if($Global:Error.Count -gt 0) {
            $FailMessage = $Global:Error.Clone()
            Write-Warning "$name is FALSE - Got Errors in Test Setup Script!`n$FailMessage"
            return ( New-Object PSObject -Property @{ Result = 'Setup Fail'; Name = $name; Category = $Category; FailMessage = $FailMessage  } | ForEach-Object { $_.PSTypeNames.Insert(0,"PSaint.TestResult"); $_ } )      
         }
         $Global:Error.InsertRange( $Global:Error.Count, $ErrorCache )
      } catch {
         $FailMessage = $_
         Write-Warning "$name is FALSE - threw exception in Test Setup Script!`n$FailMessage"
         return ( New-Object PSObject -Property @{ Result = 'Setup Fail'; Name = $name; Category = $Category; FailMessage = $FailMessage  } | ForEach-Object { $_.PSTypeNames.Insert(0,"PSaint.TestResult"); $_ } )
      }
      
      $errors = $null
      [array]$tokens = [System.Management.Automation.PSParser]::tokenize($script,[ref]$errors) | where { $_.Type -eq "Command" } 
      [array]::reverse($tokens)
      [string]$scriptString = "&{$script}"

      switch($tokens) {
         {$_.Content -eq "arrange"}
            {$scriptString = $scriptString.remove( $_.Start+2, $_.Length).Insert($_.Start+2,"begin")}
         {$_.Content -eq "act"}                                                          
            {$scriptString = $scriptString.remove( $_.Start+2, $_.Length).Insert($_.Start+2,"process")}
         {$_.Content -eq "assert"}                                                       
            {$scriptString = $scriptString.remove( $_.Start+2, $_.Length).Insert($_.Start+2,"end")}
      }

      Write-Verbose $scriptString
      
      $scriptCmd = { & ([ScriptBlock]::Create( $scriptString )) @arguments | Write-Output }
      $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
      try {
      
         $ErrorCache = $Global:Error.Clone()
         $Global:Error.Clear()
         
         $results = $steppablePipeline.Begin($myInvocation.ExpectingInput)
         $results = ($results -eq $null) -or (@($results)[0] -is [bool] -and (@($results) -notcontains $false))
         
         if($Global:Error.Count -gt 0) {
            $FailMessage = $Global:Error.Clone()
            Write-Warning "$name is FALSE - Got Errors in Arrange step!`n$FailMessage"
            $results = $false
         }
         $Global:Error.InsertRange( $Global:Error.Count, $ErrorCache )
      
      } catch {
         $FailMessage = $_
         Write-Warning "$name is FALSE - threw exception in Arrange step!`n$FailMessage"
         $results = $false
      }
      Write-Verbose "Exit Arrange for $Name"
   }

   process {
      if($skipTest) { 
         Write-Verbose "Skipping Processing for Test: $Name"
         return 
      }
      try {
         $ErrorCache = $Global:Error.Clone()
         $Global:Error.Clear()
            
         if($_) {
            $output = $steppablePipeline.Process($_)
            $results = $results -and (([string]::IsNullOrEmpty($output)) -or (@($output)[0] -is [bool] -and (@($output) -notcontains $false)))
         } else {
            $output = $steppablePipeline.Process()
            #Write-Host '$results = $results -and (([string]::IsNullOrEmpty($output)) -or ($output -is [bool] -and $output))' -fore cyan
            #Write-Host "$results = $results -and (([string]::IsNullOrEmpty($output)) -or ($($output.GetType()) -is [bool] -and $($output -join ', ') -notcontains False))" -fore cyan -NoNewLine
            $results = $results -and (([string]::IsNullOrEmpty($output)) -or (@($output)[0] -is [bool] -and (@($output) -notcontains $false)))
            #Write-Host "`t`t[$results]" -fore cyan
         }
         
         if($Global:Error.Count -gt 0) {
            $FailMessage = $Global:Error.Clone()
            Write-Warning "$name is FALSE - Got Errors in Act step!`n$FailMessage"
            $results = $false
         }
         $Global:Error.InsertRange( $Global:Error.Count, $ErrorCache )      
      } catch {
         $FailMessage = $_
         Write-Warning "$name is FALSE - threw exception in Act step!`n$FailMessage"
         $results = $false
      }
      Write-Verbose "Exit Act for $Name"   
   }

   end {
      if($skipTest) { 
         Write-Verbose "Skipping End of test: $Name"
         return 
      }
      try {
            
         $ErrorCache = $Global:Error.Clone()
         $Global:Error.Clear()
            
         $output = $steppablePipeline.End()
         #Write-Host '$results = $results -and (([string]::IsNullOrEmpty($output)) -or ($output -is [bool] -and $output))' -fore magenta
         #Write-Host "$results = $results -and (([string]::IsNullOrEmpty($output)) -or ($($output.GetType()) -is [bool] -and $($output -join ', ') -notcontains False))" -foreground magenta -NoNewLine
         $results = $results -and (([string]::IsNullOrEmpty($output)) -or (@($output)[0] -is [bool] -and (@($output) -notcontains $false)))
         #Write-Host "`t`t[$results]" -fore magenta
         
            
         if($Global:Error.Count -gt 0) {
            $FailMessage = $Global:Error.Clone()
            Write-Warning "$name is FALSE - Got Errors in Assert step!`n$FailMessage"
            $results = $false
         }
         $Global:Error.InsertRange( $Global:Error.Count, $ErrorCache )    
            
      } catch {
         $FailMessage = $_
         Write-Warning "$name is FALSE - threw exception in Assert step!`n$FailMessage"
         $results = $false
      }
      
      try {
         $output = &$PSaintTestTeardownScript
         $results = $results -and (([string]::IsNullOrEmpty($output)) -or (@($output)[0] -is [bool] -and (@($output) -notcontains $false)))
         $resultMessage = $(if($results) { "Pass" } else { "Fail" })
      } catch {
         Write-Warning "$name is FALSE - threw $_ in Test Teardown Script!"
         $FailMessage = $_
         $resultMessage = $(if($results) { "Teardown Fail" } else { "Fail" })
      }
      
      New-Object PSObject -Property @{ Result = $resultMessage; Name = $name; Category = $Category; FailMessage = $FailMessage } | ForEach-Object { $_.PSTypeNames.Insert(0,"PSaint.TestResult"); $_ }
      Write-Verbose "Exit Assert for $Name"   

   }
}

function Set-TestFilter {
   <#
      .Synopsis
         Set filters (include and/or exclude) for the tests
      .Parameter Category
         A list of categories to include in testing
      .Parameter ExcludeCategory
         A list of categories to exclude from testing (overrides the include rules from the Category parameter)
      .Parameter Name
         A list of names to include in testing (supports wildcards)
      .Parameter ExcludeName
         A list of names to exclude from testing (overrides the include rules from the Name parameter)
   #>
   param(
      [String[]]$Category,

      [String[]]$Name,

      [String[]]$ExcludeCategory,

      [String[]]$ExcludeName
   )
   end {
      $PSaintCategoryFilter = $Category
      $PSaintExcludeCategoryFilter = $ExcludeCategory
      $PSaintNameFilter = $Name
      $PSaintExcludeNameFilter = $ExcludeName
   }
}

function Set-TestSetup {
   <#
      .Synopsis
         Sets the Test Setup script that will be run before each test
      .Parameter SetupScript
         The Test Setup script block
   #>
   [CmdletBinding()]
   param([ScriptBlock]$SetupScript)
   end { 
      $Script:PSaintTestSetupScript = $SetupScript 
   }
}

function Set-TestTeardown {
   <#
      .Synopsis
         Sets the Test Teardown script that will be run after each test
      .Parameter TeardownScript
         The Test Teardown script block
   #>
   [CmdletBinding()]
   param([ScriptBlock]$TeardownScript)
   end { 
      $Script:PSaintTestTeardownScript = $TeardownScript 
   }
}

function Assert-That {
   <#
      .Synopsis
         Assert something about an object or the output of a scriptblock and throw otherwise.
      .Description
         This is the core of the PSaint functionality
        
   #>
   [CmdletBinding(DefaultParameterSetName="ScriptCondition")]
   param(
      # The Process ScriptBlock to test with 
      # Performs an operation against each item in a collection of input objects, like ForEach-Object
      [Parameter(Mandatory=$true, Position=0, ParameterSetName="ScriptCondition")]
      [Parameter(Position=0, ParameterSetName="PipelineScript")]
      $Process = { $_ },

      # Object(s) to be tested 
      [Parameter(Mandatory=$true, ParameterSetName="PipelineScript", ValueFromPipeline=$true)]
      [AllowNull()]
      [AllowEmptyString()]
      [AllowEmptyCollection()]
      [Object]$InputObject,

      # Assert that the outcome must be null or empty
      [Parameter()]
      [Switch]$IsNullOrEmpty,

      # Assert that the outcome must be null
      [Parameter()]      
      [Switch]$IsNull,

      # Reverses the outcome of the test (always evaluated last)
      [Parameter()]
      [Switch]$IsFalse,

      # [Switch]$Passthru,

      # An exception or message to be thrown if the assertion fails
      [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
      [Alias("Message")]
      [string]$FailMessage = { "Failed: { $Process } returned false" },

      # Any exceptions that are expected. The test will fail if any exceptions are thrown that are NOT listed here, and will also fail if at least one of the exceptions listed here is NOT thrown.
      [Parameter()]
      $Throws

   )
   process {
      $EAP = $Global:ErrorActionPreference
         
      $ErrorCache = $Global:Error.Clone()
      $Global:Error.Clear()
         
      try {
         $Global:ErrorActionPreference = "Stop"

         ForEach-Object $Process -InputObject $InputObject | ForEach-Object {
            if(
               $(if($IsNullOrEmpty) { [String]::IsNullOrEmpty($_) } else { $true }) -and
               $(if($IsNull) { $_ -eq $null } else { $true }) -and
               $(if(!$IsNullOrEmpty -and !$IsNull) { [bool]$_ } else { $true })
            ) {
               $IsTrue = $true
            } else {
               $IsTrue = $false
            }
         }

         $IsTrue = $(if($IsFalse) { !$IsTrue } else { $IsTrue })
         if($Passthru -and $IsTrue) { $InputObject }

         $Global:ErrorActionPreference = $EAP
         
         if(!$IsTrue) {
            $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord (New-Object System.Exception $FailMessage), "Condition Evaluated False", "InvalidResult", $IsTrue) )
         } 

         if($Global:Error.Count -gt 0) {
            $UnThrownErrors = @($Global:Error)
            $Global:Error.Clear()

            $IsTrue = $( foreach($e in $UnThrownErrors) { handleError $e $Throws } ) -notcontains $False
         } elseif($Throws) {
            # If we reach this point and we were expecting an exception, 
            # Then throw one, because we didn't get one...
            throw "Expected exception '$Throws' not thrown"
         }

      } catch { 
         Write-Warning "Caught $_"
         $Global:ErrorActionPreference = $EAP
         $IsTrue = handleError $_ $Throws
         if($IsTrue){ $Global:Error.Clear() }
      }
      $Global:Error.InsertRange( $Global:Error.Count, $ErrorCache )    

      if(!$Passthru) { $IsTrue }
   }
}


function handleError {
   param($exception, $expected)
   
   $IsExpected = $false

   if($expected -ne $null) {
      if($exception -is [System.Management.Automation.ErrorRecord]) {
         $exception = $exception.Exception
      }
      
      switch(@($expected)) {
         # { $true } { Write-host $_ -fore cyan }
         { $_ -as [Type] } {
            $type = $_ -as [Type]
            if( ($exception -is $type) -or 
                ($exception.InnerException -is $type) -or 
                ($exception.GetBaseException() -is $type) 
               ) { $IsExpected = $true; break; }
         }
         { $_ -isnot [Type] } {
            if( ($Exception.Message -eq $_) -or
                ($Exception.GetType().FullName -eq $_) -or
                ($Exception.GetType().FullName -like "*$_") 
               ) { $IsExpected = $true; break; }
         }
      }

      if(!$IsExpected) { 
         Write-Verbose "Unexpected Exception Thrown: `n$($exception|out-string)`nEXPECTED:`n$expected"
         $PSCmdlet.WriteError( (New-Object System.Management.Automation.ErrorRecord $exception, "Unexpected Exception", "InvalidResult", $_) )
      } else {
         Write-Verbose "Expected Exception Thrown: `n$($exception|out-string)"
      }
   }
   return $IsExpected
}






function Assert-PropertyEqual {
   [CmdletBinding()]
   param(
       [Parameter(Mandatory=$true, Position=0)]
       [AllowEmptyCollection()]
       [System.Management.Automation.PSObject[]]
       ${ReferenceObject},

       [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
       [AllowEmptyCollection()]
       [System.Management.Automation.PSObject[]]
       ${DifferenceObject},

       [Parameter(Mandatory=$false, Position=2, ValueFromPipelineByPropertyName=$true)]
       [String[]]
       ${Property} = @("*"),

       [ValidateRange(0, 2147483647)]
       [System.Int32]
       ${SyncWindow},

       [System.String]
       ${Culture},

       [Switch]
       ${CaseSensitive}
   )

   begin
   {
      $outBuffer = $null
      if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
      {
         $PSBoundParameters['OutBuffer'] = 1
      }
      
      $PSBoundParameters['Property'] = [string[]]@( Get-Member -InputObject @($ReferenceObject)[0] -Type Properties | 
                                                     Select -Expand Name | 
                                                     Where { @(foreach ( $pat in $Property ) { $_ -like $pat }) -contains $true } 
                                                   )
      
      $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Compare-Object', [System.Management.Automation.CommandTypes]::Cmdlet)
      $scriptCmd = {& $wrappedCmd @PSBoundParameters | Tee-Object -Variable Script:TestOutput}
      $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
      $steppablePipeline.Begin($PSCmdlet) 
      if($TestOutput -ne $null) {
         Write-Warning "Objects are different`n$($TestOutput | Out-String)`n$((Get-PSCallStack ) | Out-String)"
         Remove-Item Variable:TestOutput
      }
      $TestOutput
   }

   process
   {
      try {
         if($_) {        
            $steppablePipeline.Process($_)
         } else {
            $steppablePipeline.Process()
         }
         if($TestOutput -ne $null) {
            Write-Warning "Objects are different`n$($TestOutput | Out-String)`n$(Get-PSCallStack | Where {`$_.Command -match 'Test(-Code)?'} | Select -Expand Arguments | Out-String)"
            Remove-Item Variable:TestOutput
         }
      } catch {
         throw
      }
   }

   end
   {
      try {
         $steppablePipeline.End()
         if($TestOutput -ne $null) {
            Write-Warning "Objects are different`n$($TestOutput | Out-String)`n $(Get-PSCallStack | Where {$_.Command -match 'Test(-Code)?'} | %{ $_.Arguments } | Out-String)"
            Remove-Item Variable:TestOutput
         }
      } catch {
         throw
      }
   }
   <#
      .ForwardHelpTargetName Compare-Object
      .ForwardHelpCategory Cmdlet
   #>
}

[ScriptBlock]$PSaintTestSetupScript = {}
[ScriptBlock]$PSaintTestTeardownScript = {}

[String[]]$PSaintCategoryFilter = @("*")
[String[]]$PSaintExcludeCategoryFilter = @()
[String[]]$PSaintNameFilter = @("*")
[String[]]$PSaintExcludeNameFilter = @()


Set-Alias Test Test-Code
Set-Alias Setup Set-TestSetup
Set-Alias Teardown Set-TestTeardown
Set-Alias Must Assert-That

Export-ModuleMember -Function *-* -Alias *