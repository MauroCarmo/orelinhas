# Relatório Técnico Conclusivo de Auditoria e Implementação — Orelhinhas

**Projeto:** Orelhinhas  
**Branch auditada e corrigida:** `mauro`  
**Data da Auditoria e Implementação:** 11 de Novembro de 2026  
**Ambiente:** Supabase (PostgreSQL 15+ / pgvector em schema `public` / Storage / Auth / PostgREST) + Flutter 3.x (Clean Architecture / Riverpod)  
**Fontes e Artefatos Envolvidos:**
1. **Estado Remoto Atual:** `supabase/remote_schema.sql` (dump oficial da instância remota).
2. **Scripts SQL Consolidados:** `supabase/audit/01_complete_database_baseline.sql` e `supabase/audit/02_incremental_remote_update.sql`.
3. **Código-fonte Flutter:** `lib/` (features `pet_recognition`, `pet_lost`, `pet_found`, `pet_adoption`, `notification`, `user`, `auth`).
4. **Bateria de Testes Automatizados:** `test/pet_recognition_test.dart` (48 testes aprovados).

---

## 1. Sumário Executivo e Objetivos Alcançados

Esta etapa implementou as correções estruturais definitivas para eliminar as vulnerabilidades **D1 (exposição de embeddings de terceiros)** e **D2 (criação e manipulação arbitrária de matches pelo cliente)**, mantendo a integridade arquitetural do projeto (Clean Architecture, Riverpod, Supabase), sem alterações desnecessárias em telas ou módulos satélites e preservando integralmente o fluxo de Autenticação/Login.

### A. Diagnóstico Inicial e Correções Efetivamente Implementadas

#### 1. Resolução Definitiva de D1 — Blindagem de Embeddings
- **Problema anterior:** `pet_visual_profiles` possuía política de leitura permissiva `USING (true)`, permitindo que qualquer usuário autenticado consultasse livremente os vetores SigLIP de 768 dimensões de animais pertencentes a outros usuários via API REST direta.
- **Correção implementada:**
  - Política permissiva eliminada em ambos os scripts SQL (`01_baseline` e `02_incremental`).
  - Implementada a política estrita `pet_visual_profiles_select_owner`:
    ```sql
    CREATE POLICY "pet_visual_profiles_select_owner" ON public.pet_visual_profiles
    FOR SELECT TO authenticated USING (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    );
    ```
  - As operações de busca e correspondência entre animais são executadas exclusivamente no servidor via RPCs PostgreSQL (`match_found_pets_for_lost` e `match_lost_pets_for_found`) com `SECURITY DEFINER` e `SET search_path = ''`.
  - O retorno das RPCs expõe estritamente `TABLE (pet_id uuid, similarity_score double precision)`. **Nenhum vetor individual ou agregado de terceiros é transmitido ao cliente.**
  - O Flutter foi adaptado para consumir os resultados consolidados das RPCs sem depender de leitura de embeddings de terceiros.

