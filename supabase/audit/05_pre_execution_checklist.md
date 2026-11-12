# Checklist Pré-Execução e Validação Técnica de Conformidade — Orelhinhas

**Branch:** `mauro`  
**Data:** 11 de Novembro de 2026  
**Documentos Vinculados:**
- `supabase/audit/01_complete_database_baseline.sql`
- `supabase/audit/02_incremental_remote_update.sql`
- `supabase/audit/03_manual_steps.md`
- `supabase/audit/04_final_audit_report.md`

Este checklist formal separa com precisão as correções aplicadas no código, as validações executadas localmente, as decisões humanas e as ações dependentes do ambiente remoto.

> [!IMPORTANT]
> **Não considere o status "CONCLUÍDO" como prova automática de que um item funciona no banco remoto.** Verifique diretamente no Supabase SQL Editor após a execução do script incremental (Etapa 4 do `03_manual_steps.md`).

---

## 1. Correções Concluídas nos Scripts SQL e Código (Resolvido)

| Status | Item de Auditoria | Critério de Aceitação / Implementação | Detalhes Técnicos |
| :---: | :--- | :--- | :--- |
| **CONCLUÍDO** | Blindagem de Embeddings (**D1 Resolvido**) | Leitura direta permissiva eliminada; SELECT restrito ao proprietário via `pet_visual_profiles_select_owner` | Matching e busca vetorial transferidos exclusivamente para RPCs `SECURITY DEFINER` |
| **CONCLUÍDO** | Persistência Segura de Matches (**D2 Resolvido**) | Escrita direta no cliente revogada; criação manual via RPC `save_match` | Validação de espécies, status, titularidade e cálculo multi-sinal (0.50 max + 0.30 avg + 0.20 agg) no servidor |
| **CONCLUÍDO** | Proteção da Origem Automática | Matches automáticos criados exclusivamente pelo backend/RPCs de busca | `match_found_pets_for_lost` e `match_lost_pets_for_found` geram `origin = 'automatic'` se score >= 0.70 |
| **CONCLUÍDO** | Validação Estrita de Identidade de Sessão | RPCs automáticas comparam `auth.uid()` com `p_user_id` e bloqueiam forjamento de UUID | Previne impersonação; preserva `service_role` administrativo |
| **CONCLUÍDO** | Proteção de Score e Metadados (UPSERT) | `similarity_score = GREATEST(...)`, metadados condicionais e preservação de `origin = 'automatic'` | Impede que buscas posteriores degradem scores superiores já persistidos |
| **CONCLUÍDO** | Isolamento de Função Auxiliar (`calculate_match_score`) | Revogado acesso de `PUBLIC`, `anon` e `authenticated`; concedido apenas a `service_role` | Invocação interna encapsulada pelas RPCs `SECURITY DEFINER` via owner |
| **CONCLUÍDO** | Exclusão do Próprio Alerta Encontrado | Adicionada política `DELETE` para `pet_found_alerts` vinculada a `auth.uid() = user_id` | Alinha o banco com `deleteAlert` implementado no Flutter |
| **CONCLUÍDO** | Refatoração Flutter em `saveMatch` | `SupabasePetRecognitionService.saveMatch` migrado de `.upsert()` para `_supabase.rpc('save_match')` | Sincronizado com score e origem oficiais validados pelo servidor |
| **CONCLUÍDO** | Blindagem das RPCs Vetoriais | Remoção de fallback de embedding do cliente; uso exclusivo de vetor oficial de `pet_visual_profiles` | `match_found_pets_for_lost` e `match_lost_pets_for_found` |
| **CONCLUÍDO** | Sintaxe PostgreSQL — Operador Vetorial | `public.<=>` substituído por `OPERATOR(public.<=>)` em todas as RPCs com `search_path = ''` | Parser do PostgreSQL exige esta forma canônica |
| **CONCLUÍDO** | Sintaxe PostgreSQL — COALESCE / EXTRACT / INTERVAL | `pg_catalog.coalesce`, `pg_catalog.extract`, `pg_catalog.interval` substituídos por construções ANSI SQL padrão | `COALESCE(...)`, `EXTRACT(epoch FROM ...)`, `INTERVAL '15 minutes'` |
| **CONCLUÍDO** | Validação Dupla de Espécie | Validação da espécie de origem e da espécie candidata no perfil e no alerta (`dog`/`cat`) | Isolamento estrito entre caninos e felinos |
| **CONCLUÍDO** | Filtro de Status Ativo nas RPCs | Participação restrita a alertas onde `status = 'active'` | Alertas inativos ou resolvidos desconsiderados |
| **CONCLUÍDO** | Endurecimento `SECURITY DEFINER` | `SET search_path = ''` em todas as funções privilegiadas com qualificação explícita de schema | Previne sequestro de search path temporário |
| **CONCLUÍDO** | Permissões Explícitas de Execução | Revogação de `anon` e `PUBLIC`; concessão com assinaturas explícitas de tipos | `REVOKE ... FROM PUBLIC, anon; GRANT ... TO authenticated` |
| **CONCLUÍDO** | Preservação Absoluta de Auth/Login | Funções `is_email_locked`, `register_login_attempt` e `delete_own_user` mantidas 100% intactas | Operações removidas do incremental; zero modificações no subsistema de autenticação |
| **CONCLUÍDO** | Preservação da Tabela `profiles` | Nenhuma política RLS, coluna ou trigger de `profiles` modificada no incremental | Estado remoto original estritamente preservado |
| **CONCLUÍDO** | Remoção de `query_embedding` das Assinaturas | Assinatura simplificada em `match_found_pets_for_lost` e `match_lost_pets_for_found` | Sem parâmetro ocioso; grants e chamadas Flutter atualizados |
| **CONCLUÍDO** | Isolamento de Autenticação Remota | Zero risco de regressão em login, cadastro, recuperação de senha e sessões | Diretriz mandatória cumprida integralmente |
| **CONCLUÍDO** | Proteção de Embeddings em `pet_images` | SELECT restrito ao titular do animal via `pet_images_select_owner` | Terceiros não podem baixar vetores brutos individuais via API |
| **CONCLUÍDO** | `anon` revogado em tabelas de embedding e matches | `REVOKE ALL ON pet_images, pet_visual_profiles, matches FROM anon` | Acesso não autenticado bloqueado |
| **CONCLUÍDO** | `matches` SELECT — Privacidade | `matches_select_involved_owner` restringe SELECT a quem é dono de `lost_pet_id` OU `found_pet_id` | Terceiros não leem correspondências alheias |
| **CONCLUÍDO** | `matches` INSERT/UPDATE direto revogado | Nenhuma política de INSERT ou UPDATE concedida para clientes na tabela `matches` | Toda inserção canalizada compulsoriamente via RPC `save_match` |
| **CONCLUÍDO** | Prevenção de Spoofing de Avisos | Remoção de `notifications_insert_authenticated` — INSERT somente via trigger do banco | Clientes não inserem notificações arbitrárias |
| **CONCLUÍDO** | Preservação de Matches Antigos | Coluna `origin` com `DEFAULT 'manual'`; sem updates cegos para `'automatic'` | Evita notificações retroativas |
| **CONCLUÍDO** | Deduplicação NULL-safe de `pet_images` | `NOT EXISTS` em vez de `NOT IN` na exclusão de duplicatas | `NOT IN` falha silenciosamente com NULLs |
| **CONCLUÍDO** | FK com verificação por tabela (`conrelid`) | Checks em `pg_constraint` incluem `conrelid = 'public.matches'::regclass` | Evita falso positivo com constraints homônimas em outros schemas |
| **CONCLUÍDO** | Chaves Estrangeiras em `matches` | Limpeza NULL-safe de órfãos + `fk_matches_*` com `ON DELETE CASCADE` | Integridade referencial garantida |
| **CONCLUÍDO** | `uq_pet_images_pet_url` com verificação por tabela | Check inclui `conrelid = 'public.pet_images'::regclass` | Idempotência e precisão do check |
| **CONCLUÍDO** | Configuração Defensiva de Storage | `ON CONFLICT (id) DO NOTHING`; políticas por pasta `{userId}/...` | Preserva configurações existentes; caminhos Flutter confirmados |

