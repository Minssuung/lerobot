#!/usr/bin/env bash
# LeRobot 시연 — outputs/train/ 에 있는 훈련된 모델로 로봇 제어
# 텔레오프 없이 정책(policy)만으로 동작. 02.record 와 동일한 로봇/카메라 설정.
#
# 사용법 (프로젝트 루트에서):
#   ./scripts/03.demo.sh                    # outputs/train/ 목록에서 선택 프롬프트
#   POLICY_PATH=outputs/train/act_pilot_v0.1-pilot ./scripts/03.demo.sh
#
# 환경변수:
#   POLICY_PATH        설정 시 프롬프트 없이 해당 경로 사용. 비우면 outputs/train/ 목록에서 선택
#                      - 체크포인트: .../checkpoints/005000/pretrained_model
#                      - 런 폴더: outputs/train/act_pilot_v0.1-pilot (최신 체크포인트 자동)
#   ROBOT_PORT         팔로워(로봇) 시리얼 포트
#   CAMERA_*           01.teleop.sh / 02.record.sh 와 동일
#   NUM_EPISODES       시연 에피소드 수 (기본: 1)
#   DISPLAY_DATA       화면에 카메라 표시 (기본: true)
#
# 종료: Ctrl+C

set -e
cd "$(dirname "$0")/.."

ROBOT_PORT="${ROBOT_PORT:-/dev/tty.usbmodem5AE60810051}"
ROBOT_ID="${ROBOT_ID:-my_follower_arm1}"
CAMERA_TOP_INDEX="${CAMERA_TOP_INDEX:-0}"
CAMERA_GRIPPER_INDEX="${CAMERA_GRIPPER_INDEX:-1}"
CAMERA_WIDTH="${CAMERA_WIDTH:-640}"
CAMERA_HEIGHT="${CAMERA_HEIGHT:-480}"
CAMERA_FPS="${CAMERA_FPS:-25}"

NUM_EPISODES="${NUM_EPISODES:-5}"
DISPLAY_DATA="${DISPLAY_DATA:-true}"

# POLICY_PATH 미설정 시 outputs/train/ 목록에서 선택
TRAIN_DIR="outputs/train"
if [[ -z "${POLICY_PATH:-}" ]]; then
  if [[ ! -d "$TRAIN_DIR" ]]; then
    echo "Error: $TRAIN_DIR not found. Train a model first or set POLICY_PATH."
    exit 1
  fi
  RUNS=()
  for d in "$TRAIN_DIR"/*/; do
    [[ -d "$d" ]] && RUNS+=("${d%/}")
  done
  if [[ ${#RUNS[@]} -eq 0 ]]; then
    echo "Error: No model runs found in $TRAIN_DIR"
    exit 1
  fi
  echo "=== $TRAIN_DIR 에 있는 모델 ==="
  for i in "${!RUNS[@]}"; do
    echo "  $((i + 1))) $(basename "${RUNS[$i]}")"
  done
  echo ""
  echo -n "모델 선택 (번호 또는 경로 입력): "
  read -r CHOICE
  if [[ -z "$CHOICE" ]]; then
    echo "Error: 선택이 비어 있습니다."
    exit 1
  fi
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [[ "$CHOICE" -ge 1 ]] && [[ "$CHOICE" -le ${#RUNS[@]} ]]; then
    POLICY_PATH="${RUNS[$((CHOICE - 1))]}"
  else
    POLICY_PATH="$CHOICE"
  fi
  echo "선택: $POLICY_PATH"
  echo ""
fi

# POLICY_PATH 가 pretrained_model 이 아니면 최신 체크포인트 찾기
if [[ -d "$POLICY_PATH" ]]; then
  if [[ -d "${POLICY_PATH}/checkpoints" ]]; then
    LATEST_STEP=$(ls -1 "${POLICY_PATH}/checkpoints/" 2>/dev/null | sort -n | tail -1)
    if [[ -n "$LATEST_STEP" ]] && [[ -d "${POLICY_PATH}/checkpoints/${LATEST_STEP}/pretrained_model" ]]; then
      POLICY_PATH="${POLICY_PATH}/checkpoints/${LATEST_STEP}/pretrained_model"
    else
      echo "Error: No pretrained_model found under ${POLICY_PATH}/checkpoints/"
      exit 1
    fi
  elif [[ ! -f "${POLICY_PATH}/config.json" ]]; then
    echo "Error: POLICY_PATH is not a checkpoint dir (no config.json): $POLICY_PATH"
    exit 1
  fi
else
  echo "Error: POLICY_PATH not found: $POLICY_PATH"
  exit 1
fi

CAMERAS_JSON="{ top: {type: opencv, index_or_path: ${CAMERA_TOP_INDEX}, width: ${CAMERA_WIDTH}, height: ${CAMERA_HEIGHT}, fps: ${CAMERA_FPS}}, gripper: {type: opencv, index_or_path: ${CAMERA_GRIPPER_INDEX}, width: ${CAMERA_WIDTH}, height: ${CAMERA_HEIGHT}, fps: ${CAMERA_FPS}}}"
DATASET_FPS="${CAMERA_FPS}"

echo "=== LeRobot Demo (Policy only) ==="
echo "Policy:  $POLICY_PATH"
echo "Robot:   $ROBOT_PORT  id=$ROBOT_ID"
echo "Cameras:  top=${CAMERA_TOP_INDEX}, gripper=${CAMERA_GRIPPER_INDEX} (${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FPS}fps)"
echo "Episodes: ${NUM_EPISODES}"
echo ""

lerobot-record \
  --robot.type=so101_follower \
  --robot.port="${ROBOT_PORT}" \
  --robot.id="${ROBOT_ID}" \
  --robot.cameras="${CAMERAS_JSON}" \
  --policy.path="${POLICY_PATH}" \
  --dataset.repo_id=woolim/eval_demo \
  --dataset.root=./data/eval_demo \
  --dataset.single_task="Policy demo" \
  --dataset.num_episodes="${NUM_EPISODES}" \
  --dataset.fps="${DATASET_FPS}" \
  --dataset.push_to_hub=false \
  --display_data="${DISPLAY_DATA}" \
  "$@"
