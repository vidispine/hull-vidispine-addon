<#
.SYNOPSIS
    This script performs authenticated API calls to create, update or delete objects.
.DESCRIPTION
    This should run first before product is installed to create the necessary prerequisites.
.PARAMETER ConfigFilePath
    Path to config file in YAML holding the tasks to perform
.PARAMETER Stage
    Stage of execution in overal installation, valid options are 'pre-install' and 'post-install'. Defaults to 'pre-install'.
.EXAMPLE
    C:\PS> .\Register.ps1 -ConfigFile "C:\\test.yaml"
    C:\PS> .\Register.ps1 -ConfigFile "C:\\test.yaml" -Stage "post-install"
#>
Param(
  [string]$ConfigFilePath,
  [string]$Stage = 'pre-install'
)
Import-Module powershell-yaml

function CreateKubernetesEvent([PSCustomObject] $k8s, [string] $eventType, [string] $objectName, [string] $objectType, [string] $objectApiVersion, [string] $objectUid, [string] $objectResourceVersion, [string] $message)
{
  $now = Get-Date
  $eventName = "$($objectName).$($now.ToString("yyMMddhhmmssffffff"))"
  $trimmedMessage = $message[0..1023] -join ""
  $k8sEvent = @{ "apiVersion" = "v1";
    "action"                  = "$($eventType)";
    "count"                   = 1;
    "eventTime"               = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))";
    "firstTimestamp"          = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))";
    "involvedObject"          = @{
      "name"            = "$($objectName)";
      "kind"            = "$($objectType)";
      "namespace"       = "$($k8s.NAMESPACE)";
      "apiVersion"      = "$($objectApiVersion)";
      "uid"             = "$($objectUid)";
      "resourceVersion" = "$($objectResourceVersion)"
    };
    "kind"                    = "Event";
    "lastTimestamp"           = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))";
    "message"                 = "$($trimmedMessage)";
    "metadata"                = @{
      "namespace" = "$($k8s.NAMESPACE)";
      "name"      = "$($eventName)"
    };
    "reason"                  = "Installation $($eventType)";
    "reportingComponent"      = "hull-vidispine-addon";
    "reportingInstance"       = "hull-vidispine-addon";
    "source"                  = @{
      "component" = "hull-vidispine-addon";
      "host"      = "";
    };
    "type"                    = "$($eventType.ToString())";
  }
  if ($log)
  {
    $installer.WriteLog("Event: $($k8sEvent | ConvertTo-Json -Depth 100)")
  }
  $uri = "$($k8s.APISERVER)/api/v1/namespaces/$($k8s.NAMESPACE)/events"
  $installer.WriteLog("Uri: $($uri)")
  $responseEvent = Invoke-RestMethod -Uri $uri -Method "POST" -Body ($k8sEvent | ConvertTo-Json -Depth 100) -Headers $k8s.HEADERS -SkipCertificateCheck
  if ($log)
  {
    $installer.WriteLog("Event response $($responseEvent)")
  }
}

function CreateKubernetesEvents([string] $eventType, [string] $message)
{
                  
  $k8s = @{ "APISERVER" = "https://kubernetes.default.svc";
    "SERVICEACCOUNT"    = "/var/run/secrets/kubernetes.io/serviceaccount";
    "NAMESPACE"         = "$(Get-Content -Path "/var/run/secrets/kubernetes.io/serviceaccount/namespace")";
    "TOKEN"             = "$(Get-Content -Path "/var/run/secrets/kubernetes.io/serviceaccount/token")";
    "CACERT"            = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
    "HEADERS"           = @{
      "Authorization" = "Bearer $(Get-Content -Path "/var/run/secrets/kubernetes.io/serviceaccount/token")";
      "Content-Type"  = "application/json";
      "Accept"        = "application/json"
    }

  }
  #$installer.WriteLog("APISERVER=$($APISERVER)\nSERVICEACCOUNT=$($SERVICEACCOUNT)\nNAMESPACE=$($NAMESPACE)\nTOKEN=$($TOKEN)\nCACERT=$($CACERT)")
  # $callback = {
  #     param(
  #         $sender,
  #         [System.Security.Cryptography.X509Certificates.X509Certificate]$certificate,
  #         [System.Security.Cryptography.X509Certificates.X509Chain]$chain,
  #         [System.Net.Security.SslPolicyErrors]$sslPolicyErrors
  #     )
  #     $installer.WriteLog("Start cert callback")
  #     # No need to retype this long type name
  #     $CertificateType = [System.Security.Cryptography.X509Certificates.X509Certificate2]

  #     $installer.WriteLog("-1")
  #     # Read the CA cert from file
  #     $CACert = $CertificateType::CreateFromCertFile("$($SERVICEACCOUNT)/ca.crt") -as $CertificateType

  #     $installer.WriteLog("-2")
  #     # Add the CA cert from the file to the ExtraStore on the Chain object
  #     $null = $chain.ChainPolicy.ExtraStore.Add($CACert)

  #     $installer.WriteLog("-3")
  #     # return the result of chain validation
  #     return $chain.Build($certificate)
  # }

  # # Assign your delegate to the ServicePointManager callback
  # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $callback

  #curl.exe --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api

  # get pod
  $podName = [System.Environment]::GetEnvironmentVariable("HOSTNAME")
  $podUri = "$($k8s.APISERVER)/api/v1/namespaces/$($k8s.NAMESPACE)/pods/$($podName)"
  $installer.WriteLog("Uri: $($podUri)")
  $installer.WriteLog("GET Pod info for $($podName)")
  $podResponse = Invoke-RestMethod -Uri $podUri -Method "GET" -Headers $k8s.HEADERS -SkipCertificateCheck
  # $installer.WriteLog("Pod: $($podResponse | ConvertTo-Json -Depth 100)")

  $jobName = $podResponse.metadata.labels.'batch.kubernetes.io/job-name'
  $jobControllerUid = $podResponse.metadata.labels.'controller-uid'
  $jobResourceVersion = "$($podResponse.metadata.resourceVersion)"
  CreateKubernetesEvent $k8s $eventType $jobName "Job" "batch/v1" $jobControllerUid $jobResourceVersion $message
                  
  $podUid = "$($podResponse.metadata.uid)"
  $podResourceVersion = "$($podResponse.metadata.resourceVersion)"
  CreateKubernetesEvent $k8s $eventType $podName "Pod" "v1" $podUid $podResourceVersion $message
                  
  # New event API is not displaying in Lens so for future use
  # 
  # $event_new = @{ "apiVersion" = "events.k8s.io/v1";
  #   "metadata" = @{
  #     "name" = "$($podResponse.metadata.name).$($now.ToString("yyMMddhhmmssffffff"))";
  #     "namespace" = "$($NAMESPACE)"
  #   };
  #   "regarding" = @{
  #     "name" = "$($jobName)";
  #     "kind" = "Job";
  #     "namespace" = "$($NAMESPACE)";
  #     "apiVersion" = "batch/v1"
  #   };
  #   "kind" = "Event";
  #   "action" = "Error";
  #   "reason" = "test";
  #   "note" = "$($message)";
  #   "type" = "$($eventType.ToString())";
  #   "reportingController" = "job-controller";
  #   "reportingInstance" = "hull-vidispine-addon";
  #   "eventTime" = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))";
  #   "series" = @{
  #     "count" = 2;
  #     "lastObservedTime" = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))"
  #   };
  # }
  # $installer.WriteLog("Event New: $($event | ConvertTo-Json -Depth 100)")
  # $responseEventNew = Invoke-RestMethod -Uri "$($APISERVER)/apis/events.k8s.io/v1/namespaces/$($NAMESPACE)/events" -Method "POST" -Body ($event | ConvertTo-Json -Depth 100) -Headers $headers -SkipCertificateCheck
  # $installer.WriteLog("POST Event response $($responseEventNew)")


  # Don't really need to set the status conditions but for reference this is how you would do it
  #
  # $condition = @( @{ "type" = "HullInstallError";
  #                   "status" = "True";
  #                   "lastProbeTime" = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))";
  #                   "lastTransitionTime" = "$($now.ToString("yyyy-MM-ddThh:mm:ss.ffffffZ"))";
  #                   "reason" = "Error";
  #                   "message" = "$($message)"
  #                 })
  #
  # $status = @{ "metadata" = @{
  #               "name" = "$($jobName)";
  #               "namespace" = "$($NAMESPACE)"
  #             };
  #              "status" = @{
  #               "conditions" = $condition
  #             }
  #           }
  # $installer.WriteLog("Status: $(ConvertTo-Json -Depth 10 -InputObject $status)")
  # $response = Invoke-RestMethod -Uri "$($APISERVER)/apis/batch/v1/namespaces/$($NAMESPACE)/jobs/$($jobName)/status" -Method "PUT" -Body ($status | ConvertTo-Json -Depth 100) -Headers $headers -SkipCertificateCheck
  # $installer.WriteLog("POST Status response $($response)")
}

