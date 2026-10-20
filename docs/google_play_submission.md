# PeleIA — Conteúdo para o Google Play Console

## Informações Básicas

**Nome do app:** PeleIA — Skincare com IA
**ID do pacote:** com.peleia.app
**Categoria:** Saúde e bem-estar
**Classificação etária:** Livre (para todos)
**País de lançamento:** Brasil (prioridade), depois LatAm

---

## Título (máx. 30 caracteres)

```
PeleIA: Skincare com IA
```

## Descrição Curta (máx. 80 caracteres)

```
Diagnóstico de pele por IA. Rotina personalizada para o clima BR 🇧🇷
```

## Descrição Completa (máx. 4000 caracteres)

```
✨ PeleIA — A primeira IA de skincare pensada para a pele e o clima brasileiro.

🔬 COMO FUNCIONA
Tire uma selfie e nossa IA analisa sua pele em 30 segundos. Você recebe um diagnóstico completo com scores de oleosidade, acne, manchas solares e hidratação — tudo em português do Brasil, sem termos médicos complicados.

☀️ FEITO PARA O BRASIL
O Brasil tem um dos índices UV mais altos do mundo. Nossa IA leva em conta o calor, a umidade e a exposição solar da sua região para criar uma rotina de skincare que realmente funciona no nosso clima.

📊 O QUE A IA ANALISA
• 🛢️ Oleosidade e brilho excessivo
• 😤 Acne ativa e cravos
• ☀️ Manchas solares e melasma
• 💧 Nível de hidratação
• ⭕ Poros dilatados
• 🔴 Sensibilidade e vermelhidão

🌅 SUA ROTINA PERSONALIZADA
Receba uma rotina de manhã e noite com ingredientes ativos específicos para os seus problemas: ácido salicílico, niacinamida, vitamina C, retinol e mais — explicados de forma simples.

🛍️ PRODUTOS ACESSÍVEIS
Recomendamos marcas que as brasileiras amam e confiam:
• Principia (Salifast, Vitamina C)
• Sallve (Niacinamida 10%)
• CeraVe e La Roche-Posay
• Episol, Sundown e outros protetores solares

Com links diretos para Shopee Brasil, Mercado Livre e Amazon Brasil.

💎 PREMIUM — 3 DIAS GRÁTIS
• Análises ilimitadas (até 5 por dia)
• Acompanhamento semanal da evolução da sua pele
• Alertas UV em tempo real por cidade
• Relatório PDF para levar ao dermatologista
• Rotina adaptada às estações (verão e inverno brasileiros)

Planos a partir de R$ 9,90/semana. Cancele quando quiser pelo Google Play.

🔒 PRIVACIDADE
Suas fotos são processadas pela IA e descartadas imediatamente. Nenhuma imagem é salva em nossos servidores. Consulte nossa Política de Privacidade.

Disponível para Android — otimizado para todos os tipos de pele brasileira.
```

---

## Keywords (para ASO — App Store Optimization)

```
skincare brasil, cuidados com a pele, rotina de skincare, análise de pele, 
pele oleosa, acne, manchas solares, protetor solar, niacinamida, ácido salicílico,
inteligência artificial pele, diagnóstico de pele, rotina beauty, Principia, 
Sallve, pele mista, pele seca, melasma, cravos
```

---

## Classificação de Conteúdo (Questionário IARC)

| Categoria | Resposta |
|-----------|---------|
| Violência | Não |
| Linguagem | Não |
| Conteúdo sexual | Não |
| Drogas | Não |
| Compras no app | **Sim** (assinaturas) |
| Localização | Não |
| Câmera/Microfone | **Sim** (câmera para selfie) |

→ Classificação esperada: **Livre (L)**

---

## Política de Privacidade

Você **precisa** de uma URL de Política de Privacidade para publicar.

