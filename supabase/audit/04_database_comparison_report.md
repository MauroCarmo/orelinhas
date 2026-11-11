# Relatório de Auditoria e Rastreabilidade do Banco de Dados (Orelhinhas)

**Branch auditada:** `mauro`  
**Data:** 10/11/2026  
**Fontes comparadas:**
1. **Estado Remoto Atual:** `supabase/remote_schema.sql` (dump oficial exportado do Supabase).
2. **Estado Local de Migrations:** pasta `supabase/migrations/` (7 arquivos) e `scratch/` (scripts complementares).
3. **Estado Esperado pelo Código:** Implementação Flutter em `lib/features/` (`pet_recognition`, `pet_lost`, `pet_found`, `pet_adoption`, `notification`, `user`, `auth`).

---

## 1. Tabela Comparativa Geral de Objetos

| Objeto | Tipo | Estado Remoto (`remote_schema.sql`) | Estado nas Migrations Locais | Estado Esperado pelo Código Dart | Ação Necessária | Classificação |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`vector`** | Extensão | Habilitada no schema `public` | Habilitada em várias migrations | Usada em `pet_images` e `pet_visual_profiles` | Nenhuma ação necessária | Correto e sincronizado |
| **`uuid-ossp`** | Extensão | Habilitada no schema `extensions` | Habilitada nas migrations | Usada em defaults de IDs | Nenhuma ação necessária | Correto e sincronizado |
| **`pgcrypto`** | Extensão | Habilitada no schema `extensions` | Habilitada nas migrations | Usada em hash e gen_random_uuid | Nenhuma ação necessária | Correto e sincronizado |
| **`profiles`** | Tabela | Existe completa com campos de endereço e avatar | Criada em `setup.sql` | Usada em `ProfileRepository` | Nenhuma ação necessária | Correto e sincronizado |
| **`login_attempts`**| Tabela | Existe com RLS | Criada em migrations de auth | Usada em `AuthRepository` | Nenhuma ação necessária | Correto e sincronizado |
| **`user_push_tokens`** | Tabela | Existe com RLS e constraint `uq_user_push_token` | Criada em migrations de setup | Usada em `SupabaseNotificationService` | Nenhuma ação necessária | Correto e sincronizado |
| **`pet_lost_alerts`** | Tabela | Existe com colunas `latitude`, `longitude`, `status` | Criada e evoluída em migrations | Usada em `PetLostRepository` | Nenhuma ação necessária | Correto e sincronizado |
| **`pet_found_alerts`** | Tabela | Existe com `latitude`, `longitude`, `status` | Criada nas migrations | Usada em `PetFoundRepository` | Nenhuma ação necessária | Correto e sincronizado |
| **`pet_adoption_alerts`** | Tabela | Existe com RLS | Criada nas migrations | Usada em `PetAdoptionRepository` | Nenhuma ação necessária | Correto e sincronizado |
| **`pet_images`** | Tabela | Existe com `embedding vector(768)` | Definida nas migrations de IA | Usada em `SupabasePetRecognitionService` | Adicionar constraint `uq_pet_images_pet_url` | Existente, mas desatualizado |
| **`pet_images.uq_pet_images_pet_url`** | Constraint | **Ausente** | Prevista em `20261110_*.sql` | Necessária para o `upsert(onConflict: 'pet_id,image_url')` | Criar no script incremental | Ausente no remoto |
| **`pet_images (UPDATE e DELETE)`** | Políticas RLS | **Ausentes** (só há SELECT e INSERT) | Não constavam na migration de setup | Necessárias para `savePetImage()` (upsert) e `pruneStalePetImages()` | Criar no script incremental | Ausente no remoto |
| **`pet_visual_profiles`** | Tabela | Existe com `aggregated_embedding vector(768)` e `images jsonb` | Criada nas migrations de IA | Usada em `SupabasePetRecognitionService` | Nenhuma ação na tabela | Correto e sincronizado |
| **`matches`** | Tabela | Existe com `lost_pet_id`, `found_pet_id`, `similarity_score` | Criada em `20260824_*.sql` | Usada em `SupabasePetRecognitionService` | Adicionar coluna `origin` | Existente, mas desatualizado |
| **`matches.origin`** | Coluna | **Ausente** no banco remoto | Adicionada em `20261110_*.sql` | Usada para separar busca 'automatic' e 'manual' | Criar com `DEFAULT 'manual'` | Ausente no remoto |
| **`notifications`** | Tabela | Existe completa com `related_pet_id`, `related_match_id` | Criada nas migrations | Usada em `SupabaseNotificationService` e tela | Nenhuma ação na tabela | Correto e sincronizado |
| **`notifications (uq_notifications_match_event)`** | Índice Único | Existe no remoto como índice parcial | Criado em `20261021_fix_notification_idempotence.sql` | Garante idempotência de avisos | Nenhuma ação necessária | Correto e sincronizado |
| **`idx_pet_visual_profiles_embedding_hnsw`** | Índice Vetorial | **Ausente** (só há btree em `pet_type`) | Previsto em `20261110_*.sql` | Garante alta velocidade em busca vetorial pgvector | Criar no script incremental | Ausente no remoto |
| **`idx_pet_images_embedding_hnsw`** | Índice Vetorial | **Ausente** (só há btree em `pet_id`) | Previsto em `20261110_*.sql` | Garante alta velocidade em embeddings de fotos | Criar no script incremental | Ausente no remoto |
| **`match_found_pets_for_lost`** | Função RPC | **Ausente** no banco remoto | Implementada em `20261110_*.sql` | Invocada por `PetRecognitionRepository.findMatches()` | Criar com SECURITY DEFINER e sem anon | Ausente no remoto |
| **`match_lost_pets_for_found`** | Função RPC | **Ausente** no banco remoto | Implementada em `20261110_*.sql` | Invocada por `matchFoundPetAgainstLostPets()` | Criar com SECURITY DEFINER e sem anon | Ausente no remoto |
| **`handle_auto_match_notification`** | Trigger Function | Existe versão antiga (não checa `origin`, só `score >= 0.70`) | Atualizada nas migrations de 10/11 | Deve notificar apenas quando `origin = 'automatic'` | Atualizar implementação no banco | Existente, mas desatualizado |
| **`trg_notify_on_match`** | Trigger | Existe apenas para `AFTER INSERT` | Atualizada para `AFTER INSERT OR UPDATE OF origin` | Deve disparar na transição manual -> automatic | Recriar trigger | Existente, mas desatualizado |
| **`delete_own_user`** | Função RPC | Existe no remoto com SECURITY DEFINER | Criada no setup de perfis | Invocada por `ProfileRepository.deleteAccount()` | Nenhuma ação necessária | Correto e sincronizado |
| **`is_email_locked`** | Função RPC | Existe no remoto com SECURITY DEFINER | Criada no setup de auth | Invocada por `AuthRepository.checkLock()` | Nenhuma ação necessária | Correto e sincronizado |
| **`register_login_attempt`** | Função RPC | Existe no remoto com SECURITY DEFINER | Criada no setup de auth | Invocada por `AuthRepository.registerAttempt()` | Nenhuma ação necessária | Correto e sincronizado |
| **`handle_new_user`** | Trigger Function | Existe e vinculada em `auth.users` | Criada no setup inicial | Cria registro em `profiles` automaticamente | Nenhuma ação necessária | Correto e sincronizado |
| **`handle_updated_at`** | Trigger Function | Existe e vinculada em `profiles` e `pet_lost_alerts` | Criada no setup inicial | Mantém `updated_at = NOW()` | Nenhuma ação necessária | Correto e sincronizado |
| **Buckets de Storage** (`pet_images`, `avatars`) | Storage | Não refletido no dump de schema público | Definido em scripts de `scratch/` | Invocados em upload de fotos e avatares | Garantir via `INSERT INTO storage.buckets` | Necessita de ação manual/script |

