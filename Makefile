CLUSTER  ?= skillpulse
NAMESPACE ?= skillpulse
DOCKER_USER ?= geetanjalid009

BACKEND_IMAGE  ?= $(DOCKER_USER)/skillpulse-backend:latest
FRONTEND_IMAGE ?= $(DOCKER_USER)/skillpulse-frontend:latest

.PHONY: up down build load apply status logs mysql restart health argocd-install argocd-app argocd-password

up:
	docker build -t $(BACKEND_IMAGE) ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend
	kind create cluster --config k8s/kind-config.yaml --name $(CLUSTER)
	kind load docker-image $(BACKEND_IMAGE) --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)
	kubectl apply -f k8s/00-namespace.yaml \
	              -f k8s/10-mysql.yaml \
	              -f k8s/20-backend.yaml \
	              -f k8s/30-frontend.yaml
	kubectl rollout status statefulset/mysql -n $(NAMESPACE) --timeout=180s
	kubectl rollout status deployment/backend -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/frontend -n $(NAMESPACE) --timeout=60s
	@echo
	@echo "SkillPulse is live at http://localhost:8888"
	@echo

build:
	docker build -t $(BACKEND_IMAGE)  ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend

load:
	kind load docker-image $(BACKEND_IMAGE)  --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)

apply:
	kubectl apply -f k8s/00-namespace.yaml \
	              -f k8s/10-mysql.yaml \
	              -f k8s/20-backend.yaml \
	              -f k8s/30-frontend.yaml
	kubectl rollout status statefulset/mysql    -n $(NAMESPACE) --timeout=180s
	kubectl rollout status deployment/backend   -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/frontend  -n $(NAMESPACE) --timeout=60s

health:
	curl -f http://localhost:8888/health
	curl -f http://localhost:8888/api/dashboard

down:
	kind delete cluster --name $(CLUSTER)

status:
	kubectl get pods,svc,endpoints -n $(NAMESPACE)

logs:
	kubectl logs -n $(NAMESPACE) -l 'app in (mysql,backend,frontend)' --all-containers --tail=50 -f --max-log-requests=10

mysql:
	kubectl exec -it -n $(NAMESPACE) mysql-0 -- mysql -uskillpulse -pskillpulse123 skillpulse

restart:
	docker build -t $(BACKEND_IMAGE) ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend
	kind load docker-image $(BACKEND_IMAGE) --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)
	kubectl rollout restart deployment/backend deployment/frontend -n $(NAMESPACE)

argocd-install:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

argocd-app:
	kubectl apply -f argocd/skillpulse-application.yaml

argocd-password:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo
