# templates/_helpers.tpl
{{- define "pghero.fullname" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "pghero.labels" -}}
app: {{ .Release.Name }}
{{- end -}}