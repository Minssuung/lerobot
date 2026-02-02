#!/usr/bin/env bash
# 체크포인트에서 훈련 이어하기 (04.train.sh 로 저장된 체크포인트 사용)
# outputs/train/ 에서 런 선택 → 체크포인트(스텝) 선택 → 이어서 훈련
#
# 사용법 (프로젝트 루트에서):
#   ./scripts/04.train_resume.sh
#   (런 선택 → 체크포인트 번호 선택)
#
# 환경변수로 건너뛰기:
#   CONFIG_PATH=outputs/train/act_pilot_xxx/checkpoints/005000/pretrained_model/train_config.json ./scripts/04.train_resume.sh
#
# 종료: Ctrl+C

set -e
cd "$(dirname "$0")/.."

TRAIN_DIR="${TRAIN_DIR:-outputs/train}"

# CONFIG_PATH 가 있으면 그대로 사용
if [[ -n "${CONFIG_PATH:-}" ]]; then
  if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Error: CONFIG_PATH not found: $CONFIG_PATH"
    exit 1
  fi
  echo "Resume from: $CONFIG_PATH"
  echo ""
  lerobot-train --resume=true --config_path="${CONFIG_PATH}" "$@"
  exit 0
fi

if [[ ! -d "$TRAIN_DIR" ]]; then
  echo "Error: $TRAIN_DIR not found. 먼저 04.train.sh 로 훈련하세요."
  exit 1
fi

# outputs/train/ 아래 런 폴더 목록 (checkpoints 가 있는 것만)
RUNS=()
for d in "$TRAIN_DIR"/act_pilot_*/; do
  [[ -d "$d" ]] && [[ -d "${d}checkpoints" ]] && RUNS+=("$(basename "$d")")
done

if [[ ${#RUNS[@]} -eq 0 ]]; then
  # act_pilot_ 뿐 아니라 아무 런 폴더
  for d in "$TRAIN_DIR"/*/; do
    [[ -d "$d" ]] && [[ -d "${d}checkpoints" ]] && RUNS+=("$(basename "$d")")
  done
fi

if [[ ${#RUNS[@]} -eq 0 ]]; then
  echo "No run with checkpoints in $TRAIN_DIR. 04.train.sh 로 훈련 후 체크포인트를 만드세요."
  exit 1
fi

echo "=== 이어서 훈련할 런 선택 ==="
for i in "${!RUNS[@]}"; do
  echo "  $((i + 1))) ${RUNS[$i]}"
done
echo ""
echo -n "런 번호: "
read -r RUN_NUM
if [[ ! "$RUN_NUM" =~ ^[0-9]+$ ]] || [[ "$RUN_NUM" -lt 1 ]] || [[ "$RUN_NUM" -gt ${#RUNS[@]} ]]; then
  echo "Error: 잘못된 번호."
  exit 1
fi
RUN_NAME="${RUNS[$((RUN_NUM - 1))]}"
RUN_DIR="${TRAIN_DIR}/${RUN_NAME}"
CKPT_DIR="${RUN_DIR}/checkpoints"

# 체크포인트(스텝) 목록
STEPS=()
for d in "$CKPT_DIR"/*/; do
  if [[ -d "$d" ]] && [[ -f "${d}pretrained_model/train_config.json" ]]; then
    STEPS+=("$(basename "$d")")
  fi
done

# 숫자 순 정렬 (005000, 010000 ...)
STEPS=($(printf '%s\n' "${STEPS[@]}" | sort -n))

if [[ ${#STEPS[@]} -eq 0 ]]; then
  echo "Error: No checkpoint with train_config.json in $CKPT_DIR"
  exit 1
fi

echo ""
echo "=== 이어갈 체크포인트 (스텝) 선택 ==="
for i in "${!STEPS[@]}"; do
  echo "  $((i + 1))) ${STEPS[$i]}"
done
echo ""
echo -n "체크포인트 번호: "
read -r STEP_NUM
if [[ ! "$STEP_NUM" =~ ^[0-9]+$ ]] || [[ "$STEP_NUM" -lt 1 ]] || [[ "$STEP_NUM" -gt ${#STEPS[@]} ]]; then
  echo "Error: 잘못된 번호."
  exit 1
fi
STEP_NAME="${STEPS[$((STEP_NUM - 1))]}"
CONFIG_PATH="${RUN_DIR}/checkpoints/${STEP_NAME}/pretrained_model/train_config.json"

echo ""
echo "Resume from: $CONFIG_PATH"
echo ""

lerobot-train --resume=true --config_path="${CONFIG_PATH}" "$@"
