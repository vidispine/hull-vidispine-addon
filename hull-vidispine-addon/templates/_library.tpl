---
{{- define "hull.vidispine.addon.library.component.ingress.rules" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $componentInputs := (index . "COMPONENTS") -}}
{{- $endpoint := default "vidiflow" (index . "ENDPOINT") -}}
{{- $portName := default "http" (index . "PORTNAME") -}}
{{- $serviceName := default "" (index . "SERVICENAME") -}}
{{- $components := regexSplit "," ($componentInputs | trim) -1 -}}
{{- if $components }}
{{ $key }}:
{{ range $componentKebapCase := $components }}
{{- $componentSnakeCase := (regexReplaceAll "-" $componentKebapCase "_") | trim -}}
{{- $componentUri := camelcase $componentSnakeCase | untitle | toString }}
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
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $endpointType := (index . "TYPE") }}
{{- if (eq $endpointType "database") -}}
  {{- if (ne (default "" $parent.Values.hull.config.general.data.endpoints.postgres.uri.address) "") -}}
  postgres
  {{- end -}}
  {{- if (ne (default "" $parent.Values.hull.config.general.data.endpoints.mssql.uri.address) "") -}}
  mssql
  {{- end -}}
{{- else -}}
  {{- if (eq $endpointType "messagebus") -}}
    {{- if (ne (default "" (default $parent.Values.hull.config.general.data.endpoints.rabbitmq.uri.amq $parent.Values.hull.config.general.data.endpoints.rabbitmq.uri.amqInternal)) "") -}}
    rabbitmq
    {{- end -}}
    {{- if (ne (default "" (default $parent.Values.hull.config.general.data.endpoints.activemq.uri.amq $parent.Values.hull.config.general.data.endpoints.activemq.uri.amqInternal)) "") -}}
    activemq
    {{- end -}}
  {{- else -}}
    {{- if (eq $endpointType "index") -}}
      {{- if (ne (default "" (default $parent.Values.hull.config.general.data.endpoints.opensearch.uri.api $parent.Values.hull.config.general.data.endpoints.opensearch.uri.apiInternal)) "") -}}
      opensearch
      {{- end -}}
    {{- else -}}
      {{ $endpointType }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.get.endpoint.info" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $info := (index . "INFO") }}
{{- $endpointType := (index . "TYPE") }}
{{- $component := (index . "COMPONENT") }}
{{- $endpointKey := include "hull.vidispine.addon.library.get.endpoint" (dict "PARENT_CONTEXT" $parent "TYPE" $endpointType) }}
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



{{- define "hull.vidispine.addon.library.component.pod.volumes" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{ $key }}:
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
{{- end -}}



{{- define "hull.vidispine.addon.library.component.pod.env" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $connectionstringsuffix := default "" (index . "CONNECTIONSTRINGSUFFIX") -}}
{{ $key }}:
  'ENDPOINTS__RABBITMQCONNECTIONSTRING':
    valueFrom:
      secretKeyRef:
        name: endpoints
        key: rabbitmq-auth-basic-connectionString
  'DBUSERPOSTFIX':
    valueFrom:
      secretKeyRef:
        name: endpoints
        key: database-auth-basic-usernamesPostfix
  'DBADMINUSER':
    valueFrom:
      secretKeyRef:
        name: endpoints
        key: database-auth-basic-adminUsername
  'DBADMINPASSWORD':
    valueFrom:
      secretKeyRef:
        name: endpoints
        key: database-auth-basic-adminPassword
  'ELASTICSEARCH__USERNAME':
    valueFrom:
      secretKeyRef:
        name: endpoints
        key: index-auth-basic-username
  'ELASTICSEARCH__PASSWORD':
    valueFrom:
      secretKeyRef:
        name: endpoints
        key: index-auth-basic-password
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
{{ if (index $parent.Values.hull.config.specific.components $component).auth }}
  'CLIENTSECRET__CLIENTID':
    valueFrom:
      secretKeyRef:
        name: "authservice-token-secret"
        key:  "{{ $component }}-client-id"
  'CLIENTSECRET__CLIENTSECRET':
    valueFrom:
      secretKeyRef:
        name: "authservice-token-secret"
        key:  "{{ $component }}-client-secret"
{{- end -}}
{{- end -}}



{{- define "hull.vidispine.addon.library.component.job.database" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $type := (index . "TYPE") -}}
{{- $databaseKey := include "hull.vidispine.addon.library.get.endpoint" (dict "PARENT_CONTEXT" $parent "TYPE" "database") }}
{{- $databaseHost := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "host") }}
{{- $databasePort := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "port") }}
{{ $key }}:
  initContainers:
    check-database-ready:
      image:
        repository: vpms/dbtools
        tag: _HT!"{{ $parent.Values.hull.config.specific.tags.dbTools | toString }}"
      env:
        DBHOST:
          value: {{ $databaseHost }}
        DBPORT:
          value: {{ $databasePort }}
        DBTYPE:
          value: {{ $databaseKey }}
        DBADMINUSER:
          valueFrom:
            secretKeyRef:
              name: endpoints
              key: database-auth-basic-adminUsername
        DBADMINPASSWORD:
          valueFrom:
            secretKeyRef:
              name: endpoints
              key: database-auth-basic-adminPassword
        DBUSERPOSTFIX:
          valueFrom:
            secretKeyRef:
              name: endpoints
              key: database-auth-basic-usernamesPostfix
        DBNAME:
          valueFrom:
            secretKeyRef:
              name: "{{ $component }}"
              key: database-name
        DBUSER:
          valueFrom:
            secretKeyRef:
              name: "{{ $component }}"
              key: database-username
        DBPASSWORD:
          valueFrom:
            secretKeyRef:
              name: "{{ $component }}"
              key: database-password
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
        tag: _HT!"{{ $parent.Values.hull.config.specific.tags.dbTools | toString }}"
      env:
        DBHOST:
          value: {{ $databaseHost }}
        DBPORT:
          value: {{ $databasePort }}
        DBTYPE:
          value: {{ $databaseKey }}
        DBADMINUSER:
          valueFrom:
            secretKeyRef:
              name: endpoints
              key: database-auth-basic-adminUsername
        DBADMINPASSWORD:
          valueFrom:
            secretKeyRef:
              name: endpoints
              key: database-auth-basic-adminPassword
        DBUSERPOSTFIX:
          valueFrom:
            secretKeyRef:
              name: endpoints
              key: database-auth-basic-usernamesPostfix
        DBNAME:
          valueFrom:
            secretKeyRef:
              name: "{{ $component }}"
              key: database-name
        DBUSER:
          valueFrom:
            secretKeyRef:
              name: "{{ $component }}"
              key: database-username
        DBPASSWORD:
          valueFrom:
            secretKeyRef:
              name: "{{ $component }}"
              key: database-password
{{ end }}



