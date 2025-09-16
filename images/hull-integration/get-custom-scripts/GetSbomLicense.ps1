# Set variables
$licenseDirectory = "/oci_license"
$downloadDirectory = "$($licenseDirectory)/download"
$docDirectory = "$($licenseDirectory)/extracted"
$errorMessage = ""

# Log in to OCI
if ([String]::IsNullOrWhitespace($entity._oci_endpoint_.server))
{
  $errorMessage = "~~~ SBOM: Did not find OCI registry server name, you may need to configure a registry object for this chart!"
  $this.WriteError($errorMessage)
  return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
}
$this.WriteLog("~~~ SBOM: Logging in to $($entity._oci_endpoint_.server)")
oras login $entity._oci_endpoint_.server --username $entity._oci_endpoint_.username --password $entity._oci_endpoint_.password
$this.WriteLog("~~~ SBOM: Logged in to $($entity._oci_endpoint_.server)")

foreach($chartInfo in $entity._helm_charts_) 
{
  # Get artifacts
  $this.WriteLog("~~~ SBOM: ---> Processing License for Helm Chart $($chartInfo.name) and Version $($chartInfo.version)")
  $rootArtifact = "$($entity._oci_endpoint_.server)/helm-charts/vpms/$($chartInfo.name):$($chartInfo.version)"
  $this.WriteLog("~~~ SBOM: Getting related artifact $($rootArtifact)")
  $discoverCommand = "oras discover --format json --artifact-type 'mend/sbom' $($rootArtifact)"
  $discover = (oras discover --format json --artifact-type 'mend/sbom' $($rootArtifact)) -join "`n"
  $discoverExitCode = $LASTEXITCODE
  $this.WriteLog("~~~ SBOM: oras discover - Exit Code: $($discoverExitCode)")

  if ($discoverExitCode -eq 0)
  {
    # Found artifacts
    $discoverJson = ($discover | ConvertFrom-Json)
    $this.WriteLog("~~~ SBOM: $($discoverCommand) successful:")                              
    $this.WriteLog("~~~ SBOM: $($discoverJson)")
    
    if (-not [bool]$discoverJson.PSObject.Properties['referrers'])
    {
      $errorMessage = "~~~ SBOM: Referrers field for $($rootArtifact) does not exist! Skipping license upload ..."
      $this.WriteError($errorMessage)
      return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
    }

    if (($discoverJson.referrers | Measure-Object).Count -eq 0)
    {
      $errorMessage = "~~~ SBOM: Referrers field for $($rootArtifact) has zero elements! Skipping license upload ..."
      $this.WriteError($errorMessage)
      return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json                                
    }
    else
    {
      if (($discoverJson.referrers | Measure-Object ).Count -gt 1)
      {
        $errorMessage = "~~~ SBOM: Referrers field for $($rootArtifact) has more than one element! Only considering first element ..."
        $this.WriteError($errorMessage)
        return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
      }

      # Download Artifacts
      New-Item -ItemType Directory -Path $downloadDirectory
      $pullCommand = "oras pull -o $downloadDirectory $rootArtifact@$($discoverJson.referrers[0].digest)"
      $pull = (oras pull -o $downloadDirectory $rootArtifact@$($discoverJson.referrers[0].digest)) -join "`n"
      $pullExitCode = $LASTEXITCODE
      $this.WriteLog("~~~ SBOM: oras pull Exit Code: $($pullExitCode)")

      if ($pullExitCode -eq 0)
      {
        # Pulled artifacts to download directory
        $this.WriteLog("~~~ SBOM: $($pullCommand) successful:")
        $this.WriteLog("~~~ SBOM: $($pull)")
      }
      else
      {
        $errorMessage = "~~~ SBOM: $($pullCommand) failed!"
        $this.WriteError($errorMessage)
        return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
      }
    }
  }
  else
  {
    $errorMessage = "~~~ SBOM: $($discoverCommand) failed!"
    $this.WriteError($errorMessage)
    return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
  }

  # Iterate over downloaded files
  Get-ChildItem $downloadDirectory | Foreach-Object {

    # Check file
    $tgzFile = $_
    $this.WriteLog("~~~ SBOM: checking downloaded file $($tgzFile.Name)")
    $component = $chartInfo.name
    $subcomponent = $tgzFile.Name -Match "$($chartInfo.version)(.+).license.tgz"

    if ($subcomponent)
    {
      # File has a subcomponent - multiple files
      $component = "$($component).$($Matches[1])"
      $this.WriteLog("~~~ SBOM: Subcomponent found, setting component to $component")
    }
    else
    {
      $this.WriteLog("~~~ SBOM: No subcomponent found, using component $component")
    }

    # Unzip the tgz
    $this.WriteLog("~~~ SBOM: Creating directory $($docDirectory) for unzipped files")
    New-Item -ItemType Directory -Path $docDirectory
    $this.WriteLog("~~~ SBOM: Extracting files from $($tgzFile.FullName) to $($docDirectory)")
    $extract = (tar -xvzf $tgzFile.FullName -C $docDirectory 2>&1) -join "`n"
    $this.WriteLog("~~~ SBOM: Extracting tgz result:")
    $this.WriteLog("~~~ SBOM: $($extract)")

    if ((Get-ChildItem $docDirectory | Measure-Object ).Count -eq 1)
    {
      # Expect single unzipped file
      $docFile = Get-ChildItem -Path $docDirectory -Force -File | Select-Object -First 1

      if ($docFile.Name -imatch '\.html$')
      {
        # Single file must be HTML
        $this.WriteLog("~~~ SBOM: Found expected single HTML file $($docFile.Name) in $docDirectory")
        $this.WriteLog("~~~ SBOM: Base64 encode $($docFile.Name)")
        $extractedFileContent = Get-Content -Path $docFile.FullName
        $encodedText =[Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($extractedFileContent))

        $this.WriteLog("~~~ SBOM: Checking if component $($component) for file $($docFile.Name) already exists in ConfigPortal")
        $foundGuid = ""
        $productcomponents = $responseGet | ConvertFrom-Json
        $this.WriteLog("~~~ SBOM: GET Response was '$($productcomponents)'")

        foreach($existingComponent in $productcomponents.Result)
        {
          if ($existingComponent.Name -iMatch $component)
          {
            $this.WriteLog("~~~ SBOM: Component $($component) already found in ConfigPortal, use PUT")
            $foundGuid = $existingComponent.Guid
          }
          else
          {
            $this.WriteLog("~~~ SBOM: Existing ProductComponent name '$($existingComponent.Name)' does not match component name: '$($component)'")
          }
        }

        # Create document body
        $document = @{
          Name = $component;
          Version = $chartInfo.version;
          License = $encodedText;
          LicenseType = "text/html"
        }
        $body = $document | ConvertTo-Json -Depth 20

        if ([String]::IsNullOrEmpty($foundGuid))
        {
          # Caluclate new GUID from component name
          $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
          $utf8 = New-Object -TypeName System.Text.UTF8Encoding
          $hashGuid = [Guid]::New($md5.ComputeHash($utf8.GetBytes($component)))

          $document.ProductGuid = $hashGuid
          $document.Guid = $hashGuid

          $this.WriteLog("~~~ SBOM: POSTing component $($component)")
          $this.InvokeWebRequest($apiEndpoint, "POST", ($document | ConvertTo-Json -Depth 20), $headers)
        }
        else
        {
          $document.ProductGuid = $foundGuid
          $document.Guid = $foundGuid

          $this.WriteLog("~~~ SBOM: PUTing $($component) with existing Guid $($foundGuid)")
          $this.InvokeWebRequest("$($apiEndpoint)/$($foundGuid)", "PUT", ($document | ConvertTo-Json -Depth 20), $headers)
        }
      }
      else
      {
        $errorMessage = "~~~ SBOM: Single extracted file '$($docFile)' is not an html file!"
        $this.WriteError($errorMessage)
        return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
      }
    }
    else
    {
      $errorMessage = "~~~ SBOM: More than one file extracted from $($tgzFile.Name)!"
      $this.WriteError($errorMessage)
      return @{ "statusCode" = 500; "errorMessage" = $errorMessage } | ConvertTo-Json
    }

    $this.WriteLog("~~~ SBOM: Deleting document directory $($docDirectory)")
    Remove-Item -Recurse -Path $docDirectory
  }

  $this.WriteLog("~~~ SBOM: Deleting download directory $($downloadDirectory)")
  Remove-Item -Recurse -Path $downloadDirectory
}


$this.WriteLog("~~~ SBOM: Done processing all components")
return @{ "statusCode" = 200 } | ConvertTo-Json