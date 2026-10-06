function Invoke-WPFundoall {
    <#

    .SYNOPSIS
        Undoes every selected tweak

    #>

    $tweaks = $sync.selectedTweaks

    if ($tweaks.count -eq 0) {
        Show-tauredMessage -Message "Please check the tweaks you wish to undo." -Title "taured" -Button "OK" -Icon "Warning"
        return
    }

    Start-tauredJob -Name "Undo tweaks" -Description "Undoing tweaks" -Parameters @{
        Tweaks = @($tweaks)
    } -ScriptBlock {
        param($Tweaks)

        $total = @($Tweaks).Count
        Write-tauredLog -Component "Tweaks" -Message "Undo tweaks requested: $total selected tweak(s)."

        for ($i = 0; $i -lt $total; $i++) {
            Step-tauredJob -Status "Undoing $($Tweaks[$i]) ($($i + 1)/$total)" -Percent ([int](($i / $total) * 100))
            Measure-tauredStep -Scope "Undo tweaks" -Name $Tweaks[$i] -ScriptBlock {
                Invoke-tauredtweaks $Tweaks[$i] -undo $true
            }
            Step-tauredJob -Percent ([int]((($i + 1) / $total) * 100))
        }
    }
}
