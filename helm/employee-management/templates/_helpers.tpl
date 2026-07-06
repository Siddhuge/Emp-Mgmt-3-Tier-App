{{/* Chart name */}}
{{- define "ems.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Fully-qualified app name */}}
{{- define "ems.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ems.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels applied to every object */}}
{{- define "ems.labels" -}}
helm.sh/chart: {{ include "ems.chart" . }}
app.kubernetes.io/name: {{ include "ems.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: employee-management
environment: {{ .Values.global.environment | quote }}
{{- end -}}

{{/* Per-component selector labels. Call with (dict "ctx" . "component" "backend") */}}
{{- define "ems.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ems.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Component object name, e.g. <release>-employee-management-backend */}}
{{- define "ems.componentName" -}}
{{- printf "%s-%s" (include "ems.fullname" .ctx) .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* ServiceAccount name */}}
{{- define "ems.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ems.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Names of the shared ConfigMap and Secret */}}
{{- define "ems.configMapName" -}}{{ printf "%s-config" (include "ems.fullname" .) }}{{- end -}}
{{- define "ems.secretName" -}}
{{- if .Values.secrets.existingSecret -}}{{ .Values.secrets.existingSecret }}{{- else -}}{{ printf "%s-secret" (include "ems.fullname" .) }}{{- end -}}
{{- end -}}

{{/* Postgres headless service name (stable network identity) */}}
{{- define "ems.postgresService" -}}{{ include "ems.componentName" (dict "ctx" . "component" "postgres") }}{{- end -}}

{{/* Assembled image reference for a component */}}
{{- define "ems.image" -}}
{{- $reg := .root.Values.image.registry -}}
{{- printf "%s/%s:%s" $reg .cfg.image.repository (.cfg.image.tag | toString) -}}
{{- end -}}

{{/*
Pod anti-affinity block. Call with (dict "ctx" . "component" "backend").
- soft: preferred spreading (still schedules if a node is short)
- hard: required spreading (one replica per node)
*/}}
{{- define "ems.affinity" -}}
{{- $mode := .ctx.Values.podAntiAffinity -}}
affinity:
  podAntiAffinity:
  {{- if eq $mode "hard" }}
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            {{- include "ems.selectorLabels" (dict "ctx" .ctx "component" .component) | nindent 12 }}
  {{- else }}
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              {{- include "ems.selectorLabels" (dict "ctx" .ctx "component" .component) | nindent 14 }}
  {{- end }}
{{- end -}}
