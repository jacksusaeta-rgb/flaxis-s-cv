# Flaxis S CV

Rede social com feed, stories, chats 1:1, grupos, perfil e mensagens de voz.
Agora com design profissional (sem emojis), fundo animado futurista, retenção
local das mensagens, e uma casca nativa Android que embrulha a mesma app.

## Estrutura

```
index.html, view.html, sw.js, manifest.json   → a app web (fonte de verdade)
supabase-schema.sql                            → schema completo do Supabase
android/                                       → projeto Android nativo (WebView)
.github/workflows/build-apk.yml                → compila o APK na nuvem (GitHub Actions)
```

`android/app/src/main/assets/` contém uma cópia de `index.html`, `view.html`,
`sw.js` e `manifest.json`. Sempre que editares a app web, copia os ficheiros
atualizados para essa pasta antes de gerar um novo APK.

## Setup do Supabase (igual a antes)

1. Cria um novo projeto Supabase.
2. Cola `supabase-schema.sql` no SQL Editor → Run.
3. Substitui `SUPABASE_URL` e `SUPABASE_ANON_KEY` no topo do `<script>` de
   `index.html` (e depois volta a copiar para `android/app/src/main/assets/index.html`).

## Design

- **Sem emojis** — todos os ícones (feed, stories, chats, grupos, perfil,
  anexar, gravar áudio, enviar, gostar, comentar, descarregar, fechar) são
  SVG de traço fino, próprios da app.
- **Paleta profissional** — fundo grafite quase preto (`#0A0E13`), cartões
  translúcidos com desfoque (`backdrop-filter`), acento âmbar (`#C9A24B`) e
  azul (`#4B7BD1`) em vez do verde genérico de apps de chat.
- **Fundo animado futurista** — um `<canvas>` fixo desenha uma rede de nós
  ligados por linhas finas, com pulsos periódicos a percorrer ligações
  aleatórias (como sinal a atravessar um circuito). Corre a ~30fps, pausa
  quando o ecrã está em segundo plano, e desliga-se automaticamente se o
  sistema tiver "reduzir movimento" ativo. O cabeçalho, a barra inferior e
  os cartões usam transparência + desfoque para deixar a animação visível
  por trás do conteúdo sem prejudicar a leitura.

## Mensagens: o telemóvel é o arquivo, o Supabase é só o correio

Como pediste, texto, imagens, vídeos e agora também **áudios** (nova
gravação de voz, com botão de microfone) deixam de viver permanentemente no
Supabase. O fluxo:

1. Ao enviares, a mensagem — incluindo o ficheiro — fica logo guardada no
   **IndexedDB** deste aparelho (`idb.saveMessage` + `idb.saveBlob`).
2. Quando alguém recebe, o dispositivo dela faz o download do ficheiro,
   guarda tudo localmente e só depois confirma `delivered` na tabela
   `message_status`.
3. Assim que **todos** os membros da conversa confirmaram entrega, o
   dispositivo do remetente apaga a linha em `messages` e o ficheiro em
   `chat-media` do Supabase — automaticamente, em segundo plano.
4. Ao abrir uma conversa, a app mostra primeiro o histórico local (instantâneo,
   funciona offline) e só depois verifica se ainda há algo por entregar no
   servidor.

**Compromisso a ter em conta:** se alguém desinstalar a app ou trocar de
aparelho antes de reinstalar/restaurar, perde as mensagens que já tinham
sido limpas do Supabase — exatamente como aconteceria com histórico só local
em qualquer app deste tipo. Publicações do feed e stories **não** entram
nesta lógica (continuam no Supabase normalmente, porque precisam de ficar
visíveis para toda a gente).

## App nativa Android

`android/` é um projeto Android padrão (Gradle) com uma única `MainActivity`
que carrega a app dentro de um `WebView` a partir de `file:///android_asset/`.
O que a versão nativa acrescenta em relação à PWA:

- Seletor de ficheiros nativo para escolher fotos/vídeos (`onShowFileChooser`)
- Permissão de microfone concedida automaticamente ao WebView para as
  mensagens de voz (`onPermissionRequest`)
- Ícone de app e tema escuro/âmbar, sem barra do sistema
- Botão físico/gesto de "voltar" fecha ecrãs abertos antes de sair da app

### Como gerar o APK (recomendado: GitHub Actions)

O teu telemóvel/PC não precisam de Android SDK instalado. Basta enviar a
pasta `android/` para o teu repositório GitHub:

1. `git add android .github` → `git commit -m "app nativa"` → `git push`
2. No GitHub, vai a **Actions** → o workflow "Build APK" corre sozinho
3. Quando terminar, abre a execução → em **Artifacts** descarrega
   `flaxis-debug-apk` → é o teu `app-debug.apk`, pronto a instalar

Isto evita compilar localmente num Celeron N3050 com 4GB de RAM, que sofreria
bastante com o Android SDK + Gradle.

### Build local via Termux (alternativa, mais pesada)

Se preferires mesmo compilar no telemóvel:

```bash
pkg install openjdk-17 gradle
cd android
gradle assembleDebug
```

Vai precisar de descarregar o Android SDK (`cmdline-tools`, `platform-tools`,
`build-tools;34.0.0`, `platforms;android-34`) e apontar `ANDROID_HOME` para lá.
Espera vários GB de download e um build lento nesse hardware — a via do
GitHub Actions é bem mais prática no teu caso.

## O que já funciona

- Auth (Supabase Auth)
- Feed com posts, like, comentários
- Stories 24h com anel visto/não visto
- Chats 1:1 e grupos em tempo real, com retenção local + limpeza automática na nuvem
- Mensagens de voz (gravação com `MediaRecorder`, botão de microfone)
- Visualizador de mídia leve (`view.html`, para posts/stories) e visualizador
  em ecrã cheio embutido para mídia de chat (que pode já não existir no
  Supabase, só no dispositivo)
- Perfil editável com foto
- Fundo animado futurista em todo o app
- Casca nativa Android com build automático via GitHub Actions

## Próximos passos sugeridos

- Ícone/splash em PNG de alta resolução (hoje é um vetor simples "F")
- Notificações push nativas (Firebase Cloud Messaging) para quando a app
  está fechada — o WebView por si só não recebe realtime em segundo plano
- Indicador de "a gravar…" com forma de onda em vez de só texto
- Reenviar automaticamente o `ackDelivered` quando a rede voltar (hoje falha
  silenciosamente e só é retomado na próxima abertura da conversa)
