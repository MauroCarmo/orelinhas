# Checklist Pré-Execução e Validação Técnica de Conformidade — Orelhinhas

**Branch:** `mauro`  
**Data:** 10–11 de Novembro de 2026  
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
| **CONCLUÍDO** | Blindagem das RPCs Vetoriais | Remoção de fallback de embedding do cliente; uso exclusivo de vetor oficial de `pet_visual_profiles` | `match_found_pets_for_lost` e `match_lost_pets_for_found` |
| **CONCLUÍDO** | Sintaxe PostgreSQL — Operador Vetorial | `public.<=>` substituído por `OPERATOR(public.<=>)` em todas as RPCs com `search_path = ''` | Parser do PostgreSQL exige esta forma canônica |
| **CONCLUÍDO** | Sintaxe PostgreSQL — COALESCE / EXTRACT / INTERVAL | `pg_catalog.coalesce`, `pg_catalog.extract`, `pg_catalog.interval` substituídos por construções ANSI SQL padrão | `COALESCE(...)`, `EXTRACT(epoch FROM ...)`, `INTERVAL '15 minutes'` |
| **CONCLUÍDO** | Validação Dupla de Espécie | Validação da espécie de origem e da espécie candidata no perfil e no alerta (`dog`/`cat`) | Isolamento estrito entre caninos e felinos |
| **CONCLUÍDO** | Filtro de Status Ativo nas RPCs | Participação restrita a alertas onde `status = 'active'` | Alertas inativos ou resolvidos desconsiderados |
| **CONCLUÍDO** | Endurecimento `SECURITY DEFINER` | `SET search_path = ''` em todas as funções privilegiadas com qualificação explícita de schema | Previne sequestro de search path temporário |
| **CONCLUÍDO** | Permissões Explícitas de Execução | Revogação de `anon` e `PUBLIC`; concessão com assinaturas explícitas de tipos | `REVOKE ... FROM PUBLIC, anon; GRANT ... TO authenticated` |
| **CONCLUÍDO** | Proteção contra Abuso no Login | `register_login_attempt` bloqueia resets anônimos, valida existência em `auth.users`, trava em 3 falhas | Sincronizado com `auth_controller.dart` (bloqueio em 15 min) |
| **CONCLUÍDO** | Sanitização de E-mails | `LOWER(TRIM(user_email))` em `is_email_locked` e `register_login_attempt` | Previne falhas por caixa ou espaços no login |
| **CONCLUÍDO** | `is_email_locked` — Comportamento seguro | Retorna `false` para e-mails inexistentes sem leakage de existência da conta | Comportamento seguro por design |
| **CONCLUÍDO** | Proteção de Embeddings em `pet_images` | SELECT restrito ao titular do animal via `pet_images_select_owner` | Terceiros não podem baixar vetores brutos individuais via API |
| **CONCLUÍDO** | `anon` revogado em tabelas de embedding | `REVOKE ALL ON pet_images FROM anon` e `REVOKE ALL ON pet_visual_profiles FROM anon` | Acesso não autenticado bloqueado para tabelas vetoriais |
| **CONCLUÍDO** | `matches` SELECT — Privacidade | `matches_select_involved_owner` restringe SELECT a quem é dono de `lost_pet_id` OU `found_pet_id` | Terceiros não leem correspondências alheias |
| **CONCLUÍDO** | `matches` INSERT/UPDATE — Titularidade | `matches_insert_owner` e `matches_update_owner` exigem propriedade de ao menos um animal do par | Risco residual documentado em D2 do `04_final_audit_report.md` |
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
| **VALIDADO** | Análise Estática do Flutter | 0 erros, 0 avisos | `flutter analyze --no-pub` → `No issues found! (ran in 12.5s)` |
| **VALIDADO** | Bateria de Testes Unitários de IA | 39/39 aprovados (100%) | `flutter test test/pet_recognition_test.dart` → `All tests passed!` |
| **VALIDADO** | Contratos de Assinatura das RPCs | Parâmetros de `callMatchRpc` idênticos aos argumentos SQL | `query_embedding`, `target_pet_type`, `exclude_pet_id`, `similarity_threshold`, `match_limit` |
| **VALIDADO** | Consistência Baseline vs Incremental | Funções, constraints, RLS, índices e políticas produzem estado equivalente | Análise estática comparativa manual |
| **VALIDADO** | Sintaxe SQL — Ausência de erros conhecidos | Grep confirmou ausência de `public.<=>`, `pg_catalog.coalesce`, `pg_catalog.extract`, `pg_catalog.interval` | `Select-String` nos arquivos de auditoria |
| **VALIDADO** | Padrão de Upload no Storage | Flutter usa `{bucket}/{userId}/{timestamp}.{ext}` | Leitura de `storage_service.dart`, `create_pet_lost_screen.dart`, `create_pet_found_screen.dart`, `profile_screen.dart` |
| **VALIDADO** | Extensão `vector` no schema `public` | Confirmado em `remote_schema.sql` linha 48 | `CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public"` |
| **VALIDADO** | Leitura de `pet_images` não realizada para candidatos | O matching lê apenas `pet_visual_profiles` para perfis de candidatos | Nenhuma chamada `from('pet_images')` encontrada nos fluxos de matching |
| **NÃO EXECUTADO** | Execução do SQL no Supabase remoto | — | Fora do escopo desta fase |

