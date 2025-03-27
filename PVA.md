# 📋 Plan van Aanpak: Geïntegreerde DevSecOps & Cloud Infrastructuur

## 🎯 Doel van het project
Het opzetten van een geautomatiseerde DevSecOps-bouwstraat met monitoring, beveiliging en high-availability, in combinatie met het beheren van een Proxmox-cluster en de uitrol van webapplicaties voor klanten volgens DevOps-methodiek.

---

## 📌 Onderdeel 1: Infrastructuur (Cloud opdracht)

### Taken:
- Opzetten van een **Proxmox-cluster** met Ceph.
- Inrichten van **monitoringtools** voor de cluster en de virtuele machines (bijv. met Prometheus, Grafana).
- Aanmaken van 2 omgevingen:
  - **LXC containers** voor klant 1 (WordPress voor trainingen, lage kosten).
  - **VM met HA** voor klant 2 (CRM/WordPress, hoge beveiliging en beschikbaarheid).

### Tools:
- Proxmox
- Ceph
- Grafana + Prometheus
- Bash-scripts + Ansible (voor automatisering)

---

## 📌 Onderdeel 2: DevSecOps Pipeline (DT-opdracht)

### Taken:
- Self-hosted installatie van **Gitea** (op Proxmox of lokaal).
- **CI/CD pipeline** opzetten met Drone CI of Gitea Actions:
  - Build → Test → Deploy naar productie.
- Automatische uitrol van een zelfgekozen applicatie (bijv. NodeJS of WordPress).
- Implementatie van ten minste 1 optioneel DevSecOps-concept, zoals:
  - **Monitoring van de applicatie**
  - **Security testing** (bijv. OWASP ZAP of Snyk)
  - **Immutable infrastructure** via containerisatie

### Tools:
- Gitea
- Drone CI of Gitea Actions
- Docker / LXC
- (optioneel: OWASP ZAP, Trivy, etc.)

---

## 💡 Koppeling tussen beide opdrachten

| Cloud opdracht                        | DevSecOps opdracht                     |
|--------------------------------------|----------------------------------------|
| Proxmox infrastructuur               | Host je Gitea server hierop            |
| Monitoring van cluster & VMs         | Monitoring tools ook gebruiken voor de apps |
| Containerisatie voor klant 1         | CI/CD pipeline deployt naar containers |
| HA omgeving voor klant 2             | Test failover via rollbacks of alerts  |
| Automatisering met scripts & Ansible| Documenteer in CI-configuraties        |

---

## 📦 Oplevering (voor beide opdrachten te gebruiken)

- Markdown-documentatie met uitleg per concept (DevOps & Cloud)
- Screenshots van het werkende systeem (cluster, pipelines, monitoring)
- Git repo (geconfigureerd op Gitea) met alle YAML/configuratiebestanden
- Opnames van demonstraties (build + deployment + monitoring)
- Eventueel een presentatie van de volledige workflow

---

## 📆 Planning (4 weken)

| Week | Activiteit                                                                 |
|------|---------------------------------------------------------------------------|
| 1    | Proxmox cluster + Ceph setup + VM en LXC omgevingen voor klant 1 en 2     |
| 2    | Monitoring implementeren + Gitea installatie + CI/CD pipeline opzetten     |
| 3    | Webapplicatie integreren + security & monitoringconcepten implementeren    |
| 4    | Testen, documentatie schrijven, opnames maken en oplevering afronden       |
