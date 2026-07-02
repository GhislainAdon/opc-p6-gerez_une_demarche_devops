# Auto-évaluation — Option B : Gérez une démarche DevOps

> Transposition markdown de la fiche officielle (`consigne-pdf/artefacts/Fiche_autoevaluation_OptionB.pdf`).
> ✅ = validé (preuve entre parenthèses) — 🔲 = à finaliser avant dépôt. Contenu à copier-coller dans le PDF éditable.
> **Branche `guide` uniquement — ne jamais fusionner dans `solution`.**

## 1. Concevoir, mettre en œuvre et gérer des pipelines CI
*Livrable : lien dépôt GitLab (scripts, config CI/CD, IaC, conteneurs)*

- [x] Pipeline CI/CD configuré sur GitLab, exécution sans erreur de bout en bout — *pipeline 100 % vert : 10/10 jobs (tests, package, security, backup, deploy-smoke)*
- [x] Conteneurs + fichiers Terraform/Ansible intégrés au dépôt, organisés et cohérents — *`Dockerfile`, `deploy/terraform/`, `deploy/helm/`, `deploy/ansible/`, `monitoring/elk/`*
- [x] Chaîne fonctionnelle avec les étapes clés : build, test, déploiement — *7 stages : test → quality → package → security → backup → deploy → notify*
- [x] README documentant structure du pipeline, outils, procédures de déploiement — *section « Chaîne CI/CD » : tableau stage/job/rôle + variables + procédures*
- [x] Chaque étape clairement identifiée et compréhensible pour un autre développeur — *commentaires d'en-tête du `.gitlab-ci.yml` + README*
- [x] Automatisations maintenables, reproductibles, conformes aux bonnes pratiques DevOps — *jobs conteneurisés, caches, tags traçables `<branche>-<sha>`, `.gitattributes` LF*

## 2. Automatiser les pipelines CI/CD en orchestrant les conteneurs et en mettant en œuvre l'IaC (partie 1 du tableau)
*Notes : bonnes pratiques transverses*

- [x] Instructions claires de déploiement dans le README (reproductibilité) — *sections CI/CD, Helm/Minikube, Terraform/Ansible, ELK*
- [x] Bonnes pratiques de développement : code commenté (rôle des ressources), aucune donnée sensible exposée (`.env` gitignoré, variables CI masquées), notes explicatives — *revue faite le 02/07*
- [x] Outils de surveillance configurés (code + pipeline) pour suivre les métriques — *stack ELK (GELF→Logstash→ES→Kibana) + `dora_metrics.py`*
- [x] Infrastructure instrumentée pour analyser les données collectées — *logs enrichis (composant, verbe/statut HTTP), index `orion-logs-*`*
- [x] Schéma d'architecture détaillé (services + interactions) — *2 schémas Mermaid dans `docs/livrable-2-documentation-cicd.md` (§5.2)*
- [x] Je peux expliquer la contribution des optimisations à la performance/disponibilité du SI — *préparé dans le support de soutenance (notes slides 8-10)*

