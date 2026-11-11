# Relatório Técnico Conclusivo de Auditoria e Sincronização — Orelhinhas

**Projeto:** Orelhinhas  
**Branch auditada:** `mauro`  
**Data da Auditoria:** 10–11 de Novembro de 2026  
**Ambiente:** Supabase (PostgreSQL 15+ / pgvector instalada em schema `public` / Storage / Auth / PostgREST) + Flutter 3.x (Clean Architecture / Riverpod)  
**Fontes comparadas:**
1. **Estado Remoto Atual:** `supabase/remote_schema.sql` (dump oficial da instância remota).
2. **Estado das Migrações Locais:** pasta `supabase/migrations/` (todas as migrações existentes).
3. **Estado Esperado pelo Código Dart/Flutter:** `lib/` (features `pet_recognition`, `pet_lost`, `pet_found`, `pet_adoption`, `notification`, `user`, `auth`).

---

## 1. Sumário Executivo e Objetivos Alcançados

Esta auditoria técnica finaliza a consolidação arquitetural do projeto **Orelhinhas**, corrigindo pendências de segurança, integridade de dados, sintaxe SQL e aderência a contratos de API. Foram realizadas revisões profundas do código Flutter para validar cada decisão antes de modificar os scripts.

### A. Correções efetivamente implementadas

#### 1. Sintaxe PostgreSQL (search_path = '')
- **Operador vetorial qualificado:** `public.<=>` substituído por `OPERATOR(public.<=>)` (sintaxe canônica do PostgreSQL para operadores em ambientes com search_path vazio).
- **COALESCE / EXTRACT:** Palavras-chave ANSI SQL — `pg_catalog.coalesce(...)` e `pg_catalog.extract(...)` substituídos por `COALESCE(...)` e `EXTRACT(epoch FROM ...)`.
- **INTERVAL:** `pg_catalog.interval '15 minutes'` substituído por `INTERVAL '15 minutes'`.
- Todas as funções com `SECURITY DEFINER` preservam `SET search_path = ''` e qualificação explícita de schema para objetos `pg_catalog.*`, `auth.*` e `public.*`.

#### 2. Integridade referencial — `matches`
- **Deduplicação NULL-safe:** A exclusão de registros órfãos em `matches` foi reescrita de `NOT IN (SELECT id …)` para `NOT EXISTS (SELECT 1 … WHERE id = m.lost/found_pet_id)`. O padrão `NOT IN` falha silenciosamente quando a subconsulta retorna qualquer NULL — situação possível se `lost_pet_id` ou `found_pet_id` for NULL.
- **Verificação de FK por tabela:** Os checks em `pg_constraint` para `fk_matches_lost_pet`, `fk_matches_found_pet` e `uq_pet_images_pet_url` foram complementados com `AND conrelid = 'public.matches'::regclass` / `'public.pet_images'::regclass`, evitando falso positivo caso outra tabela possua constraint com nome idêntico.

#### 3. RPCs de reconhecimento visual (`match_found_pets_for_lost` / `match_lost_pets_for_found`)
- Embedding consumido **exclusivamente** de `public.pet_visual_profiles` — zero fallback de vetor do cliente.
- Validação cruzada de espécie (alerta de origem + perfil visual + alerta candidato).
- Filtro `status = 'active'` nos candidatos.
- Parâmetros preservados compatíveis com `callMatchRpc` do Flutter.

#### 4. Funções de autenticação (`is_email_locked` / `register_login_attempt`)
- `register_login_attempt`: resets de contador somente para usuário autenticado cujo e-mail coincida com `auth.users`; tentativas falhas rejeitadas para e-mails inexistentes em `auth.users`.
- Bloqueio após 3 falhas consecutivas alinhado com lógica do `auth_controller.dart`.
- `is_email_locked`: retorna `{is_locked: false, …}` para e-mails inexistentes sem leakage de existência da conta (comportamento seguro por design).

#### 5. RLS em `matches`
- **SELECT:** Política `matches_select_involved_owner` — apenas o dono de `lost_pet_id` ou de `found_pet_id` pode ler a correspondência.
- **INSERT/UPDATE:** Políticas `matches_insert_owner` e `matches_update_owner` — restritas ao titular de ao menos um dos animais do par (ver Seção E — Risco Residual Documentado).

#### 6. RLS em `pet_images`
- `pet_images_select_owner` — SELECT restrito ao titular do animal (impede extração de vetores brutos por terceiros via API direta).
- INSERT, UPDATE, DELETE separados por políticas nomeadas de dono.

#### 7. Proteção `anon` em tabelas de embedding
- `REVOKE ALL ON public.pet_images FROM anon` e `REVOKE ALL ON public.pet_visual_profiles FROM anon`.