#### 2. Resolução Definitiva de D2 — Persistência Segura de Matches via RPC
- **Problema anterior:** O cliente Flutter executava operações `.upsert()` diretamente na tabela `matches`. As políticas RLS com condição disjuntiva (`OR`) permitiam que um usuário associasse arbitrariamente seu pet a qualquer alerta encontrado de terceiro e forjasse pontuações de similaridade.
- **Correção implementada:**
  - **Criação da RPC `public.save_match`** com `SECURITY DEFINER` e `SET search_path = ''`:
    - Valida autenticação do usuário chamador (`auth.uid()`).
    - Valida existência e status ativo (`'active'`) tanto do animal perdido quanto do animal encontrado.
    - Valida compatibilidade estrita de espécie entre os dois alertas (cão != gato).
    - Valida a titularidade legítima: o usuário autenticado deve ser o proprietário do `lost_pet` OU do `found_pet`.
    - **Cálculo multi-sinal no servidor:** A pontuação é computada no servidor utilizando a fórmula balanceada multi-vetor (`score = 0.50 * max + 0.30 * avg + 0.20 * aggregated`) a partir das imagens (`pet_images`) e perfis oficiais (`pet_visual_profiles`). Preserva o array real de similaridades individuais (`individual_scores`) em JSONB. O cliente não pode forjar ou inflar scores.
    - **Controle estrito de origem:** A RPC `save_match` chamada pelo cliente persiste exclusivamente com `origin = 'manual'`, garantindo que buscas manuais não disparem notificações espúrias. Correspondências automáticas são geradas exclusivamente no servidor pelas RPCs de busca (`match_found_pets_for_lost` e `match_lost_pets_for_found`) com `origin = 'automatic'` quando o score atinge ou supera o limiar configurado (≥ 0.70).
    - **Idempotência e transição de origem:** Operações repetidas preservam o par único (`uq_matches_pair`), atualizam para o maior score via `GREATEST(...)` e preservam a origem `'automatic'` se a correspondência já tiver sido promovida legitimamente pelo backend.
  - **Inclusão da política de exclusão em `pet_found_alerts`:** Adicionada a política `Permitir exclusão do próprio alerta encontrado` (`FOR DELETE USING (auth.uid() = user_id)`), assegurando conformidade de segurança com a funcionalidade de deleção do Flutter.
  - **Revogação de Escrita Direta na Tabela `matches`:**
    - Políticas `matches_insert_owner` e `matches_update_owner` foram **revogadas**.
    - Concessões de `INSERT`, `UPDATE` e `DELETE` em `public.matches` para o papel `authenticated` foram revogadas.
    - Acesso à tabela `matches` por clientes é estritamente de leitura para os proprietários envolvidos (`matches_select_involved_owner`). Toda criação e atualização de matches é canalizada compulsoriamente pela RPC `save_match`.
  - **Refatoração no Flutter:** `SupabasePetRecognitionService.saveMatch` foi refatorado para invocar a RPC `save_match`, removendo o método `.upsert()` direto na tabela.

#### 3. Sintaxe PostgreSQL e Robustez de Catálogo
- Operador vetorial qualificado de forma válida: `OPERATOR(public.<=>)` em todas as RPCs.
- Remoção de falsas funções de catálogo (`pg_catalog.coalesce`, `pg_catalog.extract`, `pg_catalog.interval`) substituídas por ANSI SQL canônico.
- Verificação de constraints referenciando `conrelid = 'public.matches'::regclass` e `'public.pet_images'::regclass`.
- Exclusão de órfãos NULL-safe utilizando `NOT EXISTS`.

#### 4. Triggers e Notificações Preservados
- O trigger `trg_notify_on_match` continua monitorando `AFTER INSERT OR UPDATE OF origin ON public.matches` disparando `handle_auto_match_notification()`.
- Notificações são geradas **exclusivamente** para correspondências automáticas (`origin = 'automatic'`) com `similarity_score >= 0.70`.
- Matches manuais criados pelo usuário **não disparam notificações**.
- Deduplicação garantida pelo índice único parcial `uq_notifications_match_event`.

---

## 2. Auth/Login — Preservação Absoluta (Zero Alterações)

Conforme diretriz mandatória de preservação estrita do subsistema de Autenticação e Login:
- **Zero modificações em funções de autenticação no script incremental:** As operações que alteravam ou recriavam `public.is_email_locked(text)`, `public.register_login_attempt(text, boolean)` e `public.delete_own_user()` (antigas seções 5.1, 5.2 e 5.3), bem como suas respectivas declarações de `GRANT` e `REVOKE`, foram **totalmente removidas** do script `02_incremental_remote_update.sql`. O banco remoto permanece com as versões originais exatamente como registradas em `remote_schema_pre_update.sql`.
- **Zero alterações na tabela `profiles`:** A operação que removia políticas em `public.profiles` foi excluída do script incremental. Nenhuma política, trigger ou coluna de `profiles` é alterada.
- **Nenhum arquivo Dart de autenticação modificado:** `auth_controller.dart`, `auth_repository.dart`, fluxos de login, cadastro, recuperação de senha e gerenciamento de sessões mantêm-se 100% íntegros.
- O trigger `handle_new_user` em `auth.users` e as rotinas de criação de perfil permanecem intactos.

