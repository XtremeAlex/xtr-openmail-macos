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
- Export in PDF A4 (⇧⌘P): header, corpo testo ed elenco allegati, titolo del documento =
  oggetto; generato con CoreText, senza interpretare HTML ne' caricare risorse remote
  (niente pixel di tracciamento), pagine numerate, limite di 500 pagine
- Export in cartella dedicata (mail.txt + tutti gli allegati)
- Tema "2AD" condiviso con xtr-aeroport-edifact-spring-web: scuro/chiaro/sistema
  (pulsante tondo nella barra, menu **Aspetto** o Impostazioni ⌘,), accento rosso, sopratitoli
  mono, pulsanti 40pt con anello di focus, campi con alone accento e pulsante "lampada"
  durante l'esportazione (stessa curva 1,4 s dei keyframes `lamp` del web; nessuna animazione
  con "Riduci movimento")

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
- **Nessuna rete**: nessuna connessione in uscita, nessuna telemetria. Il bundle `.app` e'
  in sandbox senza entitlement di rete (`packaging/openmail.entitlements`).
- **Politica via MDM** (profilo di configurazione sul dominio `com.xtremealex.openmail`,
  esempio in `packaging/com.xtremealex.openmail.mobileconfig.example`):

  | Chiave | Tipo | Effetto |
  |---|---|---|
  | `MaxFileSizeMB` | intero 1…1024 (default 256) | file piu' grandi rifiutati prima della lettura |
  | `DisableAttachmentExport` | bool | nessun salvataggio di allegati su disco (DLP) |
  | `DisableFolderExport` | bool | niente export in cartella |
  | `theme` | `system` / `light` / `dark` | tema imposto, i selettori si disattivano |

  Valori non validi ricadono sui default; la politica in vigore e' visibile in Impostazioni (⌘,).
- **Integrazione Finder**: il bundle dichiara il tipo `.msg` (`CFBundleDocumentTypes`), quindi
  doppio clic e "Apri con" aprono il messaggio.

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
│  ├─ MsgPolicy.swift          politica aziendale (MDM), testata
│  └─ FileNameSanitizer.swift  nomi file sicuri e univoci
└─ XtrOpenMail/                app SwiftUI
   ├─ XtrOpenMailApp.swift     scene, menu Aspetto, Impostazioni
   ├─ ContentView.swift
   ├─ MessageViewModel.swift   parsing asincrono, log
   └─ Theme/                   token e componenti del tema 2AD
Tests/
└─ MsgKitTests/                test del parser e della politica
packaging/                     Info.plist, entitlements, profilo MDM di esempio
scripts/                       build-app.sh, check-theme-sync.sh
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

### Bundle .app, firma e notarizzazione

```bash
scripts/build-app.sh            # test + release + build/openmail.app (sandbox, hardened runtime) + zip
scripts/check-theme-sync.sh     # token del tema = app.css della web app, copie identiche fra i progetti
```

La firma di default e' ad-hoc (uso locale). Per distribuire in azienda:

```bash
SIGN_IDENTITY="Developer ID Application: Nome (TEAMID)" scripts/build-app.sh
xcrun notarytool submit build/openmail.zip --keychain-profile PROFILO --wait
xcrun stapler staple build/openmail.app
```

La CI (`.github/workflows/ci.yml`) esegue build e test su ogni push.

## Roadmap

- [x] Parser CFB/MAPI dei file .msg
- [x] Visualizzazione header + corpo + allegati
- [x] Export TXT e cartella
- [ ] Rendering del corpo HTML (`bodyHtml`)
- [x] Export in PDF (come la versione Java)
- [ ] Anteprima inline degli allegati immagine

## License

Distribuito con doppia licenza: **GNU AGPL-3.0** (vedi [`LICENSE`](LICENSE)) per uso open source, e **licenza commerciale** per uso in prodotti proprietari (vedi [`COMMERCIAL-LICENSE.md`](COMMERCIAL-LICENSE.md)).

## Contatti

Andrei Alexandru Dabija — [LinkedIn](https://www.linkedin.com/in/andrei-alexandru-dabija/) — [github.com/XtremeAlex](https://github.com/XtremeAlex)

<p align="right">(<a href="#readme-top">back to top</a>)</p>
