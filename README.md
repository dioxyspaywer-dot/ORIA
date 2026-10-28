# ORIA — prototype Android de contrôle parental transparent

Cette archive contient une base de projet avec deux variantes Android :
- **oria xx** : tableau de bord parent
- **oria** : assistant de configuration des autorisations

## Limites importantes
Ce projet est un **prototype de départ**, pas encore un système complet de surveillance à distance. Il ne capture ni ne transmet secrètement l'audio, la vidéo ou l'écran. Les flux à distance, l'enregistrement, l'association sécurisée des appareils et les tests sur de vrais téléphones restent à développer. Android exige une confirmation système pour le partage d'écran et des autorisations pour le microphone et la caméra.

## Contenu
- `android/` : projet Android natif avec variantes `parent` et `child`
- `server/` : serveur de signalisation WebSocket de démonstration (aucun média stocké)
- Icônes de lancement distinctes et stylisées pour `oria xx` et `oria`.
- `.github/workflows/build-apks.yml` : workflow GitHub Actions pour tenter de compiler les deux APK
- `render.yaml` : configuration Render à la racine

## Compilation sur GitHub
1. Extrais le ZIP et téléverse son contenu dans un dépôt GitHub.
2. Ouvre **Actions** et active les workflows si nécessaire.
3. Lance **Build oria xx and oria APKs** ou pousse une modification sur `main`.
4. Télécharge l'artefact `oria-xx-and-oria-apks` lorsque le workflow a réussi.

## Compilation
Le workflow configure JDK 17, Gradle 8.9 et installe explicitement Android SDK Platform 35 et Build Tools 35.0.0. Depuis `android/` :
```bash
gradle assembleParentDebug assembleChildDebug
```
Un vrai Gradle Wrapper standard peut être généré avec `gradle wrapper` avant une utilisation de production.

## Hébergement du serveur
Le serveur de démonstration se trouve dans `server/`. Le fichier `render.yaml` à la racine configure Render avec `rootDir: server`. Le serveur ne stocke pas de vidéos et n'implémente pas encore une liaison d'appareils sécurisée. Avant toute utilisation réelle, il faut ajouter authentification, validation des appareils, TLS/WSS, protection contre les abus et tests.

## Confidentialité
L'application ne doit pas être cachée pour surveiller quelqu'un à son insu. Les sessions audio/vidéo/écran doivent être visibles et autorisées par la personne qui utilise l'appareil.
