# Document de veille technologique, d'audit et de recommandations

**Projet** : Amélioration du pipeline CI de l'application Full-Stack (MicroCRM) — Orion
**Auteur** : Ghislain Adon, Expert DevOps
**Version** : 1.0 — juillet 2026

---

## 1. Introduction

### 1.1 Objectifs

Ce document consolide trois travaux demandés par la direction technique (Maria, CTO) :
un **audit** du processus d'intégration continue actuel de l'application Full-Stack, une
**veille technologique** ciblée sur les manques identifiés, et des **recommandations**
priorisées qui serviront de base au plan de normalisation et de mise en œuvre de la
nouvelle chaîne CI.

### 1.2 Rappel du contexte

Orion développe une application Full-Stack (frontend Angular/TypeScript, backend
Spring Boot/Java, monorepo Git avec CI GitLab minimale). Le projet est jeune
(second sprint, pas encore en production). Deux équipes interviennent :

| Équipe | Membres | Compétences fortes | Compétences faibles |
|---|---|---|---|
| **Dev** | Roubina (lead), Sylvain (senior), Temim (junior), Josefina (stagiaire) | Angular/TypeScript, NPM, Karma, Docker | Java/Spring Boot, Gradle, JUnit, HyperSQL (débutant) |
| **Ops** | Nico (lead), Maïa (senior) | Bash (très bon), Ansible, TestInfra, BashUnit, Debian, Docker | PostgreSQL (moyen) |

La direction constate que le pipeline CI est « réduit au strict minimum » et souhaite
« une intégration plus poussée des automatisations », avec trois attentes : identifier
les goulots d'étranglement et les lacunes de sécurité, proposer des solutions modernes,
et planifier l'implémentation.

---

## 2. Rapport de veille technologique

### 2.1 Méthodologie