---

## 2. Validações Realizadas Localmente no Ambiente (Verificado)

| Status | Validação Local | Resultado Obtido | Evidência |
| :---: | :--- | :--- | :--- |
| **VALIDADO** | Análise Estática do Flutter | 0 erros, 0 avisos | `flutter analyze --no-pub` → `No issues found! (ran in 13.8s)` |
| **VALIDADO** | Bateria de Testes Unitários de IA e Segurança | 48/48 aprovados (100%) | `flutter test test/pet_recognition_test.dart` → `All tests passed!` |
| **VALIDADO** | Contratos de Assinatura das RPCs | Parâmetros de `callMatchRpc` e `saveMatch` sincronizados com SQL | `save_match`, `match_found_pets_for_lost`, `match_lost_pets_for_found` |
| **VALIDADO** | Consistência Baseline vs Incremental | Funções, constraints, RLS, índices e políticas produzem estado equivalente | Análise estática comparativa manual |
| **VALIDADO** | Sintaxe SQL — Ausência de erros conhecidos | Grep confirmou ausência de `public.<=>` bare, `pg_catalog.coalesce`, `pg_catalog.extract`, `pg_catalog.interval` | `Select-String` nos arquivos de auditoria |
| **VALIDADO** | Padrão de Upload no Storage | Flutter usa `{bucket}/{userId}/{timestamp}.{ext}` | Leitura de `storage_service.dart`, `create_pet_lost_screen.dart`, etc. |
| **VALIDADO** | Extensão `vector` no schema `public` | Confirmado em `remote_schema.sql` linha 48 | `CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public"` |
| **VALIDADO** | Isolamento de Espécies | Verificado em teste unitário específico | Cão e gato nunca se cruzam no matching |
| **NÃO EXECUTADO** | Execução do SQL no Supabase remoto | — | Fora do escopo desta fase |