#### 8. Storage
- Buckets `pet_images` e `avatars` inseridos com `ON CONFLICT (id) DO NOTHING` (sem forçar `public = true` em instâncias existentes).
- Políticas de objetos por pasta (`auth.uid()::text = (storage.foldername(name))[1]`), confirmadas com o padrão `{bucket}/{userId}/{timestamp}.{ext}` utilizado pelo Flutter.

---

## 2. Decisões Arquiteturais com Trade-offs Documentados

### D1 — `pet_visual_profiles` SELECT USING (true)

**Situação:** A política `pet_visual_profiles_select_authenticated` usa `USING (true)`, permitindo que qualquer usuário autenticado leia embeddings de outros usuários via API direta.

**Motivo técnico:** O pipeline de matching do Flutter chama `getVisualProfile(petId)` e `getVisualProfilesByIds([...])` para **pets de outros usuários** (candidatos retornados pelas RPCs pgvector). Restringir o SELECT ao próprio dono quebraria completamente o reconhecimento visual.

**Mitigações aplicadas:**
- RPCs `SECURITY DEFINER` consomem o embedding **apenas da base oficial** — o cliente não pode injetar vetor arbitrário.
- `anon` não tem acesso (`REVOKE ALL FROM anon`).
- `pet_images_select_owner` protege os embeddings individuais por imagem.

**Risco residual:** Usuário autenticado pode chamar `supabase.from('pet_visual_profiles').select().eq('pet_id', X)` e obter o `aggregated_embedding` de qualquer pet de outro usuário.

**Evolução futura recomendada:** Criar uma `VIEW pet_visual_profiles_public` sem a coluna `aggregated_embedding`, conceder `SELECT` na view para `authenticated`, e revogar SELECT direto na tabela base. As RPCs acessariam a tabela base via `service_role` ou dentro de funções `SECURITY DEFINER`.

**Decisão humana obrigatória:** Esta evolução exige alterações no Flutter e deve ser aprovada pelo responsável técnico antes de implementação.

---

### D2 — `matches` INSERT/UPDATE com OR (dono de um dos animais)

**Situação:** A política `matches_insert_owner` permite INSERT quando o usuário autenticado é dono de `lost_pet_id` OU de `found_pet_id`. Isso significa que o dono de um pet perdido pode associá-lo a qualquer `found_pet_id` válido que não seja seu.

**Motivo técnico:** O Flutter chama `saveMatch` diretamente do cliente (após validação via RPC ou comparação local) com `origin = 'automatic'` ou `origin = 'manual'`. Exigir propriedade dos dois animais bloquearia o caso central do sistema.

**Risco residual:** Um usuário mal-intencionado pode inserir correspondências arbitrárias entre seu pet e pets encontrados de terceiros, potencialmente gerando notificações falsas para outros usuários. O trigger `trg_notify_on_match` só dispara para `origin = 'automatic'` — correspondências manuais não geram notificações.

**Evolução futura recomendada:** Substituir o `upsert` direto em `matches` por uma RPC `SECURITY DEFINER` (`save_match_rpc`) que valide:
1. Se o `lost_pet_id` pertence ao usuário autenticado.
2. Se o `found_pet_id` foi retornado por uma RPC vetorial registrada (ou seja, existe perfil visual com score ≥ 0.70).
3. Se a origem informada é coerente com a chamada (automática = originada de RPC; manual = iniciada pelo usuário).

---

## 3. Matriz Comparativa Tripartite e Inventário de Segurança

