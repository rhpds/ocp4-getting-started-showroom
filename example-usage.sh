#!/bin/bash

# Example Usage Script for OpenShift 4 Getting Started Workshop Automation
# This script demonstrates how to configure and run the automation script

# Step 1: Interactive Configuration
echo "=== OpenShift 4 Getting Started Workshop Automation ==="
echo ""
echo "The script will interactively prompt you for configuration details:"
echo ""

# Show what will be prompted
cat << 'EOF'
When you run the script, you'll be prompted for:

OpenShift Cluster Details:
- OpenShift API Server URL (e.g., https://api.your-cluster.example.com:6443)
- OpenShift Apps Domain (e.g., apps.your-cluster.example.com)
- OpenShift Username
- OpenShift Password (entered securely)

Gitea Repository Details:
- Gitea URL (e.g., https://gitea.apps.your-cluster.example.com)
- Gitea Username  
- Gitea Password (entered securely)

The script will show a summary and ask for confirmation before proceeding.
EOF

echo ""
echo "Step 2: Run the script:"
echo "  chmod +x run-ocp4-lab.sh"
echo "  ./run-ocp4-lab.sh"
echo ""
echo "Step 3: Follow the interactive prompts"
echo "  - Enter your OpenShift and Gitea credentials when prompted"
echo "  - Review the configuration summary"
echo "  - Confirm to proceed with the automation"
echo ""
echo "Step 4: Monitor the progress and check the results"
echo "  - The script provides colored output showing each step"
echo "  - Deployments are automatically monitored for readiness"
echo "  - At the end, you'll see a summary of deployed resources"
echo ""
echo "Step 5: Access your applications:"
echo "  - ParksMap Frontend: https://parksmap-wksp-{user}.{apps-domain}"
echo "  - NationalParks API: https://nationalparks-wksp-{user}.{apps-domain}"
echo "  - Gitea Repository: https://gitea.{apps-domain}/{user}/nationalparks"
echo "  - OpenShift Console: https://console.{apps-domain}"
echo ""

# Optional: Check prerequisites
echo "=== Prerequisites Check ==="
echo ""

# Check if oc CLI is installed
if command -v oc &> /dev/null; then
    echo "✓ oc CLI is installed: $(oc version --client 2>/dev/null | head -1 || echo 'version available')"
else
    echo "✗ oc CLI is not installed. Please install it first."
    echo "  Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
fi

# Check if curl is installed
if command -v curl &> /dev/null; then
    echo "✓ curl is installed: $(curl --version | head -1)"
else
    echo "✗ curl is not installed. Please install it for testing functionality."
fi

# Check if jq is installed (optional)
if command -v jq &> /dev/null; then
    echo "✓ jq is installed: $(jq --version)"
else
    echo "⚠ jq is not installed. This is optional but recommended for JSON parsing."
fi

echo ""
echo "=== Ready to Run! ==="
echo "No manual editing required! Simply execute:"
echo "  ./run-ocp4-lab.sh"
echo ""
echo "The script will guide you through the configuration process."
echo "" 