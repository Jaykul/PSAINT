PSAINT is PowerShell's Arrange, Act, Assert In Test

The primary goal pf PSAINT is to make testing PowerShell code easier. We do so by formalizing the the standard Arrange, Act, Assert syntax within PowerShell, and by creating testing functions and extension methods which are *as easy to use in PowerShell as possible,* with a native PowerShell syntax and feel.

This means that although we like BDD and Gherkin, we are choosing to prioritize "PowerShellyness" over other functionality, because that's what I think is most missing. 

NOTE: The concepts behind the gherkin given-when-then are functionally the idea of arrange-act-assert. Gherkin is essentially a formalized "grammar" and has been localized to many spoken languages. That is: the given clause is the arrange step, the when clause is the act step, and the then clause is the assert step.  We are not, at this time, providing a Gherkin mapping from scearios and given/when/then in "business readable" spoken languages to test code (although I'd like to do that later).


Perhaps an example.  Given a simple function:

    function Get-Multiplied {
       return $args[0] * $args[1]
    }


The simplest possible tests could be written like this:

    test "Get-Multiplied multiplies positive numbers correctly" {
      Get-Multiplied 10 * 50 | Must -eq 500
    }


## Arrange, Act, Assert is the standard unit-test format ...
## You may, if you wish, simply write a linear test function, treating the scriptblock as you would any other PowerShell ScriptBlock
test Get-Multiplied {
   arrange {
      $x = 10
      $y = 31
      $expectedTotal = $x * $y
   }
   act{
      $result = Get-Multiplied $x $y
   }
   assert {
      $result.MustEqual($total)
   }
}

 Some things to notice:
 1. arrange, act, assert is a formalization of the common test pattern -- we implement this by replacing them with begin/process/end ;)
 2. MustEqual is one of several extension methods on all objects: MustEqual( $expected ), MustNotEqual( $UnExpected ), MustBeTrue(), MustBeFalse(), MustBeA( $type )

 TODO: Design an example of a data-driven test which uses param([Parameter(ValueFromPipelineByPropertyName=$true)]) and pipes input to | test
