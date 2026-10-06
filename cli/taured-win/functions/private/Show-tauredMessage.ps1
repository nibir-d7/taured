function Show-tauredMessage {
    <#
    .SYNOPSIS
        Shows a taured message box and returns the selected result.

    .DESCRIPTION
        Message boxes need the interface thread, so this marshals onto it and can therefore be
        called from a job body as well as from an event handler. Every prompt is also written to
        the session log so the log shows what the user was asked and not just what happened next.

        With no window there is nobody to click, so nothing is shown. A modal put up in that
        state never returns and takes the worker with it.
    #>
    param (
        [string]$Message,
        [string]$Title = "taured",
        $Button = "OK",
        $Icon = "Information"
    )

    Write-tauredLog -Component "Dialog" -Message "$Title : $($Message -replace '\r?\n', ' ')"

    if (-not (Test-tauredUIAlive)) {
        # Anything with a choice is answered with the one that does not go ahead, so a prompt
        # nobody saw can never stand in for consent
        $unattended = if ("$Button" -eq "OK") { "OK" } else { "No" }
        Write-tauredLog -Level "WARN" -Component "Dialog" -Message "No window to ask on, answering '$unattended' for: $Title"
        return $unattended
    }

    return Invoke-WPFUIThread -PassThru -Parameters @{
        Message = $Message
        Title = $Title
        Button = $Button
        Icon = $Icon
    } -ScriptBlock {
        param($Message, $Title, $Button, $Icon)

        [System.Windows.MessageBox]::Show($Message, $Title, $Button, $Icon)
    }
}