---

## 3. Matriz Comparativa Tripartite e Inventário de Segurança

| Componente | Tipo | Estado Remoto Anterior | Estado Intermediário Auditado | Estado Final Consolidado (Após D1 e D2) |
| :--- | :--- | :--- | :--- | :--- |
| **`matches (Escrita)`** | RLS / Grants | Aberto / Indefinido | INSERT/UPDATE com OR (D2 pendente) | **Escrita direta revogada.** Concedido apenas `EXECUTE` na RPC `save_match` |
| **`matches.origin`** | Coluna | Ausente | Adicionada como `manual` | Coluna com default `'manual'`; gerenciada exclusivamente via `save_match` |
| **`matches.updated_at`** | Coluna | Ausente | Ausente | Adicionada com `DEFAULT NOW()`; atualizada pela RPC `save_match` |
| **`matches (RLS SELECT)`** | RLS | Genérica | `matches_select_involved_owner` | Restrita exclusivamente aos proprietários do par envolvido |
| **`pet_visual_profiles`** | RLS | Genérica | SELECT `USING (true)` (D1 pendente) | **`pet_visual_profiles_select_owner`** (somente o tutor lê seu próprio pet) |
| **`save_match`** | RPC | Inexistente | Inexistente | **Implementada** com `SECURITY DEFINER`, validações completas e cálculo server-side |
| **`match_found_pets_for_lost`** | RPC | Inexistente | `search_path = ''` | Blindada; consome embedding da base; retorna apenas `(pet_id, score)` |
| **`match_lost_pets_for_found`** | RPC | Inexistente | `search_path = ''` | Blindada; consome embedding da base; retorna apenas `(pet_id, score)` |
| **`pet_images`** | RLS | Parcial | `pet_images_*_owner` | Restrita ao tutor para todas as operações |
| **`notifications`** | RLS | Inserção cliente permitida | Inserção revogada | Inserção restrita a triggers do banco (anti-spoofing) |
| **`HNSW pgvector`** | Índices | Apenas btree | HNSW criado | `vector_cosine_ops` com operador `OPERATOR(public.<=>)` |

---

## 4. Arquivos Alterados nesta Etapa

