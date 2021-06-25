---
{{- define "hull.vidispine.addon.transformation" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $source := (index . "SOURCE") -}}
{{- $caller := default nil (index . "CALLER") -}}
{{- $callerKey := default nil (index . "CALLER_KEY") -}}
{{- if typeIs "map[string]interface {}" $source -}}
    {{- range $key,$value := $source -}}
        {{- if typeIs "map[string]interface {}" $value -}}
            {{- if hasKey $value "_HULL_TRANSFORMATION_" -}}
                {{- $params := $value._HULL_TRANSFORMATION_ -}}
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
{{ $key }}:
{{- range $u := (index $parent.Values "hull").config.general.data.installation.productUris }}
{{- range $a := $appends }}
- {{ printf "%s%s" $u $a -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "hull.vidispine.addon.coruris" -}}
{{- $parent := (index . "PARENT_CONTEXT") -}}
{{- $key := (index . "KEY") -}}
{{- $c := list -}}
{{ $key }}:
{{- range (index $parent.Values "hull").config.general.data.installation.productUris }}
- {{ printf "%s://%s"  (index (. | urlParse) "scheme") (index (. | urlParse) "host") }}
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