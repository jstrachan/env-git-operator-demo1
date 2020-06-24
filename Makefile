FETCH_DIR := build/base
OUTPUT_DIR := config-root

.PHONY: clean
clean:
	rm -rf build $(OUTPUT_DIR)

init:
	mkdir -p $(FETCH_DIR)
	mkdir -p $(OUTPUT_DIR)/namespaces/jx
	cp -r src/* build
	mkdir -p $(FETCH_DIR)/cluster/crds
	mkdir -p $(FETCH_DIR)/namespaces/nginx
	mkdir -p $(FETCH_DIR)/namespaces/vault-infra


.PHONY: fetch
fetch: init
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jx-labs/jenkins-x-crds@master $(FETCH_DIR)/cluster/crds
	- kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/jx@master $(FETCH_DIR)/namespaces/jx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/jxboot-helmfile-resources@master $(FETCH_DIR)/namespaces/jx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/jx-config@master $(FETCH_DIR)/namespaces/jx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/lighthouse@master $(FETCH_DIR)/namespaces/jx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/pusher-wave@master $(FETCH_DIR)/namespaces/jx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/tekton@master $(FETCH_DIR)/namespaces/jx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/stable/nginx-ingress@master $(FETCH_DIR)/namespaces/nginx
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/external-secrets/kubernetes-external-secrets@master $(FETCH_DIR)/namespaces/vault-infra
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/jenkins-x/vault-instance@master $(FETCH_DIR)/namespaces/vault-infra
	kpt pkg get https://github.com/jenkins-x/jxr-kube-resources.git/banzaicloud-stable/vault-operator@master $(FETCH_DIR)/namespaces/vault-infra

	# this step is not required if using `helm template --namespace` for each chart
	jx-gitops namespace --dir-mode --dir $(FETCH_DIR)/namespaces

.PHONY: build
# uncomment this line to enable kustomize
#build: build-kustomise
build: build-nokustomise

.PHONY: build-kustomise
build-kustomise: kustomize post-build

.PHONY: build-nokustomise
build-nokustomise: copy-resources post-build


.PHONY: pre-build
pre-build:
	jx-gitops repository --dir ./build/base

.PHONY: post-build
post-build:
	jx-gitops label --dir $(OUTPUT_DIR) gitops.jenkins-x.io/pipeline=environment
	jx-gitops annotate --dir  $(OUTPUT_DIR)/namespaces --kind Deployment wave.pusher.com/update-on-config-change=true


.PHONY: kustomize
kustomize: pre-build
	kustomize build ./build  -o $(OUTPUT_DIR)/namespaces

.PHONY: copy-resources
copy-resources: pre-build
	cp -r ./build/base/* $(OUTPUT_DIR)
	rm $(OUTPUT_DIR)/kustomization.yaml

.PHONY: lint
lint:

.PHONY: apply
apply:
	kubectl apply --prune -l=gitops.jenkins-x.io/pipeline=environment -R -f $(OUTPUT_DIR)

.PHONY: commit
commit:
	git add --all
	- git commit -m "chore: regenerated"
	git push

.PHONY: all
all: clean fetch build lint
