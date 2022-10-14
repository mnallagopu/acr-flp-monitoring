# acr-flp-monitoring
ACR READINESS LABS - Monitoring


az monitor diagnostic-settings create  \
--name ACR-Diagnostics \
--resource $ACR_ID \
--workspace $ACR_LAWS_ID  \
--logs    '[{"category": "ContainerRegistryLoginEvents","enabled": true}]' \
--metrics '[{"category": "AllMetrics","enabled": true}]'
