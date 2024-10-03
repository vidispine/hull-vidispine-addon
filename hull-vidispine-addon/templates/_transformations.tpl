---
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



{{- define "hull.vidispine.addon.producticon" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $iconFile := (index . "ICON_FILE") -}}
Icon: |-
{{ $parent.Files.Get (printf "%s" $iconFile) | indent 2}}
{{- end -}}



{{ define "hull.vidispine.addon.sources.folder.volumes" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{
{{ if $parent.Values.hull.config.general.data.installation.config.debug.debugInstallerScript }}
  "installation":
  { 
    "secret":{ "secretName": "hull-install" }
  },
{{ end }}
  "custom-installation-files":
  {
    "secret": { "secretName": "custom-installation-files" }
  },
  "etcssl":
  {
    "enabled": {{ if (or $parent.Values.hull.config.general.data.installation.config.customCaCertificates $parent.Values.hull.config.general.data.installation.config.certificateSecrets) }}true{{ else }}false{{ end }},
    "emptyDir": { }
  },
  "certs":
  { 
    "enabled": {{ if $parent.Values.hull.config.general.data.installation.config.customCaCertificates }}true{{ else }}false{{ end }},
    "secret": { "secretName": "custom-ca-certificates" }
  },
  {{ if $parent.Values.hull.config.general.data.installation.config.certificateSecrets }}
  {{ range $secretKey, $secretData := $parent.Values.hull.config.general.data.installation.config.certificateSecrets }}
  "certs-{{ $secretKey }}":
  { 
    "enabled": true,
    "secret": { "secretName": "{{ $secretData.secretName }}", "staticName": true }
  },
  {{ end }}
  {{ end }}
  "oci-license":
  {
    "emptyDir": { }
  },    
  {{ $processedDict := dict }}
  {{ $folderCount := 0 }}
  {{ range $file, $_ := $parent.Files.Glob "files/hull-vidispine-addon/installation/sources/**/*" }}
  {{- $folder := base (dir $file) }}
  {{- if not (hasKey $processedDict $folder) -}}
  {{ $folderCount = add $folderCount 1 }}
  {{ $_ := set $processedDict $folder "true" }}
  "custom-installation-files-{{ $folder }}":  
  {
      secret: 
      {
        secretName: "custom-installation-files-{{ $folderCount }}"
      }
  },
  {{ end }}
  {{ end }}
}
{{ end }}



{{ define "hull.vidispine.addon.sources.folder.volumemounts" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{
{{ if $parent.Values.hull.config.general.data.installation.config.debug.debugInstallerScript }}
  "installer": 
  {
    "name": "installation",
    "mountPath": "/script/Installer.ps1",
    "subPath": "Installer.ps1"
  },
{{ end }}
  "custom-installation-files":
  {
    "name": "custom-installation-files",
    "mountPath": "/custom-installation-files"
  },
  "etcssl": 
  {
    "enabled": {{ if (or $parent.Values.hull.config.general.data.installation.config.customCaCertificates $parent.Values.hull.config.general.data.installation.config.certificateSecrets) }}true{{ else }}false{{ end }},
    "name": "etcssl",
    "mountPath": "/etc/ssl/certs"
  },
  "oci-license":
  {  
    "name": "oci-license",
    "mountPath": "/oci_license"
  },
  {{ range $certkey, $certvalue := $parent.Values.hull.config.general.data.installation.config.customCaCertificates}}
  "custom-ca-certificates-{{ $certkey }}": 
  {
    "enabled": true, 
    "name": "certs",
    "mountPath": "/usr/local/share/ca-certificates/custom-ca-certificates-{{ $certkey }}",
    "subPath": "{{ $certkey }}"
  },
  {{ end }}
  {{ if $parent.Values.hull.config.general.data.installation.config.certificateSecrets }}
  {{ range $secretKey, $secretData := $parent.Values.hull.config.general.data.installation.config.certificateSecrets }}
  {{ range $secretFile := $secretData.fileNames }}
  "certs-{{ $secretKey }}-{{ $secretFile }}":
  { 
    "enabled": true,
    "name": "certs-{{ $secretKey }}",
    "mountPath": "/usr/local/share/ca-certificates/custom-ca-certificates-{{ $secretKey }}-{{ $secretFile }}",
    "subPath": "{{ $secretFile }}"
  },
  {{ end }}
  {{ end }}
  {{ end }}
  {{ $processedDict := dict }}
  {{ range $file, $_ := $parent.Files.Glob "files/hull-vidispine-addon/installation/sources/**/*" }}
  {{- $folder := base (dir $file) }}
  {{- if not (hasKey $processedDict $folder) -}}
  {{ $_ := set $processedDict $folder "true" }}
  "custom-installation-files-{{ $folder }}":
  {
      "enabled": true, 
      "name": "custom-installation-files-{{ $folder }}",
      "mountPath": "/custom-installation-files-{{ $folder }}"
  },
  {{ end }}
  {{ end }}
}
{{ end }}



{{ define "hull.vidispine.addon.sources.folder.secret" }}
{{ $parent := (index . "PARENT_CONTEXT") }}
{{ $folderIndex := (index . "FOLDER_INDEX") }}
{
  {{ $processedDict := dict }}
  {{ $folderCount := 0 }}
  {{ range $file, $_ := $parent.Files.Glob "files/hull-vidispine-addon/installation/sources/**/*" }}
  {{- $folder := base (dir $file) }}
  {{- $fileName := base $file }}
  {{- if not (hasKey $processedDict $folder) -}}
  {{- $folderCount = add $folderCount 1 }}
  {{ $_ := set $processedDict $folder $folderCount }}
  {{- end -}}
  {{ if (eq (index $processedDict $folder) $folderIndex) }}
  {{ $fileName | base | quote }}: { path: {{ $file | quote }} },
  {{ end }}
  {{ end }}
}
{{ end }}



{{- define "hull.vidispine.addon.sources.folder.secret.count" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $folderIndex := (index . "FOLDER_INDEX") -}}
{{- $processedDict := dict -}}
{{- $folderCount := 0 -}}
{{- $folderExists := false -}}
{{- range $file, $_ := $parent.Files.Glob "files/hull-vidispine-addon/installation/sources/**/*" -}}
{{- $folder := base (dir $file) -}}
{{- if not (hasKey $processedDict $folder) -}}
{{- $folderCount = add $folderCount 1 -}}
{{- $_ := set $processedDict $folder $folderCount -}}
{{- end -}}
{{- end -}}
{{- $folderCount -}}
{{- end -}}