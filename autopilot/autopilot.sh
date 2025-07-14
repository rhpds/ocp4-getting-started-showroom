#!/bin/bash

set -e

# OpenShift 4 Getting Started Workshop - End-to-End Automation Script
# This script automates the entire hands-on lab as described in the workshop content

# OPENSHIFT_SERVER=https://api.cluster.example.com:6443
# OPENSHIFT_USER=user1
# OPENSHIFT_PASSWORD=password
# GITEA_URL=https://gitea.apps.cluster-example.com

# Color codes for output (defined early for input prompts)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Interactive configuration - prompt for user input
print_step "OpenShift 4 Getting Started Workshop - Configuration"
echo ""
echo "Please provide the following configuration details:"
echo ""

# OpenShift Cluster Configuration
if [ -z "$OPENSHIFT_SERVER" ]; then
    read -p "OpenShift API Server URL (e.g., https://api.cluster.example.com:6443): " OPENSHIFT_SERVER
else
    echo "Using pre-configured OpenShift Server: $OPENSHIFT_SERVER"
fi
if [ -z "$OPENSHIFT_SERVER" ]; then
    print_error "OpenShift server URL is required"
    exit 1
fi

if [ -z "$OPENSHIFT_USER" ]; then
    read -p "OpenShift Username: " OPENSHIFT_USER
else
    echo "Using pre-configured OpenShift User: $OPENSHIFT_USER"
fi
if [ -z "$OPENSHIFT_USER" ]; then
    print_error "OpenShift username is required"
    exit 1
fi

if [ -z "$OPENSHIFT_PASSWORD" ]; then
    read -p "OpenShift Password: " OPENSHIFT_PASSWORD
    echo ""
else
    echo "Using pre-configured OpenShift Password: [HIDDEN]"
    echo ""
fi
if [ -z "$OPENSHIFT_PASSWORD" ]; then
    print_error "OpenShift password is required"
    exit 1
fi

# Gitea Configuration
if [ -z "$GITEA_URL" ]; then
    read -p "Gitea URL (e.g., https://gitea.apps.cluster.example.com): " GITEA_URL
else
    echo "Using pre-configured Gitea URL: $GITEA_URL"
fi
if [ -z "$GITEA_URL" ]; then
    print_error "Gitea URL is required"
    exit 1
fi

# Derived and default configuration
GITEA_USER="${OPENSHIFT_USER}"
GITEA_PASSWORD="${OPENSHIFT_PASSWORD}"
PROJECT_NAME="wksp-${OPENSHIFT_USER}"
PARKSMAP_IMAGE="quay.io/openshiftroadshow/parksmap:latest"
NATIONALPARKS_REPO="https://github.com/openshift-roadshow/nationalparks.git"

# Display configuration summary
echo ""
print_step "Configuration Summary"
echo "OpenShift Server: $OPENSHIFT_SERVER"
echo "OpenShift User: $OPENSHIFT_USER"
echo "Project Name: $PROJECT_NAME"
echo "Gitea URL: $GITEA_URL"
echo "Gitea User: $GITEA_USER"
echo ""
read -p "Continue with these settings? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_warning "Operation cancelled by user"
    exit 0
fi



# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment_name=$1
    local namespace=${2:-$PROJECT_NAME}
    
    print_step "Waiting for deployment $deployment_name to be ready..."
    oc rollout status deployment/$deployment_name -n $namespace --timeout=300s
    if [ $? -eq 0 ]; then
        print_success "Deployment $deployment_name is ready"
    else
        print_error "Deployment $deployment_name failed to become ready"
        exit 1
    fi
}

# Function to wait for build to complete
wait_for_build() {
    local build_name=$1
    
    print_step "Waiting for build $build_name to complete..."
    oc logs -f build/$build_name
    
    sleep 5
    # Check if build was successful
    local build_status=$(oc get build $build_name -o jsonpath='{.status.phase}')
    if [ "$build_status" = "Complete" ]; then
        print_success "Build $build_name completed successfully"
    else
        print_error "Build $build_name failed with status: $build_status"
        exit 1
    fi
}

