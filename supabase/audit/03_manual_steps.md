# Procedimentos Manuais de Sincronização e Validação — Supabase (Orelhinhas)

> **MANUAL DE EXECUÇÃO E CONTINGÊNCIA — LEITURA OBRIGATÓRIA:**  
> A execução manual deste procedimento no Supabase remoto deve ser realizada em estrita conformidade com os scripts auditados (`01_complete_database_baseline.sql` e `02_incremental_remote_update.sql`) e após a assinatura formal de liberação técnica descrita no checklist de controle (`05_pre_execution_checklist.md`).  
> Este documento orienta o operador humano no fluxo de salvaguarda, execução atômica, verificação de Storage, bateria de inspeção SQL e alinhamento de ambiente local.

---

## 1. Visão Geral do Fluxo de Execução

```
[Etapa 1: Salvaguarda e Backup Integral Verificável] 
       │
       ▼
[Etapa 2: Aplicação do Script Incremental (02) no SQL Editor]
       │
       ▼
[Etapa 3: Verificação Estrutural de Storage e Políticas de Objetos]
       │
       ▼
[Etapa 4: Bateria de Inspeção SQL Aprofundada Pós-Aplicação]
       │
       ▼
[Etapa 5: Alinhamento Criterioso do Histórico de Migrations e Dumps]
       │
       ▼
[Etapa 6: Validação de Regressão e Testes no Ambiente Flutter]
```

---

## 2. Passo a Passo Detalhado

### Etapa 1: Salvaguarda e Backup Integral Verificável

* **Onde realizar:** Painel Web do Supabase (`https://supabase.com/dashboard/project/<PROJECT_REF>`) ou Terminal Local.
* **Compreensão Técnica sobre Tipos de Backup:**
  - **Atenção:** Um dump realizado exclusivamente com `--data-only` **não é um backup integral do banco de dados**. Ele exporta apenas registros de tabelas (instruções DML `INSERT`), ignorando o esquema estrutural (DDL), definições de tabelas, chaves estrangeiras com `CASCADE`, tipos de dados (incluindo a extensão `vector`), funções PL/pgSQL com `SECURITY DEFINER`, triggers de automação, índices vetoriais HNSW, políticas de RLS e configurações do schema `storage`.
  - Um backup aceitável para mitigar riscos de migração precisa contemplar:
    1. **Esquema estrutural (DDL):** Tabelas, colunas, tipos, constraints e índices.
    2. **Dados tabulares (DML):** Registros existentes em todas as tabelas públicas e de autenticação.
    3. **Lógica de banco e segurança:** Funções `SECURITY DEFINER`, triggers e políticas completas de RLS.
    4. **Metadados de Storage:** Configuração de buckets (`storage.buckets`) e políticas de acesso (`storage.objects`).
* **Procedimento Operacional:**
  1. **Plano Pro / Team do Supabase:**
     - Acesse **Database** > **Backups**.
     - Clique em **Take a backup now** e aguarde a confirmação de conclusão do snapshot físico gerenciado.
  2. **Plano Free (Gratuito) ou Backup Manual por CLI:**
     - O plano gratuito não disponibiliza botão de snapshot sob demanda no painel web.
     - Realize a salvaguarda via terminal local ou ferramenta de conexão PostgreSQL direta (`pg_dump`):
       ```powershell
       # 1. Exportação do esquema estrutural completo (DDL)
       npx supabase db dump -f supabase/backup_pre_update_schema.sql

       # 2. Exportação de dados existentes (DML)
       npx supabase db dump --data-only -f supabase/backup_pre_update_data.sql
       ```
     - Alternativa via Painel Web: exportar individualmente os arquivos CSV de cada tabela do schema `public` via **Table Editor** > **Export to CSV**.
* **Critério de conclusão:** Arquivos de backup gerados, não vazios e verificados antes de qualquer modificação no banco de dados.

---

### Etapa 2: Aplicação do Script Incremental no SQL Editor

* **Onde realizar:** Painel Web do Supabase > **SQL Editor** (`https://supabase.com/dashboard/project/<PROJECT_REF>/sql/new`).
* **Realidade Técnica sobre Transações e Rollback:**
  - O script `02_incremental_remote_update.sql` está estruturado em um bloco `BEGIN; ... COMMIT;`.
  - **Ressalva importante sobre rollback:** A presença de `BEGIN; ... COMMIT;` **não garante rollback total em qualquer circunstância**. A atomicidade depende estritamente de:
    - O cliente SQL ou navegador despachar todo o conteúdo como uma única instrução atômica contínua. Se o cliente dividir o script em blocos (batches) ou se houver queda de conexão entre declarações, a sessão pode ser interrompida em estado intermediário.
    - Determinadas operações DDL no PostgreSQL ou manipulações em esquemas gerenciados (como `storage`) podem apresentar comportamentos específicos de catálogo.
    - Se ocorrer um erro durante a execução, o operador deve certificar-se de emitir explicitamente um `ROLLBACK;` caso o cliente SQL não tenha abortado a transação automaticamente.
