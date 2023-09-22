{{- define "hull.vidispine.addon.library.safeGetString" -}}
{{- $current := (index . "DICTIONARY") }}
{{- $dotKey := (index . "KEY") }}
{{- $path := splitList "." $dotKey -}}
{{- $keyFound := true -}}
{{- $result := "" }}
{{- range $key := $path -}}
{{- if (and (hasKey $current $key) ($keyFound)) -}}
{{- $current = (index $current $key) }}
{{- else -}}
{{- $keyFound = false -}}
{{- end -}}
{{- end -}}
{{- if (and $keyFound (not (or (typeIs "map[string]interface {}" $current) (typeIs "[]interface {}" $current) (kindIs "invalid" $current)))) -}}
{{- $current | toString -}}
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint.uri.exists" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $endpointKey := "" }}
{{- if (hasKey . "KEY") }}
{{- $endpointKey = (index . "KEY") }}
{{- end -}}
{{- if (hasKey . "ENDPOINT") }}
{{- $endpointKey = (index . "ENDPOINT") }}
{{- end -}}
{{- $uri := default "api" (index . "URI") }}
{{- $endpoints := $parent.Values.hull.config.general.data.endpoints -}}
{{- $external := printf "%s.uri.%s" $endpointKey $uri -}}
{{- $internal := printf "%sInternal" $external -}}
{{- if (or (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" $internal)) "") 
            (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" $external)) "")) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint.uri.info" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $endpoint := (index . "ENDPOINT") }}
{{- $uri := default "api" (index . "URI") }}
{{- $info := default "uri" (index . "INFO") }}
{{- $endpoints := $parent.Values.hull.config.general.data.endpoints -}}
{{- $external := printf "%s.uri.%s" $endpoint $uri -}}
{{- $internal := printf "%sInternal" $external -}}
{{- if (or (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" $internal)) "") 
            (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" $external)) "")) -}}
    {{- $selectedEndpoint := default (index (index $endpoints $endpoint).uri $uri) (index (index $endpoints $endpoint).uri (printf "%sInternal" $uri)) -}}
    {{- $host := (regexSplit ":" (urlParse $selectedEndpoint).host -1) | first | trim -}}
    {{- $netloc := (urlParse $selectedEndpoint).netloc -}}
    {{- $path := (urlParse $selectedEndpoint).path -}}
    {{- $scheme := regexSplit ":" $selectedEndpoint -1 | first -}}
    {{- $port := "0" -}}
    {{- if (contains ":" (urlParse $selectedEndpoint).host) -}}
      {{- $port = (regexSplit ":" (urlParse $selectedEndpoint).host -1) | last | trim | int -}}
    {{- else -}}
        {{- if (hasPrefix "http" $selectedEndpoint) -}}
            {{- $port = 80 -}}
        {{- end -}}
        {{- if (hasPrefix "https" $selectedEndpoint) -}}
            {{- $port = 443 -}}
        {{- end -}}
    {{- end -}}
    {{- if (eq $info "uri") -}}
      {{- $selectedEndpoint -}}
    {{- end -}}
    {{- if (or (eq $info "hostname") (eq $info "host")) -}}
      {{- $host -}}
    {{- end -}}
    {{- if (eq $info "port") -}}
      {{- $port -}}
    {{- end -}}
    {{- if (eq $info "scheme") -}}
      {{- $scheme -}}
    {{- end -}}
    {{- if (eq $info "netloc") -}}
      {{- $netloc -}}
    {{- end -}}
    {{- if (eq $info "path") -}}
      {{- $path -}}
    {{- end -}}
    {{- if (eq $info "base") -}}
      {{- if (gt $port 0) -}}
        {{- printf "%s://%s:%s" $scheme $host (toString $port) -}}
      {{- else -}}
        {{- printf "%s://%s" $scheme $host -}}
      {{- end -}}
    {{- end -}}
{{- else -}}
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint.key" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $endpointType := (index . "TYPE") }}
{{- $response := "" }}
{{- if (hasKey $parent.Values.hull.config.general.data "endpoints") -}}
  {{- $endpoints := $parent.Values.hull.config.general.data.endpoints -}}
  {{- if (eq $endpointType "database") -}}
    {{- if (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" "mssql.uri.address")) "") -}}
    mssql
    {{- end -}}
    {{- if (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" "postgres.uri.address")) "") -}}
    postgres
    {{- end -}}
  {{- else -}}
    {{- if (eq $endpointType "index") -}}
      {{- $internal := "opensearch.uri.apiInternal" -}}
      {{- $external := "opensearch.uri.api" -}}
      {{- if (or (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" $internal)) "") 
                (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" $external)) "")) -}}
      opensearch
      {{- end -}}
    {{- else -}}
      {{ $endpointType }}
    {{- end -}}
  {{- end -}}
{{- else -}}
""
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint.info" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $info := (index . "INFO") }}
{{- $endpointType := (index . "TYPE") }}
{{- $component := default "" (index . "COMPONENT") }}
{{- $endpointKey := default (include "hull.vidispine.addon.library.get.endpoint.key" (dict "PARENT_CONTEXT" $parent "TYPE" $endpointType)) (index . "KEY") }}
{{- $endpoint := (index $parent.Values.hull.config.general.data.endpoints $endpointKey) }}
{{- if (eq $endpointType "database") -}}
  {{- $databasePort := -1 }}
  {{- $databaseHost := (regexSplit "," $endpoint.uri.address -1) | first | trim }}
  {{- if (contains "," $endpoint.uri.address) }}
    {{- $databasePort = (regexSplit "," $endpoint.uri.address -1) | last | trim -}}
  {{- else -}}
    {{- if (eq $endpointKey "postgres") -}}
      {{- $databasePort = 4532 }}
    {{- else -}}
      {{- $databasePort = 1433 }}
    {{- end -}}
  {{- end -}}
  {{- if (or (eq $info "hostname") (eq $info "host")) -}}
    {{- $databaseHost -}}
  {{- end -}}
  {{- if (eq $info "port") -}}
    {{- $databasePort -}}
  {{- end -}}
  {{- if (eq $info "usernamesPostfix") -}}
    {{- $endpoint.auth.basic.usernamesPostfix -}}
  {{- end -}}
  {{- if (eq $info "adminUsername") -}}
    {{- $endpoint.auth.basic.adminUsername -}}
  {{- end -}}
  {{- if (eq $info "adminPassword") -}}
    {{- $endpoint.auth.basic.adminPassword -}}
  {{- end -}}
  {{- if (eq $info "connectionString") -}}
    {{- if (eq $endpointKey "mssql") -}}
      Data Source=
      {{- printf "%s,%s" $databaseHost (toString $databasePort) -}}
      ;Initial Catalog=
      {{- (index $parent.Values.hull.config.specific.components $component).database.name -}}
      ;MultipleActiveResultSets=true;User ID=
      {{- (index $parent.Values.hull.config.specific.components $component).database.username -}}
      ;Password={{- (index $parent.Values.hull.config.specific.components $component).database.password -}}
      ;Connect Timeout=
      {{- $timeout := include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoint "KEY" "options.timeout") -}}
      {{- if (ne $timeout "") -}} 
      {{- printf "%s" $timeout -}}      
      {{- else -}}
      {{- printf "%s" 60 -}}
      {{- end -}}
    {{- end -}}
    {{- if (eq $endpointKey "postgres") -}}
      Server=
      {{- $databaseHost -}}
      ;Port=
      {{- (toString $databasePort) -}}
      ;Database=
      {{- (index $parent.Values.hull.config.specific.components $component).database.name | lower -}}
      ;User ID=
      {{- (index $parent.Values.hull.config.specific.components $component).database.username | lower -}}
      {{- $endpoint.auth.basic.usernamesPostfix | lower -}}
      ;Password=
      {{- (index $parent.Values.hull.config.specific.components $component).database.password -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if (eq $endpointType "messagebus") -}}
  {{- if (eq $info "connectionString") -}}
    {{- if (eq $endpointKey "rabbitmq") -}}
      {{- $url := default $endpoint.uri.amq $endpoint.uri.amqInternal }}
      {{- $start := (regexSplit ":" $url -1) | first | trim -}}  
      {{- $remainder := trimPrefix (printf "%s://" $start) $url }}
      {{- if (and (contains ":" $remainder) (contains "@" $remainder)) }}
        {{- printf "%s" $url }}
      {{- else -}}      
        {{- printf "%s://" $start -}}
        {{- $endpoint.auth.basic.username -}}
        {{- printf "%s" ":" }}
        {{- $endpoint.auth.basic.password -}}
        {{- printf "@%s" $remainder }}
      {{- end -}}
    {{- end -}}    
  {{- end -}}
  {{- if (eq $info "vhost") -}}
    {{- if (eq $endpointKey "rabbitmq") -}}
      {{- $url := default $endpoint.uri.amq $endpoint.uri.amqInternal }}
      {{- $start := (regexSplit ":" $url -1) | first | trim -}}
      {{- $end := (trimPrefix (printf "%s://" $start) $url) }}
      {{- $vhost := "/" -}}
      {{- if (and (contains "/" $end) (not (hasSuffix "/" $end))) -}}
      {{- $vhost = (regexSplit "/" $end -1) | last | replace "%2F" "/" | replace "%2f" "/" -}}
      {{- end -}}
      {{- $vhost }}
      {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}



{{ define "hull.vidispine.addon.library.auth.secret.data" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $endpoints := default nil (index . "ENDPOINTS") }}
{{ $endpointsList := keys $parent.Values.hull.config.general.data.endpoints | sortAlpha }}
{{ if (ne nil $endpoints) }}
{{ $endpointsList = regexSplit "," ($endpoints | trim) -1 }}
{{ end }}
{{ range $endpointInput := $endpointsList }}
{{ $endpointKey := include "hull.vidispine.addon.library.get.endpoint.key" (dict "PARENT_CONTEXT" $parent "TYPE" $endpointInput) }}
{{ if (hasKey (index $parent.Values.hull.config.general.data.endpoints $endpointKey) "auth") }}
{{ range $authType, $authValue := (index $parent.Values.hull.config.general.data.endpoints $endpointKey).auth }}
{{ range $entryKey, $entryValue := $authValue }}
{{ regexReplaceAll "-" ((printf "AUTH_%s_%s_%s" $authType $endpointInput $entryKey) | upper) "_" }}:
  inline: {{ default nil $entryValue }}
{{ end }}
{{ end }}
{{ end }}
{{ end }}
{{ range $k, $v := $parent.Values.hull.config.specific.components }}
{{ if (hasKey $v "auth") }}
{{ regexReplaceAll "-" ((printf "CLIENT_%s_ID" $k) | upper) "_" }}:
  inline: {{ $v.auth.clientId }}
{{ regexReplaceAll "-" ((printf "CLIENT_%s_SECRET" $k) | upper) "_" }}:
  inline: {{ $v.auth.clientSecret }}
{{ end }}
{{ end }}
{{ if (ne "" (dig "authservice" "auth" "token" "installationClientId" "" $parent.Values.hull.config.general.data.endpoints)) }}
CLIENT_AUTHSERVICE_INSTALLATION_ID:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installationClientId }}
{{ end }}
{{ if (ne "" (dig "authservice" "auth" "token" "installationClientSecret" "" $parent.Values.hull.config.general.data.endpoints)) }}
CLIENT_AUTHSERVICE_INSTALLATION_SECRET:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installationClientSecret }}
{{ end }}
{{ if (ne "" (dig "configportal" "auth" "token" "installationClientId" "" $parent.Values.hull.config.general.data.endpoints)) }}
CLIENT_CONFIGPORTAL_INSTALLATION_ID:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.configportal.auth.token.installationClientId }}
{{ end }}
{{ if (ne "" (dig "configportal" "auth" "token" "installationClientSecret" "" $parent.Values.hull.config.general.data.endpoints)) }}
CLIENT_CONFIGPORTAL_INSTALLATION_SECRET:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.configportal.auth.token.installationClientSecret }}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.secret.data" }}
{{ include "hull.vidispine.addon.library.component.data" (merge . (dict "OBJECT_TYPE" "secret")) }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.configmap.data" }}
{{ include "hull.vidispine.addon.library.component.data" (merge . (dict "OBJECT_TYPE" "configmap")) }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.data" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
{{ $objectType := default "secret" (index . "OBJECT_TYPE") }}
{{ $rendered := include "hull.util.transformation" (dict "PARENT_CONTEXT" $parent "SOURCE" ($parent.Values.hull.config)) | fromYaml }}
{{ $componentMounts := dig $component "mounts" $objectType dict $parent.Values.hull.config.specific.components }}
{{ $commonMounts := dig "common" "mounts" $objectType dict $parent.Values.hull.config.specific.components }}
{{ $components := keys $componentMounts $commonMounts | uniq | sortAlpha }}
{{ range $fileKey := $components }}
{{ $fileContent := "" }}
{{ if (or (hasSuffix ".json" $fileKey) (hasSuffix ".yaml" $fileKey)) }}
{{ $componentValue := dig $component "mounts" $objectType $fileKey dict $parent.Values.hull.config.specific.components }}
{{ $commonValue := dig "common" "mounts" $objectType $fileKey dict $parent.Values.hull.config.specific.components }}
{{ $fileContent = merge $componentValue $commonValue }}
{{ if (hasSuffix ".json" $fileKey) }}
{{ $fileContent = $fileContent | toPrettyJson }}
{{ end }}
{{ else }}
{{ if (ne "" (dig $component "mounts" $objectType $fileKey "" $parent.Values.hull.config.specific.components)) }}
{{ $fileContent = dig $component "mounts" $objectType $fileKey "" $parent.Values.hull.config.specific.components }}
{{ else }}
{{ if (ne "" (dig "common" "mounts" $objectType $fileKey "" $parent.Values.hull.config.specific.components)) }}
{{ $fileContent = dig "common" "mounts" $objectType $fileKey "" $parent.Values.hull.config.specific.components }}
{{ end }}
{{ end }}
{{ end }}
{{ $fileKey }}:
{{ if (hasSuffix ".json" $fileKey) }}
  inline: {{ $fileContent | toPrettyJson  }}
{{ else }}
{{ if (hasSuffix ".yaml" $fileKey) }}
  inline: {{ $fileContent | toYaml | quote }}
{{ else }}
  inline: {{ $fileContent }}
{{ end }}
{{ end }}
{{ end }}
{{ range $path, $_ := $parent.Files.Glob (printf "files/%s/mounts/%s/*" $component $objectType) }}
{{ if (not (has ($path | base) $components )) }}
{{ $path | base }}:
  path: {{ $path}}
{{ end }}
{{ end }}
{{ if (eq $objectType "secret") }}
{{ if (index $parent.Values.hull.config.specific.components $component).database }}
{{ $databaseKey := include "hull.vidispine.addon.library.get.endpoint.key" (dict "PARENT_CONTEXT" $parent "TYPE" "database") }}
{{ $databaseUsernamesPostfix := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "usernamesPostfix") }}
{{ if (eq $databaseKey "mssql") }}
AUTH_BASIC_DATABASE_NAME:
  inline: {{ (index $parent.Values.hull.config.specific.components $component).database.name }}
AUTH_BASIC_DATABASE_USERNAME:
  inline: {{ (index $parent.Values.hull.config.specific.components $component).database.username }}
    {{ $databaseUsernamesPostfix }}
{{ end }}
{{ if (eq $databaseKey "postgres") }}
AUTH_BASIC_DATABASE_NAME:
  inline: {{ (index $parent.Values.hull.config.specific.components $component).database.name | lower }}
AUTH_BASIC_DATABASE_USERNAME:
  inline: {{ (index $parent.Values.hull.config.specific.components $component).database.username | lower }}
    {{ $databaseUsernamesPostfix | lower }}
{{ end }}
AUTH_BASIC_DATABASE_PASSWORD:
  inline: {{ (index $parent.Values.hull.config.specific.components $component).database.password }}
database-connectionString:
{{ if (hasKey (index $parent.Values.hull.config.specific.components $component).database "connectionString") }}
  inline: {{ (index $parent.Values.hull.config.specific.components $component).database.connectionString }}
{{ else }}
  inline: {{ include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "connectionString" "COMPONENT" $component) }}
{{ end }}
{{ end }}
{{ if (eq (include "hull.vidispine.addon.library.get.endpoint.uri.exists" (dict "PARENT_CONTEXT" $parent "KEY" "rabbitmq" "URI" "amq")) "true") }}
rabbitmq-connectionString:
  inline: {{ include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "messagebus" "INFO" "connectionString" "COMPONENT" $component "KEY" "rabbitmq") }}
{{ end }}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.ingress.rules" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $componentInputs := (index . "COMPONENTS") }}
{{ $endpoint := default "vidiflow" (index . "ENDPOINT") }}
{{ $portName := default "http" (index . "PORTNAME") }}
{{ $pathType := default "ImplementationSpecific" (index . "PATHTYPE") }}
{{ $serviceName := default "" (index . "SERVICENAME") }}
{{ $staticServiceName := default false (index . "STATIC_SERVICENAME") }}
{{ $components := regexSplit "," ($componentInputs | trim) -1 }}
{{ if $components }}
{{ range $componentKebapCase := $components }}
{{ $componentSnakeCase := (regexReplaceAll "-" $componentKebapCase "_") | trim }}
{{ $componentUri := camelcase $componentSnakeCase | untitle | toString }}
{{ $componentKebapCase }}:
  host: "{{ (urlParse (index (index $parent.Values.hull.config.general.data.endpoints $endpoint).uri $componentUri)).hostname }}"
  http:
    paths:
      {{ $componentKebapCase }}:
        path: {{ (urlParse (index (index $parent.Values.hull.config.general.data.endpoints $endpoint).uri $componentUri)).path }}
        pathType: {{ $pathType }}
        backend:
          service:
{{ if (eq $serviceName "") }}
            name: {{ $componentKebapCase }}
{{ else }}
            name: {{ $serviceName }}
{{ end }}
            staticName: {{ $staticServiceName }}
            port:
              name: {{ $portName }}
{{ end }}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.job.database" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
{{ $type := (index . "TYPE") }}
{{ $createScriptConfigMap := default nil (index . "CREATE_SCRIPT_CONFIGMAP") }}
{{ $databaseKey := include "hull.vidispine.addon.library.get.endpoint.key" (dict "PARENT_CONTEXT" $parent "TYPE" "database") }}
{{ $databaseHost := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "host") }}
{{ $databasePort := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "port") }}
restartPolicy: {{ default "Never" (index . "RESTART_POLICY") }}
initContainers:
{{ if $createScriptConfigMap }}
  copy-custom-scripts:
    image:
      repository: {{ dig "images" "dbTools" "repository" "vpms/dbtools" $parent.Values.hull.config.specific }}
      tag: {{ (dig "images" "dbTools" "tag" (dig "tags" "dbTools" "1.8" $parent.Values.hull.config.specific) $parent.Values.hull.config.specific) | toString | quote }}
    args:
    - "/bin/sh"
    - "-c"
    - "cp /configmap/* /custom-scripts"
    volumeMounts:
      script-configmap:
        name: script-configmap
        mountPath: /configmap
      custom-scripts:
        name: custom-scripts
        mountPath: /custom-scripts
  set-custom-script-permissions:
    image:
      repository: {{ dig "images" "dbTools" "repository" "vpms/dbtools" $parent.Values.hull.config.specific }}
      tag: {{ (dig "images" "dbTools" "tag" (dig "tags" "dbTools" "1.8" $parent.Values.hull.config.specific) $parent.Values.hull.config.specific) | toString | quote }}
    args:
    - "/bin/sh"
    - "-c"
    - "chmod -R u+x /custom-scripts"
    volumeMounts:
      custom-scripts:
        name: custom-scripts
        mountPath: /custom-scripts
{{ end }}
  check-database-ready:
    image:
      repository: {{ dig "images" "dbTools" "repository" "vpms/dbtools" $parent.Values.hull.config.specific }}
      tag: {{ (dig "images" "dbTools" "tag" (dig "tags" "dbTools" "1.8" $parent.Values.hull.config.specific) $parent.Values.hull.config.specific) | toString | quote }}
    env:
      DBHOST:
        value: {{ $databaseHost }}
      DBPORT:
        value: {{ $databasePort | toString | quote }}
      DBTYPE:
        value: {{ $databaseKey }}
      DBADMINUSER:
        valueFrom:
          secretKeyRef:
            name: auth
            key: AUTH_BASIC_DATABASE_ADMINUSERNAME
      DBADMINPASSWORD:
        valueFrom:
          secretKeyRef:
            name: auth
            key: AUTH_BASIC_DATABASE_ADMINPASSWORD
      DBUSERPOSTFIX:
        valueFrom:
          secretKeyRef:
            name: auth
            key: AUTH_BASIC_DATABASE_USERNAMESPOSTFIX
            optional: true
      DBNAME:
        valueFrom:
          secretKeyRef:
            name: "{{ $component }}"
            key: AUTH_BASIC_DATABASE_NAME
      DBUSER:
        valueFrom:
          secretKeyRef:
            name: "{{ $component }}"
            key: AUTH_BASIC_DATABASE_USERNAME
      DBPASSWORD:
        valueFrom:
          secretKeyRef:
            name: "{{ $component }}"
            key: AUTH_BASIC_DATABASE_PASSWORD
    args:
    - "/bin/sh"
    - "-c"
    - /scripts/check-database-server-ready.sh
containers:
{{ if (eq $type "create") }}
  create-database:
    args:
    - "/bin/sh"
    - "-c"
{{ if $createScriptConfigMap }}
    - /custom-scripts/create-database.sh
{{ else }}
    - /scripts/create-database.sh
{{ end }}
{{ if $createScriptConfigMap }}
    volumeMounts:
      custom-scripts:
        name: custom-scripts
        mountPath: /custom-scripts
{{ end }}
{{ end }}
{{ if (eq $type "reset") }}
  reset-database:
    args:
    - "/bin/sh"
    - "-c"
    - /scripts/reset-database.sh
{{ end }}
    image:
      repository: {{ dig "images" "dbTools" "repository" "vpms/dbtools" $parent.Values.hull.config.specific }}
      tag: {{ (dig "images" "dbTools" "tag" (dig "tags" "dbTools" "1.8" $parent.Values.hull.config.specific) $parent.Values.hull.config.specific) | toString | quote }}
    env:
      DBHOST:
        value: {{ $databaseHost }}
      DBPORT:
        value: {{ $databasePort | toString | quote }}
      DBTYPE:
        value: {{ $databaseKey }}
      DBADMINUSER:
        valueFrom:
          secretKeyRef:
            name: auth
            key: AUTH_BASIC_DATABASE_ADMINUSERNAME
      DBADMINPASSWORD:
        valueFrom:
          secretKeyRef:
            name: auth
            key: AUTH_BASIC_DATABASE_ADMINPASSWORD
      DBUSERPOSTFIX:
        valueFrom:
          secretKeyRef:
            name: auth
            key: AUTH_BASIC_DATABASE_USERNAMESPOSTFIX
            optional: true
      DBNAME:
        valueFrom:
          secretKeyRef:
            name: "{{ $component }}"
            key: AUTH_BASIC_DATABASE_NAME
      DBUSER:
        valueFrom:
          secretKeyRef:
            name: "{{ $component }}"
            key: AUTH_BASIC_DATABASE_USERNAME
      DBPASSWORD:
        valueFrom:
          secretKeyRef:
            name: "{{ $component }}"
            key: AUTH_BASIC_DATABASE_PASSWORD
{{ if $createScriptConfigMap }}
volumes:
  script-configmap:
    configMap:
      name: {{ $createScriptConfigMap }}
  custom-scripts:
    emptyDir: {}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.pod.volumes" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
{{ $hashSecret := default true (index . "HASH_SECRET") }}
{{ $hashConfigMap := default true (index . "HASH_CONFIGMAP") }}
{{ $component := (index . "COMPONENT") }}
{{ $additionalSecrets := default "" (index . "SECRETS") }}
{{ $additionalConfigMaps := default "" (index . "CONFIGMAPS") }}
{{ $additionalEmptyDirs := default "" (index . "EMPTYDIRS") }}
{{ $additionalPvcs := default "" (index . "PVCS") }}
{{ $secrets := regexSplit "," ($additionalSecrets | trim) -1 }}
{{ $configmaps := regexSplit "," ($additionalConfigMaps | trim) -1 }}
{{ $emptydirs := regexSplit "," ($additionalEmptyDirs | trim) -1 }}
{{ $pvcs := regexSplit "," ($additionalPvcs | trim) -1 }}
{{ $secretMountsSpecified := false }}
{{ $configmapMountsSpecified := false }}
{{ if (ne nil (dig $component "mounts" "secret" nil $parent.Values.hull.config.specific.components)) }}
{{ $secretMountsSpecified = true }}
{{ end }}
{{ if (ne nil (dig $component "mounts" "configmap" nil $parent.Values.hull.config.specific.components)) }}
{{ $configmapMountsSpecified = true }}
{{ end }}
{{ range $path, $_ := $parent.Files.Glob (printf "files/%s/mounts/%s/*" $component "secret") }}
{{ $secretMountsSpecified = true }}
{{ end }}
{{ range $path, $_ := $parent.Files.Glob (printf "files/%s/mounts/%s/*" $component "configmap") }}
{{ $configmapMountsSpecified = true }}
{{ end }}
{{ if $secretMountsSpecified }}
secret:
  secret:
    defaultMode: 0777
    secretName: {{ $component }}
    hashsumAnnotation: {{ $hashSecret }}
{{ end }}
{{ if $configmapMountsSpecified }}
configmap:
  configMap:
    defaultMode: 0777
    name: {{ $component }}
    hashsumAnnotation: {{ $hashConfigMap }}
{{ end }}
certs:
  enabled: $parent.Values.hull.config.general.data.installation.config.customCaCertificates
  secret:
    secretName: "custom-ca-certificates"
etcssl:
  enabled: $parent.Values.hull.config.general.data.installation.config.customCaCertificates
  emptyDir: {}
{{ if $secrets }}
{{ range $secret := $secrets }}
{{ if (ne $secret "") }}
{{ $secret }}:
  secret:
    secretName: {{ $secret }}
    staticName: true
{{ end }}
{{ end }}
{{ end }}
{{ if $configmaps }}
{{ range $configmap := $configmaps }}
{{ if (ne $configmap "") }}
{{ $configmap }}:
  configMap:
    name: {{ $configmap }}
    staticName: true
{{ end }}
{{ end }}
{{ end }}
{{ if $emptydirs }}
{{ range $emptydir := $emptydirs }}
{{ if (ne $emptydir "") }}
{{ $emptydir }}:
  emptyDir: {}
{{ end }}
{{ end }}
{{ end }}
{{ if $pvcs }}
{{ range $pvc := $pvcs }}
{{ if (ne $pvc "") }}
{{ $pvc }}:
  persistentVolumeClaim:     
    claimName: {{ $pvc }}
    staticName: true
{{ end }}
{{ end }}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.pod.env" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
{{ $connectionstringsuffix := default "" (index . "CONNECTIONSTRINGSUFFIX") }}
'DBUSERPOSTFIX':
  valueFrom:
    secretKeyRef:
      name: auth
      key: AUTH_BASIC_DATABASE_USERNAMESPOSTFIX
      optional: true
'DBADMINUSER':
  valueFrom:
    secretKeyRef:
      name: auth
      key: AUTH_BASIC_DATABASE_ADMINUSERNAME
'DBADMINPASSWORD':
  valueFrom:
    secretKeyRef:
      name: auth
      key: AUTH_BASIC_DATABASE_ADMINPASSWORD
{{ if (ne (include "hull.vidispine.addon.library.get.endpoint.key" (dict "PARENT_CONTEXT" $parent "TYPE" "index")) "" ) }}
'ELASTICSEARCH__USERNAME':
  valueFrom:
    secretKeyRef:
      name: auth
      key: AUTH_BASIC_INDEX_USERNAME
'ELASTICSEARCH__PASSWORD':
  valueFrom:
    secretKeyRef:
      name: auth
      key: AUTH_BASIC_INDEX_PASSWORD
{{ end }}
{{ if (index $parent.Values.hull.config.specific.components $component).auth }}
'CLIENTSECRET__CLIENTID':
  valueFrom:
    secretKeyRef:
      name: "auth"
      key:  "CLIENT_{{ regexReplaceAll "-" ($component | upper) "_" }}_ID"
'CLIENTSECRET__CLIENTSECRET':
  valueFrom:
    secretKeyRef:
      name: "auth"
      key:  "CLIENT_{{ regexReplaceAll "-" ($component | upper) "_" }}_SECRET"
{{ end }}
{{ if (index $parent.Values.hull.config.specific.components $component).database }}
{{ if (hasKey (index $parent.Values.hull.config.specific.components $component).database "connectionStringEnvVarSuffix") }}
"CONNECTIONSTRINGS__{{ (index $parent.Values.hull.config.specific.components $component).database.connectionStringEnvVarSuffix }}":
{{ else }}
"CONNECTIONSTRINGS":
{{ end }}
  valueFrom:
    secretKeyRef:
      name: "{{ $component }}"
      key:  database-connectionString
{{ end }}
{{ if (eq (include "hull.vidispine.addon.library.get.endpoint.uri.exists" (dict "PARENT_CONTEXT" $parent "KEY" "rabbitmq" "URI" "amq")) "true") }}
'ENDPOINTS__RABBITMQCONNECTIONSTRING':
  valueFrom:
    secretKeyRef:
      name: "{{ $component }}"
      key: rabbitmq-connectionString
{{ end }}
{{ end }}