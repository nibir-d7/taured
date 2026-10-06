function Invoke-WPFOOSU {
    Start-tauredJob -Name "OOSU" -Description "Downloading O&O ShutUp10++" -Parameters @{
        DownloadPath = Join-Path $sync.taureddir "ooshutup10.exe"
    } -ScriptBlock {
        param($DownloadPath)

        Write-tauredLog -Component "OOSU" -Message "Downloading O&O ShutUp10++."

        Save-tauredFile -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -DestinationPath $DownloadPath -ProgressCallback {
            param($percent)
            Step-tauredJob -Status "Downloading O&O ShutUp10++ ($percent%)" -Percent $percent
        }

        Step-tauredJob -Status "Launching O&O ShutUp10++" -Percent 100
        Start-Process -FilePath $DownloadPath
        Write-tauredLog -Component "OOSU" -Message "O&O ShutUp10++ launched."
    }
}