* **Principais Correções e Ações Executadas pelo Script:**
  1. **Preservação de Matches Existentes:** Adiciona a coluna `origin` na tabela `matches` com default `'manual'`, mantendo registros antigos como `'manual'` (sem disparos retroativos indevidos de notificação).
  2. **Integridade Referencial:** Remove correspondências órfãs (via `NOT EXISTS` para tratamento correto de NULLs) e adiciona chaves estrangeiras `fk_matches_lost_pet` e `fk_matches_found_pet` com `ON DELETE CASCADE`. A verificação das constraints usa `conrelid = 'public.matches'::regclass` para evitar falso positivo com constraints homônimas em outros schemas.
  3. **Deduplicação Determinística:** Prioriza registros com embeddings SigLIP válidos de 768 dimensões e data recente antes de criar a constraint `uq_pet_images_pet_url`.
  4. **Índices HNSW:** Cria índices vetoriais de cosseno (`vector_cosine_ops`) em `pet_visual_profiles` e `pet_images`.
  5. **RPCs Vetoriais Blindadas:**
     - `match_found_pets_for_lost` e `match_lost_pets_for_found` configuradas com `SET search_path = ''` e referências totalmente qualificadas.
     - **Eliminação de fallback de vetores do cliente:** O embedding de busca é recuperado **exclusivamente** de `public.pet_visual_profiles` para o animal do usuário autenticado.
     - Validação estrita de espécie no perfil e no alerta candidato, exigindo status `'active'`.
     - Utilização da sintaxe canônica do PostgreSQL para operadores qualificados: `OPERATOR(public.<=>)`.
  6. **Funções de Autenticação Seguras:**
     - `is_email_locked` e `register_login_attempt` configuradas com `SET search_path = ''`.
     - `register_login_attempt` sanitiza e-mails, valida existência em `auth.users`, restringe resets a usuários autenticados e bloqueia após 3 falhas consecutivas (`INTERVAL '15 minutes'`).
     - Uso de construções padrão ANSI SQL: `EXTRACT(epoch FROM ...)` e `COALESCE(...)`.
  7. **Saneamento e Proteção de Embeddings via RLS:**
     - Remoção da política pública permissiva em `profiles`.
     - `pet_images`: leitura e mutação restritas ao proprietário do animal (`pet_images_select_owner`), impedindo que terceiros baixem vetores brutos via API.
     - `pet_visual_profiles`: leitura permitida a **todos os usuários autenticados** (trade-off deliberado — o pipeline de matching do Flutter lê perfis de outros usuários legitimamente via `getVisualProfile` e `getVisualProfilesByIds`; restringir ao dono quebraria o reconhecimento visual); mutação restrita ao titular.
     - `matches`: leitura restrita exclusivamente aos proprietários envolvidos no par (`matches_select_involved_owner`); inserção e atualização restritas a quem possui ao menos um dos animais do par (`matches_insert_owner` e `matches_update_owner`). **Risco residual documentado:** a política INSERT com OR permite que o dono de um `lost_pet` associe-o a qualquer `found_pet_id` válido. Mitigação futura recomendada: mover `saveMatch` para RPC `SECURITY DEFINER`.
     - `notifications`: remoção da política de inserção direta por clientes (mitigação de spoofing).
     - Revogação explícita de qualquer acesso anônimo (`anon`) às tabelas de embeddings.
  8. **Storage Defensivo:** Preserva buckets existentes com `ON CONFLICT (id) DO NOTHING` e define políticas RLS por pasta (`<userId>/...`).
* **Critério de conclusão:** Execução do script sem mensagens de erro e exibição de:  
  `>>> [ORELINHAS] Script incremental concluído com sucesso e consolidado no banco remoto!`

---

### Etapa 3: Verificação Estrutural de Storage e Políticas de Objetos