function ParseErrorForResponseBody($err)
{
  try
  {
    if ($PSVersionTable.PSVersion.Major -lt 6)
    {
      if ($err.Exception.Response)
      {
        $Reader = New-Object System.IO.StreamReader($err.Exception.Response.GetResponseStream())
        $Reader.BaseStream.Position = 0
        $Reader.DiscardBufferedData()
        $ResponseBody = $Reader.ReadToEnd()
        if ($ResponseBody.StartsWith('{'))
        {
          $ResponseBody = $ResponseBody | ConvertFrom-Json
        }
        return $ResponseBody
      }
      return "<error getting body: Error.Exception.Response does not exist>"
    }
    else
    {
      return $err.ErrorDetails.Message
    }
  }
  catch
  {
    return "<error getting body: $($_.Exception.Message)"
  }
}

function Get-Node
{
  [CmdletBinding()][OutputType([Object[]])] param(
    [ScriptBlock]$Where,
    [AllowNull()][Parameter(ValueFromPipeLine = $True, Mandatory = $True)]$InputObject,
    [Int]$Depth = 10
  )
  process
  {
    if ($_ -isnot [String] -and $Depth -gt 0)
    {
      if ($_ -is [Collections.IDictionary])
      {
        if (& $Where) { $_ }
        $_.get_Values() | Get-Node -Where $Where -Depth ($Depth - 1)
      }
      elseif ($_ -is [Collections.IEnumerable])
      {
        for ($i = 0; $i -lt $_.get_Count(); $i++) { $_[$i] | Get-Node -Where $Where -Depth ($Depth - 1) }
      }
      elseif ($Nodes = $_.PSObject.Properties.Where{ $_.MemberType -eq 'NoteProperty' })
      {
        $Nodes.ForEach{
          if (& $Where) { $_ }
          $_.Value | Get-Node -Where $Where -Depth ($Depth - 1)
        }
      }
    }
  }
} 

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$installer = New-Object Installer
$installer.LoadConfiguration($ConfigFilePath, $Stage)
$installer.WriteLog("----------- Settings: ----------")
$installer.WriteLog("debug:")
$installer.WriteLog("  ignoreEntityRestCallErrors: $($installer._config.config.debug.ignoreEntityRestCallErrors)")
$installer.WriteLog("  retriesForEntityRestCall: $($installer._config.config.debug.retriesForEntityRestCall)")
$installer.WriteLog("  retriesForAuthServiceCall: $($installer.$_config.config.debug.retriesForAuthServiceCall)")
$installer.Start()
$installer.WriteLog("----------- Installer finished processing all endpoints ----------")
$installer.WriteLog("")
$installer.WriteLog("----------- Summary ----------")
if ($installer._successes)
{
  $installer.WriteLog("")
  $installer.WriteLog("----------- Successful steps ---------- ")
  foreach ($ep in $installer._successes.Keys)
  {
    $installer.WriteLog("  $($ep):")
    foreach ($sr in $installer._successes[$ep].Keys)
    {
      $installer.WriteLog("    $($sr):")
      foreach ($en in $installer._successes[$ep][$sr].Keys)
      {
        $installer.WriteLog("      $($en): $($installer._successes[$ep][$sr][$en]['lastMethod']) [$($installer._successes[$ep][$sr][$en]['lastUri'])]")
      }
    }
  }
  $installer.WriteError("-----------  Done listing successes -----------")
}
if ($installer._errors)
{
  $installer.WriteError("")
  $installer.WriteError("----------- Errors encounted but ignored due to setting 'config.ignoreAllEntityErrors=true' ----------")
  foreach ($ep in $installer._errors.Keys)
  {
    $installer.WriteError("  $($ep):")
    foreach ($sr in $installer._errors[$ep].Keys)
    {
      $installer.WriteError("    $($sr):")
      foreach ($en in $installer._errors[$ep][$sr].Keys)
      {
        $installer.WriteError("      $($en): $($installer._errors[$ep][$sr][$en]) ")
      }
    }
  }
  $installer.WriteError("-----------  Done listing errors -----------")
}

