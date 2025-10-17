# Phase 8: AWS Infrastructure with Pulumi

## Overview
Deploy the complete application stack to AWS using Pulumi for infrastructure as code. This phase creates a production-ready environment on AWS EKS with proper networking, managed services, and security.

## Objectives
- Set up AWS infrastructure using Pulumi TypeScript
- Deploy EKS cluster with managed node groups
- Configure VPC with proper subnet design
- Set up RDS for PostgreSQL
- Configure ElastiCache for Redis
- Implement ECR for container registry
- Deploy applications to EKS

## Pulumi Project Setup

### Initialize Pulumi Project
```bash
# Create infrastructure directory
mkdir -p infrastructure/pulumi
cd infrastructure/pulumi

# Initialize Pulumi project
pulumi new aws-typescript --name hello-dd-infra

# Install additional dependencies
npm install @pulumi/eks @pulumi/awsx @pulumi/kubernetes
```

### Project Structure
```
infrastructure/
└── pulumi/
    ├── index.ts              # Main infrastructure
    ├── vpc.ts                # Network configuration
    ├── eks.ts                # EKS cluster
    ├── rds.ts                # Database setup
    ├── elasticache.ts        # Redis setup
    ├── ecr.ts                # Container registry
    ├── Pulumi.yaml           # Project configuration
    ├── Pulumi.dev.yaml       # Dev environment
    ├── Pulumi.prod.yaml      # Prod environment
    └── package.json
```

## Core Infrastructure Components

### VPC and Networking
```typescript
// vpc.ts
import * as pulumi from "@pulumi/pulumi";
import * as awsx from "@pulumi/awsx";

export function createVPC(name: string) {
    const vpc = new awsx.ec2.Vpc(`${name}-vpc`, {
        cidrBlock: "10.0.0.0/16",
        numberOfAvailabilityZones: 3,
        natGateways: {
            strategy: awsx.ec2.NatGatewayStrategy.OnePerAz,
        },
        subnetSpecs: [
            {
                type: awsx.ec2.SubnetType.Public,
                cidrMask: 24,
                name: "public",
            },
            {
                type: awsx.ec2.SubnetType.Private,
                cidrMask: 22,
                name: "private",
            },
            {
                type: awsx.ec2.SubnetType.Isolated,
                cidrMask: 26,
                name: "database",
            },
        ],
        tags: {
            Name: `${name}-vpc`,
            Environment: pulumi.getStack(),
        },
    });

    return vpc;
}
```

### EKS Cluster
```typescript
// eks.ts
import * as pulumi from "@pulumi/pulumi";
import * as eks from "@pulumi/eks";
import * as awsx from "@pulumi/awsx";

export function createEKSCluster(name: string, vpc: awsx.ec2.Vpc) {
    const cluster = new eks.Cluster(`${name}-eks`, {
        vpcId: vpc.vpcId,
        privateSubnetIds: vpc.privateSubnetIds,
        publicSubnetIds: vpc.publicSubnetIds,
        instanceType: "t3.medium",
        desiredCapacity: 3,
        minSize: 2,
        maxSize: 6,
        nodeAssociatePublicIpAddress: false,

        enabledClusterLogTypes: [
            "api",
            "audit",
            "authenticator",
        ],

        tags: {
            Environment: pulumi.getStack(),
        },
    });

    // Install AWS Load Balancer Controller
    new eks.HelmChart("aws-load-balancer-controller", {
        chart: "aws-load-balancer-controller",
        namespace: "kube-system",
        fetchOpts: {
            repo: "https://aws.github.io/eks-charts",
        },
        values: {
            clusterName: cluster.eksCluster.name,
        },
    }, { provider: cluster.provider });

    return cluster;
}
```

### RDS PostgreSQL
```typescript
// rds.ts
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

export function createRDS(name: string, vpc: awsx.ec2.Vpc, securityGroupId: pulumi.Output<string>) {
    const dbSubnetGroup = new aws.rds.SubnetGroup(`${name}-db-subnet`, {
        subnetIds: vpc.isolatedSubnetIds,
    });

    const dbInstance = new aws.rds.Instance(`${name}-postgres`, {
        engine: "postgres",
        engineVersion: "15",
        instanceClass: "db.t3.medium",
        allocatedStorage: 100,
        storageType: "gp3",

        dbName: "inventory",
        username: "dbadmin",
        password: new pulumi.random.RandomPassword("db-password", {
            length: 32,
            special: false,
        }).result,

        vpcSecurityGroupIds: [securityGroupId],
        dbSubnetGroupName: dbSubnetGroup.name,

        backupRetentionPeriod: 7,
        multiAz: pulumi.getStack() === "prod",

        skipFinalSnapshot: pulumi.getStack() !== "prod",
    });

    return dbInstance;
}
```