| Componente | Tipo | Estado Remoto (`remote_schema.sql`) | Estado na Branch `mauro` | Estado Esperado pelo Flutter | Resolução Técnica Consolidada |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`matches.origin`** | Coluna | Ausente | Adicionada como `manual` | Usada para filtrar notificações | Coluna criada com `DEFAULT 'manual'`; registros antigos preservados |
| **`matches (FKs)`** | Constraints | Inexistentes | Adicionadas com `CASCADE` | Integridade referencial | Limpeza NULL-safe de órfãos + `fk_matches_*` com check `conrelid` |
| **`matches (RLS SELECT)`** | RLS | Genérica para autenticados | Estrita aos titulares do par | Leitura dos próprios matches | `matches_select_involved_owner` ativa |
| **`matches (RLS INSERT/UPDATE)`** | RLS | Genérica para autenticados | Dono de ao menos um animal | `saveMatch` direto pelo cliente | `matches_insert_owner` / `matches_update_owner` — risco residual documentado (D2) |
| **`pet_images.uq`** | Constraint | Ausente | Constraint de unicidade | PostgREST `upsert` | Deduplicação determinística + `uq_pet_images_pet_url` com check `conrelid` |
| **`pet_images (RLS)`** | RLS | Incompleta (sem update/delete) | Estrita por titularidade | Prune de fotos e upsert | `pet_images_*_owner` para SELECT, INSERT, UPDATE, DELETE |
| **`pet_visual_profiles (RLS)`** | RLS | Genérica para autenticados | SELECT aberto autenticados / Mutação dono | Leitura de candidatos | Trade-off documentado (D1) — `pet_visual_profiles_select_authenticated USING (true)` |
| **`profiles`** | RLS | Leitura pública para autenticados | Estrita ao próprio ID | Acesso ao perfil próprio | DROP da política pública; isolamento `auth.uid() = id` |
| **`notifications`** | RLS | Inserção livre para autenticados | Inserção restrita a triggers | Leitura/atualização do dono | DROP de `notifications_insert_authenticated` (anti-spoofing) |
| **`HNSW pgvector`** | Índices | Apenas btree existente | Índices HNSW criados | Busca vetorial por cosseno | `idx_*_embedding_hnsw` com `vector_cosine_ops` |
| **`match_found_pets_for_lost`** | RPC | Inexistente | Blindada com `search_path = ''` | Invocada por `findMatches` | Embedding exclusivo da base; `OPERATOR(public.<=>)` |
| **`match_lost_pets_for_found`** | RPC | Inexistente | Blindada com `search_path = ''` | Invocada por `matchFoundPetAgainstLostPets` | Embedding exclusivo da base; `OPERATOR(public.<=>)` |
| **`register_login_attempt`** | RPC | Permissiva e vulnerável a DoS | Blindada com `search_path = ''` | Controle de bloqueio | Resets anônimos bloqueados; trava em 3 falhas |
| **`is_email_locked`** | RPC | Sem sanitização | Sanitizada (`LOWER(TRIM)`) | Verificação no login | Endurecida com `search_path = ''`; sem leakage de existência |
| **Storage `pet_images`** | Bucket | Políticas legadas dispersas | Isolamento por pasta | Upload `{userId}/...` | `storage_pet_images_*` ativas; leitura pública, mutação por pasta |
| **Storage `avatars`** | Bucket | Políticas legadas dispersas | Isolamento por pasta | Upload `{userId}/...` | `storage_avatars_*` ativas; leitura pública, mutação por pasta |
| **`vector` extension** | Extensão | Instalada em `public` (confirmado em `remote_schema.sql`) | `CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public` | `public.vector(768)` em colunas e RPCs | Compatível — schema `public` confirmado no remoto |

---

## 4. Compatibilidade com Flutter (D)

| Módulo / Fluxo Flutter | Operação Verificada | Resultado |
| :--- | :--- | :--- |
| `SupabasePetRecognitionService.saveMatch` | `upsert` em `matches` | ✅ Compatível com `matches_insert_owner` (OR) |
| `SupabasePetRecognitionService.getMatchesForLostPet` | SELECT em `matches` com `.eq('lost_pet_id', …)` | ✅ Compatível com `matches_select_involved_owner` |
| `SupabasePetRecognitionService.getMatchScore` | SELECT `similarity_score` em `matches` | ✅ Compatível |
| `SupabasePetRecognitionService.getVisualProfile` | SELECT em `pet_visual_profiles` | ✅ Compatível com SELECT USING(true) |
| `SupabasePetRecognitionService.getVisualProfilesByIds` | SELECT em `pet_visual_profiles` com inFilter | ✅ Compatível com SELECT USING(true) |
| `SupabasePetRecognitionService.saveVisualProfile` | upsert em `pet_visual_profiles` | ✅ Compatível com `pet_visual_profiles_manage_owner` |
| `SupabasePetRecognitionService.callMatchRpc` | RPC `match_found_pets_for_lost` / `match_lost_pets_for_found` | ✅ Assinatura preservada; embedding vem da base |
| `StorageService.uploadImage` | `storage.from(bucket).uploadBinary('{userId}/{ts}.{ext}')` | ✅ Compatível com `storage_*_insert_owner` via `foldername[1]` |
| `AuthRepository.checkLock` | RPC `is_email_locked` | ✅ Compatível; retorna `{is_locked, remaining_seconds, attempts_count}` |
| `AuthRepository.registerAttempt` | RPC `register_login_attempt` | ✅ Compatível; anon pode chamar para falhas; reset requer auth |
| `SupabasePetRecognitionService` (pet_images) | SELECT para embedding existente | ✅ `pet_images_select_owner` protege; a leitura é sempre do próprio pet |

---

## 5. Validações Realmente Executadas (B)