* **Onde realizar:** Painel Web do Supabase > **Storage** (`https://supabase.com/dashboard/project/<PROJECT_REF>/storage/buckets`).
* **Critérios de Validação em Storage:**
  - A simples confirmação de que os buckets constam na listagem **não é suficiente**.
  - O operador deve verificar:
    1. **Decisão Arquitetural de Visibilidade:** Os buckets `pet_images` e `avatars` possuem leitura pública via `storage_pet_images_select_public` para permitir a exibição direta de imagens no aplicativo Flutter através do método `getPublicUrl` (cards, feeds e avatares), sem sobrecarga de tokens temporários.
    2. **Caminhos Reais de Upload:** O aplicativo Flutter grava arquivos no padrão `<bucket>/<userId>/<timestamp>.<ext>`.
    3. **Diferenciação Estrita de Ações:**
       - **SELECT (Leitura):** Pública para os buckets de imagens do aplicativo.
       - **INSERT (Upload):** Exige autenticação (`auth.role() = 'authenticated'`), validação de pasta (`auth.uid()::text = (storage.foldername(name))[1]`) e restrição de extensões/MIME (`jpg`, `jpeg`, `png`, `webp`).
       - **UPDATE e DELETE (Modificação e Remoção):** Restritos unicamente ao proprietário da pasta correspondente.
    4. **Limpeza de Políticas Antigas:** Assegurar que nenhuma política antiga (com ou sem acentuação) tenha permanecido ativa em `storage.objects`.
* **Critério de conclusão:** Políticas de Storage ativas e conformes com a convenção de pastas do aplicativo.

---

### Etapa 4: Bateria de Inspeção SQL Aprofundada Pós-Aplicação

* **Onde realizar:** Supabase SQL Editor.
* **Diretriz de Validação:** Não utilize consultas que apenas confirmem a existência de um nome. Inspecione a **definição real e a configuração efetiva** de cada objeto.

Execute os blocos de consulta abaixo:

```sql
-- 1. Inspeciona a definição exata das constraints e suas tabelas vinculadas
SELECT 
    c.conrelid::regclass AS table_name,
    c.conname AS constraint_name,
    c.contype AS constraint_type,
    pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'public' 
  AND c.conname IN ('uq_matches_pair', 'fk_matches_lost_pet', 'fk_matches_found_pet', 'uq_pet_images_pet_url')
ORDER BY table_name, constraint_name;

-- 2. Inspeciona índices HNSW, colunas indexadas, classes de operadores e parâmetros
SELECT 
    t.relname AS table_name,
    i.relname AS index_name,
    a.amname AS access_method,
    pg_get_indexdef(i.oid) AS index_definition
FROM pg_index x
JOIN pg_class i ON i.oid = x.indexrelid
JOIN pg_class t ON t.oid = x.indrelid
JOIN pg_am a ON a.oid = i.relam
WHERE a.amname = 'hnsw' 
  AND t.relname IN ('pet_visual_profiles', 'pet_images')
ORDER BY table_name, index_name;

-- 3. Inspeciona assinaturas, SECURITY DEFINER e search_path configurado das funções
SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.prosecdef AS is_security_definer,
    p.proconfig AS runtime_configurations
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('match_found_pets_for_lost', 'match_lost_pets_for_found', 'is_email_locked', 'register_login_attempt', 'delete_own_user')
ORDER BY function_name;

-- 4. Inspeciona privilégios de execução efetivos concedidos por papel
SELECT 
    routine_name, 
    grantee, 
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN ('match_found_pets_for_lost', 'match_lost_pets_for_found', 'delete_own_user', 'is_email_locked', 'register_login_attempt')
ORDER BY routine_name, grantee;

-- 5. Inspeciona detalhadamente as políticas RLS (papéis, comandos, expressões USING e WITH CHECK)
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual AS using_expression, 
    with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'pet_images', 'pet_visual_profiles', 'matches', 'notifications')
ORDER BY tablename, policyname;

-- 6. Inspeciona políticas ativas no schema storage
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual AS using_expression, 
    with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
ORDER BY policyname;

-- 7. Inspeciona a definição da trigger, tabela alvo, temporização e eventos que a disparam
SELECT 
    event_object_table, 
    trigger_name, 
    action_timing, 
    event_manipulation, 
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN ('trg_notify_on_match', 'on_auth_user_created', 'on_profiles_updated', 'on_pet_lost_alerts_updated')
ORDER BY event_object_table, trigger_name;
```

* **Resultados esperados:**
  1. `fk_matches_*` presentes com cláusula `ON DELETE CASCADE`. Constraint `uq_pet_images_pet_url` única presente. **Ambas devem ter `conrelid = public.matches` / `public.pet_images` respectivamente** (verificado pelo JOIN com schema no SQL de inspeção).
  2. Índices HNSW ativos com `vector_cosine_ops`.
  3. Funções críticas com `runtime_configurations = '{search_path=}'` e `is_security_definer = true`.
  4. Nenhuma permissão de execução concedida a `anon` ou `PUBLIC` em `match_*` e `delete_own_user`.
  5. Políticas RLS ativas: `pet_images_select_owner` impedindo leitura pública de vetores; `profiles` com acesso restrito ao próprio ID; `notifications` sem política de INSERT de cliente; `matches_select_involved_owner` restringindo SELECT ao dono de `lost_pet_id` OU `found_pet_id`; `pet_visual_profiles_select_authenticated` com `USING (true)` — **comportamento esperado e documentado como trade-off arquitetural do pipeline de matching**.
  6. Trigger `trg_notify_on_match` vinculada a `matches` em eventos de `INSERT` e `UPDATE`.

