function Start-tauredAssetRendering {
    <#
        .SYNOPSIS
            Renders the taskbar overlay bitmaps on a thread of their own

        .DESCRIPTION
            Rasterising the overlays costs the interface thread time it could spend getting the
            window up. The bitmaps are frozen before publication, so they can be built anywhere.

            Nothing waits on this: if the render has not finished when an overlay is asked for,
            Set-tauredTaskbaritem renders it in place.

            Needs STA for RenderTargetBitmap, which the shared worker pool is not.
    #>

    $runspace = [runspacefactory]::CreateRunspace((New-tauredSessionState))
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()

    $shell = [powershell]::Create()
    $shell.Runspace = $runspace
    [void]$shell.AddScript({
        # A new runspace does not inherit assemblies loaded by the interface runspace. On a cold
        # process these types otherwise fail before the off-thread render can do any work.
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName PresentationFramework

        Measure-tauredStep -Scope "UI" -Name "render taskbar overlays (off thread)" -ScriptBlock {
            Initialize-tauredTaskbarOverlayAssets -IncludeLogo $true -IncludeStatusAssets $true
        }
    })

    $handle = $shell.BeginInvoke()

    Register-tauredRunspaceCleanup -PowerShell $shell -Handle $handle -Runspace $runspace

    return $handle
}
