# Job Électricien - FiveM Standalone

Un script de job d'électricien indépendant (standalone) pour FiveM.
Il intègre un mini-jeu de diagnostic procédural avec une difficulté évolutive (jeux inspiré du `zip` de LinkedIn.

## Fonctionnalités

* **100% Standalone :** Aucun framework (ESX, QB-Core, VRP) n'est requis pour faire fonctionner ce script.
* **Mini-jeu Procédural :** Les grilles de diagnostic sont générées dynamiquement via un algorithme DFS, garantissant que chaque puzzle est unique et toujours réalisable.
* **Difficulté Évolutive :** La taille de la grille et la marge d'erreur s'adaptent automatiquement au nombre de réparations déjà effectuées par le joueur.
* **Performance Optimisée :** La consommation du script côté client est gérée dynamiquement, tombant à 0.00ms lorsque le joueur n'est pas en interaction.
* **Sécurité Serveur :** Vérifications des distances et des états de mission côté serveur pour empêcher l'exploitation des gains.

## Installation

1. Téléchargez ou clonez les fichiers de ce dossier.
2. Placez le dossier dans le répertoire `resources` de votre serveur FiveM.
3. Ajoutez `ensure [nom_du_dossier]` dans votre fichier `server.cfg`.

## Commandes Administrateur

* `/addborne` : Imprime les coordonnées de votre position actuelle dans la console F8 pour ajouter facilement de nouveaux points de réparation.
* `/setrepairs [nombre]` : Permet de définir manuellement votre nombre de réparations (idéal pour tester les différents niveaux de difficulté du mini-jeu).
* `/showbornes` : Affiche ou masque temporairement les blips administratifs de toutes les stations électriques directement sur la carte.
