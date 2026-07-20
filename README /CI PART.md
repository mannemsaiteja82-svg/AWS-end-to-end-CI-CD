# AWS End-to-End Continuous Integration (CI) Pipeline Project

This project establishes a fully automated, managed Continuous Integration (CI) framework on AWS. 
Every code commit pushed to GitHub automatically triggers automated dependency tracking, containerizes the underlying Flask application, and deploys the production-ready image securely to Docker Hub.

---

🛠️ CI Services & Key Benefits

We utilize natively managed **AWS DevOps services** alongside popular industry-standard version control systems and container registries to construct a secure, lightweight architecture:

*   GitHub: Acts as our central source control management (SCM) server holding application logic and configuration templates.
    *   Benefit: High availability, extensive community marketplace integrations, and standard webhooks support.
*   AWS CodePipeline: Acts as our continuous integration workflow orchestrator. 
    *   Benefit: Fully managed, removes complex operational master infrastructure administration tasks (like Jenkins masters), and charges entirely based on dynamic workflow usage duration.
*   AWS CodeBuild: Compiles source data, runs dependency updates, and produces production-ready build artifacts inside ephemeral execution nodes.
    *   Benefit: Naturally scalable container environment that self-terminates post-build, ensuring you only pay for active compute uptime.
*   AWS Systems Manager (SSM) Parameter Store**: Provides a secured, centralized key-value database for structural environment configuration variables and encrypted strings.
    *   Benefit: Mitigates credential leakage by avoiding cleartext injection inside source files, utilizing native IAM access control validations.
*   Docker Hub: Serves as our primary external open container image registry platform.
    *   Benefit: Accessible distribution channel allowing downstream Continuous Delivery (CD) clusters to fetch target application iterations seamlessly.

---

## 🔄 Project Workflow Architecture


  [ Developer ] 
        │  (Git Push Changes)
        ▼
  ┌───────────────┐
  │  GitHub Repo  │ ◄──────────┐
  └───────┬───────┘            │
          │ (Webhook Event)    │ Code Checkout
          ▼                    │
  ┌───────────────┐            │
  │ CodePipeline  ├────────────┘
  └───────┬───────┘
          │ (Triggers Build Environment)
          ▼
  ┌───────────────┐ ◄─── Fetches Secrets ─── ┌─────────────────────┐
  │   CodeBuild   │                          │ SSM Parameter Store │
  │ (Ubuntu Node) │                          └─────────────────────┘
  └───────┬───────┘
          │ (Docker Login, Build & Tag, Push Image)
          ▼
  ┌───────────────┐
  │  Docker Hub   │ (Application Image Available: 'latest')
  └───────────────┘
```

```

🚀 Step-by-Step Implementation Guide

1. Create a GitHub repository containing your central deployment code.
2. Structure a simple backend service (e.g., Python Flask) alongside its target dependencies inside a `requirements.txt` file:
  
   Flask==3.0.0
   
3. Craft a lightweight Dockerfile configuration to define your container boundaries:
   dockerfile
   FROM python:3.11-slim
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install --no-cache-dir -r requirements.txt
   COPY . .
   EXPOSE 5000
   CMD ["python", "app.py"]
  ```
```
### Step 2: Configure Secure Credentials in AWS SSM Parameter Store
To protect your infrastructure against identity compromise, offload sensitive container registry tokens out of public view:
1. Navigate to **AWS Systems Manager** > **Parameter Store** via the AWS Console.
2. Choose **Create Parameter** to map three separate security records:
   *   `/myapp/docker/username` ── Type: `SecureString` ── Value: `Your_DockerHub_Username`
   *   `/myapp/docker/password` ── Type: `SecureString` ── Value: `Your_DockerHub_Password/Token`
   *   `/myapp/docker/registry` ── Type: `String`       ── Value: `docker.io`

