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
{{- if (or (not $keyFound) (not (typeIs "string" $current))) -}}
{{- else -}}
{{- $current -}}
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint.uri.exists" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $endpointKey := (index . "KEY") }}
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
    {{- if (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" "postgres.uri.address")) "") -}}
    postgres
    {{- end -}}
    {{- if (ne (include "hull.vidispine.addon.library.safeGetString" (dict "DICTIONARY" $endpoints "KEY" "mssql.uri.address")) "") -}}
    mssql
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
      {{- default 60 $endpoint.options.timeout -}}
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
      {{ printf "%s" "amqp://" }}
      {{- $endpoint.auth.basic.username -}}
      {{- printf "%s" ":" }}
      {{- $endpoint.auth.basic.password -}}
      {{- printf "%s" "@" }}
      {{- $url := default $endpoint.uri.amq $endpoint.uri.amqInternal }}
      {{- $end := (regexSplit ":" $url -1) | last | trim -}}
      {{- $vhost := "" -}}
      {{- $port := (regexSplit "/" $end -1) | first -}}
      {{- if (and (contains "/" $end) (not (hasSuffix "/" $end))) -}}
      {{- $vhost = (regexSplit "/" $end -1) | last -}}
      {{- end -}}
      {{- printf "%s:%s/%s" (urlParse $url).hostname $port $vhost }}
      {{- end -}}
  {{- end -}}
  {{- if (eq $info "vhost") -}}
    {{- if (eq $endpointKey "rabbitmq") -}}
      {{- $url := default $endpoint.uri.amq $endpoint.uri.amqInternal }}
      {{- $end := (regexSplit ":" $url -1) | last | trim -}}
      {{- $vhost := "" -}}
      {{- if (and (contains "/" $end) (not (hasSuffix "/" $end))) -}}
      {{- $vhost = (regexSplit "/" $end -1) | last -}}
      {{- end -}}
      {{- $vhost }}
      {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}



{{ define "hull.vidispine.addon.library.component.ingress.rules" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $componentInputs := (index . "COMPONENTS") }}
{{ $endpoint := default "vidiflow" (index . "ENDPOINT") }}
{{ $portName := default "http" (index . "PORTNAME") }}
{{ $serviceName := default "" (index . "SERVICENAME") }}
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
        pathType: ImplementationSpecific
        backend:
          service:
{{ if (eq $serviceName "") }}
            name: {{ $componentKebapCase }}
{{ else }}
            name: {{ $serviceName }}
{{ end }}
            port:
              name: {{ $portName }}
{{ end }}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.pod.volumes" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
settings:
  secret:
    defaultMode: 0744
    secretName: {{ $component }}
certs:
  enabled: $parent.Values.hull.config.general.data.installation.config.customCaCertificates
  secret:
    secretName: "custom-ca-certificates"
etcssl:
  enabled: $parent.Values.hull.config.general.data.installation.config.customCaCertificates
  emptyDir: {}
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



{{ define "hull.vidispine.addon.library.component.job.database" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
{{ $type := (index . "TYPE") }}
{{ $databaseKey := include "hull.vidispine.addon.library.get.endpoint.key" (dict "PARENT_CONTEXT" $parent "TYPE" "database") }}
{{ $databaseHost := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "host") }}
{{ $databasePort := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "port") }}
initContainers:
  check-database-ready:
    image:
      repository: vpms/dbtools
      tag: {{ $parent.Values.hull.config.specific.tags.dbTools | toString | quote }}
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
    - /scripts/create-database.sh
{{ end }}
{{ if (eq $type "reset") }}
  reset-database:
    args:
    - "/bin/sh"
    - "-c"
    - /scripts/reset-database.sh
{{ end }}
    image:
      repository: vpms/dbtools
      tag: {{ $parent.Values.hull.config.specific.tags.dbTools | toString | quote }}
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
{{ end }}



{{ define "hull.vidispine.addon.library.auth.secret.data" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $endpoints := (index . "ENDPOINTS") }}
{{ $endpointsList := regexSplit "," ($endpoints | trim) -1 }}
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
{{ if (hasKey $parent.Values.hull.config.general.data.endpoints "authservice") }}
{{ if (hasKey $parent.Values.hull.config.general.data.endpoints.authservice "auth") }}
{{ if (hasKey $parent.Values.hull.config.general.data.endpoints.authservice.auth "token") }}
CLIENT_AUTHSERVICE_INSTALLATION_ID:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installationClientId }}
CLIENT_AUTHSERVICE_INSTALLATION_SECRET:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installationClientSecret }}
{{ if (hasKey $parent.Values.hull.config.general.data.endpoints "configportal") }}
{{ if (hasKey $parent.Values.hull.config.general.data.endpoints.configportal "auth") }}
{{ if (hasKey $parent.Values.hull.config.general.data.endpoints.configportal.auth "token") }}
CLIENT_CONFIGPORTAL_INSTALLATION_ID:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.configportal.auth.token.installationClientId }}
CLIENT_CONFIGPORTAL_INSTALLATION_SECRET:
  inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.configportal.auth.token.installationClientSecret }}
{{ end }}
{{ end }}
{{ end }}
{{ end }}
{{ end }}
{{ end }}
{{ end }}



