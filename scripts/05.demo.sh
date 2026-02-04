#!/usr/bin/env bash
# LeRobot 시연 — outputs/train/ 훈련 모델로 로봇 제어 (대회용)
# 모델을 먼저 로드한 뒤 엔터를 누르면 바로 동작. 텔레오프 없이 정책만 사용.
#
# 사용법 (프로젝트 루트에서):
#   ./scripts/05.demo.sh
#   POLICY_PATH=outputs/train/v0.1 ./scripts/05.demo.sh
#
# 환경변수:
#   POLICY_PATH        모델 경로. 비우면 outputs/train/ 목록에서 선택
#   DEMO_WAIT_ENTER    1 이면 로드 후 엔터로 시작 (기본: 1)
#   ROBOT_PORT, ROBOT_ID, CAMERA_*, NUM_EPISODES, DISPLAY_DATA
#
# 녹화는 하지 않음 (데이터 저장 없음). 녹화는 02.record.sh 사용.
#
# 종료: Ctrl+C

set -e
cd "$(dirname "$0")/.."

ROBOT_PORT="${ROBOT_PORT:-/dev/tty.usbmodem5AE60810051}"
ROBOT_ID="${ROBOT_ID:-my_follower_arm1}"
CAMERA_TOP_INDEX="${CAMERA_TOP_INDEX:-0}"
CAMERA_GRIPPER_INDEX="${CAMERA_GRIPPER_INDEX:-1}"
CAMERA_WIDTH="${CAMERA_WIDTH:-1280}"
CAMERA_HEIGHT="${CAMERA_HEIGHT:-720}"
CAMERA_FPS="${CAMERA_FPS:-30}"

NUM_EPISODES="${NUM_EPISODES:-10}"
DISPLAY_DATA="${DISPLAY_DATA:-true}"
export DEMO_WAIT_ENTER="${DEMO_WAIT_ENTER:-1}"

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

# 데모는 항상 녹화 안 함: 임시 디렉터리 사용 후 종료 시 삭제
# (dataset.root 는 존재하지 않는 경로여야 LeRobotDataset.create() 가 mkdir 할 수 있음)
DEMO_BASE=$(mktemp -d 2>/dev/null || mktemp -d -t lerobot_demo)
DEMO_ROOT="${DEMO_BASE}/lerobot_demo"
DATASET_REPO_ID="woolim/eval_demo_tmp"
trap 'rm -rf "$DEMO_BASE"' EXIT

echo "=== LeRobot Demo (Policy only, no recording) ==="
echo "Policy:   $POLICY_PATH"
echo "Robot:    $ROBOT_PORT  id=$ROBOT_ID"
echo "Cameras:  top=${CAMERA_TOP_INDEX}, gripper=${CAMERA_GRIPPER_INDEX} (${CAMERA_WIDTH}x${CAMERA_HEIGHT} @ ${CAMERA_FPS}fps)"
echo "Episodes: ${NUM_EPISODES}"
echo ""

lerobot-record \
  --robot.type=so101_follower \
  --robot.port="${ROBOT_PORT}" \
  --robot.id="${ROBOT_ID}" \
  --robot.cameras="${CAMERAS_JSON}" \
  --policy.path="${POLICY_PATH}" \
  --dataset.repo_id="${DATASET_REPO_ID}" \
  --dataset.root="${DEMO_ROOT}" \
  --dataset.single_task="Policy demo" \
  --dataset.num_episodes="${NUM_EPISODES}" \
  --dataset.fps="${DATASET_FPS}" \
  --dataset.push_to_hub=false \
  --display_data="${DISPLAY_DATA}" \
  "$@"
