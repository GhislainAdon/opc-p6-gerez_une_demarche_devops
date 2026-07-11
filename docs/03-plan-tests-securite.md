# Plan de tests automatisés et de sécurité

**Projet** : Amélioration du pipeline CI de l'application Full-Stack (MicroCRM) — Orion
**Auteur** : Ghislain Adon, Expert DevOps
**Version** : 1.0 — juillet 2026
**Documents amont** : [audit et recommandations](./01-veille-audit-recommandations.md), [normalisation et plan CI](./02-normalisation-plan-ci.md)

---

## 1. Introduction

### 1.1 Contexte du projet

L'application Full-Stack d'Orion (frontend Angular 17, backend Spring Boot 3)
approche de sa première mise en production. L'audit a montré que les contrôles de
qualité et de sécurité étaient partiels (tests unitaires seuls) et exécutés
manuellement pour la partie sécurité (scan Trivy par les Ops après livraison).

### 1.2 Objectifs du plan de tests

Garantir qu'aucun code défectueux ou vulnérable n'atteint le registre d'images :
chaque commit est validé automatiquement par une chaîne de tests et de contrôles
bloquants, avec un retour aux équipes en quelques minutes.

## 2. Stratégie de test

### 2.1 Typologie des tests

| Type | Périmètre | Moment |
|---|---|---|
| **Tests unitaires** | Logique métier back (JUnit 5) et composants front (Karma/Jasmine) | Chaque push (stage `test`) |
| **Tests d'intégration** | Persistance JPA + endpoints REST (spring-boot-starter-test, base HSQLDB en mémoire) | Chaque push (inclus dans `test-back`) |
| **Analyse statique** | Bugs, code smells, hotspots sécurité, duplication (SonarQube Java + TS) | Chaque MR (stage `quality`) |
| **Tests de sécurité** | CVE des images (Trivy), audit des dépendances (`npm audit`, arbre Gradle) | Chaque push (stages `test` + `security`) |
| **Smoke tests de déploiement** | Démarrage réel des 2 conteneurs + réponses HTTP | Stage `deploy` (`deploy_demo.sh`) |
| **Tests d'infrastructure** *(partie 2)* | Playbooks et hôtes (TestInfra/BashUnit — compétence Ops existante) | Post-déploiement |

### 2.2 Outils de test

- **JUnit 5 + JaCoCo** : tests back + couverture (rapport XML consommé par SonarQube).
- **Karma/Jasmine + lcov** : tests front + couverture (idem).
- **SonarQube Community** : quality gate centralisée bloquante (`sonar.qualitygate.wait=true`).
- **Trivy** : scan d'images bloquant HIGH/CRITICAL, exceptions tracées dans `.trivyignore`.
- **curl** (smoke) : vérification HTTP des services déployés.

### 2.3 Environnements de test

- **CI éphémère** : conteneurs de jobs GitLab (gradle, cypress/browsers, docker:dind) — jetables, reproductibles.
- **Déploiement smoke** : réseau Docker éphémère créé/détruit par `deploy_demo.sh` (en CI via dind, ou sur poste).
- **Environnements dev/test/prod** *(partie 2)* : Kubernetes local (Docker Desktop ou Minikube), déploiement continu **GitOps par Argo CD** ; Terraform/Ansible pour le provisionnement/portabilité.

## 3. Processus d'intégration continue

### 3.1 Configuration du pipeline CI

GitLab CI (`.gitlab-ci.yml`), runners SaaS. Secrets exclusivement en variables
CI/CD masquées (`SONAR_TOKEN`, `DISCORD_WEBHOOK_URL`) ; caches npm/Gradle/Sonar/Trivy
par branche pour un feedback rapide.

### 3.2 Étapes du pipeline

1. **test** : compilation + tests unitaires/intégration + couverture + rapport de dépendances — rapports JUnit publiés dans l'interface MR.
2. **quality** : analyse SonarQube des 2 composants, gate bloquante.
3. **package** : artefacts classiques (JAR/bundle) + images Docker non-root taguées `<ref>-<SHA>` poussées au registre interne.
4. **security** : scan Trivy des 2 images, bloquant HIGH/CRITICAL.
5. **backup** : archive horodatée des artefacts (support rollback).
6. **deploy** : déploiement smoke des images + vérifications HTTP.
7. **notify** : notification Discord succès/échec aux équipes.