{{ define "hull.vidispine.addon.library.component.secret.data" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $component := (index . "COMPONENT") }}
{{ $timeout := default "60" (index . "TIMEOUT") }}
{{ $mountsSpecified := false }}
{{ $componentSpecified := false }}
{{ if (hasKey $parent.Values.hull.config.specific "components") }}
{{ if (hasKey (index $parent.Values.hull.config.specific.components) $component) }}
{{ $componentSpecified = true }}
{{ if (hasKey (index $parent.Values.hull.config.specific.components $component) "mounts") }}
{{ $mountsSpecified = true }}
{{ end }}
{{ end }}
{{ end }}
{{ range $path, $_ := $parent.Files.Glob (printf "files/mounts/%s/*" $component) }}
{{ $mountSpecified := false }}
{{ if $mountsSpecified }}
{{ if (hasKey (index $parent.Values.hull.config.specific.components $component).mounts ($path | base) ) }}
{{ $mountSpecified = true }}
{{ end }}
{{ end }}
{{ if (not $mountSpecified) }}
{{ $path | base }}:
  path: {{ $path}}
{{ end }}
{{ end }}
{{ if $mountsSpecified }}
{{ range $filename, $filecontent := (index $parent.Values.hull.config.specific.components $component).mounts }}
{{ $filename }}:
{{ if (hasSuffix ".json" $filename) }}
{{ $json := $filecontent | toPrettyJson }}
{{ if (hasKey $parent.Values.hull.config.specific.components "common") }}
{{ if (hasKey $parent.Values.hull.config.specific.components.common "mounts") }}
{{ if (hasKey $parent.Values.hull.config.specific.components.common.mounts $filename) }}
{{ $json = merge $filecontent (index $parent.Values.hull.config.specific.components.common.mounts $filename) | toPrettyJson }}
{{ end }}
{{ end }}
{{ end }}
  inline: {{ $json | toPrettyJson }}
{{ else }}
  inline: {{ $filecontent}}
{{ end }}
{{ end }}
{{ end }}
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
  inline: {{ include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "connectionString" "COMPONENT" $component) }}
{{ end }}
{{ if (eq (include "hull.vidispine.addon.library.get.endpoint.uri.exists" (dict "PARENT_CONTEXT" $parent "KEY" "rabbitmq" "URI" "amq")) "true") }}
rabbitmq-connectionString:
  inline: {{ include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "messagebus" "INFO" "connectionString" "COMPONENT" $component "KEY" "rabbitmq") }}
{{ end }}
{{ end }}