### ElastiCache Redis
```typescript
// elasticache.ts
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

export function createRedis(name: string, vpc: awsx.ec2.Vpc, securityGroupId: pulumi.Output<string>) {
    const cacheSubnetGroup = new aws.elasticache.SubnetGroup(`${name}-cache-subnet`, {
        subnetIds: vpc.privateSubnetIds,
    });

    const redis = new aws.elasticache.ReplicationGroup(`${name}-redis`, {
        replicationGroupDescription: "Redis for hello-dd",
        engine: "redis",
        nodeType: "cache.t3.micro",
        numberCacheClusters: pulumi.getStack() === "prod" ? 3 : 1,

        subnetGroupName: cacheSubnetGroup.name,
        securityGroupIds: [securityGroupId],

        atRestEncryptionEnabled: true,
        transitEncryptionEnabled: false, // Enable in production with proper auth

        snapshotRetentionLimit: 5,
    });

    return redis;
}
```

### ECR Repositories
```typescript
// ecr.ts
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

export function createECRRepositories(name: string) {
    const services = ["api-gateway", "inventory-service", "pricing-service"];
    const repositories: Record<string, aws.ecr.Repository> = {};

    for (const service of services) {
        repositories[service] = new aws.ecr.Repository(`${name}-${service}`, {
            imageScanningConfiguration: {
                scanOnPush: true,
            },
        });

        // Lifecycle policy
        new aws.ecr.LifecyclePolicy(`${name}-${service}-lifecycle`, {
            repository: repositories[service].name,
            policy: JSON.stringify({
                rules: [{
                    rulePriority: 1,
                    selection: {
                        tagStatus: "any",
                        countType: "imageCountMoreThan",
                        countNumber: 10,
                    },
                    action: { type: "expire" },
                }],
            }),
        });
    }

    return repositories;
}
```

### Main Infrastructure
```typescript
// index.ts
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import { createVPC } from "./vpc";
import { createEKSCluster } from "./eks";
import { createRDS } from "./rds";
import { createRedis } from "./elasticache";
import { createECRRepositories } from "./ecr";

const config = new pulumi.Config();
const name = `hello-dd-${pulumi.getStack()}`;

// Create VPC
const vpc = createVPC(name);

// Create security groups
const eksNodeSg = new aws.ec2.SecurityGroup(`${name}-eks-node-sg`, {
    vpcId: vpc.vpcId,
    ingress: [{
        protocol: "-1",
        fromPort: 0,
        toPort: 0,
        self: true,
    }],
    egress: [{
        protocol: "-1",
        fromPort: 0,
        toPort: 0,
        cidrBlocks: ["0.0.0.0/0"],
    }],
});

const rdsSg = new aws.ec2.SecurityGroup(`${name}-rds-sg`, {
    vpcId: vpc.vpcId,
    ingress: [{
        protocol: "tcp",
        fromPort: 5432,
        toPort: 5432,
        securityGroups: [eksNodeSg.id],
    }],
});

const redisSg = new aws.ec2.SecurityGroup(`${name}-redis-sg`, {
    vpcId: vpc.vpcId,
    ingress: [{
        protocol: "tcp",
        fromPort: 6379,
        toPort: 6379,
        securityGroups: [eksNodeSg.id],
    }],
});

// Create infrastructure
const eksCluster = createEKSCluster(name, vpc);
const database = createRDS(name, vpc, rdsSg.id);
const cache = createRedis(name, vpc, redisSg.id);
const repositories = createECRRepositories(name);

// Export outputs
export const kubeconfig = eksCluster.kubeconfig;
export const vpcId = vpc.vpcId;
export const databaseEndpoint = database.endpoint;
export const redisEndpoint = cache.configurationEndpointAddress;
export const ecrUrls = Object.entries(repositories).reduce((acc, [key, repo]) => {
    acc[key] = repo.repositoryUrl;
    return acc;
}, {} as Record<string, pulumi.Output<string>>);
```

## Deployment Scripts