# Main script execution
print_step "Starting OpenShift 4 Getting Started Workshop Automation"

# Step 1: Login to OpenShift
print_step "Step 1: Logging into OpenShift cluster"
oc login --insecure-skip-tls-verify=true -u $OPENSHIFT_USER -p $OPENSHIFT_PASSWORD $OPENSHIFT_SERVER
if [ $? -eq 0 ]; then
    print_success "Successfully logged into OpenShift"
else
    print_error "Failed to login to OpenShift"
    exit 1
fi

# Step 2: Create or switch to project
print_step "Step 2: Setting up project"
oc project $PROJECT_NAME 2>/dev/null || oc new-project $PROJECT_NAME
print_success "Using project: $PROJECT_NAME"

# Step 3: Deploy ParksMap Frontend Application
print_step "Step 3: Deploying ParksMap frontend application"
oc new-app --name=parksmap \
    --image=$PARKSMAP_IMAGE \
    --labels="app=workshop,component=parksmap,role=frontend"

wait_for_deployment "parksmap"
print_success "ParksMap application deployed successfully"

# Step 4: Scale the application
print_step "Step 4: Scaling ParksMap application to 2 replicas"
oc scale --replicas=2 deployment/parksmap
sleep 10
oc get pods -l app=parksmap
print_success "ParksMap application scaled to 2 replicas"

# Step 5: Create route for ParksMap
print_step "Step 5: Creating route for ParksMap application"
oc create route edge parksmap --service=parksmap
PARKSMAP_URL=$(oc get route parksmap -o jsonpath='{.spec.host}')
print_success "ParksMap route created: https://$PARKSMAP_URL"

# Step 6: Grant service account permissions
print_step "Step 6: Granting view permissions to default service account"
oc policy add-role-to-user view -z default
oc rollout restart deployment/parksmap
wait_for_deployment "parksmap"
print_success "Service account permissions granted and application restarted"

# Step 7: Deploy NationalParks Backend Application
print_step "Step 7: Deploying NationalParks backend application"
oc new-app --name=nationalparks \
    --image-stream=java:openjdk-11-ubi8 \
    --code=$GITEA_URL/$GITEA_USER/nationalparks.git \
    --labels="app=workshop,component=nationalparks,role=backend"

# Wait for build to start
sleep 10
BUILD_NAME=$(oc get builds --no-headers -o custom-columns=":metadata.name" | head -1)
if [ -n "$BUILD_NAME" ]; then
    wait_for_build "$BUILD_NAME"
    wait_for_deployment "nationalparks"
    print_success "NationalParks backend application deployed successfully"
else
    print_error "Failed to find build for nationalparks"
    exit 1
fi

# Step 8: Deploy MongoDB Database
print_step "Step 8: Deploying MongoDB database"

# Create MongoDB credentials secret
oc create secret generic mongodb-credentials \
    --from-literal=admin-usr=admin \
    --from-literal=admin-pwd=secret \
    --from-literal=app-usr=parksapp \
    --from-literal=app-pwd=keepsafe \
    2>/dev/null || echo "Secret already exists or created"

# Deploy MongoDB and then configure environment variables from secret
oc new-app --name=mongodb \
    --image=docker.io/library/mongo:6.0.4 \
    --labels="app=workshop,component=nationalparks,role=database"

# Wait for the initial deployment to be created
sleep 5

# Patch the deployment to use secret environment variables
oc patch deployment/mongodb -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "mongodb",
          "env": [
            {
              "name": "MONGO_INITDB_ROOT_USERNAME",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "mongodb-credentials",
                  "key": "admin-usr"
                }
              }
            },
            {
              "name": "MONGO_INITDB_ROOT_PASSWORD",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "mongodb-credentials",
                  "key": "admin-pwd"
                }
              }
            }
          ]
        }]
      }
    }
  }
}'

