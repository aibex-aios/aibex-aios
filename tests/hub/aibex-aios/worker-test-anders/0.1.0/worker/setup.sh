# setup of worker-test-anders: the program of worker-test, from another package (conflict, F9)
mkdir -p "$AIOS_WORKER_DIR/bin" || exit 1
printf '#!/bin/bash\necho "anders $*"\n' > "$AIOS_WORKER_DIR/bin/aios-test-tool"
chmod +x "$AIOS_WORKER_DIR/bin/aios-test-tool"