---

## 2. Rastreabilidade das Migrations Locais

### A. Migrations já refletidas no banco remoto
* `20260824_notifications_and_matches.sql` e `20260824_complete_ai_and_notifications_setup.sql`:
  - As tabelas `matches`, `pet_images`, `pet_visual_profiles` e `notifications` já existem no banco remoto com as tipagens e foreign keys essenciais.
* `20261021_fix_notification_idempotence.sql`:
  - O índice único parcial `uq_notifications_match_event` já está aplicado no banco remoto (visível nas linhas 582-584 de `remote_schema.sql`).
* Funções administrativas de login e usuário (`delete_own_user`, `is_email_locked`, `register_login_attempt`, `handle_new_user`, `handle_updated_at`):
  - Todas já estão compiladas e ativas no banco remoto.

### B. Migrations que AINDA NÃO foram aplicadas no banco remoto
* **`20261110_standardize_ai_matching_and_pgvector.sql`**
* **`20261110_fix_ai_matching_security_and_sync.sql`**
  - **Evidência irrefutável:**
    - A coluna `origin` não existe na tabela `matches` em `remote_schema.sql`.
    - A constraint `uq_pet_images_pet_url` não existe em `remote_schema.sql`.
    - Os índices HNSW `idx_pet_visual_profiles_embedding_hnsw` e `idx_pet_images_embedding_hnsw` não existem em `remote_schema.sql`.
    - As funções RPC `match_found_pets_for_lost` e `match_lost_pets_for_found` não existem em `remote_schema.sql`.
    - A trigger function `handle_auto_match_notification` em `remote_schema.sql` ainda é a versão legada que não avalia `NEW.origin`.