wait_for_deployment "mongodb"
print_success "MongoDB database deployed successfully"

# Step 9: Configure database user and connection
print_step "Step 9: Configuring database user and connection"

# Create database user (wait for MongoDB to be fully ready)
sleep 20
MONGODB_POD=$(oc get pods -l deployment=mongodb --no-headers -o custom-columns=":metadata.name" | head -1)
oc exec $MONGODB_POD -- mongosh -u admin -p secret --authenticationDatabase admin --eval 'use parksapp' --eval 'db.createUser({user: "parksapp", pwd: "keepsafe", roles: [{ role: "dbAdmin", db: "parksapp" },{ role: "readWrite", db: "parksapp" }]})' --quiet

# Update NationalParks deployment with database environment variables
oc patch deployment/nationalparks -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nationalparks",
          "env": [
            {
              "name": "MONGODB_SERVER_HOST",
              "value": "mongodb"
            },
            {
              "name": "MONGODB_DATABASE",
              "value": "parksapp"
            },
            {
              "name": "MONGODB_USER",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "mongodb-credentials",
                  "key": "app-usr"
                }
              }
            },
            {
              "name": "MONGODB_PASSWORD",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "mongodb-credentials",
                  "key": "app-pwd"
                }
              }
            }
          ]
        }]
      }
    }
  }
}'

wait_for_deployment "nationalparks"
print_success "Database connection configured successfully"

# Step 10: Create route for NationalParks and load data
print_step "Step 10: Creating route for NationalParks and loading data"
oc create route edge nationalparks --service=nationalparks
NATIONALPARKS_URL=$(oc get route nationalparks -o jsonpath='{.spec.host}')
print_success "NationalParks route created: https://$NATIONALPARKS_URL"

# Wait for application to be ready and load data
print_step "Loading initial data into database"
sleep 30
curl -k "https://$NATIONALPARKS_URL/ws/data/load" || print_warning "Data load may have failed, continuing..."

# Verify data was loaded
DATA_COUNT=$(curl -k -s "https://$NATIONALPARKS_URL/ws/data/all" | jq '. | length' 2>/dev/null || echo "0")
if [ "$DATA_COUNT" -gt "0" ]; then
    print_success "Data loaded successfully: $DATA_COUNT records"
else
    print_warning "Data loading may have failed or is still in progress"
fi

# Step 11: Configure service discovery labels
print_step "Step 11: Configuring service discovery labels"
oc label service nationalparks "type=parksmap-backend"
oc annotate service nationalparks "getmap.parksmap.io/url=https://$NATIONALPARKS_URL/ws/data/all"

# Restart parksmap to pick up the new backend
oc rollout restart deployment/parksmap
wait_for_deployment "parksmap"
print_success "Service discovery configured successfully"

# Step 12: Add health checks to NationalParks
print_step "Step 12: Adding health checks to NationalParks application"
oc patch deployment/nationalparks -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nationalparks",
          "livenessProbe": {
            "httpGet": {
              "path": "/ws/healthz/",
              "port": 8080,
              "scheme": "HTTP"
            },
            "initialDelaySeconds": 120,
            "timeoutSeconds": 1,
            "periodSeconds": 10,
            "successThreshold": 1,
            "failureThreshold": 3
          },
          "readinessProbe": {
            "httpGet": {
              "path": "/ws/healthz/",
              "port": 8080,
              "scheme": "HTTP"
            },
            "initialDelaySeconds": 20,
            "timeoutSeconds": 1,
            "periodSeconds": 10,
            "successThreshold": 1,
            "failureThreshold": 3
          }
        }]
      }
    }
  }
}'

wait_for_deployment "nationalparks"
print_success "Health checks added successfully"

