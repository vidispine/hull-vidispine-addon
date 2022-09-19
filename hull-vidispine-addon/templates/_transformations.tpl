---
{{- define "hull.vidispine.addon.transformation" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $source := (index . "SOURCE") -}}
{{- $caller := default nil (index . "CALLER") -}}
{{- $callerKey := default nil (index . "CALLER_KEY") -}}
{{- $shortForms := dict -}}
{{- $shortForms = set $shortForms "_HT?" (list "hull.util.transformation.bool" "CONDITION") -}}
{{- $shortForms = set $shortForms "_HT*" (list "hull.util.transformation.get" "REFERENCE") -}}
{{- $shortForms = set $shortForms "_HT!" (list "hull.util.transformation.tpl" "CONTENT") -}}
{{- $shortForms = set $shortForms "_HT^" (list "hull.util.transformation.makefullname" "COMPONENT") -}}
{{- if typeIs "map[string]interface {}" $source -}}
    {{- range $key,$value := $source -}}
        {{- if typeIs "map[string]interface {}" $value -}}
            {{- $params := default nil $value._HULL_TRANSFORMATION_ -}}
            {{- range $sfKey, $sfValue := $shortForms -}}
                {{- if (hasKey $value $sfKey) -}}
                    {{- $params = dict "NAME" (first $sfValue) (last $sfValue) (first (values (index $value $sfKey))) -}}
                {{- end -}} 
            {{- end -}} 
            {{- if $params -}} 
                {{- $pass := merge (dict "PARENT_CONTEXT" $parent "KEY" $key) $params -}}
                {{- $valDict := fromYaml (include $value._HULL_TRANSFORMATION_.NAME $pass) -}}
                {{- $source := unset $source $key -}}
                {{- $source := merge $source $valDict -}}  
            {{- else -}}
                {{- include "hull.vidispine.addon.transformation" (dict "PARENT_CONTEXT" $parent "SOURCE" $value "CALLER" $source "CALLER_KEY" $key) -}}
            {{- end -}}
        {{- end -}}
        {{- if typeIs "[]interface {}" $value -}}
            {{- include "hull.vidispine.addon.transformation" (dict "PARENT_CONTEXT" $parent "SOURCE" $value "CALLER" $source "CALLER_KEY" $key) -}}
        {{- end -}}
        {{- if typeIs "string" $value -}}
            {{- $params := default nil nil -}}
            {{- if (or (hasPrefix "_HULL_TRANSFORMATION_" $value) (hasPrefix "_HT?" $value) (hasPrefix "_HT*" $value) (hasPrefix "_HT!" $value) (hasPrefix "_HT^" $value)) -}}
                {{- range $sfKey, $sfValue := $shortForms -}}
                    {{- if (hasPrefix $sfKey $value) -}}
                        {{- $params = dict "NAME" (first $sfValue) (last $sfValue) (trimPrefix $sfKey $value) -}}
                    {{- end -}} 
                {{- end -}} 
                {{- if (hasPrefix "_HULL_TRANSFORMATION_" $value) -}}
                    {{- $paramsString := trimPrefix "_HULL_TRANSFORMATION_" $value -}}
                    {{- $paramsSplitted := regexFindAll "(<<<[A-Z]+=.+?>>>)" $paramsString -1 -}}
                    {{- $params = dict -}}
                    {{- range $p := $paramsSplitted -}}
                        {{- $params = set $params (trimPrefix "<<<" (first (regexSplit "=" $p -1))) (trimSuffix ">>>" (trimPrefix (printf "%s=" (first (regexSplit "=" $p -1))) $p)) -}}
                    {{- end -}}
                {{- end -}}
            {{- end -}}             
            {{- if $params }}
                {{- $pass := merge (dict "PARENT_CONTEXT" $parent "KEY" $key) $params -}}
                {{- $valDict := fromYaml (include ($params.NAME) $pass) -}} 
                {{- $source := unset $source $key -}}
                {{- $source := set $source $key (index $valDict $key) -}}  
            {{- end -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- if typeIs "[]interface {}" $source -}}

    {{- range $listentry := $source -}}
        {{- $newlistentry := include "hull.vidispine.addon.transformation" (dict "PARENT_CONTEXT" $parent "SOURCE" $listentry "CALLER" nil "CALLER_KEY" nil) -}}
        
    {{- end -}}
    {{- $t2 := set $caller $callerKey $source -}}
{{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.producturis" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $appends := (index . "APPENDS") -}}
{{- $c := list -}}
{{- $field := "" }}
{{- if (hasKey (index $parent.Values "hull").config.general.data.installation.config "productUris") -}}
{{- $field = "productUris" -}}
{{- end -}}
{{- if (ne $field "") -}}
{{- $uris := list -}}
{{ $key }}:
{{- range $u := (index ((index $parent.Values "hull").config.general.data.installation.config) $field) }}
{{- range $a := $appends }}
{{- $entry := printf "%s%s" $u $a }}
{{- if (has $entry $uris) -}}
{{- else -}}
{{- $uris = append $uris $entry }}
- {{ $entry }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.coruris" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $c := list -}}
{{- $field := "" }}
{{- if (hasKey (index $parent.Values "hull").config.general.data.installation.config "productUris") -}}
{{- $field = "productUris" -}}
{{- end -}}
{{- if (ne $field "") -}}
{{- $origins := list -}}
{{ $key }}:
{{- range (index ((index $parent.Values "hull").config.general.data.installation.config) $field) }}
{{- $entry := printf "%s://%s"  (index (. | urlParse) "scheme") (index (. | urlParse) "host") }}
{{- if (has $entry $origins) -}}
{{- else -}}
{{- $origins = append $origins $entry }}
- {{ $entry }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.producticon" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $iconFile := (index . "ICON_FILE") -}}
Icon: |-
{{ $parent.Files.Get (printf "%s" $iconFile) | indent 2}}
{{- end -}}

{{- define "hull.vidispine.addon.generalendpoint" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $name := (index . "ENTRY") -}}
{{- $endpoint := (index . "ENDPOINT") -}}
{{- $excludeSubpath := (index . "EXCLUDE_SUBPATH") }}
{{- if hasKey $parent.Values.hull.config.general.data "endpoints" }}
{{- if hasKey $parent.Values.hull.config.general.data.endpoints $name }}
{{- if hasKey (index $parent.Values.hull.config.general.data.endpoints $name) "uri" }}
{{- if hasKey (index (index $parent.Values.hull.config.general.data.endpoints $name) "uri") $endpoint}}
{{- $ep := (index (index $parent.Values.hull.config.general.data.endpoints $name).uri $endpoint) -}}
{{- if $ep -}}
{{ $key }}:{{ printf " %s" $ep }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.ingress_classname_default" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{ $key }}: {{ printf "nginx-%s" ($parent.Release.Name | quote) }}
{{- end -}}

{{- define "hull.vidispine.addon.makefullname" -}}
{{- $key := (index . "KEY") -}}
{{ $key }}: {{ template "hull.transformation.fullname" . }}
{{- end -}}

{{- define "hull.vidispine.addon.imagepullsecrets" -}}
{{- $key := (index . "KEY") -}}
{{ $key }}: 
  {{ template "hull.object.pod.imagePullSecrets" (dict "PARENT_CONTEXT" (index . "PARENT") "SPEC" (index . "SPEC") "HULL_ROOT_KEY" "hull") }}
{{- end -}}

{{- define "hull.vidispine.addon.vidiflow.component.secret.data" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $timeout := default "60" (index . "TIMEOUT") }}
{{ $key }}:
{{ range $path, $_ := $parent.Files.Glob (printf "files/mounts/%s/*" $component) }}
{{ if (hasKey (index $parent.Values.hull.config.specific.components $component) "mounts") }}
{{ if (hasKey (index (index $parent.Values.hull.config.specific.components $component).mounts) ($path | base)) }}
{{ else }}
    {{ $path | base }}:
      path: {{ $path}}
{{ end }}
{{ end }}
{{ end }}
{{ if (index $parent.Values.hull.config.specific.components $component).mounts }}
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
{{ if (eq $parent.Values.hull.config.specific.database.type "mssql") }}
    database-name:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.name }}
    database-username: 
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.username }}
        {{- $parent.Values.hull.config.specific.database.usernamesPostfix }}
{{ end }}
{{ if (eq $parent.Values.hull.config.specific.database.type "postgres") }}
    database-name:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.name | lower }}
    database-username: 
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.username | lower }}
        {{- $parent.Values.hull.config.specific.database.usernamesPostfix | lower }}
{{ end }}
    database-password:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.password }}    
    database-connection-string:
      inline: 
        {{ if (eq $parent.Values.hull.config.specific.database.type "mssql") -}}
        Data Source=
        {{- printf "%s,%s" $parent.Values.hull.config.specific.database.host (toString $parent.Values.hull.config.specific.database.port) -}}
        ;Initial Catalog=
        {{- (index $parent.Values.hull.config.specific.components $component).database.name -}}
        ;MultipleActiveResultSets=true;User ID=
        {{- (index $parent.Values.hull.config.specific.components $component).database.username -}}
        ;Password={{- (index $parent.Values.hull.config.specific.components $component).database.password -}}
        ;Connect Timeout=
        {{- $timeout -}}
        {{- end -}}
        {{- if (eq $parent.Values.hull.config.specific.database.type "postgres") -}}
        Server=
        {{- $parent.Values.hull.config.specific.database.host -}}
        ;Port=
        {{- (toString $parent.Values.hull.config.specific.database.port) -}}
        ;Database=
        {{- (index $parent.Values.hull.config.specific.components $component).database.name | lower -}}
        ;User ID=
        {{- (index $parent.Values.hull.config.specific.components $component).database.username | lower -}}
        {{- $parent.Values.hull.config.specific.database.usernamesPostfix | lower -}}
        ;Password=
        {{- (index $parent.Values.hull.config.specific.components $component).database.password -}}
        {{- end -}}
        {{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.vidiflow.component.ingress.rules" -}}
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

{{- define "hull.vidispine.addon.vidiflow.component.pod.volumes" -}}
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

{{- define "hull.vidispine.addon.vidiflow.component.pod.env" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $connectionstringsuffix := default "" (index . "CONNECTIONSTRINGSUFFIX") -}}
{{ $key }}:
  'ENDPOINTS__RABBITMQCONNECTIONSTRING':
    valueFrom:
      secretKeyRef:
        name: messagebus
        key: connectionString
  'DBUSERPOSTFIX':
    valueFrom:
      secretKeyRef:
        name: database
        key: usernamesPostfix
  'DBADMINUSER':
    valueFrom:
      secretKeyRef:
        name: database
        key: adminUsername
  'DBADMINPASSWORD':
    valueFrom:
      secretKeyRef:
        name: database
        key: adminPassword
  'ELASTICSEARCH__USERNAME':
    valueFrom:
      secretKeyRef:
        name: index
        key: username
  'ELASTICSEARCH__PASSWORD':
    valueFrom:
      secretKeyRef:
        name: index
        key: password
{{ if (index $parent.Values.hull.config.specific.components $component).database }}
{{ if (hasKey (index $parent.Values.hull.config.specific.components $component).database "connectionStringEnvVarSuffix") }}
  "CONNECTIONSTRINGS__{{ (index $parent.Values.hull.config.specific.components $component).database.connectionStringEnvVarSuffix }}":
{{ else }}
  "CONNECTIONSTRINGS":
{{ end }}
    valueFrom:
      secretKeyRef:
        name: "{{ $component }}"
        key:  database-connection-string
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

{{- define "hull.vidispine.addon.vidiflow.component.job.database" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $type := (index . "TYPE") -}}
{{ $key }}:
  initContainers:
    check-database-ready:
      image:
        repository: vpms/dbtools
        tag: _HT!"{{ $parent.Values.hull.config.specific.tags.dbTools | toString }}"
      env:
        DBHOST:
          value: _HT*hull.config.specific.database.host
        DBPORT:
          value: _HT!{{ $parent.Values.hull.config.specific.database.port | toString | quote }}
        DBTYPE:
          value: _HT*hull.config.specific.database.type
        DBADMINUSER:
          valueFrom:
            secretKeyRef:
              name: database
              key: adminUsername
        DBADMINPASSWORD:
          valueFrom:
            secretKeyRef:
              name: database
              key: adminPassword
        DBUSERPOSTFIX:
          valueFrom:
            secretKeyRef:
              name: database
              key: usernamesPostfix
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
          value: _HT*hull.config.specific.database.host
        DBPORT:
          value: _HT!{{ $parent.Values.hull.config.specific.database.port | toString | quote }}
        DBTYPE:
          value: _HT*hull.config.specific.database.type
        DBADMINUSER:
          valueFrom:
            secretKeyRef:
              name: database
              key: adminUsername
        DBADMINPASSWORD:
          valueFrom:
            secretKeyRef:
              name: database
              key: adminPassword
        DBUSERPOSTFIX:
          valueFrom:
            secretKeyRef:
              name: database
              key: usernamesPostfix
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

{{- define "hull.vidispine.addon.vidiflow.secret.messagebus.connectionstring" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $type := (index . "TYPE") -}}
{{- if (eq $parent.Values.hull.config.specific.messagebus.type "rabbitmq") -}}
{{ $key }}:
   {{ printf "%s" "amqp://" }}
{{- $parent.Values.hull.config.specific.messagebus.username }}
{{- printf "%s" ":" }}
{{- $parent.Values.hull.config.specific.messagebus.password }}
{{- printf "%s" "@" }}
{{- $url := default $parent.Values.hull.config.general.data.endpoints.rabbitmq.uri.amq $parent.Values.hull.config.general.data.endpoints.rabbitmq.uri.amqInternal }}
{{- $end := (regexSplit ":" $url -1) | last | trim -}}
{{- $vhost := "" -}}
{{- $port := (regexSplit "/" $end -1) | first -}}
{{- if (and (contains "/" $end) (not (hasSuffix "/" $end))) -}}
{{- $vhost = (regexSplit "/" $end -1) | last -}}
{{- end -}}
{{- printf "%s:%s/%s" (urlParse $url).hostname $port $vhost }}
{{- else -}}
""
{{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.vidiflow.secret.authservicetokensecret" -}}
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
    inline: {{ $parent.Values.hull.config.specific.authService.installerClientId }}
  installerClientSecret: 
    inline: {{ $parent.Values.hull.config.specific.authService.installerClientSecret }}
  productClientId: 
    inline: {{ $parent.Values.hull.config.specific.authService.productClientId }}
  productClientSecret: 
    inline: {{ $parent.Values.hull.config.specific.authService.productClientSecret }}
{{ end }}