### 3.3 Gestion des données de test

- Back : base **HSQLDB en mémoire** recréée à chaque exécution + fixtures (`spring-boot-data-fixtures`) — aucune donnée persistante, aucun nettoyage requis.
- Front : mocks Jasmine, pas de dépendance réseau.
- Aucune donnée de production n'est utilisée dans les tests (conformité par construction).

## 4. Critères de réussite et seuils d'acceptation

### 4.1 Définition des critères de réussite

- 100 % des tests verts (aucun test ignoré sans justification en revue).
- Quality gate SonarQube : 0 bug bloquant/critique nouveau, couverture sur code nouveau ≥ seuil, duplication < 3 %.
- 0 CVE HIGH/CRITICAL non justifiée dans les images.
- Smoke déploiement : les 2 services répondent HTTP < 60 s après démarrage.

### 4.2 Seuils d'acceptation

| Métrique | Seuil initial | Cible (3 mois) |
|---|---|---|
| Couverture back (JaCoCo) | ≥ 60 % | ≥ 80 % |
| Couverture front (lcov) | ≥ 50 % | ≥ 70 % |
| CVE HIGH/CRITICAL images | 0 (hors `.trivyignore` justifié) | 0 |
| Durée totale du pipeline | < 15 min | < 10 min |

Progressivité assumée (équipe Dev débutante en Java) : 2 semaines d'observation
avant passage de la gate en mode bloquant, seuils relevés par paliers.

## 5. Plan de maintenance des tests

### 5.1 Mise à jour

Tout nouveau code arrive avec ses tests (critère de revue) ; toute correction de bug
commence par un test de non-régression ; images de base et base CVE Trivy mises à
jour au fil de l'eau (cache CI régénéré chaque semaine).

### 5.2 Surveillance

Tendances suivies dans SonarQube (dette, couverture) et dans les rapports de
pipeline ; tests instables (« flaky ») tracés et corrigés en priorité — un test
non fiable est un test supprimé ou réécrit.

### 5.3 Documentation et formation

README = référence d'exécution (jobs, scripts, variables). Sessions courtes de
pair-testing senior/junior (Sylvain → Temim, Josefina) sur JUnit — répond au point
faible identifié dans le sondage Dev.

## 6. Sécurité

### 6.1 Sécurisation des environnements

Jobs CI éphémères et isolés ; conteneurs applicatifs **non-root** (UID 10001), un
processus par conteneur ; images de base épinglées (`node:20-alpine`,
`gradle:8.7-jdk17-alpine`, `caddy:2-alpine`, `eclipse-temurin:17-jre-alpine`).

### 6.2 Protection des données sensibles

Secrets en variables GitLab **masquées et protégées**, jamais dans le dépôt
(`.env` gitignoré, `.env.example` comme gabarit) ; aucun secret dans les images
(vérifié par revue du Dockerfile) ; webhook Discord révocable indépendamment.

### 6.3 Sécurité des dépendances et du code source

`npm audit` + arbre Gradle en rapport à chaque push (`check_deps.sh`) ; hotspots
sécurité SonarQube revus en MR ; dépendances épinglées (`package-lock.json`,
versions Gradle explicites) ; branches `test`/`prod` protégées et promotion
contrôlée `dev → test → prod` (job `promotion-guard`), MR + approbation obligatoires.

### 6.4 Sécurisation du pipeline CI

Principe du moindre privilège : jobs docker limités au login registre par jeton CI
éphémère (`$CI_REGISTRY_*`) ; scan Trivy **avant** toute mise à disposition des
images aux Ops (shift-left — supprime les « retours à l'envoyeur ») ; exceptions
CVE uniquement via `.trivyignore` justifié et revu par l'équipe Ops.

### 6.5 Plan de réponse aux incidents

1. **Détection** : pipeline rouge → notification Discord immédiate aux 2 équipes.
2. **Qualification** : CVE bloquante ? gate qualité ? régression ? (rapports en artefacts).
3. **Réaction** : correction prioritaire ou rollback vers la dernière image saine (tag `<ref>-<SHA>` précédent + archive `backup.sh`).
4. **Post-mortem** : cause ajoutée au backlog (règle Sonar, test manquant, image de base), `.trivyignore` réévalué.
