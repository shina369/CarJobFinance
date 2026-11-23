# Assinatura Premium — Design

Data: 2026-11-23 · Plataforma atual: Android (iOS depois) · Status: aguardando aprovação

## Intenção

Hoje o app é 100% gratuito e não tem nenhuma infraestrutura de cobrança. A ideia é
transformar o registro diário (corridas e despesas) numa porta de entrada gratuita e
cobrar por aquilo que cresce em valor conforme o motorista acumula dados: relatórios,
metas anuais, exportação, backup na nuvem e lembretes avançados.

O motorista paga por uma assinatura **anual** (não há plano mensal) cobrada pelo **Google Play** (Play
Billing é obrigatório para conteúdo digital no Android). Não há usuários reais ainda,
então não existe migração nem período de cortesia a tratar.

## Objetivos

- Assinatura recorrente anual (plano único) comprada dentro do app, via Google Play.
- Um único status "premium" por conta, que acompanha o motorista entre aparelhos.
- Travar as áreas premium com um paywall que aparece **só quando o usuário toca** em algo
  premium.
- Proteger no servidor o único recurso que custa dinheiro real: o backup na nuvem.
- Deixar o código pronto para o iOS depois sem refazer a lógica do app.

## Fora do escopo

- Valores de preço, promoções, códigos promocionais, plano vitalício e plano família
  (preços e período de teste são configurados no Play Console e no RevenueCat, não no
  código).
- Compra pela web e qualquer pagamento fora das lojas.
- As funções premium futuras (lucro por km/hora por plataforma, foto de recibo, vários
  veículos). Serão specs próprios.
- Publicação na App Store.

## O que NÃO queremos (anti-objetivos)

- Prender os dados do usuário: quem deixar de pagar continua podendo **restaurar** o
  backup que já existe e continua usando o app normalmente.
- Travar o registro de corridas e despesas, o Dashboard ou a meta mensal simples.
- Paywall na abertura do app, pop-ups repetidos ou qualquer coisa que atrapalhe o uso
  grátis.
- Confiar só no app para proteger o backup (um app adulterado não pode gravar no servidor
  sem assinatura).

## Divisão grátis × premium

| Área | Grátis | Premium |
|---|---|---|
| Corridas e despesas | Ilimitadas, com filtros e ordenação | — |
| Dashboard | Hoje, mês e a meta mensal simples | — |
| Comissão por plataforma, idioma, moeda, tema, plataformas | Sim | — |
| Relatórios (aba Relatórios) | Amostra borrada com chamada para assinar | Semana, mês, ano e período personalizado |
| Exportar CSV e PDF | — | Sim |
| Backup e restauração em arquivo (JSON local) | Sim | — |
| Backup na nuvem (envio automático e manual) | Só **restaurar** o que já existe | Enviar backups |
| Meus objetivos (metas anuais por mês) | — | Sim |
| Lembretes | 1 lembrete, com texto e som padrão | Ilimitados, com mensagem e som personalizados |

Decisão: o backup/restauração em arquivo JSON fica grátis porque é o próprio dado do
usuário saindo do app (portabilidade). CSV/PDF são relatórios elaborados e ficam premium.

## Abordagens consideradas

- **A. RevenueCat (`purchases_flutter`) + status na conta Supabase — escolhida.**
  O RevenueCat conversa com o Google Play, valida a compra e avisa o app e o servidor. Menor
  código, menor risco, iOS depois quase de graça. Custo: depende de um serviço terceiro,
  grátis até certo faturamento mensal e depois cobra uma pequena porcentagem (confirmar os
  valores atuais no site deles antes do lançamento).
- **B. `in_app_purchase` oficial + validação própria (Edge Function).** Sem terceiro nem
  porcentagem, mas exige tratar renovação, reembolso e notificações do Google por conta
  própria. Mais código e mais risco. Migrar para B depois continua possível.
- **C. `in_app_purchase` só no cliente.** Fácil de burlar e não protege o backup no
  servidor. Descartada.

O Google Play cobra comissão da loja sobre as assinaturas (15% hoje; confirmar no Play
Console). O RevenueCat não processa pagamento.

## Arquitetura

```
 Motorista ──toca "Assinar"──▶ App (purchases_flutter) ──▶ Google Play Billing
                                   │                              │
                                   │ CustomerInfo (cache offline) │ recibo
                                   ▼                              ▼
                          EntitlementController            RevenueCat
                          (isPremium, validade)                   │ webhook
                                   │                              ▼
                                   │                  Edge Function revenuecat-webhook
                                   │                              │ service role
                                   ▼                              ▼
                       trava no app (6 pontos)        tabela public.entitlements
                                                                  │
                                                                  ▼
                                              RLS da tabela backups exige premium
```

### App (Flutter)

- **Identidade:** o login do Supabase já é obrigatório antes de qualquer tela, então o
  `app_user_id` do RevenueCat é sempre o `user.id` do Supabase (`Purchases.logIn` no
  login, `logOut` ao sair da conta). A assinatura acompanha a conta em qualquer aparelho.
- **Interface `PurchasesGateway`** (mesmo padrão de `AuthRepository`/`CloudBackupRepository`):
  `customerInfo` (stream), `offerings()`, `purchase(package)`, `restore()`. A implementação
  real usa `purchases_flutter`; os testes usam um fake. Registrada em
  `lib/core/di/injection.dart`/providers como os demais repositórios.
