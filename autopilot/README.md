# OpenShift 4 Getting Started Workshop - Automation Script

This script (`autopilot.sh`) automates the entire OpenShift 4 Getting Started Workshop end-to-end, executing all the hands-on lab steps using `oc` CLI commands.

## Overview

The script automates the following workshop components:

1. **Environment Setup** - Login to OpenShift and project creation
2. **ParksMap Frontend** - Deploy container image, scaling, routes, permissions
3. **NationalParks Backend** - Deploy using Source-to-Image (S2I) build process
4. **MongoDB Database** - Deploy and configure database with secrets
5. **Database Integration** - Connect backend to database with environment variables
6. **Service Discovery** - Configure service discovery between frontend and backend
7. **Health Checks** - Add liveness and readiness probes
8. **CI/CD Pipeline** - Create Tekton pipeline for automated builds (if available)
9. **Webhook Integration** - Configure Gitea webhooks for automatic pipeline triggers

## Prerequisites

- OpenShift 4.x cluster with admin or developer access
- `oc` CLI installed and configured
- `curl` and `jq` utilities (optional, for testing)
- OpenShift Pipelines operator (optional, for CI/CD pipeline)

## Configuration

The script will interactively prompt you for all required configuration values when you run it. No manual editing is required! You'll be asked for:

**OpenShift Cluster Details:**
- OpenShift API Server URL (e.g., `https://api.cluster.example.com:6443`)
- OpenShift Apps Domain (e.g., `apps.cluster.example.com`)
- OpenShift Username
- OpenShift Password (entered securely, not displayed)

**Gitea Repository Details:**
- Gitea URL (e.g., `https://gitea.apps.cluster.example.com`)
- Gitea Username
- Gitea Password (entered securely, not displayed)

The script will display a summary of your configuration and ask for confirmation before proceeding.

## Usage

1. **Make the script executable:**
   ```bash
   chmod +x autopilot.sh
   ```

2. **Run the script:**
   ```bash
   ./autopilot.sh
   ```

The script will:
- **Interactively prompt** for all required configuration values
- **Display a summary** and ask for confirmation before proceeding
- **Provide colored output** to track progress through each step
- **Wait for deployments** to be ready before proceeding to the next step
- **Handle errors gracefully** and exit on failures with clear error messages
- **Display a summary** of deployed resources at the end

## Script Steps

### Step 1: OpenShift Login
- Authenticates with the OpenShift cluster
- Creates or switches to the workshop project

### Step 2: ParksMap Frontend Deployment
- Deploys the ParksMap web application using a pre-built container image
- Scales the application to 2 replicas
- Creates an edge-terminated route for external access
- Grants service account permissions for service discovery

### Step 3: NationalParks Backend Deployment
- Uses Source-to-Image (S2I) to build the Java application from source
- Monitors the build process and waits for completion
- Deploys the built application

### Step 4: MongoDB Database Setup
- Creates Kubernetes secrets for database credentials
- Deploys MongoDB 6.0.4 with proper environment variables
- Creates application database user with appropriate permissions

### Step 5: Database Integration
- Configures NationalParks backend with database connection details
- Uses secrets for secure credential management
- Restarts the application with new configuration

### Step 6: Data Loading and Service Discovery
- Creates a route for the NationalParks backend
- Loads initial park data into the database
- Configures service discovery labels and annotations
- Restarts ParksMap to discover the new backend

### Step 7: Health Checks
- Adds liveness and readiness probes to the NationalParks application
- Configures proper health check endpoints and timing

### Step 8: CI/CD Pipeline (Optional)
- Creates a Tekton pipeline for automated builds
- Sets up workspaces and PersistentVolumeClaim for pipeline execution
- Includes tasks for: git clone, Maven build/test, image build, and deployment
- Creates Tekton Triggers (TriggerTemplate, TriggerBinding, EventListener)
- Configures Gitea webhook for automatic pipeline execution on code changes

## Expected Results

Upon successful completion, the script will deploy:

- **ParksMap Frontend** - Web application showing an interactive map
- **NationalParks Backend** - REST API serving park location data
- **MongoDB Database** - Persistent storage for park data
- **Routes** - External access to both applications
- **Pipeline** - CI/CD pipeline for future updates (if OpenShift Pipelines is available)

## Accessing the Application

After the script completes, you can access:

- **ParksMap Application**: `https://parksmap-wksp-{user}.{apps-domain}`
- **NationalParks API**: `https://nationalparks-wksp-{user}.{apps-domain}`
- **Gitea Repository**: `https://gitea.{apps-domain}/{user}/nationalparks`
- **OpenShift Console**: Check the Topology view for visual representation

## Testing Webhook Integration

To test the automated CI/CD pipeline with webhooks:

1. **Access Gitea Repository**: Navigate to `https://gitea.{apps-domain}/{user}/nationalparks`
2. **Login**: Use your Gitea credentials
3. **Edit Code**: Modify `src/main/java/com/openshift/evg/roadshow/parks/rest/BackendController.java`
4. **Change Line 20**: From `"National Parks"` to `"Amazing National Parks"`
5. **Commit Changes**: This will automatically trigger the pipeline
6. **Monitor Pipeline**: Run `oc get pipelineruns -w` to watch the pipeline execution
7. **Verify Results**: Check `https://nationalparks-wksp-{user}.{apps-domain}/ws/info/` for the updated name

## Troubleshooting

### Common Issues:

1. **Authentication Failures**: Verify OpenShift credentials and server URL
2. **Build Failures**: Check if the source repository is accessible
3. **Database Connection Issues**: Ensure MongoDB is fully started before backend deployment
4. **Route Access Issues**: Verify the apps domain is correctly configured

### Debugging Commands:

```bash
# Check deployment status
oc get deployments

# Check pod logs
oc logs deployment/parksmap
oc logs deployment/nationalparks
oc logs deployment/mongodb

# Check routes
oc get routes

# Check services
oc get services

# Check pipeline status (if created)
oc get pipelines
oc get pipelineruns
```

## Customization

The script can be easily customized for different environments:

- Modify the Git repository URL for different application versions
- Adjust resource limits and requests
- Change database configurations
- Add additional applications or services
- Modify pipeline tasks for different build processes

## Architecture

The deployed application follows this architecture:

```
[Internet] → [OpenShift Router] → [ParksMap Frontend] → [NationalParks Backend] → [MongoDB Database]
```

- **ParksMap**: Web frontend that displays parks on a map
- **NationalParks**: REST API that serves park data from MongoDB
- **MongoDB**: Database storing park location and information data
- **Service Discovery**: Automatic discovery of backend services by the frontend

## Security

The script implements several security best practices:

- Uses Kubernetes secrets for database credentials
- Configures TLS-terminated routes
- Implements proper RBAC with service accounts
- Uses non-root containers
- Implements health checks for application reliability

## Additional Resources

- [OpenShift Documentation](https://docs.openshift.com/)
- [OpenShift Pipelines Documentation](https://docs.openshift.com/container-platform/latest/cicd/pipelines/understanding-openshift-pipelines.html)
- [Source-to-Image Documentation](https://docs.openshift.com/container-platform/latest/builds/understanding-image-builds.html#build-strategy-s2i_understanding-image-builds)
- [Original Workshop Content](https://github.com/openshift-roadshow) 