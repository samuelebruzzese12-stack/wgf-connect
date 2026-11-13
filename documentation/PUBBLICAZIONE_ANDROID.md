# Build e pubblicazione Android

## 1. Generare la parte Android (una volta)
```bash
cd mobile
flutter create --platforms=android --org it.wgfconnect --project-name wgf_connect .
flutter pub get
dart run flutter_launcher_icons        # icone dal logo originale
```

In `android/app/src/main/AndroidManifest.xml` aggiungi, sopra `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
e nel tag `<application>` imposta `android:label="WGF CONNECT"`.

Per aprire numeri di telefono e link (sezione "Non sei solo") aggiungi dentro `<manifest>`:
```xml
<queries>
  <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
</queries>
```

## 2. APK di prova
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<progetto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```
Il file è in `build/app/outputs/flutter-apk/app-release.apk`: si installa su un telefono Android (consenti "origini sconosciute").

## 3. Firma per il Play Store
```bash
keytool -genkey -v -keystore ~/wgf-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Crea `android/key.properties` (già escluso da Git):
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/percorso/wgf-upload.jks
```
e collega la firma in `android/app/build.gradle` (guida ufficiale: docs.flutter.dev/deployment/android). Poi:
```bash
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## 4. Google Play Console
- Account sviluppatore Google: richiede una quota di registrazione una tantum (unico costo non gratuito del percorso; in alternativa si può distribuire l'APK direttamente).
- Scheda dell'app: specifica che è un'app **indipendente, non ufficiale**, senza loghi dei WGF.
- Classificazione dei contenuti e **pubblico destinatario: 18+**.
- Sezione "Sicurezza dei dati": dichiara i dati elencati nell'informativa privacy.
- Le app con funzioni di incontri hanno requisiti specifici nelle norme di Google Play: verificali prima di attivare il dating.

## 5. Pannello amministrativo (gratis su Cloudflare Pages)
Pubblica la cartella `admin/` come sito statico (Cloudflare Pages → "Upload assets" oppure collega il repository con output directory `admin`). Proteggilo anche con **Cloudflare Access** (gratuito fino a 50 utenti) per limitare chi può aprire la pagina. I permessi veri restano comunque controllati dal database.