---

## 3. Decisões Arquiteturais que Dependem de Aprovação Humana

| Status | Decisão Pendente | Contexto Técnico | Ação Esperada |
| :---: | :--- | :--- | :--- |
| **DECISÃO HUMANA — D1** | `pet_visual_profiles` SELECT USING(true) | O SELECT aberto para autenticados expõe `aggregated_embedding` a qualquer usuário. Necessário para o matching pipeline atual. | Aprovar trade-off atual OU planejar view sem coluna de embedding |
| **DECISÃO HUMANA — D2** | `saveMatch` direto pelo cliente | O Flutter insere em `matches` diretamente, permitindo associação de pets sem validação server-side da origem. | Aprovar trade-off atual OU planejar RPC `save_match_rpc` SECURITY DEFINER |
| **DECISÃO HUMANA** | Visibilidade Pública dos Buckets | Buckets `pet_images` e `avatars` com SELECT público viabilizam `getPublicUrl` nos cards. URLs permanentes expõem imagens a quem tiver o link. | Confirmar aceitabilidade ou migrar para signed URLs |
| **DECISÃO HUMANA** | Validação do Plano de Backup | O método de backup varia conforme plano Free/Pro do Supabase. | Atestar que backup verificável (esquema + dados + policies) está gravado |
| **DECISÃO HUMANA** | Agendamento da Janela de Aplicação | Script DDL incremental deve ser aplicado em horário de baixo tráfego. | Aprovação do cronograma pelo responsável técnico |

---

## 4. Etapas que Só Podem Ser Confirmadas Após Intervenção no Supabase Remoto

| Status | Etapa Remota | Procedimento Obrigatório | Responsável |
| :---: | :--- | :--- | :--- |
| **DEPENDENTE DO REMOTO** | Execução do Script no SQL Editor | Colar e executar `02_incremental_remote_update.sql` completo | Operador Humano |
| **DEPENDENTE DO REMOTO** | Verificação de `origin` em `matches` | Confirmar que coluna `origin` foi adicionada com `DEFAULT 'manual'` | Operador Humano |
| **DEPENDENTE DO REMOTO** | Inspeção SQL Pós-Aplicação | Executar bateria de consultas da Etapa 4 de `03_manual_steps.md` | Operador Humano |
| **DEPENDENTE DO REMOTO** | Validação das Funções com `search_path` | Confirmar `proconfig = '{search_path=}'` via `pg_proc` | Operador Humano |
| **DEPENDENTE DO REMOTO** | Validação no Painel de Storage | Confirmar buckets e políticas ativas; nenhuma política legada remanescente | Operador Humano |
| **DEPENDENTE DO REMOTO** | Atualização do `remote_schema.sql` | `npx supabase db dump -f supabase/remote_schema.sql` ou `pg_dump` | Operador Humano |

---

## 5. Parecer Técnico Final

> **PARECER DA AUDITORIA: ✅ APROVADO COM RESSALVAS**  
> Todos os bloqueios técnicos com solução implementável sem quebrar o Flutter foram corrigidos. Os scripts estão consistentes, sintaticamente válidos e alinhados com o código Flutter.  
> As ressalvas (D1, D2 e riscos residuais) são trade-offs arquiteturais deliberados que requerem decisão humana para evolução futura — não bloqueiam a execução controlada atual.
