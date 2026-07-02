# Normalisation du processus de développement et plan de mise en œuvre de la chaîne CI

**Projet** : Amélioration du pipeline CI de l'application Full-Stack (MicroCRM) — Orion
**Auteur** : Ghislain Adon, Expert DevOps
**Version** : 1.0 — juillet 2026
**Document amont** : [01-veille-audit-recommandations.md](./01-veille-audit-recommandations.md)

---

## 1. Introduction

### 1.1 Objectifs

Normaliser le processus de développement de l'application Full-Stack afin que chaque
commit suive un chemin unique, automatisé et contrôlé, du poste du développeur
jusqu'à l'image déployable dans le registre interne. Ce document fixe les normes
(§2) puis le plan de mise en œuvre de la chaîne CI (§3), en application des
recommandations R1-R5 de l'audit.

### 1.2 Contexte

État initial du pipeline (audit §3.3.2) : 2 stages (`test`, `build`), 4 jobs, aucune
construction d'image, aucun contrôle qualité/sécurité, livraison manuelle en fin de
sprint. Équipes : 4 Dev (fortes en Angular, débutantes en Java/Gradle/JUnit),
2 Ops (très fortes en Bash/Ansible, Trivy déjà pratiqué manuellement).

## 2. Normes et bonnes pratiques

### 2.1 Principes de base

1. **Automatisation** : aucune opération de livraison manuelle ; tout passe par le pipeline.
2. **Répétabilité** : un même commit produit toujours les mêmes artefacts (builds conteneurisés, versions épinglées).
3. **Shift-left** : qualité et sécurité contrôlées au commit, pas après livraison.
4. **Traçabilité** : chaque image est taguée `<ref>-<SHA court>` — on sait toujours quel code tourne.
5. **Feedback rapide** : résultats de pipeline notifiés aux équipes en temps réel (Discord).

### 2.2 Conventions d'écriture de code et règles de style

- **Frontend** : ESLint + Prettier (config Angular par défaut), TypeScript strict.
- **Backend** : Checkstyle (convention Google Java), avertissements traités comme dette suivie dans SonarQube.
- **Scripts** : Bash `set -euo pipefail` + ShellCheck ; Python PEP 8 (ruff).
- Nommage des fichiers, classes et variables en anglais ; documentation utilisateur en français.

### 2.3 Gestion des versions

- **Modèle de branches** : GitLab Flow simplifié — `master` (production/baseline, protégée), branches de fonctionnalité `feat/<sujet>` courtes (< 3 jours), intégration par merge request.
- **Commits** : Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `ci:`) — prépare l'automatisation future des releases (semantic versioning).
- **Tags d'images** : `<branche>-<SHA court>` en continu.

### 2.4 Revue de code

- Toute merge request requiert **1 approbation** (lead ou senior) + pipeline vert.
- La quality gate SonarQube est un critère d'acceptation **bloquant**.
- Les juniors (Temim, Josefina) sont relecteurs en binôme avec un senior — objectif pédagogique explicite.

### 2.5 Intégration continue

