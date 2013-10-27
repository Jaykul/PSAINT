& "$(Split-Path $MyInvocation.MyCommand.Path)\New-Struct.ps1"

############################################################
############################################################
### UNIT TESTS using PSaint ################################

Import-Module Reflection, PSaint 

test "Simple Struct with Function Constructor" {
arrange {
    New-Struct Song1 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
        [DateTime]$ReleaseDate
    } -CreateConstructorFunction # -Verbose
}
act {
    $song = New-Song1 -Artist "Steven Curtis Chapman" -Name "Broken" -Album "Early" -Length "3:57" -Release "1/5/2006"
}
assert {
    $song.Artist -eq "Steven Curtis Chapman"
    $song.Name -eq "Broken"
    $song.Album -eq "Early"
    $song.Length -eq ([TimeSpan]"3:57")
}} -Category Single, Function


test "Simple Struct with Constructor Parameter Order " {
arrange {
    New-Struct Song2 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
    }
}
act {
    $song = New-Object Song2 "Steven Curtis Chapman","Broken","Early","3:57"
}
assert {
    $song.Artist -eq "Steven Curtis Chapman"
    $song.Name -eq "Broken"
    $song.Album -eq "Early"
    $song.Length -eq ([TimeSpan]"3:57")
}} -Category Single, Constructor


test "Simple Struct with Function Constructor Parameter Order" {
arrange {
    New-Struct Song3 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
    } -CreateConstructorFunction
}
act {
    $song = New-Song3 "Steven Curtis Chapman" "Broken" "Early" "3:57"
}
assert {
    $song.Artist -eq "Steven Curtis Chapman"
    $song.Name -eq "Broken"
    $song.Album -eq "Early"
    $song.Length -eq ([TimeSpan]"3:57")
}} -Category Single, Function


test "Simple Struct WITHOUT Function Constructor" {
arrange {
    Assert-That -Condition {Get-Command New-Song4} -Throws CommandNotFoundException
}
act {
    New-Struct Song4 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
    }
}
assert {
    Assert-That -Condition {Get-Command New-Song4} -Throws CommandNotFoundException
}} -Category Single, Function # -Verbose


test "Simple Struct Constructor Equivalence" {
arrange {
    New-Struct Song5 { [string]$Artist; [string]$Name; [string]$Album; [TimeSpan]$Length } -CreateConstructorFunction
}
act {
    $song1 = New-Object Song5 "Steven Curtis Chapman","Broken","Early","3:57"
    $song2 = New-Song5 "Steven Curtis Chapman" "Broken" "Early" "3:57"
}
assert {
    $song1.Artist -eq $song2.Artist 
    $song1.Name   -eq $song2.Name   
    $song1.Album  -eq $song2.Album  
    $song1.Length -eq $song2.Length 
}} -Category Single, Constructor, Function


test "Interdependent Struct Types" {
arrange {
    New-Struct @{
        Product  = { [string]$Name; [double]$Price; }
        Order    = { [Guid]$Id; [Product]$Product; [int]$Quantity }
        Customer = { [string]$FirstName; [string]$LastName; [int]$Age; [Order[]]$OrderHistory }
    } -CreateConstructorFunction
}
act {
    $cd = New-Product "Early (CD)" 17.99
    $song = New-Product "Broken (Single)" 0.99
    $cust1 = New-Customer Joel Bennett 42
    $order = New-Order ([Guid]::NewGuid()) $cd 3
    $cust1.OrderHistory += $order
    $order = New-Order ([Guid]::NewGuid()) $song 1
    $cust1.OrderHistory += $order
}
assert {
    # A few random things to show it's all put together right (assuming all other tests pass)
    $cust1.FirstName -eq "Joel"
    $cust1.LastName -eq "Bennett"
    $cust1.OrderHistory.Count -eq 2
    $cust1.OrderHistory[0].Quantity -eq 3
    $cust1.OrderHistory[0].Product.Name -eq "Early (CD)"
    $cust1.OrderHistory[1].Product.Name -eq "Broken (Single)"
    
}} -Category Multiple, Constructor


test "Simple Struct Hashtable Cast Operator" {
arrange {
    New-Struct Song6 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
    }
}
act {
    [Song6]$song = @{Artist="Steven Curtis Chapman"}
}
assert {
   $song.Artist -eq "Steven Curtis Chapman"
}} -Category Single, Cast


test "Simple Struct PSObject Cast Operator" {
arrange {
    New-Struct Song7 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
        [DateTime]$ReleaseDate
    }
    New-Struct Song8 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
        [DateTime]$ReleaseDate
    }
    
    function Test-Cast {
      param([Song8]$copy, [Song7]$original) 
      $original.Artist      -eq $copy.Artist 
      $original.Name        -eq $copy.Name   
      $original.Album       -eq $copy.Album  
      $original.Length      -eq $copy.Length       
      $original.ReleaseDate -eq $copy.ReleaseDate       
    }
}
act {
    $song1 = New-Object Song7 "Steven Curtis Chapman","Broken","Early","3:57","1/5/2006"
    $song2 = @{
       Artist      = "Steven Curtis Chapman"
       Name        = "Broken" 
       Album       = "Early" 
       Length      = [TimeSpan]"3:57"      # Note: the strong-typing here is required ...
       ReleaseDate = [DateTime]"1/5/2006"
    }
    $song3 = New-Object PSObject -Property $song2
}
assert {
    Test-Cast ($song1 | select *) $song1
    Test-Cast $song3 $song3
    Test-Cast $song3 $song2
    Test-Cast $song2 $song2
    Test-Cast $song2 $song3
}} -Category Single, Cast


test "Simple Struct RoundTrip ToString" {
arrange {
    New-Struct Song9 { 
        [string]$Artist
        [string]$Name
        [string]$Album
        [TimeSpan]$Length
        [DateTime]$ReleaseDate
    } -CreateConstructorFunction
}
act {
    $song = New-Song9 "Steven Curtis Chapman" "Broken" "Early" "3:57" "1/5/2006"
}
assert {
    [Song9]$song2 = iex $song.ToString()
    Compare-Object $song $song2 -IncludeEqual -Property Album, Name, Artist, Length, ReleaseDate
}} -Category Single, ToString, Cast