## 3. Planifier la mise en production CI/CD
*Livrable : Documentation CI/CD (plan de sécurité, plan d'automatisation des releases)*

- [x] Outils/technologies adaptés aux besoins d'Orion et compatibles avec l'existant — *veille + matrices comparatives (`docs/01`), choix justifiés (`docs/livrable-2` §3)*
- [x] Choix techniques facilitant l'intégration et respectant les standards — *GitLab/Docker/Trivy/Ansible déjà en place chez Orion, aucun outil exotique*
- [x] Je peux expliquer la contribution de la chaîne CI à la collaboration Dev/Intégration/Exploitation — *fin des « retours à l'envoyeur », notifications communes (soutenance slide 10)*
- [x] Objectifs CI alignés avec les priorités de l'organisation — *§2.2 de la documentation CI/CD (5 objectifs mesurables)*
- [x] Plan de mise à jour/sauvegarde structuré avec rollback et back-up — *`docs/livrable-2` §7.4-7.6 + `scripts/backup.sh`*
- [x] Plan accessible à toutes les parties prenantes, y compris PSH — *documents structurés (titres hiérarchisés, tableaux légendés, contrastes) compatibles lecteurs d'écran*
- [x] Satisfait du niveau de détail du plan de mise en production — *revue le 02/07*

## 4. Automatiser les pipelines CI/CD, orchestrer les conteneurs et déployer
*Livrables : Documentation CI/CD complète + lien dépôt GitLab*

- [x] Plan de conteneurs + plan d'optimisation des releases cohérents avec Orion — *`docs/livrable-2` §5 et §7*
- [x] Plans sans erreur technique bloquante, fidèles à la configuration réelle — *vérifiés contre le dépôt le 02/07*
- [x] Documentation cohérente avec le déploiement effectif — *terminologie unifiée (tags, environnements dev/staging)*
- [x] Dockerfiles et Helm Charts fonctionnels dans le dépôt — *builds CI verts ; chart déployé (`helm_release` status deployed)*
- [x] Orchestration Kubernetes vérifiée — *Minikube : dev 1+1 pods, staging 2+2 pods Running, HTTP 200 (captures `docs/captures/`)*
- [x] Processus d'automatisation du déploiement documentés et justifiés (logique + traçabilité) — *`docs/livrable-2` §7.1-7.2*
- [x] Automatisation des releases fonctionnelle, reproductible, tracée dans le pipeline — *tags `<branche>-<sha>`, artefacts, historique pipelines*
- [x] Pipelines limitant erreurs et points de défaillance, temps optimisés — *caches npm/Gradle/Trivy/Sonar, `needs:` (pipeline < 15 min)*
- [x] Je peux justifier mes choix technologiques (contexte Orion) — *tableau des choix justifiés + alternatives écartées (`docs/livrable-2` §3)*
- [x] Documentation permettant de reproduire le pipeline sans difficulté — *README + devcontainer Codespaces (16 Go) pour reproduction 1-clic*
- [x] Plan de release : versioning, livraison, rollback détaillés, applicables en environnement de test — *§7.3-7.4 ; rollback = re-bascule tag précédent, testé conceptuellement via registre*

## 5. Mettre en place des mesures de sécurité (DevSecOps)
*Livrables : Documentation CI/CD (plan de sécurité) + rapport de performance*

- [ ] 🔲 Analyse statique SonarQube intégrée à la chaîne CI — *job `sonarqube` prêt (gate bloquante `qualitygate.wait`) ; **reste : démarrer l'instance (`tools/sonarqube/compose.yaml`) + variables `SONAR_*` + 1 exécution de preuve***
- [x] Tests automatisés de sécurité à chaque build — *Trivy bloquant HIGH/CRITICAL sur les 2 images + `check_deps.sh` (npm audit / arbre Gradle)*
- [x] Sécurité appliquée à chaque étape : secrets (variables CI masquées), contrôle d'accès (branche protégée, registre privé), analyse du code, validation des déploiements (smoke) — *`docs/03-plan-tests-securite.md` §6*
- [x] Vulnérabilités identifiées, priorisées, corrigées avant production — ***cas réel : 28 CVE bloquées → remédiation racine (Spring Boot 3.5.14, Tomcat 10.1.55, jackson 2.21.4, apk upgrade) → 0 CVE bloquante ; 2 exceptions gouvernées `.trivyignore`***
- [ ] 🔲 Captures des dashboards ELK (supervision sécurité + alertes) dans le rapport de performance — *1 capture Kibana faite ; **reste : dashboard sécurité dédié + capture***
- [x] Rapports de tests de sécurité lisibles et exploitables (Dev + Ops) — *rapports Trivy en artefacts + `.trivyignore` justifié/daté*
- [x] Gains sécurité + recommandations documentés dans le rapport de performance — *§4 et §7 du rapport*
- [x] Je peux expliquer la contribution de la sécurité intégrée à la fiabilité du processus — *préparé (soutenance slide 6 + notes)*

## 6. Mettre en place un système de mesure de performance
*Livrables : Documentation CI/CD + rapport de performance*

- [ ] 🔲 Tableaux de bord de monitoring ELK (disponibilité, performance, sécurité) — *stack opérationnelle + logs indexés ; **reste : dashboard Kibana 3 visualisations (pics de trafic, erreurs par service)***
- [x] Données analysées, points de vigilance et axes d'amélioration identifiés — *rapport de performance §5-7*
- [x] Solution viable pour mesurer les indicateurs DORA — *`scripts/dora_metrics.py` (API GitLab), exécuté sur les pipelines réels*
- [ ] 🔲 KPIs clairs et pertinents affichés dans les tableaux de bord — *dépend du dashboard ci-dessus*
- [x] Indicateurs de performance définis et justifiés (DORA, logs ELK, métriques techniques) — *`docs/livrable-2` §7.7 + rapport §2*
- [x] Indicateurs DORA listés avec leur signification — *rapport de performance §2 (tableau + lecture)*
- [x] Métriques ELK visibles et justifiées — *champs enrichis expliqués (README monitoring)*
- [ ] 🔲 Alertes paramétrées (disponibilité, performance, sécurité) — *notifications pipeline Discord prêtes ; **reste : règle d'alerte Kibana/ES sur erreurs applicatives***
- [x] Interprétation des données → actions d'amélioration argumentées — *rapport §7 (5 recommandations)*
- [x] Captures, analyses et conclusions dans le rapport de performance — *baseline DORA réelle (lead time ≈ 6 min, MTTR ≈ 36 min) ; captures à compléter avec les dashboards*
- [x] Je peux expliquer la contribution à l'amélioration continue — *soutenance slide 9 + notes*

## 7. Développer et mettre en œuvre des processus pour optimiser la disponibilité et la performance du SI
*Livrable : rapport de performance*

- [x] Propositions d'optimisation claires, réalistes, justifiées — *rapport §7 (SonarQube bloquant, PostgreSQL, semantic-release, dashboards, montée en compétence)*
- [x] Comparaison avant/après dans « Gains obtenus » — *rapport §6 (tableau avant/après)*
- [x] Recommandations argumentées et contextualisées (besoins techniques et organisationnels d'Orion) — *chaque reco reliée à un constat d'audit*
- [x] Synthèse structurée des résultats monitoring + tests — *rapport §3 et §5*
- [x] Conclusions appuyées sur des métriques concrètes — *DORA mesurées, durées de jobs, 28→0 CVE*
- [x] Document clair, visuel, lisible par des non-techniques — *tableaux, métriques vulgarisées (lecture DORA)*
- [x] Impacts mesurés présentés (disponibilité, stabilité, performance) — *rapport §2 et §6*
- [x] Format professionnel adapté au CTO — *ton neutre, synthèse en tête*

## 8. Automatiser le processus de release avec le versioning
*Livrables : GitLab section Scripts + Documentation CI/CD (plan d'automatisation des releases)*

- [x] Processus de release automatisé et documenté — *`docs/livrable-2` §7 (stratégie images immuables + promotion par tag)*
- [x] Pratiques de maintenance et rollback décrites et applicables — *§7.4 (re-bascule tag précédent, `backup.sh` + checksum)*
- [x] Feedbacks du pipeline analysés pour identifier les améliorations — *3 itérations de remédiation CVE tracées dans Git*
- [x] Observations/améliorations release intégrées au rapport (« Gains obtenus ») — *rapport §6-7*
- [x] Recommandations répondant aux problématiques observées — *semantic-release proposé (Conventional Commits déjà en place)*
- [x] Chaque script documenté : but, fonctionnement, paramètres, conditions d'exécution — *tableau des 5 scripts dans le README*
- [x] Plan d'automatisation des releases : étapes de livraison, rollback, conventions de versioning — *§7.2-7.4*
- [x] Scripts exécutables dans le pipeline, traçabilité versions/déploiements — *tous appelés par les jobs CI (pipeline vert)*

---

## Synthèse avant dépôt

**Reste à faire pour tout cocher** (4 cases) :
1. Démarrer SonarQube local + variables CI + 1 pipeline avec la gate exécutée (compétence 5).
2. Dashboard Kibana avec 3 visualisations (pics de trafic, erreurs par service, sécurité) + captures dans le rapport (compétences 5-6).
3. Règle d'alerte applicative (Kibana alerting ou Watcher) (compétence 6).
4. Rafraîchir les captures/métriques du rapport de performance après 1-2.