- **Fréquence** : pipeline à chaque push ; intégration sur `master` au moins quotidienne (fin de l'effet tunnel de fin de sprint).
- **Critères de réussite** : compilation OK, 100 % des tests verts, quality gate SonarQube passée, scan Trivy sans CVE HIGH/CRITICAL.
- **Outil** : GitLab CI (runners SaaS), stages `verify → test → quality → package → security → notify`.

### 2.6 Tests

- **Unitaires** : JUnit (back), Karma/Jasmine (front) — exécutés à chaque push, rapports JUnit publiés dans GitLab.
- **Couverture** : JaCoCo (back) + lcov (front) remontés dans SonarQube ; seuil initial 60 %, cible 80 %.
- **Infrastructure** : TestInfra/BashUnit conservés côté Ops pour les playbooks (compétence existante).

### 2.7 Sécurité

- **Images** : scan Trivy bloquant (HIGH/CRITICAL) avant tout push au registre.
- **Code** : règles security hotspots SonarQube ; `npm audit` / `gradle dependencies` en job d'observation.
- **Secrets** : exclusivement en variables CI/CD GitLab masquées/protégées (`SONAR_TOKEN`, `DISCORD_WEBHOOK_URL`) — jamais dans le dépôt (`.env` gitignoré en local).
- **Conteneurs** : utilisateurs non-root, images de base épinglées, un processus par conteneur (suppression de l'image « tout-en-un »).

### 2.8 Documentation

- README technique du dépôt : instructions de build/test/déploiement + but, fonctionnement et paramètres **de chaque script** (exigence de la direction).
- Chaque étape du pipeline documentée dans le README (tableau stage → job → rôle).
- Documentation CI/CD complète (architecture, plans de sécurité/tests/rollback) maintenue dans `docs/`.

## 3. Plan de mise en œuvre

### 3.1 Objectifs

Livrer en deux sprints un pipeline CI complet et démontrable sur le dépôt GitLab,
puis étendre au CD (conteneurisation orchestrée, IaC, monitoring) au sprint suivant.

### 3.2 Étapes

#### Étape A — Socle CI (recommandations R1, R4 partiel)
- **Description** : refonte du `.gitlab-ci.yml` (stages complets, cache npm/Gradle, rapports JUnit), Dockerfiles multi-stage non-root front/back, publication au Container Registry avec tags traçables.
- **Responsables** : Expert DevOps (implémentation), Roubina (revue Dev), Nico (revue Ops).
- **Livrables** : pipeline vert sur MR, images `front`/`back` dans le registre interne.

#### Étape B — Qualité et sécurité (R2, R3)
- **Description** : instance SonarQube (conteneur) + jobs `quality` avec quality gate bloquante ; job Trivy bloquant sur les images ; `npm audit`/`gradle dependencies` en observation.
- **Responsables** : Expert DevOps ; Maïa (validation seuils sécurité) ; Sylvain (adoption Dev).
- **Livrables** : quality gate active sur MR, rapport Trivy en artefact, plan de tests/sécurité documenté.

#### Étape C — Scripts d'automatisation et notifications (R4)
- **Description** : `scripts/check_deps.sh` (dépendances), `scripts/backup.sh` (sauvegarde artefacts/données horodatée), `scripts/notify_discord.py` (notification de fin de pipeline), intégrés aux jobs.
- **Responsables** : Expert DevOps ; Nico (revue Bash).
- **Livrables** : scripts versionnés, documentés dans le README, appelés par la CI.

#### Étape D — Déploiement rejouable et parité BDD (R5)
- **Description** : PostgreSQL en conteneur dès le développement (parité dev/ops) ; déploiement de démonstration par playbook Ansible tirant l'image du registre interne (job manuel GitLab).
- **Responsables** : Nico/Maïa (playbook), Expert DevOps (intégration CI).
- **Livrables** : `compose.yaml` avec PostgreSQL, playbook `deploy.yml`, job `deploy:demo` manuel.

#### Étape E — Extension CD (partie 2 de la mission)
- **Description** : orchestration Kubernetes/Helm (Minikube), IaC Terraform + Ansible, monitoring ELK + indicateurs DORA, optimisation des processus.
- **Responsables** : Expert DevOps ; équipe Ops en binôme (montée en compétence K8s).
- **Livrables** : charts Helm, code Terraform/Ansible versionnés, stack ELK opérationnelle, rapport de performance.

### 3.3 Ressources nécessaires

- **Humaines** : 1 Expert DevOps (plein temps sur la mission), relais leads Dev/Ops (~10 % de leur temps pour revues et validation).
- **Techniques** : GitLab SaaS (runners partagés + Container Registry, offre existante), 1 hôte Docker pour SonarQube (2 vCPU / 4 Go RAM), Minikube sur poste pour l'étape E — **aucun coût de licence** (outils open source / éditions Community).
- **Budget** : temps homme uniquement ; pas d'achat d'outillage.

### 3.4 Calendrier prévisionnel

| Semaine | Étape | Jalon |
|---|---|---|
| S1 | A | Pipeline refondu + images dans le registre |
| S2 | B | Quality gate SonarQube + scan Trivy bloquants |
| S2-S3 | C | Scripts back-up/dépendances/notifications actifs |
| S3 | D | Déploiement démo rejouable + PostgreSQL partout |
| S4-S5 | E | K8s/Helm + IaC + ELK/DORA + rapport de performance |

### 3.5 Gestion des risques

| Risque | Prob. | Impact | Mitigation |
|---|---|---|---|
| Runners SaaS lents / quotas CI atteints | Moyenne | Retards pipeline | Cache agressif npm/Gradle ; jobs parallèles ; runner spécifique en secours |
| Quality gate trop stricte → blocage de l'équipe Dev junior | Moyenne | Frustration, contournement | Seuils progressifs (60 % → 80 %), période d'observation de 2 semaines avant mode bloquant |
| Faux positifs Trivy sur images de base | Moyenne | MR bloquées à tort | Fichier `.trivyignore` revu par Maïa, mise à jour régulière des images de base |
| SonarQube indisponible (hôte unique) | Faible | Perte de la gate | Job `allow_failure` temporaire documenté + redémarrage conteneur scripté |
| Compétences K8s limitées (étape E) | Haute | Retard partie 2 | Option locale Minikube (sans coût), binômes Ops + documentation pas-à-pas |

## 4. Conclusion

### 4.1 Synthèse

La normalisation transforme un processus artisanal (images sur poste, contrôles
a posteriori, déploiement manuel) en une chaîne unique automatisée : conventions de
code et de branches, revue outillée, CI avec quality gate et scan de sécurité
bloquants, artefacts tracés dans un registre interne, scripts d'automatisation
documentés. Elle s'appuie délibérément sur l'existant (GitLab, Docker, Trivy,
Ansible) pour minimiser la conduite du changement.

### 4.2 Prochaines étapes

Exécution du plan (étapes A→D sur les 3 premières semaines), puis extension CD
(étape E) : orchestration, IaC et monitoring, mesurés par les métriques DORA dans le
rapport de performance final.