{{- define "hull.vidispine.addon.library.secret.authservicetokensecret" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{ $key }}:
{{ range $k, $v := $parent.Values.hull.config.specific.components }}
{{ if (hasKey $v "auth") }}
  {{ $k }}-client-id: 
    inline: {{ $v.auth.clientId }}
  {{ $k }}-client-secret: 
    inline: {{ $v.auth.clientSecret }}  
{{ end }}
{{ end }}
  installerClientId: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installerClientId }}
  installerClientSecret: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installerClientSecret }}
  productClientId: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.productClientId }}
  productClientSecret: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.productClientSecret }}
{{ end }}



{{- define "hull.vidispine.addon.library.auth.secret.data" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $endpoints := (index . "ENDPOINTS") -}}
{{- $endpointsList := regexSplit "," ($endpoints | trim) -1 -}}
{{ $key }}:
{{ range $endpointInput := $endpointsList }}
{{ $endpointKey := include "hull.vidispine.addon.library.get.endpoint" (dict "PARENT_CONTEXT" $parent "TYPE" $endpointInput) }}
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
  CLIENT_INSTALLER_ID: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installerClientId }}
  CLIENT_INSTALLER_SECRET:
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.installerClientSecret }}
  CLIENT_PRODUCT_ID: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.productClientId }}
  CLIENT_PRODUCT_SECRET: 
    inline: {{ default "" $parent.Values.hull.config.general.data.endpoints.authservice.auth.token.productClientSecret }}
{{ end }}



{{- define "hull.vidispine.addon.library.component.secret.data" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $timeout := default "60" (index . "TIMEOUT") }}
{{ $key }}:
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
{{ $databaseKey := include "hull.vidispine.addon.library.get.endpoint" (dict "PARENT_CONTEXT" $parent "TYPE" "database") }}
{{ $databaseUsernamesPostfix := include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "usernamesPostfix") }}
{{ if (eq $databaseKey "mssql") }}
    database-name:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.name }}
    database-username: 
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.username }}
        {{- $databaseUsernamesPostfix }}
{{ end }}
{{ if (eq $databaseKey "postgres") }}
    database-name:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.name | lower }}
    database-username: 
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.username | lower }}
        {{- $databaseUsernamesPostfix | lower }}
{{ end }}
    database-password:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.password }}    
    database-connectionString:
      inline: {{ include "hull.vidispine.addon.library.get.endpoint.info" (dict "PARENT_CONTEXT" $parent "TYPE" "database" "INFO" "connectionString" "COMPONENT" $component) }}
{{- end -}}
{{- end -}}