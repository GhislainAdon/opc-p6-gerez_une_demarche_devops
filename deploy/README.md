# `deploy/` — Déploiement de l'application et de la plateforme

Ce dossier regroupe **tout l'Infrastructure-as-Code**. Deux chemins possibles avec
**les mêmes charts Helm** — c'est ce qui rend la solution **portable** :

| | Démo locale (validée en direct) | Cloud managé (EKS/AKS/GKE) |
|---|---|---|
| Cluster | Docker Desktop / Minikube | EKS (via `eksctl`) |
| Outillage (Argo CD, Sonar, ELK) | `scripts/secret/bootstrap.sh` (rapide, éphémère) | `deploy/terraform-platform/` (déclaratif) |
| Application MicroCRM | Argo CD (GitOps) ou `deploy/terraform/` | idem — **inchangé** |

```
deploy/
├── helm/microcrm/       # chart de l'application (front + back), values par env
├── argocd/              # Applications Argo CD (dev/test/prod) — GitOps
├── terraform/           # IaC APPLICATION : namespaces + secret registre + release Helm
├── terraform-platform/  # IaC PLATEFORME (cloud) : Argo CD, SonarQube, ELK (optionnels)
└── ansible/             # provisionnement hôte + déploiement + smoke test
```

> Le Terraform de l'application est **déjà agnostique du cluster** : il cible
> `var.kube_context`. Passer du local à EKS = **changer de contexte kube**, rien d'autre.

---

## Chemin A — Démo locale (ce qui est montré en soutenance)

```bash
docker desktop start                       # + activer Kubernetes
bash scripts/secret/bootstrap.sh           # SonarQube + tunnel + Argo CD + variables + reset dev
```
Le script installe Argo CD, SonarQube (conteneur) et le tunnel, puis affiche les liens.
Le déploiement de l'app se fait ensuite **en GitOps** (merge `solution → dev` → Argo CD).

**Identifiants Argo CD (installation locale par bootstrap)**
- **Utilisateur : `admin`**
- **Mot de passe** :
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d ; echo
  ```
- **Accès UI** :
  ```bash
  kubectl -n argocd port-forward svc/argocd-server 8080:443
  # puis https://localhost:8080
  ```

*(Alternative sans GitOps : `cd deploy/terraform && terraform apply -var kube_context=docker-desktop -var registry_token=<deploy-token>`.)*

---

## Chemin B — Cloud EKS (portabilité — mêmes charts)

### 1. Créer le cluster et se brancher dessus
```bash
eksctl create cluster --name orion --region eu-west-3 --nodes 2 --node-type t3.large
aws eks update-kubeconfig --name orion --region eu-west-3   # ajoute le contexte au kubeconfig
kubectl config current-context                              # note l'ARN du contexte
```

### 2. Installer l'outillage (Argo CD, Sonar, ELK) — `terraform-platform`
```bash
cd deploy/terraform-platform
terraform init
terraform apply \
  -var kube_context=<arn-du-contexte-eks> \
  -var install_argocd=true \
  -var install_sonarqube=true \
  -var install_elk=true \
  -var gitlab_repo_token=<PAT read_repository>   # pour qu'Argo CD lise le dépôt privé
```
Après `apply`, les `outputs` donnent les commandes d'accès (mot de passe Argo CD, endpoints).

### 3. Déployer l'application — `terraform` (inchangé) ou GitOps
```bash
cd ../terraform
terraform apply -var kube_context=<arn-du-contexte-eks> \
  -var registry_token=<deploy-token> -var image_tag=<tag>
```
*(ou laisser Argo CD déployer via les `Application` appliquées à l'étape 2.)*

---

## Avertissements assumés (honnêteté)

- **Non testé sur un EKS réel** dans ce projet : seul le chemin local (Docker
  Desktop/Minikube) est **validé en direct**. Le module `terraform-platform` est
  **correct par construction** (charts officiels, versions épinglées) et documenté.
- **SonarQube** : le module active un **PostgreSQL embarqué** pour la démo ; en
  production, pointer une base **managée** (RDS) et du stockage persistant.
- **ELK** : sur cloud, l'ingestion des logs ne passe **pas** par le driver GELF
  local — utiliser un collecteur (**Fluent Bit → Elasticsearch**) déployé en
  DaemonSet ; les charts ici fournissent Elasticsearch + Kibana, la brique de
  collecte est à adapter à la plateforme.
- **Secrets** : `registry_token`, `gitlab_repo_token`, etc. se passent par
  `TF_VAR_*` ou `-var`, **jamais commités** (le state `*.tfstate` est gitignoré).
