## 🚀 Part 2: Continuous Deployment (CD) Deep Dive

The Continuous Deployment (CD) layer acts as the automated delivery vehicle. It takes the immutable image artifact built during the CI process, provisions serverless compute clusters on demand, establishes virtual networking routes, and exposes the live web application securely to the internet.

---

### 🎨 1. CD Layer Services & Core Functions

To build a production-grade rollout architecture on AWS, the following specialized native services are integrated:

*   **AWS CodePipeline (Deploy Stage)**: Acts as the **workflow engine**. It intercepts the compiled zip bundle from the preceding CodeBuild stage, unpacks it to read deployment instructions, and coordinates the rolling update with Amazon ECS.
*   **Amazon ECS (Elastic Container Service)**: Acts as the **container orchestrator**. It tracks active task lifecycles, scales tasks, processes container health metrics, and ensures zero-downtime rollouts.
*   **AWS Fargate**: Acts as the **serverless compute engine**. It eliminates the need to provision, scale, or patch physical virtual machines (EC2). Fargate dynamically allocates processing cores and memory footprints to run containers in isolation.
*   **AWS IAM (Identity and Access Management)**: Acts as the **security layer**. It enforces fine-grained authorization using two core configurations:
    *   *Pipeline Service Role*: Grants CodePipeline explicit authorization to modify and update active ECS cluster objects.
    *   *ECS Task Execution Role (`ecsTaskExecutionRole`)*: Grants the Fargate agent backend permissions to authenticate with Docker Hub and open CloudWatch system streams.
*   **AWS VPC (Virtual Private Cloud)**: Acts as the **network layer**. It isolates cloud assets. It maps infrastructure across **Public Subnets** bound to an Internet Gateway (`igw-`) to give running containers a public IP to connect outward.
*   **AWS Security Groups**: Act as an **inline firewall**. It actively blocks all external internet requests by default, except for specific incoming traffic explicitly whitelisted on your custom application ports.
*   **AWS CloudWatch Logs**: Acts as the **centralized monitoring layer**. Because Fargate is completely serverless, traditional terminal SSH access is unavailable. CloudWatch dynamically streams your container's internal standard output (`stdout`/`stderr`) onto your dashboard for real-time debugging.

---

### 🔗 2. Connection Logic: Bridging Part 1 (CI) to Part 2 (CD)

To bridge the gap between building a container image (CI) and deploying it to infrastructure (CD), **three critical architectural links must be established**:

[Part 1: CodeBuild Stage] ──(Generates)──► imagedefinitions.json ──(Passed via BuildArtifact)──► [Part 2: CodePipeline Deploy Stage]

1.  **The Artifact Handshake (`imagedefinitions.json`)**: CodePipeline cannot parse external registry tags automatically. CodeBuild must be configured to generate an exact artifact declaration payload file during its `post_build` phase:
    ```
    printf '[{"name":"flask-app-container","imageUri":"%s"}]' "\$DOCKER_REGISTRY_USERNAME/simple-python-flask-app:latest" > imagedefinitions.json
    ```
2.  **The Pipeline Handover Mapping**: The `artifacts` section at the absolute bottom of the repository's `buildspec.yaml` must be modified to isolate and export **only** this single JSON target. CodePipeline intercepts this bundle as a named `BuildArtifact` and transfers it to the deployment stage.
3.  **The Case-Sensitive Name Match**: The literal `name` string declared inside your JSON snippet (`flask-app-container`) **must perfectly match** the Container Name property configured inside your Amazon ECS Task Definition container specs. If these strings mismatch, CodePipeline will fail to bind the image.

---

### 🛠️ 3. Step-by-Step CD Building Procedure

Follow these sequential steps to construct the deployment architecture and wire it directly into the active pipeline:

#### Step 1: Fix Core Network Isolation & Security Groups
If your AWS account lacks public internet routing rules, Fargate tasks will immediately drop into a stopped loop during boot verification.
1. Re-instantiate a fresh, pre-configured default networking layout containing public routing parameters via your terminal:
   ```
   aws ec2 create-default-vpc --no-cli-pager
   ```
2. Retrieve your account's public subnet identification strings (e.g., `subnet-0cf9742e95b064d66`):
   ```
   aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query "Subnets[*].[SubnetId]" --output table
   ```
3. Locate your default network firewall group identifier (e.g., `sg-06ce2e786a778ea0c`):
   ```
   aws ec2 describe-security-groups --filters "Name=group-name,Values=default" --query "SecurityGroups[*].[GroupId]" --output table
   ```
4. **Execution Command**: Open Port `5000` globally to allow any external browser or smartphone to reach your running Python Flask app over the internet:
   ```
   aws ec2 authorize-security-group-ingress --group-id YOUR_DEFAULT_SG_ID --protocol tcp --port 5000 --cidr 0.0.0.0/0 --no-cli-pager
   ```
   *(Note: If the terminal outputs an `InvalidPermission.Duplicate` response, it means the firewall is already safely open).*

