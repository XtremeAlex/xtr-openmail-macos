<a name="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Issues][issues-shield]][issues-url]
[![License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

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
│  └─ MsgExporter.swift        export TXT / cartella
└─ XtrOpenMail/                app SwiftUI
   ├─ XtrOpenMailApp.swift
   ├─ ContentView.swift
   └─ MessageViewModel.swift
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

Distribuito sotto licenza Apache 2.0. Vedi [`LICENSE`](LICENSE).

## Contatti

Andrei Alexandru Dabija — [LinkedIn](https://www.linkedin.com/in/andrei-alexandru-dabija/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/XtremeAlex/xtr-openmail-macos.svg?style=for-the-badge
[contributors-url]: https://github.com/XtremeAlex/xtr-openmail-macos/graphs/contributors
[issues-shield]: https://img.shields.io/github/issues/XtremeAlex/xtr-openmail-macos.svg?style=for-the-badge
[issues-url]: https://github.com/XtremeAlex/xtr-openmail-macos/issues
[license-shield]: https://img.shields.io/github/license/XtremeAlex/xtr-openmail-macos.svg?style=for-the-badge
[license-url]: https://github.com/XtremeAlex/xtr-openmail-macos/blob/main/LICENSE
[linkedin-shield]: https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white
[linkedin-url]: https://www.linkedin.com/in/andrei-alexandru-dabija/
