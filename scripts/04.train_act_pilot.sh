#!/usr/bin/env bash
# data/pilot 데이터로 ACT 짧게 훈련 (방향성 확인용 v0.1-pilot)
# 카메라: top, gripper | FPS: 25 | 기본: steps=5000, batch_size=8
#
# 사용법 (프로젝트 루트에서):
#   ./scripts/04.train_act_pilot.sh
#   MODEL_VERSION=v0.1-pilot ./scripts/04.train_act_pilot.sh
#
# 환경변수:
#   DATASET_ROOT  기본: ./data/pilot
#   MODEL_VERSION 있으면 outputs/train/act_pilot_${MODEL_VERSION} 에 저장

set -e
cd "$(dirname "$0")/.."

DATASET_ROOT="${DATASET_ROOT:-./data/pilot}"
REPO_ID="${REPO_ID:-woolim/record_test}"
MODEL_VERSION="${MODEL_VERSION:-v0.1-pilot}"
OUTPUT_DIR="${OUTPUT_DIR:-outputs/train/act_pilot_${MODEL_VERSION}}"
JOB_NAME="${JOB_NAME:-act_pilot_${MODEL_VERSION}}"

echo "Dataset: repo_id=${REPO_ID} root=${DATASET_ROOT}"
echo "Output:  ${OUTPUT_DIR}"
echo ""

lerobot-train \
  --dataset.repo_id="${REPO_ID}" \
  --dataset.root="${DATASET_ROOT}" \
  --policy.type=act \
  --policy.device=mps \
  --policy.push_to_hub=false \
  --output_dir="${OUTPUT_DIR}" \
  --job_name="${JOB_NAME}" \
  --dataset.image_transforms.enable=true \
  --wandb.enable=false \
  --steps=5000 \
  --batch_size=32 \
  "$@"
