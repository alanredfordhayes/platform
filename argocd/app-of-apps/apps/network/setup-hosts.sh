#!/bin/bash
# Setup script to add platform domains to /etc/hosts

HOSTS_ENTRIES="
# Platform Applications - Added by setup script
127.0.0.1 argocd.localhost
127.0.0.1 vault.localhost
127.0.0.1 dashboard.localhost
127.0.0.1 platform.localhost
"

echo "Adding platform domains to /etc/hosts..."
echo "$HOSTS_ENTRIES" | sudo tee -a /etc/hosts

echo ""
echo "✅ Hosts file updated!"
echo ""
echo "Next steps:"
echo "1. Port-forward Traefik: kubectl port-forward -n traefik svc/traefik 80:80"
echo "2. Access applications:"
echo "   - Platform Landing: http://localhost or http://platform.localhost"
echo "   - Argo CD: http://argocd.localhost"
echo "   - Vault: http://vault.localhost"
echo "   - Traefik Dashboard: http://dashboard.localhost/dashboard/"