### Build and Push to ECR
```bash
#!/bin/bash
# scripts/push-to-ecr.sh

set -e

# Get ECR URLs from Pulumi
API_GATEWAY_ECR=$(pulumi stack output ecrUrls | jq -r '.["api-gateway"]')
INVENTORY_ECR=$(pulumi stack output ecrUrls | jq -r '.["inventory-service"]')
PRICING_ECR=$(pulumi stack output ecrUrls | jq -r '.["pricing-service"]')

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $API_GATEWAY_ECR

# Build and push each service
docker build -t api-gateway:latest ./api-gateway
docker tag api-gateway:latest $API_GATEWAY_ECR:latest
docker push $API_GATEWAY_ECR:latest

docker build -t inventory-service:latest ./inventory-service
docker tag inventory-service:latest $INVENTORY_ECR:latest
docker push $INVENTORY_ECR:latest

docker build -t pricing-service:latest ./pricing-service
docker tag pricing-service:latest $PRICING_ECR:latest
docker push $PRICING_ECR:latest
```

### Deploy to EKS
```bash
#!/bin/bash
# scripts/deploy-to-eks.sh

set -e

# Get kubeconfig from Pulumi
pulumi stack output kubeconfig > kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml

# Get database and Redis endpoints
DB_ENDPOINT=$(pulumi stack output databaseEndpoint)
REDIS_ENDPOINT=$(pulumi stack output redisEndpoint)

# Update Kubernetes manifests with AWS resources
kubectl create namespace hello-dd || true

# Create ConfigMap with AWS endpoints
kubectl create configmap aws-config \
  --from-literal=db-endpoint=$DB_ENDPOINT \
  --from-literal=redis-endpoint=$REDIS_ENDPOINT \
  -n hello-dd \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy applications
kubectl apply -f k8s/
```

## Pulumi Commands

```bash
# Set AWS credentials
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1

# Initialize stack
cd infrastructure/pulumi
pulumi stack init dev

# Set configuration
pulumi config set aws:region us-east-1

# Preview changes
pulumi preview

# Deploy infrastructure
pulumi up

# View outputs
pulumi stack output

# Destroy infrastructure
pulumi destroy
```

## Cost Optimization

### Development Settings
```yaml
# Pulumi.dev.yaml
config:
  aws:region: us-east-1
  hello-dd-infra:instanceType: t3.small
  hello-dd-infra:minSize: 1
  hello-dd-infra:maxSize: 3
  hello-dd-infra:dbInstanceClass: db.t3.micro
  hello-dd-infra:cacheNodeType: cache.t3.micro
```

### Production Settings
```yaml
# Pulumi.prod.yaml
config:
  aws:region: us-east-1
  hello-dd-infra:instanceType: t3.large
  hello-dd-infra:minSize: 3
  hello-dd-infra:maxSize: 10
  hello-dd-infra:dbInstanceClass: db.t3.medium
  hello-dd-infra:cacheNodeType: cache.t3.small
  hello-dd-infra:multiAz: true
```

## Monitoring Setup

### CloudWatch Dashboard
```typescript
// monitoring.ts
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

export function createDashboard(name: string, cluster: eks.Cluster) {
    const dashboard = new aws.cloudwatch.Dashboard(`${name}-dashboard`, {
        dashboardName: `${name}-metrics`,
        dashboardBody: JSON.stringify({
            widgets: [
                {
                    type: "metric",
                    properties: {
                        metrics: [
                            ["AWS/EKS", "cluster_node_count", { stat: "Average" }],
                            [".", "cluster_failed_node_count", { stat: "Sum" }],
                        ],
                        period: 300,
                        stat: "Average",
                        region: aws.getRegion().name,
                        title: "EKS Cluster Health",
                    },
                },
                // Add more widgets as needed
            ],
        }),
    });

    return dashboard;
}
```

## Deliverables

1. **AWS Infrastructure**
   - VPC with proper networking
   - EKS cluster operational
   - RDS PostgreSQL deployed
   - ElastiCache Redis running
   - ECR repositories created

2. **Pulumi Codebase**
   - Modular TypeScript infrastructure
   - Environment configurations
   - Automated scripts

3. **Applications Deployed**
   - Services running in EKS
   - Connected to AWS managed services
   - Load balancer configured

## Success Criteria

- Infrastructure deploys with Pulumi
- All services running in EKS
- Database and cache accessible
- Load balancer routing traffic
- Costs optimized per environment
- Security best practices followed
- Monitoring configured

## Preparation for Phase 9

Ready for:
- Advanced patterns implementation
- Production optimizations
- Disaster recovery setup