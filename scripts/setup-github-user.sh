#!/bin/bash
# Setup GitHub user for CI/CD operations
# Run this script on the VPS as leonidas user

set -e

echo "========================================="
echo "Setup GitHub CI/CD User"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo "❌ Please run as normal user (leonidas), not as root"
   exit 1
fi

echo "=== Step 1: Creating github user ==="
sudo useradd -m -s /bin/bash github 2>/dev/null || echo "User github already exists"

echo ""
echo "=== Step 2: Adding github to docker group ==="
# We'll add to docker group even if docker isn't installed yet
sudo usermod -aG docker github 2>/dev/null || echo "docker group doesn't exist yet (will be created when Docker is installed)"

echo ""
echo "=== Step 3: Configuring passwordless sudo ==="
echo "github ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/github
sudo chmod 0440 /etc/sudoers.d/github

echo ""
echo "=== Step 4: Verifying sudoers syntax ==="
sudo visudo -c
if [ $? -eq 0 ]; then
    echo "✅ Sudoers configuration is valid"
else
    echo "❌ Sudoers configuration has errors"
    sudo rm /etc/sudoers.d/github
    exit 1
fi

echo ""
echo "=== Step 5: Creating SSH directory ==="
sudo mkdir -p /home/github/.ssh
sudo chown github:github /home/github/.ssh
sudo chmod 700 /home/github/.ssh

echo ""
echo "=== Step 6: Generating SSH key ==="
sudo -u github ssh-keygen -t ed25519 -C "github-actions@codespartan" -f /home/github/.ssh/id_ed25519 -N ""

echo ""
echo "=== Step 7: Authorizing SSH key ==="
sudo -u github cat /home/github/.ssh/id_ed25519.pub | sudo -u github tee /home/github/.ssh/authorized_keys
sudo -u github chmod 600 /home/github/.ssh/authorized_keys

echo ""
echo "=== Step 8: Testing sudo access ==="
sudo -u github sudo whoami
if [ $? -eq 0 ]; then
    echo "✅ Passwordless sudo is working correctly"
else
    echo "❌ Passwordless sudo failed"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Copy the SSH PRIVATE KEY below and add it to GitHub Secrets"
echo "   - Go to: https://github.com/TechnoSpartan/iac-code-spartan/settings/secrets/actions"
echo "   - Update secret: VPS_SSH_KEY"
echo "   - Update secret: VPS_SSH_USER to 'github'"
echo ""
echo "2. SSH PRIVATE KEY (copy everything between the lines):"
echo "========================================="
sudo cat /home/github/.ssh/id_ed25519
echo "========================================="
echo ""
echo "3. Test the connection from your local machine:"
echo "   ssh -i <path-to-key> github@91.98.137.217"
echo ""
echo "4. Update GitHub Secrets:"
echo "   VPS_SSH_USER=github"
echo "   VPS_SSH_KEY=<paste the private key above>"
echo ""
