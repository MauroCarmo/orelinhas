-- 003_pet_lost_enhancements.sql
-- Adiciona campos de localização geográfica, status e ajusta descrição

-- 1. Coordenadas
ALTER TABLE pet_lost_alerts 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 2. Status (ativo/resolvido)
ALTER TABLE pet_lost_alerts 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved'));

-- 3. Ajusta descrição para 255 caracteres (conforme requisito)
--    (use o comando correspondente à situação dos seus dados)
--    Se não houver dados que excedam 255, use:
ALTER TABLE pet_lost_alerts 
ALTER COLUMN description TYPE VARCHAR(255);
--    Caso já existam registros com textos maiores, descomente a linha abaixo e comente a acima:
-- ALTER TABLE pet_lost_alerts ALTER COLUMN description TYPE VARCHAR(255) USING (SUBSTRING(description, 1, 255));