#### Step 2: Establish the Log Monitoring Framework
1. Create the persistent log group target that Fargate's internal logging driver expects:
   ```
   aws logs create-log-group --log-group-name /ecs/flask-app-task --no-cli-pager
   ```

#### Step 3: Register the Upgraded Task Definition Blueprint
1. Navigate to the **Amazon ECS Console** ➡️ Click **Task definitions** in the left menu ➡️ Select **Create new task definition (JSON)**.
2. Clear out the workspace workspace and paste the following configuration. 
   *   **⚠️ Port Fix**: The port mappings are explicitly aligned to `5000` to resolve `ERR_CONNECTION_REFUSED` codes.
   *   **⚠️ Memory Fix**: Resource allocations are scaled to `512 CPU` (.5 vCPU) and `1024 Memory` (1 GB RAM) to eliminate **Linux Exit Code 137** crashes caused by loading styled Bootstrap CSS layouts.
```
{
  "family": "flask-app-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [{
    "name": "flask-app-container",
    "image": "docker.io/YOUR_DOCKER_HUB_USERNAME/simple-python-flask-app:latest",
    "essential": true,
    "portMappings": [{
      "containerPort": 5000,
      "hostPort": 5000,
      "protocol": "tcp",
      "name": "flask-app-container-5000-tcp",
      "appProtocol": "http"
    }],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/flask-app-task",
        "awslogs-create-group": "true",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }]
}
```
3. Click **Create** at the bottom of the dashboard.

#### Step 4: Provision Your Serverless ECS Fargate Service
1. Click **Clusters** on the ECS left sidebar menu ➡️ Click **Create cluster**. Name it `flask-app-cluster`, select **AWS Fargate (Serverless)**, and hit **Create**.
2. Once provisions complete, click inside your cluster, select the **Services** tab, and click **Deploy**.
3. Apply the infrastructure configurations exactly as follows:
   *   **Application type**: Service
   *   **Family**: Select `flask-app-task` (Revision: `latest`)
   *   **Service name**: `flask-app-service`
   *   **Desired tasks**: `1`
4. Expand the **Networking** dropdown parameters block:
   *   **VPC**: Select your fresh Default VPC block.
   *   **Subnets**: Check the boxes for your public subnet IDs extracted in Step 1.
   *   **Security Group**: Select your default group ID containing your open port 5000 configuration.
   *   **Public IP**: Ensure this is explicitly toggled to **`Turned on`**.
5. Click **Deploy**.

#### Step 5: Link Part 1 (CI) to Part 2 (CD) Inside CodePipeline
1. Open the **AWS CodePipeline Console** and click on your pipeline (**`sample-python-app`**).
2. Click the **Edit** button located at the top of the interface.
3. Scroll to the absolute bottom of your pipeline visual stage timeline and click **+ Add stage**. Name the stage `Deploy`.
4. Inside your new Deploy stage box, click **+ Add action group**:
   *   **Action name**: `ECS-Deploy`
   *   **Action provider**: **Amazon ECS**
   *   **Input artifacts**: Select **`BuildArtifact`** *(This captures the output file passed down from the build engine)*.
   *   **Cluster name**: Select `flask-app-cluster`
   *   **Service name**: Select `flask-app-service`
   *   **Image definitions file**: Type exactly **`imagedefinitions.json`**
5. Click **Done**, then click **Save** at the top right of the screen.

#### Step 6: Elevate Pipeline Access Policies
1. If your pipeline deployment action fails immediately with a `PermissionError`, execute this command to grant the pipeline full access to coordinate with your active container management layer:
   ```
   aws iam attach-role-policy --role-name AWSCodePipelineServiceRole-us-east-1-sample-python-app --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess --no-cli-pager
   ```

---

### 🏁 Verification & Continuous Validation
To verify the entire automated architecture, modify your frontend files and push them to your repository:
```
git add . && git commit -m "feat: complete automated pipeline verification" && git push origin main
```
Your pipeline dashboard stages will switch to a green completed state. Run this clean parsing block to instantly extract your container's live public IP routing address:
```
aws ecs describe-tasks --cluster flask-app-cluster --tasks \$(aws ecs list-tasks --cluster flask-app-cluster --desired-status RUNNING --query "taskArns" --output text --no-cli-pager) --query "tasks[].attachments[].details[?name=='networkInterfaceId'].value" --output text --no-cli-pager | xargs -n 1 | grep -v "None" | xargs -I % aws ec2 describe-network-interfaces --network-interface-ids % --query "NetworkInterfaces[].Association.PublicIp" --output text --no-cli-pager