Class Installer
{
  hidden [PSCustomObject] $_config
  hidden [string] $_stage
  hidden [PSCustomObject] $_errors
  hidden [PSCustomObject] $_successes
  hidden [System.Net.CookieCollection] $_sessionCookies

  # Load the config
  [void] LoadConfiguration($ConfigFilePath, $Stage)
  {
    # Load File
    $this._config = (Get-Content $ConfigFilePath | Out-String | ConvertFrom-Yaml -Ordered)
    $this._stage = $Stage
  }


  hidden [void] WriteLog($message)
  {
    "$(get-date -format "yyyy-MM-dd HH:mm:ss"): $($message)" | Write-Host
  }

  # Override the built-in cmdlet with a custom version
  hidden [void] WriteError($message)
  {
    [Console]::ForegroundColor = 'red'
    [Console]::Error.WriteLine("$(get-date -format "yyyy-MM-dd HH:mm:ss"): $($message)")
    [Console]::ResetColor()
  }

  hidden [string] LogInvokeWebRequestError()
  {
    return $this.LogInvokeWebRequestError($null, $null)
  }

  hidden [string] LogInvokeWebRequestError($uri, $method)
  {
    $log = ""
    $message = ""
    if ($null -ne $uri)
    {
      $message = "***** ERROR $($method.ToUpper()) to service: StatusCode: $($_.Exception.Response.StatusCode.Value__)"
      $this.WriteError($message)
      $log += $message + [System.Environment]::Newline
    }
    if ($null -ne $method)
    {
      $message = "***** ERROR -> Url: '$($uri)'. $($_.Exception.ToString())"
      $this.WriteError($message)
      $log += $message + [System.Environment]::Newline
    }
    $message = "***** ERROR -> Exception Message: $($_.Exception.Message)"
    $this.WriteError($message)
    $log += $message + [System.Environment]::Newline

    if ($null -ne $_.Exception.InnerException)
    {
      $message = "****** ERROR -> Inner Exception Message: $($_.Exception.InnerException.Message)"
      $this.WriteError($message)
      $log += $message + [System.Environment]::Newline
    }
    $bodyError = ParseErrorForResponseBody($_)
    if (-Not [String]::IsNullOrWhitespace($bodyError))
    {
      $message = "***** ERROR -> Body: $($bodyError)"
      $this.WriteError($message)
      $log += $message + [System.Environment]::Newline
    }

    return $log
  }

  # Invoke-WebRequest (GET, POST, PUT, DELETE) with retries and error handling
  hidden [PSCustomObject] InvokeWebRequest(
    [string] $url,
    [string] $method,
    [string] $jsonBody,
    [PSCustomObject] $headers
  )
  {
    $retryLimit = $this._config.config.debug.retriesForEntityRestCall
    $retryCount = 1
    $response = $null

    do
    {
      try
      {
        $this.WriteLog("***** $($method.ToUpper()) content '$($jsonBody)' to '$($url)'")
        $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        if ($null -ne $this._sessionCookies)
        {
          $this.WriteLog("***** using WebSession cookie: $($this._sessionCookies[0])")
          $cookie = New-Object System.Net.Cookie($this._sessionCookies[0].Name, $this._sessionCookies[0].Value, '/')
          $webSession.Cookies.Add($url, $cookie)
          # $this._webSession.Cookies.SetCookies($url, $this._webSession.Cookies.GetCookies($this._webSessionLoginUri))
        }
        
        $response = Invoke-WebRequest -Uri $url -Method $method -Body $jsonBody -headers $headers -UseBasicParsing -SkipCertificateCheck -WebSession $webSession
        $this.AssertResponse($response)
        $this.WriteLog("***** $($method.ToUpper()) to '$($url)' was successful!")
        return $response
      }
      catch
      {

        $this.LogInvokeWebRequestError($url, $method)

        if ($retryCount -lt $retryLimit)
        {
          $this.WriteError("***** Retrying in 5 seconds.  Retry count $($retryCount) of $($retryLimit)")
          $retryCount++
          Start-Sleep 5
        }
        else
        {
          $this.WriteError("***** Failed $($method.ToUpper()) '$($url)' after $($retryLimit) attempt(s): $($_.Exception.Message)")
          throw
        }
      }
    } while ($true)

    return $response
  }

  # Gets the authorization header for either token based or basic auth
  hidden [PSCustomObject] GetHttpHeaders([PSCustomObject] $auth, [string] $contentType, [PSCustomObject] $endpointExtraHeaders = $null, [PSCustomObject] $entity = $null)
  {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"

    # Set ContentType Header always
    $headers.Add("Content-Type", $contentType)
    $headers.Add("Accept", $contentType)
    $authHeader = [String]::Empty

    $explicitAuthType = $false
    if ($null -ne $auth.type) 
    {
      $this.WriteLog("++++ Auth type is explicitly set to '$($auth.type)'")
      $explicitAuthType = $true
    }
    else
    {
      $this.WriteLog("++++ No explitit auth type is set, selecting first one defined.")
    }

    if ($null -ne $auth.session -and (-not $explicitAuthType -or ($explicitAuthType -and $auth.type -eq "session"))) 
    {
      if ($null -ne $this._sessionCookies)
      {
        $this.WriteLog("++++ Cookies for endpoint exists already")
      }
      else
      {
        $this.WriteLog("++++ Creating new Cookies for endpoint")
        $this.GetAccess($auth.session, "session")
      }
    }
    if ($null -ne $auth.token -and (-not $explicitAuthType -or ($explicitAuthType -and $auth.type -eq "token")))
    {
      $accessToken = $this.GetAccess($auth.token, "token")
      $authHeader = "Bearer $accessToken"
    }
    if ($null -ne $auth.basic -and (-not $explicitAuthType -or ($explicitAuthType -and $auth.type -eq "basic")))
    {
      $username = [environment]::GetEnvironmentVariable($auth.basic.env.username,"Process")
      $password = [environment]::GetEnvironmentVariable($auth.basic.env.password,"Process")
      $this.WriteLog("++++ Getting basic auth credentials from environment variables: username=$(if ($username -ne [String]::Empty) {$username} else {"<empty>"}) password=$(if ($password -ne [String]::Empty) {"***"} else {"<empty>"}))")
      if ([String]::IsNullOrWhitespace($username))
      {
        throw [Exception]::new("ERROR --> Basic auth environment variable '$($auth.basic.env.username)' for 'username' is empty.")
      }
      if ([String]::IsNullOrWhitespace($password))
      {
        throw [Exception]::new("ERROR --> Basic auth environment variable '$($auth.basic.env.password)' for 'password' is empty.")
      }
      $authHeader = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($username + ":" + $password)))"
      $this.WriteLog("++++ Using Basic Auth for User '$($username)'. Password is $(if ($password -ne [String]::Empty) {"not "} else {" "} )empty.")
    }

    if ($authHeader -ne [String]::Empty)
    {
      $headers.Add("Authorization", $authHeader)
      # $this.WriteLog("++++ Authorization header: $authHeader")
    }

    if ($endpointExtraHeaders )
    {
      foreach ($header in $endpointExtraHeaders.Keys)
      {
        if ($headers.ContainsKey($header))
        {
          $this.WriteLog("++++ OVerwriting Header '$($header)' with value '$($endpointExtraHeaders[$header])' from Endpoint Headers.")                              
        }
        else
        {
          $this.WriteLog("++++ Adding Header '$($header)' with value '$($endpointExtraHeaders[$header])' from Endpoint Headers.")
        }
        $headers[$header] = $endpointExtraHeaders[$header]
      }
    }

    if ($entity.extraHeaders)
    {
      foreach ($header in $entity.extraHeaders.Keys)
      {
        if ($headers.ContainsKey($header))
        {
          $this.WriteLog("++++ OVerwriting Header '$($header)' with value '$($entity.extraHeaders[$header])' from Entity Headers.")                              
        }
        else
        {
          $this.WriteLog("++++ Adding Header '$($header)' with value '$($entity.extraHeaders[$header])' from Entity Headers.")
        }

        $headers[$header] = $entity.extraHeaders[$header]

      }
    }

    return $headers
  }

  # Replace env vars in string
  hidden [string] InsertEnvironmentVariables($source)
  {
    if ([string]::IsNullOrWhitespace($source))
    {
      $this.WriteLog("+++++ Inserting environment variables not possible. Content is empty.")
      return $source
    }

    $this.WriteLog("+++++ Inserting environment variables in content of type '$($source.GetType())'")
    if ($source.GetType() -Eq [System.Collections.Specialized.OrderedDictionary])
    {
      $this.WriteLog("+++++ Converting Content from OrderedDictionary to JSON for environment variable insertion")
      $source = $source | ConvertTo-Json -Depth 100
    }
    if ($source.GetType() -Eq [System.Collections.Generic.List[System.Object]])
    {
      $this.WriteLog("+++++ Converting Content from Generic.List[System.Object] to JSON for environment variable insertion")
      $source = $source | ConvertTo-Json -Depth 100
    }

    Select-String '\$\{env:(.*)\}' -Input $source -AllMatches | ForEach-Object {
      $_.matches | ForEach-Object {
        $this.WriteLog("+++++   Inserting value for environment variable $($_.Groups[0])")
        $source = $source.replace($_.Groups[0], "$([environment]::GetEnvironmentVariable($_.Groups[1], "Process"))")
      }
    }

    return $source
  }

  # Gets an access token for the OAuth2 authentication.
  hidden [string] GetAccess([PSCustomObject] $request, [string] $accessType)
  {
    $this.WriteLog("++++ Getting $($accessType)")

    $endpointBaseUri = $request.endpoint.baseUri.Trim('/')
    $requestSubpath = ""
    
    if (-Not [String]::IsNullOrWhitespace($request.endpoint.requestSubpath))
    {
      $requestSubPath = $request.endpoint.requestSubpath
    }
    
    $endpointUri = "$($endpointBaseUri)$($requestSubPath)"
    $this.PingEndpoint($request.endpoint, "$($accessType)")

    $requestBodyJson = ($request.request.body | ConvertTo-Json -Depth 100)

    $this.WriteLog("++++ Getting $($accessType) with following body (not showing resolved env var values): ")
    $this.WriteLog("++++ $($requestBodyJson)")
    $this.WriteLog("++++ and headers: ")
    foreach ($key in $request.request.headers.Keys)
    {
      $this.WriteLog("++++   Key: $key Value: $($request.request.headers[$key])")
    }
    $this.WriteLog("++++ to Uri: $($endpointUri)")

    $requestBodyJson = $this.InsertEnvironmentVariables($requestBodyJson)

    try
    {
      $session = $null
      $body = $requestBodyJson | ConvertFrom-Json -AsHashTable
      if ($request.request.headers.Contains("Content-Type") -And ($request.request.headers["Content-Type"].Equals("application/json")))
      {
        $this.WriteLog("++++ Body submitted as JSON since Content-Type is application/json.")
        $body = $requestBodyJson
      }
      $response = Invoke-WebRequest -Uri "$($endpointUri)" -Method Post -Body $body -Headers $request.request.headers -UseBasicParsing -SkipCertificateCheck -SessionVariable session
      $this.AssertResponse($response)

      if ($accessType.Equals("session"))
      {
        $this._sessionCookies = $session.Cookies.GetCookies($endpointUri)
        $this.WriteLog("++++ Created session $($session) and stored cookie: $($session.Cookies.GetCookies($endpointUri))")
      }
      if ($accessType.Equals("token"))
      {
        if ([string]::IsNullOrWhiteSpace($request.response.tokenField))
        {
          throw [Exception]::new("The field 'tokenField' must be set in 'token.response' to lookup the retrieved token.")
        }
        else
        {
          $token = ($response | ConvertFrom-Json).($request.response.tokenField)
        }

        $this.WriteLog("++++ Got access token: $token")
        return $token
      }

      return ""
    }
    catch
    {
      throw [Exception]::new("Error getting $($accessType): $($_.Exception.ToString())")
    }
  }

  # Ping authentication service
  hidden [void] PingEndpoint([PSCustomObject] $endpoint, [string] $type)
  {
    if ([string]::IsNullOrWhiteSpace($endpoint.healthCheckSubpath))
    {
      $this.WriteLog("++++ Not health checking $($type) auth endpoint at '$($endpoint.baseUri)' because no 'healthCheckSubPath' is defined.")
      return
    }

    $retryCount = 0;
    $retryLimit = $this._config.config.debug.retriesForAuthServiceCall

    # The health check URI of Endpoint. Must not require any authentication.
    $ep = $endpoint.baseUri.Trim('/')
    $healthCheckUri = "$($ep)$($endpoint.healthCheckSubPath)"
    $this.WriteLog("++++ Pinging $($type) auth service at '$($healthCheckUri)'")

    while ($retryCount -lt $retryLimit)
    {
      try
      {
        $this.WriteLog("++++ Attempting to contact $($type) auth service. Retry count: " + $retryCount + " of " + $retryLimit)
        $response = Invoke-WebRequest -URI ($healthCheckUri) -Method Get -UseBasicParsing -SkipCertificateCheck
        if ($response.StatusCode -ge 200 -And $response.StatusCode -lt 300)
        {
          $this.WriteLog("++++ Successfully connected to $($type) auth service")
          return
        }
      }
      catch [Exception]
      {
        $this.WriteLog("**** Failed to contact $($type) auth service. " + $_.Exception.Message + "$(if ($null -ne $_.Exception.InnerException) {$_.Exception.InnerException.Message} else {''})")
      }

      $retryCount++;
      Start-Sleep -s 5
    }

    throw "Failed to contact $($type) auth service after $($retryLimit) retry/retries."
  }

  # Execute a Powershell script
  [void] ExecuteScript([string]$step, [string]$script)
  {
    # Check for custom script
    if (![String]::IsNullOrWhitespace($script))
    {
      $config = $this._config
      $this.WriteLog("** Invoking script at step '$step': $([System.Environment]::NewLine) $($script)")
      $scriptblock = [Scriptblock]::Create($script)
      $this.WriteLog("[- Start Script -]")
      & $scriptblock
      $this.WriteLog("[- End Script -]")
    }
    else
    {
      $this.WriteLog("** No scripts to invoke found for step '$step'")
    }
  }

  # Start processing
  [void] Start()
  {
    $this.WriteLog("---------- Starting all installations ----------")
    $this.ExecuteScript("pre-install", $this._config.config.preScript)
    foreach ($apiKey in $this._config.endpoints.Keys)
    {
      $value = $this._config.endpoints[$apiKey]
      if ([string]::IsNullOrWhitespace($value.endpoint))
      {
        $this.WriteLog("*")
        $this.WriteLog("* Ignoring Endpoint $($apiKey) because it does not have an active endpoint set.")
        $this.WriteLog("*")
      }
      else
      {
        $this.WriteLog("*")
        $this.WriteLog("* Starting installation for Endpoint '$($apiKey)'")
        $this.Endpoint($apiKey, $value)
        if ($null -ne $this._sessionCookies)
        {
          $this.WriteLog("* Resetting cookies for endpoint")
          $this._sessionCookies = $null
        }
        $this.WriteLog("*")
      }
    }
    $this.ExecuteScript("post-install", $this._config.config.postScript)
  }

  # Handles all operations for a given endpoint/API
  hidden [void] Endpoint([string] $name, [Hashtable] $config)
  {
    foreach ($subresourceKey in $config.subresources.Keys)
    {
      $value = $config.subresources[$subresourceKey]
      $this.WriteLog("** Starting installation for Subresource '$($subresourceKey)'")

      $this.Subresource($subresourceKey, $value, $config.endpoint, $config.auth, $config.stage, $config.extraHeaders, $name)

      $this.WriteLog("** Finished installation for Subresource '$($subresourceKey)'")
      $this.WriteLog("*")
    }
  }

  # Handles all operations on a subresource of an endpoint
  hidden [void] Subresource([string] $subresourceName, [PSCustomObject] $subresource, [string] $endpoint, [PSCustomObject] $auth, [string] $stage, [PSCustomObject] $extraHeaders, [string] $endpointName)
  {
    $stageSubresource = if ($subresource.Contains("stage")) { $subresource.stage } else { if ([String]::IsNullOrEmpty($stage)) { "pre-install" } else { $stage } }
    $authSubresource = if ($subresource.Contains("auth")) { $subresource.auth } else { $auth }
    $this.WriteLog("*** Subresource stage is '$($stageSubresource)', global stage is '$($this._stage)'")
    if ($stageSubresource.Equals($this._stage))
    {
      $endpoint = $endpoint.Trim('/')
      foreach ($entityKey in $subresource.entities.Keys)
      {

        try
        {
          $callResult = $this.CheckEntity(
            $entityKey,
            $endpoint,
            $subresource,
            $authSubresource,
            $extraHeaders
          )

          if (-Not ($this._successes))
          {
            $this._successes = @{}
          }
          if (-Not ($this._successes.ContainsKey($endpointName)))
          {
            $this._successes[$endpointName] = @{}
          }
          if (-Not ($this._successes[$endpointName].ContainsKey($subresourceName)))
          {
            $this._successes[$endpointName][$subresourceName] = @{}
          }

          $this._successes[$endpointName][$subresourceName][$entityKey] = $callResult
        }
        catch
        {
          CreateKubernetesEvents "Warning" "$($endpointName) -> $($subresourceName) -> $($entityKey): $($this.LogInvokeWebRequestError())"
          
          if ($this._config.config.debug.ignoreEntityRestCallErrors)
          {
            if (-Not ($this._errors))
            {
              $this._errors = @{}
            }
            if (-Not ($this._errors.ContainsKey($endpointName)))
            {
              $this._errors[$endpointName] = @{}
            }
            if (-Not ($this._errors[$endpointName].ContainsKey($subresourceName)))
            {
              $this._errors[$endpointName][$subresourceName] = @{}
            }

            $this._errors[$endpointName][$subresourceName][$entityKey] = "[" + [System.Environment]::NewLine + $this.LogInvokeWebRequestError() + "]"
          }
          else
          {
            throw
          }
        }
      }
    }
    else
    {
      $this.WriteLog("*** Subresource stage '$($stageSubresource)' does not match global stage '$($this._stage)', skip processing.")
    }
  }

  # Checks entities and performs required operations (DELETE/PUT/POST)
  hidden [PSCustomObject] CheckEntity([string] $entityKey, [PSCustomObject] $endpoint, [PSCustomObject] $subresource, [PSCustomObject] $auth, [PSCustomObject] $extraHeaders)
  {

    $entity = $subresource.entities[$entityKey]
    
    # Either register or remove needs to be enabled (normally)
    if ($entity.register -ne $true -and $entity.remove -ne $true)
    {
      $lastMethod = ""
      $lastUri = ""
      if ($entity.processNoOp -eq $true)
      {
        $this.WriteLog("*** Not skipping subresource because 'processNoOp' is true even though neither 'register' nor 'remove' is set to true.")
      }
      else
      {
        $this.WriteLog("*** Skipping subresource because neither 'register' nor 'remove' is set to true.")
        return @{ "lastMethod" = $lastMethod; "lastUri" = $lastUri }
      }
    }

    $identifier = if ([string]::IsNullOrWhiteSpace($entity.identifier)) { $entityKey } else { $entity.identifier }
    $identifier = $this.InsertEnvironmentVariables($identifier)

    $deleteQueryParams = @{}
    if ($entity.deleteQueryParams)
    {
      $this.WriteLog("*** Using deleteQueryParams from entity config")
      $deleteQueryParams = $entity.deleteQueryParams
    }
    else
    {
      if ($entity.remove -eq $true)
      {
        if ([string]::IsNullOrWhiteSpace($subresource.identifierQueryParam))
        {
          $this.WriteLog("*** No legacy field 'identifierQueryParam' defined, specyfing object for deletion by identifier in URI")
          if ($entity.deleteUriExcludeIdentifier -eq $true)
          {
            $this.WriteError("*** No 'deleteQueryParams' and no legacy field 'identifierQueryParam' defined but also 'deleteUriExcludeIdentifier' is true. The object to delete is not properly indicated this way and is very likely a misconfiguration!")
          }
        }
        else
        {
          $this.WriteLog("*** Using legacy parameter 'identifierQueryParam' for specifying object to delete")
          $deleteQueryParams = @{ $subresource.identifierQueryParam = $identifier }
        }
      }
    }
    
    $contentType = "$(if ([String]::IsNullOrEmpty($entity.contentType)) { "application/json" } else { $entity.contentType })"
    $this.WriteLog("*** ContentType is '$($contentType)'")

    $entityType = $subresource.typeDescription
    $headers = $this.GetHttpHeaders($auth, $contentType, $extraHeaders, $entity)


    # $this.WriteLog("*** Headers are '$($headers | ConvertTo-Json -Depth 100)'")
    $apiEndpoint = "$($endpoint)/$($subresource.apiPath)".Trim('/')
    $uri = "$apiEndpoint/$identifier"
    $uriPut = if ($entity.putUriExcludeIdentifier -eq $true) { $apiEndpoint } else { $uri }
    $uriGet = if ($entity.getUriExcludeIdentifier -eq $true) { $apiEndpoint } else { $uri }
    $uriDelete = if ($entity.deleteUriExcludeIdentifier -eq $true) { $apiEndpoint } else { $uri }

    $message = ""
    $statusCode = 500
    $result = $null
    $json = "{}"

    $lastMethod = ""
    $lastUri = ""
    
    if ($entity.noGet)
    {
      $statusCode = 404
      $this.WriteLog("**** NoGet is true, not GETting value. Handle as StatusCode $($statusCode)")
    }
    else
    {
      try
      {
        $uriGet = $this.AppendQueryParamsToUri($uriGet, $entity.getQueryParams, $identifier, $false)

        $this.WriteLog("**** Checking if entity exists, GETting uri '$($uriGet)'")
        $responseGet = Invoke-WebRequest -Uri $uriGet -Method "GET" -headers $headers -UseBasicParsing -SkipCertificateCheck
        $lastMethod = "GET"
        $lastUri = $uriGet
        if ([String]::IsNullOrWhitespace($entity.getCustomScript) -and [String]::IsNullOrWhitespace($entity.getCustomScriptFromFile))
        {
          $statusCode = $responseGet.StatusCode
          $this.WriteLog("**** SUCCESS --> StatusCode: $($statusCode)")
        }
        else
        {
          try
          {
            $value = $entity
            $this.WriteLog("**** Invoking getCustomScript")
            $scriptblock = $null
            if (-Not [String]::IsNullOrWhitespace($entity.getCustomScript))
            {
              $this.WriteLog("***** Using inline getCustomScript")
              $scriptblock = [Scriptblock]::Create($entity.getCustomScript)
            }
            else
            {
              $currentPath = (Get-Item -Path ".\" -Verbose).FullName
              $scriptPath = Join-Path $currentPath $entity.getCustomScriptFromFile
              $this.WriteLog("***** Using getCustomScriptFromFile $($scriptPath)")
              $scriptblock = Get-Command $scriptPath | Select-Object -ExpandProperty ScriptBlock 
            }
            
            $this.WriteLog("[- Start Script -]")
            $result = $scriptblock.InvokeReturnAsIs()
            $this.WriteLog("Type of result: $($result.GetType())")
            $this.WriteLog("[- End Script -]")
            if ($result.GetType() -eq "Bool")
            {
              if ($result)
              {
                $statusCode = 200
              }
              else
              {
                $statusCode = 404
              }
            }
            else
            {
              if ($result.GetType().ToString() -eq "System.Object[]")
              {
                $result = $result | Select-Object -Last 1
                $this.WriteLog("Ignoring previous result elements and getting last only: $($result)")
              }
              if ($null -ne $result)
              {
                $json = $result | ConvertFrom-Json
                $this.WriteLog("JSON response from getCustomScript: $($json)")
                if ($json.statusCode)
                {
                  $statusCode = $json.statusCode
                  $this.WriteLog("Updated StatusCode: $($statusCode)")
                }
                if ($json.errorMessage)
                {
                  $message = $json.errorMessage
                  $this.WriteLog("Updated Message from errorMessage: $($message)")
                }
                if ($json.uriPut)
                {
                  $uriPut = $json.uriPut
                  $this.WriteLog("Updated PUT Uri: $($uriPut)")
                }
                if ($json.uriDelete)
                {
                  $uriDelete = $json.uriDelete
                  $this.WriteLog("Updated DELETE Uri: $($uriDelete)")
                }
                if ($json.identifier)
                {
                  $identifier = $json.identifier
                  $this.WriteLog("Updated Identifier: $($identifier)")
                }

              }
            }
          }
          catch
          {
            $statusCode = 500
            $message = "ERROR --> Failed getCustomScript, set statusCode to $($statusCode). Exception was: $($Error[0])"
          }
        }
      }
      catch
      {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        $message = $_.Exception.Response
        $this.LogInvokeWebRequestError($uriGet, "GET")
      }
    }

    $this.WriteLog("**** StatusCode is $($statusCode)")
    
    if ([String]::IsNullOrEmpty($entity.config))
    {
      $this.WriteLog("**** Created new empty config dictionary.")
      $entity.config = @{}
    }
    else
    {
      $this.WriteLog("**** Current config: $($entity.config | ConvertTo-Json -Depth 100).")
    }

    $entity.config = $this.ReadConfigFromFile($entity, $statusCode)
    $entity.config = $this.UpdateConfigValues($entity, $statusCode, "readConfigValuesFromFiles")
    $entity.config = $this.UpdateConfigValues($entity, $statusCode, "updateConfigValues")
    
    $content = $this.InsertEnvironmentVariables($entity.config)
    
    $testJson = $false
    if ($content.GetType() -Eq [String])
    {
      $testJson = Test-Json -Json $content
      $this.WriteLog("**** Config type is String (JSON=$($testJson))")
    }
    else
    {
      $this.WriteLog("**** Config type is $($content.GetType())")
    }

    if ((-Not $testJson) -and ($contentType -eq "application/json"))
    {
      $this.WriteLog("**** ContentType is 'application/json', converting config of string type to JSON object")
      $content = $content | ConvertTo-Json -Depth 100
    }

    if ($entity.customGetScriptJsonResponseConfigReplacements)
    {
      $this.WriteLog("Check customGetScriptJsonResponseConfigReplacements")
      foreach ($placeholder in $entity.customGetScriptJsonResponseConfigReplacements.Keys)
      {
        $jsonKey = $entity.customGetScriptJsonResponseConfigReplacements[$placeholder]
        $this.WriteLog("Check customGetScriptJsonResponseConfigReplacements key $($jsonKey)")
        if ($null -ne $json.$jsonKey)
        {
          $this.WriteLog("Replacing '$($placeholder)' in config with '$($json.$jsonKey)")
          $content = $content.replace($placeholder, $json.$jsonKey)
        }
        else
        {
          $this.WriteLog("$($jsonkey) not found in JSON response of getCustomScript") 
        }
      }
    }

    if ($entity.processConfigScript)
    {
      $CONTENT = $content
      $this.WriteLog("**** Found 'processConfigScript': $entity.processConfigScript")
      $this.WriteLog("**** Invoking processConfigScript")
      $scriptblock = [Scriptblock]::Create($entity.processConfigScript)
      $this.WriteLog("[- Start Script -]")
      $result = $scriptblock.InvokeReturnAsIs()
      $this.WriteLog("Type of result: $($result.GetType())")
      $this.WriteLog("[- End Script -]")
      $content = $result
      $this.WriteLog("Processed Config is '$($content)'")

    }
    
    if ($statusCode -ne 200 -and $statusCode -ne 404)
    {
      throw [Exception]::new("ERROR --> Unexpected StatusCode: $($statusCode) - Message: $($message)")
    }
    
    if ($entity.remove -eq $true)
    {
      if ($statusCode -eq 200)
      {
        $this.WriteLog("**** '$entityType' entry '$identifier' already exists and is going to be deleted now")
        $this.DeleteEntity($uriDelete, $identifier, $deleteQueryParams, $auth, $contentType, $headers)
        $lastMethod = "DELETE"
        $lastUri = $uriDelete
      }
      elseif ($entity.noGet -or ($statusCode -eq 404))
      {
        if ($entity.noGet)
        {
          $this.WriteLog("**** Unclear if '$entityType' entry '$identifier' does exist due to 'noGet=true', DELETEing anyway since 'remove=true'")
          $this.DeleteEntity($uriDelete, $identifier, $deleteQueryParams, $auth, $contentType, $headers)
          $lastMethod = "DELETE"
          $lastUri = $uriDelete
        }
        else
        {
          $this.WriteLog("**** '$entityType' entry '$identifier' does not exist but should be deleted, nothing will be done")
        }
      }
      $this.WriteLog("**** StatusCode is treated as 404 since entity does not exist!")
      $statusCode = 404
    }

    if ($entity.register -eq $true)
    {
      if ($statusCode -eq 200)
      {
        if ($entity.overwriteExisting -eq $true)
        {
          $this.WriteLog("**** '$entityType' entry '$identifier' already exists, hence PUTing instead of POSTing to update entity")
          $this.PutEntity($uriPut, $identifier, $content, $entity.putQueryParams, $auth, $contentType, $headers)
          $lastMethod = "PUT"
          $lastUri = $uriPut
        }
        else
        {
          $this.WriteLog("**** '$entityType' entry '$identifier' already exists, not overwriting due to flag 'overwriteExisting' not being set")
        }
      }
      elseif ($entity.noGet -or ($statusCode -eq 404))
      {
        $this.WriteLog("**** '$entityType' entry '$identifier' does not exist and will be created now")
        if ($entity.putInsteadOfPost -eq $true)
        {
          $this.WriteLog("**** PUTting '$entityType' entry '$identifier' to create it since 'putInsteadOfPost' is set to true")
          $this.PutEntity($uriPut, $identifier, $content, $entity.putQueryParams, $auth, $contentType, $headers)
          $lastMethod = "PUT"
          $lastUri = $uriPut
        }
        else
        {
          $this.WriteLog("**** POSTing '$entityType' entry '$identifier' to create it")
          $this.PostEntity($apiEndpoint, $identifier, $content, $auth, $entity.postQueryParams, $contentType, $headers)
          $lastMethod = "POST"
          $lastUri = $apiEndpoint
        }
      }
    }
    else
    {
      $this.WriteLog("**** 'Register set to false, not PUTing or POSTing.")
    }

    return @{ "lastMethod" = $lastMethod; "lastUri" = $lastUri }
  }

  # Post an entity
  hidden [PSCustomObject] PostEntity([string] $postUrl, [string] $identifier, [string] $json, [PSCustomObject] $auth, [PSCustomObject] $postQueryParams, [string] $contentType, [PSCustomObject] $headers)
  {
    $this.WriteLog("**** 'URL before: $($postUrl)")
    $url = $this.AppendQueryParamsToUri($postUrl, $postQueryParams, $identifier, $false)
    $this.WriteLog("**** 'URL after: $($url)")
    return $this.InvokeWebRequest($url, "POST", $json, $headers)
  }

  # Put an entity
  hidden [PSCustomObject] PutEntity([string] $putUrl, [string] $identifier, [string] $json, [PSCustomObject] $putQueryParams, [PSCustomObject] $auth, [string] $contentType, [PSCustomObject] $headers)
  {
    $url = $this.AppendQueryParamsToUri($putUrl, $putQueryParams, $identifier, $false)
    return $this.InvokeWebRequest($url, "PUT", $json, $headers)
  }

  # Delete an entity
  hidden [PSCustomObject] DeleteEntity([string] $deleteUrl, [string] $identifier, [PSCustomObject] $deleteQueryParams, [PSCustomObject] $auth, [string] $contentType, [PSCustomObject] $headers)
  {
    $url = $this.AppendQueryParamsToUri($deleteUrl, $deleteQueryParams, $identifier, $false)
    return $this.InvokeWebRequest($url, "DELETE", "", $headers)
  }

  # Check if Api response is valid
  hidden [bool] AssertResponse($response)
  {
    if ($response.StatusCode -lt 200 -Or $response.StatusCode -gt 299)
    {
      $this.WriteError("***** Invalid response from server: $($response.StatusCode)")
      return $false
    }
    return $true
  }
  
  # Map JSON config value from JSON file content key
  [PSCustomObject] UpdateConfigValues([PSCustomObject] $entity, [int] $statusCode, [string] $entityConfigValuesKey)
  {
    if ($null -ne $entity.$entityConfigValuesKey)
    {
      foreach ($configKey in $entity.$entityConfigValuesKey.Keys)
      {

        $entry = $entity.$entityConfigValuesKey[$configKey]
        $updateContent = ""
        $updateContentJson = $null
        $path = $null
        $value = $null
        $put = $statusCode -eq 200
        $post = $statusCode -eq 404
        if ([String]::IsNullOrEmpty($entry.putValue) -and [String]::IsNullOrEmpty($entry.postValue))
        {
          $this.WriteLog("**** Properties 'putValue' and 'postValue' not set, checking for 'value'.")
          if (-not [String]::IsNullOrEmpty($entry.value))
          {
            $this.WriteLog("**** Property 'value' set, using it as source for mapping'.")
            $value = $entry.value
          }
        }
        else
        {
          $this.WriteLog("**** Property 'putValue' or 'postValue' set, defaulting to 'value' if PUT or POST not matched.")
          $value = $entry.value
          if ((-not [String]::IsNullOrEmpty($entry.putValue)) -and $put)
          {
            $this.WriteLog("**** Property 'putValue' set and PUTing, using it as source for mapping'.")
            $value = $entry.putValue
          }
          if ((-not [String]::IsNullOrEmpty($entry.postValue)) -and $post)
          {
            $this.WriteLog("**** Property 'postValue' set and POSTing, using it as source for mapping'.")
            $value = $entry.postValue
          }
        }
        
        if ([String]::IsNullOrEmpty($value))
        {
          if ([String]::IsNullOrEmpty($entry.putPath) -and [String]::IsNullOrEmpty($entry.postPath))
          {
            $this.WriteLog("**** Properties 'putPath' and 'postPath' not set, checking for 'path'.")
            if (-not [String]::IsNullOrEmpty($entry.path))
            {
              $this.WriteLog("**** Property 'path' set, using it as source for mapping'.")
              $path = $entry.path
            }
            else
            {
              throw [Exception]::new("ERROR --> Properties 'value' and 'path' do not exist for Config Key '$($configKey)', cannot identify content to update.")
            }
          }
          else
          {
            $this.WriteLog("**** Property 'putPath' or 'postPath' set, defaulting to 'path' if PUT or POST not matched.")
            $path = $entry.path
            if ((-not [String]::IsNullOrEmpty($entry.putPath)) -and $put)
            {
              $this.WriteLog("**** Property 'putPath' set and PUTing, using it as source for mapping'.")
              $path = $entry.putPath
            }
            if ((-not [String]::IsNullOrEmpty($entry.postPath)) -and $post)
            {
              $this.WriteLog("**** Property 'postPath' set and POSTing, using it as source for mapping'.")
              $path = $entry.postPath
            }
          }
        }

        if ([String]::IsNullOrEmpty($value))
        {
          $this.WriteLog("**** Determined file path '$($path)' as source for mapping'.")
          $currentPath = (Get-Item -Path ".\" -Verbose).FullName
          $filePath = ""
          if ($path -like "*/*" )
          {
            $split = $path.split('/')
            $filePath = Join-Path $currentPath "custom-installation-files-$($split[0])" $split[1]
          }
          else
          {
            $filePath = Join-Path $currentPath "custom-installation-files" $($path)
          }
          if (!(Test-Path $filePath))
          {
            throw [Exception]::new("ERROR --> File '$($filePath)' does not exist")
          }
          $this.WriteLog("**** External Config file found: " + $filePath)
          
          $updateContent = Get-Content -Path $filePath | Out-String

          if (-not [string]::IsNullOrWhitespace($entry.key))
          {
            $this.WriteLog("**** Value '$($entry.key)' provided for 'key' property, mapping content of key to Config Key '$($configKey)'")
            $updateContentJson = ($updateContent | ConvertFrom-Json).$($entry.key)
          }
        }
        else
        {
        
          if ($value.GetType() -eq "String")
          {
            $updateContent = $value
          }
          else
          {
            if ($null -ne $value)
            {
              $updateContent = $value | Out-String
              $updateContentJson = $value
            }
            else
            {
              throw [Exception]::new("ERROR --> Properties 'path' or 'value' do not exist for Config Key '$($configKey)', cannot identify content to update.")
            }
          }
        }
        
        if ($null -eq $updateContentJson)
        {
          $this.WriteLog("**** No JSON structure found, mapping full contents to Config Key '$($configKey)'")
          $entity.config.$configKey = $updateContent  
        }
        else
        {
        
          $this.WriteLog("**** Entity content: " + $($entity.config | ConvertTo-Json -Depth 100))
          $this.WriteLog("**** JSON content for update: " + $($updateContentJson | ConvertTo-Json -Depth 100))
          
          $this.WriteLog("**** Replacing key '$($configKey)' in entity fully with content: " + $($updateContentJson | ConvertTo-Json -Depth 100))
          $entity.config[$configKey] = $updateContentJson
        }
      }
    }
    
    return $entity.config
  }

  # Read complete config from file
  [PSCustomObject] ReadConfigFromFile([PSCustomObject] $entity, [int] $statusCode)
  {
    if ($null -ne $entity.readConfigFromFile)
    {    
      $currentPath = (Get-Item -Path "./" -Verbose).FullName

      $filePath = [String]::Empty
      $contextPath = ""
      
      $contextPath = $entity.readConfigFromFile.path

      if ([string]::IsNullOrWhitespace($entity.readConfigFromFile.putPath) -and 
        [string]::IsNullOrWhitespace($entity.readConfigFromFile.postPath))
      {
        $this.WriteLog("**** Reading File from 'readConfigFromFile.path' value, no 'putPath' or 'postPath' set.")
      }
      else
      {
        if ($statusCode -eq 404 -and (-not [string]::IsNullOrWhitespace($entity.readConfigFromFile.postPath)))
        {
          $this.WriteLog("**** Property 'postPath' set and POSTing, using it as source for mapping'.")
          $contextPath = $entity.readConfigFromFile.postPath
        }
        if ($statusCode -eq 200 -and (-not [string]::IsNullOrWhitespace($entity.readConfigFromFile.putPath)))
        {
          $this.WriteLog("**** Property 'putPath' set and PUTing, using it as source for mapping'.")
          $contextPath = $entity.readConfigFromFile.putPath
        }
      }


      $filePath = ""
      if ($contextPath -like "*/*" )
      {
        $split = $contextPath.split('/')
        $filePath = Join-Path $currentPath "custom-installation-files-$($split[0])" $split[1]
      }
      else
      {
        $filePath = Join-Path $currentPath "custom-installation-files" $($contextPath)
      }
      
      if (!(Test-Path $filePath))
      {
        $this.WriteLog("File '$($filePath)' does not exist")
      }
      else
      {
        $fileContent = Get-Content -Path $filePath | Out-String
        $this.WriteLog("**** FileContent of " + $filePath + " is:" + $fileContent)
        
        if ([string]::IsNullOrWhitespace($entity.readConfigFromFile.key))
        {
          $this.WriteLog("**** No 'key' property provided, mapping full contents of '$($filePath)' to Config")
          $entity.config = $fileContent
        }
        else
        {
          $this.WriteLog("**** Value '$($entity.readConfigFromFile.key)' provided for 'key' property, mapping content of key from JSON file '$($filePath)' to Config")
          $fileContentJson = $fileContent | ConvertFrom-Json
          $entity.config = $fileContentJson.$($entity.readConfigFromFile.key) | ConvertTo-Json -Depth 100
          $this.WriteLog("**** JSON file content extracted from key '$($entity.readConfigFromFile.key)': " + $entity.config)
        }
      }
    }
  
    return $entity.config
  }

  [PSCustomObject] AppendQueryParamsToUri([String] $uri, [PSCustomObject] $queryParams, [String] $identifier, [bool] $disableReplacements)
  {
  
    if ($null -ne $queryParams)
    {
      $count = 0
      $start = "?"
      foreach ($key in $queryParams.Keys)
      {
        if ($count -gt 0)
        {
          $start = "&"
        }
        $value = ""
        if ($disableReplacements)
        {
          $value = $queryParams[$key]
        }
        else
        {
          $value = $queryParams[$key].toString().Replace('$identifier', $identifier)
        }
        $uri += "$($start)$($key)=$($value)"
        $count = $count + 1
      }
    }

    return $uri
  }
}