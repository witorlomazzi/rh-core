#!/usr/bin/env bash
# RH Core: carga de dados de demonstracao da Vetra Distribuidora (empresa ficticia).
# Projeto demonstrativo, empresa e dados ficticios.
#
# Uso:  scripts/seed-vetra-rh.sh <alias-da-org> [--agendar]
#
# O Apex anonimo aceita no maximo ~32 mil caracteres por script, entao o seed e dividido em fases. Cada fase e
# idempotente (upsert por chave externa ou verificacao previa), logo o conjunto pode rodar quantas vezes quiser.
# Executar a partir da raiz do repositorio, com o admin da org (precisa de HR_Admin e HR_Manager; a etapa
# "permissoes do admin" cuida disso). Com --agendar, agenda tambem os jobs recorrentes (schedule-jobs.apex).
#
# Fases:
#   assign-admin-psg  atribui HR_Admin e HR_Manager ao admin e o coloca no grupo HR_Team
#   0 usuarios        3 usuarios de demonstracao (licenca Salesforce Platform) e suas permissoes
#   1 estrutura       departamentos, cargos, faixas, 40 colaboradores, feriados
#   2 ferias          periodos aquisitivos, faltas, 12 pedidos com etapas, gozo historico
#   3 promocoes       3 promocoes e historico de cargo
#   4 recrutamento    4 vagas, 25 candidatos, 30 candidaturas, contratado (e plano de onboarding, se o modulo existir)
#   5 desempenho      Ciclo 2026 em Avaliacao_Gestor
set -euo pipefail

ORG="${1:?Informe o alias da org: scripts/seed-vetra-rh.sh <alias> [--agendar]}"
SCHEDULE="${2:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apex"

run() {
  local file="$1"
  echo ">> ${file}"
  local out
  if ! out="$(sf apex run --file "${DIR}/${file}" --target-org "${ORG}" 2>&1)"; then
    echo "${out}" | grep -vE "CUMULATIVE|LIMIT_USAGE|Number of|Maximum " | tail -25
    echo "FALHOU em ${file}" >&2
    exit 1
  fi
  if echo "${out}" | grep -qE "^Error \(|Compilation failed|Execution failed"; then
    echo "${out}" | grep -E -A3 "^Error \(" | head -12
    echo "FALHOU em ${file}" >&2
    exit 1
  fi
  echo "${out}" | grep "USER_DEBUG" | sed -E 's/^.*\|DEBUG\|//' || true
}

run assign-admin-psg.apex
run seed-vetra-rh-0-usuarios.apex
run seed-vetra-rh-1-estrutura.apex
run seed-vetra-rh-2-ferias.apex
run seed-vetra-rh-3-promocoes.apex
run seed-vetra-rh-4-recrutamento.apex
run seed-vetra-rh-5-desempenho.apex
if [ "${SCHEDULE}" = "--agendar" ]; then
  run schedule-jobs.apex
fi
echo "Seed concluido em ${ORG}."
