-- ============================================================
-- FLAXIS S CV — Schema Supabase
-- Cola isto no SQL Editor do teu projeto Supabase (novo projeto)
-- ============================================================

-- Extensão para uuid
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- PERFIS
-- ------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  avatar_url text,           -- URL pública no Storage (não base64)
  avatar_thumb_url text,     -- versão pequena (~64px) usada nas listas
  bio text,
  status_msg text default 'Olá! Estou no Flaxis.',
  is_online boolean default false,
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- POSTS (feed)
-- ------------------------------------------------------------
create table posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  caption text,
  media_url text,          -- imagem/vídeo em tamanho real (Storage)
  media_thumb_url text,    -- thumbnail pequena p/ carregar rápido no feed
  media_type text check (media_type in ('image','video',null)),
  likes_count int default 0,
  comments_count int default 0,
  created_at timestamptz default now()
);

create table post_likes (
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

create table post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- STORIES (expiram em 24h)
-- ------------------------------------------------------------
create table stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  media_url text not null,
  media_thumb_url text,
  media_type text check (media_type in ('image','video')),
  caption text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '24 hours')
);

create table story_views (
  story_id uuid references stories(id) on delete cascade,
  viewer_id uuid references profiles(id) on delete cascade,
  viewed_at timestamptz default now(),
  primary key (story_id, viewer_id)
);

-- ------------------------------------------------------------
-- CHATS (1:1 e grupos)
-- ------------------------------------------------------------
create table chats (
  id uuid primary key default gen_random_uuid(),
  is_group boolean default false,
  name text,               -- só usado em grupos
  avatar_url text,         -- só usado em grupos
  created_by uuid references profiles(id),
  last_message_preview text,
  last_message_at timestamptz default now(),
  created_at timestamptz default now()
);

create table chat_members (
  chat_id uuid references chats(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  role text default 'member' check (role in ('admin','member')),
  joined_at timestamptz default now(),
  last_read_at timestamptz default now(),
  primary key (chat_id, user_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid references chats(id) on delete cascade,
  sender_id uuid references profiles(id) on delete cascade,
  content text,
  media_url text,
  media_thumb_url text,
  media_type text check (media_type in ('image','video','audio',null)),
  reply_to uuid references messages(id),
  created_at timestamptz default now(),
  edited_at timestamptz
);

create table message_status (
  message_id uuid references messages(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  status text default 'sent' check (status in ('sent','delivered','read')),
  updated_at timestamptz default now(),
  primary key (message_id, user_id)
);

-- ------------------------------------------------------------
-- ÍNDICES (consultas rápidas + paginação barata)
-- ------------------------------------------------------------
create index idx_posts_created on posts(created_at desc);
create index idx_stories_expires on stories(expires_at);
create index idx_messages_chat_time on messages(chat_id, created_at desc);
create index idx_chatmembers_user on chat_members(user_id);

-- ------------------------------------------------------------
-- RLS (Row Level Security)
-- ------------------------------------------------------------
alter table profiles enable row level security;
alter table posts enable row level security;
alter table post_likes enable row level security;
alter table post_comments enable row level security;
alter table stories enable row level security;
alter table story_views enable row level security;
alter table chats enable row level security;
alter table chat_members enable row level security;
alter table messages enable row level security;
alter table message_status enable row level security;

-- Perfis: qualquer autenticado pode ver, só o dono edita
create policy "perfis visiveis" on profiles for select using (true);
create policy "perfil editavel pelo dono" on profiles for update using (auth.uid() = id);
create policy "perfil criado no signup" on profiles for insert with check (auth.uid() = id);

-- Posts: qualquer autenticado vê e cria os seus
create policy "posts visiveis" on posts for select using (true);
create policy "posts criados pelo dono" on posts for insert with check (auth.uid() = user_id);
create policy "posts apagados pelo dono" on posts for delete using (auth.uid() = user_id);

create policy "likes visiveis" on post_likes for select using (true);
create policy "likes geridos pelo dono" on post_likes for all using (auth.uid() = user_id);

create policy "comentarios visiveis" on post_comments for select using (true);
create policy "comentarios criados pelo dono" on post_comments for insert with check (auth.uid() = user_id);

-- Stories: visíveis enquanto não expiram
create policy "stories visiveis" on stories for select using (expires_at > now());
create policy "stories criadas pelo dono" on stories for insert with check (auth.uid() = user_id);
create policy "story views" on story_views for all using (auth.uid() = viewer_id);

-- Chats: só membros veem
create policy "chats visiveis a membros" on chats for select using (
  exists (select 1 from chat_members where chat_id = chats.id and user_id = auth.uid())
);
create policy "chats criados por autenticados" on chats for insert with check (auth.uid() = created_by);

create policy "membros visiveis a membros" on chat_members for select using (
  exists (select 1 from chat_members cm where cm.chat_id = chat_members.chat_id and cm.user_id = auth.uid())
);
create policy "entrar em chat" on chat_members for insert with check (true);
create policy "sair de chat" on chat_members for delete using (auth.uid() = user_id);

create policy "mensagens visiveis a membros" on messages for select using (
  exists (select 1 from chat_members where chat_id = messages.chat_id and user_id = auth.uid())
);
create policy "enviar mensagem" on messages for insert with check (
  auth.uid() = sender_id and
  exists (select 1 from chat_members where chat_id = messages.chat_id and user_id = auth.uid())
);

create policy "status visivel a membros" on message_status for select using (
  exists (select 1 from chat_members cm join messages m on m.chat_id = cm.chat_id
          where m.id = message_status.message_id and cm.user_id = auth.uid())
);
create policy "status atualizado pelo proprio" on message_status for all using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- STORAGE BUCKETS (cria no painel Storage, ou via SQL abaixo)
-- Todos "public" para leitura = URLs diretas, sem gastar egress
-- servindo pela API; upload só por autenticados.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public) values
  ('avatars', 'avatars', true),
  ('posts', 'posts', true),
  ('stories', 'stories', true),
  ('chat-media', 'chat-media', true)
on conflict (id) do nothing;

create policy "leitura publica avatars" on storage.objects for select using (bucket_id = 'avatars');
create policy "upload avatars autenticado" on storage.objects for insert with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

create policy "leitura publica posts" on storage.objects for select using (bucket_id = 'posts');
create policy "upload posts autenticado" on storage.objects for insert with check (bucket_id = 'posts' and auth.role() = 'authenticated');

create policy "leitura publica stories" on storage.objects for select using (bucket_id = 'stories');
create policy "upload stories autenticado" on storage.objects for insert with check (bucket_id = 'stories' and auth.role() = 'authenticated');

create policy "leitura publica chat-media" on storage.objects for select using (bucket_id = 'chat-media');
create policy "upload chat-media autenticado" on storage.objects for insert with check (bucket_id = 'chat-media' and auth.role() = 'authenticated');

-- ------------------------------------------------------------
-- Job simples para apagar stories expiradas (podes correr via cron/edge function)
-- ------------------------------------------------------------
-- delete from stories where expires_at < now();
