# AWS CSV Pipeline

# AWS Weather CSV Pipeline

Ce projet met en place un **data pipeline serverless** sur AWS pour traiter des fichiers CSV de données météo.

## Architecture

Le pipeline s’appuie sur les services suivants :

1. **Amazon S3**
   - Bucket `weather-csv-raw-data` : stockage des fichiers CSV bruts uploadés.
   - Bucket `weather-csv-processed-data` : stockage des fichiers nettoyés par Lambda.
   - Bucket `weather-csv-final-data` : stockage des données finales transformées (souvent compressées en GZIP).

2. **AWS Lambda**
   - Fonction déclenchée automatiquement à chaque nouvel objet dans le bucket *raw*.
   - Rôle : lire le CSV brut, effectuer un pré‑traitement (nettoyage, filtrage, normalisation) et écrire le résultat dans le bucket *processed*.

3. **AWS Glue**
   - **Glue Crawler** : détecte automatiquement le schéma des fichiers présents dans le bucket *processed* et alimente le **Glue Data Catalog**.
   - **Glue Job** (PySpark) : lit les données cataloguées, applique les transformations ETL (agrégations, jointures, enrichissements) et écrit le résultat dans le bucket *final*.

## Objectifs pédagogiques

- Mettre en pratique les 5V du Big Data (Volume, Vélocité, Variété, Véracité, Valeur) sur un cas **weather data**.
- Concevoir un pipeline ETL entièrement **serverless** et automatisé.
- Déployer l’infrastructure avec **Terraform** (Infrastructure as Code) et versionner le projet avec **Git/GitHub**.

## Infrastructure as Code (Terraform)

Le dossier `teraform/` contient les fichiers Terraform :

- `main.tf` : définition des buckets S3, des rôles IAM, de la fonction Lambda, du Glue Crawler et du Glue Job.
- `variables.tf` : variables (environnement, région, suffixes).
- `scripts/etl_csv_to_final.py` : script Glue utilisé par le job ETL.

Le déploiement se fait avec :

```bash
cd teraform
terraform init
terraform plan
terraform apply

