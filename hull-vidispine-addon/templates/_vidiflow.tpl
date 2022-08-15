{{- define "hull.vidispine.addon.vidiflow.component.secret.data" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $timeout := default "TIMEOUT" "60" }}
{{ $key }}:
{{ if (index $parent.Values.hull.config.specific.components $component).appsettings }}
    appsettings.json:
      path: files/appsettings-{{ $component }}.json
{{ end }}
{{ if (index $parent.Values.hull.config.specific.components $component).database }}
    database-name:
      inline: {{ printf "%s_vidiflow_%s" $parent.Values.hull.config.specific.system.name ((index $parent.Values.hull.config.specific.components $component).database.name) }}
    database-username: 
      inline: {{ printf "%s_vidiflow_%s" $parent.Values.hull.config.specific.system.name ((index $parent.Values.hull.config.specific.components $component).database.username) }}
        {{- $parent.Values.hull.config.specific.database.usernamesPostfix }}
    database-password:
      inline: {{ (index $parent.Values.hull.config.specific.components $component).database.password }}    
    database-connection-string:
      inline: 
        {{ if (eq $parent.Values.hull.config.specific.database.type "mssql") -}}
        Data Source=
        {{- printf "%s,%s" $parent.Values.hull.config.specific.database.host (toString $parent.Values.hull.config.specific.database.port) -}}
        ;Initial Catalog=
        {{- printf "%s_vidiflow_%s" $parent.Values.hull.config.specific.system.name ((index $parent.Values.hull.config.specific.components $component).database.name) -}}
        ;MultipleActiveResultSets=true;User ID=
        {{- printf "%s_vidiflow_%s" $parent.Values.hull.config.specific.system.name ((index $parent.Values.hull.config.specific.components $component).database.username) -}}
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
        {{- printf "%s_vidiflow_%s" $parent.Values.hull.config.specific.system.name ((index $parent.Values.hull.config.specific.components $component).database.name) -}}
        ;User ID=
        {{- printf "%s_vidiflow_%s" $parent.Values.hull.config.specific.system.name ((index $parent.Values.hull.config.specific.components $component).database.username) -}}
        {{- $parent.Values.hull.config.specific.database.usernamesPostfix -}}
        ;Password=
        {{- (index $parent.Values.hull.config.specific.components $component).database.password -}}
        {{- end -}}
        {{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.vidiflow.component.ingress.rule" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $uriname := (index . "URINAME") -}}
{{- $endpoint := default (index . "ENDPOINT") "vidiflow" -}}
{{ $key }}:
  {{ $component }}:
    host: "{{ (urlParse (index (index $parent.Values.hull.config.general.data.endpoints $endpoint).uri $uriname)).hostname }}"
    http:
      paths:
        {{ $component }}:
          path: {{ (urlParse (index (index $parent.Values.hull.config.general.data.endpoints $endpoint).uri $uriname)).path }}
          pathType: ImplementationSpecific
          backend:
            service: 
              name: {{ $component }}
              port:
                name: http
{{- end -}}

{{- define "hull.vidispine.addon.vidiflow.component.pod.env" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $component := (index . "COMPONENT") -}}
{{- $connectionstringsuffix := default nil (index . "CONNECTIONSTRINGSUFFIX") -}}
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
{{ if (ne $connectionstringsuffix "") }}
  "CONNECTIONSTRINGS__{{ $connectionstringsuffix }}":
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
{{- $url := default 
    $parent.Values.hull.config.general.data.endpoints.rabbitmq.uri.amq 
    $parent.Values.hull.config.general.data.endpoints.rabbitmq.uri.amqInternal }}
{{- printf "%s:%s" (urlParse $url).hostname ((urlParse $url).port | toString) }}
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
    inline: ""
  productClientSecret: 
    inline: "" 
{{ end }}
