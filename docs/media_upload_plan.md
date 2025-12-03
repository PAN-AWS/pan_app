# Piano per upload di media in chat e cambio immagine profilo

## Stato attuale dell'app
- **Chat 1:1**: i messaggi sono solo testo. Ogni invio crea un documento in `chats/{chatId}/messages` con i campi `senderId`, `text`, `createdAt` e aggiorna il documento chat con `lastMessage`, `lastSenderId`, `updatedAt`. Non esiste supporto per immagini o video e il rendering in UI mostra solo il testo della bolla. 【F:lib/features/chat/chat_room_page.dart†L32-L152】
- **Chat di gruppo**: stessa struttura testuale. I messaggi sono salvati come testo e la lista mostra solo il contenuto testuale. 【F:lib/features/chat/group_chat_page.dart†L20-L115】
- **Immagine profilo**: già presente un flusso completo che sceglie un'immagine dalla galleria (`image_picker`), la carica su Storage in `public_profiles/{uid}/avatar.jpg`, recupera la download URL e aggiorna sia `users/{uid}` che `public_profiles/{uid}` oltre a `photoURL` su Firebase Auth. 【F:lib/features/profile/profile_page.dart†L15-L197】
- **Regole Storage correnti**: consentono lettura pubblica e scrittura proprietaria per gli avatar sotto `public_profiles/{userId}/...` e regole private simili per `users/{userId}/profile/**`. Non esistono percorsi per allegati chat. 【F:firebase_storage.rules†L1-L21】

## Modifiche client consigliate per media in chat
1. **Nuovo schema messaggi**
   - Aggiungere i campi `type` (`text`, `image`, `video`), `storagePath`, `mediaUrl`, `contentType`, `size`, `width`, `height`, `durationMs` (per video) e `text` opzionale per la caption.
   - Salvare `lastMessage` come un riassunto (“📷 Foto”, “🎬 Video” o testo) e `lastMessageType` per le liste chat/gruppi.

2. **UI/UX input**
   - Nel footer di `ChatRoomPage` e `GroupChatPage`, affiancare all'icona di invio un pulsante di allegato che apra picker per immagini (galleria/fotocamera) e video. Su web usare `kIsWeb` per limitarsi alla selezione file.
   - Mostrare stato di upload (progress bar o spinner nel bottone) e prevenire invii duplicati finché l'upload non termina.

3. **Pipeline invio media**
   - Dopo aver scelto il file, caricarlo su Storage sotto `chat_uploads/{chatId}/{messageId}.{ext}` (o `group_uploads/{groupId}/...`) con `SettableMetadata(contentType: ...)`.
   - Ottenere la `mediaUrl` via `getDownloadURL()` e creare il documento messaggio con i metadati sopra e `createdAt` server-side dentro una transazione che aggiorna anche il documento chat/gruppo.
   - Per immagini grandi creare thumbnail client-side opzionale (per web/mobile) e salvarla accanto al file per un rendering più rapido.

4. **Rendering messaggi**
   - In elenco messaggi distinguere i tipi: immagini con `Image.network` e `GestureDetector` per full-screen, video con thumbnail/play overlay e un player (es. `video_player` + `chewie` o `video_player_web`).
   - Gestire fallback di testo per link non caricabili e mostrare pulsante download per video pesanti.

5. **Gestione errori e cleanup**
   - Se l'upload fallisce, cancellare eventuali file parziali su Storage e non scrivere il messaggio.
   - Aggiungere un campo `storagePath` per poter eliminare media correlati quando un messaggio viene rimosso.

## Rafforzamenti per l'immagine profilo
- Il flusso esistente rimane valido; per coerenza spostare eventuali upload futuri sotto `users/{uid}/profile/avatar.jpg` e copiare in `public_profiles` se serve la versione pubblica.
- Considerare compressione e ridimensionamento lato client prima dell'upload per ridurre costi di banda.

## Regole Firebase proposte
### Firestore (`firestore.rules`)
```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isOwner(userId) { return isSignedIn() && request.auth.uid == userId; }
    function isChatMember(chatId) {
      return isSignedIn() &&
             get(/databases/$(database)/documents/chats/$(chatId)).data.members.hasAny([request.auth.uid]);
    }
    function isGroupMember(groupId) {
      return isSignedIn() &&
             get(/databases/$(database)/documents/groups/$(groupId)).data.members.hasAny([request.auth.uid]);
    }

    // Profili
    match /public_profiles/{userId} { allow read: if true; allow write: if isOwner(userId); }
    match /users/{userId} { allow read, write: if isOwner(userId); }

    // Chat 1:1
    match /chats/{chatId} {
      allow read, update, delete: if isChatMember(chatId);
      allow create: if isSignedIn(); // creatore inserisce se stesso in members
      match /messages/{messageId} {
        allow read: if isChatMember(chatId);
        allow create: if isChatMember(chatId)
          && request.resource.data.senderId == request.auth.uid
          && request.resource.data.createdAt == request.time
          && (request.resource.data.type in ['text','image','video']);
        allow delete: if false; // opzionale: abilita solo admin/moderatore
      }
    }

    // Gruppi
    match /groups/{groupId} {
      allow read, update: if isGroupMember(groupId);
      allow create: if isSignedIn();
      match /messages/{messageId} {
        allow read: if isGroupMember(groupId);
        allow create: if isGroupMember(groupId)
          && request.resource.data.senderId == request.auth.uid
          && request.resource.data.createdAt == request.time
          && (request.resource.data.type in ['text','image','video']);
      }
    }
  }
}
```

### Storage (`firebase_storage.rules`)
```rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }
    function isOwner(userId) { return isSignedIn() && request.auth.uid == userId; }
    function isChatMember(chatId) {
      return isSignedIn() &&
             get(/databases/(default)/documents/chats/$(chatId)).data.members.hasAny([request.auth.uid]);
    }
    function isGroupMember(groupId) {
      return isSignedIn() &&
             get(/databases/(default)/documents/groups/$(groupId)).data.members.hasAny([request.auth.uid]);
    }

    // Avatar pubblici
    match /public_profiles/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if isOwner(userId);
    }

    // Chat private
    match /chat_uploads/{chatId}/{allPaths=**} {
      allow read, write: if isChatMember(chatId);
    }

    // Chat di gruppo
    match /group_uploads/{groupId}/{allPaths=**} {
      allow read, write: if isGroupMember(groupId);
    }

    // Altri file profilo privati
    match /users/{userId}/profile/{allPaths=**} {
      allow read, write: if isOwner(userId);
    }

    // Blocca tutto il resto
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```
- Le regole Storage usano `get` su Firestore per verificare l'appartenenza a chat/gruppi; assicurarsi che le collezioni contengano il campo `members` coerente con il client.
- In Firestore, l'accesso in lettura/scrittura ai messaggi è vincolato ai membri per evitare che URL pubblici degli allegati possano essere enumerati.
