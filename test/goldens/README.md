2 golden tests réels existent aujourd'hui : `CoverPlaceholder` (livre, audiobook,
titre vide) et `OfflineBadge`.

[Note Partie 8] Le plan initial (09_TESTS_CI.md) prévoyait 4 sujets : Loader,
ProgressBar dot-matrix, Badge OFFLINE, Library Card. Seuls `OfflineBadge` (déjà
présent) et le rendu couverture (`CoverPlaceholder`, servant de "Library Card"
faute d'un widget dédié) existent réellement dans le code à ce stade — `Loader`
et `DotMatrixProgressBar` n'ont jamais été construits (ce sont des widgets de
la Partie 5/8 UI-UX qui restent à faire). Ajouter leurs goldens quand ils
existeront, pas avant.

Générer la baseline AVANT que la CI ne puisse comparer utilement :

    flutter test --update-goldens test/goldens

Sinon le job `golden-tests` de `.github/workflows/ci.yml` échoue dès le premier run.

⚠️ Les golden tests Flutter sont sensibles au rendu de police, qui diffère
selon la plateforme (Linux/macOS/Windows). Le job `golden-tests` de la CI
tourne sur `ubuntu-latest` : générer la baseline sur un Linux (WSL, Docker, ou
laisser un premier run de CI échouer puis récupérer ses artefacts) donne des
résultats fiables. Générer la baseline sur macOS/Windows puis comparer en CI
Linux fera très probablement échouer la comparaison dès le premier run, sans
que ce soit un bug du widget lui-même.
