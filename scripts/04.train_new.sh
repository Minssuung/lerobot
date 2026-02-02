#!/usr/bin/env bash
# merge 된 데이터로 ACT 훈련 (05.merge.sh 로 먼저 merge 한 뒤 사용)
# data/ 에서 데이터셋 선택 → 모델 이름 입력 → 훈련
#
# 사용법 (프로젝트 루트에서):
#   ./scripts/04.train.sh
#   (데이터셋 선택 프롬프트 → merge 된 폴더 선택, 모델 이름 입력)
#
# 환경변수로 건너뛰기:
#   REPO_ID / DATASET_ROOT / MODEL_VERSION 지정 시 프롬프트 없이 훈련
#
# 기본: steps=10000, save_freq=5000 (5k·10k 스텝에 체크포인트 저장)
#
# 체크포인트 이어서 훈련: ./scripts/04.train_resume.sh
#
# 종료: Ctrl+C

set -e
cd "$(dirname "$0")/.."

DATA_DIR="${DATA_DIR:-./data}"

# REPO_ID, DATASET_ROOT, MODEL_VERSION 이 모두 있으면 프롬프트 건너뜀
if [[ -z "${REPO_ID:-}" ]] || [[ -z "${DATASET_ROOT:-}" ]] || [[ -z "${MODEL_VERSION:-}" ]]; then
  if [[ ! -d "$DATA_DIR" ]]; then
    echo "Error: $DATA_DIR not found. 먼저 02.record.sh 로 녹화하고 05.merge.sh 로 merge 하세요."
    exit 1
  fi

  # data/ 아래 lerobot 데이터셋 목록
  CANDIDATES=()
  for d in "$DATA_DIR"/*/; do
    [[ -d "$d" ]] && [[ -f "${d}meta/info.json" ]] && CANDIDATES+=("$(basename "$d")")
  done

  if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo "No LeRobot datasets in $DATA_DIR. 02.record.sh 로 녹화 후 05.merge.sh 로 merge 하세요."
    exit 1
  fi

  echo "=== 훈련에 쓸 데이터셋 선택 (merge 된 폴더 선택) ==="
  for i in "${!CANDIDATES[@]}"; do
    echo "  $((i + 1))) ${CANDIDATES[$i]}"
  done
  echo ""
  echo -n "데이터셋 번호: "
  read -r NUM
  if [[ ! "$NUM" =~ ^[0-9]+$ ]] || [[ "$NUM" -lt 1 ]] || [[ "$NUM" -gt ${#CANDIDATES[@]} ]]; then
    echo "Error: 잘못된 번호."
    exit 1
  fi
  SELECTED_FOLDER="${CANDIDATES[$((NUM - 1))]}"
  DATASET_ROOT="./data/${SELECTED_FOLDER}"
  REPO_ID="woolim/${SELECTED_FOLDER}"

  echo ""
  echo -n "모델 이름 (예: v0.1-pilot, act_bun_basket. 비우면 act_pilot_default): "
  read -r MODEL_VERSION
  MODEL_VERSION="${MODEL_VERSION:-act_pilot_default}"
fi

MODEL_VERSION="${MODEL_VERSION:-act}"
OUTPUT_DIR="${OUTPUT_DIR:-outputs/train/${MODEL_VERSION}}"
JOB_NAME="${JOB_NAME:-act_pilot_${MODEL_VERSION}}"

# macOS → mps, Ubuntu/Linux → cuda (conda 환경에서 GPU 사용)
if [[ "$(uname -s)" == "Linux" ]]; then
  POLICY_DEVICE="${POLICY_DEVICE:-cuda}"
else
  POLICY_DEVICE="${POLICY_DEVICE:-mps}"
fi

echo ""
echo "Dataset: repo_id=${REPO_ID} root=${DATASET_ROOT}"
echo "Model:   ${MODEL_VERSION}"
echo "Output:  ${OUTPUT_DIR}"
echo "Device:  ${POLICY_DEVICE}"
echo ""

lerobot-train \
  --dataset.repo_id="${REPO_ID}" \
  --dataset.root="${DATASET_ROOT}" \
  --policy.type=act \
  --policy.device="${POLICY_DEVICE}" \
  --policy.push_to_hub=false \
  --output_dir="${OUTPUT_DIR}" \
  --job_name="${JOB_NAME}" \
  --dataset.image_transforms.enable=true \
  --wandb.enable=true \
  --steps=10000 \
  --batch_size=16 \
  --num_workers=2 \
  --save_checkpoint=true \
  --save_freq=1000 \
  --dataset.video_backend=torchcodec \
  "$@"
