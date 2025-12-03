# Analisi per foto/video in chat e immagine profilo

## Stato attuale
- **Chat uno-a-uno**: `ChatRoomPage` salva solo testo nella sottocollezione `chats/{chatId}/messages` con campi `senderId`, `text`, `createdAt` e aggiorna `lastMessage` sul documento chat. Nessun supporto a media o upload su Storage. 【F:lib/features/chat/chat_room_page.dart†L32-L152】
- **Chat di gruppo**: `GroupChatPage` gestisce solo messaggi testuali con la stessa struttura di campi e aggiorna `lastMessage`. 【F:lib/features/chat/group_chat_page.dart†L15-L74】
- **Creazione chat/gruppi**: i documenti `chats/{chatId}` e `groups/{groupId}` includono l'array `members`, utile per le regole di accesso. 【F:lib/features/chat/chat_page.dart†L213-L246】【F:lib/features/chat/chat_page.dart†L495-L505】
- **Immagine profilo**: già supportata tramite `ProfilePage`, che usa `image_picker`, carica su `public_profiles/{uid}/avatar.jpg`, aggiorna Auth e Firestore. 【F:lib/features/profile/profile_page.dart†L23-L199】
- **Regole Storage**: consentono solo avatar pubblici e profili privati; mancano permessi per allegati chat/gruppi. 【F:firebase_storage.rules†L1-L21】

## Modifiche applicative necessarie
1. **UI chat (DM e gruppi)**
   - Aggiungere pulsante di allegato vicino al campo testo per aprire selezione immagini/video (ad es. `image_picker` per mobile, `file_picker` per web/desktop con filtri MIME immagine/video).
   - Gestire preview (thumbnail per immagini, icona/mini player per video) nelle bubble e placeholder durante upload.
   - Permettere invio di soli allegati (messaggio senza testo) e combinazione testo+media.

2. **Gestione dati messaggio**
   - In `ChatRoomPage` e `GroupChatPage`, estendere il payload del messaggio con campi come `type` (`text`/`image`/`video`), `mediaUrl`, `storagePath`, `mediaWidth`/`mediaHeight`, `durationMs` (per video) e `text` opzionale.
   - Aggiornare il rendering per distinguere testo e media (es. `Image.network` con `ClipRRect`, player video leggero o link apribile se non si vuole integrare un player completo).
   - Dopo l’upload a Storage, scrivere il messaggio in Firestore dentro una transazione come ora per mantenere `lastMessage` coerente (es. usare descrizione “📷 Foto”/“🎞️ Video” per `lastMessage`).

3. **Upload Storage**
   - Percorsi proposti:
     - DM: `chat_media/{chatId}/{messageId}/{filename}`
     - Gruppi: `group_media/{groupId}/{messageId}/{filename}`
   - Impostare `contentType` corretto (`image/*`, `video/*`) e, se possibile, limitare dimensione prima dell’upload (compressione immagini, limite video).
   - Salvare `storagePath` nel documento messaggio per facilitare cleanup.

4. **Permessi runtime**
   - **Android**: aggiungere `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` (o `READ_EXTERNAL_STORAGE` su API <33) e, se serve fotocamera, `CAMERA` in `android/app/src/main/AndroidManifest.xml`.
   - **iOS**: aggiungere `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription` e, per video, `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`.
   - **Web**: per `file_picker` non servono permessi, ma va aggiornata la whitelist MIME in `web/index.html` solo se si usano `<input accept>` personalizzati.

5. **Pulizia e gestione errori**
   - Gestire retry/cancel upload e mostrare stato (progress spinner) nelle bubble.
   - Quando una chat viene eliminata, rimuovere anche i file Storage usando `storagePath` salvato.

## Regole Firebase proposte
### Firestore (`firestore.rules`)
- Consente accesso a profili pubblici e scrittura solo da proprietario.
- Consente lettura/scrittura su `users/{uid}` solo all’utente.
- Per DM, l’accesso a documento chat e messaggi è riservato ai membri indicati in `members`.
- Per gruppi, lettura a membri e join tramite `arrayUnion` controllando che l’utente sia autenticato; i messaggi richiedono appartenenza al gruppo.

### Storage (`firebase_storage.rules`)
- Mantiene le regole esistenti per avatar.
- Aggiunge cartelle `chat_media/{chatId}/...` e `group_media/{groupId}/...` accessibili solo agli utenti autenticati membri della chat/gruppo, con limite dimensione (es. 20 MB) e controllo del MIME (`image/*`, `video/*`).

## Passi consigliati per l’implementazione
1. Integrare `file_picker`/`image_picker` dove mancano e aggiornare `pubspec.yaml` se necessario.
2. Estendere i widget di input in `ChatRoomPage` e `GroupChatPage` con pulsante allegati, flusso di upload e nuovi tipi di messaggio.
3. Aggiornare la visualizzazione lista messaggi per gestire media, fallback e progress.
4. Adattare la logica di cancellazione chat/gruppo per rimuovere file Storage associati.
5. Aggiornare manifest/Info.plist per i permessi e testare su web/mobile.
6. Deploy delle nuove regole Firestore e Storage proposte.
