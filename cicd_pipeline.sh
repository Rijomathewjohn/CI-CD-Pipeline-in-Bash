#!/bin/bash
set -e  # exit on error

# === CONFIGURATION ===
GITHUB_REPO="https://github.com/username/projectname.git"
APP_NAME="projectname"
DOCKER_USER="abcde"
DOCKER_PASS="abcde"
DOCKER_IMAGE="$DOCKER_USER/$APP_NAME:latest"
NAMESPACE="default"
DEPLOYMENT_NAME="myapp-deployment"

WORKDIR="/tmp/cicd-pipeline"
rm -rf $WORKDIR && mkdir -p $WORKDIR
cd $WORKDIR

echo "=== [1/5] Cloning Repository ==="
git clone $GITHUB_REPO
cd $(basename "$GITHUB_REPO" .git)

echo "=== [2/5] Running Tests ==="
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    pytest || { echo "❌ Tests failed"; exit 1; }
elif [ -f "pom.xml" ]; then
    mvn test || { echo "❌ Tests failed"; exit 1; }
else
    echo "  No test framework found, skipping..."
fi

echo "=== [3/5] Building Docker Image ==="
if [ ! -f "Dockerfile" ]; then
    echo "  No Dockerfile found, creating a default one..."
    cat <<EOF > Dockerfile
# Default Dockerfile
FROM alpine:latest
WORKDIR /app
COPY . .
CMD ["echo", "Hello from Docker!"]
EOF
fi
docker build -t $DOCKER_IMAGE .

echo "=== [4/5] Pushing to DockerHub ==="
echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
docker push $DOCKER_IMAGE

echo "=== [5/5] Deploying to Kubernetes ==="
kubectl create deployment $DEPLOYMENT_NAME \
  --image=$DOCKER_IMAGE -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE

echo "✅ CI/CD Pipeline Completed Successfully!"