### Flutter (Dart):
1. [`lib/features/pet_recognition/data/services/supabase_pet_recognition_service.dart`](file:///C:/Users/mbdcc/.gemini/antigravity/scratch/orelinhas/lib/features/pet_recognition/data/services/supabase_pet_recognition_service.dart):
   - Refatoração do método `saveMatch`: substituição da escrita direta `.from('matches').upsert()` pela chamada à RPC segura `_supabase.rpc('save_match', params: ...)`.
   - Limpeza na assinatura de `callMatchRpc`: remoção do parâmetro não utilizado `queryEmbedding`, consolidando a passagem direta de `p_source_pet_id` e alinhando com a assinatura SQL da RPC.
2. [`lib/features/pet_recognition/data/repositories/pet_recognition_repository.dart`](file:///C:/Users/mbdcc/.gemini/antigravity/scratch/orelinhas/lib/features/pet_recognition/data/repositories/pet_recognition_repository.dart):
   - Atualização das chamadas a `callMatchRpc` removendo `queryEmbedding` em conformidade com o novo contrato de backend.
3. [`test/pet_recognition_test.dart`](file:///C:/Users/mbdcc/.gemini/antigravity/scratch/orelinhas/test/pet_recognition_test.dart):
   - Inclusão do Grupo 9 com 5 novos testes cobrindo segurança D1 (não-exposição de vetores no retorno de RPCs) e D2 (validação de score, idempotência de pares repetidos, descarte de scores abaixo do limiar e isolamento estrito de espécies).

### Scripts SQL:
1. [`supabase/audit/01_complete_database_baseline.sql`](file:///C:/Users/mbdcc/.gemini/antigravity/scratch/orelinhas/supabase/audit/01_complete_database_baseline.sql):
   - Inclusão da coluna `updated_at` na tabela `matches`.
   - Implementação da RPC `public.save_match`.
   - Remoção de `query_embedding` das assinaturas das RPCs `match_found_pets_for_lost` e `match_lost_pets_for_found`, com grants atualizados.
   - Substituição de `pg_catalog.trim` por `pg_catalog.btrim`.
   - Substituição da política permissiva por `pet_visual_profiles_select_owner`.
   - Revogação de INSERT/UPDATE direto em `matches`, mantendo `matches_select_involved_owner`.
   - Adicionada política `DELETE` para `pet_found_alerts`.
   - Concessões explícitas de grants e permissões de segurança.
2. [`supabase/audit/02_incremental_remote_update.sql`](file:///C:/Users/mbdcc/.gemini/antigravity/scratch/orelinhas/supabase/audit/02_incremental_remote_update.sql):
   - Alteração delta de `updated_at` e `origin` em `matches`.
   - Criação da RPC `public.save_match`.
   - Criação da função auxiliar `public.calculate_match_score` com fórmula canônica 50/30/20.
   - Remoção de `query_embedding` das assinaturas das RPCs `match_found_pets_for_lost` e `match_lost_pets_for_found` (com `DROP FUNCTION IF EXISTS` prévio de assinaturas legadas).
   - Políticas RLS e revogações de acesso direto em `matches`, `pet_images`, `pet_visual_profiles` e `notifications`, incluindo `DELETE` em `pet_found_alerts`.
   - **Exclusão completa de Auth/Login:** Remoção integral das operações de alteração em `is_email_locked`, `register_login_attempt`, `delete_own_user` e `profiles`.

---

## 5. Validações Realmente Executadas

| Validação | Ferramenta / Método | Resultado |
| :--- | :--- | :--- |
| Testes Automatizados Unitários e de IA | `flutter test test/pet_recognition_test.dart` | ✅ **48/48 aprovados (`All tests passed!`)** |
| Análise Estática do Código Dart | `flutter analyze --no-pub` | ✅ **`No issues found!` (0 erros, 0 warnings)** |
| Verificação de Sintaxe SQL Qualificada | Grep por operadores e funções inválidas | ✅ **Zero construções inválidas; 14 ocorrências canônicas de `OPERATOR(public.<=>)`** |
| Sincronismo Baseline ↔ Incremental | Comparação de DDL, RPCs e RLS | ✅ **Consistentes e idempotentes** |
| Execução Direta no Banco Remoto | — | ❌ **NÃO EXECUTADA** (estritamente vedada pelas diretrizes) |

---

## 6. Riscos Residuais e Procedimentos de Aplicação Remota

| Risco Residual | Severidade | Mitigação Existente | Ação Necessária |
| :--- | :--- | :--- | :--- |
| Necessidade de execução manual no Supabase | Baixo | Scripts transacionais e documentados | Aplicar `02_incremental_remote_update.sql` no SQL Editor do Supabase |
| Backup pré-execução | Crítico para contingência | Procedimento documentado em `03_manual_steps.md` | Operador deve gerar dump completo (DDL + dados) antes de aplicar o script |
| Imagens públicas em storage | Baixo / Aceito por design | URLs públicas usadas para exibição em cards | Manter configuração atual; migrar para signed URLs apenas se houver exigência futura |

---

## 7. Parecer Técnico Final

> **PARECER DA AUDITORIA: ✅ APROVADO PARA EXECUÇÃO CONTROLADA**  
> Os dois bloqueios arquiteturais remanescentes (**D1** — exposição de embeddings de terceiros; **D2** — manipulação de correspondências pelo cliente) foram **definitivamente resolvidos** no código Dart e nos scripts SQL.  
> 
> A leitura de embeddings de terceiros foi eliminada e transferida para processamento seguro server-side via RPCs `SECURITY DEFINER`. A persistência de matches agora é controlada pela RPC `save_match`, que recalcula o score no servidor a partir dos dados persistidos oficiais e impede a criação de vínculos arbitrários.  
> 
> Todos os 48 testes automatizados estão passando, o analisador Dart está limpo sem advertências e o módulo de Auth/Login permanece intocado. Os scripts estão prontos para aplicação manual no Supabase remoto pelo operador responsável, seguindo o roteiro estabelecido em `03_manual_steps.md`.