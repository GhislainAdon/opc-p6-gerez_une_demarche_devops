<p align="center">
   <img src="./front/src/favicon.png" width="192px" />
</p>

# Orion — Application Full-Stack (MicroCRM)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/GhislainAdon/opc-p6-gerez_une_demarche_devops/tree/solution?quickstart=1)

> **Tester dans un Codespace (gratuit)** : le bouton ci-dessus ouvre l'environnement complet
> (Docker, Terraform, kubectl/Helm/Minikube, Java 17, Node 20, Python + Ansible) sur une machine
> **4 vCPU / 16 Go RAM / 32 Go de stockage** — dans la limite du forfait gratuit GitHub
> (120 heures-cœur/mois, soit ~30 h sur cette machine ; le stockage gratuit est de 15 Go-mois).
> Pensez à arrêter le Codespace après usage. Tout le projet s'exécute dedans :
> `docker compose up`, `terraform apply` (Minikube préinstallé), stack ELK, scripts.



MicroCRM est l'application Full-Stack d'Orion. Ce dépôt contient son code source ainsi que la chaîne CI/CD complète (tests, qualité, sécurité, packaging, sauvegarde, déploiement, notifications) décrite ci-dessous.

L'application MicroCRM est une implémentation simplifiée d'un ["CRM" (Customer Relationship Management)](https://fr.wikipedia.org/wiki/Gestion_de_la_relation_client). Les fonctionnalités sont limitées à la création, édition et la visualisations des individus liés à des organisations.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

## Code source

### Organisation

Ce [monorepo](https://en.wikipedia.org/wiki/Monorepo) contient les 2 composantes du projet "MicroCRM":

- La partie serveur (ou "backend"), en Java SpringBoot 3;
- La partie cliente (ou "frontend"), en Angular 17.

La chaîne CI/CD est définie via le fichier [`.gitlab-ci.yml`](./.gitlab-ci.yml) — voir la section [Chaîne CI/CD](#chaîne-cicd).

### Démarrer avec les sources

#### Serveur

##### Dépendances

- [OpenJDK >= 17](https://openjdk.org/)

##### Procédure

1. Se positionner dans le répertoire `back` avec une invite de commande:

   ```shell
   cd back
   ```

2. Construire le JAR:

   ```shell
   # Sur Linux
   ./gradlew build

   # Sur Windows
   gradlew.bat build
   ```

3. Démarrer le service:

   ```shell
   java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
   ```

Puis ouvrir l'URL http://localhost:8080 dans votre navigateur.

#### Client

##### Dépendances

- [NPM >= 10.2.4](https://www.npmjs.com/)

##### Procédure

1. Se positionner dans le répertoire `front` avec une invite de commande:

   ```shell
   cd front
   ```

2. (La première fois seulement) Installer les dépendances NodeJS:

   ```shell
   npm install
   ```

3. Démarrer le service de développement:

   ```shell
   npx @angular/cli serve
   ```

Puis ouvrir l'URL http://localhost:4200 dans votre navigateur.

### Exécution des tests

#### Client

**Dépendances**

- Google Chrome ou Chromium

Dans votre terminal:

```shell
cd front
CHROME_BIN=</path/to/google/chrome> npm test
```

#### Serveur

Dans votre terminal:

```shell
cd back
./gradlew test
```

### Images Docker

#### Client

##### Construire l'image

```shell
docker build --target front -t orion-microcrm-front:latest .
```

##### Exécuter l'image

```shell
docker run -it --rm -p 80:80 -p 443:443 orion-microcrm-front:latest
```

L'application sera disponible sur https://localhost.

#### Serveur

##### Construire l'image

```shell
docker build --target back -t orion-microcrm-back:latest .
```

##### Exécuter l'image

```shell
docker run -it --rm -p 8080:8080 orion-microcrm-back:latest
```

L'API sera disponible sur http://localhost:8080.

#### Tout en un

```shell
docker build --target standalone -t orion-microcrm-standalone:latest .
```

##### Exécuter l'image

```shell
docker run -it --rm -p 8080:8080 -p 80:80 -p 443:443 orion-microcrm-standalone:latest
```

L'application sera disponible sur https://localhost et l'API sur http://localhost:8080.

## Chaîne CI/CD

Le pipeline s'exécute à chaque push. Chaque image publiée est taguée
`<branche>-<SHA court>` : on sait toujours quel commit tourne où.

| Stage | Job(s) | Rôle |
|---|---|---|
| `test` | `test-back`, `test-front` | Tests unitaires (JUnit, Karma) + couverture (JaCoCo, lcov) + rapport de dépendances (`scripts/check_deps.sh`). Rapports JUnit publiés dans GitLab. |
| `quality` | `sonarqube` | Analyse statique Java + TypeScript, **quality gate bloquante** (`sonar.qualitygate.wait=true`). Activé quand `SONAR_HOST_URL`/`SONAR_TOKEN` sont définis. |
| `package` | `build-back`, `build-front`, `docker-back`, `docker-front` | Artefacts classiques (JAR, bundle Angular) + images Docker poussées au **Container Registry** GitLab. |
| `security` | `trivy-back`, `trivy-front` | Scan de vulnérabilités des images, **bloquant** sur CVE HIGH/CRITICAL (exceptions justifiées dans `.trivyignore`). |
| `backup` | `backup-artifacts` | Archive horodatée des artefacts déployables (`scripts/backup.sh`) — support de rollback. |
| `deploy` | `deploy-smoke` | Déploiement des 2 images + vérification HTTP (`scripts/deploy_demo.sh`). |
| `notify` | `notify-success` / `notify-failure` | Notification Discord du résultat (`scripts/notify_discord.py`). Activé quand `DISCORD_WEBHOOK_URL` est défini. |

### Variables CI/CD à configurer (Settings → CI/CD → Variables, masquées)

| Variable | Rôle |
|---|---|
| `SONAR_HOST_URL` | URL de l'instance SonarQube (ex. `http://sonar.example.com:9000`) |
| `SONAR_TOKEN` | Jeton d'analyse SonarQube (protégé + masqué) |
| `DISCORD_WEBHOOK_URL` | Webhook du canal Discord de l'équipe (masqué) |

Aucun secret n'est versionné : en local, copier `.env.example` vers `.env` (gitignoré).

### Scripts d'automatisation (`scripts/`)

| Script | But | Fonctionnement | Paramètres |
|---|---|---|---|
| `check_deps.sh` | Gestion/audit des dépendances | `npm audit` + `npm outdated` (front) ou arbre `gradle dependencies` (back), rapport écrit dans `reports/` et conservé en artefact. Toujours exit 0 : job d'observation, la sécurité bloquante est portée par Trivy/Sonar. | `<front\|back>` |
| `backup.sh` | Sauvegarde des builds | Tar+gzip horodaté (UTC) + SHA du commit de `back/build/libs` et `front/dist`, checksum SHA-256 associé. Échoue si aucun artefact n'existe. | `[dossier-sortie]` (défaut `backups/`) |
| `notify_discord.py` | Notification des résultats | Poste un embed (statut, branche, commit, auteur, lien pipeline) sur le webhook Discord. Librairie standard uniquement. No-op sans `DISCORD_WEBHOOK_URL`, exit 1 si l'envoi échoue. | `[success\|failed\|canceled]` (défaut `$CI_JOB_STATUS`) |
| `deploy_demo.sh` | Déploiement + smoke test | Crée un réseau Docker, lance les images back (:8081) et front (:8082), attend leur réponse HTTP (30 tentatives), nettoie en sortie. | `<image-back> <image-front>` ; env `DEPLOY_HOST` (défaut `localhost`, `docker` en CI dind) |

### SonarQube en local

```bash
docker compose -f tools/sonarqube/compose.yaml up -d   # http://localhost:9000
# créer un token projet puis :
export SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=<token>
sonar-scanner   # analyse locale (mêmes propriétés que la CI : sonar-project.properties)
```

### Images Docker

Deux images ciblées (un processus par conteneur, utilisateurs non-root) construites
depuis le [`Dockerfile`](./Dockerfile) multi-stage :

```bash
docker build --target back  -t microcrm-back  .   # Spring Boot, port 8080
docker build --target front -t microcrm-front .   # Caddy + bundle Angular, port 8080
```

## Déploiement continu (CD) et Infrastructure-as-Code

### Orchestration Kubernetes (Minikube + Helm)

Le chart Helm [`deploy/helm/microcrm`](./deploy/helm/microcrm) déploie les 2 composants
(probes readiness/liveness, ressources limitées, imagePullSecret pour le registre privé) :

```bash
minikube start
kubectl create secret docker-registry gitlab-registry \
  --docker-server=registry.gitlab.com --docker-username=<user> --docker-password=<deploy-token>
helm install microcrm deploy/helm/microcrm -f deploy/helm/microcrm/values-dev.yaml
minikube service microcrm-front --url
```

Environnements différenciés : `values-dev.yaml` (1 replica, NodePort 30080) et
`values-staging.yaml` (2 replicas — résilience, NodePort 30081).

### IaC Terraform + Ansible

- [`deploy/terraform/`](./deploy/terraform) : crée les namespaces `dev` et `staging`
  et installe une release Helm dans chacun (`terraform apply -var image_tag=<tag>`).
  State local, aucun credential versionné.
- [`deploy/ansible/`](./deploy/ansible) :
  - `provision.yml` — vérifie l'outillage du poste (docker, kubectl, minikube, helm, terraform) et démarre Minikube si nécessaire ;
  - `deploy.yml` — enchaîne Terraform → attente des pods Ready → smoke test HTTP du frontend (`ansible-playbook -i inventory.ini deploy.yml -e image_tag=<tag>`).

### Monitoring — stack ELK + métriques DORA

```bash
docker compose -f monitoring/elk/compose.yaml up -d   # Kibana : http://localhost:5601
```

Les conteneurs applicatifs envoient leurs logs à Logstash via le driver GELF
(`--log-driver gelf --log-opt gelf-address=udp://<hôte>:12201`) ; sous Docker
Desktop, utiliser l'**IP du conteneur Logstash** (`docker inspect orion-logstash`)
car le driver s'exécute dans le démon et ne voit pas les ports publiés ; Logstash
enrichit (composant, verbe/statut HTTP) et indexe dans `orion-logs-*` pour les
dashboards Kibana.

Les 4 métriques **DORA** sont calculées depuis l'API GitLab par
[`scripts/dora_metrics.py`](./scripts/dora_metrics.py) :

| Script | But | Fonctionnement | Paramètres |
|---|---|---|---|
| `dora_metrics.py` | Mesure de la performance de livraison | Interroge l'API GitLab (pipelines + commits) et calcule : fréquence de déploiement/semaine, lead time médian commit→succès, taux d'échec des changements, MTTR (échec→succès suivant). Résultat affiché + `reports/dora_metrics.json`. | `--branch` (défaut `solution`), `--days` (défaut 30), `--project-id` ; env `GITLAB_TOKEN` |