### C. Migrations redundantes ou conflitantes identificadas
1. **Redundância histórica de setup:**
   - `20260824_notifications_and_matches.sql`, `20260824_complete_ai_and_notifications_setup.sql` e `20260824_RESET_and_setup_ai_notifications.sql` executavam tarefas semelhantes de recriação de tabelas de IA. O banco remoto estabilizou nessa estrutura em agosto.
2. **Conflito na estratégia de deduplicação:**
   - A migration `20261110_standardize_ai_matching_and_pgvector.sql` utilizava `WHERE a.id > b.id`, gerando risco de apagar linhas com embeddings válidos para manter linhas nulas.
   - A migration `20261110_fix_ai_matching_security_and_sync.sql` corrigiu isso utilizando ordenação por `(embedding IS NOT NULL) DESC, created_at DESC`.
   - **Solução no script incremental:** O script consolidado `02_incremental_remote_update.sql` adota estritamente a versão segura e definitiva, tornando a execução 100% previsível.

---

## 3. Compatibilidade entre Flutter e PostgreSQL

1. **RPCs e Assinatura de Parâmetros:**
   - O Flutter em `supabase_pet_recognition_service.dart` envia:
     ```dart
     params: {
       'query_embedding': queryEmbedding,   // List<double> -> vector(768)
       'target_pet_type': targetPetType,   // String -> varchar(50)
       'exclude_pet_id': excludePetId,     // String -> uuid
       'similarity_threshold': similarityThreshold, // double -> float
       'match_limit': matchLimit,          // int -> int
     }
     ```
   - As funções SQL criadas no script incremental espelham com exatidão esses nomes e tipos de parâmetros, evitando erros de mapeamento no PostgREST.

2. **Segurança e Propriedade:**
   - As RPCs foram protegidas para exigir `auth.uid() = exclude_pet.user_id`. O aplicativo sempre inicia a busca passando o ID do seu próprio animal cadastrado, o que garante 100% de compatibilidade sem quebrar o acesso aos candidatos de terceiros (graças ao `SECURITY DEFINER`).

3. **Operações de Podagem de Fotos:**
   - O aplicativo agora executa `_supabase.from('pet_images').delete().eq('pet_id', petId)...`. A inclusão da política RLS `pet_images_delete_authenticated` garante que essa operação não seja bloqueada por violação de RLS.

---

## 4. Riscos Mitigados pelo Script Incremental

1. **Risco de Perda de Embeddings:** Mitigado pela query de deduplicação com critério de prioridade para vetores não-nulos.
2. **Risco de Ataques de Varredura Anônima:** Mitigado pela revogação de permissões para `anon` e `PUBLIC` nas RPCs.
3. **Risco de Spam de Notificações:** Mitigado pelo trigger que só sensibiliza novos matches automáticos ou transições de manual para automático, além do índice único em `notifications`.
