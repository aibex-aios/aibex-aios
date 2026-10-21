# app-taschenrechner

Demo-App von AIbex AIOS: programmierbarer Taschenrechner mit umgekehrter polnischer Notation nach dem Vorbild des HP-15C (Stack X, Y, Z, T): Ziffern, Punkt, Grundrechenarten, `CHS`, `ENTER`, vier Kacheln A bis D und die Taste *Lernen*. Ein Quadrat ist `ENTER ×`. Mit *LEARN* nimmt der Rechner eine Tastenfolge auf; die nächste gedrückte Kachel übernimmt sie, und Claude speichert sie mit dem Skill `taschenrechner` in `@Data/app-taschenrechner/kacheln.yaml`.

```bash
aios --fetch app-taschenrechner
```

Öffnen mit `/taschenrechner-gui` oder über die Kachel *Apps* von `/aios-gui`. Mitgelieferte Kacheln liegen in `knowledge/@!Kacheln/`; Beiträge kommen als Pull Request (`aios --contribute`) und nach Prüfung dorthin.