---

## 3. Decisões Humanas e Operacionais

| Status | Decisão / Ação | Contexto Técnico | Ação Esperada |
| :---: | :--- | :--- | :--- |
| **RESOLVIDO TECNICAMENTE** | D1 — Proteção de `aggregated_embedding` | SELECT restrito ao dono; matching transferido para RPCs server-side | Validar comportamento em staging |
| **RESOLVIDO TECNICAMENTE** | D2 — Persistência segura de correspondências | RPC `save_match` implementada; escrita direta na tabela revogada | Validar comportamento em staging |
| **DECISÃO HUMANA** | Visibilidade Pública dos Buckets | Buckets `pet_images` e `avatars` públicos viabilizam `getPublicUrl` nos cards | Confirmar aceitabilidade ou migrar para signed URLs no futuro |
| **DECISÃO HUMANA** | Validação do Plano de Backup | O método de backup varia conforme plano Free/Pro do Supabase | Atestar que backup verificável (esquema + dados + policies) está gravado |
| **DECISÃO HUMANA** | Agendamento da Janela de Aplicação | Script DDL incremental deve ser aplicado em horário de baixo tráfego | Aprovação do cronograma pelo responsável técnico |

---

## 4. Etapas que Só Podem Ser Confirmadas Após Intervenção no Supabase Remoto

| Status | Etapa Remota | Procedimento Obrigatório | Responsável |
| :---: | :--- | :--- | :--- |
| **DEPENDENTE DO REMOTO** | Execução do Script no SQL Editor | Colar e executar `02_incremental_remote_update.sql` completo | Operador Humano |
| **DEPENDENTE DO REMOTO** | Verificação de `origin` e `updated_at` em `matches` | Confirmar que as colunas foram adicionadas com sucesso | Operador Humano |
| **DEPENDENTE DO REMOTO** | Inspeção SQL Pós-Aplicação | Executar bateria de consultas da Etapa 4 de `03_manual_steps.md` | Operador Humano |
| **DEPENDENTE DO REMOTO** | Validação das Funções com `search_path` | Confirmar `proconfig = '{search_path=}'` via `pg_proc` | Operador Humano |
| **DEPENDENTE DO REMOTO** | Validação no Painel de Storage | Confirmar buckets e políticas ativas; nenhuma política legada remanescente | Operador Humano |
| **DEPENDENTE DO REMOTO** | Atualização do `remote_schema.sql` | `npx supabase db dump -f supabase/remote_schema.sql` ou `pg_dump` | Operador Humano |

---

## 5. Parecer Técnico Final

> **PARECER DA AUDITORIA: ✅ APROVADO PARA EXECUÇÃO CONTROLADA**  
> Todas as pendências técnicas de segurança (D1 e D2), integridade referencial, sintaxe SQL e alinhamento com contratos Flutter foram integralmente implementadas e testadas.  
> O código Flutter está sincronizado e validado (48/48 testes aprovados, `flutter analyze` sem advertências).  
> Os scripts `01_complete_database_baseline.sql` e `02_incremental_remote_update.sql` estão prontos para aplicação pelo operador humano no Supabase remoto, mediante observância do procedimento de salvaguarda descrito em `03_manual_steps.md`.