# setup of worker-test-script: one program in $AIOS_WORKER_DIR/bin (spec 07, kind script)
[ -n "$AIOS_TEST_SETUP_FAIL" ] && { echo "setup fails on purpose"; exit 3; }
mkdir -p "$AIOS_WORKER_DIR/bin" || exit 1
printf '#!/bin/bash\necho "aios-test-script $*"\n' > "$AIOS_WORKER_DIR/bin/aios-test-script"
chmod +x "$AIOS_WORKER_DIR/bin/aios-test-script"
echo "setup done in $AIOS_WORKER_DIR"