| Validação | Método | Resultado |
| :--- | :--- | :--- |
| Testes unitários de IA e reconhecimento | `flutter test test/pet_recognition_test.dart` | ✅ 39/39 aprovados (`All tests passed!`) |
| Análise estática Flutter | `flutter analyze --no-pub` | ✅ `No issues found! (ran in 12.5s)` |
| Verificação de assinatura das RPCs | Comparação manual Flutter ↔ SQL | ✅ Parâmetros idênticos |
| Verificação de sintaxe SQL | Grep + análise estática dos scripts | ✅ Sem `pg_catalog.coalesce`, `pg_catalog.extract`, `pg_catalog.interval`, `public.<=>` inválidos |
| Verificação de caminho Storage | Leitura de código Flutter (`StorageService`, screens) | ✅ Padrão `{userId}/{timestamp}.{ext}` confirmado |
| Verificação de NULL em DELETE orphan | Análise do script incremental | ✅ Corrigido para `NOT EXISTS` |
| Verificação de FK por tabela | Análise do bloco DO $$ | ✅ `conrelid` adicionado |
| Leitura de `remote_schema.sql` | Schema dump disponível | ✅ `vector` em schema `public` confirmado; tabelas `matches`, `pet_images`, `pet_visual_profiles` existentes |
| Execução de SQL no Supabase remoto | — | ❌ **NÃO EXECUTADO** (escopo proibido) |

---

## 6. Pontos Ainda Pendentes / Decisões Humanas (C)

| Item | Natureza | Ação Esperada |
| :--- | :--- | :--- |
| **D1 — Exposição de `aggregated_embedding`** | Decisão arquitetural de segurança | Aprovar trade-off atual ou planejar migração para view sem coluna de embedding |
| **D2 — `saveMatch` direto pelo cliente** | Decisão de arquitetura de segurança | Aprovar trade-off atual ou planejar RPC `save_match_rpc` SECURITY DEFINER |
| **Visibilidade pública dos buckets** | Decisão de privacidade | Confirmar que URLs públicas são aceitáveis ou migrar para signed URLs |
| **Backup verificável antes da execução** | Pré-requisito crítico | Operador deve atestar backup completo (esquema + dados + policies + storage) |
| **Execução do script no SQL Editor** | Ação operacional no remoto | Seguir `03_manual_steps.md` Etapa 2 |
| **Validação pós-execução no Supabase** | Ação operacional no remoto | Seguir `03_manual_steps.md` Etapa 4 (bateria SQL de inspeção) |
| **Atualização de `remote_schema.sql`** | Ação operacional local | `npx supabase db dump` ou `pg_dump` após aplicação |

---

## 7. Riscos Residuais (E)

| Risco | Severidade | Mitigação Existente | Recomendação Futura |
| :--- | :--- | :--- | :--- |
| Usuário autenticado lê `aggregated_embedding` de qualquer pet via API | Médio | `anon` revogado; RPCs ignoram vetor do cliente | View sem coluna de embedding (ver D1) |
| Usuário autenticado cria `match` associando seu pet a qualquer `found_pet_id` válido | Médio | Trigger de notificação só dispara para `origin = 'automatic'`; score mínimo 0.70 no Flutter | RPC `save_match_rpc` SECURITY DEFINER (ver D2) |
| `is_email_locked` / `register_login_attempt` chamadas por `anon` | Baixo | `register_login_attempt` rejeita e-mails inexistentes; reset exige auth | Implementação como Auth Hook ou Edge Function no Supabase em versão futura |
| Imagens públicas acessíveis por URL direta sem autenticação | Baixo / Aceito | Decisão arquitetural deliberada (getPublicUrl nos cards) | Signed URLs se privacidade das imagens for requisito futuro |

---

## 8. Parecer Final (F)

> **PARECER DA AUDITORIA: ✅ APROVADO COM RESSALVAS**  
> Todos os problemas críticos de sintaxe SQL, integridade referencial e segurança com solução técnica possível sem quebrar o Flutter foram corrigidos. Os scripts `01_complete_database_baseline.sql` e `02_incremental_remote_update.sql` estão consistentes entre si e com a implementação Flutter.  
>
> As ressalvas documentadas (D1, D2 e riscos residuais de E) representam **trade-offs arquiteturais deliberados** que dependem de decisão humana para evolução. Não representam bloqueios para a execução controlada do script incremental no Supabase remoto.  
>
> A execução manual no Supabase remoto está liberada para ser realizada pelo operador humano, observando as etapas de salvaguarda descritas em `03_manual_steps.md` e confirmando os resultados esperados da bateria SQL de inspeção (Etapa 4).
