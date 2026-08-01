# TODO - Corrections tests

- [x] Revue et correction initiale migration rollback tentative (transaction onUpgrade).
- [ ] Mettre en place stratégie **staged upgrade** (DB temporaire + remplacement uniquement si succès) pour faire passer `migration_rollback_test.dart`.
- [ ] Relancer `migration_rollback_test.dart`.
- [ ] Gérer `widget_test.dart` si encore KO (cleanup/PathNotFoundException).
- [ ] Ignorer/mettre à part les golden tests tant que les PNG n’existent pas.

