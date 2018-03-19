﻿Function Watch-Command {
    <#
        .SYNOPSIS
            Runs a scriptblock or the preceeding pipeline repeatedly until there is change.

        .DESCRIPTION
            The Watch-Command cmdlet runs a specified scriptblock repeatedly at the specified interval (or
            every 1 second by default) and returns the result of the scriptblock when the output has changed.
            For the command to work the specified scriptblock must return a result to the pipeline.

        .PARAMETER ScriptBlock
            The scriptblock to execute, specified via curly braces. If you provide input via the pipleine that
            isn't a scriptblock then the entire invocation line that preceeded the cmdlet will be used as the
            scriptblock input.

        .PARAMETER Seconds
            Number of seconds to wait between checks. Default = 1

        .PARAMETER Difference
            Switch: Use to only output items in the collection that have changed
            dditions or modifications).

        .PARAMETER Continuous
            Switch: Run continuously (even after a change has occurred) until exited with CTRL+C.
        
        .PARAMETER AsString
            Switch: Converts the result of the scriptblock into an array of strings for comparison.
        
        .PARAMETER Property
            Manually specify one or more property names to be used for comparison. If not specified,
            the default display property set is used. If there is not a default display property set,
            all properties are used.

        .EXAMPLE
            Watch-Command -ScriptBlock { Get-Process }

        .EXAMPLE
            Get-Service | Watch-Command -Diff -Cont

        .EXAMPLE
            Watch-Command { Get-Content test.txt } -Difference -Verbose

        .EXAMPLE
            Get-ChildItem | Watch-Command -Difference -AsString

        .EXAMPLE
            Get-Process | Watch-Command -Difference -Property processname,id -Continuous
    #>      
    [cmdletbinding()]
    Param(
        [parameter(ValueFromPipeline,Mandatory)]
        $ScriptBlock,

        [int]
        $Seconds = 1,

        [switch]
        $Difference,

        [switch]
        $Continuous,

        [switch]
        $AsString,

        [string[]]
        $Property
    )
 
    if ($ScriptBlock -isnot [scriptblock])
    {
        if ($MyInvocation.PipelinePosition -gt 1)
        {        
            $ScriptBlock = [Scriptblock]::Create( ($MyInvocation.Line -Split "\|\s*$($MyInvocation.InvocationName)")[0] )
        }
        else
        {
            Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
        }
    }
       
    Write-Verbose "Started watching $($ScriptBlock | Out-String)"
     
    $FirstResult = Invoke-Command $ScriptBlock
    
    if ($AsString) { $FirstResult = $FirstResult | Out-String -Stream }

    if (-not $Property) 
    {
        $Property = ($FirstResult | Select-Object -First 1).PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
        
        if (-not $Property)
        {
            $Property = ($FirstResult | Select-Object -First 1).PSObject.Properties.Name
        }
    }

    Write-Verbose "Properties: $($Property -Join ',')"

    do 
    { 
        do
        {
            if ($Result)
            { 
                Start-Sleep $Seconds
            }

            $Result = Invoke-Command $ScriptBlock

            $CompareParams = @{
                ReferenceObject  = @($FirstResult | Select-Object)
                DifferenceObject = @($Result | Select-Object)
            }

            if (-not $AsString)
            { 
                $CompareParams.Add('Property',$Property)
            }
            
            $Diff = Compare-Object @CompareParams -PassThru
        } 
        until ($Diff)
        
        Write-Verbose "Change occurred at $(Get-Date)"
        
        if ($Difference) 
        { 
            $Diff | Where-Object {$_.SideIndicator -eq '=>'}
        }
        else 
        {
            $Result
        }
        
        $FirstResult = $Result

    }
    until (-not $Continuous)
}