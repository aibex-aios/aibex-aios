# app-taschenrechner

Demo-App von AIbex AIOS: programmierbarer Taschenrechner mit umgekehrter polnischer Notation nach dem Vorbild des HP-15C (Stack X, Y, Z, T): Ziffern, Punkt, Grundrechenarten, `CHS`, `ENTER`, vier Funktionstasten A bis D und die Taste *LEARN*. Ein Quadrat ist `ENTER ×`. Mit *LEARN* nimmt der Rechner eine Tastenfolge auf; die nächste gedrückte Funktionstaste übernimmt sie, und Claude speichert sie mit dem Skill `taschenrechner` in `@Data/app-taschenrechner/funktionstasten.yaml`.

```bash
aios --fetch app-taschenrechner
```

Öffnen mit `/taschenrechner-gui` oder über die Kachel *Apps* von `/aios-gui`. Mitgelieferte Funktionstasten liegen in `knowledge/@!Funktionstasten/`; Beiträge kommen als Pull Request (`aios --contribute`) und nach Prüfung dorthin.