La veille a été menée en 3 temps : (1) extraction des besoins depuis l'audit (§3) et
les souhaits exprimés dans les sondages des équipes ; (2) recherche par catégorie
d'outils dans des sources de référence — documentation officielle des éditeurs,
CNCF Landscape (landscape.cncf.io), comparatifs StackShare, retours d'expérience
(blogs d'ingénierie, r/devops) ; (3) évaluation de l'applicabilité au contexte Orion :
compatibilité avec GitLab CI (déjà en place), courbe d'apprentissage des équipes
(profil Dev junior sur la partie Java), coût.

### 2.2 Technologies évaluées

#### 2.2.1 SonarQube (analyse statique / qualité de code)
- **Description** : plateforme d'analyse statique continue (bugs, code smells, vulnérabilités, couverture, duplication) avec « quality gates » bloquantes.
- **Catégorie** : Qualité & analyse statique (SAST).
- **Fonctionnalités clés** : quality gate par merge request, support Java + TypeScript natif, intégration GitLab CI documentée, seuils de couverture.
- **Cas d'usage** : bloquer l'intégration d'un code sous les standards ; accompagner la montée en compétence Java de l'équipe Dev (souhait explicite du sondage Dev : « outils d'analyse statique et d'aide à la conception »).
- **Références** : docs.sonarsource.com (intégration GitLab), édition Community gratuite self-hosted.

#### 2.2.2 Trivy (analyse de vulnérabilités d'images)
- **Description** : scanner open source (Aqua Security) de CVE dans les images de conteneurs, systèmes de fichiers et dépôts Git.
- **Catégorie** : Sécurité conteneurs (SCA).
- **Fonctionnalités clés** : scan d'images en CI, base CVE à jour, sortie SARIF/table, seuils de sévérité bloquants.
- **Cas d'usage** : l'équipe Ops utilise **déjà Trivy manuellement** après livraison des images ; l'automatiser dans la CI supprime les « retours à l'envoyeur » (souhait explicite du sondage Ops : contrôles « en amont de la transmission »).
- **Références** : github.com/aquasecurity/trivy, docs GitLab « Container Scanning ».

#### 2.2.3 GitLab Container Registry (registre d'images interne)
- **Description** : registre Docker privé intégré à GitLab, adossé au projet.
- **Catégorie** : Gestion d'artefacts.
- **Fonctionnalités clés** : authentification par jeton CI natif (`$CI_REGISTRY_*`), tags par branche/SHA, politique de rétention.
- **Cas d'usage** : répond au souhait Ops d'un « dépôt d'images interne pour ne plus dépendre de DockerHub » ; disponible sans nouvel outil puisque GitLab héberge déjà le code.
- **Références** : docs.gitlab.com/ee/user/packages/container_registry.

#### 2.2.4 GitLab CI (chaîne CI existante, à étendre)
- **Description** : orchestrateur CI/CD intégré à GitLab (runners SaaS gratuits, templates standards).
- **Catégorie** : Plateforme CI/CD.
- **Fonctionnalités clés** : stages/needs, cache par gestionnaire de dépendances, artefacts + rapports JUnit, `rules:`, composants réutilisables, intégration registry/secrets.
- **Cas d'usage** : conserver l'existant (courbe d'apprentissage nulle) et l'étendre — plutôt que migrer vers Jenkins/GitHub Actions.
- **Références** : docs.gitlab.com/ee/ci, lib/gitlab/ci/templates.

#### 2.2.5 Kubernetes + Helm (orchestration, partie 2)
- **Description** : orchestrateur de conteneurs standard de fait + gestionnaire de paquets de manifestes (charts versionnés, values par environnement).
- **Catégorie** : Orchestration.
- **Cas d'usage** : déploiements reproductibles staging/démo, scalabilité et résilience demandées par la direction ; exécutable localement via Minikube sans coût cloud.
- **Références** : kubernetes.io, helm.sh.

#### 2.2.6 Terraform + Ansible (Infrastructure-as-Code, partie 2)
- **Description** : provisionnement déclaratif (Terraform) + gestion de configuration idempotente (Ansible).
- **Catégorie** : IaC.
- **Cas d'usage** : industrialiser la création des environnements ; **l'équipe Ops maîtrise déjà Ansible (bon niveau)** — Terraform complète sans remplacer.
- **Références** : terraform.io, ansible.com.

#### 2.2.7 Stack ELK (observabilité, partie 2)
- **Description** : Elasticsearch (indexation), Logstash (ingestion), Kibana (visualisation).
- **Catégorie** : Monitoring & logs.
- **Cas d'usage** : centralisation des logs applicatifs et mesure de performance (métriques DORA au niveau livraison) ; alternative Grafana/Prometheus évaluée en complément pour les métriques.
- **Références** : elastic.co ; cours « Centralisez vos alertes avec ELK Stack ».

### 2.3 Matrices comparatives

#### 2.3.1 Qualité / analyse statique

| | **SonarQube (Community)** | **Codacy / CodeClimate (SaaS)** | **Linters seuls (ESLint + Checkstyle)** |
|---|---|---|---|
| Avantages | Java + TS natifs, quality gates MR, self-hosted gratuit, demandé par la consigne | Zéro hébergement, setup rapide | Zéro infra, ultra léger |
| Inconvénients | Conteneur à héberger (2 Go RAM min) | Coût récurrent, données hors entreprise | Pas de vision dette/couverture, pas de gate centralisée |
| Verdict Orion | ✅ **Retenu** (souhait Dev + exigence projet) | ❌ coût + confidentialité | ➕ conservés en pré-commit, complément |

#### 2.3.2 Sécurité des images

| | **Trivy** | **Grype** | **Clair** |
|---|---|---|---|
| Avantages | Déjà connu des Ops, rapide, seuils bloquants, gratuit | Rapide, SBOM natif | Intégré à certains registres |
| Inconvénients | — | Moins connu de l'équipe | Déploiement serveur plus lourd |
| Verdict Orion | ✅ **Retenu** (continuité de pratique, shift-left en CI) | alternative crédible | ❌ complexité inutile |

#### 2.3.3 Registre d'images

| | **GitLab Container Registry** | **Harbor** | **DockerHub (statu quo)** |
|---|---|---|---|
| Avantages | Inclus dans GitLab, auth CI native, zéro infra | Scan intégré, réplication | Aucun changement |
| Inconvénients | Lié à GitLab | Serveur dédié à opérer | Dépendance externe + rate limits (irritant Ops) |
| Verdict Orion | ✅ **Retenu** | ❌ surdimensionné | ❌ rejeté par les Ops |

#### 2.3.4 Notification des résultats de pipeline

| | **Webhook Discord (script Python)** | **E-mail SMTP** | **Artefact de rapport seul** |
|---|---|---|---|
| Avantages | Temps réel, riche (statut par job), gratuit, démontrable | Standard entreprise | Zéro dépendance |
| Inconvénients | Canal externe à provisionner | Config SMTP + secrets, peu lisible | Pas de « push » vers l'équipe |
| Verdict Orion | ✅ **Retenu** | alternative documentée | complément (artefacts conservés) |

---

## 3. Audit des processus de développement

### 3.1 Objectifs

Évaluer l'efficacité du processus CI/dev actuel, identifier les opérations manuelles,
les goulots d'étranglement et les lacunes de sécurité, afin d'alimenter les
recommandations (§4) et le plan de normalisation (document 2).

### 3.2 Méthodologie

Audit documentaire croisé : sondages « pratiques et technologies » remplis par les
équipes Dev et Ops, lecture du dépôt Git (README, `.gitlab-ci.yml`, `Dockerfile`),
reconstitution du flux de livraison de bout en bout, puis analyse SWOT.

### 3.3 Processus audités

#### 3.3.1 Cycle de développement (équipe Dev)
- **Description** : itérations avec product owner (priorisation, démo mi-sprint, corrections), puis **génération manuelle des images en fin de sprint** et transmission des références à l'équipe Ops par e-mail/oral.
- **Forces** : rituel agile en place ; frontend bien maîtrisé ; Docker connu de tous.
- **Faiblesses** : équipe **débutante sur Java/Spring Boot, Gradle et JUnit** (la moitié du stack) ; livraison des artefacts en toute fin de sprint (effet tunnel) ; pas de revue de code outillée décrite.
- **Risques** : dette et mauvaises pratiques Java intégrées sans garde-fou ; bugs découverts tard ; dépendance à des sachants (Roubina/Sylvain).

#### 3.3.2 Chaîne d'intégration continue (`.gitlab-ci.yml` actuel)
- **Description** : 2 stages (`test`, `build`) × 2 composants = 4 jobs. Tests Karma et JUnit, builds Angular et Gradle. **Aucun job de construction/publication d'images, aucun scan, aucune analyse statique, aucun cache, aucun rapport de tests publié.**
- **Forces** : la base existe (tests exécutés sur les 2 composants) ; monorepo simple ; GitLab CI déjà adopté.
- **Faiblesses** : les images Docker livrées aux Ops sont construites **hors CI** (sur poste développeur) ; `npm ci` exécuté 2 fois sans cache ; pas de quality gate ; pas de versionnage d'artefacts ; incohérence JDK (build `gradle:jdk17`, exécution `openjdk21-jre`) ; image « tout-en-un » (front + back + supervisor) contraire aux bonnes pratiques un-processus-par-conteneur ; conteneurs exécutés en root.
- **Risques** : « ça marche sur ma machine » (images non reproductibles) ; CVE embarquées découvertes seulement chez les Ops ; impossibilité de tracer quelle image correspond à quel commit.

#### 3.3.3 Livraison et déploiement (équipe Ops)
- **Description** : réception d'un numéro de version d'image → **scan Trivy manuel** → si CVE : « retour à l'envoyeur » ; sinon **déploiement manuel** par commandes Docker sur l'environnement de démonstration.
- **Forces** : réflexe sécurité existant (Trivy) ; forte compétence Bash/Ansible ; outils de test d'infra connus (TestInfra, BashUnit).
- **Faiblesses** : contrôle de sécurité **après** livraison (trop tard) ; déploiement non scripté/rejouable ; dépendance à DockerHub ; pas de registre interne ; **base de données divergente entre Dev (HyperSQL) et Ops (PostgreSQL)** ; aucune sauvegarde automatisée décrite.
- **Risques** : allers-retours Dev↔Ops coûteux (déjà constaté : premier déploiement retardé par des CVE) ; erreurs humaines au déploiement ; comportements différents dev/prod à cause de la BDD ; perte de données sans back-up.

### 3.4 Synthèse (SWOT)

| **Forces** | **Faiblesses** |
|---|---|
| GitLab CI en place avec tests des 2 composants ; Docker maîtrisé par les 2 équipes ; Trivy déjà pratiqué par les Ops ; très bon niveau Bash/Ansible côté Ops ; projet jeune = peu de dette à rattraper | Construction et livraison des images manuelles, hors CI ; aucun scan ni quality gate automatisés ; pas de registre interne ; déploiement manuel non rejouable ; équipe Dev débutante sur la moitié du stack (Java/Gradle/JUnit) ; BDD divergente dev (HyperSQL) / ops (PostgreSQL) ; images root + « tout-en-un » ; pas de traçabilité image ↔ commit |
| **Opportunités** | **Menaces** |
| GitLab offre registry + container scanning + rapports sans nouvel outil ; SonarQube répond au souhait Dev et compense le niveau Java ; automatiser Trivy supprime l'irritant n°1 des Ops ; Ansible existant réutilisable pour le déploiement continu | CVE en production si les scans restent manuels ; goulot humain (2 Ops seulement) à l'approche de la mise en production ; perte de temps récurrente en allers-retours de fin de sprint ; monopolisation des connaissances (lead Dev/Ops) ; dépendance DockerHub (rate limits, indisponibilité) |

**Goulots d'étranglement principaux** : (1) génération manuelle des images en fin de
sprint, (2) contrôle sécurité post-livraison au lieu d'être en amont, (3) déploiement
manuel par 2 personnes seulement.

---

## 4. Recommandations

### 4.1 Objectifs

Automatiser la chaîne de la validation du code jusqu'à l'image déployable, déplacer
les contrôles qualité/sécurité **dans** le pipeline (shift-left), et outiller la montée en
compétence de l'équipe Dev — sans introduire d'outil étranger à l'écosystème déjà en
place (GitLab, Docker, Trivy, Ansible).

### 4.2 Recommandations pour l'automatisation et la chaîne CI

#### R1 — Construire et publier les images Docker dans le pipeline
- **Description** : ajouter un stage `package` qui construit les images front/back à chaque commit sur les branches d'intégration et les pousse dans le **GitLab Container Registry**, taguées `<branche>-<SHA court>`.
- **Raisonnement** : supprime le goulot n°1 (images manuelles), garantit la reproductibilité et la traçabilité image ↔ commit, et répond au souhait Ops d'un registre interne.
- **Implémentation** : jobs `docker:dind` + `docker build/push` ; refonte du Dockerfile en 2 images ciblées (front, back) multi-stage non-root ; abandon de l'image « tout-en-un ».
- **Impacts** : plus d'effet tunnel de fin de sprint ; les Ops tirent une image versionnée du registre interne.

#### R2 — Intégrer le scan de vulnérabilités Trivy dans la CI (shift-left sécurité)
- **Description** : job `security-scan` exécutant Trivy sur les images construites, bloquant si CVE de sévérité HIGH/CRITICAL.
- **Raisonnement** : le contrôle passe **avant** la livraison — irritant n°1 des Ops supprimé, plus de « retours à l'envoyeur » ; premier incident déjà constaté (déploiement retardé).
- **Implémentation** : image `aquasec/trivy` en job CI, cache de la base CVE, rapport artefact + seuil `--exit-code 1 --severity HIGH,CRITICAL`.
- **Impacts** : détection au commit (minutes) au lieu de fin de sprint (jours) ; MTTR sécurité réduit.

#### R3 — Déployer SonarQube avec quality gate bloquante
- **Description** : instance SonarQube Community (conteneur) analysant Java + TypeScript à chaque merge request, gate bloquante (bugs critiques, couverture minimale, duplication).
- **Raisonnement** : souhait explicite de l'équipe Dev ; compense le niveau débutant Java/JUnit en détectant les mauvaises pratiques avant intégration.
- **Implémentation** : `sonar-scanner` en stage `quality` après les tests (rapports JaCoCo/LCOV), variables `SONAR_HOST_URL`/`SONAR_TOKEN` en variables CI protégées.
- **Impacts** : qualité mesurée en continu ; support pédagogique pour Temim et Josefina ; base du taux de couverture exigé dans le rapport de performance.

#### R4 — Automatiser dépendances, back-up et notifications par scripts
- **Description** : scripts versionnés dans `scripts/` — gestion/audit des dépendances (`npm audit`, `gradle dependencies`), sauvegarde des artefacts et données (back-up horodaté), notification **Discord** des résultats de pipeline (Python).
- **Raisonnement** : demande explicite de la direction (scripts Bash/Python) ; les Ops sont très bons en Bash → adoption facile ; la notification restaure la boucle de feedback Dev↔Ops aujourd'hui « minime ».
- **Implémentation** : `scripts/backup.sh`, `scripts/notify_discord.py` (webhook en variable CI masquée), `scripts/check_deps.sh` ; appelés depuis les jobs CI.
- **Impacts** : zéro étape manuelle répétitive ; visibilité temps réel de l'état du pipeline pour les deux équipes.

#### R5 — Aligner les environnements sur PostgreSQL et scripter le déploiement
- **Description** : remplacer HyperSQL par PostgreSQL dès le développement (conteneur), et confier le déploiement de démonstration à un playbook **Ansible** rejouable (compétence Ops existante), en attendant l'orchestration Kubernetes (partie 2).
- **Raisonnement** : la divergence de BDD dev/ops est un risque de comportement en production ; le déploiement manuel Docker est le goulot n°3.
- **Implémentation** : service PostgreSQL dans `compose.yaml` et dans la CI de test ; playbook `deploy.yml` (pull image registre interne → run) exécuté par les Ops ou par un job manuel GitLab.
- **Impacts** : parité dev/prod ; déploiement en 1 commande, auditable et répétable.

*(Priorisation : R1 → R2 → R3 dans le sprint courant ; R4 → R5 au sprint suivant.
Conformément à la consigne, toutes les recommandations n'ont pas vocation à être
implémentées immédiatement — R5 (partie BDD) peut être planifiée avec le product owner.)*

---

## 5. Conclusion

### 5.1 Synthèse des constats

Le processus actuel repose sur une CI embryonnaire (tests seuls) suivie d'opérations
entièrement manuelles : construction d'images sur poste, contrôle sécurité après
livraison, déploiement à la main. Les compétences des deux équipes sont
complémentaires mais asymétriques (Dev fort en front/faible en Java, Ops fort en
automatisation système). Les outils déjà adoptés (GitLab, Docker, Trivy, Ansible)
suffisent, correctement assemblés, à automatiser la chaîne complète — complétés par
SonarQube pour la qualité.

### 5.2 Prochaines étapes

1. Valider les recommandations avec la CTO (fait — mail de Maria, phase 2 de la mission).
2. Formaliser la **normalisation du processus de développement et le plan de mise en œuvre CI** (document 2).
3. Implémenter le pipeline CI amélioré (R1-R4) sur le dépôt GitLab.
4. Étendre au CD : conteneurisation finalisée, orchestration Kubernetes/Helm, IaC Terraform/Ansible, monitoring ELK + métriques DORA (partie 2 de la mission).
