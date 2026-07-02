# Rapport de performance — Démarche DevOps Orion

**Destinataires** : Maria (CTO) et parties prenantes — **Auteur** : Ghislain Adon, Expert DevOps
**Version** : 1.0 (draft) — juillet 2026

---

## 1. Synthèse du projet

La mission a transformé un processus de livraison artisanal (CI limitée aux tests,
images construites sur poste, contrôle sécurité manuel après livraison, déploiement
à la main) en une **chaîne CI/CD automatisée de bout en bout** :

- **Pipeline GitLab CI à 7 stages** (tests, qualité, packaging, sécurité, back-up, déploiement, notification), exécuté à chaque commit — 10 jobs, tous verts sur la branche d'intégration.
- **Images Docker non-root tracées** (`<branche>-<SHA>`) publiées dans le **registre interne** GitLab — la dépendance DockerHub des Ops est supprimée.
- **Sécurité shift-left** : scan Trivy bloquant + audit de dépendances à chaque commit ; quality gate SonarQube prête (activation par variables CI).
- **Déploiement industrialisé** : chart Helm (dev/staging), IaC **Terraform + Ansible**, exécuté et vérifié sur cluster Kubernetes (Minikube).
- **Observabilité** : stack **ELK** opérationnelle (logs conteneurs → Logstash/GELF → Elasticsearch → Kibana) + calcul automatisé des **métriques DORA**.

## 2. Métriques DORA (fenêtre de mise en place, branche d'intégration)

Mesurées automatiquement par `scripts/dora_metrics.py` depuis l'API GitLab
(`reports/dora_metrics.json`) :

| Métrique | Valeur mesurée | Lecture |
|---|---|---|
| **Deployment Frequency** | 1 pipeline de livraison réussi sur la fenêtre (5 exécutions au total) | Chaque commit produit désormais des artefacts déployables — la fréquence suit le rythme des commits |
| **Lead Time for Changes** | **≈ 6 min** (médiane commit → pipeline succès) | Contre plusieurs jours dans le processus manuel (génération d'images en fin de sprint) |
| **Change Failure Rate** | 80 % sur la fenêtre de mise en place | Attendu en phase de construction : 4 échecs = la **gate de sécurité faisant son travail** (voir §4) ; tendance cible < 15 % en régime établi |
| **MTTR** | **≈ 36 min** (échec pipeline → succès suivant) | Diagnostic immédiat grâce aux rapports en artefacts + notifications |

> Ces valeurs constituent la **baseline** ; le script est rejouable à tout moment
> (`python scripts/dora_metrics.py --days 30`) pour suivre la tendance en exploitation.

## 3. Résultats des tests et couverture

| Contrôle | Résultat |
|---|---|
| Tests backend (JUnit 5, unitaires + intégration JPA/REST) | ✅ 100 % verts à chaque pipeline (rapports JUnit publiés dans GitLab) |
| Tests frontend (Karma/Jasmine, ChromeHeadless) | ✅ 100 % verts à chaque pipeline |
| Couverture | JaCoCo (XML+HTML) et lcov produits à chaque exécution, remontés en artefacts et consommés par SonarQube ; seuils progressifs 60 % → 80 % définis dans le plan de tests |
| Smoke test de déploiement | ✅ en CI (dind) **et** en local : les 2 services répondent HTTP 200 |
| Déploiement Kubernetes | ✅ `terraform apply` : namespaces `dev` (1+1 pods) et `staging` (2+2 pods, résilience) — tous `Running`, front/back HTTP 200 via port-forward |

## 4. Sécurité — un cas réel traité par la chaîne

Le premier passage du pipeline a **bloqué 28 vulnérabilités réelles** dans les images
(dont **4 CRITICAL** sur le serveur Tomcat embarqué) — exactement le scénario vécu par
les Ops (« retours à l'envoyeur ») désormais détecté **avant** livraison :

| Itération | Action | Résultat |
|---|---|---|
| 1 | Scan initial | 26 CVE back (4 CRITICAL Tomcat 10.1.20, jackson, spring) + 2 CVE front + 2 OS |
| 2 | Spring Boot 3.2.5 → 3.5.14, Tomcat forcé 10.1.55, json-smart 2.5.2, `apk upgrade` images | Reste 2 CVE (jackson via BOM) |
| 3 | Surclassement `jackson-bom` 2.21.4 ; 2 CVE stdlib Go du binaire Caddy **gouvernées** dans `.trivyignore` (classe DoS, aucun correctif upstream, justifiées et datées) | ✅ **0 CVE bloquante** — pipeline vert |

Temps total de remédiation : **< 2 h**, entièrement tracé dans l'historique Git.
Dans l'ancien processus, ces mêmes CVE auraient été découvertes par les Ops après
livraison, en fin de sprint.

## 5. Captures du monitoring

- `docs/captures/kibana-discover.png` — Kibana (data view `orion-logs-*`) : logs des conteneurs back/front centralisés en temps réel via GELF→Logstash, enrichis (composant, verbe/statut HTTP) — 55 documents lors du test de trafic.
- `docs/captures/kubectl-pods.txt` — état des pods dev/staging après `terraform apply`.
- Pipelines et rapports (JUnit, Trivy, backups) : onglet CI/CD du dépôt GitLab.
- *(À compléter avant soutenance : dashboard Kibana 3 visualisations + capture SonarQube après activation de l'instance.)*

## 6. Gains obtenus

| Avant | Après |
|---|---|
| Images construites sur poste en fin de sprint | Images construites/publiées à **chaque commit**, traçables au SHA |
| Scan sécurité manuel, après livraison | Scan **bloquant dans le pipeline**, exceptions gouvernées |
| Déploiement manuel (2 personnes, commandes Docker) | `terraform apply` / playbook Ansible rejouables + smoke test automatique |
| Dépendance DockerHub | Registre interne GitLab |
| Feedback en jours (fin de sprint) | Feedback en **< 15 min** (pipeline + notification Discord) |
| Aucune mesure | Couverture, rapports de tests, métriques DORA automatisées |

## 7. Recommandations d'amélioration continue

1. **Activer SonarQube en mode bloquant** après les 2 semaines d'observation (instance locale fournie, `tools/sonarqube/compose.yaml`).
2. **Basculer PostgreSQL** en développement (parité dev/prod — recommandation R5 de l'audit) et ajouter le back-up de données à la stratégie existante.
3. **Releases sémantiques** : introduire semantic-release sur `master` (les Conventional Commits sont déjà en place).
4. **Étendre les dashboards** Kibana (latences, taux d'erreur par endpoint) et ajouter l'alerting (Watcher/Grafana) au-delà des notifications de pipeline.
5. **Montée en compétence** : pair-testing JUnit senior/junior (point faible identifié côté Dev) ; rotation Ops sur la maintenance du pipeline pour éviter la monopolisation des connaissances.
