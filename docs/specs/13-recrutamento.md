# 13. Fase 1: Recrutamento (recruiting)

Pasta: `force-app/recruiting`. Depende da Fase 0. Branch: `feat/recruiting`.

## Histórias

1. Como recrutador, crio e publico vagas, cadastro candidatos e movo candidaturas pelo funil.
2. Como recrutador, vejo um kanban por vaga com as candidaturas por etapa e arrasto entre etapas.
3. Como gestor contratante, vejo as candidaturas das minhas vagas, dou nota e movo entre etapas de
   entrevista.
4. Como RH, os dados de candidatos não contratados são anonimizados depois do prazo de retenção (LGPD).

## Regras

- C1. Etapas e transições vêm de `Recruiting_Stage__mdt`. Transições padrão:
  Nova → Triagem, Reprovado, Desistiu; Triagem → Entrevista_RH, Reprovado, Desistiu;
  Entrevista_RH → Entrevista_Tecnica, Reprovado, Desistiu; Entrevista_Tecnica → Proposta, Reprovado,
  Desistiu; Proposta → Contratado, Reprovado, Desistiu. Contratado, Reprovado e Desistiu são terminais.
  Transição fora da lista: "Mudança de etapa não permitida: de X para Y."
- C2. Reprovado exige `Rejection_Reason__c`. Entrevista_Tecnica → Proposta exige `Score__c`.
- C3. Toda mudança de etapa cria `Application_Stage_History__c` com dias na etapa anterior e atualiza
  `Stage_Entered_Date__c` e `Candidate__c.Last_Activity_Date__c`.
- C4. Candidato único por `Email_Normalized__c` (minúsculo, sem espaços). Ao cadastrar com e-mail
  existente, reaproveita o candidato (serviço `CandidateService.upsertByEmail`).
- C5. Candidatura única por candidato e vaga (`Unique_Key__c`). Erro: "Este candidato já se inscreveu nesta vaga."
- C6. Só vagas Aberta aceitam candidatura nova. Ao fechar a vaga (Fechada ou Cancelada), candidaturas não
  terminais viram Reprovado com motivo Outro e histórico "Vaga encerrada".
- C7. `Public_Slug__c` gerado do título: minúsculo, sem acento, hifens, sufixo numérico se repetido.
- C8. `Applications_Count__c` mantido no insert, delete e undelete de candidatura.
- C9. Compartilhamento com o gestor contratante (spec 02) via `RecruitingSharingService`; ao mudar o
  `Hiring_Manager__c` da vaga, refazer os shares de todas as candidaturas.
- C10. A mudança para Contratado chama `JobApplicationService.onHired(Set<Id> applicationIds)`. A criação
  do colaborador é do módulo onboarding (spec 15): o recrutamento declara a interface
  `HiredApplicationHandler` (`void handle(Set<Id> applicationIds)`) e resolve a implementação com
  `Type.forName('OnboardingHiredHandler')`. Se a classe não existir, só registra em debug; o
  recrutamento funciona sozinho.
- C11. LGPD: `CandidateRetentionBatch` (semanal) anonimiza candidatos sem candidatura ativa e com
  `Last_Activity_Date__c` mais antiga que `Candidate_Retention_Days__c`: Name = "Candidato anonimizado",
  e-mail = `anon-<Id>@anon.invalid`, Email_Normalized__c igual, telefone, LinkedIn e cidade vazios,
  Cover_Letter__c das candidaturas vazio, Anonymized__c = true. Nunca anonimizar candidato contratado.

## Componentes

Apex: `JobOpeningService`, `JobOpeningSelector`, `JobOpeningTriggerHandler` + trigger,
`CandidateService`, `CandidateSelector`, `CandidateTriggerHandler` + trigger, `JobApplicationService`,
`JobApplicationSelector`, `JobApplicationTriggerHandler` + trigger, `RecruitingStageConfig`,
`RecruitingSharingService`, `RecruitingKanbanController`, `CandidateRetentionBatch` (+ Schedulable),
`HiredApplicationHandler` (interface), testes.

LWC:
- `recruitingKanban`: seletor de vaga, colunas por etapa (ordem do CMDT, cor), cartões com nome, nota e
  dias na etapa; arrastar e soltar com validação da transição no servidor (C1, C2) e modal para motivo
  ou nota quando exigido; versão acessível sem arrastar (menu "Mover para").
- `recruitingApplicationPanel`: na página da candidatura, histórico de etapas em linha do tempo.
- `recruitingOpeningSummary`: na página da vaga, contagem por etapa e tempo médio por etapa.

## Critérios de aceite

- [ ] Transições válidas e inválidas, C2, C4, C5, C6 e C11 testados (positivo e negativo).
- [ ] Lote de 200 candidaturas mudando de etapa.
- [ ] Segurança: gestor contratante vê só candidaturas das próprias vagas; colaborador comum não vê
      candidato nenhum.
- [ ] Jest para os 3 LWCs (incluindo erro do servidor ao mover).
- [ ] Gates da spec 03.
