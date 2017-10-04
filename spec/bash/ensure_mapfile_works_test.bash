#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
source spec/bash/test_helpers

theCommand() {
  cat <<'EOF'
output line 1
output line 2
some more lines
WE WILL ASSERT ON THIS LINE
because lines are cool
last line
EOF

  return 0
}

T_mapfile_does_work() {
  mapfile \
    -s 2      `# remove first 2 lines` \
    -t        `# strip trailing newlines` \
    theOutput `# save to that array` \
    < <( theCommand )

  expect_to_equal "${theOutput[1]}" "WE WILL ASSERT ON THIS LINE"
}
