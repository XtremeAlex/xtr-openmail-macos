<a name="readme-top"></a>

<div align="center">
  <h3 align="center">xtr-openmail-macos</h3>
  <p align="center">
    Visualizzatore nativo macOS per file <code>.msg</code> di Outlook: apre il messaggio, mostra intestazioni e corpo, estrae gli allegati ed esporta in TXT.
    <br />
    <a href="https://github.com/XtremeAlex/xtr-openmail-macos/issues">Segnala un bug</a>
    &middot;
    <a href="https://github.com/XtremeAlex/xtr-openmail-macos/issues">Richiedi una feature</a>
  </p>
</div>

<details>
  <summary>Indice</summary>
  <ol>
    <li><a href="#info-sul-progetto">Info sul progetto</a></li>
    <li><a href="#stack-tecnologico">Stack tecnologico</a></li>
    <li><a href="#architettura">Architettura</a></li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contatti">Contatti</a></li>
  </ol>
</details>

## Info sul progetto

`xtr-openmail-macos` e la controparte nativa macOS del progetto Java `xtr-openmail`.
Apre i file `.msg` di Outlook (formato Compound File Binary / MAPI), ne estrae
oggetto, mittente, destinatari, corpo e allegati, e permette di esportarli.

L'app **non si connette a nessun server di posta** e non richiede credenziali:
lavora solo su file `.msg` gia presenti sul disco. Nessun dato lascia il tuo Mac.

### Funzioni

- Apertura di file `.msg` (pulsante o drag &amp; drop)
- Visualizzazione di oggetto, mittente, destinatari (To/CC) e corpo
- Elenco ed estrazione degli allegati
- Export del messaggio in TXT
- Export in cartella dedicata (mail.txt + tutti gli allegati)
- Tema "2AD" condiviso con xtr-aeroport-edifact-spring-web: scuro/chiaro/sistema
  (menu **Aspetto** o Impostazioni ⌘,), accento rosso, etichette mono, pulsante "lampada"
  durante l'esportazione

### Uso aziendale

- **Export sicuro**: i nomi degli allegati sono controllati dal mittente; vengono ripuliti
  (niente `../`, percorsi Windows, file nascosti, caratteri di controllo, >255 byte), i file
  esistenti non sono mai sovrascritti (`nome (2).ext`) e le scritture sono atomiche.
- **Robustezza**: header CFB con dimensioni di settore non standard rifiutati, dimensioni
  degli stream limitate a quella del file, limite di 256 MB per file, parsing fuori dal main
  thread.
- **Diagnostica**: log unificato di sistema, sottosistema `com.xtremealex.openmail`
  (`log stream --predicate 'subsystem == "com.xtremealex.openmail"'`); nomi file e percorsi
  sono marcati privati.
- **Nessuna rete**: nessuna connessione in uscita, nessuna telemetria.

## Stack tecnologico

- Swift 5.9, SwiftUI (macOS 13+)
- Swift Package Manager
- Parser `.msg` scritto da zero (nessuna dipendenza esterna) nel modulo `MsgKit`

## Architettura

```
Sources/
├─ MsgKit/                     libreria di parsing (no UI, testabile)
│  ├─ CompoundFileReader.swift lettore CFB/OLE2
│  ├─ Data+LittleEndian.swift  helper binari
│  ├─ MsgMessage.swift         modello + parser MAPI
│  ├─ MsgExporter.swift        export TXT / cartella (sicuro, atomico)
│  └─ FileNameSanitizer.swift  nomi file sicuri e univoci
└─ XtrOpenMail/                app SwiftUI
   ├─ XtrOpenMailApp.swift     scene, menu Aspetto, Impostazioni
   ├─ ContentView.swift
   ├─ MessageViewModel.swift   parsing asincrono, log
   └─ Theme/                   token e componenti del tema 2AD
Tests/
└─ MsgKitTests/                test del parser
```

## Getting Started

### Prerequisiti

- macOS 13 o superiore
- Xcode 15+ oppure la toolchain Swift da riga di comando

### Build e run

```bash
# build della libreria e dell'app
swift build

# esecuzione dei test del parser
swift test

# avvio dell'app da riga di comando
swift run xtr-openmail-macos
```

Per un'app con icona/bundle completo aprire il pacchetto in Xcode
(`File > Open` sulla cartella del progetto) ed eseguire lo schema `xtr-openmail-macos`.

## Roadmap

- [x] Parser CFB/MAPI dei file .msg
- [x] Visualizzazione header + corpo + allegati
- [x] Export TXT e cartella
- [ ] Rendering del corpo HTML (`bodyHtml`)
- [ ] Export in PDF (come la versione Java)
- [ ] Anteprima inline degli allegati immagine

## License

Distribuito con doppia licenza: **GNU AGPL-3.0** (vedi [`LICENSE`](LICENSE)) per uso open source, e **licenza commerciale** per uso in prodotti proprietari (vedi [`COMMERCIAL-LICENSE.md`](COMMERCIAL-LICENSE.md)).

## Contatti

Andrei Alexandru Dabija — [LinkedIn](https://www.linkedin.com/in/andrei-alexandru-dabija/) — [github.com/XtremeAlex](https://github.com/XtremeAlex)

<p align="right">(<a href="#readme-top">back to top</a>)</p>
