#!/usr/bin/env bash
# setup_local_env.sh — ALFWorld benchmark environment, self-contained in THIS folder.
#
#   .venv/   uv venv, Python 3.12 (CPU only); this repo installed editable (with its textworld dependency)
#   data/    game data from alfworld-download (json_2.1.1/{train,valid_seen,valid_unseen}, logic/)
#
# Kept isolated from the training framework (implementation/CO-HARNESS-SEED-RL). That venv only
# POINTS at data/ via ALFWORLD_DATA. It installs this same repo (non-editable) and pins the same
# textworld, and its setup script checks that the versions match.
#
# Usage: bash setup_local_env.sh            Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
VENV="$HERE/.venv"
PY="$VENV/bin/python"
export ALFWORLD_DATA="$HERE/data"

echo "[1] venv $VENV"
[ -x "$PY" ] || uv venv --python 3.12 "$VENV"
uv pip install --python "$PY" -e "$HERE"
"$PY" -c "import alfworld, textworld; print('  [ok] alfworld', alfworld.__file__, ' textworld', textworld.__version__)"

echo "[2] game data -> $ALFWORLD_DATA"
if [ -d "$ALFWORLD_DATA/json_2.1.1/train" ] && [ -f "$ALFWORLD_DATA/logic/alfred.pddl" ]; then
  echo "  already present"
else
  "$VENV/bin/alfworld-download"
fi
for need in json_2.1.1/train json_2.1.1/valid_seen json_2.1.1/valid_unseen logic/alfred.pddl logic/alfred.twl2; do
  [ -e "$ALFWORLD_DATA/$need" ] || { echo "FATAL: missing $ALFWORLD_DATA/$need"; exit 1; }
done
for s in train valid_seen valid_unseen; do
  echo "  $s: $(find "$ALFWORLD_DATA/json_2.1.1/$s" -name game.tw-pddl | wc -l) games"
done

echo "[3] env smoke: one TextWorld ALFWorld reset (valid_unseen)"
"$PY" - "$HERE/configs/base_config.yaml" <<'PY'
import sys, yaml
from alfworld.agents.environment import get_environment
cfg = yaml.safe_load(open(sys.argv[1]))
env = get_environment("AlfredTWEnv")(cfg, train_eval="eval_out_of_distribution").init_env(batch_size=1)
obs, info = env.reset()
print("  [ok] reset:", obs[0][:120].replace("\n", " "))
PY
echo "[done] ALFWORLD_DATA=$ALFWORLD_DATA  venv=$VENV"