# Step 13: Create CI/CD Pipeline (if OpenShift Pipelines is available)
print_step "Step 13: Setting up CI/CD Pipeline"
if true; then
    print_step "Creating Tekton Pipeline for NationalParks"
    
    # Create pipeline workspace PVC
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-source-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

    # Create the pipeline
    cat <<EOF | oc apply -f -
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: nationalparks-pipeline
spec:
  params:
    - default: nationalparks
      name: APP_NAME
      type: string
    - default: $GITEA_URL/$GITEA_USER/nationalparks.git
      description: The application git repository url
      name: APP_GIT_URL
      type: string
    - default: master
      description: The application git repository revision
      name: APP_GIT_REVISION
      type: string
  tasks:
    - name: git-clone
      params:
        - name: URL
          value: \$(params.APP_GIT_URL)
        - name: REVISION
          value: \$(params.APP_GIT_REVISION)
        - name: SUBMODULES
          value: 'true'
        - name: DEPTH
          value: '1'
        - name: SSL_VERIFY
          value: 'false'
        - name: DELETE_EXISTING
          value: 'true'
        - name: VERBOSE
          value: 'true'
      taskRef:
        kind: Task
        name: git-clone
      workspaces:
        - name: output
          workspace: app-source
    - name: build-and-test
      params:
        - name: MAVEN_IMAGE
          value: maven:3.8.3-openjdk-11
        - name: GOALS
          value:
            - package
        - name: PROXY_PROTOCOL
          value: http
      runAfter:
        - git-clone
      taskRef:
        kind: Task
        name: maven
      workspaces:
        - name: source
          workspace: app-source
        - name: maven_settings
          workspace: maven-settings
    - name: build-image
      params:
        - name: IMAGE
          value: image-registry.openshift-image-registry.svc:5000/\$(context.pipelineRun.namespace)/\$(params.APP_NAME):latest
        - name: BUILDER_IMAGE
          value: registry.redhat.io/rhel8/buildah:latest
        - name: STORAGE_DRIVER
          value: vfs
        - name: DOCKERFILE
          value: ./Dockerfile
        - name: CONTEXT
          value: .
        - name: TLSVERIFY
          value: 'true'
        - name: FORMAT
          value: oci
      runAfter:
        - build-and-test
      taskRef:
        kind: Task
        name: buildah
      workspaces:
        - name: source
          workspace: app-source
    - name: redeploy
      params:
        - name: SCRIPT
          value: oc rollout restart deployment/\$(params.APP_NAME)
      runAfter:
        - build-image
      taskRef:
        kind: Task
        name: openshift-client
  workspaces:
    - name: app-source
    - name: maven-settings
EOF

    print_success "Pipeline created successfully"
    
    # Step 13b: Create Tekton Triggers for webhook automation
    print_step "Step 13b: Creating Tekton Triggers for webhook automation"
    
    # Use the existing triggers YAML from the workshop repository
    oc create -f $GITEA_URL/$GITEA_USER/nationalparks/raw/branch/master/pipeline/nationalparks-triggers.yaml -n $PROJECT_NAME
    
    print_success "Tekton Triggers created successfully"
    
    # Wait for EventListener to be ready
    sleep 10
    wait_for_deployment "el-nationalparks"
    
    EVENTLISTENER_URL=$(oc get route el-nationalparks -o jsonpath='{.spec.host}')
    print_success "EventListener route created: http://$EVENTLISTENER_URL"
        
    # Step 13c: Configure Gitea webhook
    print_step "Step 13c: Configuring Gitea webhook"
    
    # Create webhook in Gitea using API
    WEBHOOK_URL="http://$EVENTLISTENER_URL/"
    GITEA_REPO_URL="$GITEA_URL/$GITEA_USER/nationalparks"
    
    print_step "Creating webhook in Gitea repository"
    print_step "Repository: $GITEA_REPO_URL"
    print_step "Webhook URL: $WEBHOOK_URL"
    
    # Create webhook using curl (requires Gitea API access)
    WEBHOOK_PAYLOAD=$(cat <<EOF
{
  "type": "gitea",
  "config": {
    "url": "$WEBHOOK_URL",
    "content_type": "json",
    "secret": ""
  },
  "events": ["push"],
  "active": true
}
EOF
)
    
    # Try to create webhook via API
    WEBHOOK_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$WEBHOOK_PAYLOAD" \
        "$GITEA_URL/api/v1/repos/$GITEA_USER/nationalparks/hooks" \
        -u "$GITEA_USER:$GITEA_PASSWORD" 2>/dev/null || echo "")
    
    if [ -n "$WEBHOOK_RESPONSE" ] && echo "$WEBHOOK_RESPONSE" | grep -q "id"; then
        print_success "Webhook created successfully in Gitea"
    else
        print_warning "Could not automatically create webhook in Gitea"
        print_step "Manual webhook setup required:"
        print_step "1. Go to: $GITEA_REPO_URL/settings/hooks"
        print_step "2. Add webhook with URL: $WEBHOOK_URL"
        print_step "3. Set content type to: application/json"
        print_step "4. Login with user: $GITEA_USER, password: $GITEA_PASSWORD"
    fi
    
