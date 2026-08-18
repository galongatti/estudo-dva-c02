#!/usr/bin/env bash
# Executa com seguranca: encerra em erro, falha em variavel indefinida e propaga erro de pipeline.
set -euo pipefail

# Resolve o diretorio raiz do projeto a partir da localizacao deste script.
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Pasta de saida dos artefatos de build.
DIST_DIR="$ROOT_DIR/dist"
# Pasta temporaria onde o pacote e montado antes de compactar.
BUILD_DIR="$DIST_DIR/package"
# Caminho final do zip da Lambda usado pelo Terraform.
ZIP_FILE="$DIST_DIR/function.zip"

# Limpa artefatos anteriores para evitar sobras no novo empacotamento.
rm -rf "$BUILD_DIR" "$ZIP_FILE"
# Cria a pasta temporaria de build.
mkdir -p "$BUILD_DIR"

# Instala dependencias Python dentro da pasta de build para irem no zip da Lambda.
python3 -m pip install -r "$ROOT_DIR/app/requirements.txt" -t "$BUILD_DIR"

# Mantem a mesma estrutura de modulos da aplicacao dentro do pacote.
mkdir -p "$BUILD_DIR/app"
# Copia o handler principal.
cp "$ROOT_DIR/app/index.py" "$BUILD_DIR/app/index.py"
# Copia modulo auxiliar usado pelo handler.
cp "$ROOT_DIR/app/create_order.py" "$BUILD_DIR/app/create_order.py"

# Usa subshell para compactar sem alterar o diretorio atual do script.
(
  cd "$BUILD_DIR"
  # Compacta recursivamente todo o conteudo do build para o zip final.
  zip -r "$ZIP_FILE" .
)

# Informa onde o artefato final foi gerado.
echo "Pacote gerado em: $ZIP_FILE"