---

### Etapa 5: Alinhamento Criterioso do Histórico de Migrations e Dumps

* **Onde realizar:** Terminal local na pasta raiz do projeto (`C:\Users\mbdcc\.gemini\antigravity\scratch\orelinhas`).
* **Conceito sobre Dashboard vs Histórico de Migrations:**
  - A execução manual de comandos SQL diretamente no **Supabase SQL Editor não grava registros na tabela de migrações (`supabase_migrations.schema_migrations`)**.
* **Procedimento de Sincronização:**
  1. **Confrontação Analítica:**
     - Verifique o histórico de migrações:
       ```powershell
       npx supabase migration list
       ```
     - Compare os arquivos locais em `supabase/migrations/` com o que foi executado no banco remoto.
     - **Atenção:** **Não utilize `npx supabase migration repair` de forma indiscriminada**. O uso precipitado desse comando força o registro de migrações sem garantir que o banco possua o estado exato, podendo mascarar divergências.
  2. **Atualização do dump (`remote_schema.sql`):**
     - A geração de dump pelo Supabase CLI (`npx supabase db dump`) depende de ferramentas de conteinerização locais (**Docker** ou **Podman**).
     - **Se o ambiente local não possuir Docker/Podman ativo:** O comando `npx supabase db dump` falhará. Nesse caso, documente formalmente a limitação de infraestrutura e realize o dump via `pg_dump` direto contra a connection string do banco.
     - Caso o ambiente conte com Docker funcional:
       ```powershell
       npx supabase db dump -f supabase/remote_schema.sql
       ```
       E confirme a sincronia com `git diff supabase/remote_schema.sql`.

---

### Etapa 6: Validação de Regressão e Testes no Ambiente Flutter

* **Onde realizar:** Terminal local na pasta raiz do projeto (`C:\Users\mbdcc\.gemini\antigravity\scratch\orelinhas`).
* **Distinção entre Testes Unitários e de Integração:**
  - **Testes Unitários de Reconhecimento:** Avaliam cálculos matemáticos vetoriais em Dart, modelos de entidades e regras de pipeline com mocks locais. Rodam localmente sem tocar na rede externa.
  - **Testes de Integração:** Exercitam o ciclo completo com rede, PostgREST, RPCs e Storage.
* **Procedimento de Execução:**
  1. **Execução da Suíte de Testes:**
     - Execute obrigatoriamente a partir do diretório raiz onde reside o `pubspec.yaml`:
       ```powershell
       Set-Location "C:\Users\mbdcc\.gemini\antigravity\scratch\orelinhas"
       flutter test test/pet_recognition_test.dart
       ```
     - A execução deve concluir com código de saída 0 e exibir `All tests passed!`.
  2. **Análise Estática do Projeto:**
     - Execute a verificação estática do Dart:
       ```powershell
       Set-Location "C:\Users\mbdcc\.gemini\antigravity\scratch\orelinhas"
       flutter analyze --no-pub
       ```
     - Exigência de conclusão: `No issues found!`.

---

## 3. Matriz de Classificação de Ações e Bloqueios

| Ação | Onde Executar | Classificação | Condição de Bloqueio / Atenção |
| :--- | :--- | :--- | :--- |
| **Backup Integral do Banco** | Painel / CLI | **Pré-Requisito Crítico** | Bloqueia a execução se não houver salvaguarda verificável |
| **Executar `02_incremental_remote_update.sql`** | SQL Editor Supabase | **Ação Operacional** | Executar somente após checklist assinado |
| **Validar Políticas de Storage** | Painel Storage | **Obrigatória pós-script** | Exige conferência dos caminhos reais do Flutter |
| **Bateria SQL de Inspeção (Etapa 4)** | SQL Editor Supabase | **Obrigatória pós-script** | Inspeciona definições completas de objetos e search_path |
| **Atualização do `remote_schema.sql`** | Terminal Local | **Condicional à Infraestrutura** | Depende de Docker/Podman ativo no ambiente local |
| **Testes Unitários e Análise Flutter** | Terminal Local | **Obrigatória** | Exige execução no diretório raiz com código de saída 0 |
