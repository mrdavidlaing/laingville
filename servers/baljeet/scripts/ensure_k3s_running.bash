#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-false}"
if [ "$DRY_RUN" = true ]; then
  echo "Would enable and start k3s via systemd"
  echo "Would print kubectl connection instructions"
  exit 0
fi
echo "[ensure_k3s_running] Forcing enable/start of k3s.service"
set -x
sudo systemctl daemon-reload || true
sudo systemctl enable --now k3s.service || true
rc=$?
set +x
echo "[ensure_k3s_running] systemctl exit code: $rc"
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  mkdir -p "$HOME/.kube"
  sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
  sudo chown "$USER":"$USER" "$HOME/.kube/config"
fi
IP=$(ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)
[ -n "$IP" ] || IP="<server-ip>"
if [ -f /var/lib/rancher/k3s/server/node-token ]; then
  TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
else
  TOKEN="<node-token>"
fi
cat <<EOF
To use kubectl from this server or another machine:
1) kubeconfig on this server is at ~/.kube/config
2) If needed, set server to https://$IP:6443 in that file
3) From another machine, copy this file securely and update the server IP
4) Alternatively, create a token-based context:
   kubectl config set-cluster baljeet --server=https://$IP:6443 --certificate-authority=/etc/rancher/k3s/k3s.crt
   kubectl config set-credentials baljeet-user --token=$TOKEN
   kubectl config set-context baljeet --cluster=baljeet --user=baljeet-user
   kubectl config use-context baljeet
EOF