else
    print_warning "OpenShift Pipelines not available, skipping pipeline creation"
fi

# Step 14: Final verification and summary
print_step "Step 14: Final verification and summary"

echo ""
echo "=== DEPLOYMENT SUMMARY ==="
echo "Project: $PROJECT_NAME"
echo "ParksMap Frontend: https://$PARKSMAP_URL"
echo "NationalParks Backend: https://$NATIONALPARKS_URL"
echo "Gitea Repository: $GITEA_URL/$GITEA_USER/nationalparks"
if [ -n "$EVENTLISTENER_URL" ]; then
    echo "Pipeline EventListener: http://$EVENTLISTENER_URL"
fi
echo ""

# Check all deployments
echo "Checking deployment status..."
oc get deployments
echo ""

# Check routes
echo "Available routes:"
oc get routes
echo ""

# Check services
echo "Available services:"
oc get services
echo ""

# Check pods
echo "Running pods:"
oc get pods
echo ""

print_success "OpenShift 4 Getting Started Workshop completed successfully!"
print_step "You can now access the ParksMap application at: https://$PARKSMAP_URL"
print_step "The application should show a map with national parks data loaded from the backend"

# Optional: Test the complete application
print_step "Testing complete application stack..."
if curl -k -s "https://$PARKSMAP_URL" >/dev/null 2>&1; then
    print_success "ParksMap frontend is accessible"
else
    print_warning "ParksMap frontend may not be fully ready yet"
fi

if curl -k -s "https://$NATIONALPARKS_URL/ws/data/all" >/dev/null 2>&1; then
    print_success "NationalParks backend is accessible"
else
    print_warning "NationalParks backend may not be fully ready yet"
fi

print_step "Lab automation completed! Check the applications in your OpenShift console."

# Step 15: Provide webhook testing instructions
if [ -n "$EVENTLISTENER_URL" ]; then
    print_step "Step 15: Testing webhook functionality"
    echo ""
    echo "To test the webhook integration:"
    echo "1. Go to: $GITEA_URL/$GITEA_USER/nationalparks"
    echo "2. Login with: $GITEA_USER / $GITEA_PASSWORD"
    echo "3. Edit file: src/main/java/com/openshift/evg/roadshow/parks/rest/BackendController.java"
    echo "4. Change line 20 from:"
    echo "   return new Backend(\"nationalparks\",\"National Parks\", new Coordinates(\"47.039304\", \"14.505178\"), 4);"
    echo "   to:"
    echo "   return new Backend(\"nationalparks\",\"Amazing National Parks\", new Coordinates(\"47.039304\", \"14.505178\"), 4);"
    echo "5. Commit the changes"
    echo "6. Watch the pipeline run automatically: oc get pipelineruns -w"
    echo "7. Verify the change: https://$NATIONALPARKS_URL/ws/info/"
    echo ""
fi 