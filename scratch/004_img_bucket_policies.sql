-- 1. Criar bucket público para imagens dos pets
INSERT INTO storage.buckets (id, name, public)
VALUES ('pet_images', 'pet_images', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Política: usuários autenticados podem fazer upload
CREATE POLICY "Usuários autenticados podem enviar imagens de pets"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'pet_images' AND (LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')));

-- 3. Política: qualquer pessoa pode visualizar as imagens (leitura pública)
CREATE POLICY "Qualquer pessoa pode ver imagens de pets"
ON storage.objects
FOR SELECT
USING (bucket_id = 'pet_images');

-- 4. Política: dono pode deletar ou atualizar (opcional, mas útil)
CREATE POLICY "Usuários podem gerenciar suas próprias imagens"
ON storage.objects
FOR ALL
TO authenticated
USING (bucket_id = 'pet_images' AND auth.uid()::text = (storage.foldername(name))[1])
WITH CHECK (bucket_id = 'pet_images' AND auth.uid()::text = (storage.foldername(name))[1]);