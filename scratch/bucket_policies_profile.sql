-- Criar bucket público para avatares
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Permitir leitura pública de qualquer avatar
CREATE POLICY "Qualquer pessoa pode ver avatares"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Permitir que usuário autenticado faça upload do próprio avatar
CREATE POLICY "Usuários podem enviar seus avatares"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND (LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp'))
);

-- Permitir que dono atualize ou delete seu avatar
CREATE POLICY "Usuários gerenciam seus avatares"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND (LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp'))
);