- **`EntitlementController`** (Riverpod, em `lib/presentation/controllers/`): expõe
  `isPremium`, data de renovação/expiração e se vai renovar. Inicializado em `main.dart`
  junto de `sessionProvider`. Sem rede na abertura, usa o último `CustomerInfo` em cache do
  SDK; se não houver nada, trata como não premium.
- **Chave do SDK:** `REVENUECAT_ANDROID_KEY` em `.env`/`.env.example`, lida por `Env`.
- **Override de desenvolvimento:** em build debug, uma variável `.env`
  (`PREMIUM_OVERRIDE=true|false`) força o status, para testar as travas sem comprar.

### Servidor (Supabase)

- **Migração nova:** tabela `public.entitlements` (`user_id uuid pk references auth.users
  on delete cascade`, `is_premium boolean`, `expires_at timestamptz`, `updated_at`).
  RLS: o dono só pode **ler** a própria linha. Ninguém escreve pelo app.
- **Edge Function `revenuecat-webhook`:** recebe os eventos do RevenueCat, confere um
  segredo compartilhado no cabeçalho (guardado nos secrets do Supabase) e faz upsert em
  `entitlements` com a service role. Cobre compra, renovação, cancelamento (continua
  premium até expirar), expiração, problema de cobrança, troca de plano e transferência.
- **Backup protegido:** as políticas de `insert` e `update` de `public.backups` passam a
  exigir uma linha em `entitlements` com `is_premium` e `expires_at > now()`. A política de
  `select` não muda: restaurar continua liberado.
- **Exclusão de conta:** `entitlements` some junto (cascade). A tela de exclusão avisa que
  a assinatura na Play Store precisa ser cancelada pelo próprio usuário.

### Pontos de trava no app

1. **Aba Relatórios** (`reports_page.dart`, rota `/reports`): a aba continua na barra de
   navegação; para quem não é premium a página mostra uma amostra borrada com dados
   fictícios e o botão de assinar.
2. **Meus objetivos** (`/goals`, aberto pelo Dashboard): rota protegida; não premium vai
   para o paywall. A meta mensal simples do Dashboard continua livre.
3. **Exportação** (`ExportTiles` em `export_actions.dart`): CSV e PDF mostram cadeado e
   abrem o paywall. O terceiro item (backup JSON em arquivo) segue livre.
4. **Backup na nuvem** (`backup_page.dart`, `CloudBackupController`): `autoBackupIfDue`,
   `backupNow` e o backup feito ao sair da conta (`SessionController`) só enviam se
   premium; para os outros, ficam silenciosos (sem erro). Restaurar e a oferta de
   restauração no login (`LoginGate.restoreOffer`) continuam liberados. A tela mostra o
   estado e o convite para assinar.
5. **Lembretes** (`reminders_page.dart`, `notification_settings.dart`): grátis permite 1
   lembrete com texto e som padrão. Criar o segundo, ou personalizar mensagem/som, abre o
   paywall. Ao perder o premium, os lembretes extras e as personalizações **ficam salvos
   mas não são agendados** (continua ativo o criado primeiro, o de menor `id`, com texto e
   som padrão); voltam a funcionar se reassinar. O interruptor geral de notificações
   continua grátis.
6. **Configurações:** novo item "Premium" no topo, com status, data de renovação, botão de
   assinar ou de gerenciar assinatura (link para a página de assinaturas do Google Play).

### Paywall

Rota `/paywall` fora do shell (tela cheia, como `/goals`). Conteúdo: lista dos benefícios,
o plano anual vindo das Offerings do RevenueCat (preço do ano, equivalente por mês como
texto de apoio e informação do teste grátis quando houver), botão de assinar, "Restaurar compras" e links
para Termos e Privacidade (páginas já existentes em `legal_page.dart`). Todos os textos novos
entram em `strings.dart` com prefixo `premium.` em **todos** os idiomas do app.

## Decisões minhas (para você conferir)

- Plano único anual (decisão sua) com **7 dias de teste grátis**; preço e teste são
  configurados fora do código e podem mudar sem nova versão.
- Backup/restauração em arquivo JSON grátis (portabilidade de dados).
- Quem perde o premium mantém o direito de restaurar o backup existente.
- No debug, override por `.env` para testar as travas.
- Webhook usa segredo compartilhado no cabeçalho em vez de validar assinatura própria.

## Testes

- `PurchasesGateway` fake: testes unitários do `EntitlementController` (premium, expirado,
  offline com cache, logout).
- Testes de widget: aba Relatórios borrada, tiles de exportação com cadeado, limite de
  lembretes e perda de premium, paywall com os planos.
- `CloudBackupController`: não envia sem premium; restaura sem premium.
- Teste do router: `/goals` redireciona ao paywall para não premium.
- Webhook e RLS: testes da função e uma verificação de que um usuário não premium é
  recusado ao gravar em `backups` e premium é aceito.
- Teste manual de compra no Android com faixa de teste interna e licenciados de teste do
  Play Console (compras só funcionam em build assinado enviado à Play Store).

## Fica para quem constrói

- Configuração externa: criar os produtos de assinatura no Play Console, o projeto no
  RevenueCat (entitlement `premium`, offering com o plano anual), o webhook apontando para
  a Edge Function e as chaves no `.env` e nos secrets do Supabase.
- Detalhe dos eventos do webhook e idempotência (consultar a documentação do RevenueCat).
- Textos finais dos benefícios e da amostra borrada, em cada idioma.
- Escolha do visual do paywall e do cadeado, seguindo o tema atual do app.