### Step 3: Establish an IAM Service Role for CodeBuild
1. Go to **Identity and Access Management (IAM)** > **Roles** > **Create Role**.
2. Pick **CodeBuild** as the trusted AWS service entity.
3. Name your target resource (e.g., `codebuild-service-role-ci`).
4. To grant access to credential stores, navigate to **Add Permissions** > **Attach Policies** within your newly made role, search for `AmazonSSMReadOnlyAccess` (or custom minimal decrypted actions), and select **Attach**.

### Step 4: Provision the AWS CodeBuild Project
1. Open the **AWS CodeBuild** console panel and select **Create build project**.
2. Set your **Project name** (e.g., `sample-python-flask-service`).
3. Under **Source**:
   *   Set the source provider platform to **GitHub**.
   *   Choose **Connect using OAuth** to authenticate your user profile securely.
   *   Select **Repository in my GitHub account** and locate your target code repository.
4. Under **Environment**:
   *   Environment image: Select **Managed Image**.
   *   Operating System: **Ubuntu**.
   *   Runtime(s): **Standard** ── Image: **Latest** available variation.
   *   ⚠️ **Critical Configuration**: Expand the *Additional Configuration* block, navigate to **Privileged**, and select **Enable this flag if you want to build Docker images**. *Failing to flag this breaks Docker daemon process bindings within container environments.*
   *   Service Role: Select **Existing service role** and target your IAM configuration from Step 3.

### Step 5: Define the Inline Build Specifications (Buildspec)
Under the **Buildspec** definition setup tab, choose **Insert build commands** to toggle the configuration workspace editor and define your operational instructions:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.11
  pre_build:
    commands:
      # If your application tracks scripts deeper inside folder tiers, alter your relative path mappings safely here
      - echo "Installing requirements..."
      - pip install -r requirements.txt
  build:
    commands:
      - echo "Logging into Docker Hub..."
      # Pull runtime application state arguments from parameter store keys
      - echo $docker_registry_password | docker login --username $docker_registry_username --password-stdin $docker_registry_url
      - echo "Building the Docker Image..."
      - docker build -t $docker_registry_url/$docker_registry_username/sample-python-flask-app:latest .
  post_build:
    commands:
      - echo "Pushing container image to repository..."
      - docker push $docker_registry_url/$docker_registry_username/sample-python-flask-app:latest
      - echo "CI pipeline phase completed successfully!"

# Explicitly tie local workflow parameters back to your system manager's keys
env:
  parameter-store:
    docker_registry_username: "/myapp/docker/username"
    docker_registry_password: "/myapp/docker/password"
    docker_registry_url: "/myapp/docker/registry"
```

Save your configuration profile changes by clicking **Create build project**.

### Step 6: Automate Orchestration via AWS CodePipeline
1. Open the **AWS CodePipeline** menu options, click **Create pipeline**, and assign a clear orchestration title.
2. For your **Source Stage**:
   *   Source Provider: **GitHub (Version 2)**.
   *   Complete connection handshakes, then map your structural **Repository name** and target deployment **Branch** (e.g., `main`).
   *   Trigger Execution Settings: Leave default webhook options selected so automated monitoring functions cleanly.
3. For your **Build Stage**:
   *   Build Provider: **AWS CodeBuild**.
   *   Select the matching Project Region along with your configured build project name from Step 4.
4. For your **Deploy Stage**:
   *   Choose **Skip deploy stage** for this scope, as our target deployment actions resolve fully once images compile smoothly into registries.
5. Review your structural outline parameters and hit **Create pipeline**.

---

## 🧪 Testing and Pipeline Verification

To ensure your Continuous Integration configuration behaves predictably under active development iterations:

1. Open your workspace branch code natively or modify configurations via GitHub's remote web interface directly.
2. Make a trivial modification to the codebase (such as updating text markers inside an evaluation script or layout workspace configurations) and commit your file revisions.
3. Return to the **AWS CodePipeline** overview screen. You should immediately see the **Source Stage** turn blue and switch to an `In Progress` execution phase.
4. Once structural code verification completes successfully, execution triggers cascade into your **Build Stage** automatically. Click **Details** to scan live build outputs or look up historical log data.