### Opção rápida: usar Termly (grátis)
1. Acesse [termly.io](https://termly.io)
2. Crie conta grátis → "Privacy Policy"
3. Preencha: nome do app = PeleIA, coleta câmera = sim, pagamentos = sim
4. Copie o link gerado → cole no Play Console

### Template básico do texto:
```
PeleIA coleta imagens de rosto para análise por IA. 
As imagens são processadas e descartadas imediatamente — não são armazenadas. 
Dados de assinatura são processados pelo Google Play Billing. 
Não vendemos dados a terceiros.
Contato: privacidade@peleia.com.br
```

---

## Screenshots necessárias (mínimo 2, ideal 8)

### Tamanhos para telefone Android:
- **Retrato:** 1080 x 1920 px (ou 1080 x 2280)
- **Formato:** JPG ou PNG, máx 8MB cada

### O que capturar (em ordem de impacto):

| # | Tela | Mensagem chave |
|---|------|----------------|
| 1 | Scan em progresso | "IA analisando sua pele" |
| 2 | Resultado com scores | "Diagnóstico completo em 30s" |
| 3 | Rotina personalizada | "Manhã e noite adaptados para você" |
| 4 | Produtos recomendados | "A partir de R$ 35" |
| 5 | Onboarding página 1 | "Feito para o Brasil" |
| 6 | Quiz de tipo de pele | "Descubra seu tipo de pele" |
| 7 | Paywall | "3 dias grátis" |
| 8 | Tela de sucesso Premium | "Bem-vinda ao Premium" |

### Como capturar com emulador:
```bash
# Tira screenshot do emulador
adb exec-out screencap -p > screenshot_01.png
```

---

## Ícone do App

**Especificações:**
- Tamanho: **512 x 512 px**
- Formato: PNG 32-bit (com alpha)
- Design: fundo gradiente terracota (#C8714A → #E8A44A) + emoji ✨ centralizado
- Sem texto (o nome aparece abaixo no Play)

**Ferramenta rápida:** [appicon.co](https://appicon.co) — gera todos os tamanhos de mipmap automaticamente.

---

## Ficha de Dados de Segurança (obrigatória desde 2022)

No Play Console → Segurança dos dados, declare:

| Dado | Coletado? | Compartilhado? | Finalidade |
|------|-----------|----------------|------------|
| Fotos | Sim | Não | Análise de pele pela IA |
| Dados de compra | Sim | Google Play | Assinatura Premium |
| Identificador do app | Sim | Não | Funcionalidade |

---

## Requisitos do Google Play (novos em 2023-2024)

### ⚠️ 20 testadores por 14 dias (OBRIGATÓRIO para novos devs)

Antes de publicar abertamente, o Google exige:

1. Ir em: **Play Console → Teste → Teste interno**
2. Criar uma versão de teste
3. Adicionar **mínimo 20 e-mails** de testadores
4. Eles precisam:
   - Aceitar o convite (link enviado por e-mail)
   - **Instalar e usar** o app por pelo menos 14 dias corridos
5. Após 14 dias, você pode solicitar acesso à produção

### Como conseguir os 20 testadores no Brasil:
- WhatsApp de amigas/colegas que topam testar
- Grupos de skincare no Facebook/Reddit
- Comunidade de devs brasileiros (grupos Flutter BR)
- Postar no seu Instagram pedindo voluntárias

---

## Checklist Final Antes de Publicar

- [ ] `flutter build appbundle --release` funcionando
- [ ] Keystore gerado e salvo com segurança
- [ ] `key.properties` configurado (e no `.gitignore`)
- [ ] ApplicationId único: `com.peleia.app`
- [ ] Conta Google Play ($25 paga)
- [ ] Política de Privacidade com URL pública
- [ ] Ícone 512x512 pronto
- [ ] Mínimo 2 screenshots (ideal 8)
- [ ] Ficha de segurança preenchida
- [ ] 20 testadores confirmados para o closed test
- [ ] RevenueCat conectado ao Google Play (produtos cadastrados)
- [ ] `.env` com `GEMINI_API_KEY` real (não de desenvolvimento)
